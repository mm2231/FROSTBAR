// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import XCTest
@testable import FrostBarCore
@testable import FrostBarModes

final class CurveInterpolatorTests: XCTestCase {
    func testLinearInterpolation() {
        let interpolator = CurveInterpolator()
        XCTAssertEqual(interpolator.rpm(for: Celsius(50), curve: .balanced), RPM(1750))
    }

    func testClampingOutsideTheCurve() {
        let interpolator = CurveInterpolator()
        XCTAssertEqual(interpolator.rpm(for: Celsius(0), curve: .balanced), RPM(1300))
        XCTAssertEqual(interpolator.rpm(for: Celsius(120), curve: .balanced), RPM(6200))
    }

    func testStepInterpolation() {
        let curve = FanCurve(
            points: [
                .init(celsius: Celsius(40), rpm: RPM(1000)),
                .init(celsius: Celsius(60), rpm: RPM(2000)),
            ],
            interpolation: .step
        )
        XCTAssertEqual(CurveInterpolator().rpm(for: Celsius(59), curve: curve), RPM(1000))
    }

    func testEmptyCurve() {
        XCTAssertEqual(CurveInterpolator().rpm(for: Celsius(50), curve: FanCurve(points: [])), .zero)
    }
}

final class HysteresisGateTests: XCTestCase {
    func testEngagesAboveThresholdPlusOffset() {
        let rule = makeRule()
        let gate = HysteresisGate()

        XCTAssertFalse(gate.isEngaged(rule: rule, input: makeInput(temperature: 80)))
        XCTAssertTrue(gate.isEngaged(rule: rule, input: makeInput(temperature: 82)))
    }

    func testStaysEngagedDuringMinimumDwell() {
        let rule = makeRule()
        let now = Date(timeIntervalSince1970: 1_000)
        let input = makeInput(
            temperature: 60,
            state: EvaluationState(engagedRules: [rule.id.rawValue: now.addingTimeInterval(-5)]),
            now: now
        )
        XCTAssertTrue(HysteresisGate().isEngaged(rule: rule, input: input))
    }

    func testReleasesBelowReleaseThresholdAfterDwell() {
        let rule = makeRule()
        let now = Date(timeIntervalSince1970: 1_000)
        let input = makeInput(
            temperature: 70,
            state: EvaluationState(engagedRules: [rule.id.rawValue: now.addingTimeInterval(-30)]),
            now: now
        )
        XCTAssertFalse(HysteresisGate().isEngaged(rule: rule, input: input))
    }

    private func makeRule() -> Rule {
        Rule(
            id: "hot",
            condition: .sensorAbove(.cpuMax, Celsius(78)),
            output: .fixed(RPM(4000)),
            hysteresis: HysteresisPolicy(
                engageOffset: 3,
                releaseOffset: 5,
                minimumDwell: 10,
                cooldown: 15,
                maxStepRPM: 800
            )
        )
    }
}

final class FanSafetyPolicyTests: XCTestCase {
    func testEmergencyTemperatureForcesAutomatic() {
        let input = makeInput(temperature: 96)
        XCTAssertEqual(
            FanSafetyPolicy().review(.fixed(RPM(3000)), input: input),
            .forceAutomatic(.emergencyTemperature)
        )
    }

    func testUnsupportedHardwareForcesAutomatic() {
        var input = makeInput(temperature: 60)
        input.capabilities.canControlFans = false
        XCTAssertEqual(
            FanSafetyPolicy().review(.fixed(RPM(3000)), input: input),
            .forceAutomatic(.unsupportedHardware)
        )
    }

    func testClampsAboveHardwareMaximum() {
        let input = makeInput(temperature: 60)
        guard case let .clamped(command, violations) = FanSafetyPolicy().review(.fixed(RPM(9000)), input: input) else {
            return XCTFail("Expected a clamped verdict")
        }
        XCTAssertEqual(command, .fixed(RPM(6000)))
        XCTAssertTrue(violations.contains(.clampRequired))
    }

    func testSlewLimitsTheChange() {
        let now = Date(timeIntervalSince1970: 1_000)
        var input = makeInput(
            temperature: 60,
            state: EvaluationState(lastTargetRPM: RPM(1000), lastChangeAt: now.addingTimeInterval(-1)),
            now: now
        )
        input.profile = Profile(id: "p", name: "P", rules: [])
        guard case let .clamped(command, violations) = FanSafetyPolicy().review(.fixed(RPM(5000)), input: input) else {
            return XCTFail("Expected a clamped verdict")
        }
        XCTAssertEqual(command, .fixed(RPM(1800)))
        XCTAssertTrue(violations.contains(.slewLimited))
    }

    func testForceZeroIsForcedBackToAutomaticAboveSeventyDegrees() {
        var input = makeInput(temperature: 72)
        input.advanced.idleBehavior = .forceZero
        XCTAssertEqual(
            FanSafetyPolicy().review(.fixed(RPM(0)), input: input),
            .forceAutomatic(.fanStopTooHot)
        )
    }
}

final class FanWritePolicyTests: XCTestCase {
    private let inventory = [
        FanDescriptor(id: FanID(0), name: "Fan 1", currentRPM: RPM(1500), minRPM: RPM(1300), maxRPM: RPM(6000)),
        FanDescriptor(id: FanID(1), name: "Fan 2", currentRPM: RPM(1500), minRPM: RPM(1300), maxRPM: RPM(6000)),
    ]

    func testAutomaticWritesModeZero() throws {
        let writes = try FanWritePolicy().plan(
            command: .automatic,
            inventory: inventory,
            issuedAt: Date(),
            now: Date(),
            idleBehavior: .off
        )
        XCTAssertEqual(writes.count, 2)
        XCTAssertEqual(writes.first?.key, .mode)
        XCTAssertEqual(writes.first?.value, .flag(0))
    }

    func testFixedWritesManualModeAndTarget() throws {
        let writes = try FanWritePolicy().plan(
            command: .fixed(RPM(3000)),
            inventory: inventory,
            issuedAt: Date(),
            now: Date(),
            idleBehavior: .off
        )
        XCTAssertEqual(writes.count, 4)
        XCTAssertTrue(writes.contains(.init(fan: FanID(0), key: .mode, value: .flag(1))))
        XCTAssertTrue(writes.contains(.init(fan: FanID(0), key: .target, value: .rpm(RPM(3000)))))
    }

    func testZeroRPMIsRejectedWithoutForceZero() {
        XCTAssertThrowsError(
            try FanWritePolicy().plan(
                command: .fixed(RPM(0)),
                inventory: inventory,
                issuedAt: Date(),
                now: Date(),
                idleBehavior: .off
            )
        ) { error in
            XCTAssertEqual(error as? FanWritePolicy.PolicyError, .zeroRPMRequiresForceZero)
        }
    }

    func testZeroRPMIsRejectedEvenWithForceZeroInV1() {
        XCTAssertThrowsError(
            try FanWritePolicy().plan(
                command: .fixed(RPM(0)),
                inventory: inventory,
                issuedAt: Date(),
                now: Date(),
                idleBehavior: .forceZero
            )
        ) { error in
            XCTAssertEqual(error as? FanWritePolicy.PolicyError, .forceZeroNotAvailable)
        }
    }

    func testOutOfRangeIsRejected() {
        XCTAssertThrowsError(
            try FanWritePolicy().plan(
                command: .fixed(RPM(7000)),
                inventory: inventory,
                issuedAt: Date(),
                now: Date(),
                idleBehavior: .off
            )
        ) { error in
            guard case .outOfRange = error as? FanWritePolicy.PolicyError else {
                return XCTFail("Expected outOfRange, got \(error)")
            }
        }
    }

    func testExpiredCommandIsRejected() {
        XCTAssertThrowsError(
            try FanWritePolicy().plan(
                command: .fixed(RPM(3000)),
                inventory: inventory,
                issuedAt: Date(timeIntervalSince1970: 0),
                now: Date(timeIntervalSince1970: 100),
                idleBehavior: .off
            )
        ) { error in
            XCTAssertEqual(error as? FanWritePolicy.PolicyError, .commandExpired)
        }
    }
}

final class DefaultModeEvaluatorTests: XCTestCase {
    func testRuleOutputWinsOverBasePolicy() {
        let profile = Profile(
            id: "p",
            name: "P",
            base: .fixed(RPM(1300)),
            rules: [
                Rule(
                    id: "hot",
                    condition: .sensorAbove(.cpuMax, Celsius(60)),
                    output: .fixed(RPM(4000)),
                    hysteresis: HysteresisPolicy(engageOffset: 2, releaseOffset: 4)
                ),
            ]
        )
        var input = makeInput(temperature: 70)
        input.profile = profile

        guard case let .apply(command, reason) = DefaultModeEvaluator().evaluate(input) else {
            return XCTFail("Expected an apply result")
        }
        XCTAssertEqual(command, .fixed(RPM(4000)))
        XCTAssertEqual(reason.ruleID, "hot")
    }

    func testBaseCurveAppliesWithoutRules() {
        let profile = Profile(id: "p", name: "P", base: .curve(.balanced))
        var input = makeInput(temperature: 50)
        input.profile = profile

        guard case let .apply(command, _) = DefaultModeEvaluator().evaluate(input) else {
            return XCTFail("Expected an apply result")
        }
        XCTAssertEqual(command, .fixed(RPM(1750)))
    }
}

// MARK: - Fixtures

private func makeInput(
    temperature: Double,
    state: EvaluationState = .initial,
    now: Date = Date(timeIntervalSince1970: 1_000)
) -> EvaluationInput {
    let snapshot = SensorSnapshot(
        timestamp: now,
        temperatures: [.init(sensor: .cpuMax, celsius: Celsius(temperature))],
        fans: [
            FanDescriptor(id: FanID(0), name: "Fan 1", currentRPM: RPM(1500), minRPM: RPM(1300), maxRPM: RPM(6000)),
            FanDescriptor(id: FanID(1), name: "Fan 2", currentRPM: RPM(1500), minRPM: RPM(1300), maxRPM: RPM(6000)),
        ]
    )
    return EvaluationInput(
        snapshot: snapshot,
        profile: Profile(id: "p", name: "P"),
        context: .empty,
        capabilities: SystemCapabilities(
            architecture: .intel,
            modelIdentifier: "MacBookPro15,1",
            isTouchBarModel: true,
            fanCount: 2,
            canControlFans: true,
            sensorTransport: .inProcess
        ),
        advanced: AdvancedSettings(),
        state: state,
        now: now
    )
}

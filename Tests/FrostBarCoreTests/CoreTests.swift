// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import XCTest
@testable import FrostBarCore

final class HardwareGuardrailsTests: XCTestCase {
    func testGuardrailValuesAreCompiledIn() {
        XCTAssertEqual(HardwareGuardrails.forceZeroAmbientLimit, Celsius(50))
        XCTAssertEqual(HardwareGuardrails.forceZeroForcedAuto, Celsius(70))
        XCTAssertEqual(HardwareGuardrails.emergencyAuto, Celsius(95))
        XCTAssertEqual(HardwareGuardrails.maxSlewRPMps, 800)
        XCTAssertEqual(HardwareGuardrails.watchdogTimeout, 10)
    }

    func testGuardrailsAreNotPartOfTheCodableConfiguration() throws {
        // Whatever a user writes into JSON, the compiled constants do not change
        // and SafetySettings cannot raise the emergency threshold above them.
        var configuration = Configuration.default
        configuration.safety.emergencyCelsius = Celsius(120)
        let data = try JSONEncoder().encode(configuration)
        let decoded = try JSONDecoder().decode(Configuration.self, from: data)

        XCTAssertEqual(decoded.safety.emergencyCelsius, Celsius(120))
        XCTAssertGreaterThan(decoded.safety.emergencyCelsius, HardwareGuardrails.emergencyAuto)
        // The policy, not the JSON, decides. See FanSafetyPolicyTests.
    }
}

final class CodableTests: XCTestCase {
    func testConfigurationRoundTrip() throws {
        let encoder = JSONCodingForTests.encoder
        let data = try encoder.encode(Configuration.default)
        let decoded = try JSONCodingForTests.decoder.decode(Configuration.self, from: data)
        XCTAssertEqual(decoded, Configuration.default)
    }

    func testFanPolicyRoundTrip() throws {
        let policies: [FanPolicy] = [
            .automatic,
            .fixed(RPM(4200)),
            .curve(.balanced),
            .perFan(["fan0": RPM(3000), "fan1": RPM(3200)]),
        ]
        for policy in policies {
            let data = try JSONCodingForTests.encoder.encode(policy)
            let decoded = try JSONCodingForTests.decoder.decode(FanPolicy.self, from: data)
            XCTAssertEqual(decoded, policy)
        }
    }

    func testUnknownPolicyAndConditionArePreserved() throws {
        let json = Data(#"{"type":"futurePolicy","value":1}"#.utf8)
        let policy = try JSONCodingForTests.decoder.decode(FanPolicy.self, from: json)
        XCTAssertEqual(policy, .unsupported("futurePolicy"))

        let conditionJSON = Data(#"{"type":"futureCondition"}"#.utf8)
        let condition = try JSONCodingForTests.decoder.decode(Condition.self, from: conditionJSON)
        XCTAssertEqual(condition, .unsupported("futureCondition"))
    }

    func testFanCommandRoundTrip() throws {
        let commands: [FanCommand] = [
            .automatic,
            .fixed(RPM(2000)),
            .perFan(["fan0": RPM(1500)]),
            .limits(fan: FanID(0), minimum: RPM(1200), maximum: RPM(6000)),
        ]
        for command in commands {
            let data = try JSONCodingForTests.encoder.encode(command)
            let decoded = try JSONCodingForTests.decoder.decode(FanCommand.self, from: data)
            XCTAssertEqual(decoded, command)
        }
    }
}

final class FallbackSensorProviderTests: XCTestCase {
    func testFallsBackWhenInProcessAccessIsDenied() async throws {
        let primary = FailingSensorProvider(error: .smcNotPrivileged)
        let secondary = StaticSensorProvider()
        let provider = FallbackSensorProvider(inProcess: primary, helperBacked: secondary)

        let snapshot = try await provider.snapshot()
        XCTAssertEqual(snapshot.temperatures.count, 1)
        let capabilities = try await provider.capabilities()
        XCTAssertEqual(capabilities.sensorTransport, .helper)
    }
}

// MARK: - Fakes

private enum FailingSensorProviderError: Error {
    case unexpected
}

private struct FailingSensorProvider: SensorProviding {
    let error: FrostBarError

    func capabilities() async throws -> SystemCapabilities {
        throw error
    }

    func snapshot() async throws -> SensorSnapshot {
        throw error
    }
}

private struct StaticSensorProvider: SensorProviding {
    func capabilities() async throws -> SystemCapabilities {
        SystemCapabilities(
            architecture: .intel,
            modelIdentifier: "MacBookPro15,1",
            isTouchBarModel: true,
            fanCount: 2,
            canControlFans: true,
            sensorTransport: .helper
        )
    }

    func snapshot() async throws -> SensorSnapshot {
        SensorSnapshot(
            timestamp: Date(timeIntervalSince1970: 0),
            temperatures: [.init(sensor: .cpuMax, celsius: Celsius(60))],
            fans: []
        )
    }
}

enum JSONCodingForTests {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation
import FrostBarCore

/// Last line of defence before a fan command leaves the process.
///
/// The helper re-runs an equivalent policy, so a bug or a compromised app
/// process cannot bypass the limits.
public struct FanSafetyPolicy: Sendable {
    public enum Verdict: Sendable, Equatable {
        case allow(FanCommand)
        case clamped(FanCommand, [SafetyViolation])
        case forceAutomatic(SafetyViolation)
    }

    public init() {}

    public func review(_ proposal: FanCommand, input: EvaluationInput) -> Verdict {
        guard input.capabilities.canControlFans else {
            return .forceAutomatic(.unsupportedHardware)
        }

        if let maximum = input.snapshot.maxTemperature, maximum >= HardwareGuardrails.emergencyAuto {
            return .forceAutomatic(.emergencyTemperature)
        }

        if input.advanced.idleBehavior == .forceZero,
           let maximum = input.snapshot.maxTemperature,
           maximum >= HardwareGuardrails.forceZeroForcedAuto {
            return .forceAutomatic(.fanStopTooHot)
        }

        switch proposal {
        case .automatic, .limits:
            return .allow(proposal)

        case let .fixed(rpm):
            return reviewTarget(rpm, command: proposal, input: input)

        case let .perFan(values):
            let fans = input.snapshot.fans
            var violations: [SafetyViolation] = []
            var clampedValues: [String: RPM] = [:]
            for fan in fans {
                let requested = values[fan.id.rawValue] ?? fan.currentRPM
                let limited = limit(requested, fan: fan, input: input)
                if limited != requested {
                    violations.append(.clampRequired)
                }
                clampedValues[fan.id.rawValue] = limited
            }
            let command = FanCommand.perFan(clampedValues)
            return violations.isEmpty ? .allow(command) : .clamped(command, violations)
        }
    }

    private func reviewTarget(_ rpm: RPM, command: FanCommand, input: EvaluationInput) -> Verdict {
        let globalRange = globalRange(for: input.snapshot.fans)
        var violations: [SafetyViolation] = []

        var target = rpm
        if target > globalRange.upperBound || target < globalRange.lowerBound {
            target = target.clamped(to: globalRange)
            violations.append(.clampRequired)
        }

        let limited = SlewRateLimiter().limit(
            target: target,
            previous: input.state.lastTargetRPM,
            elapsed: elapsedSinceLastChange(input),
            maxRPMps: input.safetyMaxSlew
        )
        if limited != target {
            violations.append(.slewLimited)
        }

        let result = FanCommand.fixed(limited)
        return violations.isEmpty ? .allow(result) : .clamped(result, violations)
    }

    private func limit(_ rpm: RPM, fan: FanDescriptor, input: EvaluationInput) -> RPM {
        var range = fan.range
        let absolute = RPM(0)...min(fan.maxRPM, HardwareGuardrails.absoluteMaxRPM)
        range = max(range.lowerBound, absolute.lowerBound)...min(range.upperBound, absolute.upperBound)
        return rpm.clamped(to: range)
    }

    private func globalRange(for fans: [FanDescriptor]) -> ClosedRange<RPM> {
        guard let first = fans.first else { return RPM(0)...HardwareGuardrails.absoluteMaxRPM }
        var lower = first.minRPM
        var upper = first.maxRPM
        for fan in fans {
            lower = min(lower, fan.minRPM)
            upper = max(upper, fan.maxRPM)
        }
        return lower...min(upper, HardwareGuardrails.absoluteMaxRPM)
    }

    private func elapsedSinceLastChange(_ input: EvaluationInput) -> TimeInterval {
        guard let last = input.state.lastChangeAt else { return 3600 }
        return max(0, input.now.timeIntervalSince(last))
    }
}

private extension EvaluationInput {
    var safetyMaxSlew: Int {
        min(HardwareGuardrails.maxSlewRPMps, max(0, profile.rules.first?.hysteresis.maxStepRPM ?? HardwareGuardrails.maxSlewRPMps))
    }
}

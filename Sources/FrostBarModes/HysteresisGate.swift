// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation
import FrostBarCore

public struct SlewRateLimiter: Sendable {
    public init() {}

    /// Limits the change relative to the previously applied speed.
    public func limit(target: RPM, previous: RPM?, elapsed: TimeInterval, maxRPMps: Int) -> RPM {
        guard let previous else { return target }
        guard maxRPMps > 0 else { return previous }

        let maxDelta = Int(Double(maxRPMps) * max(elapsed, 0))
        let delta = target.rawValue - previous.rawValue
        let clampedDelta = min(max(delta, -maxDelta), maxDelta)
        return RPM(previous.rawValue + clampedDelta)
    }
}

public struct HysteresisGate: Sendable {
    public init() {}

    /// True when the rule is (or must remain) engaged.
    ///
    /// Threshold rules use separate engage/release offsets plus dwell and
    /// cooldown; non-threshold rules simply follow their condition.
    public func isEngaged(rule: Rule, input: EvaluationInput) -> Bool {
        guard rule.isEnabled else { return false }

        guard case let .sensorAbove(sensor, threshold) = rule.condition else {
            return RuleEvaluator().matches(rule.condition, snapshot: input.snapshot, context: input.context)
        }
        guard let value = input.snapshot.temperature(for: sensor) else { return false }

        if let engagedAt = input.state.engagedRules[rule.id.rawValue] {
            let dwell = input.now.timeIntervalSince(engagedAt)
            let releaseThreshold = threshold.rawValue - rule.hysteresis.releaseOffset
            if value.rawValue >= releaseThreshold || dwell < rule.hysteresis.minimumDwell {
                return true
            }
            return false
        }

        let engageThreshold = threshold.rawValue + rule.hysteresis.engageOffset
        guard value.rawValue >= engageThreshold else { return false }

        if let lastChange = input.state.lastChangeAt {
            return input.now.timeIntervalSince(lastChange) >= rule.hysteresis.cooldown
        }
        return true
    }
}

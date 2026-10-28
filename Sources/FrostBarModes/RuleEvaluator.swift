// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation
import FrostBarCore

public struct RuleEvaluator: Sendable {
    public init() {}

    public func matches(_ condition: Condition, snapshot: SensorSnapshot, context: AppContext) -> Bool {
        switch condition {
        case .any:
            return true

        case let .sensorAbove(sensor, threshold):
            guard let value = snapshot.temperature(for: sensor) else { return false }
            return value > threshold

        case let .sensorBelow(sensor, threshold):
            guard let value = snapshot.temperature(for: sensor) else { return false }
            return value < threshold

        case let .all(conditions):
            return !conditions.isEmpty && conditions.allSatisfy { matches($0, snapshot: snapshot, context: context) }

        case let .anyOf(conditions):
            return conditions.contains { matches($0, snapshot: snapshot, context: context) }

        case let .appRunning(bundleIDs):
            let running = Set(bundleIDs)
            return !running.isDisjoint(with: context.runningBundleIDs)

        case .onBattery:
            return !context.isOnAC

        case let .thermalPressure(required):
            return rank(snapshot.thermalPressure) >= rank(required)

        case .unsupported:
            return false
        }
    }

    /// Highest-priority enabled rule whose condition matches and whose
    /// hysteresis gate is engaged. Ties are broken by identifier so the result
    /// is deterministic and reproducible in tests.
    public func bestRule(in input: EvaluationInput) -> Rule? {
        let gate = HysteresisGate()
        return input.profile.rules
            .filter(\.isEnabled)
            .filter { matches($0.condition, snapshot: input.snapshot, context: input.context) }
            .filter { gate.isEngaged(rule: $0, input: input) }
            .max { lhs, rhs in
                if lhs.priority != rhs.priority {
                    return lhs.priority < rhs.priority
                }
                return lhs.id.rawValue > rhs.id.rawValue
            }
    }

    private func rank(_ pressure: ThermalPressure) -> Int {
        switch pressure {
        case .nominal: return 0
        case .fair: return 1
        case .serious: return 2
        case .critical: return 3
        }
    }
}

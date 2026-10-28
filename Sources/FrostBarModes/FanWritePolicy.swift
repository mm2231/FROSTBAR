// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation
import FrostBarCore

/// Helper-side validation of everything that reaches the SMC.
///
/// Whitelisted keys only, fan indices bounded, values clamped, commands expire
/// and the future `forceZero` behaviour is rejected unless explicitly enabled.
public struct FanWritePolicy: Sendable {
    public enum PolicyError: Error, Equatable, LocalizedError {
        case noFans
        case unknownFan(FanID)
        case outOfRange(fan: FanID, requested: Int, allowed: ClosedRange<Int>)
        case zeroRPMRequiresForceZero
        case forceZeroNotAvailable
        case commandExpired
        case writeTooSoon

        public var errorDescription: String? {
            switch self {
            case .noFans: return "The Mac reports no controllable fans."
            case let .unknownFan(fan): return "Unknown fan \(fan.rawValue)."
            case let .outOfRange(fan, requested, allowed):
                return "\(fan.rawValue): \(requested) rpm is outside \(allowed.lowerBound)...\(allowed.upperBound)."
            case .zeroRPMRequiresForceZero: return "Zero rpm requires the forceZero behaviour."
            case .forceZeroNotAvailable: return "forceZero is not available in v1."
            case .commandExpired: return "The command expired before it was applied."
            case .writeTooSoon: return "Two writes for the same fan arrived too close together."
            }
        }
    }

    public static let allowedFans = 0 ... 3

    public init() {}

    public func plan(
        command: FanCommand,
        inventory: [FanDescriptor],
        issuedAt: Date?,
        now: Date,
        idleBehavior: FanIdleBehavior
    ) throws -> [PlannedWrite] {
        guard !inventory.isEmpty else { throw PolicyError.noFans }
        guard Set(inventory.map(\.id.index)).isSubset(of: Set(Self.allowedFans)) else {
            throw PolicyError.unknownFan(inventory.first { !Self.allowedFans.contains($0.id.index) }?.id ?? FanID(0))
        }
        if let issuedAt, now.timeIntervalSince(issuedAt) > HardwareGuardrails.commandTTL {
            throw PolicyError.commandExpired
        }

        switch command {
        case .automatic:
            return inventory.flatMap { fan in
                [
                    PlannedWrite(fan: fan.id, key: .mode, value: .flag(0)),
                ]
            }

        case let .fixed(rpm):
            return try inventory.flatMap { try writes(for: $0, rpm: rpm, idleBehavior: idleBehavior) }

        case let .perFan(values):
            return try inventory.flatMap { fan -> [PlannedWrite] in
                guard let rpm = values[fan.id.rawValue] else { return [] }
                return try writes(for: fan, rpm: rpm, idleBehavior: idleBehavior)
            }

        case let .limits(fanID, minimum, maximum):
            guard let fan = inventory.first(where: { $0.id == fanID }) else { throw PolicyError.unknownFan(fanID) }
            var result: [PlannedWrite] = []
            if let minimum {
                result.append(PlannedWrite(fan: fanID, key: .minimum, value: .rpm(try validated(minimum, fan: fan, idleBehavior: idleBehavior))))
            }
            if let maximum {
                result.append(PlannedWrite(fan: fanID, key: .maximum, value: .rpm(try validated(maximum, fan: fan, idleBehavior: idleBehavior))))
            }
            return result
        }
    }

    private func writes(for fan: FanDescriptor, rpm: RPM, idleBehavior: FanIdleBehavior) throws -> [PlannedWrite] {
        let validated = try validated(rpm, fan: fan, idleBehavior: idleBehavior)
        return [
            PlannedWrite(fan: fan.id, key: .mode, value: .flag(1)),
            PlannedWrite(fan: fan.id, key: .target, value: .rpm(validated)),
        ]
    }

    private func validated(_ rpm: RPM, fan: FanDescriptor, idleBehavior: FanIdleBehavior) throws -> RPM {
        if rpm == .zero {
            guard idleBehavior == .forceZero else { throw PolicyError.zeroRPMRequiresForceZero }
            throw PolicyError.forceZeroNotAvailable
        }
        let upper = min(fan.maxRPM, HardwareGuardrails.absoluteMaxRPM)
        let range = max(fan.minRPM, RPM(1))...upper
        guard range.contains(rpm) else {
            throw PolicyError.outOfRange(
                fan: fan.id,
                requested: rpm.rawValue,
                allowed: range.lowerBound.rawValue...range.upperBound.rawValue
            )
        }
        return rpm
    }
}

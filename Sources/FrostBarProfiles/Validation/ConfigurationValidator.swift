// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation
import FrostBarCore

public struct ValidationIssue: Sendable, Equatable {
    public enum Severity: String, Sendable {
        case warning
        case error
    }

    public var severity: Severity
    public var path: String
    public var message: String

    public init(severity: Severity, path: String, message: String) {
        self.severity = severity
        self.path = path
        self.message = message
    }
}

public struct ConfigurationValidator: Sendable {
    public init() {}

    public func validate(_ configuration: Configuration) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        if configuration.profiles.isEmpty {
            issues.append(.init(severity: .error, path: "profiles", message: "At least one profile is required."))
        }

        let ids = configuration.profiles.map(\.id.rawValue)
        if Set(ids).count != ids.count {
            issues.append(.init(severity: .error, path: "profiles", message: "Duplicate profile identifiers."))
        }

        if let active = configuration.activeProfileID, configuration.profile(id: active) == nil {
            issues.append(.init(severity: .error, path: "activeProfileID", message: "Active profile does not exist."))
        }

        for profile in configuration.profiles {
            for rule in profile.rules {
                if rule.hysteresis.releaseOffset < rule.hysteresis.engageOffset {
                    issues.append(.init(
                        severity: .warning,
                        path: "profiles.\(profile.id.rawValue).rules.\(rule.id.rawValue)",
                        message: "releaseOffset is smaller than engageOffset; the rule may flap."
                    ))
                }
                if case let .curve(curve) = rule.output, curve.points.count < 2 {
                    issues.append(.init(
                        severity: .error,
                        path: "profiles.\(profile.id.rawValue).rules.\(rule.id.rawValue).output",
                        message: "A curve needs at least two points."
                    ))
                }
            }
        }

        if configuration.advanced.idleBehavior == .forceZero {
            if configuration.advanced.forceZeroAcknowledgedAt == nil {
                issues.append(.init(
                    severity: .error,
                    path: "advanced.idleBehavior",
                    message: "forceZero requires explicit acknowledgement in Settings > Advanced."
                ))
            }
            issues.append(.init(
                severity: .error,
                path: "advanced.idleBehavior",
                message: "forceZero is not available in v1."
            ))
        }

        if configuration.safety.emergencyCelsius > HardwareGuardrails.emergencyAuto {
            issues.append(.init(
                severity: .warning,
                path: "safety.emergencyCelsius",
                message: "Values above \(HardwareGuardrails.emergencyAuto) are capped by the hardware guardrail."
            ))
        }

        return issues
    }

    public func assertValid(_ configuration: Configuration) throws {
        let errors = validate(configuration).filter { $0.severity == .error }
        guard errors.isEmpty else {
            throw FrostBarError.invalidConfiguration(errors.map(\.message).joined(separator: " "))
        }
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation

/// A machine-readable reason for a decision, surfaced in the UI and in logs.
public struct DecisionReason: Codable, Sendable, Equatable {
    public var ruleID: String?
    public var summary: String
    public var values: [String: Double]

    public init(ruleID: String? = nil, summary: String, values: [String: Double] = [:]) {
        self.ruleID = ruleID
        self.summary = summary
        self.values = values
    }
}

public enum SafetyViolation: String, Codable, Sendable, Equatable {
    case fanStopTooHot
    case emergencyTemperature
    case unsupportedHardware
    case belowAppleMinimumNotAllowed
    case clampRequired
    case commandExpired
    case slewLimited
}

/// Argument-passing state for the evaluator. Kept outside the evaluator so that
/// evaluation is a pure function and can be replayed from a test fixture.
public struct EvaluationState: Sendable, Equatable {
    public var lastCommand: FanCommand?
    public var lastTargetRPM: RPM?
    public var lastChangeAt: Date?
    public var lastWriteAt: Date?
    /// Rule identifier -> moment the rule engaged.
    public var engagedRules: [String: Date]

    public init(
        lastCommand: FanCommand? = nil,
        lastTargetRPM: RPM? = nil,
        lastChangeAt: Date? = nil,
        lastWriteAt: Date? = nil,
        engagedRules: [String: Date] = [:]
    ) {
        self.lastCommand = lastCommand
        self.lastTargetRPM = lastTargetRPM
        self.lastChangeAt = lastChangeAt
        self.lastWriteAt = lastWriteAt
        self.engagedRules = engagedRules
    }

    public static let initial = EvaluationState()
}

public struct EvaluationInput: Sendable {
    public var snapshot: SensorSnapshot
    public var profile: Profile
    public var context: AppContext
    public var capabilities: SystemCapabilities
    public var advanced: AdvancedSettings
    public var state: EvaluationState
    public var now: Date

    public init(
        snapshot: SensorSnapshot,
        profile: Profile,
        context: AppContext,
        capabilities: SystemCapabilities,
        advanced: AdvancedSettings,
        state: EvaluationState,
        now: Date
    ) {
        self.snapshot = snapshot
        self.profile = profile
        self.context = context
        self.capabilities = capabilities
        self.advanced = advanced
        self.state = state
        self.now = now
    }
}

public enum EvaluationResult: Sendable, Equatable {
    case hold
    case apply(FanCommand, DecisionReason)
    case automatic(DecisionReason)
    case refused(SafetyViolation)
}

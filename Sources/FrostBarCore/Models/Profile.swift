// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation

public struct Profile: Codable, Sendable, Identifiable, Equatable {
    public typealias ID = TaggedID<Profile>

    public var id: ID
    public var name: String
    public var symbolName: String
    public var isEnabled: Bool
    /// Applied when no rule matches.
    public var base: FanPolicy
    public var rules: [Rule]

    public init(
        id: ID,
        name: String,
        symbolName: String = "wind",
        isEnabled: Bool = true,
        base: FanPolicy = .automatic,
        rules: [Rule] = []
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.isEnabled = isEnabled
        self.base = base
        self.rules = rules
    }
}

public struct Rule: Codable, Sendable, Identifiable, Equatable {
    public typealias ID = TaggedID<Rule>

    public var id: ID
    public var isEnabled: Bool
    /// Higher wins when several rules match.
    public var priority: Int
    public var condition: Condition
    public var output: FanPolicy
    public var hysteresis: HysteresisPolicy
    public var note: String?

    public init(
        id: ID,
        isEnabled: Bool = true,
        priority: Int = 0,
        condition: Condition,
        output: FanPolicy,
        hysteresis: HysteresisPolicy = HysteresisPolicy(),
        note: String? = nil
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.priority = priority
        self.condition = condition
        self.output = output
        self.hysteresis = hysteresis
        self.note = note
    }
}

/// Hysteresis and smoothing applied around a rule transition.
///
/// `engageOffset` / `releaseOffset` are measured from the rule threshold,
/// `minimumDwell` prevents flapping, `cooldown` limits how often a rule may
/// re-engage, `maxStepRPM` caps the change per tick for this rule and
/// `smoothing` is the EMA alpha applied to the sensor input (1.0 = no smoothing).
public struct HysteresisPolicy: Codable, Sendable, Equatable {
    public var engageOffset: Double
    public var releaseOffset: Double
    public var minimumDwell: TimeInterval
    public var cooldown: TimeInterval
    public var maxStepRPM: Int
    public var smoothing: Double

    public init(
        engageOffset: Double = 2,
        releaseOffset: Double = 4,
        minimumDwell: TimeInterval = 10,
        cooldown: TimeInterval = 15,
        maxStepRPM: Int = HardwareGuardrails.maxSlewRPMps,
        smoothing: Double = 1.0
    ) {
        self.engageOffset = engageOffset
        self.releaseOffset = releaseOffset
        self.minimumDwell = minimumDwell
        self.cooldown = cooldown
        self.maxStepRPM = maxStepRPM
        self.smoothing = smoothing
    }

    public static let `default` = HysteresisPolicy()
}

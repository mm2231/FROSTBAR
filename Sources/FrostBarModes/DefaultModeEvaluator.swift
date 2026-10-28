// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation
import FrostBarCore

/// Default `ModeEvaluating` implementation.
///
/// Pure: no clocks, no hardware, no side effects. The caller supplies state and
/// the current time, which makes the decision replayable from a fixture.
public struct DefaultModeEvaluator: ModeEvaluating {
    private let rules: RuleEvaluator
    private let curves: CurveInterpolator

    public init(rules: RuleEvaluator = RuleEvaluator(), curves: CurveInterpolator = CurveInterpolator()) {
        self.rules = rules
        self.curves = curves
    }

    public func evaluate(_ input: EvaluationInput) -> EvaluationResult {
        guard input.capabilities.canControlFans else {
            return .automatic(DecisionReason(summary: "Fan control is not supported on this Mac."))
        }

        guard input.advanced.idleBehavior != .forceZero else {
            return .automatic(DecisionReason(summary: "forceZero is not available in v1."))
        }

        let selectedRule = rules.bestRule(in: input)
        let policy = selectedRule?.output ?? input.profile.base

        guard let command = command(for: policy, input: input) else {
            return .hold
        }

        let reason = DecisionReason(
            ruleID: selectedRule?.id.rawValue,
            summary: summary(policy: policy, rule: selectedRule, input: input),
            values: [
                "maxTemperature": input.snapshot.maxTemperature?.rawValue ?? 0,
            ]
        )
        return .apply(command, reason)
    }

    private func command(for policy: FanPolicy, input: EvaluationInput) -> FanCommand? {
        switch policy {
        case .automatic:
            return .automatic
        case let .fixed(rpm):
            return .fixed(rpm)
        case let .curve(curve):
            guard let temperature = input.snapshot.maxTemperature else { return .automatic }
            return .fixed(curves.rpm(for: temperature, curve: curve))
        case let .perFan(values):
            return .perFan(values)
        case .unsupported:
            return nil
        }
    }

    private func summary(policy: FanPolicy, rule: Rule?, input: EvaluationInput) -> String {
        let temperature = input.snapshot.maxTemperature.map { String(format: "%.1f °C", $0.rawValue) } ?? "n/a"
        if let rule {
            return "Rule \(rule.id.rawValue) matched at \(temperature)."
        }
        return "Base policy \(policy.kindName) applied at \(temperature)."
    }
}

private extension FanPolicy {
    var kindName: String {
        switch self {
        case .automatic: return "automatic"
        case .fixed: return "fixed"
        case .curve: return "curve"
        case .perFan: return "perFan"
        case .unsupported: return "unsupported"
        }
    }
}

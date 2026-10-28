// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation
import FrostBarCore

/// Renders a decision for logs and for the "why" popover in the UI.
public struct DecisionFormatter: Sendable {
    public init() {}

    public func describe(_ result: EvaluationResult, unit: GeneralSettings.TemperatureUnit = .celsius) -> String {
        switch result {
        case .hold:
            return "Holding the current speed."
        case let .apply(command, reason):
            return "\(describe(command, unit: unit)) — \(reason.summary)"
        case let .automatic(reason):
            return "Apple automatic mode — \(reason.summary)"
        case let .refused(violation):
            return "Refused by the safety policy — \(violation.rawValue)"
        }
    }

    public func describe(_ command: FanCommand, unit: GeneralSettings.TemperatureUnit = .celsius) -> String {
        switch command {
        case .automatic:
            return "Apple automatic"
        case let .fixed(rpm):
            return "\(rpm.rawValue) rpm"
        case let .perFan(values):
            let parts = values.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value.rawValue)" }
            return parts.joined(separator: ", ")
        case let .limits(fan, minimum, maximum):
            return "\(fan.rawValue) limits \(minimum?.rawValue.description ?? "-")...\(maximum?.rawValue.description ?? "-")"
        }
    }
}

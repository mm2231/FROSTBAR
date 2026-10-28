// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import AppKit
import FrostBarCore
import SwiftUI

/// FrostBar's visual language.
///
/// The control panel is a fixed dark instrument surface on purpose: a fan
/// controller is read at a glance from an angle, so contrast and numeric
/// legibility matter more than matching the system appearance. The Settings
/// window stays native and follows the system.
enum Theme {
    // MARK: Colours

    /// Panel background. Slightly blue-shifted black, like cold metal.
    static let ink = Color(red: 0.055, green: 0.078, blue: 0.094)
    /// Raised surface.
    static let steel = Color(red: 0.086, green: 0.114, blue: 0.133)
    /// Primary accent: cold air.
    static let frost = Color(red: 0.624, green: 0.910, blue: 1.0)
    /// Secondary text.
    static let mist = Color(red: 0.60, green: 0.67, blue: 0.71)
    /// Hairlines.
    static let line = Color(red: 0.16, green: 0.21, blue: 0.24)
    static let amber = Color(red: 0.949, green: 0.722, blue: 0.294)
    static let alert = Color(red: 1.0, green: 0.42, blue: 0.37)

    static let nsInk = NSColor(red: 0.055, green: 0.078, blue: 0.094, alpha: 1)

    // MARK: Type

    static let label = Font.system(size: 11, weight: .medium)
    static let caption = Font.system(size: 10, weight: .regular)
    static let numeric = Font.system(size: 34, weight: .semibold).monospacedDigit()
    static let numericSmall = Font.system(size: 15, weight: .medium).monospacedDigit()

    // MARK: Helpers

    static func tint(for temperature: Celsius?) -> Color {
        guard let temperature else { return frost }
        if temperature >= HardwareGuardrails.emergencyAuto {
            return alert
        }
        if temperature >= HardwareGuardrails.forceZeroForcedAuto {
            return amber
        }
        return frost
    }

    static func formatted(_ temperature: Celsius?, unit: GeneralSettings.TemperatureUnit) -> String {
        guard let temperature else { return "—" }
        switch unit {
        case .celsius:
            return String(format: "%.1f°", temperature.rawValue)
        case .fahrenheit:
            return String(format: "%.0f°", temperature.rawValue * 9 / 5 + 32)
        }
    }
}

/// Surface used by every panel section: a quiet fill plus a hairline, no shadow.
struct InstrumentSurface: ViewModifier {
    var padding: CGFloat = 14
    var highlighted: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.steel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(highlighted ? Theme.frost.opacity(0.45) : Theme.line, lineWidth: 1)
            )
    }
}

extension View {
    func instrumentSurface(padding: CGFloat = 14, highlighted: Bool = false) -> some View {
        modifier(InstrumentSurface(padding: padding, highlighted: highlighted))
    }
}

/// Small section heading. Sentence case, generous tracking, no boxes.
struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.label)
            .foregroundColor(Theme.mist)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A read-only numeric readout with a caption underneath.
struct Readout: View {
    let caption: String
    let value: String
    var unit: String?
    var tint: Color = Theme.frost

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(Theme.numericSmall)
                    .foregroundColor(tint)
                if let unit {
                    Text(unit)
                        .font(Theme.caption)
                        .foregroundColor(Theme.mist)
                }
            }
            Text(caption)
                .font(Theme.caption)
                .foregroundColor(Theme.mist)
        }
    }
}

/// Frost-tinted button used for the primary action in a section.
struct FrostButtonStyle: ButtonStyle {
    var prominent: Bool = true

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(prominent ? Theme.frost.opacity(configuration.isPressed ? 0.75 : 1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(prominent ? Color.clear : Theme.line, lineWidth: 1)
            )
            .foregroundColor(prominent ? Theme.ink : Theme.frost)
            .contentShape(Rectangle())
    }
}

/// Segmented preset selector used by the Touch Bar and the control panel.
struct PresetButtonStyle: ButtonStyle {
    var selected: Bool
    var compact: Bool = false

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .font(.system(size: compact ? 11 : 12, weight: .medium))
            .padding(.horizontal, compact ? 9 : 12)
            .padding(.vertical, compact ? 3 : 6)
            .background(
                RoundedRectangle(cornerRadius: compact ? 5 : 7, style: .continuous)
                    .fill(selected ? Theme.frost.opacity(0.16) : Theme.ink.opacity(0.35))
            )
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 5 : 7, style: .continuous)
                    .stroke(selected ? Theme.frost.opacity(0.7) : Theme.line, lineWidth: 1)
            )
            .foregroundColor(selected ? Theme.frost : Theme.mist)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

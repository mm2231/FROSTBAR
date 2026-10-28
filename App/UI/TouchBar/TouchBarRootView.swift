// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import SwiftUI

/// Compact Touch Bar content: live RPM and temperature, the three quickest
/// profile switches, automatic mode, and a way into the full panel.
struct TouchBarRootView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        HStack(spacing: 8) {
            readout(
                value: "\(state.currentFanRPM)",
                unit: "rpm",
                tint: Theme.frost
            )
            readout(
                value: Theme.formatted(
                    state.referenceTemperature,
                    unit: state.configuration.general.temperatureUnit
                ),
                unit: state.referenceSensorShortLabel,
                tint: Theme.tint(for: state.referenceTemperature)
            )

            Rectangle()
                .fill(Theme.line)
                .frame(width: 1, height: 18)
                .padding(.horizontal, 2)

            ForEach(Array(state.configuration.profiles.prefix(3))) { profile in
                Button(profile.name) {
                    state.activate(profile: profile.id)
                }
                .buttonStyle(PresetButtonStyle(
                    selected: state.configuration.activeProfileID == profile.id,
                    compact: true
                ))
            }

            Button {
                state.restoreAutomatic()
            } label: {
                Label("Auto", systemImage: "arrow.uturn.backward")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(PresetButtonStyle(selected: state.fansAreAutomatic, compact: true))

            Spacer(minLength: 0)

            Button {
                AppActions.showControlPanel()
            } label: {
                Image(systemName: "macwindow")
            }
            .buttonStyle(PresetButtonStyle(selected: false, compact: true))
        }
        .padding(.horizontal, 10)
        .frame(width: 620, height: 30)
        .background(Theme.ink)
        .preferredColorScheme(.dark)
        .disabled(!state.canApplySettings)
    }

    private func readout(value: String, unit: String, tint: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value)
                .font(.system(size: 16, weight: .semibold).monospacedDigit())
                .foregroundColor(tint)
            Text(unit)
                .font(.system(size: 9, weight: .regular))
                .foregroundColor(Theme.mist)
        }
        .frame(minWidth: 58, alignment: .leading)
    }
}

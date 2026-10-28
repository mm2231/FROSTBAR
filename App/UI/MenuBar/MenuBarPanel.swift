// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import AppKit
import SwiftUI

/// Compact panel shown from the menu bar.
///
/// Deliberately small: it is the fallback for machines where the Touch Bar UI
/// is unavailable, so it offers presets and a way into the full panel rather
/// than duplicating every control.
struct MenuBarPanel: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            readouts
            presets
            Divider().overlay(Theme.line)
            footer
        }
        .padding(14)
        .frame(width: 300)
        .background(Theme.ink)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 1) {
                Text("FrostBar")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text(state.capabilities.modelIdentifier)
                    .font(Theme.caption)
                    .foregroundColor(Theme.mist)
            }
            Spacer()
            StatusDot(isActive: state.helperStatus.isUsable)
        }
    }

    private var readouts: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 1) {
                Text(state.fanRPMText)
                    .font(Theme.numeric)
                    .foregroundColor(Theme.frost)
                Text("fan speed")
                    .font(Theme.caption)
                    .foregroundColor(Theme.mist)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(Theme.formatted(state.referenceTemperature, unit: state.configuration.general.temperatureUnit))
                    .font(Theme.numeric)
                    .foregroundColor(Theme.tint(for: state.referenceTemperature))
                Text(state.referenceSensorLabel)
                    .font(Theme.caption)
                    .foregroundColor(Theme.mist)
            }
            Spacer()
        }
    }

    private var presets: some View {
        HStack(spacing: 6) {
            ForEach(state.configuration.profiles) { profile in
                Button(profile.name) {
                    state.activate(profile: profile.id)
                }
                .buttonStyle(PresetButtonStyle(
                    selected: state.configuration.activeProfileID == profile.id,
                    compact: true
                ))
            }
            Spacer(minLength: 0)
            Button {
                state.restoreAutomatic()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .buttonStyle(PresetButtonStyle(selected: false, compact: true))
            .help("Return the fans to Apple automatic mode")
        }
        .disabled(!state.isFanControlAvailable)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button("Open panel") {
                AppActions.showControlPanel()
            }
            .buttonStyle(FrostButtonStyle())
            Button("Settings") {
                AppActions.showSettings()
            }
            .buttonStyle(FrostButtonStyle(prominent: false))
            Spacer()
            Button {
                AppActions.quit()
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(FrostButtonStyle(prominent: false))
            .help("Quit FrostBar")
        }
    }
}

struct StatusDot: View {
    let isActive: Bool

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isActive ? Theme.frost : Theme.amber)
                .frame(width: 6, height: 6)
            Text(isActive ? "helper ready" : "helper off")
                .font(Theme.caption)
                .foregroundColor(Theme.mist)
        }
    }
}

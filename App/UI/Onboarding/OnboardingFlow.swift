// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import SwiftUI

/// Three-step setup. Shown inside the control panel until the helper has been
/// installed and the safety model has been read, so it never interrupts the
/// menu bar fallback.
struct OnboardingFlow: View {
    @EnvironmentObject private var state: AppState
    @State private var step = 0

    private let steps = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            progress

            Group {
                switch step {
                case 0: welcome
                case 1: helper
                default: safety
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 12)

            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.easeInOut(duration: 0.2), value: step)
    }

    private var progress: some View {
        HStack(spacing: 5) {
            ForEach(0 ..< steps, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? Theme.frost : Theme.line)
                    .frame(height: 3)
            }
        }
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "wind")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundColor(Theme.frost)

            Text("Fans, on your terms.")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.white)

            Text("FrostBar reads the SMC, applies a curve or a preset, and tells you why it chose a speed. On Touch Bar Macs the controls sit above the keyboard while this panel is open.")
                .font(.callout)
                .foregroundColor(Theme.mist)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                chip("Intel MacBook Pro")
                chip("2016–2019")
                chip("Touch Bar")
            }

            Text("Apple Silicon is supported in monitor-only mode.")
                .font(.caption)
                .foregroundColor(Theme.mist)
        }
    }

    private var helper: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundColor(Theme.frost)

            Text("One helper, one job.")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.white)

            Text("macOS only lets a privileged daemon write to the SMC. FrostBarHelper accepts fan speeds, never raw SMC keys. It clamps every value, enforces a 15-second command lifetime, and hands the fans back to Apple after 10 seconds without a heartbeat.")
                .font(.callout)
                .foregroundColor(Theme.mist)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Circle()
                    .fill(state.helperStatus.isUsable ? Theme.frost : Theme.amber)
                    .frame(width: 7, height: 7)
                Text(state.helperStatusLabel)
                    .font(Theme.caption)
                    .foregroundColor(.white)
            }

            HStack(spacing: 8) {
                switch state.helperStatus {
                case .requiresApproval:
                    Button("Open Login Items") {
                        AppActions.openLoginItemsSettings()
                    }
                    .buttonStyle(FrostButtonStyle())
                case .enabled:
                    Label("Helper installed", systemImage: "checkmark")
                        .font(Theme.caption)
                        .foregroundColor(Theme.frost)
                default:
                    Button("Install helper") {
                        Task { await state.installHelper() }
                    }
                    .buttonStyle(FrostButtonStyle())
                }

                if state.helperStatus != .enabled {
                    Button("Check again") {
                        Task { await state.refreshHelperStatus() }
                    }
                    .buttonStyle(FrostButtonStyle(prominent: false))
                }
            }

            Text("You can finish setup without the helper and install it later from Settings.")
                .font(.caption)
                .foregroundColor(Theme.mist)
        }
    }

    private var safety: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "thermometer.medium")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundColor(Theme.frost)

            Text("The limits are not settings.")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.white)

            Text("Three rules are compiled into both the app and the helper. No profile, imported file or script can weaken them.")
                .font(.callout)
                .foregroundColor(Theme.mist)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                rule("95 °C", "Manual control returns to Apple automatic mode.")
                rule("70 °C", "A future forced fan stop is released.")
                rule("10 s", "Without an app heartbeat, the helper restores automatic mode.")
            }

            Text("Fan control writes to the System Management Controller. Keep the stock cooling path intact; do not block the vents.")
                .font(.caption)
                .foregroundColor(Theme.mist)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            if step > 0 {
                Button("Back") {
                    step -= 1
                }
                .buttonStyle(FrostButtonStyle(prominent: false))
            }

            Spacer()

            if step < steps - 1 {
                Button("Continue") {
                    step += 1
                }
                .buttonStyle(FrostButtonStyle())
            } else {
                Button("Start using FrostBar") {
                    state.completeOnboarding()
                }
                .buttonStyle(FrostButtonStyle())
            }
        }
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(Theme.caption)
            .foregroundColor(Theme.frost)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(Theme.frost.opacity(0.35), lineWidth: 1)
            )
    }

    private func rule(_ number: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(number)
                .font(.system(size: 14, weight: .semibold).monospacedDigit())
                .foregroundColor(Theme.frost)
                .frame(width: 52, alignment: .leading)
            Text(text)
                .font(.callout)
                .foregroundColor(Theme.mist)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

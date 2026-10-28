// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import FrostBarCore
import SwiftUI

/// The full control panel. This is the window the Touch Bar belongs to, so on
/// Touch Bar Macs the same state is editable from two places at once.
struct ControlPanelView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        ZStack {
            Theme.ink.ignoresSafeArea()

            if state.hasCompletedOnboarding {
                panel
            } else {
                OnboardingFlow()
                    .padding(24)
            }
        }
        .frame(minWidth: 380, minHeight: 560)
        .preferredColorScheme(.dark)
    }

    private var panel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                curveCard
                profileRow
                manualCard
                sensorCard
                footer
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("FrostBar")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                Text("\(state.capabilities.modelIdentifier) · \(state.helperStatusLabel)")
                    .font(Theme.caption)
                    .foregroundColor(Theme.mist)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Theme.formatted(state.referenceTemperature, unit: state.configuration.general.temperatureUnit))
                    .font(Theme.numeric)
                    .foregroundColor(Theme.tint(for: state.referenceTemperature))
                Text(state.referenceSensorLabel)
                    .font(Theme.caption)
                    .foregroundColor(Theme.mist)
            }
        }
    }

    // MARK: Curve

    private var curveCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: state.activeProfile?.name ?? "No profile")
                Spacer()
                Text(state.decision)
                    .font(Theme.caption)
                    .foregroundColor(Theme.mist)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 230, alignment: .trailing)
            }

            CurveGraph(
                curve: state.activeCurve,
                temperature: state.referenceTemperature,
                rpm: state.snapshot.fans.first?.currentRPM
            )
            .frame(height: 132)

            HStack(spacing: 18) {
                Readout(caption: "requested", value: state.targetRPMText)
                Readout(caption: "reported", value: state.fanRPMText, tint: .white)
                Spacer()
                if !state.capabilities.canControlFans {
                    Text("monitor only")
                        .font(Theme.caption)
                        .foregroundColor(Theme.amber)
                }
            }
        }
        .instrumentSurface(highlighted: state.isFanControlAvailable)
    }

    // MARK: Profiles

    private var profileRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Profile")
            HStack(spacing: 6) {
                ForEach(state.configuration.profiles) { profile in
                    Button(profile.name) {
                        state.activate(profile: profile.id)
                    }
                    .buttonStyle(PresetButtonStyle(
                        selected: state.configuration.activeProfileID == profile.id
                    ))
                }
                Spacer(minLength: 0)
                Button {
                    state.restoreAutomatic()
                } label: {
                    Label("Auto", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(PresetButtonStyle(selected: state.fansAreAutomatic))
                .help("Hand the fans back to Apple")
            }
            .disabled(!state.canApplySettings)
        }
    }

    // MARK: Manual

    private var manualCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: "Manual speed")
                Spacer()
                Text("\(state.manualRPM) rpm")
                    .font(Theme.numericSmall)
                    .foregroundColor(Theme.frost)
            }

            Slider(
                value: Binding(
                    get: { Double(state.manualRPM) },
                    set: { state.manualRPM = Int($0.rounded()) }
                ),
                in: state.manualRange,
                step: 50
            ) { editing in
                if !editing {
                    state.setManualRPM(RPM(state.manualRPM))
                }
            }
            .tint(Theme.frost)
            .disabled(!state.canApplySettings)

            HStack {
                Text("\(Int(state.manualRange.lowerBound)) min")
                Spacer()
                Text("\(Int(state.manualRange.upperBound)) max")
            }
            .font(Theme.caption)
            .foregroundColor(Theme.mist)
        }
        .instrumentSurface()
    }

    // MARK: Sensors

    private var sensorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Sensors")
            HStack(spacing: 0) {
                Readout(
                    caption: "CPU",
                    value: state.temperatureText(.cpuMax),
                    tint: Theme.tint(for: state.snapshot.temperature(for: .cpuMax))
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                Readout(
                    caption: "GPU",
                    value: state.temperatureText(.gpuMax),
                    tint: Theme.tint(for: state.snapshot.temperature(for: .gpuMax))
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                Readout(
                    caption: "System",
                    value: state.temperatureText(.systemMax),
                    tint: Theme.tint(for: state.snapshot.temperature(for: .systemMax))
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            ForEach(state.snapshot.fans) { fan in
                HStack {
                    Text(fan.name)
                        .font(Theme.caption)
                        .foregroundColor(Theme.mist)
                    Spacer()
                    Text("\(fan.currentRPM.rawValue) rpm")
                        .font(Theme.caption.monospacedDigit())
                        .foregroundColor(.white)
                    Text(fan.mode == .forced ? "manual" : "auto")
                        .font(Theme.caption)
                        .foregroundColor(fan.mode == .forced ? Theme.frost : Theme.mist)
                        .frame(width: 48, alignment: .trailing)
                }
            }

            if state.snapshot.fans.isEmpty {
                Text("No fans were reported. On Apple Silicon FrostBar is monitor-only.")
                    .font(Theme.caption)
                    .foregroundColor(Theme.mist)
            }
        }
        .instrumentSurface()
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 10) {
            if !state.helperStatus.isUsable {
                HelperPrompt()
            }

            HStack(spacing: 8) {
                Button("Settings") {
                    AppActions.showSettings()
                }
                .buttonStyle(FrostButtonStyle(prominent: false))
                Spacer()
                Text("helper 10 s watchdog · 95 °C auto")
                    .font(Theme.caption)
                    .foregroundColor(Theme.mist)
            }
        }
    }
}

/// The memorable element of the panel: the live operating point on the active
/// curve. Everything else stays deliberately quiet around it.
struct CurveGraph: View {
    let curve: FanCurve?
    let temperature: Celsius?
    let rpm: RPM?

    private let domainLow: Double = 30
    private let domainHigh: Double = 100
    private let floorRPM: Double = 0

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let ceiling = Double(max(6000, curve?.normalized().points.map(\.rpm.rawValue).max() ?? 6000))
            let points = (curve?.normalized().points ?? []).map { point in
                CGPoint(
                    x: x(for: point.celsius.rawValue, width: size.width),
                    y: y(for: Double(point.rpm.rawValue), height: size.height, ceiling: ceiling)
                )
            }

            ZStack(alignment: .topLeading) {
                grid(size: size)

                if points.count >= 2 {
                    areaPath(points: points, size: size)
                        .fill(
                            LinearGradient(
                                colors: [Theme.frost.opacity(0.22), Theme.frost.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    linePath(points: points)
                        .stroke(
                            LinearGradient(
                                colors: [Theme.frost.opacity(0.5), Theme.frost],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                        )

                    ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                        Circle()
                            .fill(Theme.ink)
                            .overlay(Circle().stroke(Theme.frost.opacity(0.7), lineWidth: 1.5))
                            .frame(width: 5, height: 5)
                            .position(point)
                    }
                } else {
                    Text("Apple automatic")
                        .font(Theme.caption)
                        .foregroundColor(Theme.mist)
                        .frame(width: size.width, height: size.height)
                }

                if points.count >= 2, let temperature {
                    let marker = CGPoint(
                        x: x(for: temperature.rawValue, width: size.width),
                        y: y(
                            for: Double(rpm?.rawValue ?? curve?.normalized().points.last?.rpm.rawValue ?? 0),
                            height: size.height,
                            ceiling: ceiling
                        )
                    )
                    Rectangle()
                        .fill(Theme.frost.opacity(0.25))
                        .frame(width: 1, height: size.height)
                        .position(x: marker.x, y: size.height / 2)
                    Circle()
                        .fill(Theme.frost)
                        .frame(width: 9, height: 9)
                        .shadow(color: Theme.frost.opacity(0.8), radius: 6)
                        .position(marker)
                        .animation(.easeOut(duration: 0.35), value: temperature.rawValue)
                }

                Text("30°")
                    .font(Theme.caption)
                    .foregroundColor(Theme.mist)
                    .position(x: 16, y: size.height - 8)
                Text("100°")
                    .font(Theme.caption)
                    .foregroundColor(Theme.mist)
                    .position(x: size.width - 20, y: size.height - 8)
                Text("\(Int(ceiling)) rpm")
                    .font(Theme.caption)
                    .foregroundColor(Theme.mist)
                    .position(x: size.width - 32, y: 10)
            }
        }
    }

    private func grid(size: CGSize) -> some View {
        ZStack {
            ForEach(0 ..< 4) { row in
                Rectangle()
                    .fill(Theme.line.opacity(0.6))
                    .frame(height: 1)
                    .position(x: size.width / 2, y: size.height * CGFloat(row) / 3)
            }
        }
    }

    private func linePath(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }

    private func areaPath(points: [CGPoint], size: CGSize) -> Path {
        var path = linePath(points: points)
        guard let first = points.first, let last = points.last else { return path }
        path.addLine(to: CGPoint(x: last.x, y: size.height))
        path.addLine(to: CGPoint(x: first.x, y: size.height))
        path.closeSubpath()
        return path
    }

    private func x(for celsius: Double, width: CGFloat) -> CGFloat {
        let clamped = min(max(celsius, domainLow), domainHigh)
        let ratio = (clamped - domainLow) / (domainHigh - domainLow)
        return CGFloat(ratio) * width
    }

    private func y(for rpm: Double, height: CGFloat, ceiling: Double) -> CGFloat {
        guard ceiling > floorRPM else { return height }
        let clamped = min(max(rpm, floorRPM), ceiling)
        let ratio = (clamped - floorRPM) / (ceiling - floorRPM)
        return height - CGFloat(ratio) * height
    }
}

private struct HelperPrompt: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(state.helperStatus == .requiresApproval
                 ? "Approve FrostBarHelper in System Settings to enable fan control."
                 : "Install the helper to enable fan control.")
                .font(Theme.caption)
                .foregroundColor(Theme.amber)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                if state.helperStatus == .requiresApproval {
                    Button("Open Login Items") {
                        AppActions.openLoginItemsSettings()
                    }
                    .buttonStyle(FrostButtonStyle())
                } else {
                    Button("Install helper") {
                        Task { await state.installHelper() }
                    }
                    .buttonStyle(FrostButtonStyle())
                }
                Button("Check again") {
                    Task { await state.refreshHelperStatus() }
                }
                .buttonStyle(FrostButtonStyle(prominent: false))
            }
        }
        .instrumentSurface(padding: 10)
    }
}

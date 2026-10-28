// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import AppKit
import FrostBarCore
import SwiftUI

// MARK: - Profiles

struct ProfilesSettingsTab: View {
    @EnvironmentObject private var state: AppState
    @State private var selection: Profile.ID?

    private var selectedProfile: Profile? {
        guard let selection else { return state.configuration.profiles.first }
        return state.configuration.profile(id: selection)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Profiles")
                    .font(.headline)

                List(selection: $selection) {
                    ForEach(state.configuration.profiles) { profile in
                        HStack(spacing: 6) {
                            Image(systemName: profile.symbolName)
                                .foregroundColor(.secondary)
                            Text(profile.name)
                            Spacer()
                            if state.configuration.activeProfileID == profile.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .tag(profile.id)
                    }
                }
                .frame(height: 290)

                HStack(spacing: 6) {
                    Button {
                        duplicateSelected()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help("Duplicate the selected profile")

                    Button {
                        deleteSelected()
                    } label: {
                        Image(systemName: "minus")
                    }
                    .disabled(state.configuration.profiles.count <= 1)
                    .help("Delete the selected profile")

                    Spacer()
                }
            }
            .frame(width: 210)

            Divider()

            if let profile = selectedProfile {
                editor(for: profile)
            } else {
                Text("Select a profile")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if selection == nil {
                selection = state.configuration.activeProfileID ?? state.configuration.profiles.first?.id
            }
        }
    }

    private func editor(for profile: Profile) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                TextField("Name", text: Binding(
                    get: { state.configuration.profile(id: profile.id)?.name ?? "" },
                    set: { newValue in
                        state.mutateConfiguration { configuration in
                            guard let index = configuration.profiles.firstIndex(where: { $0.id == profile.id }) else { return }
                            configuration.profiles[index].name = newValue
                        }
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.title3)

                Toggle("Enabled", isOn: Binding(
                    get: { state.configuration.profile(id: profile.id)?.isEnabled ?? false },
                    set: { newValue in
                        state.mutateConfiguration { configuration in
                            guard let index = configuration.profiles.firstIndex(where: { $0.id == profile.id }) else { return }
                            configuration.profiles[index].isEnabled = newValue
                        }
                    }
                ))
                .toggleStyle(.switch)

                SettingsRow(title: "Base policy", subtitle: describe(profile.base)) {
                    Button(state.configuration.activeProfileID == profile.id ? "Active" : "Make active") {
                        state.activate(profile: profile.id)
                    }
                    .disabled(state.configuration.activeProfileID == profile.id)
                }

                Divider()

                Text("Rules")
                    .font(.headline)
                Text("Higher priority wins. Hysteresis decides when a rule releases again.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if profile.rules.isEmpty {
                    Text("This profile has no rules; its base policy is applied.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(profile.rules.sorted { $0.priority > $1.priority }) { rule in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(rule.id.rawValue)
                                    .font(.callout.weight(.medium))
                                Spacer()
                                Text("priority \(rule.priority)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text("\(describe(rule.condition)) → \(describe(rule.output))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.08)))
                    }
                }

                Text("Rule curves, hysteresis offsets and per-fan values are preserved in the exported JSON. A full graphical editor lands with the profile editor milestone.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 2)
        }
    }

    private func duplicateSelected() {
        guard let profile = selectedProfile else { return }
        let suffix = Int(Date().timeIntervalSince1970)
        var copy = profile
        copy.id = Profile.ID("\(profile.id.rawValue)-copy-\(suffix)")
        copy.name = "\(profile.name) copy"
        state.mutateConfiguration { $0.profiles.append(copy) }
        selection = copy.id
    }

    private func deleteSelected() {
        guard let profile = selectedProfile, state.configuration.profiles.count > 1 else { return }
        state.mutateConfiguration { configuration in
            configuration.profiles.removeAll { $0.id == profile.id }
            configuration.triggers.removeAll { $0.profileID == profile.id }
            if configuration.activeProfileID == profile.id {
                configuration.activeProfileID = configuration.profiles.first?.id
            }
        }
        selection = state.configuration.profiles.first?.id
    }

    private func describe(_ policy: FanPolicy) -> String {
        switch policy {
        case .automatic: return "Apple automatic"
        case let .fixed(rpm): return "fixed \(rpm.rawValue) rpm"
        case let .curve(curve): return "curve, \(curve.points.count) points"
        case let .perFan(values): return "per fan, \(values.count) values"
        case let .unsupported(kind): return "unsupported (\(kind))"
        }
    }

    private func describe(_ condition: Condition) -> String {
        switch condition {
        case .any: return "always"
        case let .sensorAbove(sensor, value): return "\(sensor.rawValue) > \(Int(value.rawValue)) °C"
        case let .sensorBelow(sensor, value): return "\(sensor.rawValue) < \(Int(value.rawValue)) °C"
        case let .all(conditions): return "all of (\(conditions.map(describe).joined(separator: ", ")))"
        case let .anyOf(conditions): return "any of (\(conditions.map(describe).joined(separator: ", ")))"
        case let .appRunning(bundleIDs): return "\(bundleIDs.joined(separator: ", ")) running"
        case .onBattery: return "on battery"
        case let .thermalPressure(pressure): return "thermal pressure ≥ \(pressure.rawValue)"
        case let .unsupported(kind): return "unsupported (\(kind))"
        }
    }
}

// MARK: - App triggers

struct TriggersSettingsTab: View {
    @EnvironmentObject private var state: AppState
    @State private var newBundleID = ""
    @State private var newProfileID: Profile.ID?
    @State private var runningApps: [(name: String, bundleID: String)] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Apps")
                .font(.headline)
            Text("Switch profiles automatically while an app is frontmost or running. The frontmost match wins, then the highest priority.")
                .font(.callout)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(state.configuration.triggers) { trigger in
                        triggerRow(trigger)
                    }
                    if state.configuration.triggers.isEmpty {
                        Text("No app triggers yet.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 20)
                    }
                }
            }

            Divider()

            HStack(spacing: 8) {
                TextField("com.example.app", text: $newBundleID)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)

                Picker("", selection: profileSelection) {
                    ForEach(state.configuration.profiles) { profile in
                        Text(profile.name).tag(Optional(profile.id))
                    }
                }
                .labelsHidden()
                .frame(width: 130)

                Button("Add") {
                    addTrigger()
                }
                .disabled(newBundleID.isEmpty || newProfileID == nil)

                Menu("Add running app") {
                    ForEach(runningApps, id: \.bundleID) { app in
                        Button(app.name) {
                            newBundleID = app.bundleID
                        }
                    }
                }
            }
        }
        .onAppear {
            newProfileID = newProfileID ?? state.configuration.profiles.first?.id
            loadRunningApps()
        }
    }

    private var profileSelection: Binding<Profile.ID?> {
        Binding(
            get: { newProfileID ?? state.configuration.profiles.first?.id },
            set: { newProfileID = $0 }
        )
    }

    private func triggerRow(_ trigger: AppTrigger) -> some View {
        HStack(spacing: 8) {
            Text(trigger.bundleID)
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 200, alignment: .leading)

            Picker("", selection: Binding(
                get: { trigger.profileID },
                set: { newValue in
                    state.mutateConfiguration { configuration in
                        guard let index = configuration.triggers.firstIndex(where: { $0.id == trigger.id }) else { return }
                        configuration.triggers[index].profileID = newValue
                    }
                }
            )) {
                ForEach(state.configuration.profiles) { profile in
                    Text(profile.name).tag(profile.id)
                }
            }
            .labelsHidden()
            .frame(width: 130)

            Toggle("", isOn: Binding(
                get: { trigger.isEnabled },
                set: { newValue in
                    state.mutateConfiguration { configuration in
                        guard let index = configuration.triggers.firstIndex(where: { $0.id == trigger.id }) else { return }
                        configuration.triggers[index].isEnabled = newValue
                    }
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)

            Spacer()

            Button {
                state.mutateConfiguration { $0.triggers.removeAll { $0.id == trigger.id } }
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }

    private func addTrigger() {
        guard !newBundleID.isEmpty, let profileID = newProfileID else { return }
        let trigger = AppTrigger(bundleID: newBundleID, profileID: profileID)
        state.mutateConfiguration { configuration in
            configuration.triggers.removeAll { $0.id == trigger.id }
            configuration.triggers.append(trigger)
        }
        newBundleID = ""
    }

    private func loadRunningApps() {
        runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app in
                guard let bundleID = app.bundleIdentifier, bundleID != Bundle.main.bundleIdentifier else { return nil }
                return (app.localizedName ?? bundleID, bundleID)
            }
            .sorted { $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending }
    }
}

// MARK: - Safety

struct SafetySettingsTab: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsSection(title: "Manual control") {
                    SettingsRow(
                        title: "Emergency handoff",
                        subtitle: "At or above this temperature the fans return to Apple automatic mode, whatever the profile says."
                    ) {
                        Picker("", selection: Binding(
                            get: { state.configuration.safety.emergencyCelsius.rawValue },
                            set: { value in
                                state.mutateConfiguration { $0.safety.emergencyCelsius = Celsius(value) }
                            }
                        )) {
                            ForEach(Array(stride(from: 80.0, through: 95.0, by: 5.0)), id: \.self) { value in
                                Text("\(Int(value)) °C").tag(value)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 90)
                    }

                    SettingsRow(
                        title: "Maximum change per second",
                        subtitle: "Limits how fast the requested speed may move. Capped at the compiled guardrail."
                    ) {
                        Picker("", selection: Binding(
                            get: { state.configuration.safety.maxSlewRPMps },
                            set: { value in
                                state.mutateConfiguration { $0.safety.maxSlewRPMps = value }
                            }
                        )) {
                            Text("400 rpm/s").tag(400)
                            Text("600 rpm/s").tag(600)
                            Text("800 rpm/s").tag(800)
                        }
                        .labelsHidden()
                        .frame(width: 120)
                    }

                    SettingsRow(
                        title: "Release on sleep",
                        subtitle: "Hand the fans back to Apple when the Mac sleeps."
                    ) {
                        Toggle("", isOn: Binding(
                            get: { state.configuration.safety.restoreAutomaticOnSleep },
                            set: { value in
                                state.mutateConfiguration { $0.safety.restoreAutomaticOnSleep = value }
                            }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }
                }

                SettingsSection(title: "Compiled guardrails") {
                    Text("These limits are constants in the binary. They cannot be changed here, in the JSON configuration, or by a profile.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    GuardrailRow(label: "Fan stop refused at", value: "≥ 50 °C")
                    GuardrailRow(label: "Fan stop released at", value: "≥ 70 °C")
                    GuardrailRow(label: "Automatic mode at", value: "≥ 95 °C")
                    GuardrailRow(label: "Maximum slew", value: "800 rpm/s")
                    GuardrailRow(label: "Helper watchdog", value: "10 s")
                }
            }
        }
    }
}

private struct GuardrailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundColor(.secondary)
        }
        .font(.callout)
    }
}

// MARK: - Advanced

struct AdvancedSettingsTab: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsSection(title: "Fan stop") {
                    SettingsRow(
                        title: "Force fans to zero",
                        subtitle: "Deferred to v1.1. It requires per-model verification, a separate acknowledgement and a 70 °C forced handoff."
                    ) {
                        Toggle("", isOn: .constant(false))
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .disabled(true)
                    }

                    SettingsRow(
                        title: "Current idle behaviour",
                        subtitle: "Releasing the override (F0Md = 0) is the only stop behaviour in v1."
                    ) {
                        Text(state.configuration.advanced.idleBehavior == .off ? "Hand back to Apple" : "Force zero")
                            .foregroundColor(.secondary)
                    }

                    SettingsRow(
                        title: "Allow below Apple minimum",
                        subtitle: "Not available: writing under F0Mn can stall a fan that Apple expects to keep spinning."
                    ) {
                        Toggle("", isOn: .constant(false))
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .disabled(true)
                    }
                }

                SettingsSection(title: "Hardware") {
                    GuardrailRow(label: "Model", value: state.capabilities.modelIdentifier)
                    GuardrailRow(label: "Architecture", value: state.capabilities.architecture.rawValue)
                    GuardrailRow(label: "Touch Bar model", value: state.capabilities.isTouchBarModel ? "yes" : "no")
                    GuardrailRow(label: "Fans", value: "\(state.capabilities.fanCount)")
                    GuardrailRow(label: "Sensor transport", value: state.capabilities.sensorTransport.rawValue)
                }

                SettingsSection(title: "Helper") {
                    SettingsRow(title: "Status", subtitle: state.helperStatusLabel) {
                        HStack(spacing: 8) {
                            Button("Install") {
                                Task { await state.installHelper() }
                            }
                            Button("Uninstall") {
                                Task { await state.uninstallHelper() }
                            }
                        }
                    }
                    Text("Uninstalling removes the launchd registration. Fans return to Apple automatic mode.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

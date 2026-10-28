// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import AppKit
import FrostBarCore
import SwiftUI
import UniformTypeIdentifiers

/// Native Settings window. It follows the system appearance; only the control
/// panel and the Touch Bar use the fixed instrument palette.
struct SettingsWindow: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gearshape") }
            ProfilesSettingsTab()
                .tabItem { Label("Profiles", systemImage: "slider.horizontal.3") }
            TriggersSettingsTab()
                .tabItem { Label("Apps", systemImage: "app.badge") }
            SafetySettingsTab()
                .tabItem { Label("Safety", systemImage: "checkmark.shield") }
            AdvancedSettingsTab()
                .tabItem { Label("Advanced", systemImage: "wrench.and.screwdriver") }
            AboutSettingsTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .padding(16)
        .frame(width: 600, height: 470)
    }
}

// MARK: - General

struct GeneralSettingsTab: View {
    @EnvironmentObject private var state: AppState
    @State private var errorMessage: String?
    @State private var showResetConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsSection(title: "Startup") {
                    SettingsRow(
                        title: "Launch at login",
                        subtitle: "FrostBar starts in the menu bar and reconnects to the helper."
                    ) {
                        Toggle("", isOn: Binding(
                            get: { state.configuration.general.launchAtLogin },
                            set: { state.setLaunchAtLogin($0) }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }

                    SettingsRow(
                        title: "Show Dock icon",
                        subtitle: "Turn this off for a menu-bar-only app."
                    ) {
                        Toggle("", isOn: Binding(
                            get: { state.configuration.general.showDockIcon },
                            set: { value in
                                state.mutateConfiguration { $0.general.showDockIcon = value }
                                AppActions.setDockIconVisible(value)
                            }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }
                }

                SettingsSection(title: "Sampling") {
                    SettingsRow(
                        title: "Update interval",
                        subtitle: "How often sensors are read and the profile is evaluated."
                    ) {
                        Picker("", selection: Binding(
                            get: { state.configuration.general.sampleInterval },
                            set: { value in
                                state.mutateConfiguration { $0.general.sampleInterval = value }
                            }
                        )) {
                            Text("0.5 s").tag(0.5)
                            Text("1 s").tag(1.0)
                            Text("2 s").tag(2.0)
                            Text("5 s").tag(5.0)
                        }
                        .labelsHidden()
                        .frame(width: 100)
                    }

                    SettingsRow(title: "Temperature unit") {
                        Picker("", selection: Binding(
                            get: { state.configuration.general.temperatureUnit },
                            set: { value in
                                state.mutateConfiguration { $0.general.temperatureUnit = value }
                            }
                        )) {
                            Text("Celsius").tag(GeneralSettings.TemperatureUnit.celsius)
                            Text("Fahrenheit").tag(GeneralSettings.TemperatureUnit.fahrenheit)
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                    }
                }

                SettingsSection(title: "Configuration") {
                    Text("Profiles, rules, hysteresis, app triggers and safety preferences are stored as one JSON document. Export it to back up your setup or move it to another Mac.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Button("Export…") { exportConfiguration() }
                        Button("Import…") { importConfiguration() }
                        Spacer()
                        Button("Reset all settings") { showResetConfirmation = true }
                    }

                    Button("Show configuration in Finder") {
                        Task {
                            let url = await state.configurationLocation()
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }
                    }
                    .buttonStyle(.link)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                SettingsSection(title: "Setup") {
                    SettingsRow(
                        title: "Onboarding",
                        subtitle: "Re-run the helper installation and safety walkthrough."
                    ) {
                        Button("Run setup again") { state.restartOnboarding() }
                    }
                }
            }
        }
        .alert("Reset all settings?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { state.resetConfiguration() }
        } message: {
            Text("Profiles, rules and triggers return to the built-in defaults. This cannot be undone.")
        }
    }

    private func exportConfiguration() {
        do {
            let data = try state.exportArchive()
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.json]
            panel.nameFieldStringValue = "FrostBar-Configuration.json"
            panel.canCreateDirectories = true
            guard panel.runModal() == .OK, let url = panel.url else { return }
            try data.write(to: url, options: .atomic)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func importConfiguration() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            let alert = NSAlert()
            alert.messageText = "Import configuration"
            alert.informativeText = "Replace your current settings with the file, or merge its profiles into the ones you already have?"
            alert.addButton(withTitle: "Replace")
            alert.addButton(withTitle: "Merge")
            alert.addButton(withTitle: "Cancel")

            switch alert.runModal() {
            case .alertFirstButtonReturn:
                Task { await state.importArchive(data, strategy: .replace) }
            case .alertSecondButtonReturn:
                Task { await state.importArchive(data, strategy: .mergeByID) }
            default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - About

struct AboutSettingsTab: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image(systemName: "wind")
                    .font(.system(size: 34, weight: .light))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("FrostBar")
                        .font(.title2.weight(.semibold))
                    Text("Version \(Self.appVersion)")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            Text("Fan control for Intel MacBook Pro with Touch Bar. Apple Silicon Macs are monitor-only.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Updates")
                    .font(.headline)
                HStack {
                    Text(updateDescription)
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Check now") {
                        Task { await state.checkForUpdates() }
                    }
                    .disabled(state.updateState == .checking)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Link("Project page", destination: URL(string: "https://github.com/mm2231/FROSTBAR")!)
                Link("Report a security issue", destination: URL(string: "https://github.com/mm2231/FROSTBAR/security/advisories/new")!)
                Text("GPL-3.0-or-later. Includes SMCKit (MIT) and Sparkle (MIT); see NOTICE.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(4)
    }

    private var updateDescription: String {
        switch state.updateState {
        case .idle: return "Not checked yet."
        case .checking: return "Checking…"
        case .upToDate: return "You are up to date."
        case let .available(version): return "Version \(version) is available."
        case let .downloading(progress): return "Downloading \(Int(progress * 100))%…"
        case let .readyToInstall(version): return "Version \(version) is ready to install."
        case let .failed(message): return "Update failed: \(message)"
        }
    }

    static var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(short) (\(build))"
    }
}

// MARK: - Building blocks

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsRow<Control: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var control: () -> Control

    init(title: String, subtitle: String? = nil, @ViewBuilder control: @escaping () -> Control) {
        self.title = title
        self.subtitle = subtitle
        self.control = control
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            control()
        }
    }
}

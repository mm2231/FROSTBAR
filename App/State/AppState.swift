// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation
import FrostBarCore
import FrostBarModes
import FrostBarProfiles

/// Presentation-facing state.
///
/// Views observe this object and call its methods; they never talk to SMC, XPC
/// or the file system directly. All collaborators arrive through
/// `AppEnvironment` (constructor injection in `CompositionRoot`).
@MainActor
final class AppState: ObservableObject {
    @Published private(set) var snapshot: SensorSnapshot = .empty
    @Published private(set) var capabilities: SystemCapabilities = .unknown
    @Published private(set) var configuration: Configuration = .default
    @Published private(set) var helperStatus: HelperStatus = .unknown
    @Published private(set) var decision: String = "Starting…"
    @Published private(set) var updateState: UpdateState = .idle
    @Published private(set) var lastError: String?
    @Published private(set) var lastCommand: FanCommand?
    @Published private(set) var hasCompletedOnboarding: Bool
    @Published var isControlPanelVisible = false
    /// Slider value. Applied only when the user releases the handle.
    @Published var manualRPM: Int = 2000

    private let environment: AppEnvironment
    private let controlLoop: ControlLoop
    private let flags: UserDefaultsFlags
    private var tickTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    /// Set while the user has pinned a speed from the slider. The profile is not
    /// evaluated during this time, but sensors are still read so the emergency
    /// handoff works exactly as it does for a curve.
    private var manualCommand: FanCommand?

    init(environment: AppEnvironment, flags: UserDefaultsFlags = UserDefaultsFlags()) {
        self.environment = environment
        self.flags = flags
        self.hasCompletedOnboarding = flags.hasCompletedOnboarding
        self.controlLoop = ControlLoop(
            sensors: environment.sensors,
            fans: environment.fans,
            evaluator: environment.evaluator,
            log: environment.log
        )
    }

    // MARK: Lifecycle

    func start() async {
        helperStatus = await environment.helper.status()
        configuration = (try? await environment.store.load()) ?? .default
        capabilities = (try? await environment.sensors.capabilities()) ?? .unknown
        updateState = await environment.updates.state
        clampManualRPM()
        startTicking()
    }

    func shutdown() async {
        tickTask?.cancel()
        tickTask = nil
        saveTask?.cancel()
        if let saveTask {
            await saveTask.value
        }
        // Never leave the fans in manual mode when the app terminates. The
        // helper watchdog is the backstop if this does not complete in time.
        await restoreAutomaticNow()
    }

    private func startTicking() {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.tick()
                let interval = max(0.25, self.configuration.general.sampleInterval)
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    private func tick() async {
        let context = await environment.triggers.context()

        if let manualCommand {
            await tickManual(manualCommand)
            return
        }

        let result = await controlLoop.tick(
            configuration: configuration,
            context: context,
            capabilities: capabilities,
            now: environment.time.now
        )

        switch result {
        case let .apply(command, _):
            lastCommand = command
        case .automatic:
            lastCommand = .automatic
        case .hold, .refused:
            break
        }

        decision = DecisionFormatter().describe(result, unit: configuration.general.temperatureUnit)

        // The loop returns the snapshot it evaluated, so the UI does not read
        // the SMC a second time per tick.
        if let fresh = await controlLoop.currentSnapshot() {
            snapshot = fresh
            clampManualRPM()
        }
    }

    /// Manual mode still evaluates the safety rules; it just does not consult
    /// the active profile. The helper is holding the speed, so no write is
    /// needed unless the emergency limit is crossed.
    private func tickManual(_ command: FanCommand) async {
        do {
            let fresh = try await environment.sensors.snapshot()
            snapshot = fresh
            clampManualRPM()

            if let maximum = fresh.maxTemperature, maximum >= HardwareGuardrails.emergencyAuto {
                manualCommand = nil
                lastError = "Emergency handoff at \(Int(maximum.rawValue)) °C. Fans returned to Apple automatic mode."
                await restoreAutomaticNow()
                return
            }

            decision = "Manual \(DecisionFormatter().describe(command))"
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: Actions

    func refreshHelperStatus() async {
        helperStatus = await environment.helper.status()
    }

    func installHelper() async {
        do {
            try await environment.helper.install()
            await refreshHelperStatus()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func uninstallHelper() async {
        do {
            try await environment.helper.uninstall()
            await refreshHelperStatus()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func activate(profile id: Profile.ID) {
        configuration.activeProfileID = id
        flags.lastSelectedProfile = id.rawValue
        manualCommand = nil
        Task { await controlLoop.setManualOverride(nil) }
        scheduleSave()
    }

    func setManualRPM(_ rpm: RPM) {
        let input = EvaluationInput(
            snapshot: snapshot,
            profile: activeProfile ?? Profile(id: "manual", name: "Manual"),
            context: .empty,
            capabilities: capabilities,
            advanced: configuration.advanced,
            state: EvaluationState(lastTargetRPM: snapshot.fans.first?.currentRPM),
            now: environment.time.now
        )

        switch FanSafetyPolicy().review(.fixed(rpm), input: input) {
        case let .allow(command), let .clamped(command, _):
            manualCommand = command
            Task { await applyManual(command) }
        case let .forceAutomatic(violation):
            manualCommand = nil
            lastError = "Safety override (\(violation.rawValue)). Returning the fans to Apple automatic mode."
            restoreAutomatic()
        }
    }

    private func applyManual(_ command: FanCommand) async {
        do {
            try await environment.fans.apply(command)
            lastCommand = command
            decision = "Manual \(DecisionFormatter().describe(command))"
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func restoreAutomatic() {
        Task { await restoreAutomaticNow() }
    }

    private func restoreAutomaticNow() async {
        manualCommand = nil
        do {
            try await environment.fans.restoreAutomatic()
            lastCommand = .automatic
            decision = "Apple automatic mode"
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Mutates the persisted configuration and saves it with a short debounce,
    /// so dragging a slider does not rewrite the file on every tick.
    func mutateConfiguration(_ mutate: (inout Configuration) -> Void) {
        var copy = configuration
        mutate(&copy)
        configuration = copy
        scheduleSave()
    }

    func resetConfiguration() {
        configuration = .default
        flags.lastSelectedProfile = nil
        scheduleSave()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LoginItemService.setEnabled(enabled)
            mutateConfiguration { $0.general.launchAtLogin = enabled }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func completeOnboarding() {
        flags.hasCompletedOnboarding = true
        hasCompletedOnboarding = true
    }

    func restartOnboarding() {
        flags.hasCompletedOnboarding = false
        hasCompletedOnboarding = false
    }

    func checkForUpdates() async {
        await environment.updates.checkForUpdates(userInitiated: true)
        updateState = await environment.updates.state
    }

    func clearError() {
        lastError = nil
    }

    // MARK: Configuration import/export

    func exportArchive() throws -> Data {
        try environment.store.export(configuration)
    }

    func importArchive(_ data: Data, strategy: ImportMergeStrategy) async {
        do {
            configuration = try await environment.store.importArchive(data, strategy: strategy)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func configurationLocation() async -> URL {
        await environment.store.location()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        let pending = configuration
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled, let self else { return }
            do {
                try await self.environment.store.save(pending)
            } catch {
                self.lastError = error.localizedDescription
            }
        }
    }

    // MARK: Derived values

    var activeProfile: Profile? {
        configuration.activeProfile
    }

    var activeCurve: FanCurve? {
        guard case let .curve(curve) = activeProfile?.base else { return nil }
        return curve
    }

    var isFanControlAvailable: Bool {
        capabilities.canControlFans && helperStatus.isUsable
    }

    /// Profiles can be selected while monitoring, but writes need the helper.
    var canApplySettings: Bool { isFanControlAvailable }

    var fansAreAutomatic: Bool {
        lastCommand == nil || lastCommand == .automatic
    }

    /// Menu bar text: fan speed plus the hottest sensor, compact enough not to
    /// crowd the status items.
    var menuBarTitle: String {
        guard let fan = snapshot.fans.first else { return "—" }
        guard let temperature = snapshot.maxTemperature else { return "\(fan.currentRPM.rawValue)" }
        return "\(fan.currentRPM.rawValue) · \(Theme.formatted(temperature, unit: configuration.general.temperatureUnit))"
    }

    var referenceTemperature: Celsius? {
        snapshot.temperature(for: .cpuMax) ?? snapshot.maxTemperature
    }

    var referenceSensorLabel: String {
        snapshot.temperature(for: .cpuMax) != nil ? "CPU max" : "peak sensor"
    }

    var referenceSensorShortLabel: String {
        snapshot.temperature(for: .cpuMax) != nil ? "cpu" : "max"
    }

    var currentFanRPM: Int {
        snapshot.fans.first?.currentRPM.rawValue ?? 0
    }

    var fanRPMText: String {
        guard let fan = snapshot.fans.first else { return "—" }
        return "\(fan.currentRPM.rawValue)"
    }

    var targetRPMText: String {
        switch lastCommand {
        case let .fixed(rpm):
            return "\(rpm.rawValue)"
        case let .perFan(values):
            return values.values.first.map { "\($0.rawValue)" } ?? "—"
        case .automatic, .limits, .none:
            return "auto"
        }
    }

    var manualRange: ClosedRange<Double> {
        guard let fan = snapshot.fans.first else { return 1300 ... 6000 }
        let lower = Double(max(fan.minRPM.rawValue, 0))
        let upper = Double(max(fan.maxRPM.rawValue, Int(lower) + 1))
        return lower ... min(upper, Double(HardwareGuardrails.absoluteMaxRPM.rawValue))
    }

    var helperStatusLabel: String {
        switch helperStatus {
        case .enabled: return "helper ready"
        case .requiresApproval: return "helper needs approval"
        case .notRegistered: return "helper not installed"
        case .notReachable: return "helper unreachable"
        case .unknown: return "helper unknown"
        }
    }

    func temperatureText(_ sensor: SensorID) -> String {
        guard let value = snapshot.temperature(for: sensor) else { return "—" }
        return Theme.formatted(value, unit: configuration.general.temperatureUnit)
    }

    private func clampManualRPM() {
        let range = manualRange
        let clamped = min(max(Double(manualRPM), range.lowerBound), range.upperBound)
        manualRPM = Int(clamped.rounded())
    }
}

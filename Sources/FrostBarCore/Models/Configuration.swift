// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation

/// Root of the persisted configuration.
///
/// `schemaVersion` is part of the file. Migrations are applied by
/// `FrostBarProfiles.ConfigurationMigrator`; unknown fields are preserved by the
/// lossless decoding of individual models.
public struct Configuration: Codable, Sendable, Equatable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var activeProfileID: Profile.ID?
    public var profiles: [Profile]
    public var triggers: [AppTrigger]
    public var safety: SafetySettings
    public var advanced: AdvancedSettings
    public var general: GeneralSettings

    public init(
        schemaVersion: Int = Configuration.currentSchemaVersion,
        activeProfileID: Profile.ID? = nil,
        profiles: [Profile] = [],
        triggers: [AppTrigger] = [],
        safety: SafetySettings = SafetySettings(),
        advanced: AdvancedSettings = AdvancedSettings(),
        general: GeneralSettings = GeneralSettings()
    ) {
        self.schemaVersion = schemaVersion
        self.activeProfileID = activeProfileID
        self.profiles = profiles
        self.triggers = triggers
        self.safety = safety
        self.advanced = advanced
        self.general = general
    }

    public static var `default`: Configuration {
        let balanced = Profile(
            id: "balanced",
            name: "Balanced",
            symbolName: "wind",
            base: .curve(.balanced),
            rules: [
                Rule(
                    id: "cpu-warm",
                    priority: 100,
                    condition: .sensorAbove(.cpuMax, Celsius(78)),
                    output: .fixed(RPM(4200)),
                    hysteresis: HysteresisPolicy(engageOffset: 3, releaseOffset: 5)
                ),
            ]
        )
        let quiet = Profile(
            id: "quiet",
            name: "Quiet",
            symbolName: "speaker.slash",
            base: .curve(.quiet)
        )
        return Configuration(activeProfileID: balanced.id, profiles: [balanced, quiet])
    }

    public func profile(id: Profile.ID) -> Profile? {
        profiles.first { $0.id == id }
    }

    public var activeProfile: Profile? {
        guard let id = activeProfileID else { return profiles.first }
        return profile(id: id) ?? profiles.first
    }
}

/// User-facing safety preferences. Values are validated against
/// `HardwareGuardrails`; the guardrails always win.
public struct SafetySettings: Codable, Sendable, Equatable {
    public var emergencyCelsius: Celsius
    public var emergencyHoldSeconds: TimeInterval
    public var maxSlewRPMps: Int
    public var restoreAutomaticOnSleep: Bool

    public init(
        emergencyCelsius: Celsius = HardwareGuardrails.emergencyAuto,
        emergencyHoldSeconds: TimeInterval = 60,
        maxSlewRPMps: Int = HardwareGuardrails.maxSlewRPMps,
        restoreAutomaticOnSleep: Bool = true
    ) {
        self.emergencyCelsius = emergencyCelsius
        self.emergencyHoldSeconds = emergencyHoldSeconds
        self.maxSlewRPMps = maxSlewRPMps
        self.restoreAutomaticOnSleep = restoreAutomaticOnSleep
    }
}

/// Experimental behaviour, still gated.
public struct AdvancedSettings: Codable, Sendable, Equatable {
    public var idleBehavior: FanIdleBehavior
    /// Reserved for v1.1 so enabling `forceZero` does not require a schema bump.
    public var forceZeroAcknowledgedAt: Date?
    public var allowBelowAppleMinimum: Bool

    public init(
        idleBehavior: FanIdleBehavior = .off,
        forceZeroAcknowledgedAt: Date? = nil,
        allowBelowAppleMinimum: Bool = false
    ) {
        self.idleBehavior = idleBehavior
        self.forceZeroAcknowledgedAt = forceZeroAcknowledgedAt
        self.allowBelowAppleMinimum = allowBelowAppleMinimum
    }
}

public struct GeneralSettings: Codable, Sendable, Equatable {
    public enum TemperatureUnit: String, Codable, Sendable {
        case celsius
        case fahrenheit
    }

    public var launchAtLogin: Bool
    public var sampleInterval: TimeInterval
    public var temperatureUnit: TemperatureUnit
    public var showDockIcon: Bool
    public var checkForUpdatesAutomatically: Bool

    public init(
        launchAtLogin: Bool = false,
        sampleInterval: TimeInterval = 1.0,
        temperatureUnit: TemperatureUnit = .celsius,
        showDockIcon: Bool = true,
        checkForUpdatesAutomatically: Bool = true
    ) {
        self.launchAtLogin = launchAtLogin
        self.sampleInterval = sampleInterval
        self.temperatureUnit = temperatureUnit
        self.showDockIcon = showDockIcon
        self.checkForUpdatesAutomatically = checkForUpdatesAutomatically
    }
}

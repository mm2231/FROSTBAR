// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation

/// Small, typed wrapper over `UserDefaults`.
///
/// UserDefaults holds only UI flags and the last selection. Profiles, rules,
/// hysteresis and app triggers live in the JSON document so they can be
/// exported, diffed and migrated.
public struct UserDefaultsFlags: @unchecked Sendable {
    public enum Key: String, CaseIterable {
        case hasCompletedOnboarding = "ui.hasCompletedOnboarding"
        case lastSelectedProfile = "ui.lastSelectedProfile"
        case menuBarShowsTemperature = "ui.menuBarShowsTemperature"
        case updateChannel = "update.channel"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Key.hasCompletedOnboarding.rawValue) }
        nonmutating set { defaults.set(newValue, forKey: Key.hasCompletedOnboarding.rawValue) }
    }

    public var lastSelectedProfile: String? {
        get { defaults.string(forKey: Key.lastSelectedProfile.rawValue) }
        nonmutating set { defaults.set(newValue, forKey: Key.lastSelectedProfile.rawValue) }
    }

    public var menuBarShowsTemperature: Bool {
        get { defaults.object(forKey: Key.menuBarShowsTemperature.rawValue) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Key.menuBarShowsTemperature.rawValue) }
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation

public struct AppTrigger: Codable, Sendable, Identifiable, Equatable {
    public var bundleID: String
    public var profileID: Profile.ID
    public var priority: Int
    public var isEnabled: Bool

    public var id: String { "\(bundleID)->\(profileID.rawValue)" }

    public init(bundleID: String, profileID: Profile.ID, priority: Int = 50, isEnabled: Bool = true) {
        self.bundleID = bundleID
        self.profileID = profileID
        self.priority = priority
        self.isEnabled = isEnabled
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation
import FrostBarCore

public struct AppTriggerMatcher: Sendable {
    public init() {}

    /// Frontmost application wins over background applications; ties are broken
    /// by the trigger priority and then by bundle identifier for determinism.
    public func match(triggers: [AppTrigger], context: AppContext) -> AppTrigger? {
        let enabled = triggers.filter(\.isEnabled)

        if let frontmost = context.frontmostBundleID {
            let candidates = enabled.filter { $0.bundleID == frontmost }
            if let best = best(in: candidates) {
                return best
            }
        }

        let running = enabled.filter { context.runningBundleIDs.contains($0.bundleID) }
        return best(in: running)
    }

    private func best(in triggers: [AppTrigger]) -> AppTrigger? {
        triggers.max { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority < rhs.priority
            }
            return lhs.bundleID > rhs.bundleID
        }
    }
}

public struct ProfileResolver: Sendable {
    public struct Resolution: Sendable, Equatable {
        public enum Source: String, Sendable {
            case manualOverride
            case appTrigger
            case activeProfile
            case firstAvailable
        }

        public var profile: Profile
        public var source: Source
        public var trigger: AppTrigger?

        public init(profile: Profile, source: Source, trigger: AppTrigger? = nil) {
            self.profile = profile
            self.source = source
            self.trigger = trigger
        }
    }

    private let matcher: AppTriggerMatcher

    public init(matcher: AppTriggerMatcher = AppTriggerMatcher()) {
        self.matcher = matcher
    }

    public func resolve(
        configuration: Configuration,
        context: AppContext,
        manualOverride: Profile.ID? = nil
    ) -> Resolution? {
        if let manualOverride, let profile = configuration.profile(id: manualOverride) {
            return Resolution(profile: profile, source: .manualOverride)
        }

        if let trigger = matcher.match(triggers: configuration.triggers, context: context),
           let profile = configuration.profile(id: trigger.profileID) {
            return Resolution(profile: profile, source: .appTrigger, trigger: trigger)
        }

        if let id = configuration.activeProfileID, let profile = configuration.profile(id: id) {
            return Resolution(profile: profile, source: .activeProfile)
        }

        if let profile = configuration.profiles.first(where: \.isEnabled) ?? configuration.profiles.first {
            return Resolution(profile: profile, source: .firstAvailable)
        }

        return nil
    }
}

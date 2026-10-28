// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation

/// The complete set of collaborators the app depends on.
///
/// Built once in `App/CompositionRoot.swift` and injected into `AppState`.
/// Tests and SwiftUI previews build their own environment with fakes; nothing in
/// the UI ever constructs a service directly.
public struct AppEnvironment: Sendable {
    public let time: any TimeProvider
    public let sensors: any SensorProviding
    public let fans: any FanControlling
    public let evaluator: any ModeEvaluating
    public let triggers: any AppTriggering
    public let capabilities: any CapabilityProviding
    public let store: any ConfigurationStoring
    public let updates: any UpdateProviding
    public let helper: any HelperManaging
    public let log: any Logging

    public init(
        time: any TimeProvider,
        sensors: any SensorProviding,
        fans: any FanControlling,
        evaluator: any ModeEvaluating,
        triggers: any AppTriggering,
        capabilities: any CapabilityProviding,
        store: any ConfigurationStoring,
        updates: any UpdateProviding,
        helper: any HelperManaging,
        log: any Logging
    ) {
        self.time = time
        self.sensors = sensors
        self.fans = fans
        self.evaluator = evaluator
        self.triggers = triggers
        self.capabilities = capabilities
        self.store = store
        self.updates = updates
        self.helper = helper
        self.log = log
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation
import FrostBarCore
import FrostBarModes
import FrostBarProfiles
import FrostBarSMC

/// The only place in the app where concrete implementations are created.
///
/// Every dependency is a protocol from `FrostBarCore`; tests and previews build
/// the same graph with fakes instead of calling this.
@MainActor
enum CompositionRoot {
    static func makeLive() -> AppState {
        let log = OSLogLogger()
        let helperClient = HelperClient()

        let inProcessSensors = SMCSensorProvider()
        let helperSensors = HelperSensorProvider(client: helperClient)
        let sensors = FallbackSensorProvider(
            inProcess: inProcessSensors,
            helperBacked: helperSensors,
            log: log
        )

        let environment = AppEnvironment(
            time: SystemTimeProvider(),
            sensors: sensors,
            fans: HelperFanController(client: helperClient),
            evaluator: DefaultModeEvaluator(),
            triggers: WorkspaceAppTrigger(),
            capabilities: CapabilityService(sensors: sensors),
            store: FileConfigurationStore(),
            updates: SparkleUpdateProvider(),
            helper: SMAppServiceHelperInstaller(),
            log: log
        )
        return AppState(environment: environment)
    }
}

/// Holds the single app graph. `AppDelegate` and the SwiftUI scenes share it,
/// which keeps the composition root from running twice.
@MainActor
enum AppContainer {
    static let state: AppState = CompositionRoot.makeLive()
}

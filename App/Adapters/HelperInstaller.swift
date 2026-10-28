// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation
import FrostBarCore
import ServiceManagement

/// Registers the launchd daemon with `SMAppService` (macOS 13+).
struct SMAppServiceHelperInstaller: HelperManaging {
    private var service: SMAppService {
        SMAppService.daemon(plistName: HelperConstants.launchDaemonPlistName)
    }

    func status() async -> HelperStatus {
        switch service.status {
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notRegistered:
            return .notRegistered
        case .notFound:
            return .unknown
        @unknown default:
            return .unknown
        }
    }

    func install() async throws {
        try service.register()
        // The user may still have to approve the daemon in System Settings >
        // General > Login Items. The UI deep-links there when status is
        // `.requiresApproval`.
    }

    func uninstall() async throws {
        try await service.unregister()
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation
import ServiceManagement

/// Login item for the app itself (not the privileged helper).
///
/// macOS 13 introduced `SMAppService.mainApp`; the older `SMLoginItemSetEnabled`
/// path would require a bundled login helper and is not needed here.
enum LoginItemService {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

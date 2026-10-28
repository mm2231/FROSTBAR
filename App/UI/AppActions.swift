// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import AppKit

/// App-level commands shared by the menu bar panel, the Touch Bar and the
/// control panel. Keeping them in one place means the three surfaces cannot
/// drift apart.
@MainActor
enum AppActions {
    static func showControlPanel() {
        (NSApp.delegate as? AppDelegate)?.showControlPanel()
    }

    static func showSettings() {
        // macOS 13 has no `openSettings` environment action; the Settings scene
        // is opened through the responder chain.
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    static func openLoginItemsSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    static func setDockIconVisible(_ visible: Bool) {
        _ = NSApp.setActivationPolicy(visible ? .regular : .accessory)
    }

    static func quit() {
        NSApp.terminate(nil)
    }
}

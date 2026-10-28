// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controlPanel: ControlPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        Task {
            await AppContainer.state.start()
            AppActions.setDockIconVisible(AppContainer.state.configuration.general.showDockIcon)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Best effort: the helper watchdog also restores automatic mode if the
        // process disappears without saying goodbye.
        let state = AppContainer.state
        Task { await state.shutdown() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showControlPanel()
        return true
    }

    /// Opens the compact panel. While it is the key window, macOS shows its
    /// `NSTouchBar`; that is the primary UI on Touch Bar Macs.
    @objc func showControlPanel() {
        if controlPanel == nil {
            controlPanel = ControlPanelController(state: AppContainer.state)
        }
        controlPanel?.show()
    }
}

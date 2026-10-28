// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import AppKit
import SwiftUI

/// Hosts the control panel window and owns its `NSTouchBar`.
///
/// The Touch Bar is attached to the window, not to the application, so it
/// appears exactly while the panel is key and disappears with it. No Control
/// Strip APIs are involved: `NSTouchBar` is public AppKit.
@MainActor
final class ControlPanelController: NSWindowController, NSWindowDelegate {
    private let state: AppState
    private let touchBarHost: TouchBarHost

    init(state: AppState) {
        self.state = state
        self.touchBarHost = TouchBarHost(state: state)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "FrostBar"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.backgroundColor = Theme.nsInk
        window.minSize = NSSize(width: 380, height: 560)
        window.contentView = NSHostingView(rootView: ControlPanelView().environmentObject(state))

        super.init(window: window)

        window.delegate = self
        window.setFrameAutosaveName("FrostBarControlPanel")
        window.center()
        touchBarHost.attach(to: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("FrostBar windows are created in code")
    }

    func show() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        // Releasing it prevents a stale Touch Bar from being restored for the
        // next key window.
        window?.touchBar = nil
    }
}

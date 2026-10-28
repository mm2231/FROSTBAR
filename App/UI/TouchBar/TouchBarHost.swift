// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import SwiftUI

/// The whole Touch Bar is one principal item hosting a SwiftUI view, so every
/// surface reads the same `AppState` and stays in sync without extra plumbing.
@MainActor
final class TouchBarHost: NSObject, NSTouchBarDelegate {
    private let state: AppState
    private var touchBar: NSTouchBar?

    init(state: AppState) {
        self.state = state
        super.init()
    }

    func attach(to window: NSWindow) {
        let bar = NSTouchBar()
        bar.delegate = self
        bar.principalItemIdentifier = .frostBarPanel
        bar.defaultItemIdentifiers = [.frostBarPanel]
        window.touchBar = bar
        touchBar = bar
    }

    func touchBar(
        _ touchBar: NSTouchBar,
        makeItemForIdentifier identifier: NSTouchBarItem.Identifier
    ) -> NSTouchBarItem? {
        guard identifier == .frostBarPanel else { return nil }

        let item = NSCustomTouchBarItem(identifier: identifier)
        let hosting = NSHostingView(rootView: TouchBarRootView().environmentObject(state))
        hosting.frame = NSRect(x: 0, y: 0, width: 620, height: 30)
        hosting.autoresizingMask = [.width, .height]
        hosting.wantsLayer = true
        item.view = hosting
        return item
    }
}

extension NSTouchBarItem.Identifier {
    static let frostBarPanel = NSTouchBarItem.Identifier("com.mm2231.frostbar.touchbar.panel")
}

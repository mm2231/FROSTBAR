// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import SwiftUI

@main
@MainActor
struct FrostBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var state = AppContainer.state

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanel()
                .environmentObject(state)
        } label: {
            MenuBarLabel()
                .environmentObject(state)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsWindow()
                .environmentObject(state)
        }
    }
}
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import SwiftUI

/// Menu bar fallback. The Touch Bar is the primary UI when the app is focused;
/// this label is what remains when the Control Strip is not available.
struct MenuBarLabel: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: state.helperStatus.isUsable ? "wind" : "wind.snow")
            Text(state.menuBarTitle)
                .monospacedDigit()
        }
        .accessibilityLabel(Text("FrostBar, \(state.menuBarTitle)"))
    }
}

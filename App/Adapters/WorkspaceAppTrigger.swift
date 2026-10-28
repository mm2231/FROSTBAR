// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import AppKit
import Foundation
import FrostBarCore
import IOKit.ps

/// `AppTriggering` backed by `NSWorkspace` notifications.
///
/// The implementation polls at a low frequency: foreground application changes
/// also arrive through `NSWorkspace.didActivateApplicationNotification`, but a
/// poll keeps the skeleton deterministic and cheap. TODO: replace with
/// notification observers plus a debounce.
struct WorkspaceAppTrigger: AppTriggering {
    func context() async -> AppContext {
        await MainActor.run {
            let workspace = NSWorkspace.shared
            let running = Set(workspace.runningApplications.compactMap(\.bundleIdentifier))
            return AppContext(
                frontmostBundleID: workspace.frontmostApplication?.bundleIdentifier,
                runningBundleIDs: running,
                isOnAC: PowerSource.isOnAC,
                isSessionActive: !workspace.runningApplications.isEmpty,
                isDisplayAsleep: false
            )
        }
    }

    func contexts() -> AsyncStream<AppContext> {
        AsyncStream { continuation in
            let task = Task {
                var last: AppContext?
                while !Task.isCancelled {
                    let next = await context()
                    if next != last {
                        continuation.yield(next)
                        last = next
                    }
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

enum PowerSource {
    static var isOnAC: Bool {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return true }
        guard let raw = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() else { return true }

        for element in raw as NSArray {
            let source = element as AnyObject
            guard let info = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
                  let state = info[kIOPSPowerSourceStateKey as String] as? String
            else { continue }
            if state == (kIOPSACPowerValue as String) {
                return true
            }
            if state == (kIOPSBatteryPowerValue as String) {
                return false
            }
        }
        return true
    }
}

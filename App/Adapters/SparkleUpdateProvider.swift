// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation
import FrostBarCore
import Sparkle

/// Bridges Sparkle 2 to the `UpdateProviding` port.
///
/// Domain and UI only ever see `UpdateState`; swapping Sparkle for another
/// updater is a change in this file.
///
/// The updater is only started when the bundle carries a usable feed URL and
/// EdDSA public key. Development builds keep the placeholders from
/// `Team.xcconfig`, and Sparkle would otherwise try to verify against an empty
/// key and report a confusing failure on launch.
final class SparkleUpdateProvider: NSObject, UpdateProviding, SPUUpdaterDelegate, @unchecked Sendable {
    private let controller: SPUStandardUpdaterController?
    private let disabledReason: String?
    private let box = UpdateStateBox()

    override init() {
        let problem = Self.configurationProblem()
        disabledReason = problem
        controller = problem == nil
            ? SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
            : nil
        super.init()
        controller?.updater.delegate = self
    }

    var state: UpdateState {
        box.value
    }

    func checkForUpdates(userInitiated: Bool) async {
        guard let controller else {
            if userInitiated {
                box.value = .failed(message: disabledReason ?? "Updates are disabled in this build.")
            }
            return
        }

        await MainActor.run {
            box.value = .checking
            controller.checkForUpdates(nil)
        }
    }

    func states() -> AsyncStream<UpdateState> {
        AsyncStream { continuation in
            let task = Task {
                var last: UpdateState = .idle
                while !Task.isCancelled {
                    let current = box.value
                    if current != last {
                        continuation.yield(current)
                        last = current
                    }
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: Configuration

    /// Returns a human-readable reason when this build cannot update itself.
    private static func configurationProblem(bundle: Bundle = .main) -> String? {
        let key = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        let unresolvedKey = key.isEmpty || key.hasPrefix("REPLACE_WITH") || key.hasPrefix("$(")
        guard !unresolvedKey else {
            return "This build has no Sparkle public key, so automatic updates are disabled."
        }

        let feed = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? ""
        guard let url = URL(string: feed), url.scheme == "https" else {
            return "This build has no HTTPS update feed, so automatic updates are disabled."
        }

        return nil
    }

    // MARK: SPUUpdaterDelegate

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        box.value = .available(version: item.displayVersionString)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        box.value = .upToDate
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        box.value = .failed(message: error.localizedDescription)
    }
}

private final class UpdateStateBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: UpdateState = .idle

    var value: UpdateState {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storage
        }
        set {
            lock.lock()
            storage = newValue
            lock.unlock()
        }
    }
}

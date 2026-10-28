// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation
import FrostBarCore

/// Crash-safe record of an override that has not been released yet.
///
/// The helper is a launchd daemon and can be restarted (or killed) while a fan
/// is in manual mode. The journal is written before the helper answers `.applied`
/// and deleted only after Apple automatic mode has been restored, so a restart
/// can undo a stale override.
struct WriteJournal {
    private struct Record: Codable {
        var command: FanCommand
        var updatedAt: Date
    }

    private let directory: URL
    private let fileURL: URL
    private let fileManager = FileManager.default

    init(directory: URL = URL(fileURLWithPath: "/Library/Application Support/FrostBar", isDirectory: true)) {
        self.directory = directory
        self.fileURL = directory.appendingPathComponent("helper-journal.json")
    }

    var wasActive: Bool {
        fileManager.fileExists(atPath: fileURL.path)
    }

    func record(_ command: FanCommand) {
        do {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(Record(command: command, updatedAt: Date()))
            try data.write(to: fileURL, options: [.atomic])
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        } catch {
            NSLog("FrostBarHelper: could not write the write journal: %@", error.localizedDescription)
        }
    }

    func clear() {
        guard wasActive else { return }
        do {
            try fileManager.removeItem(at: fileURL)
        } catch {
            NSLog("FrostBarHelper: could not clear the write journal: %@", error.localizedDescription)
        }
    }
}

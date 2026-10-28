// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation

public enum JSONCoding {
    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

public struct FileLocations: Sendable, Equatable {
    public let configurationDirectory: URL

    public init(configurationDirectory: URL) {
        self.configurationDirectory = configurationDirectory
    }

    public var configurationFile: URL {
        configurationDirectory.appendingPathComponent("configuration.json")
    }

    public var backupFile: URL {
        configurationDirectory.appendingPathComponent("configuration.backup.json")
    }

    public var logsDirectory: URL {
        configurationDirectory.appendingPathComponent("Logs", isDirectory: true)
    }

    public static func applicationSupport(bundleID: String? = Bundle.main.bundleIdentifier) -> FileLocations {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return FileLocations(
            configurationDirectory: base.appendingPathComponent(bundleID ?? "FrostBar", isDirectory: true)
        )
    }

    /// Used by tests and previews: never touches the user's real configuration.
    public static func temporary() -> FileLocations {
        FileLocations(
            configurationDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("frostbar-\(UUID().uuidString)", isDirectory: true)
        )
    }
}

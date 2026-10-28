// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation
import FrostBarCore

public struct ConfigurationMigrator: Sendable {
    public init() {}

    private struct Header: Decodable {
        var schemaVersion: Int?
    }

    public func migrate(_ data: Data) throws -> Configuration {
        let header = try JSONCoding.decoder().decode(Header.self, from: data)
        var version = header.schemaVersion ?? 0

        guard version <= Configuration.currentSchemaVersion else {
            throw FrostBarError.invalidConfiguration(
                "Configuration schema \(version) is newer than this build (\(Configuration.currentSchemaVersion))."
            )
        }

        var migrated = data
        while version < Configuration.currentSchemaVersion {
            switch version {
            case 0:
                // Legacy files without a version: decoded with defaults below.
                migrated = data
                version = Configuration.currentSchemaVersion
            default:
                throw FrostBarError.invalidConfiguration("No migration from schema \(version).")
            }
        }

        var configuration = try JSONCoding.decoder().decode(Configuration.self, from: migrated)
        configuration.schemaVersion = Configuration.currentSchemaVersion
        if configuration.profiles.isEmpty {
            configuration = .default
        }
        if configuration.activeProfileID == nil {
            configuration.activeProfileID = configuration.profiles.first?.id
        }
        return configuration
    }
}

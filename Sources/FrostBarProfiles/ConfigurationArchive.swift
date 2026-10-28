// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation
import FrostBarCore

/// Versioned container for export/import. Separate from the on-disk file so the
/// file format can evolve independently of the archive format.
public struct ConfigurationArchive: Codable, Sendable, Equatable {
    public static let formatIdentifier = "frostbar.configuration"
    public static let currentFormatVersion = 1

    public var format: String
    public var formatVersion: Int
    public var exportedAt: Date
    public var appVersion: String
    public var configuration: Configuration

    public init(
        format: String = ConfigurationArchive.formatIdentifier,
        formatVersion: Int = ConfigurationArchive.currentFormatVersion,
        exportedAt: Date = Date(),
        appVersion: String = "0.0.0",
        configuration: Configuration
    ) {
        self.format = format
        self.formatVersion = formatVersion
        self.exportedAt = exportedAt
        self.appVersion = appVersion
        self.configuration = configuration
    }

    public enum ArchiveError: Error, LocalizedError {
        case wrongFormat(String)
        case unsupportedVersion(Int)

        public var errorDescription: String? {
            switch self {
            case let .wrongFormat(format):
                return "Not a FrostBar configuration archive (format: \(format))."
            case let .unsupportedVersion(version):
                return "Archive format version \(version) is newer than this build supports."
            }
        }
    }

    public static func decode(_ data: Data) throws -> ConfigurationArchive {
        let archive = try JSONCoding.decoder().decode(ConfigurationArchive.self, from: data)
        guard archive.format == formatIdentifier else {
            throw ArchiveError.wrongFormat(archive.format)
        }
        guard archive.formatVersion <= currentFormatVersion else {
            throw ArchiveError.unsupportedVersion(archive.formatVersion)
        }
        return archive
    }
}

public enum ConfigurationMerger {
    public static func merge(
        current: Configuration,
        imported: Configuration,
        strategy: ImportMergeStrategy,
        now: Date = Date()
    ) -> Configuration {
        switch strategy {
        case .replace:
            var result = imported
            result.schemaVersion = Configuration.currentSchemaVersion
            return result

        case .mergeByID:
            var result = current
            for profile in imported.profiles {
                if let index = result.profiles.firstIndex(where: { $0.id == profile.id }) {
                    result.profiles[index] = profile
                } else {
                    result.profiles.append(profile)
                }
            }
            for trigger in imported.triggers {
                if let index = result.triggers.firstIndex(where: { $0.id == trigger.id }) {
                    result.triggers[index] = trigger
                } else {
                    result.triggers.append(trigger)
                }
            }
            if result.profile(id: result.activeProfileID ?? "") == nil {
                result.activeProfileID = result.profiles.first?.id
            }
            return result

        case let .asNewProfile(name):
            var result = current
            let suffix = Int(now.timeIntervalSince1970)
            for var profile in imported.profiles {
                profile.id = Profile.ID("imported-\(profile.id.rawValue)-\(suffix)")
                profile.name = imported.profiles.count == 1 ? name : "\(name) — \(profile.name)"
                result.profiles.append(profile)
            }
            return result
        }
    }
}

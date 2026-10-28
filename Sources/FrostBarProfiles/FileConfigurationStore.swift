// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation
import FrostBarCore

public actor FileConfigurationStore: ConfigurationStoring {
    private let locations: FileLocations
    private let fileManager = FileManager.default
    private let validator = ConfigurationValidator()
    private let migrator = ConfigurationMigrator()

    public init(locations: FileLocations = .applicationSupport()) {
        self.locations = locations
    }

    public func load() async throws -> Configuration {
        guard fileManager.fileExists(atPath: locations.configurationFile.path) else {
            return .default
        }
        let data = try Data(contentsOf: locations.configurationFile)
        let configuration = try migrator.migrate(data)
        try validator.assertValid(configuration)
        return configuration
    }

    public func save(_ configuration: Configuration) async throws {
        try validator.assertValid(configuration)

        try fileManager.createDirectory(
            at: locations.configurationDirectory,
            withIntermediateDirectories: true
        )

        if fileManager.fileExists(atPath: locations.configurationFile.path) {
            try? fileManager.removeItem(at: locations.backupFile)
            try? fileManager.copyItem(at: locations.configurationFile, to: locations.backupFile)
        }

        let data = try JSONCoding.encoder().encode(configuration)
        try data.write(to: locations.configurationFile, options: [.atomic])
    }

    public nonisolated func export(_ configuration: Configuration) throws -> Data {
        let archive = ConfigurationArchive(configuration: configuration)
        return try JSONCoding.encoder().encode(archive)
    }

    public func importArchive(_ data: Data, strategy: ImportMergeStrategy) async throws -> Configuration {
        let archive = try ConfigurationArchive.decode(data)
        try validator.assertValid(archive.configuration)

        let current = (try? await load()) ?? .default
        let merged = ConfigurationMerger.merge(current: current, imported: archive.configuration, strategy: strategy)
        try validator.assertValid(merged)
        try await save(merged)
        return merged
    }

    public func location() async -> URL {
        locations.configurationFile
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import XCTest
@testable import FrostBarCore
@testable import FrostBarProfiles

final class ConfigurationStoreTests: XCTestCase {
    func testSaveAndLoadRoundTrip() async throws {
        let locations = FileLocations.temporary()
        let store = FileConfigurationStore(locations: locations)

        var configuration = Configuration.default
        configuration.safety.maxSlewRPMps = 600
        try await store.save(configuration)

        let loaded = try await store.load()
        XCTAssertEqual(loaded, configuration)
        XCTAssertTrue(FileManager.default.fileExists(atPath: locations.configurationFile.path))
    }

    func testExportImportRoundTrip() async throws {
        let store = FileConfigurationStore(locations: .temporary())
        let configuration = Configuration.default

        let data = try store.export(configuration)
        let imported = try await store.importArchive(data, strategy: .replace)
        XCTAssertEqual(imported, configuration)
    }

    func testImportMergeKeepsExistingProfiles() async throws {
        let store = FileConfigurationStore(locations: .temporary())
        var current = Configuration.default
        current.profiles.append(Profile(id: "custom", name: "Custom"))
        try await store.save(current)

        var incoming = Configuration.default
        incoming.profiles = [Profile(id: "imported", name: "Imported")]
        let data = try store.export(incoming)
        let merged = try await store.importArchive(data, strategy: .mergeByID)

        XCTAssertNotNil(merged.profile(id: "custom"))
        XCTAssertNotNil(merged.profile(id: "imported"))
    }
}

final class ConfigurationMigratorTests: XCTestCase {
    private let migrator = ConfigurationMigrator()

    func testMissingSchemaVersionIsAccepted() throws {
        let json = Data(#"{"profiles":[]}"#.utf8)
        let configuration = try migrator.migrate(json)
        XCTAssertEqual(configuration.schemaVersion, Configuration.currentSchemaVersion)
        XCTAssertFalse(configuration.profiles.isEmpty)
    }

    func testNewerSchemaIsRejected() throws {
        let json = Data(#"{"schemaVersion":99,"profiles":[]}"#.utf8)
        XCTAssertThrowsError(try migrator.migrate(json))
    }
}

final class ConfigurationValidatorTests: XCTestCase {
    private let validator = ConfigurationValidator()

    func testDuplicateProfileIdentifiersAreErrors() {
        var configuration = Configuration.default
        configuration.profiles.append(Profile(id: "balanced", name: "Duplicate"))
        let errors = validator.validate(configuration).filter { $0.severity == .error }
        XCTAssertFalse(errors.isEmpty)
    }

    func testForceZeroIsRejectedInV1() {
        var configuration = Configuration.default
        configuration.advanced.idleBehavior = .forceZero
        let errors = validator.validate(configuration).filter { $0.severity == .error }
        XCTAssertTrue(errors.contains { $0.path == "advanced.idleBehavior" })
    }
}

final class ProfileResolverTests: XCTestCase {
    func testManualOverrideWins() {
        var configuration = Configuration.default
        configuration.triggers = [AppTrigger(bundleID: "com.apple.dt.Xcode", profileID: "quiet", priority: 100)]
        let context = AppContext(frontmostBundleID: "com.apple.dt.Xcode", runningBundleIDs: ["com.apple.dt.Xcode"])

        let resolution = ProfileResolver().resolve(
            configuration: configuration,
            context: context,
            manualOverride: "balanced"
        )
        XCTAssertEqual(resolution?.source, .manualOverride)
        XCTAssertEqual(resolution?.profile.id, "balanced")
    }

    func testFrontmostAppTriggerWinsOverActiveProfile() {
        var configuration = Configuration.default
        configuration.triggers = [AppTrigger(bundleID: "com.apple.dt.Xcode", profileID: "quiet", priority: 10)]
        let context = AppContext(frontmostBundleID: "com.apple.dt.Xcode", runningBundleIDs: ["com.apple.dt.Xcode"])

        let resolution = ProfileResolver().resolve(configuration: configuration, context: context)
        XCTAssertEqual(resolution?.source, .appTrigger)
        XCTAssertEqual(resolution?.profile.id, "quiet")
    }

    func testFallsBackToActiveProfile() {
        let resolution = ProfileResolver().resolve(
            configuration: .default,
            context: .empty
        )
        XCTAssertEqual(resolution?.source, .activeProfile)
    }
}

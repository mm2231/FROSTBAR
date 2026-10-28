// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation

/// Placeholder for the next schema migration.
///
/// v1 is the initial schema, so nothing to do yet. When a field is renamed or a
/// rule kind is replaced, add the transformation here and register it in
/// `ConfigurationMigrator`. Migrations must be pure `Data -> Data` steps so they
/// can be tested against fixtures in `Tests/FrostBarProfilesTests/Fixtures`.
enum MigrationV1ToV2 {
    static func migrate(_ data: Data) throws -> Data {
        // TODO: implement when schemaVersion 2 is introduced.
        data
    }
}

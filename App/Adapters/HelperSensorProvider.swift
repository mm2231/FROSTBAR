// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation
import FrostBarCore

/// Sensor readings through the privileged helper.
struct HelperSensorProvider: SensorProviding {
    let client: HelperClient

    func capabilities() async throws -> SystemCapabilities {
        switch try await client.send(.capabilities) {
        case let .capabilities(capabilities):
            return capabilities
        case let .failure(message):
            throw FrostBarError.helperRejected(message)
        default:
            throw FrostBarError.helperUnavailable
        }
    }

    func snapshot() async throws -> SensorSnapshot {
        switch try await client.send(.snapshot) {
        case let .snapshot(snapshot):
            return snapshot
        case let .failure(message):
            throw FrostBarError.helperRejected(message)
        default:
            throw FrostBarError.helperUnavailable
        }
    }
}

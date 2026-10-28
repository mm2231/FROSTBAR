// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation
import FrostBarCore

/// Read-only `SensorProviding` backed by the in-process AppleSMC connection.
///
/// Never writes. If the user client denies access, it throws
/// `FrostBarError.smcNotPrivileged` and `FallbackSensorProvider` switches to the
/// helper transport.
public struct SMCSensorProvider: SensorProviding {
    private let connection: SMCConnection

    public init(connection: SMCConnection = SMCConnection()) {
        self.connection = connection
    }

    public func capabilities() async throws -> SystemCapabilities {
        let fanCount: Int
        switch await connection.probe() {
        case let .ready(count):
            fanCount = count
        case .notPrivileged:
            throw FrostBarError.smcNotPrivileged
        case .unavailable:
            throw FrostBarError.smcUnavailable
        }

        return SystemCapabilities(
            architecture: HostInfo.architecture,
            modelIdentifier: HostInfo.modelIdentifier,
            isTouchBarModel: HostInfo.isTouchBarModel,
            fanCount: fanCount,
            canControlFans: HostInfo.architecture == .intel && fanCount > 0,
            sensorTransport: .inProcess
        )
    }

    public func snapshot() async throws -> SensorSnapshot {
        try await connection.readSnapshot()
    }
}

/// Read/write facade used exclusively by the privileged helper.
///
/// The helper performs `FanWritePolicy` validation before calling these
/// methods; this type only guards the "must be root" invariant.
public struct SMCFanWriter: Sendable {
    private let connection: SMCConnection

    public init(connection: SMCConnection = SMCConnection()) {
        self.connection = connection
    }

    public func setMode(fan: FanID, automatic: Bool) async throws {
        if automatic {
            try await connection.writeAutomatic(fan: fan)
        } else {
            try await connection.writeManualMode(fan: fan)
        }
    }

    public func setTarget(fan: FanID, rpm: RPM) async throws {
        try await connection.writeTarget(fan: fan, rpm: rpm)
    }

    public func setMinimum(fan: FanID, rpm: RPM) async throws {
        try await connection.writeMinimum(fan: fan, rpm: rpm)
    }

    public func restoreAutomatic(fans: [FanID]) async throws {
        for fan in fans {
            try await connection.writeAutomatic(fan: fan)
        }
    }
}

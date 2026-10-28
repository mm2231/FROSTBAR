// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation

/// Reads sensors in-process and permanently falls back to the privileged helper
/// when the AppleSMC user client refuses access (`kIOReturnNotPrivileged`).
public actor FallbackSensorProvider: SensorProviding {
    private let inProcess: any SensorProviding
    private let helperBacked: any SensorProviding
    private var usesHelper: Bool
    private let log: any Logging

    public init(
        inProcess: any SensorProviding,
        helperBacked: any SensorProviding,
        log: any Logging = NoopLogger()
    ) {
        self.inProcess = inProcess
        self.helperBacked = helperBacked
        self.usesHelper = false
        self.log = log
    }

    public func capabilities() async throws -> SystemCapabilities {
        guard !usesHelper else { return try await helperBacked.capabilities() }
        do {
            return try await inProcess.capabilities()
        } catch FrostBarError.smcNotPrivileged {
            usesHelper = true
            log.log(.warning, "SMC in-process access denied, switching to helper transport")
            return try await helperBacked.capabilities()
        }
    }

    public func snapshot() async throws -> SensorSnapshot {
        guard !usesHelper else { return try await helperBacked.snapshot() }
        do {
            return try await inProcess.snapshot()
        } catch FrostBarError.smcNotPrivileged {
            usesHelper = true
            log.log(.warning, "SMC in-process read denied, switching to helper transport")
            return try await helperBacked.snapshot()
        }
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation
import FrostBarCore
import FrostBarModes
import FrostBarSMC
import os

/// The only process that writes to the SMC.
///
/// Requests are serialised through an actor: `FanWritePolicy` validates every
/// command, the write journal records an override before it is acknowledged, and
/// the watchdog hands the fans back to Apple if the app disappears.
actor HelperCore {
    private let connection: SMCConnection
    private let policy = FanWritePolicy()
    private let journal = WriteJournal()
    private let log = Logger(subsystem: "com.mm2231.frostbar.helper", category: "core")

    private var watchdog = Watchdog()
    private var monitor: Task<Void, Never>?
    private var activeOverride: FanCommand?
    private var sessionToken: UUID?

    init(connection: SMCConnection = SMCConnection()) {
        self.connection = connection
    }

    // MARK: Lifecycle

    func start() async {
        if journal.wasActive {
            log.notice("Found an unreleased override from a previous run; restoring Apple automatic mode")
            try? await restoreAutomatic()
        }

        monitor?.cancel()
        monitor = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await self?.enforceWatchdog()
            }
        }
    }

    /// Best effort cleanup on `SIGTERM`, `SIGINT` and `--restore`.
    func prepareForExit() async {
        monitor?.cancel()
        monitor = nil
        if activeOverride != nil || journal.wasActive {
            try? await restoreAutomatic()
        }
        watchdog.disarm()
        await connection.close()
    }

    // MARK: Requests

    func handle(_ data: Data) async -> HelperResponse {
        let request: HelperRequest
        do {
            request = try HelperCoding.decoder.decode(HelperRequest.self, from: data)
        } catch {
            return .failure(message: "Malformed request.")
        }

        switch request {
        case let .handshake(clientVersion):
            let token = UUID()
            sessionToken = token
            log.info("Handshake from app version \(clientVersion, privacy: .public)")
            return .handshake(
                protocolVersion: HelperConstants.protocolVersion,
                helperVersion: HelperConstants.hostAppVersion,
                sessionToken: token
            )

        case .capabilities:
            return await capabilitiesResponse()

        case .snapshot:
            do {
                return .snapshot(try await connection.readSnapshot())
            } catch {
                return .failure(message: error.localizedDescription)
            }

        case let .apply(command, issuedAt):
            return await apply(command, issuedAt: issuedAt)

        case .restoreAutomatic:
            do {
                try await restoreAutomatic()
                return .restored
            } catch {
                return .failure(message: error.localizedDescription)
            }

        case let .heartbeat(token):
            guard token == sessionToken else {
                return .failure(message: "Stale heartbeat token.")
            }
            guard activeOverride != nil else { return .heartbeatAccepted }
            watchdog.arm()
            return .heartbeatAccepted
        }
    }

    // MARK: Commands

    private func capabilitiesResponse() async -> HelperResponse {
        let probe = await connection.probe()
        let fanCount: Int
        switch probe {
        case let .ready(count):
            fanCount = count
        case .notPrivileged:
            return .capabilities(SystemCapabilities(
                architecture: HostInfo.architecture,
                modelIdentifier: HostInfo.modelIdentifier,
                isTouchBarModel: HostInfo.isTouchBarModel,
                fanCount: 0,
                canControlFans: false,
                sensorTransport: .helper
            ))
        case let .unavailable(reason):
            return .failure(message: reason)
        }

        return .capabilities(SystemCapabilities(
            architecture: HostInfo.architecture,
            modelIdentifier: HostInfo.modelIdentifier,
            isTouchBarModel: HostInfo.isTouchBarModel,
            fanCount: fanCount,
            canControlFans: HostInfo.architecture == .intel && fanCount > 0,
            sensorTransport: .helper
        ))
    }

    private func apply(_ command: FanCommand, issuedAt: Date) async -> HelperResponse {
        do {
            let snapshot = try await connection.readSnapshot()
            if let maximum = snapshot.maxTemperature, maximum >= HardwareGuardrails.emergencyAuto {
                try? await restoreAutomatic()
                return .failure(message: "Emergency temperature \(maximum.description); fans returned to automatic.")
            }

            let inventory = try await connection.fanInventory()
            guard !inventory.isEmpty else {
                return .failure(message: "No controllable fans reported by the SMC.")
            }

            // forceZero is rejected by the policy in v1, so the helper always
            // validates against `.off`. v1.1 must make this explicit per command.
            let writes = try policy.plan(
                command: command,
                inventory: inventory,
                issuedAt: issuedAt,
                now: Date(),
                idleBehavior: .off
            )

            do {
                try await perform(writes)
            } catch {
                // A partial write is the worst state to leave a fan in.
                try? await restoreAutomatic()
                return .failure(message: "SMC write failed: \(error.localizedDescription)")
            }

            if case .automatic = command {
                activeOverride = nil
                watchdog.disarm()
                journal.clear()
            } else {
                activeOverride = command
                watchdog.arm()
                journal.record(command)
            }
            return .applied
        } catch let error as FanWritePolicy.PolicyError {
            return .failure(message: error.localizedDescription)
        } catch {
            return .failure(message: error.localizedDescription)
        }
    }

    private func perform(_ writes: [PlannedWrite]) async throws {
        for write in writes {
            switch write.value {
            case let .flag(flag):
                if flag == 0 {
                    try await connection.writeAutomatic(fan: write.fan)
                } else {
                    try await connection.writeManualMode(fan: write.fan)
                }

            case let .rpm(rpm):
                switch write.key {
                case .target:
                    try await connection.writeTarget(fan: write.fan, rpm: rpm)
                case .minimum:
                    try await connection.writeMinimum(fan: write.fan, rpm: rpm)
                case .maximum:
                    try await connection.writeMaximum(fan: write.fan, rpm: rpm)
                case .mode:
                    break
                }
            }
        }
    }

    /// Hands every fan back to the SMC's automatic mode.
    ///
    /// Continues after a per-fan error so one stubborn fan does not leave the
    /// others in manual mode; the journal is cleared only when all writes
    /// succeeded, which means a restart will retry.
    private func restoreAutomatic() async throws {
        let inventory = try await connection.fanInventory()
        var firstError: Error?

        for fan in inventory {
            do {
                try await connection.writeAutomatic(fan: fan.id)
            } catch {
                if firstError == nil { firstError = error }
            }
        }

        if let firstError {
            throw firstError
        }

        activeOverride = nil
        watchdog.disarm()
        journal.clear()
    }

    private func enforceWatchdog() async {
        guard activeOverride != nil, watchdog.hasExpired() else { return }
        log.warning("Watchdog expired without a heartbeat; restoring Apple automatic mode")
        do {
            try await restoreAutomatic()
        } catch {
            log.error("Watchdog restore failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

/// XPC facade. Keeps message ordering stable while the actual work happens in
/// `HelperCore`, which is the only thing that touches the SMC.
final class HelperRPCService: NSObject, FrostBarHelperXPC {
    private let core: HelperCore
    private let lock = NSLock()
    private var pending: Task<Void, Never>?

    init(core: HelperCore) {
        self.core = core
    }

    func perform(_ request: Data, withReply reply: @escaping (Data) -> Void) {
        let box = ReplyBox(reply)

        lock.lock()
        let previous = pending
        let task = Task { [core, box] in
            await previous?.value
            let response = await core.handle(request)
            let data = (try? HelperCoding.encoder.encode(response)) ?? Data()
            box.send(data)
        }
        pending = task
        lock.unlock()
    }
}

/// `NSXPCConnection` does not require reply blocks to be `Sendable`; the box
/// states that the block is safe to move to the actor's task.
private final class ReplyBox: @unchecked Sendable {
    private let reply: (Data) -> Void

    init(_ reply: @escaping (Data) -> Void) {
        self.reply = reply
    }

    func send(_ data: Data) {
        reply(data)
    }
}

/// Rejects every connection that is not the signed FrostBar app before it can
/// reach `HelperRPCService`.
final class HelperServiceDelegate: NSObject, NSXPCListenerDelegate {
    private let service: HelperRPCService
    private let authenticator = ClientAuthenticator()
    private let log = Logger(subsystem: "com.mm2231.frostbar.helper", category: "xpc")

    init(service: HelperRPCService) {
        self.service = service
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard authenticator.hasUsableRequirement else {
            log.fault("Refusing XPC connection: the client code signing requirement could not be built")
            return false
        }

        guard authenticator.isAuthorized(connection) else {
            log.error("Refusing XPC connection from pid \(connection.processIdentifier, privacy: .public)")
            return false
        }

        connection.exportedInterface = NSXPCInterface(with: FrostBarHelperXPC.self)
        connection.exportedObject = service
        connection.resume()
        return true
    }
}

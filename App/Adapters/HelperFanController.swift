// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation
import FrostBarCore

/// All fan writes go through the helper. The app has no write path of its own.
///
/// While an override is active this actor sends a heartbeat every
/// `HardwareGuardrails.heartbeatInterval` seconds. The helper releases the fans
/// after `watchdogTimeout` without one, so a crashed or killed app can never
/// leave a fan pinned.
actor HelperFanController: FanControlling {
    private let client: HelperClient
    private var heartbeatTask: Task<Void, Never>?

    init(client: HelperClient) {
        self.client = client
    }

    func inventory() async throws -> [FanDescriptor] {
        try await HelperSensorProvider(client: client).snapshot().fans
    }

    func apply(_ command: FanCommand) async throws {
        // `.automatic` is a release, not a write: route it through the same
        // path so the heartbeat stops before the helper disarms.
        if case .automatic = command {
            try await restoreAutomatic()
            return
        }

        switch try await client.send(.apply(command: command, issuedAt: Date())) {
        case .applied:
            startHeartbeat()
        case let .failure(message):
            throw FrostBarError.helperRejected(message)
        default:
            throw FrostBarError.helperUnavailable
        }
    }

    func restoreAutomatic() async throws {
        stopHeartbeat()

        switch try await client.send(.restoreAutomatic) {
        case .restored:
            return
        case let .failure(message):
            throw FrostBarError.helperRejected(message)
        default:
            throw FrostBarError.helperUnavailable
        }
    }

    func activeOverride() async -> FanCommand? {
        // The helper owns the authoritative journal; the app only needs to know
        // whether it has an override in flight, which the control loop tracks.
        nil
    }

    // MARK: Heartbeat

    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task.detached { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(
                    nanoseconds: UInt64(HardwareGuardrails.heartbeatInterval * 1_000_000_000)
                )
                guard !Task.isCancelled, let self else { return }

                do {
                    try await self.client.heartbeat()
                } catch {
                    // The helper is gone or the session is stale; its watchdog
                    // restores Apple automatic mode on its own.
                    await self.stopHeartbeat()
                    return
                }
            }
        }
    }

    private func stopHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }

    deinit {
        heartbeatTask?.cancel()
    }
}

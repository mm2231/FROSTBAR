// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation
import FrostBarCore

/// Async wrapper around the Mach XPC connection to the privileged helper.
///
/// The helper hands out a session token during the handshake. `apply` performs
/// the handshake lazily, so callers never have to think about connection state;
/// `heartbeat()` keeps the helper's watchdog fed while an override is active.
public actor HelperClient {
    private let serviceName: String
    private var connection: NSXPCConnection?
    private var sessionToken: UUID?

    public init(serviceName: String = HelperConstants.machServiceName) {
        self.serviceName = serviceName
    }

    public func send(_ request: HelperRequest) async throws -> HelperResponse {
        switch request {
        case .apply, .heartbeat:
            try await ensureSession()
        default:
            break
        }

        let payload: Data
        do {
            payload = try HelperCoding.encoder.encode(request)
        } catch {
            throw FrostBarError.helperUnavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            let connection: NSXPCConnection
            do {
                connection = try connect()
            } catch {
                continuation.resume(throwing: error)
                return
            }

            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in
                continuation.resume(throwing: FrostBarError.helperUnavailable)
            }) as? FrostBarHelperXPC else {
                continuation.resume(throwing: FrostBarError.helperUnavailable)
                return
            }

            proxy.perform(payload) { reply in
                do {
                    let response = try HelperCoding.decoder.decode(HelperResponse.self, from: reply)
                    continuation.resume(returning: response)
                } catch {
                    continuation.resume(throwing: FrostBarError.helperRejected("Malformed reply from the helper."))
                }
            }
        }
    }

    /// Extends the helper's watchdog for the current session.
    ///
    /// A rejected token means the helper restarted (or another handshake took
    /// over the session), so the local session is dropped and the next `apply`
    /// starts a new one. Nothing here writes to the SMC.
    public func heartbeat() async throws {
        guard let token = sessionToken else { return }

        switch try await send(.heartbeat(token: token)) {
        case .heartbeatAccepted:
            return
        case let .failure(message):
            sessionToken = nil
            throw FrostBarError.helperRejected(message)
        default:
            throw FrostBarError.helperUnavailable
        }
    }

    public func invalidate() {
        connection?.invalidate()
        connection = nil
        sessionToken = nil
    }

    private func ensureSession() async throws {
        if sessionToken != nil { return }

        switch try await send(.handshake(clientVersion: HelperConstants.hostAppVersion)) {
        case let .handshake(protocolVersion, _, token):
            guard protocolVersion == HelperConstants.protocolVersion else {
                throw FrostBarError.helperRejected(
                    "FrostBar and FrostBarHelper use different protocol versions. Reinstall the helper."
                )
            }
            sessionToken = token

        case let .failure(message):
            throw FrostBarError.helperRejected(message)

        default:
            throw FrostBarError.helperUnavailable
        }
    }

    private func connect() throws -> NSXPCConnection {
        if let connection {
            return connection
        }
        let newConnection = NSXPCConnection(machServiceName: serviceName, options: [])
        newConnection.remoteObjectInterface = NSXPCInterface(with: FrostBarHelperXPC.self)
        newConnection.invalidationHandler = { [weak self] in
            guard let self else { return }
            Task { await self.clearConnection() }
        }
        newConnection.interruptionHandler = { [weak self] in
            guard let self else { return }
            Task { await self.clearConnection() }
        }
        newConnection.resume()
        connection = newConnection
        return newConnection
    }

    private func clearConnection() {
        connection?.invalidate()
        connection = nil
        sessionToken = nil
    }
}

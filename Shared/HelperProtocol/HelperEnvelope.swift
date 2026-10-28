// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation
import FrostBarCore

/// Requests accepted by the helper.
///
/// The helper never receives raw SMC keys, file paths or shell commands: only
/// these cases cross the XPC boundary. The envelope is versioned by
/// `HelperConstants.protocolVersion` and `handshake`.
public enum HelperRequest: Codable, Sendable {
    case handshake(clientVersion: String)
    case capabilities
    case snapshot
    case apply(command: FanCommand, issuedAt: Date)
    case restoreAutomatic
    case heartbeat(token: UUID)
}

public enum HelperResponse: Codable, Sendable {
    /// The session token must be echoed in every heartbeat; the helper drops
    /// the override when the token is missing or stale.
    case handshake(protocolVersion: Int, helperVersion: String, sessionToken: UUID)
    case capabilities(SystemCapabilities)
    case snapshot(SensorSnapshot)
    case applied
    case restored
    case heartbeatAccepted
    case failure(message: String)
}

@objc public protocol FrostBarHelperXPC {
    /// Single entry point: `HelperRequest` encoded as JSON, replied with an
    /// encoded `HelperResponse`. One method keeps the attack surface small and
    /// makes protocol evolution a matter of decoding, not of interface changes.
    func perform(_ request: Data, withReply reply: @escaping (Data) -> Void)
}

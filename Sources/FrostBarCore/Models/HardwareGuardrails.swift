// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation

/// What "fan off" means for a profile.
public enum FanIdleBehavior: String, Codable, Sendable, CaseIterable {
    /// Release the override and hand control back to Apple (`F0Md = 0`).
    /// This is the only behaviour shipped in v1.
    case off

    /// Write `F0Tg = 0` (and `F0Mn = 0` where required).
    /// v1.1, opt-in, requires explicit acknowledgement and hardware verification.
    case forceZero
}

/// Safety limits that are compiled into the binary.
///
/// These are deliberately not `Codable`, have no settings switch and are never
/// passed through `Configuration`: a user, an imported profile or a compromised
/// app process cannot weaken them. The helper enforces its own copy.
public enum HardwareGuardrails {
    /// `forceZero` is refused at or above this temperature.
    public static let forceZeroAmbientLimit = Celsius(50)

    /// An active `forceZero` is released to Apple automatic mode at or above this temperature.
    public static let forceZeroForcedAuto = Celsius(70)

    /// Manual control is released to Apple automatic mode at or above this temperature.
    public static let emergencyAuto = Celsius(95)

    /// Upper bound for the rate of change of the requested fan speed.
    public static let maxSlewRPMps = 800

    /// Hard ceiling for any requested speed; the helper additionally clamps to `F0Mx`.
    public static let absoluteMaxRPM = RPM(7200)

    /// The helper restores automatic mode when no heartbeat arrived for this long.
    public static let watchdogTimeout: TimeInterval = 10

    /// Client heartbeat period.
    public static let heartbeatInterval: TimeInterval = 2

    /// Lifetime of a single write command.
    public static let commandTTL: TimeInterval = 15

    /// Minimum delay between two SMC writes for the same fan.
    public static let writeCooldown: TimeInterval = 1.0
}

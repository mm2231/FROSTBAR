// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation

/// The only SMC keys the helper is allowed to write.
///
/// Raw key strings never cross the XPC boundary: the app sends a `FanCommand`,
/// the helper turns it into `PlannedWrite` values, and `SMCFanWriter` is the
/// only place that formats `F0Md`, `F0Tg`, `F0Mn`, `F0Mx`.
public enum SMCWriteKey: String, Sendable, Codable, CaseIterable {
    case mode = "Md"
    case target = "Tg"
    case minimum = "Mn"
    case maximum = "Mx"

    public func key(for fan: FanID) -> String {
        "F\(fan.index)\(rawValue)"
    }
}

public struct PlannedWrite: Sendable, Equatable {
    public enum Value: Sendable, Equatable {
        case flag(Int)
        case rpm(RPM)
    }

    public var fan: FanID
    public var key: SMCWriteKey
    public var value: Value

    public init(fan: FanID, key: SMCWriteKey, value: Value) {
        self.fan = fan
        self.key = key
        self.value = value
    }
}

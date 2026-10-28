// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation
import FrostBarCore

/// SMC data types that FrostBar understands.
///
/// Upstream SMCKit only implemented a broken `sp78`; decoding lives here so it
/// can be tested without hardware.
public enum SMCDataType: String, Sendable, Equatable {
    case fpe2
    case sp78
    case ui8
    case ui16
    case ui32
    case flt
    case flag

    public init?(fourCC: String) {
        switch fourCC {
        case "fpe2": self = .fpe2
        case "sp78": self = .sp78
        case "ui8 ": self = .ui8
        case "ui16": self = .ui16
        case "ui32": self = .ui32
        case "flt ": self = .flt
        case "flag": self = .flag
        default: return nil
        }
    }
}

public enum SMCDataCodec {
    // MARK: Decoding

    /// Signed 7.8 fixed point, big endian. Used by temperature keys.
    public static func sp78(_ bytes: [UInt8]) -> Double? {
        guard bytes.count >= 2 else { return nil }
        let raw = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
        return Double(Int16(bitPattern: raw)) / 256.0
    }

    /// Unsigned 14.2 fixed point, big endian. Used by fan RPM keys.
    public static func fpe2(_ bytes: [UInt8]) -> Int? {
        guard bytes.count >= 2 else { return nil }
        return (Int(bytes[0]) << 6) | (Int(bytes[1]) >> 2)
    }

    public static func ui8(_ bytes: [UInt8]) -> Int? {
        bytes.first.map(Int.init)
    }

    public static func ui16(_ bytes: [UInt8]) -> Int? {
        guard bytes.count >= 2 else { return nil }
        return Int(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
    }

    public static func ui32(_ bytes: [UInt8]) -> Int? {
        guard bytes.count >= 4 else { return nil }
        let value = UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
        return Int(value)
    }

    /// IEEE-754 single. The SMC stores it in host (little endian) order.
    public static func flt(_ bytes: [UInt8]) -> Double? {
        guard bytes.count >= 4 else { return nil }
        let bits = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
        return Double(Float(bitPattern: bits))
    }

    public static func decode(_ bytes: [UInt8], as type: SMCDataType) -> Double? {
        switch type {
        case .sp78: return sp78(bytes)
        case .fpe2: return fpe2(bytes).map(Double.init)
        case .ui8, .flag: return ui8(bytes).map(Double.init)
        case .ui16: return ui16(bytes).map(Double.init)
        case .ui32: return ui32(bytes).map(Double.init)
        case .flt: return flt(bytes)
        }
    }

    // MARK: Encoding

    public static func encodeFPE2(_ rpm: RPM) -> [UInt8] {
        let value = UInt16(clamping: max(0, min(rpm.rawValue, 16383)))
        let raw = value << 2
        return [UInt8(raw >> 8), UInt8(raw & 0xFF)]
    }

    public static func encodeUI8(_ value: Int) -> [UInt8] {
        [UInt8(clamping: max(0, min(value, 255)))]
    }

    public static func encodeUI16(_ value: Int) -> [UInt8] {
        let raw = UInt16(clamping: max(0, min(value, 65535)))
        return [UInt8(raw >> 8), UInt8(raw & 0xFF)]
    }
}

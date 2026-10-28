// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation

/// Fan speed in revolutions per minute.
public struct RPM: RawRepresentable, Hashable, Sendable, Comparable, CustomStringConvertible {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public init(_ value: Int) {
        self.rawValue = value
    }

    public static let zero = RPM(0)

    public static func < (lhs: RPM, rhs: RPM) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public func clamped(to range: ClosedRange<RPM>) -> RPM {
        RPM(min(max(self, range.lowerBound), range.upperBound).rawValue)
    }

    public var description: String { "\(rawValue) rpm" }
}

extension RPM: Codable {
    public init(from decoder: Decoder) throws {
        self.rawValue = try decoder.singleValueContainer().decode(Int.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Temperature in degrees Celsius.
public struct Celsius: RawRepresentable, Hashable, Sendable, Comparable, CustomStringConvertible {
    public let rawValue: Double

    public init(rawValue: Double) {
        self.rawValue = rawValue
    }

    public init(_ value: Double) {
        self.rawValue = value
    }

    public static func < (lhs: Celsius, rhs: Celsius) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public func rounded(toPlaces places: Int = 1) -> Celsius {
        let factor = pow(10.0, Double(places))
        return Celsius((rawValue * factor).rounded() / factor)
    }

    public var description: String { String(format: "%.1f °C", rawValue) }
}

extension Celsius: Codable {
    public init(from decoder: Decoder) throws {
        self.rawValue = try decoder.singleValueContainer().decode(Double.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Stable identifier of a fan. Index-based because SMC accesses fans by index.
public struct FanID: Hashable, Sendable, Codable, CustomStringConvertible {
    public let index: Int

    public init(_ index: Int) {
        self.index = index
    }

    public var rawValue: String { "fan\(index)" }

    public init?(rawValue: String) {
        guard rawValue.hasPrefix("fan"), let index = Int(rawValue.dropFirst(3)) else { return nil }
        self.index = index
    }

    public var description: String { rawValue }
}

/// Identifier of a temperature sensor or of an aggregated group such as `cpu.max`.
public struct SensorID: RawRepresentable, Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public static let cpuMax = SensorID("cpu.max")
    public static let gpuMax = SensorID("gpu.max")
    public static let systemMax = SensorID("system.max")

    public var description: String { rawValue }
}

/// Stable, human-readable identifier used for profiles, rules and triggers.
/// String-backed on purpose: identifiers survive refactors and hand-edited JSON.
public struct TaggedID<Phantom>: Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue }
}

extension TaggedID: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.rawValue = value
    }
}

extension TaggedID {
    public init(from decoder: Decoder) throws {
        self.rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

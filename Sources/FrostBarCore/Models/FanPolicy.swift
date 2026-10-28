// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation

/// What a profile or a rule asks the fans to do.
///
/// Encoded as a discriminated union with a stable `type` string so the JSON is
/// readable and does not depend on Swift's automatic enum encoding. Unknown
/// kinds are preserved as `.unsupported` instead of failing the whole import.
public enum FanPolicy: Sendable, Equatable {
    case automatic
    case fixed(RPM)
    case curve(FanCurve)
    case perFan([String: RPM])
    case unsupported(String)
}

extension FanPolicy: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case rpm
        case curve
        case perFan
    }

    private enum Kind: String, Codable {
        case automatic
        case fixed
        case curve
        case perFan
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawType = try container.decode(String.self, forKey: .type)
        guard let kind = Kind(rawValue: rawType) else {
            self = .unsupported(rawType)
            return
        }
        switch kind {
        case .automatic:
            self = .automatic
        case .fixed:
            self = .fixed(try container.decode(RPM.self, forKey: .rpm))
        case .curve:
            self = .curve(try container.decode(FanCurve.self, forKey: .curve))
        case .perFan:
            self = .perFan(try container.decode([String: RPM].self, forKey: .perFan))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .automatic:
            try container.encode(Kind.automatic.rawValue, forKey: .type)
        case let .fixed(rpm):
            try container.encode(Kind.fixed.rawValue, forKey: .type)
            try container.encode(rpm, forKey: .rpm)
        case let .curve(curve):
            try container.encode(Kind.curve.rawValue, forKey: .type)
            try container.encode(curve, forKey: .curve)
        case let .perFan(values):
            try container.encode(Kind.perFan.rawValue, forKey: .type)
            try container.encode(values, forKey: .perFan)
        case let .unsupported(type):
            try container.encode(type, forKey: .type)
        }
    }
}

/// Temperature-to-RPM curve. Points are normalised (sorted, clamped) before use.
public struct FanCurve: Codable, Sendable, Equatable {
    public enum Interpolation: String, Codable, Sendable {
        case linear
        case step
    }

    public struct Point: Codable, Sendable, Equatable {
        public var celsius: Celsius
        public var rpm: RPM

        public init(celsius: Celsius, rpm: RPM) {
            self.celsius = celsius
            self.rpm = rpm
        }
    }

    public var points: [Point]
    public var interpolation: Interpolation

    public init(points: [Point], interpolation: Interpolation = .linear) {
        self.points = points
        self.interpolation = interpolation
    }

    public func normalized() -> FanCurve {
        let sorted = points
            .sorted { $0.celsius < $1.celsius }
            .map { Point(celsius: $0.celsius, rpm: RPM(max(0, $0.rpm.rawValue))) }
        return FanCurve(points: sorted, interpolation: interpolation)
    }

    public static let balanced = FanCurve(points: [
        Point(celsius: Celsius(40), rpm: RPM(1300)),
        Point(celsius: Celsius(60), rpm: RPM(2200)),
        Point(celsius: Celsius(75), rpm: RPM(3600)),
        Point(celsius: Celsius(85), rpm: RPM(5200)),
        Point(celsius: Celsius(95), rpm: RPM(6200)),
    ])

    public static let quiet = FanCurve(points: [
        Point(celsius: Celsius(45), rpm: RPM(1300)),
        Point(celsius: Celsius(70), rpm: RPM(2000)),
        Point(celsius: Celsius(85), rpm: RPM(3200)),
        Point(celsius: Celsius(95), rpm: RPM(5000)),
    ])
}

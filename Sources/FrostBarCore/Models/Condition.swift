// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation

/// Predicate that decides whether a rule is a candidate.
///
/// Recursive, therefore encoded manually. Unknown conditions decode to
/// `.unsupported` and never match, which keeps imported profiles from a newer
/// version usable instead of rejecting the whole file.
public indirect enum Condition: Sendable, Equatable {
    case any
    case sensorAbove(SensorID, Celsius)
    case sensorBelow(SensorID, Celsius)
    case all([Condition])
    case anyOf([Condition])
    case appRunning([String])
    case onBattery
    case thermalPressure(ThermalPressure)
    case unsupported(String)
}

extension Condition: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case sensor
        case celsius
        case conditions
        case bundleIDs
        case pressure
    }

    private enum Kind: String, Codable {
        case any
        case sensorAbove
        case sensorBelow
        case all
        case anyOf
        case appRunning
        case onBattery
        case thermalPressure
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawType = try container.decode(String.self, forKey: .type)
        guard let kind = Kind(rawValue: rawType) else {
            self = .unsupported(rawType)
            return
        }
        switch kind {
        case .any:
            self = .any
        case .sensorAbove:
            self = .sensorAbove(
                try container.decode(SensorID.self, forKey: .sensor),
                try container.decode(Celsius.self, forKey: .celsius)
            )
        case .sensorBelow:
            self = .sensorBelow(
                try container.decode(SensorID.self, forKey: .sensor),
                try container.decode(Celsius.self, forKey: .celsius)
            )
        case .all:
            self = .all(try container.decode([Condition].self, forKey: .conditions))
        case .anyOf:
            self = .anyOf(try container.decode([Condition].self, forKey: .conditions))
        case .appRunning:
            self = .appRunning(try container.decode([String].self, forKey: .bundleIDs))
        case .onBattery:
            self = .onBattery
        case .thermalPressure:
            self = .thermalPressure(try container.decode(ThermalPressure.self, forKey: .pressure))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .any:
            try container.encode(Kind.any.rawValue, forKey: .type)
        case let .sensorAbove(sensor, celsius):
            try container.encode(Kind.sensorAbove.rawValue, forKey: .type)
            try container.encode(sensor, forKey: .sensor)
            try container.encode(celsius, forKey: .celsius)
        case let .sensorBelow(sensor, celsius):
            try container.encode(Kind.sensorBelow.rawValue, forKey: .type)
            try container.encode(sensor, forKey: .sensor)
            try container.encode(celsius, forKey: .celsius)
        case let .all(conditions):
            try container.encode(Kind.all.rawValue, forKey: .type)
            try container.encode(conditions, forKey: .conditions)
        case let .anyOf(conditions):
            try container.encode(Kind.anyOf.rawValue, forKey: .type)
            try container.encode(conditions, forKey: .conditions)
        case let .appRunning(bundleIDs):
            try container.encode(Kind.appRunning.rawValue, forKey: .type)
            try container.encode(bundleIDs, forKey: .bundleIDs)
        case .onBattery:
            try container.encode(Kind.onBattery.rawValue, forKey: .type)
        case let .thermalPressure(pressure):
            try container.encode(Kind.thermalPressure.rawValue, forKey: .type)
            try container.encode(pressure, forKey: .pressure)
        case let .unsupported(type):
            try container.encode(type, forKey: .type)
        }
    }
}

public enum ThermalPressure: String, Codable, Sendable, CaseIterable {
    case nominal
    case fair
    case serious
    case critical
}

// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation

public struct SensorSnapshot: Codable, Sendable, Equatable {
    public struct Temperature: Codable, Sendable, Equatable {
        public var sensor: SensorID
        public var celsius: Celsius

        public init(sensor: SensorID, celsius: Celsius) {
            self.sensor = sensor
            self.celsius = celsius
        }
    }

    public var timestamp: Date
    public var temperatures: [Temperature]
    public var fans: [FanDescriptor]
    public var thermalPressure: ThermalPressure

    public init(
        timestamp: Date,
        temperatures: [Temperature],
        fans: [FanDescriptor],
        thermalPressure: ThermalPressure = .nominal
    ) {
        self.timestamp = timestamp
        self.temperatures = temperatures
        self.fans = fans
        self.thermalPressure = thermalPressure
    }

    public static let empty = SensorSnapshot(timestamp: Date(timeIntervalSince1970: 0), temperatures: [], fans: [])

    public func temperature(for sensor: SensorID) -> Celsius? {
        temperatures.first { $0.sensor == sensor }?.celsius
    }

    public var maxTemperature: Celsius? {
        temperatures.map(\.celsius).max()
    }

    public func fan(_ id: FanID) -> FanDescriptor? {
        fans.first { $0.id == id }
    }
}

public struct FanDescriptor: Codable, Sendable, Equatable, Identifiable {
    public enum Mode: String, Codable, Sendable {
        case automatic
        case forced
    }

    public var id: FanID
    public var name: String
    /// Currently reported speed (`F0Ac`).
    public var currentRPM: RPM
    /// Range advertised by the SMC (`F0Mn`...`F0Mx`).
    public var minRPM: RPM
    public var maxRPM: RPM
    public var mode: Mode

    public init(id: FanID, name: String, currentRPM: RPM, minRPM: RPM, maxRPM: RPM, mode: Mode = .automatic) {
        self.id = id
        self.name = name
        self.currentRPM = currentRPM
        self.minRPM = minRPM
        self.maxRPM = maxRPM
        self.mode = mode
    }

    public var range: ClosedRange<RPM> {
        minRPM...max(minRPM, maxRPM)
    }
}

public struct SystemCapabilities: Codable, Sendable, Equatable {
    public enum Architecture: String, Codable, Sendable {
        case intel
        case appleSilicon
    }

    /// Where sensor readings actually come from.
    public enum SensorTransport: String, Codable, Sendable {
        case inProcess
        case helper
        case unavailable
    }

    public var architecture: Architecture
    public var modelIdentifier: String
    public var isTouchBarModel: Bool
    public var fanCount: Int
    public var canControlFans: Bool
    public var sensorTransport: SensorTransport

    public init(
        architecture: Architecture,
        modelIdentifier: String,
        isTouchBarModel: Bool,
        fanCount: Int,
        canControlFans: Bool,
        sensorTransport: SensorTransport
    ) {
        self.architecture = architecture
        self.modelIdentifier = modelIdentifier
        self.isTouchBarModel = isTouchBarModel
        self.fanCount = fanCount
        self.canControlFans = canControlFans
        self.sensorTransport = sensorTransport
    }

    public static let unknown = SystemCapabilities(
        architecture: .intel,
        modelIdentifier: "unknown",
        isTouchBarModel: false,
        fanCount: 0,
        canControlFans: false,
        sensorTransport: .unavailable
    )
}

public struct AppContext: Sendable, Equatable {
    public var frontmostBundleID: String?
    public var runningBundleIDs: Set<String>
    public var isOnAC: Bool
    public var isSessionActive: Bool
    public var isDisplayAsleep: Bool

    public init(
        frontmostBundleID: String? = nil,
        runningBundleIDs: Set<String> = [],
        isOnAC: Bool = true,
        isSessionActive: Bool = true,
        isDisplayAsleep: Bool = false
    ) {
        self.frontmostBundleID = frontmostBundleID
        self.runningBundleIDs = runningBundleIDs
        self.isOnAC = isOnAC
        self.isSessionActive = isSessionActive
        self.isDisplayAsleep = isDisplayAsleep
    }

    public static let empty = AppContext()
}

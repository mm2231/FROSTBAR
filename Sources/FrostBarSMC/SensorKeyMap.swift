// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation
import FrostBarCore

/// SMC keys used to derive logical sensors, grouped by hardware component.
///
/// Key names differ between MacBook Pro generations. The table below is a
/// starting point for the 2016–2019 Touch Bar machines; every model must be
/// verified on hardware (`scripts/smc_probe.swift`) before release.
public struct SensorKeyMap: Sendable, Equatable {
    public struct Sensor: Sendable, Equatable {
        public var id: SensorID
        public var key: String

        public init(id: SensorID, key: String) {
            self.id = id
            self.key = key
        }
    }

    public struct Group: Sendable, Equatable {
        public var id: SensorID
        public var sensors: [Sensor]

        public init(id: SensorID, sensors: [Sensor]) {
            self.id = id
            self.sensors = sensors
        }
    }

    public var modelIdentifier: String
    public var groups: [Group]

    public init(modelIdentifier: String, groups: [Group]) {
        self.modelIdentifier = modelIdentifier
        self.groups = groups
    }

    public static func standard(for modelIdentifier: String) -> SensorKeyMap {
        // TODO: per-model tables for MacBookPro13,x ... 16,x. Until each model is
        // verified, use the superset below; missing keys are skipped at runtime.
        SensorKeyMap(
            modelIdentifier: modelIdentifier,
            groups: [
                Group(id: .cpuMax, sensors: [
                    Sensor(id: SensorID("cpu.proximity"), key: "TC0P"),
                    Sensor(id: SensorID("cpu.die"), key: "TC0E"),
                    Sensor(id: SensorID("cpu.die2"), key: "TC0F"),
                ]),
                Group(id: .gpuMax, sensors: [
                    Sensor(id: SensorID("gpu.proximity"), key: "TG0P"),
                    Sensor(id: SensorID("gpu.die"), key: "TG0D"),
                ]),
                Group(id: .systemMax, sensors: [
                    Sensor(id: SensorID("enclosure.base"), key: "TB0T"),
                    Sensor(id: SensorID("heatsink.1"), key: "Th1H"),
                ]),
            ]
        )
    }
}

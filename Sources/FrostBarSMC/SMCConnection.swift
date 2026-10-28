// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation
import FrostBarCore
import SMCKit

/// Serialised access to the AppleSMC user client.
///
/// `SMCKit` uses global static state, so every call must go through a single
/// actor. The app uses this type read-only; the helper uses the write methods.
public actor SMCConnection {
    public enum ProbeResult: Sendable, Equatable {
        case ready(fanCount: Int)
        case notPrivileged
        case unavailable(String)
    }

    private var opened = false
    private let keyMap: SensorKeyMap

    public init(keyMap: SensorKeyMap = .standard(for: HostInfo.modelIdentifier)) {
        self.keyMap = keyMap
    }

    public func probe() -> ProbeResult {
        do {
            try openIfNeeded()
            let count = try fanCount()
            return .ready(fanCount: count)
        } catch FrostBarError.smcNotPrivileged {
            return .notPrivileged
        } catch {
            return .unavailable(error.localizedDescription)
        }
    }

    public func openIfNeeded() throws {
        guard !opened else { return }
        do {
            try SMCKit.open()
            opened = true
        } catch SMCError.notPrivileged {
            throw FrostBarError.smcNotPrivileged
        } catch {
            throw FrostBarError.smcUnavailable
        }
    }

    public func close() {
        guard opened else { return }
        SMCKit.close()
        opened = false
    }

    // MARK: Reads

    public func fanCount() throws -> Int {
        try readInt("FNum", as: .ui8)
    }

    public func fanInventory() throws -> [FanDescriptor] {
        let count = try fanCount()
        guard count > 0 else { return [] }
        return try (0 ..< count).map { index in
            let id = FanID(index)
            return FanDescriptor(
                id: id,
                name: "Fan \(index + 1)",
                currentRPM: RPM(try readInt("F\(index)Ac", as: .fpe2)),
                minRPM: RPM(try readInt("F\(index)Mn", as: .fpe2)),
                maxRPM: RPM(try readInt("F\(index)Mx", as: .fpe2)),
                mode: (try? readInt("F\(index)Md", as: .ui8)) == 1 ? .forced : .automatic
            )
        }
    }

    public func readSnapshot(now: Date = Date()) throws -> SensorSnapshot {
        var temperatures: [SensorSnapshot.Temperature] = []

        for group in keyMap.groups {
            var values: [Celsius] = []
            for sensor in group.sensors {
                guard let value = try? readTemperature(sensor.key) else { continue }
                temperatures.append(.init(sensor: sensor.id, celsius: value))
                values.append(value)
            }
            if let maximum = values.max() {
                temperatures.append(.init(sensor: group.id, celsius: maximum))
            }
        }

        let fans = (try? fanInventory()) ?? []
        return SensorSnapshot(
            timestamp: now,
            temperatures: temperatures,
            fans: fans,
            thermalPressure: HostInfo.thermalPressure
        )
    }

    public func readTemperature(_ key: String) throws -> Celsius {
        let bytes = try read(key)
        guard let value = SMCDataCodec.sp78(bytes) else {
            throw FrostBarError.smcUnavailable
        }
        return Celsius(value)
    }

    // MARK: Writes (helper only)

    public func writeAutomatic(fan: FanID) throws {
        try requireRoot()
        try write(applyFanKey(.mode, to: fan), bytes: SMCDataCodec.encodeUI8(0))
    }

    public func writeTarget(fan: FanID, rpm: RPM) throws {
        try requireRoot()
        try write(applyFanKey(.target, to: fan), bytes: SMCDataCodec.encodeFPE2(rpm))
    }

    public func writeMinimum(fan: FanID, rpm: RPM) throws {
        try requireRoot()
        try write(applyFanKey(.minimum, to: fan), bytes: SMCDataCodec.encodeFPE2(rpm))
    }

    public func writeMaximum(fan: FanID, rpm: RPM) throws {
        try requireRoot()
        try write(applyFanKey(.maximum, to: fan), bytes: SMCDataCodec.encodeFPE2(rpm))
    }

    public func writeManualMode(fan: FanID) throws {
        try requireRoot()
        try write(applyFanKey(.mode, to: fan), bytes: SMCDataCodec.encodeUI8(1))
    }

    // MARK: Primitives

    private func applyFanKey(_ key: SMCWriteKey, to fan: FanID) -> String {
        key.key(for: fan)
    }

    private func readInt(_ key: String, as type: SMCDataType) throws -> Int {
        let bytes = try read(key)
        guard let value = SMCDataCodec.decode(bytes, as: type) else {
            throw FrostBarError.smcUnavailable
        }
        return Int(value.rounded())
    }

    private func read(_ key: String) throws -> [UInt8] {
        do {
            return try SMCKit.readBytes(key)
        } catch SMCError.notPrivileged {
            throw FrostBarError.smcNotPrivileged
        } catch SMCError.keyNotFound(let missing) {
            throw FrostBarError.smcKeyMissing(missing)
        } catch {
            throw FrostBarError.smcUnavailable
        }
    }

    private func write(_ key: String, bytes: [UInt8]) throws {
        do {
            try SMCKit.writeBytes(key, bytes)
        } catch SMCError.notPrivileged {
            throw FrostBarError.smcNotPrivileged
        } catch SMCError.keyNotFound(let missing) {
            throw FrostBarError.smcKeyMissing(missing)
        } catch {
            throw FrostBarError.smcUnavailable
        }
    }

    private func requireRoot() throws {
        guard geteuid() == 0 else { throw FrostBarError.writeNotPermitted }
    }
}

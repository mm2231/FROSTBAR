// SPDX-License-Identifier: MIT
// SMCKit — Apple System Management Controller transport layer for Intel Macs.
//
// Vendored from https://github.com/beltex/SMCKit (MIT, Copyright (c) 2014-2017 beltex)
// and adapted for FrostBar. See Vendored/SMCKit/PATCHES.md for the list of changes.
// This file intentionally keeps only the transport primitives: key info, raw
// reads and raw writes. Fan and temperature semantics live in FrostBarSMC.

import Foundation
import IOKit

public enum SMCError: Error, Equatable {
    case driverNotFound
    case failedToOpen
    case notPrivileged
    case keyNotFound(String)
    case badKey(String)
    case invalidValueSize(expected: Int, actual: Int)
    case transport(kernReturn: kern_return_t, smcResult: UInt8)
}

public struct SMCKeyInfo: Sendable, Equatable {
    public let dataSize: Int
    public let dataType: UInt32

    public init(dataSize: Int, dataType: UInt32) {
        self.dataSize = dataSize
        self.dataType = dataType
    }

    public var typeString: String {
        let bytes = [
            UInt8((dataType >> 24) & 0xFF), UInt8((dataType >> 16) & 0xFF),
            UInt8((dataType >> 8) & 0xFF), UInt8(dataType & 0xFF),
        ]
        return String(bytes: bytes, encoding: .ascii) ?? "????"
    }
}

/// 32-byte payload with an inline layout, so `SMCParamStruct` matches the
/// 80-byte C structure expected by the AppleSMC user client.
public struct SMCBytes: Sendable, Equatable {
    public static let size = 32

    public var b00: UInt8 = 0
    public var b01: UInt8 = 0
    public var b02: UInt8 = 0
    public var b03: UInt8 = 0
    public var b04: UInt8 = 0
    public var b05: UInt8 = 0
    public var b06: UInt8 = 0
    public var b07: UInt8 = 0
    public var b08: UInt8 = 0
    public var b09: UInt8 = 0
    public var b10: UInt8 = 0
    public var b11: UInt8 = 0
    public var b12: UInt8 = 0
    public var b13: UInt8 = 0
    public var b14: UInt8 = 0
    public var b15: UInt8 = 0
    public var b16: UInt8 = 0
    public var b17: UInt8 = 0
    public var b18: UInt8 = 0
    public var b19: UInt8 = 0
    public var b20: UInt8 = 0
    public var b21: UInt8 = 0
    public var b22: UInt8 = 0
    public var b23: UInt8 = 0
    public var b24: UInt8 = 0
    public var b25: UInt8 = 0
    public var b26: UInt8 = 0
    public var b27: UInt8 = 0
    public var b28: UInt8 = 0
    public var b29: UInt8 = 0
    public var b30: UInt8 = 0
    public var b31: UInt8 = 0

    public init() {}

    public init(_ bytes: [UInt8]) {
        for (index, byte) in bytes.prefix(SMCBytes.size).enumerated() {
            self[index] = byte
        }
    }

    public subscript(index: Int) -> UInt8 {
        get {
            withUnsafeBytes(of: self) { buffer in
                buffer[index]
            }
        }
        set {
            withUnsafeMutableBytes(of: &self) { buffer in
                buffer[index] = newValue
            }
        }
    }

    public var array: [UInt8] {
        withUnsafeBytes(of: self) { Array($0) }
    }
}

/// Mirrors `SMCKeyData_t` from the reference AppleSMC implementation.
/// Layout is asserted to be exactly 80 bytes in `SMCKit.open()`.
public struct SMCParamStruct {
    public enum Selector: UInt8 {
        case handleYPCEvent = 2
        case readKey = 5
        case writeKey = 6
        case getKeyFromIndex = 8
        case getKeyInfo = 9
    }

    public struct Version {
        public var major: UInt8 = 0
        public var minor: UInt8 = 0
        public var build: UInt8 = 0
        public var reserved: UInt8 = 0
        public var release: UInt16 = 0
    }

    public struct PLimitData {
        public var version: UInt16 = 0
        public var length: UInt16 = 0
        public var cpuPLimit: UInt32 = 0
        public var gpuPLimit: UInt32 = 0
        public var memPLimit: UInt32 = 0
    }

    public struct KeyInfoData {
        public var dataSize: UInt32 = 0
        public var dataType: UInt32 = 0
        public var dataAttributes: UInt8 = 0
    }

    public var key: UInt32 = 0
    public var vers = Version()
    public var pLimitData = PLimitData()
    public var keyInfo = KeyInfoData()
    public var result: UInt8 = 0
    public var status: UInt8 = 0
    public var data8: UInt8 = 0
    public var data32: UInt32 = 0
    public var bytes = SMCBytes()

    public init() {}
}

public enum SMCKit {
    public static let structSize = 80

    private static var connection: io_connect_t = 0
    private static var isOpen = false

    // MARK: Lifecycle

    public static func open() throws {
        guard MemoryLayout<SMCParamStruct>.stride == structSize else {
            assertionFailure("SMCParamStruct must be 80 bytes, got \(MemoryLayout<SMCParamStruct>.stride)")
            throw SMCError.failedToOpen
        }
        guard !isOpen else { return }

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { throw SMCError.driverNotFound }
        defer { IOObjectRelease(service) }

        var connection: io_connect_t = 0
        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        guard result == kIOReturnSuccess else {
            throw result == kIOReturnNotPrivileged ? SMCError.notPrivileged : SMCError.failedToOpen
        }
        SMCKit.connection = connection
        SMCKit.isOpen = true
    }

    public static func close() {
        guard isOpen else { return }
        IOServiceClose(connection)
        connection = 0
        isOpen = false
    }

    // MARK: Keys

    public static func keyInfo(_ code: String) throws -> SMCKeyInfo {
        var input = SMCParamStruct()
        input.key = try fourCharCode(code)
        input.data8 = SMCParamStruct.Selector.getKeyInfo.rawValue
        let output = try call(&input)
        return SMCKeyInfo(dataSize: Int(output.keyInfo.dataSize), dataType: output.keyInfo.dataType)
    }

    public static func readBytes(_ code: String) throws -> [UInt8] {
        let info = try keyInfo(code)
        guard info.dataSize > 0, info.dataSize <= SMCBytes.size else {
            throw SMCError.invalidValueSize(expected: SMCBytes.size, actual: info.dataSize)
        }

        var input = SMCParamStruct()
        input.key = try fourCharCode(code)
        input.keyInfo.dataSize = UInt32(info.dataSize)
        input.data8 = SMCParamStruct.Selector.readKey.rawValue
        let output = try call(&input)
        return Array(output.bytes.array.prefix(info.dataSize))
    }

    public static func writeBytes(_ code: String, _ bytes: [UInt8]) throws {
        let info = try keyInfo(code)
        guard bytes.count == info.dataSize else {
            throw SMCError.invalidValueSize(expected: info.dataSize, actual: bytes.count)
        }

        var input = SMCParamStruct()
        input.key = try fourCharCode(code)
        input.keyInfo.dataSize = UInt32(info.dataSize)
        input.bytes = SMCBytes(bytes)
        input.data8 = SMCParamStruct.Selector.writeKey.rawValue
        _ = try call(&input)
    }

    // MARK: Transport

    private static func call(_ input: inout SMCParamStruct) throws -> SMCParamStruct {
        guard isOpen else { throw SMCError.failedToOpen }

        var output = SMCParamStruct()
        let size = MemoryLayout<SMCParamStruct>.stride
        var outputSize = size

        let result = IOConnectCallStructMethod(
            connection,
            UInt32(SMCParamStruct.Selector.handleYPCEvent.rawValue),
            &input,
            size,
            &output,
            &outputSize
        )

        switch (result, output.result) {
        case (kIOReturnSuccess, 0):
            return output
        case (kIOReturnSuccess, 132):
            throw SMCError.keyNotFound(fourCharCodeString(input.key))
        case (kIOReturnNotPrivileged, _):
            throw SMCError.notPrivileged
        default:
            throw SMCError.transport(kernReturn: result, smcResult: output.result)
        }
    }

    // MARK: Helpers

    static func fourCharCode(_ string: String) throws -> UInt32 {
        let bytes = Array(string.utf8)
        guard bytes.count == 4 else { throw SMCError.badKey(string) }
        return bytes.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    }

    static func fourCharCodeString(_ code: UInt32) -> String {
        let bytes = [
            UInt8((code >> 24) & 0xFF), UInt8((code >> 16) & 0xFF),
            UInt8((code >> 8) & 0xFF), UInt8(code & 0xFF),
        ]
        return String(bytes: bytes, encoding: .ascii) ?? "????"
    }
}

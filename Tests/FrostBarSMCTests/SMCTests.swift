// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import XCTest
@testable import FrostBarCore
@testable import FrostBarSMC

final class SMCDataCodecTests: XCTestCase {
    func testSP78Decoding() {
        XCTAssertEqual(SMCDataCodec.sp78([0x41, 0x00]), 65.0)
        XCTAssertEqual(SMCDataCodec.sp78([0x41, 0x80]), 65.5)
        XCTAssertEqual(SMCDataCodec.sp78([0x00, 0x80]), 0.5)
        XCTAssertEqual(SMCDataCodec.sp78([0xFF, 0x00]), -1.0)
        XCTAssertNil(SMCDataCodec.sp78([]))
    }

    func testFPE2Decoding() {
        XCTAssertEqual(SMCDataCodec.fpe2([0x0F, 0xA0]), 1000)
        XCTAssertEqual(SMCDataCodec.fpe2([0x00, 0x00]), 0)
        XCTAssertNil(SMCDataCodec.fpe2([0x01]))
    }

    func testFPE2EncodingRoundTrip() {
        for rpm in [0, 1000, 1300, 6200, 16383] {
            let encoded = SMCDataCodec.encodeFPE2(RPM(rpm))
            XCTAssertEqual(SMCDataCodec.fpe2(encoded), rpm, "round trip failed for \(rpm)")
        }
    }

    func testEncodingClampsOutOfRangeValues() {
        XCTAssertEqual(SMCDataCodec.encodeFPE2(RPM(20000)), SMCDataCodec.encodeFPE2(RPM(16383)))
        XCTAssertEqual(SMCDataCodec.encodeUI8(300), [255])
    }

    func testUnsignedDecoders() {
        XCTAssertEqual(SMCDataCodec.ui8([0x2A]), 42)
        XCTAssertEqual(SMCDataCodec.ui16([0x01, 0x02]), 258)
        XCTAssertEqual(SMCDataCodec.ui32([0x00, 0x00, 0x01, 0x00]), 256)
    }

    func testUnknownDataTypeIsNil() {
        XCTAssertNil(SMCDataType(fourCC: "????"))
        XCTAssertEqual(SMCDataType(fourCC: "fpe2"), .fpe2)
        XCTAssertEqual(SMCDataType(fourCC: "ui8 "), .ui8)
    }
}

final class SMCKeyTests: XCTestCase {
    func testFanWriteKeyFormatting() {
        XCTAssertEqual(SMCWriteKey.mode.key(for: FanID(0)), "F0Md")
        XCTAssertEqual(SMCWriteKey.target.key(for: FanID(1)), "F1Tg")
        XCTAssertEqual(SMCWriteKey.minimum.key(for: FanID(0)), "F0Mn")
        XCTAssertEqual(SMCWriteKey.maximum.key(for: FanID(0)), "F0Mx")
    }

    func testStandardKeyMapContainsAggregates() {
        let map = SensorKeyMap.standard(for: "MacBookPro15,1")
        XCTAssertEqual(map.groups.first?.id, .cpuMax)
        XCTAssertTrue(map.groups.contains { $0.id == .systemMax })
    }

    func testHostInfoHasModelIdentifier() {
        XCTAssertFalse(HostInfo.modelIdentifier.isEmpty)
    }
}

final class SMCHardwareTests: XCTestCase {
    func testProbeOnThisMachine() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["FROSTBAR_SMC_INTEGRATION"] == "1",
            "Set FROSTBAR_SMC_INTEGRATION=1 to run hardware-dependent tests."
        )
        let connection = SMCConnection()
        let result = await connection.probe()
        switch result {
        case let .ready(fanCount):
            XCTAssertGreaterThanOrEqual(fanCount, 0)
        case .notPrivileged:
            // Expected when the test runner is not the helper.
            break
        case let .unavailable(reason):
            XCTFail("SMC unavailable: \(reason)")
        }
        await connection.close()
    }
}

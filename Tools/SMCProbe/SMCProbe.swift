// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation
import FrostBarCore
import FrostBarSMC

/// Hardware verification helper. Run on every supported MacBookPro model before
/// adding it to `HostInfo.touchBarModels`:
///
///     swift run FrostBarProbe
///     sudo swift run FrostBarProbe    # SMC writes are not performed
///
/// The JSON output is the fixture used to build per-model sensor key maps.
@main
struct SMCProbe {
    struct Report: Codable {
        var model: String
        var architecture: String
        var isTouchBarModel: Bool
        var probe: String
        var fanCount: Int
        var canControlFans: Bool
        var error: String?
        var snapshot: SensorSnapshot?
    }

    static func main() async {
        let connection = SMCConnection()
        let probe = await connection.probe()

        var report = Report(
            model: HostInfo.modelIdentifier,
            architecture: HostInfo.architecture.rawValue,
            isTouchBarModel: HostInfo.isTouchBarModel,
            probe: "",
            fanCount: 0,
            canControlFans: false,
            error: nil,
            snapshot: nil
        )

        switch probe {
        case let .ready(fanCount):
            report.probe = "ready"
            report.fanCount = fanCount
            report.canControlFans = HostInfo.architecture == .intel && fanCount > 0
            do {
                report.snapshot = try await connection.readSnapshot()
            } catch {
                report.error = error.localizedDescription
            }

        case .notPrivileged:
            report.probe = "notPrivileged"

        case let .unavailable(reason):
            report.probe = "unavailable"
            report.error = reason
        }

        await connection.close()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(report), let json = String(data: data, encoding: .utf8) {
            print(json)
        }

        if report.probe != "ready" {
            FileHandle.standardError.write(Data("SMC probe failed: \(report.probe)\n".utf8))
            if report.probe == "notPrivileged" {
                FileHandle.standardError.write(Data("Reading may require root: sudo swift run FrostBarProbe\n".utf8))
            }
            exit(EXIT_FAILURE)
        }
    }
}

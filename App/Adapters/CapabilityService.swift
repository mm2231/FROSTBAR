// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation
import FrostBarCore

struct CapabilityService: CapabilityProviding {
    let sensors: any SensorProviding

    func capabilities() async -> SystemCapabilities {
        (try? await sensors.capabilities()) ?? .unknown
    }
}

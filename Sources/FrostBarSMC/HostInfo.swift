// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation
import FrostBarCore

public enum HostInfo {
    public static var modelIdentifier: String {
        var size = 0
        guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 0 else { return "unknown" }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.model", &buffer, &size, nil, 0) == 0 else { return "unknown" }
        return String(cString: buffer)
    }

    public static var architecture: SystemCapabilities.Architecture {
        #if arch(arm64)
        return .appleSilicon
        #else
        return .intel
        #endif
    }

    /// 2016–2019 Touch Bar machines. `13,1` and `14,1` are the non-Touch Bar
    /// 13-inch models and are intentionally excluded.
    public static let touchBarModels: Set<String> = [
        "MacBookPro13,2", "MacBookPro13,3",
        "MacBookPro14,2", "MacBookPro14,3",
        "MacBookPro15,1", "MacBookPro15,2", "MacBookPro15,3", "MacBookPro15,4",
        "MacBookPro16,1", "MacBookPro16,2", "MacBookPro16,3", "MacBookPro16,4",
    ]

    public static var isTouchBarModel: Bool {
        touchBarModels.contains(modelIdentifier)
    }

    public static var thermalPressure: ThermalPressure {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return .nominal
        case .fair: return .fair
        case .serious: return .serious
        case .critical: return .critical
        @unknown default: return .nominal
        }
    }
}

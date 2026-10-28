// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation
import FrostBarCore

public struct CurveInterpolator: Sendable {
    public init() {}

    /// Interpolates the requested speed for a temperature. Values outside the
    /// curve are clamped to the first/last point; a curve with fewer than two
    /// points returns its only value (or `0` when empty).
    public func rpm(for temperature: Celsius, curve: FanCurve) -> RPM {
        let normalized = curve.normalized()
        guard let first = normalized.points.first, let last = normalized.points.last else {
            return .zero
        }
        if temperature <= first.celsius { return first.rpm }
        if temperature >= last.celsius { return last.rpm }

        for index in 1 ..< normalized.points.count {
            let lower = normalized.points[index - 1]
            let upper = normalized.points[index]
            guard temperature <= upper.celsius else { continue }

            switch normalized.interpolation {
            case .step:
                return lower.rpm
            case .linear:
                let span = upper.celsius.rawValue - lower.celsius.rawValue
                guard span > 0 else { return upper.rpm }
                let ratio = (temperature.rawValue - lower.celsius.rawValue) / span
                let delta = Double(upper.rpm.rawValue - lower.rpm.rawValue)
                return RPM(Int((Double(lower.rpm.rawValue) + ratio * delta).rounded()))
            }
        }
        return last.rpm
    }
}

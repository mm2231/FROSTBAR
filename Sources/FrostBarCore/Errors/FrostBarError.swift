// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation

public enum FrostBarError: Error, LocalizedError, Sendable, Equatable {
    case notImplemented(String)
    case invalidConfiguration(String)
    case smcUnavailable
    case smcNotPrivileged
    case smcKeyMissing(String)
    case fanOutOfRange(fan: String, requested: Int, allowed: ClosedRange<Int>)
    case helperUnavailable
    case helperRejected(String)
    case writeNotPermitted
    case cancelled

    public var errorDescription: String? {
        switch self {
        case let .notImplemented(what):
            return "Not implemented: \(what)"
        case let .invalidConfiguration(reason):
            return "Invalid configuration: \(reason)"
        case .smcUnavailable:
            return "The System Management Controller is not available."
        case .smcNotPrivileged:
            return "Reading the SMC requires the privileged helper."
        case let .smcKeyMissing(key):
            return "SMC key \(key) is not available on this Mac."
        case let .fanOutOfRange(fan, requested, allowed):
            return "Fan \(fan) cannot run at \(requested) rpm (allowed \(allowed.lowerBound)...\(allowed.upperBound))."
        case .helperUnavailable:
            return "The FrostBar helper is not installed or not reachable."
        case let .helperRejected(reason):
            return "The helper rejected the request: \(reason)."
        case .writeNotPermitted:
            return "Writing to the SMC is only allowed in the privileged helper."
        case .cancelled:
            return "The operation was cancelled."
        }
    }
}

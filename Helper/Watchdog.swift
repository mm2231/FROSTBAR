// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation
import FrostBarCore

/// Deadline arithmetic for the helper's heartbeat watchdog.
///
/// Deliberately a value type with no timer of its own: the actor that owns the
/// fans decides how often to call `hasExpired`, which makes the timeout easy to
/// exercise without sleeping in a test.
struct Watchdog: Sendable, Equatable {
    let timeout: TimeInterval
    private(set) var deadline: Date?

    init(timeout: TimeInterval = HardwareGuardrails.watchdogTimeout) {
        self.timeout = timeout
    }

    var isArmed: Bool {
        deadline != nil
    }

    mutating func arm(now: Date = Date()) {
        deadline = now.addingTimeInterval(timeout)
    }

    mutating func disarm() {
        deadline = nil
    }

    func hasExpired(at now: Date = Date()) -> Bool {
        guard let deadline else { return false }
        return now >= deadline
    }
}

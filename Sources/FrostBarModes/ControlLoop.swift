// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation
import FrostBarCore
import FrostBarProfiles

/// Manual profile selection with a deadline; when it expires the app- and
/// profile-based resolution takes over again.
public struct ManualOverride: Sendable, Equatable {
    public var profileID: Profile.ID
    public var expiresAt: Date

    public init(profileID: Profile.ID, expiresAt: Date) {
        self.profileID = profileID
        self.expiresAt = expiresAt
    }

    public func isActive(at date: Date) -> Bool {
        date < expiresAt
    }
}

/// One evaluation tick.
///
/// Reads a snapshot, resolves the profile, evaluates it, lets the safety policy
/// review the result and applies it. All collaborators are protocols, so the
/// loop is exercised in unit tests with fakes and a fake clock.
public actor ControlLoop {
    private let sensors: any SensorProviding
    private let fans: any FanControlling
    private let evaluator: any ModeEvaluating
    private let resolver: ProfileResolver
    private let safety: FanSafetyPolicy
    private let log: any Logging

    private var state: EvaluationState
    private var manualOverride: ManualOverride?
    private var lastSnapshot: SensorSnapshot?

    public init(
        sensors: any SensorProviding,
        fans: any FanControlling,
        evaluator: any ModeEvaluating,
        resolver: ProfileResolver = ProfileResolver(),
        safety: FanSafetyPolicy = FanSafetyPolicy(),
        log: any Logging = NoopLogger(),
        initialState: EvaluationState = .initial
    ) {
        self.sensors = sensors
        self.fans = fans
        self.evaluator = evaluator
        self.resolver = resolver
        self.safety = safety
        self.log = log
        self.state = initialState
    }

    public func setManualOverride(_ override: ManualOverride?) {
        manualOverride = override
    }

    public func currentState() -> EvaluationState {
        state
    }

    /// Snapshot used by the most recent tick, so the UI does not need a second
    /// SMC read to render the values that were just evaluated.
    public func currentSnapshot() -> SensorSnapshot? {
        lastSnapshot
    }

    public func tick(
        configuration: Configuration,
        context: AppContext,
        capabilities: SystemCapabilities,
        now: Date
    ) async -> EvaluationResult {
        do {
            let snapshot = try await sensors.snapshot()
            lastSnapshot = snapshot

            if let override = manualOverride, !override.isActive(at: now) {
                manualOverride = nil
            }

            guard let resolution = resolver.resolve(
                configuration: configuration,
                context: context,
                manualOverride: manualOverride?.profileID
            ) else {
                return .hold
            }

            let input = EvaluationInput(
                snapshot: snapshot,
                profile: resolution.profile,
                context: context,
                capabilities: capabilities,
                advanced: configuration.advanced,
                state: state,
                now: now
            )

            var result = evaluator.evaluate(input)

            if case let .apply(proposal, reason) = result {
                switch safety.review(proposal, input: input) {
                case let .allow(command):
                    result = .apply(command, reason)
                case let .clamped(command, violations):
                    result = .apply(command, DecisionReason(
                        ruleID: reason.ruleID,
                        summary: "\(reason.summary) (limited: \(violations.map(\.rawValue).joined(separator: ", ")))",
                        values: reason.values
                    ))
                case let .forceAutomatic(violation):
                    result = .automatic(DecisionReason(
                        ruleID: reason.ruleID,
                        summary: "Safety override: \(violation.rawValue)",
                        values: reason.values
                    ))
                }
            }

            try await apply(result, now: now)
            return result
        } catch {
            log.log(.error, "Control tick failed: \(error.localizedDescription)")
            return .hold
        }
    }

    private func apply(_ result: EvaluationResult, now: Date) async throws {
        switch result {
        case let .apply(command, _):
            try await fans.apply(command)
            state.lastCommand = command
            if case let .fixed(rpm) = command {
                state.lastTargetRPM = rpm
            }
            state.lastChangeAt = now
            state.lastWriteAt = now

        case .automatic:
            try await fans.restoreAutomatic()
            state.lastCommand = .automatic
            state.lastChangeAt = now

        case .hold, .refused:
            break
        }
    }
}

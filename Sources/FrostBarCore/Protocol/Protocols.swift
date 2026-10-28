// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation

// MARK: - Reading

public protocol SensorProviding: Sendable {
    func capabilities() async throws -> SystemCapabilities
    func snapshot() async throws -> SensorSnapshot
    func stream(every interval: TimeInterval) -> AsyncThrowingStream<SensorSnapshot, Error>
}

public extension SensorProviding {
    func stream(every interval: TimeInterval) -> AsyncThrowingStream<SensorSnapshot, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                let nanos = UInt64(max(interval, 0.1) * 1_000_000_000)
                do {
                    while !Task.isCancelled {
                        let value = try await snapshot()
                        continuation.yield(value)
                        try await Task.sleep(nanoseconds: nanos)
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

// MARK: - Control

public protocol FanControlling: Sendable {
    func inventory() async throws -> [FanDescriptor]
    func apply(_ command: FanCommand) async throws
    func restoreAutomatic() async throws
    func activeOverride() async -> FanCommand?
}

// MARK: - Evaluation

public protocol ModeEvaluating: Sendable {
    func evaluate(_ input: EvaluationInput) -> EvaluationResult
}

// MARK: - Triggers

public protocol AppTriggering: Sendable {
    func context() async -> AppContext
    func contexts() -> AsyncStream<AppContext>
}

// MARK: - Updates

public enum UpdateState: Sendable, Equatable {
    case idle
    case checking
    case upToDate
    case available(version: String)
    case downloading(progress: Double)
    case readyToInstall(version: String)
    case failed(message: String)
}

public protocol UpdateProviding: Sendable {
    var state: UpdateState { get async }
    func checkForUpdates(userInitiated: Bool) async
    func states() -> AsyncStream<UpdateState>
}

// MARK: - Storage

public enum ImportMergeStrategy: Sendable, Equatable {
    case replace
    case mergeByID
    case asNewProfile(name: String)
}

public protocol ConfigurationStoring: Sendable {
    func load() async throws -> Configuration
    func save(_ configuration: Configuration) async throws
    func export(_ configuration: Configuration) throws -> Data
    func importArchive(_ data: Data, strategy: ImportMergeStrategy) async throws -> Configuration
    func location() async -> URL
}

// MARK: - Helper lifecycle

public enum HelperStatus: Sendable, Equatable {
    case unknown
    case notRegistered
    case requiresApproval
    case enabled
    case notReachable

    public var isUsable: Bool { self == .enabled }
}

public protocol HelperManaging: Sendable {
    func status() async -> HelperStatus
    func install() async throws
    func uninstall() async throws
}

// MARK: - Capabilities

public protocol CapabilityProviding: Sendable {
    func capabilities() async -> SystemCapabilities
}

// MARK: - Support

public protocol TimeProvider: Sendable {
    var now: Date { get }
}

public struct SystemTimeProvider: TimeProvider {
    public init() {}
    public var now: Date { Date() }
}

public enum LogLevel: String, Sendable {
    case debug
    case info
    case warning
    case error
}

public protocol Logging: Sendable {
    func log(_ level: LogLevel, _ message: String)
}

public struct NoopLogger: Logging {
    public init() {}
    public func log(_ level: LogLevel, _ message: String) {}
}

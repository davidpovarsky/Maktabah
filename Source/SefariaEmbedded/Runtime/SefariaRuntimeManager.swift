//
//  SefariaRuntimeManager.swift
//  Maktabah
//
//  Downstream-owned single-flight lifecycle controller managing the embedded Sefaria-Mobile
//  React Native / Expo Hermes runtime.
//

import Foundation

public enum SefariaRuntimeState: Sendable, Equatable {
    case notStarted
    case starting
    case bootstrapping
    case ready
    case failed(message: String, retryable: Bool)
    case suspended

    public var isReady: Bool {
        if case .ready = self { return true }
        return false
    }
}

public actor SefariaRuntimeManager {
    public static let shared = SefariaRuntimeManager()

    private(set) public var state: SefariaRuntimeState = .notStarted
    private var startupTask: Task<Void, any Error>?

    private init() {}

    /// Ensures the Sefaria runtime is bootstrapped and ready.
    /// Thread-safe single-flight: concurrent callers await the same in-flight startup.
    public func ensureReady(timeoutSeconds: Double = 25.0) async throws {
        if state == .ready {
            return
        }

        if let task = startupTask {
            try await task.value
            return
        }

        let task = Task<Void, any Error> {
            try await self.performBootstrap(timeoutSeconds: timeoutSeconds)
        }
        self.startupTask = task

        do {
            try await task.value
            self.startupTask = nil
        } catch {
            self.startupTask = nil
            throw error
        }
    }

    private func performBootstrap(timeoutSeconds: Double) async throws {
        state = .starting

        // 1. Ensure the React Native host factory has mounted the root view on MainActor
        await MainActor.run {
            SefariaExpoLifecycleAdapter.shared.ensureHostStarted()
        }

        state = .bootstrapping
        let bridge = SefariaJSRPCBridge.shared

        // 2. Send runtime.initialize to JS
        let initResponse = try await bridge.call(
            method: "runtime.initialize",
            paramsJson: nil,
            timeoutMs: Int(timeoutSeconds * 1000)
        )

        guard initResponse.isSuccess else {
            let errorMsg = initResponse.error?.message ?? "Sefaria.init() failed in JavaScript"
            state = .failed(message: errorMsg, retryable: true)
            throw SefariaRPCError(code: "BOOTSTRAP_FAILED", message: errorMsg, retryable: true)
        }

        // 3. Trigger non-blocking search and update setup
        Task.detached {
            _ = try? await bridge.call(method: "runtime.postInitSearch", paramsJson: nil, timeoutMs: 10000)
            _ = try? await bridge.call(method: "runtime.postInit", paramsJson: nil, timeoutMs: 30000)
        }

        state = .ready
    }

    /// Resets the runtime state after failure or during diagnostics.
    public func reset() {
        startupTask?.cancel()
        startupTask = nil
        state = .notStarted
        Task {
            await SefariaJSRPCBridge.shared.cancelAll(reason: "Runtime reset")
        }
    }

    /// Marks runtime as ready directly when native host completes startup.
    public func markReady() {
        state = .ready
    }

    /// Marks runtime as failed with an authoritative message.
    public func markFailed(message: String, retryable: Bool = true) {
        state = .failed(message: message, retryable: retryable)
    }
}

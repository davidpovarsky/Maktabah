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

public struct SefariaCapabilityReadiness: Sendable, Equatable {
    public var hostReady: Bool = false
    public var catalogReady: Bool = false
    public var searchReady: Bool = false
    public var packagesReady: Bool = false

    public var isFullyReady: Bool {
        hostReady && catalogReady && searchReady && packagesReady
    }

    public init(
        hostReady: Bool = false,
        catalogReady: Bool = false,
        searchReady: Bool = false,
        packagesReady: Bool = false
    ) {
        self.hostReady = hostReady
        self.catalogReady = catalogReady
        self.searchReady = searchReady
        self.packagesReady = packagesReady
    }
}

public actor SefariaRuntimeManager {
    public static let shared = SefariaRuntimeManager()

    private(set) public var state: SefariaRuntimeState = .notStarted
    private(set) public var readiness = SefariaCapabilityReadiness()

    private var startupTask: Task<Void, any Error>?
    private var searchInitTask: Task<Void, any Error>?
    private var packagesInitTask: Task<Void, any Error>?

    private init() {}

    /// Ensures the Sefaria runtime and catalog are bootstrapped and ready.
    /// Thread-safe single-flight: concurrent callers await the same in-flight startup.
    public func ensureReady(timeoutSeconds: Double = 25.0) async throws {
        try await ensureCatalogReady(timeoutSeconds: timeoutSeconds)
    }

    /// Ensures host and catalog (TOC / index) are ready.
    public func ensureCatalogReady(timeoutSeconds: Double = 25.0) async throws {
        if readiness.catalogReady && state == .ready {
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

    /// Ensures search index and engine are ready via postInitSearch.
    public func ensureSearchReady(timeoutSeconds: Double = 30.0) async throws {
        try await ensureCatalogReady(timeoutSeconds: timeoutSeconds)

        if readiness.searchReady {
            return
        }

        if let task = searchInitTask {
            try await task.value
            return
        }

        let task = Task<Void, any Error> {
            try await self.performSearchInit()
        }
        self.searchInitTask = task

        do {
            try await task.value
            self.searchInitTask = nil
        } catch {
            self.searchInitTask = nil
            throw error
        }
    }

    /// Ensures package state and download engine are ready via postInit / packageSetupProtocol.
    public func ensurePackagesReady(timeoutSeconds: Double = 30.0) async throws {
        try await ensureCatalogReady(timeoutSeconds: timeoutSeconds)

        if readiness.packagesReady {
            return
        }

        if let task = packagesInitTask {
            try await task.value
            return
        }

        let task = Task<Void, any Error> {
            try await self.performPackagesInit()
        }
        self.packagesInitTask = task

        do {
            try await task.value
            self.packagesInitTask = nil
        } catch {
            self.packagesInitTask = nil
            throw error
        }
    }

    /// Ensures all capabilities (catalog, search, and packages) are ready.
    public func ensureFullyReady(timeoutSeconds: Double = 35.0) async throws {
        try await ensureCatalogReady(timeoutSeconds: timeoutSeconds)
        try await ensureSearchReady(timeoutSeconds: timeoutSeconds)
        try await ensurePackagesReady(timeoutSeconds: timeoutSeconds)
    }

    private func performBootstrap(timeoutSeconds: Double) async throws {
        state = .starting

        // 1. Ensure the React Native host factory has mounted the root view on MainActor
        await MainActor.run {
            SefariaExpoLifecycleAdapter.shared.ensureHostStarted()
        }
        readiness.hostReady = true

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

        readiness.catalogReady = true
        state = .ready

        // 3. Eagerly trigger search and packages setup tasks in background
        if searchInitTask == nil {
            searchInitTask = Task {
                try await self.performSearchInit()
            }
        }
        if packagesInitTask == nil {
            packagesInitTask = Task {
                try await self.performPackagesInit()
            }
        }
    }

    private func performSearchInit() async throws {
        let bridge = SefariaJSRPCBridge.shared
        let response = try await bridge.call(method: "runtime.postInitSearch", paramsJson: nil, timeoutMs: 15000)
        guard response.isSuccess else {
            let errorMsg = response.error?.message ?? "runtime.postInitSearch failed"
            throw SefariaRPCError(code: "SEARCH_INIT_FAILED", message: errorMsg, retryable: true)
        }
        readiness.searchReady = true
    }

    private func performPackagesInit() async throws {
        let bridge = SefariaJSRPCBridge.shared
        let response = try await bridge.call(method: "runtime.postInit", paramsJson: nil, timeoutMs: 30000)
        guard response.isSuccess else {
            let errorMsg = response.error?.message ?? "runtime.postInit failed"
            throw SefariaRPCError(code: "PACKAGES_INIT_FAILED", message: errorMsg, retryable: true)
        }
        readiness.packagesReady = true
    }

    /// Resets the runtime state after failure or during diagnostics.
    public func reset() {
        startupTask?.cancel()
        searchInitTask?.cancel()
        packagesInitTask?.cancel()
        startupTask = nil
        searchInitTask = nil
        packagesInitTask = nil
        readiness = SefariaCapabilityReadiness()
        state = .notStarted
        Task {
            await SefariaJSRPCBridge.shared.cancelAll(reason: "Runtime reset")
        }
    }

    /// Marks runtime as ready directly when native host completes startup.
    public func markReady() {
        readiness = SefariaCapabilityReadiness(
            hostReady: true,
            catalogReady: true,
            searchReady: true,
            packagesReady: true
        )
        state = .ready
    }

    /// Marks runtime as failed with an authoritative message.
    public func markFailed(message: String, retryable: Bool = true) {
        state = .failed(message: message, retryable: retryable)
    }
}

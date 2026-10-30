//
//  ChavrusaSefariaBridgeModule.swift
//  Maktabah
//
//  Downstream-owned native module bridging Swift to Sefaria-Mobile React Native runtime.
//  Registered with React Native's NativeModules and provides robust bidirectional
//  communication without relying on unverified globals.
//

import Foundation

#if canImport(React)
import React
#endif

#if canImport(React)
@objc(ChavrusaSefariaBridgeModule)
final class ChavrusaSefariaBridgeModule: RCTEventEmitter, SefariaJSTransport, @unchecked Sendable {
    private let stateLock = NSLock()
    private var _customExecutor: (@Sendable (String) async throws -> Void)?
    private var _hasListeners: Bool = false

    private var hasListeners: Bool {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return _hasListeners
        }
        set {
            stateLock.lock()
            defer { stateLock.unlock() }
            _hasListeners = newValue
        }
    }

    private var customExecutor: (@Sendable (String) async throws -> Void)? {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return _customExecutor
        }
        set {
            stateLock.lock()
            defer { stateLock.unlock() }
            _customExecutor = newValue
        }
    }

    override init() {
        super.init()
        Task {
            await SefariaJSRPCBridge.shared.setTransport(self)
        }
    }

    override class func moduleName() -> String! {
        return "ChavrusaSefariaBridgeModule"
    }

    override class func requiresMainQueueSetup() -> Bool {
        return true
    }

    override func supportedEvents() -> [String]! {
        return ["onSefariaRPCRequest"]
    }

    override func startObserving() {
        hasListeners = true
    }

    override func stopObserving() {
        hasListeners = false
    }

    override func invalidate() {
        hasListeners = false
        Task {
            await SefariaJSRPCBridge.shared.setTransport(nil)
        }
        super.invalidate()
    }

    func setJSExecutor(_ executor: @escaping @Sendable (String) async throws -> Void) {
        self.customExecutor = executor
    }

    // MARK: - SefariaJSTransport (Swift -> JS)

    func sendToJS(jsonString: String) async throws {
        if let custom = customExecutor {
            try await custom(jsonString)
            return
        }

        guard hasListeners else {
            throw SefariaRPCError(
                code: "BRIDGE_NOT_READY",
                message: "React Native event emitter has no active listeners",
                retryable: true
            )
        }

        await MainActor.run {
            self.sendEvent(withName: "onSefariaRPCRequest", body: jsonString)
        }
    }

    // MARK: - JS -> Native Callbacks

    @objc func deliverResponse(_ jsonString: String) {
        Task {
            await SefariaJSRPCBridge.shared.handleIncomingResponse(jsonString: jsonString)
        }
    }

    @objc func deliverEvent(_ jsonString: String) {
        Task {
            await SefariaJSRPCBridge.shared.handleIncomingEvent(jsonString: jsonString)
        }
    }

    @objc func echo(_ message: String, resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
        resolver("echo:\(message)")
    }
}

#else

final class ChavrusaSefariaBridgeModule: NSObject, SefariaJSTransport, @unchecked Sendable {
    private let stateLock = NSLock()
    private var _customExecutor: (@Sendable (String) async throws -> Void)?

    private var customExecutor: (@Sendable (String) async throws -> Void)? {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return _customExecutor
        }
        set {
            stateLock.lock()
            defer { stateLock.unlock() }
            _customExecutor = newValue
        }
    }

    override init() {
        super.init()
        Task {
            await SefariaJSRPCBridge.shared.setTransport(self)
        }
    }

    func setJSExecutor(_ executor: @escaping @Sendable (String) async throws -> Void) {
        self.customExecutor = executor
    }

    func sendToJS(jsonString: String) async throws {
        if let custom = customExecutor {
            try await custom(jsonString)
            return
        }
        throw SefariaRPCError(
            code: "BRIDGE_NOT_ATTACHED",
            message: "RCTBridge is not available in non-React environment",
            retryable: true
        )
    }

    func deliverResponse(_ jsonString: String) {
        Task {
            await SefariaJSRPCBridge.shared.handleIncomingResponse(jsonString: jsonString)
        }
    }

    func deliverEvent(_ jsonString: String) {
        Task {
            await SefariaJSRPCBridge.shared.handleIncomingEvent(jsonString: jsonString)
        }
    }
}
#endif

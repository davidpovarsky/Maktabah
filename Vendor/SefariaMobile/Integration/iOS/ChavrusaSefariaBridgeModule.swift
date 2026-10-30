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
    nonisolated(unsafe) private static var activeInstance: ChavrusaSefariaBridgeModule?
    private var customExecutor: (@Sendable (String) async throws -> Void)?
    private var hasListeners: Bool = false

    override init() {
        super.init()
        ChavrusaSefariaBridgeModule.activeInstance = self
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

    func setJSExecutor(_ executor: @escaping @Sendable (String) async throws -> Void) {
        self.customExecutor = executor
    }

    // MARK: - SefariaJSTransport (Swift -> JS)

    func sendToJS(jsonString: String) async throws {
        if let custom = customExecutor {
            try await custom(jsonString)
            return
        }

        guard let active = ChavrusaSefariaBridgeModule.activeInstance else {
            throw SefariaRPCError(
                code: "BRIDGE_NOT_ATTACHED",
                message: "ChavrusaSefariaBridgeModule instance not created by React Native runtime",
                retryable: true
            )
        }

        active.sendEvent(withName: "onSefariaRPCRequest", body: jsonString)
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
    static let shared = ChavrusaSefariaBridgeModule()
    private var customExecutor: (@Sendable (String) async throws -> Void)?

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

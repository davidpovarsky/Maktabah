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

@objc(ChavrusaSefariaBridgeModule)
public final class ChavrusaSefariaBridgeModule: NSObject, SefariaJSTransport {
    public static let shared = ChavrusaSefariaBridgeModule()

    #if canImport(React)
    public weak var bridge: RCTBridge?
    #endif

    public typealias JSDispatcherBlock = @convention(block) (String) -> Void
    private var jsDispatcher: JSDispatcherBlock?
    private var customExecutor: (@Sendable (String) async throws -> Void)?

    override public init() {
        super.init()
        Task {
            await SefariaJSRPCBridge.shared.setTransport(self)
        }
    }

    public func setJSExecutor(_ executor: @escaping @Sendable (String) async throws -> Void) {
        self.customExecutor = executor
    }

    // MARK: - JS -> Native Registration

    @objc public func registerJSDispatcher(_ dispatcher: @escaping JSDispatcherBlock) {
        self.jsDispatcher = dispatcher
    }

    // MARK: - SefariaJSTransport (Swift -> JS)

    public func sendToJS(jsonString: String) async throws {
        if let custom = customExecutor {
            try await custom(jsonString)
            return
        }

        if let dispatcher = jsDispatcher {
            dispatcher(jsonString)
            return
        }

        #if canImport(React)
        if let bridge = self.bridge {
            bridge.enqueueJSCall(
                "ChavrusaRPCModule",
                method: "handleEnvelope",
                args: [jsonString],
                completion: nil
            )
            return
        }
        #endif

        throw SefariaRPCError(
            code: "BRIDGE_NOT_ATTACHED",
            message: "Neither JS dispatcher nor RCTBridge is attached to ChavrusaSefariaBridgeModule",
            retryable: true
        )
    }

    // MARK: - JS -> Native Callbacks

    @objc public func deliverResponse(_ jsonString: String) {
        Task {
            await SefariaJSRPCBridge.shared.handleIncomingResponse(jsonString: jsonString)
        }
    }

    @objc public func deliverEvent(_ jsonString: String) {
        Task {
            await SefariaJSRPCBridge.shared.handleIncomingEvent(jsonString: jsonString)
        }
    }

    #if canImport(React)
    @objc public static func requiresMainQueueSetup() -> Bool {
        return true
    }
    #endif
}

#if canImport(React)
extension ChavrusaSefariaBridgeModule: RCTBridgeModule {
    public static func moduleName() -> String! {
        return "ChavrusaSefariaBridgeModule"
    }
}
#endif

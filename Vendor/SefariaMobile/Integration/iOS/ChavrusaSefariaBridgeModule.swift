//
//  ChavrusaSefariaBridgeModule.swift
//  Maktabah
//
//  Downstream-owned native module bridging Swift to Sefaria-Mobile React Native runtime.
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

    private var jsExecutor: (@Sendable (String) async throws -> Void)?

    override public init() {
        super.init()
        Task {
            await SefariaJSRPCBridge.shared.setTransport(self)
        }
    }

    public func setJSExecutor(_ executor: @escaping @Sendable (String) async throws -> Void) {
        self.jsExecutor = executor
    }

    // MARK: - SefariaJSTransport

    public func sendToJS(jsonString: String) async throws {
        if let customExecutor = jsExecutor {
            try await customExecutor(jsonString)
            return
        }

        #if canImport(React)
        guard let bridge = self.bridge else {
            throw SefariaRPCError(
                code: "BRIDGE_NOT_ATTACHED",
                message: "RCTBridge is not attached to ChavrusaSefariaBridgeModule",
                retryable: true
            )
        }

        // Call global.__chavrusaHandleEnvelope on the JS thread
        bridge.enqueueJSCall(
            "__chavrusaHandleEnvelope",
            method: "call",
            args: [jsonString],
            completion: nil
        )
        #else
        // Mock / headless portable execution fallback
        #endif
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
}

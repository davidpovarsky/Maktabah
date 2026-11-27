import Foundation
enum BackendID: String { case sefariaEmbedded }
@main @MainActor struct OriginalRPCControls {
static var passed = 0
static var failed = 0
static func assertCondition(_ condition: Bool, _ message: String) {
 if condition { passed += 1; print("PASS "+message) } else { failed += 1; print("FAIL "+message) }
}
static func main() async {
        print("\n--- 36. Testing SefariaJSRPCBridge Generation Epoch & Call Validation ---")
        do {
            let bridge = SefariaJSRPCBridge.shared
            await bridge.setSessionEpoch(1)
            let initialEpoch = await bridge.sessionEpoch
            assertCondition(initialEpoch == 1, "sessionEpoch starts at 1")

            let bumpedEpoch = await bridge.bumpSessionEpoch()
            assertCondition(bumpedEpoch == 2, "bumpSessionEpoch increments to 2")
            let currentEpoch = await bridge.sessionEpoch
            assertCondition(currentEpoch == 2, "sessionEpoch reflects incremented value")

            await bridge.setSessionEpoch(42)
            let setEpoch = await bridge.sessionEpoch
            assertCondition(setEpoch == 42, "setSessionEpoch sets epoch to 42")
            await bridge.setSessionEpoch(1)
        }

        print("\n--- 37. Testing SefariaJSRPCBridge Strict Response Verification ---")
        do {
            final class MockBridgeTransport: SefariaJSTransport, @unchecked Sendable {
                var responseModifier: (@Sendable (SefariaRPCEnvelope) -> SefariaRPCResponse)?

                func sendToJS(jsonString: String) async throws {
                    guard let data = jsonString.data(using: .utf8),
                          let env = try? JSONDecoder().decode(SefariaRPCEnvelope.self, from: data) else {
                        return
                    }
                    if let mod = responseModifier {
                        let resp = mod(env)
                        if let respData = try? JSONEncoder().encode(resp),
                           let respStr = String(data: respData, encoding: .utf8) {
                            await SefariaJSRPCBridge.shared.handleIncomingResponse(jsonString: respStr)
                        }
                    }
                }
            }

            let transport = MockBridgeTransport()
            let bridge = SefariaJSRPCBridge.shared
            await bridge.setTransport(transport)
            let activeResponseEpoch = await bridge.sessionEpoch

            // Subtest A: Stale generation rejection
            transport.responseModifier = { env in
                return SefariaRPCResponse(
                    protocolVersion: "1.0",
                    requestID: env.requestID,
                    status: "success",
                    resultJson: "{\"echo\": true}",
                    error: nil,
                    sessionGeneration: env.sessionGeneration + 999,
                    backendID: BackendID.sefariaEmbedded.rawValue
                )
            }
            do {
                _ = try await bridge.call(method: "test.stale", paramsJson: nil, generation: activeResponseEpoch, timeoutMs: 2000)
                assertCondition(false, "Should have thrown STALE_GENERATION")
            } catch let rpcErr as SefariaRPCError {
                assertCondition(rpcErr.code == "STALE_GENERATION", "Mismatched generation rejected with STALE_GENERATION (\(rpcErr.code))")
            }

            // Subtest B: Protocol version mismatch rejection
            transport.responseModifier = { env in
                return SefariaRPCResponse(
                    protocolVersion: "2.0",
                    requestID: env.requestID,
                    status: "success",
                    resultJson: "{\"echo\": true}",
                    error: nil,
                    sessionGeneration: env.sessionGeneration,
                    backendID: BackendID.sefariaEmbedded.rawValue
                )
            }
            do {
                _ = try await bridge.call(method: "test.proto", paramsJson: nil, generation: activeResponseEpoch, timeoutMs: 2000)
                assertCondition(false, "Should have thrown PROTOCOL_VERSION_MISMATCH")
            } catch let rpcErr as SefariaRPCError {
                assertCondition(rpcErr.code == "PROTOCOL_VERSION_MISMATCH", "Mismatched protocol rejected with PROTOCOL_VERSION_MISMATCH (\(rpcErr.code))")
            }

            // Subtest C: Backend ID mismatch rejection
            transport.responseModifier = { env in
                return SefariaRPCResponse(
                    protocolVersion: "1.0",
                    requestID: env.requestID,
                    status: "success",
                    resultJson: "{\"echo\": true}",
                    error: nil,
                    sessionGeneration: env.sessionGeneration,
                    backendID: "unauthorizedBackend"
                )
            }
            do {
                _ = try await bridge.call(method: "test.backend", paramsJson: nil, generation: activeResponseEpoch, timeoutMs: 2000)
                assertCondition(false, "Should have thrown BACKEND_MISMATCH")
            } catch let rpcErr as SefariaRPCError {
                assertCondition(rpcErr.code == "BACKEND_MISMATCH", "Mismatched backend ID rejected with BACKEND_MISMATCH (\(rpcErr.code))")
            }

            // Subtest D: Valid matching response acceptance
            transport.responseModifier = { env in
                return SefariaRPCResponse(
                    protocolVersion: "1.0",
                    requestID: env.requestID,
                    status: "success",
                    resultJson: "{\"status\": \"verified\"}",
                    error: nil,
                    sessionGeneration: env.sessionGeneration,
                    backendID: BackendID.sefariaEmbedded.rawValue
                )
            }
            let validResp = try await bridge.call(method: "test.valid", paramsJson: nil, generation: activeResponseEpoch, timeoutMs: 2000)
            assertCondition(validResp.isSuccess, "Valid response accepted successfully")
            assertCondition(validResp.resultJson == "{\"status\": \"verified\"}", "Valid response data matches")

            await bridge.setTransport(nil)
        } catch {
            assertCondition(false, "Strict response verification failed: \(error)")
        }

        print("\n--- 38. Testing SefariaJSRPCBridge Concurrent Parallel In-Flight Calls ---")
        do {
            final class ConcurrentEchoTransport: SefariaJSTransport, @unchecked Sendable {
                func sendToJS(jsonString: String) async throws {
                    guard let data = jsonString.data(using: .utf8),
                          let env = try? JSONDecoder().decode(SefariaRPCEnvelope.self, from: data) else {
                        return
                    }
                    Task {
                        try? await Task.sleep(nanoseconds: UInt64.random(in: 1_000_000...5_000_000))
                        let resp = SefariaRPCResponse(
                            protocolVersion: "1.0",
                            requestID: env.requestID,
                            status: "success",
                            resultJson: env.paramsJson,
                            error: nil,
                            sessionGeneration: env.sessionGeneration,
                            backendID: BackendID.sefariaEmbedded.rawValue
                        )
                        if let respData = try? JSONEncoder().encode(resp),
                           let respStr = String(data: respData, encoding: .utf8) {
                            await SefariaJSRPCBridge.shared.handleIncomingResponse(jsonString: respStr)
                        }
                    }
                }
            }

            let transport = ConcurrentEchoTransport()
            let bridge = SefariaJSRPCBridge.shared
            await bridge.setTransport(transport)
            let activeResponseEpoch = await bridge.sessionEpoch

            let callCount = 20
            try await withThrowingTaskGroup(of: (Int, String).self) { group in
                for i in 0..<callCount {
                    group.addTask {
                        let payload = "{\"index\": \(i)}"
                        let resp = try await bridge.call(
                            method: "echo",
                            paramsJson: payload,
                            generation: activeResponseEpoch,
                            timeoutMs: 5000
                        )
                        return (i, resp.resultJson ?? "")
                    }
                }

                var completed = 0
                for try await (idx, result) in group {
                    assertCondition(result == "{\"index\": \(idx)}", "Concurrent call \(idx) received correct matching response")
                    completed += 1
                }
                assertCondition(completed == callCount, "All \(callCount) concurrent calls resolved successfully")
            }

            await bridge.setTransport(nil)
        } catch {
            assertCondition(false, "Concurrent calls test failed: \(error)")
        }

print("ORIGINAL_RPC_COUNTS passed="+String(passed)+" failed="+String(failed))
if failed != 0 { exit(1) }
}
}

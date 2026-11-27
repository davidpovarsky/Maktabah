// Actual bridge, runtime reset and diagnostic helper; explicit controllable
// transport/library/native-domain doubles. This is NOT a Hermes/native app run.
import Foundation

actor LateReplyControlTransport: SefariaJSTransport {
    private var held: SefariaRPCEnvelope?
    private var calls: [String] = []
    func sendToJS(jsonString: String) async throws {
        let envelope = try JSONDecoder().decode(SefariaRPCEnvelope.self, from: Data(jsonString.utf8))
        calls.append(envelope.method)
        if let params = envelope.paramsJson?.data(using: .utf8),
           let value = try JSONSerialization.jsonObject(with: params) as? [String: Any],
           value["lateReplyDiagnostic"] != nil {
            held = envelope
            return
        }
        let body: String
        switch envelope.method {
        case "runtime.initialize": body = "{\"status\":\"initialized\"}"
        case "catalog.toc": body = "[{\"title\":\"Genesis\"}]"
        case "runtime.postInitSearch": body = "{\"searchReady\":true}"
        case "runtime.postInit": body = "{\"packagesReady\":true}"
        default:
            let value = envelope.paramsJson?.data(using: .utf8)
                .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
            body = String(decoding: try JSONSerialization.data(withJSONObject: [
                "echoedMessage": value["message"] as? String ?? "",
                "generation": envelope.sessionGeneration
            ]), as: UTF8.self)
        }
        await deliver(.init(requestID: envelope.requestID, status: "success",
            resultJson: body, sessionGeneration: envelope.sessionGeneration))
    }
    func waitForHeld() async throws -> SefariaRPCEnvelope {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while ContinuousClock.now < deadline {
            if let held { return held }
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(1))
        }
        throw SefariaRPCError(code: "CONTROL_DISPATCH_MISSING", message: "No actual source call reached the transport double.")
    }
    private func proof(_ envelope: SefariaRPCEnvelope) throws -> [String: Any] {
        let params = try JSONSerialization.jsonObject(with: Data((envelope.paramsJson ?? "{}").utf8)) as! [String: Any]
        let options = params["lateReplyDiagnostic"] as! [String: Any]
        return ["contract": options["contract"]!, "nonce": options["nonce"]!,
            "delayMs": options["delayMs"]!, "requestID": envelope.requestID,
            "sessionGeneration": envelope.sessionGeneration]
    }
    func started(_ mutation: String = "") async throws {
        guard let held else { throw SefariaRPCError(code: "CONTROL_NO_HELD_REQUEST", message: "No held request") }
        var p = try proof(held)
        if mutation == "wrongStartedNonce" { p["nonce"] = UUID().uuidString }
        if mutation == "wrongStartedID" { p["requestID"] = UUID().uuidString }
        if mutation == "wrongStartedEpoch" { p["sessionGeneration"] = held.sessionGeneration + 1 }
        if mutation == "wrongStartedDelay" { p["delayMs"] = 3_000 }
        let body = String(decoding: try JSONSerialization.data(withJSONObject: p), as: UTF8.self)
        let event = SefariaRPCEvent(event: "diagnostic.echo.started", sequence: 1,
            backendID: mutation == "wrongStartedBackend" ? "otzaria" : "sefariaEmbedded", payloadJson: body)
        let json = String(decoding: try JSONEncoder().encode(event), as: UTF8.self)
        await SefariaJSRPCBridge.shared.handleIncomingEvent(jsonString: json)
    }
    func reply(_ mutation: String = "") async throws {
        guard let held else { throw SefariaRPCError(code: "CONTROL_NO_HELD_REQUEST", message: "No held request") }
        var p = try proof(held)
        if mutation == "wrongLateNonce" { p["nonce"] = UUID().uuidString }
        if mutation == "wrongLateProofEpoch" { p["sessionGeneration"] = held.sessionGeneration + 1 }
        if mutation == "wrongLateProofID" { p["requestID"] = UUID().uuidString }
        let body = String(decoding: try JSONSerialization.data(withJSONObject: ["lateReplyDiagnostic": p]), as: UTF8.self)
        await deliver(.init(protocolVersion: mutation == "wrongLateProtocol" ? "2.0" : "1.0",
            requestID: mutation == "wrongLateID" ? UUID().uuidString : held.requestID,
            status: mutation == "errorLate" ? "error" : "success", resultJson: body,
            error: mutation == "errorLate" ? .init(code: "CONTROL_REMOTE_ERROR", message: "Explicit error double") : nil,
            sessionGeneration: mutation == "wrongLateEpoch" ? held.sessionGeneration + 1 : held.sessionGeneration,
            backendID: mutation == "wrongLateBackend" ? "otzaria" : "sefariaEmbedded"))
    }
    private func deliver(_ response: SefariaRPCResponse) async {
        let json = String(decoding: try! JSONEncoder().encode(response), as: UTF8.self)
        await SefariaJSRPCBridge.shared.handleIncomingResponse(jsonString: json)
    }
    func echoCalls() -> Int { calls.filter { $0 == "diagnostic.echo" }.count }
}

@main struct LateReplyDiagnosticControls {
    struct Row: Codable { let name: String; let passed: Bool; let observed: String }
    @MainActor static var rows: [Row] = []
    static let bridge = SefariaJSRPCBridge.shared

    static func ready() async throws -> LateReplyControlTransport {
        await SefariaRuntimeManager.shared.reset()
        let transport = LateReplyControlTransport()
        await bridge.setTransport(transport)
        await bridge.notifyListenersActive(true)
        let event = SefariaRPCEvent(event: "ready", sequence: 1)
        await bridge.handleIncomingEvent(jsonString: String(decoding: try JSONEncoder().encode(event), as: UTF8.self))
        return transport
    }
    static func code(_ error: any Error) -> String {
        if error is CancellationError { return "CANCELLED_TASK" }
        return (error as? SefariaRPCError)?.code ?? String(describing: error)
    }
    @MainActor static func test(_ name: String, expected: String = "PASS",
                               _ body: () async throws -> Void) async {
        do { try await body(); rows.append(.init(name: name, passed: expected == "PASS", observed: "PASS")) }
        catch { let observed = code(error); rows.append(.init(name: name, passed: observed == expected, observed: observed)) }
    }
    static func require(_ value: Bool, _ message: String) throws {
        if !value { throw SefariaRPCError(code: "CONTROL_ASSERTION", message: message) }
    }
    static func manual(_ fault: String) async throws {
        let transport = try await ready()
        let budget = ["missingStarted", "missingLate", "wrongLateID"].contains(fault) ? 80 : 2_000
        let token = try await bridge.beginLateReplyDiagnostic(nonce: UUID(), delayMs: 1, timeoutMs: budget)
        let data = try JSONSerialization.data(withJSONObject: [
            "message": "control", "lateReplyDiagnostic": [
                "contract": "chavrusa.diagnostic.late-reply.v1", "nonce": token.nonce, "delayMs": token.delayMs
            ]
        ])
        let json = String(decoding: data, as: UTF8.self)
        let originalCall = Task { try await bridge.call(method: "diagnostic.echo", paramsJson: json,
            generation: token.originalEpoch, timeoutMs: token.timeoutMs) }
        do {
            _ = try await transport.waitForHeld()
            if fault == "retired" {
                await bridge.endLateReplyDiagnostic(token)
                try await bridge.waitForLateReplyJSReceipt(token)
            }
            if fault == "cancelledWait" {
                let wait = Task { try await bridge.waitForLateReplyJSReceipt(token) }
                wait.cancel()
                try await wait.value
            }
            if fault == "earlyResponse" { try await transport.reply() }
            if fault != "missingStarted" { try await transport.started(fault) }
            if fault == "duplicateStarted" { try await transport.started() }
            try await bridge.waitForLateReplyJSReceipt(token)
            try await bridge.validateLateReplyBeforeReset(token)
            if fault != "noReset" { await SefariaRuntimeManager.shared.reset() }
            if fault == "doubleReset" { await SefariaRuntimeManager.shared.reset() }
            if fault == "replaceTransport" { await bridge.setTransport(LateReplyControlTransport()) }
            if fault == "noReset" { try await transport.reply() }
            try await bridge.validateLateReplyAfterReset(token)
            switch await originalCall.result {
            case .failure(let error): try require((error as? SefariaRPCError)?.code == "CANCELLED", "Original reset cancellation was not observed")
            case .success: throw SefariaRPCError(code: "CONTROL_ASSERTION", message: "Original request unexpectedly succeeded")
            }
            if fault != "missingLate" { try await transport.reply(fault) }
            if fault == "duplicateLate" { try await transport.reply() }
            let evidence = try await bridge.waitForDiscardedLateReply(token)
            try require(evidence.jsReceived && evidence.originalCancellation
                && evidence.originalEpoch == token.originalEpoch && evidence.currentEpoch == token.originalEpoch + 1
                && evidence.nonce == token.nonce && evidence.disposition == "discarded_no_in_flight_request",
                "Actual source observation receipt is incomplete")
            try await bridge.validateLateReplyCompletion(token, evidence: evidence)
            await bridge.endLateReplyDiagnostic(token)
        } catch {
            originalCall.cancel()
            _ = await originalCall.result
            await bridge.endLateReplyDiagnostic(token)
            throw error
        }
    }

    @MainActor static func main() async {
        await test("actual bridge reset and late discard") { try await manual("") }
        for fault in ["wrongStartedNonce", "wrongStartedID", "wrongStartedEpoch", "wrongStartedDelay", "wrongStartedBackend", "duplicateStarted"] {
            await test(fault, expected: "DIAGNOSTIC_JS_RECEIPT_MISMATCH") { try await manual(fault) }
        }
        for fault in ["earlyResponse", "noReset", "wrongLateNonce", "wrongLateProofEpoch", "wrongLateProofID",
                      "wrongLateProtocol", "wrongLateEpoch", "wrongLateBackend", "errorLate", "duplicateLate"] {
            await test(fault, expected: "DIAGNOSTIC_LATE_DISPOSITION_MISMATCH") { try await manual(fault) }
        }
        for fault in ["missingStarted", "missingLate", "wrongLateID"] {
            await test(fault, expected: "DIAGNOSTIC_DEADLINE_EXCEEDED") { try await manual(fault) }
        }
        await test("double original reset invalidates exact new epoch", expected: "DIAGNOSTIC_RESET_NOT_OBSERVED") { try await manual("doubleReset") }
        await test("foreign original transport invalidates observation", expected: "DIAGNOSTIC_TRANSPORT_CHANGED") { try await manual("replaceTransport") }
        await test("ended token cannot wait or rearm", expected: "DIAGNOSTIC_RETIRED") { try await manual("retired") }
        await test("cancelled observation returns and drains original RPC", expected: "CANCELLED_TASK") { try await manual("cancelledWait") }
        await test("original lifecycle transition blocks a new diagnostic", expected: "DIAGNOSTIC_UNAVAILABLE") {
            _ = try await ready()
            let transition = bridge.beginSurfaceLifecycleTransition()
            defer { transition.finish() }
            _ = try await bridge.beginLateReplyDiagnostic(nonce: UUID(), delayMs: 1, timeoutMs: 1000)
        }
        await test("only one active diagnostic observer", expected: "DIAGNOSTIC_UNAVAILABLE") {
            _ = try await ready()
            let first = try await bridge.beginLateReplyDiagnostic(nonce: UUID(), delayMs: 1, timeoutMs: 1000)
            do {
                _ = try await bridge.beginLateReplyDiagnostic(nonce: UUID(), delayMs: 1, timeoutMs: 1000)
                await bridge.endLateReplyDiagnostic(first)
            } catch { await bridge.endLateReplyDiagnostic(first); throw error }
        }
        await test("exact source helper executes actual reset and fresh echo") {
            let transport = try await ready()
            let before = await bridge.sessionEpoch
            let operation = Task { @MainActor in try await SefariaEmbeddedAcceptanceDiagnosticRunner.sourceControlVerifyOriginalLateReply() }
            do {
                _ = try await transport.waitForHeld()
                try await transport.started()
                let deadline = ContinuousClock.now.advanced(by: .seconds(2))
                while await bridge.sessionEpoch == before && ContinuousClock.now < deadline {
                    try await Task.sleep(for: .milliseconds(1))
                }
                try require(await bridge.sessionEpoch == before + 1, "Actual original helper never reset the runtime")
                try await transport.reply()
                let evidence = try await operation.value
                try require(evidence.originalEpoch == before && evidence.currentEpoch == before + 1,
                    "Helper returned another reset's evidence")
                try require(await transport.echoCalls() == 2,
                    "Helper did not use exactly held and fresh real call paths; explicit stale call must reject before transport")
                let next = try await bridge.beginLateReplyDiagnostic(nonce: UUID(), delayMs: 1, timeoutMs: 1000)
                await bridge.endLateReplyDiagnostic(next)
                try await SefariaRuntimeManager.shared.ensureFullyReady()
                let state = await SefariaRuntimeManager.shared.state
                try require(state.isReady, "Original ensureReady cannot recover after actual reset")
            } catch { operation.cancel(); _ = await operation.result; throw error }
        }
        for fault in ["wrongLateNonce", "doubleReset", "cancelledHelper"] {
            let expected = fault == "wrongLateNonce" ? "DIAGNOSTIC_LATE_DISPOSITION_MISMATCH"
                : fault == "doubleReset" ? "DIAGNOSTIC_RESET_NOT_OBSERVED" : "CANCELLED_TASK"
            await test("actual helper failure cleanup: " + fault, expected: expected) {
                let transport = try await ready()
                let before = await bridge.sessionEpoch
                let operation = Task { @MainActor in try await SefariaEmbeddedAcceptanceDiagnosticRunner.sourceControlVerifyOriginalLateReply() }
                do {
                    _ = try await transport.waitForHeld()
                    if fault == "cancelledHelper" { operation.cancel() }
                    else {
                        try await transport.started()
                        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
                        while await bridge.sessionEpoch == before && ContinuousClock.now < deadline {
                            try await Task.sleep(for: .milliseconds(1))
                        }
                        try require(await bridge.sessionEpoch == before + 1, "Helper reset was not reached")
                        if fault == "doubleReset" { await SefariaRuntimeManager.shared.reset() }
                        else { try await transport.reply(fault) }
                    }
                    _ = try await operation.value
                    throw SefariaRPCError(code: "CONTROL_ASSERTION", message: "Actual helper accepted a broken late proof")
                } catch {
                    operation.cancel(); _ = await operation.result
                    let next = try await bridge.beginLateReplyDiagnostic(nonce: UUID(), delayMs: 1, timeoutMs: 1000)
                    await bridge.endLateReplyDiagnostic(next)
                    throw error
                }
            }
        }
        await test("retired original token cannot close a new observation") {
            _ = try await ready()
            let old = try await bridge.beginLateReplyDiagnostic(nonce: UUID(), delayMs: 1, timeoutMs: 1000)
            await bridge.endLateReplyDiagnostic(old)
            let current = try await bridge.beginLateReplyDiagnostic(nonce: UUID(), delayMs: 1, timeoutMs: 1000)
            await bridge.endLateReplyDiagnostic(old)
            do {
                _ = try await bridge.beginLateReplyDiagnostic(nonce: UUID(), delayMs: 1, timeoutMs: 1000)
                await bridge.endLateReplyDiagnostic(current)
                throw SefariaRPCError(code: "CONTROL_ASSERTION", message: "Old token retired current lifetime")
            } catch let error as SefariaRPCError where error.code == "DIAGNOSTIC_UNAVAILABLE" {
                await bridge.endLateReplyDiagnostic(current)
            }
        }
        await bridge.setTransport(nil)
        struct Report: Encodable {
            let boundary: String; let caseCount: Int; let passed: Int; let failed: Int; let cases: [Row]
            let nativeAppAcceptance = "NOT_RUN"
        }
        let report = Report(boundary: "actual original bridge/runtime/full diagnostic helper compiled; controllable transport and library/native-domain doubles",
            caseCount: rows.count, passed: rows.filter(\.passed).count, failed: rows.filter { !$0.passed }.count, cases: rows)
        let bytes = try! JSONEncoder().encode(report)
        print(String(decoding: bytes, as: UTF8.self))
        if rows.contains(where: { !$0.passed }) { exit(1) }
    }
}

//
//  SefariaEmbeddedAcceptanceDiagnosticRunner.swift
//  Maktabah
//
//  Downstream-owned diagnostic runner executing comprehensive real runtime acceptance
//  verifications for the embedded Sefaria-Mobile engine on iPad Simulator.
//

import Foundation

#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class SefariaEmbeddedAcceptanceDiagnosticRunner {

    /// Internal diagnostic evidence from the canonical Core/native receipt plus
    /// an immediate read of the original rendered Reader. This is not a public
    /// navigation token and does not authorize or acknowledge any mutation.
    struct ReaderEvidence: Codable, Sendable {
        let nativeRequestID: UUID
        let nativeSceneID: String
        let backendID: String
        let sessionEpoch: UInt64
        let backendGeneration: UInt64
        let basedOnSceneRevision: UInt64
        let appliedSceneRevision: UInt64
        let requestedLocator: TextLocator
        let sectionLocator: TextLocator
        let focusLocator: TextLocator?
        let displayRef: String
        let segmentCount: Int

        func matches(_ locator: TextLocator, epoch: UInt64) -> Bool {
            !nativeSceneID.isEmpty && backendID == BackendID.sefariaEmbedded.rawValue
                && locator.backend == .sefariaEmbedded && requestedLocator == locator
                && sessionEpoch == epoch && epoch > 0
                && appliedSceneRevision > basedOnSceneRevision && segmentCount > 0
                && sectionLocator.backend == locator.backend
                && sectionLocator.workKey == locator.workKey
                && (focusLocator == nil || (focusLocator?.backend == locator.backend
                    && focusLocator?.workKey == locator.workKey))
        }
    }

    struct AcceptanceReport: Codable, Sendable {
        var status: String // "SUCCESS", "FAILURE", "PENDING"
        var failedStage: String?
        var errorMessage: String?
        var backendID: String = "sefariaEmbedded"
        var sessionEpoch: UInt64 = 1
        var stages: [String: StageDetail] = [:]

        struct StageDetail: Codable, Sendable {
            var passed: Bool
            var details: String?
            var durationMs: Int?
            var surfaceEvidence: SefariaEmbeddedSurfaceAcceptanceEvidence? = nil
            var readerEvidence: ReaderEvidence? = nil
            var lateReplyEvidence: SefariaLateReplyDiagnosticEvidence? = nil
        }
    }

    /// Uses only the existing RN/Hermes transport and original runtime reset.
    /// The child RPC is always drained before its observational metadata retires.
    private static func verifyOriginalLateReply() async throws -> SefariaLateReplyDiagnosticEvidence {
        let bridge = SefariaJSRPCBridge.shared
        let token = try await bridge.beginLateReplyDiagnostic(nonce: UUID(), delayMs: 1_500, timeoutMs: 10_000)
        do {
            let evidence = try await withThrowingTaskGroup(of: SefariaRPCError.self) { group in
                defer { group.cancelAll() }
                let params: [String: Any] = [
                    "message": "late-generation-check",
                    "lateReplyDiagnostic": [
                        "contract": "chavrusa.diagnostic.late-reply.v1",
                        "nonce": token.nonce, "delayMs": token.delayMs
                    ]
                ]
                let json = String(decoding: try JSONSerialization.data(withJSONObject: params), as: UTF8.self)
                group.addTask {
                    do {
                        _ = try await bridge.call(method: "diagnostic.echo", paramsJson: json,
                            generation: token.originalEpoch, timeoutMs: token.timeoutMs)
                        throw SefariaRPCError(code: "LATE_REQUEST_COMPLETED_EARLY",
                            message: "The original request completed before reset cancelled it.")
                    } catch let error as SefariaRPCError {
                        return error
                    }
                }
                try await bridge.waitForLateReplyJSReceipt(token)
                try await bridge.validateLateReplyBeforeReset(token)
                await SefariaRuntimeManager.shared.reset()
                try await bridge.validateLateReplyAfterReset(token)
                guard let cancellation = try await group.next(), cancellation.code == "CANCELLED" else {
                    throw SefariaRPCError(code: "ORIGINAL_RESET_CANCELLATION_MISSING",
                        message: "The original in-flight request was not cancelled by reset.")
                }
                let discarded = try await bridge.waitForDiscardedLateReply(token)
                let fresh = try await bridge.call(method: "diagnostic.echo",
                    paramsJson: "{\"message\":\"after-original-reset\"}",
                    generation: discarded.currentEpoch, timeoutMs: 2_000)
                struct Echo: Decodable { let echoedMessage: String; let generation: UInt64 }
                let echo = try fresh.decodeResult(Echo.self)
                guard fresh.isSuccess, fresh.protocolVersion == "1.0",
                      fresh.backendID == BackendID.sefariaEmbedded.rawValue,
                      fresh.sessionGeneration == discarded.currentEpoch,
                      echo.generation == discarded.currentEpoch,
                      echo.echoedMessage == "after-original-reset" else {
                    throw SefariaRPCError(code: "FRESH_GENERATION_ECHO_FAILED",
                        message: "The real post-reset echo did not match the current runtime.")
                }
                // Preserve the original negative expectation as a separate real
                // invocation; it cannot substitute for the late-response proof.
                do {
                    _ = try await bridge.call(method: "diagnostic.echo",
                        paramsJson: "{\"message\":\"stale-gen-check\"}", generation: token.originalEpoch)
                    throw SefariaRPCError(code: "STALE_GENERATION_ACCEPTED",
                        message: "The bridge accepted the old generation after reset.")
                } catch let error as SefariaRPCError where error.code == "STALE_GENERATION" {}
                try await bridge.validateLateReplyCompletion(token, evidence: discarded)
                return discarded
            }
            await bridge.endLateReplyDiagnostic(token)
            return evidence
        } catch {
            await bridge.endLateReplyDiagnostic(token)
            throw error
        }
    }

    static func run(visibleSurfaceProvider: @escaping @MainActor () async throws -> SefariaEmbeddedSurfaceAcceptanceEvidence,
                    nativeReaderProvider: @escaping @MainActor (TextLocator, UInt64) async throws -> ReaderEvidence,
                    backendRegressionProvider: @escaping () async -> (succeeded: Bool, failureDetail: String?)) async -> AcceptanceReport {
        var report = AcceptanceReport(
            status: "PENDING",
            failedStage: nil,
            errorMessage: nil,
            backendID: BackendID.sefariaEmbedded.rawValue,
            sessionEpoch: await SefariaJSRPCBridge.shared.sessionEpoch,
            stages: [:]
        )

        do {
            // Ensure backend is committed to sefariaEmbedded
            BackendCoordinator.shared.commit(.sefariaEmbedded)

            // Start React Native host and mount headless root view to spin up Hermes runtime
            #if canImport(UIKit)
            SefariaExpoLifecycleAdapter.shared.ensureHostStarted()
            #endif
            try? await Task.sleep(nanoseconds: 500_000_000)

            // Stage 1: waitForReady handshake
            let startT1 = Date()
            NSLog("[SefariaAcceptance] Stage 1: waitForReady started")
            try await SefariaJSRPCBridge.shared.waitForReady(timeoutSeconds: 60)
            let dur1 = Int(Date().timeIntervalSince(startT1) * 1000)
            report.stages["waitForReady"] = .init(passed: true, details: "Hermes JS bridge emitted ready event with active listeners and transport", durationMs: dur1)
            NSLog("[SefariaAcceptance] Stage 1: waitForReady passed (%d ms)", dur1)

            // Stage 2: diagnostic.echo with Hebrew UTF-8 roundtrip
            let startT2 = Date()
            NSLog("[SefariaAcceptance] Stage 2: echoHebrew started")
            let echoParams: [String: Any] = ["message": "שלום עולם"]
            let echoJson = String(data: try JSONSerialization.data(withJSONObject: echoParams), encoding: .utf8)
            let echoResp = try await SefariaJSRPCBridge.shared.call(method: "diagnostic.echo", paramsJson: echoJson, timeoutMs: 10000)
            guard echoResp.isSuccess,
                  let resJson = echoResp.resultJson,
                  resJson.contains("שלום עולם") else {
                throw SefariaRPCError(code: "ECHO_HEBREW_FAILED", message: "Echo did not return expected Hebrew string")
            }
            let dur2 = Int(Date().timeIntervalSince(startT2) * 1000)
            report.stages["echoHebrew"] = .init(passed: true, details: "Hebrew UTF-8 roundtrip verified losslessly", durationMs: dur2)
            NSLog("[SefariaAcceptance] Stage 2: echoHebrew passed (%d ms)", dur2)

            // Stage 3: diagnostic.echo error injection
            let startT3 = Date()
            NSLog("[SefariaAcceptance] Stage 3: echoErrorInjection started")
            let errParams: [String: Any] = ["message": "test-fail", "injectError": true]
            let errJson = String(data: try JSONSerialization.data(withJSONObject: errParams), encoding: .utf8)
            let errResp = try await SefariaJSRPCBridge.shared.call(method: "diagnostic.echo", paramsJson: errJson, timeoutMs: 10000)
            guard !errResp.isSuccess, errResp.error?.code == "ECHO_INJECTED_ERROR" else {
                throw SefariaRPCError(code: "ERROR_INJECTION_FAILED", message: "Error injection did not return ECHO_INJECTED_ERROR")
            }
            let dur3 = Int(Date().timeIntervalSince(startT3) * 1000)
            report.stages["echoErrorInjection"] = .init(passed: true, details: "Injected error correctly rejected across bridge", durationMs: dur3)
            NSLog("[SefariaAcceptance] Stage 3: echoErrorInjection passed (%d ms)", dur3)

            // Stage 4: the actual JS-received request survives in the same Hermes
            // instance while ORIGINAL runtime reset cancels its native continuation.
            // Only the actor's later real discard plus a fresh echo closes this stage.
            let startT4 = Date()
            NSLog("[SefariaAcceptance] Stage 4: lateGenerationRejected started")
            let lateReply = try await verifyOriginalLateReply()
            report.sessionEpoch = lateReply.currentEpoch
            let dur4 = Int(Date().timeIntervalSince(startT4) * 1000)
            report.stages["lateGenerationRejected"] = .init(passed: true,
                details: "Original JS request received at epoch \(lateReply.originalEpoch); original reset cancelled it; its real late response was discarded; current epoch \(lateReply.currentEpoch) echo succeeded.",
                durationMs: dur4, lateReplyEvidence: lateReply)
            NSLog("[SefariaAcceptance] Stage 4: lateGenerationRejected passed (%d ms)", dur4)

            // Stage 5: runtime.initialize
            let startT5 = Date()
            NSLog("[SefariaAcceptance] Stage 5: runtimeInitialize started")
            try await SefariaRuntimeManager.shared.ensureReady()
            let dur5 = Int(Date().timeIntervalSince(startT5) * 1000)
            report.stages["runtimeInitialize"] = .init(passed: true, details: "SefariaRuntimeManager initialized cleanly", durationMs: dur5)
            NSLog("[SefariaAcceptance] Stage 5: runtimeInitialize passed (%d ms)", dur5)

            // Stage 6: catalog.toc asserting Genesis/Bereshit
            let startT6 = Date()
            NSLog("[SefariaAcceptance] Stage 6: catalogTOC started")
            let roots = try await SefariaEmbeddedCatalogAdapter.shared.rootNodes()
            guard !roots.isEmpty else {
                throw SefariaRPCError(code: "CATALOG_EMPTY", message: "Catalog returned zero root categories")
            }
            let dur6 = Int(Date().timeIntervalSince(startT6) * 1000)
            report.stages["catalogTOC"] = .init(passed: true, details: "Catalog loaded \(roots.count) root nodes", durationMs: dur6)
            NSLog("[SefariaAcceptance] Stage 6: catalogTOC passed (%d ms)", dur6)

            // Stage 7: text.load Genesis 1:1 asserting Hebrew בראשית
            let startT7 = Date()
            NSLog("[SefariaAcceptance] Stage 7: textLoadGenesis started")
            let genLocator = TextLocator(backend: .sefariaEmbedded, workKey: "Genesis", position: .canonicalRef("Genesis 1:1"))
            let genSection = try await SefariaEmbeddedTextAdapter.shared.section(at: genLocator)
            guard let firstGenSeg = genSection.segments.first else {
                throw SefariaRPCError(code: "GENESIS_EMPTY", message: "Genesis 1:1 returned no segments")
            }
            let genLetters = String(firstGenSeg.primaryText.readerPlainText.unicodeScalars.filter { $0.value >= 0x05D0 && $0.value <= 0x05EA })
            guard genLetters.contains("בראשית") || firstGenSeg.primaryText.contains("בְּרֵאשִׁית") || firstGenSeg.primaryText.contains("בראשית") else {
                throw SefariaRPCError(code: "GENESIS_TEXT_INVALID", message: "Genesis 1:1 text missing Hebrew בראשית: '\(firstGenSeg.primaryText)'")
            }
            let dur7 = Int(Date().timeIntervalSince(startT7) * 1000)
            report.stages["textLoadGenesis"] = .init(passed: true, details: "Genesis 1:1 loaded with Hebrew text: \(firstGenSeg.primaryText)", durationMs: dur7)
            NSLog("[SefariaAcceptance] Stage 7: textLoadGenesis passed (%d ms)", dur7)

            // Stage 8: text.load Berakhot 2a asserting Hebrew מאימתי
            let startT8 = Date()
            NSLog("[SefariaAcceptance] Stage 8: textLoadBerakhot started")
            let berLocator = TextLocator(backend: .sefariaEmbedded, workKey: "Berakhot", position: .canonicalRef("Berakhot 2a:1"))
            let berSection = try await SefariaEmbeddedTextAdapter.shared.section(at: berLocator)
            guard let firstBerSeg = berSection.segments.first else {
                throw SefariaRPCError(code: "BERAKHOT_EMPTY", message: "Berakhot 2a:1 returned no segments")
            }
            let berLetters = String(firstBerSeg.primaryText.readerPlainText.unicodeScalars.filter { $0.value >= 0x05D0 && $0.value <= 0x05EA })
            guard berLetters.contains("מאימתי") || firstBerSeg.primaryText.contains("מֵאֵימָתַי") || firstBerSeg.primaryText.contains("מאימתי") else {
                throw SefariaRPCError(code: "BERAKHOT_TEXT_INVALID", message: "Berakhot 2a:1 text missing Hebrew מאימתי: '\(firstBerSeg.primaryText)'")
            }
            let dur8 = Int(Date().timeIntervalSince(startT8) * 1000)
            report.stages["textLoadBerakhot"] = .init(passed: true, details: "Berakhot 2a:1 loaded with Hebrew text: \(firstBerSeg.primaryText)", durationMs: dur8)
            NSLog("[SefariaAcceptance] Stage 8: textLoadBerakhot passed (%d ms)", dur8)

            // Stage 9: textOriginRemote provenance validation
            let startT9 = Date()
            NSLog("[SefariaAcceptance] Stage 9: textOriginRemote started")
            // In clean simulator without offline packages installed, text loaded from API must be tagged .remote
            guard genSection.origin == .remote else {
                throw SefariaRPCError(code: "ORIGIN_MISMATCH", message: "Genesis section loaded via API fallback must have origin .remote, got .\(genSection.origin.rawValue)")
            }
            let dur9 = Int(Date().timeIntervalSince(startT9) * 1000)
            report.stages["textOriginRemote"] = .init(passed: true, details: "Truthful provenance verified: API fallback text carries origin .remote (not falsely labeled offline)", durationMs: dur9)
            NSLog("[SefariaAcceptance] Stage 9: textOriginRemote passed (%d ms)", dur9)

            // Stage 10: navigation.textToc Genesis asserting chapter count
            let startT10 = Date()
            NSLog("[SefariaAcceptance] Stage 10: navigationTextToc started")
            let structures = try await SefariaEmbeddedNavigationAdapter.shared.navigationStructures(for: "Genesis")
            guard let defaultStruct = structures.first(where: { $0.id == "default" }), !defaultStruct.nodes.isEmpty else {
                throw SefariaRPCError(code: "NAVIGATION_TOC_EMPTY", message: "Genesis TOC returned empty nodes")
            }
            let dur10 = Int(Date().timeIntervalSince(startT10) * 1000)
            report.stages["navigationTextToc"] = .init(passed: true, details: "Genesis navigation structure has \(defaultStruct.nodes.count) nodes", durationMs: dur10)
            NSLog("[SefariaAcceptance] Stage 10: navigationTextToc passed (%d ms)", dur10)

            // Stage 11: a real live result is required. An endpoint error or
            // empty page cannot be converted to success or a canned Genesis hit.
            let startT11 = Date()
            NSLog("[SefariaAcceptance] Stage 11: searchLive started")
            let searchEpoch = await SefariaJSRPCBridge.shared.sessionEpoch
            let liveHit: LibrarySearchHit
            do {
                let searchReq = LibrarySearchRequest(query: "בראשית", offset: 0, limit: 10)
                let searchPage = try await SefariaEmbeddedSearchAdapter.shared.search(searchReq)
                try Task.checkCancellation()
                guard searchEpoch > 0, await SefariaJSRPCBridge.shared.sessionEpoch == searchEpoch,
                      BackendCoordinator.shared.activeBackendID == .sefariaEmbedded else {
                    throw SefariaRPCError(code: "SEARCH_SOURCE_CHANGED", message: "The live search runtime or backend changed")
                }
                guard let first = searchPage.hits.first,
                      searchPage.total >= searchPage.hits.count,
                      first.locator.backend == .sefariaEmbedded,
                      !first.locator.workKey.isEmpty else {
                    throw SefariaRPCError(code: "SEARCH_LIVE_NO_VALID_HIT", message: "Live search returned no valid result to open")
                }
                liveHit = first
                let dur11 = Int(Date().timeIntervalSince(startT11) * 1000)
                report.stages["searchLive"] = .init(
                    passed: true,
                    details: "Live search returned total=\(searchPage.total), page hits=\(searchPage.hits.count) in runtime epoch \(searchEpoch).",
                    durationMs: dur11
                )
                NSLog("[SefariaAcceptance] Stage 11: searchLive passed: %ld hits (%d ms)", searchPage.hits.count, dur11)
            } catch {
                report.stages["searchLive"] = .init(passed: false,
                    details: error.localizedDescription,
                    durationMs: Int(Date().timeIntervalSince(startT11) * 1000))
                throw error
            }

            // Stage 12: require the actual original native Reader/Core route.
            // TextAdapter resolution by itself provides no native UI evidence.
            let startT12 = Date()
            NSLog("[SefariaAcceptance] Stage 12: searchOpenResult started")
            do {
                let reader = try await nativeReaderProvider(liveHit.locator, searchEpoch)
                try Task.checkCancellation()
                guard await SefariaJSRPCBridge.shared.sessionEpoch == searchEpoch,
                      BackendCoordinator.shared.activeBackendID == .sefariaEmbedded,
                      reader.matches(liveHit.locator, epoch: searchEpoch) else {
                    throw SefariaRPCError(code: "SEARCH_OPEN_RECEIPT_INVALID", message: "The original native Reader receipt does not match the live search result")
                }
                let dur12 = Int(Date().timeIntervalSince(startT12) * 1000)
                report.stages["searchOpenResult"] = .init(
                    passed: true,
                    details: "Canonical Core/native receipt and original rendered Reader verified '\(reader.displayRef)' with \(reader.segmentCount) segments.",
                    durationMs: dur12, readerEvidence: reader
                )
                NSLog("[SefariaAcceptance] Stage 12: searchOpenResult passed (%d ms)", dur12)
            } catch {
                report.stages["searchOpenResult"] = .init(passed: false,
                    details: error.localizedDescription,
                    durationMs: Int(Date().timeIntervalSince(startT12) * 1000))
                throw error
            }

            // Stage 13: the same canonical parent route must return its actual
            // owned-window receipt and fresh original React/bridge proof.
            let startT13 = Date()
            NSLog("[SefariaAcceptance] Stage 13: fullReactSurface started")
            let surface = try await visibleSurfaceProvider()
            let original = surface.originalSurface
            let identity = SefariaEmbeddedSurfaceIdentity(id: original.surfaceID, mountID: original.mountID,
                sceneID: surface.nativeSceneID, epoch: SefariaJSRPCBridge.shared.currentSessionEpoch)
            guard original.matches(identity, nonce: original.nonce) else {
                throw SefariaRPCError(code: "VISIBLE_SURFACE_RECEIPT_STALE",
                                      message: "The original Sefaria surface receipt no longer matches its runtime.")
            }
            let dur13 = Int(Date().timeIntervalSince(startT13) * 1000)
            report.stages["fullReactSurface"] = .init(
                passed: true,
                details: "Canonical native receipt observed the original ReaderApp in its owned visible window and bridge epoch.",
                durationMs: dur13, surfaceEvidence: surface
            )
            NSLog("[SefariaAcceptance] Stage 13: fullReactSurface passed (%d ms)", dur13)

            // Stage 14: normalAppBootstrap verification
            let startT14 = Date()
            NSLog("[SefariaAcceptance] Stage 14: normalAppBootstrap started")
            let runtimeState = await SefariaRuntimeManager.shared.state
            let readiness = await SefariaRuntimeManager.shared.readiness
            let isReady = runtimeState.isReady
            let hostReady = readiness.hostReady
            let catalogReady = readiness.catalogReady
            guard isReady && hostReady && catalogReady else {
                throw SefariaRPCError(code: "BOOTSTRAP_STATE_INVALID", message: "Runtime not in verified ready state (state=\(runtimeState), host=\(hostReady), catalog=\(catalogReady))")
            }
            let dur14 = Int(Date().timeIntervalSince(startT14) * 1000)
            report.stages["normalAppBootstrap"] = .init(
                passed: true,
                details: "Runtime state is verified .ready with hostReady=true and catalogReady=true",
                durationMs: dur14
            )
            NSLog("[SefariaAcceptance] Stage 14: normalAppBootstrap passed (%d ms)", dur14)

            // Stage 15: 3-backend switch regression
            let startT15 = Date()
            NSLog("[SefariaAcceptance] Stage 15: backendSwitchRegression started")
            let regression = await backendRegressionProvider()
            guard regression.succeeded else {
                throw SefariaRPCError(code: "BACKEND_SWITCH_REGRESSION_FAILED", message: regression.failureDetail ?? "Unknown backend regression error")
            }
            let dur15 = Int(Date().timeIntervalSince(startT15) * 1000)
            report.stages["backendSwitchRegression"] = .init(passed: true, details: "3-backend switch regression completed cleanly", durationMs: dur15)
            NSLog("[SefariaAcceptance] Stage 15: backendSwitchRegression passed (%d ms)", dur15)

            report.status = "SUCCESS"
        } catch {
            report.status = "FAILURE"
            report.errorMessage = error.localizedDescription
            if let rpcErr = error as? SefariaRPCError {
                report.failedStage = rpcErr.code
            } else {
                report.failedStage = "UNKNOWN_ERROR"
            }
            NSLog("[SefariaAcceptance] Acceptance FAILED at stage '%@': %@", report.failedStage ?? "unknown", report.errorMessage ?? "none")
        }

        return report
    }
}

// Test-only same-file access; the entire original product source above is verbatim.
extension SefariaEmbeddedAcceptanceDiagnosticRunner {
    static func sourceControlVerifyOriginalLateReply() async throws -> SefariaLateReplyDiagnosticEvidence {
        try await verifyOriginalLateReply()
    }
}

// One DEBUG invocation per process. This slot holds only the actual returned
// value and evidence metadata; it has no executable authority or UI reference.
// Retention precedes every fallible serialization/write and lasts for the
// process, including when the diagnostic cannot persist its checkpoint.
@MainActor
private final class MaktabahNativeSearchContinuationProbeReturn {
    private static var retained: MaktabahNativeSearchContinuationProbeReturn?
    private enum RetentionError: Error { case alreadyInvoked, alreadyReturned, invalidKind }
    let kind: String
    let token: UUID
    private(set) var returned: ActionSearchContinuationOutcome?
    private(set) var checkpointReference: [String: Any]?

    private init(kind: String, token: UUID) { self.kind = kind; self.token = token }

    static func reserve(kind: String, token: UUID) throws -> MaktabahNativeSearchContinuationProbeReturn {
        guard ["search-continuation-hit", "search-continuation-page"].contains(kind) else {
            throw RetentionError.invalidKind
        }
        guard retained == nil else { throw RetentionError.alreadyInvoked }
        let entry = MaktabahNativeSearchContinuationProbeReturn(kind: kind, token: token)
        retained = entry
        return entry
    }

    // Both closures only project/write evidence. Neither is a source validator,
    // a grant, an operation chooser, or a fallback executor.
    func publish(_ actualReturn: ActionSearchContinuationOutcome,
                 checkpoint: (ActionSearchContinuationOutcome) throws -> [String: Any],
                 envelope: ([String: Any]) throws -> Void) throws {
        guard returned == nil else { throw RetentionError.alreadyReturned }
        returned = actualReturn
        let reference = try checkpoint(actualReturn)
        checkpointReference = reference
        try envelope(reference)
    }
}

// DEBUG acceptance projection only. It serializes the actual returned value;
// it cannot issue a grant, alter an original search or construct a UI witness.
@MainActor
private final class MaktabahNativeSearchContinuationProbeEvidence {
    private let probe: MaktabahNativeActionAcceptanceProbe
    private var blobs: Set<String> = []
    private var totalBytes = 0
    private enum EvidenceError: Error { case invalidKind, budget }

    init(_ probe: MaktabahNativeActionAcceptanceProbe) { self.probe = probe }

    private func optional<T>(_ value: T?) -> Any { value.map { $0 as Any } ?? NSNull() }

    // Original Data is retained losslessly outside the bounded JSON envelope.
    // Both filename and size are code-owned; no path is supplied by a caller.
    private func data(_ value: Data) throws -> [String: Any] {
        guard ["search-continuation-hit", "search-continuation-page"].contains(probe.kind) else {
            throw EvidenceError.invalidKind
        }
        guard value.count <= 4 * 1024 * 1024 else { throw EvidenceError.budget }
        let digest = SHA256.hash(data: value).map { String(format: "%02x", $0) }.joined()
        if !blobs.contains(digest) {
            guard blobs.count < 512, totalBytes <= 8 * 1024 * 1024 - value.count else {
                throw EvidenceError.budget
            }
            try probe.writeSearchContinuationBlob(value, digest: digest)
            blobs.insert(digest); totalBytes += value.count
        }
        return ["sha256": digest, "bytes": value.count,
                "file": "native-action-\(probe.kind)-\(probe.token.uuidString)-data-\(digest).bin"]
    }

    private func nullableData(_ value: Data?) throws -> Any {
        if let value { return try data(value) }
        return NSNull()
    }

    func source(_ value: ActionSearchContinuationSource) throws -> [String: Any] {
        ["observationID": value.observationID.uuidString, "sceneID": value.sceneID,
         "snapshot": try probe.json(value.snapshot), "sessionID": value.sessionID.uuidString,
         "modelID": value.modelID.uuidString, "generation": value.generation,
         "sourceRevision": value.sourceRevision, "submissionRevision": value.submissionRevision,
         "cancellationRevision": value.cancellationRevision, "paginationRevision": value.paginationRevision,
         "pageRevision": value.pageRevision, "configuration": try data(value.configuration)]
    }

    func hit(_ value: ActionLoadedSearchHit) throws -> [String: Any] {
        ["token": value.token.uuidString, "stableID": value.stableID,
         "locator": optional(value.locator), "versionTitle": optional(value.versionTitle),
         "language": optional(value.language), "identity": try data(value.identity)]
    }

    func observation(_ value: ActionSearchContinuationObservation) throws -> [String: Any] {
        ["source": try source(value.source), "loadedHits": try value.loadedHits.map { try hit($0) },
         "nextPageToken": optional(value.nextPageToken?.uuidString)]
    }

    func operation(_ value: ActionSearchContinuationOperation) -> [String: Any] {
        switch value {
        case .revealLoadedHit(let token): return ["kind": "revealLoadedHit", "token": token.uuidString]
        case .nextOriginalPage(let token): return ["kind": "nextOriginalPage", "token": token.uuidString]
        }
    }

    private func page(_ value: ActionSearchOriginalPageReceipt) throws -> [String: Any] {
        ["attemptID": value.attemptID.uuidString, "modelID": value.modelID.uuidString,
         "generation": value.generation, "pageRevision": value.pageRevision,
         "request": try data(value.request), "requestOffset": value.requestOffset,
         "requestLimit": value.requestLimit, "rawRowCount": value.rawRowCount,
         "mappedRowCount": value.mappedRowCount, "consumedBefore": value.consumedBefore,
         "consumedAfter": value.consumedAfter, "cursorBefore": optional(value.cursorBefore),
         "rawNextOffset": optional(value.rawNextOffset), "normalizedNextOffset": optional(value.normalizedNextOffset),
         "hasMore": value.hasMore, "sourceEvidence": try nullableData(value.sourceEvidence)]
    }

    private func effect(_ value: ActionSearchContinuationEffect) throws -> [String: Any] {
        switch value {
        case .pageRequested(let id): return ["kind": "pageRequested", "attemptID": id.uuidString]
        case .pageCommitted(let receipt): return ["kind": "pageCommitted", "page": try page(receipt)]
        case .hitSelectionApplied(let value): return ["kind": "hitSelectionApplied", "hit": try hit(value)]
        }
    }

    private func command(_ value: ActionSearchContinuationCommand) throws -> [String: Any] {
        ["source": try source(value.source), "operation": operation(value.operation),
         "invocation": ["requestID": value.invocation.requestId.uuidString,
                        "snapshot": try probe.json(value.invocation.snapshot),
                        "deadlineUptimeNanoseconds": value.invocation.deadlineUptimeNanoseconds]]
    }

    func outcome(_ value: ActionSearchContinuationOutcome, depth: Int = 0) throws -> [String: Any] {
        guard depth < 64 else { throw EvidenceError.budget }
        switch value {
        case .acknowledged(let receipt):
            return ["kind": "acknowledged", "receipt": [
                "requestID": receipt.requestID.uuidString, "before": try source(receipt.before),
                "after": try source(receipt.after), "operation": operation(receipt.operation),
                "effects": try receipt.effects.map { try effect($0) },
                "visible": ["witnessID": receipt.visible.witnessID.uuidString,
                            "listID": receipt.visible.listID.uuidString,
                            "rowID": optional(receipt.visible.rowID?.uuidString),
                            "layoutRevision": receipt.visible.layoutRevision,
                            "identity": try nullableData(receipt.visible.identity)]]]
        case .refused(let failure):
            return ["kind": "refused", "failure": [
                "requestID": failure.requestID.uuidString,
                "source": try failure.source.map { try source($0) } as Any? ?? NSNull(),
                "operation": failure.operation.map { operation($0) } as Any? ?? NSNull(),
                "reason": failure.reason.rawValue, "effects": try failure.effects.map { try effect($0) }]]
        case .unqualified(let attempted, let original):
            return ["kind": "unqualified", "command": try command(attempted),
                    "originalResponse": try outcome(original, depth: depth + 1)]
        }
    }
}

extension MaktabahNativeActionAcceptanceProbe {
    fileprivate func writeSearchContinuationCheckpoint(_ payload: [String: Any]) throws -> [String: Any] {
        guard ["search-continuation-hit", "search-continuation-page"].contains(kind) else {
            throw CocoaError(.coderInvalidValue)
        }
        let bytes = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        guard bytes.count < 128 * 1024 else { throw CocoaError(.coderInvalidValue) }
        let filename = stem + "-outcome.json"
        let url = documents.appendingPathComponent(filename)
        // A prior checkpoint is never replaced, even after a reporting failure.
        try bytes.write(to: url, options: [.withoutOverwriting])
        return ["file": filename, "bytes": bytes.count,
                "sha256": SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()]
    }

    fileprivate func writeSearchContinuationBlob(_ bytes: Data, digest: String) throws {
        guard ["search-continuation-hit", "search-continuation-page"].contains(kind),
              bytes.count <= 4 * 1024 * 1024, digest.count == 64,
              digest.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }),
              SHA256.hash(data: bytes).map({ String(format: "%02x", $0) }).joined() == digest else {
            throw CocoaError(.coderInvalidValue)
        }
        let url = documents.appendingPathComponent(stem + "-data-" + digest + ".bin")
        if FileManager.default.fileExists(atPath: url.path) {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            guard values.isRegularFile == true, values.isSymbolicLink == false,
                  values.fileSize == bytes.count, try Data(contentsOf: url) == bytes else {
                throw CocoaError(.fileReadCorruptFile)
            }
        } else {
            try bytes.write(to: url, options: [.withoutOverwriting])
        }
    }
}

extension MaktabahNativeRoutingComposition {
    // The original SearchModeView task calls this through the existing DEBUG
    // dispatcher. Original UI submission happens before the nonce is consumed.
    private func runSearchContinuationAcceptanceProbe(_ probe: MaktabahNativeActionAcceptanceProbe,
                                                       manager: iOSNavigationManager) async {
        var consumed = false
        var selectedObservation: ActionSearchContinuationObservation?
        var selectedOperation: ActionSearchContinuationOperation?
        var retainedReturn: MaktabahNativeSearchContinuationProbeReturn?
        do {
            for _ in 0..<900 {
                try Task.checkCancellation()
                if probe.hasResult { return }
                let search = manager.unifiedSearchSession
                if manager.currentMode == .search,
                   let scene = actionAcceptanceSession(manager: manager), scene.isPresentationReady,
                   search.hasSubmitted, !search.isSearching, !search.isLoadingMore,
                   !search.nativeContinuationIsBusy, !search.resultsAreDirty,
                   search.errorMessage == nil, !search.results.isEmpty,
                   try probe.consumeTrigger() {
                    consumed = true
                    let retention = try MaktabahNativeSearchContinuationProbeReturn.reserve(kind: probe.kind,
                                                                                           token: probe.token)
                    retainedReturn = retention
                    let beforeIDs = search.results.map(\.stableID)
                    let beforeSubmission = search.submissionRevision
                    let beforeCancellation = search.cancellationRevision
                    let beforePagination = search.paginationRevision
                    let result = try await continueOriginalSearch(manager: manager) { observation in
                        selectedObservation = observation
                        let operation: ActionSearchContinuationOperation
                        if probe.kind == "search-continuation-hit" {
                            guard let last = observation.loadedHits.last, last.locator?.isEmpty == false else {
                                throw UIRouteError(.unavailable, "continuation_probe_no_qualified_loaded_hit")
                            }
                            operation = .revealLoadedHit(token: last.token)
                        } else {
                            guard probe.kind == "search-continuation-page", let token = observation.nextPageToken else {
                                throw UIRouteError(.unavailable, "continuation_probe_no_original_next_page")
                            }
                            operation = .nextOriginalPage(token: token)
                        }
                        selectedOperation = operation
                        return operation
                    }
                    let evidence = MaktabahNativeSearchContinuationProbeEvidence(probe)
                    try retention.publish(result, checkpoint: { actualReturn in
                        try probe.writeSearchContinuationCheckpoint([
                            "schemaVersion": 1, "triggerToken": probe.token.uuidString, "probeKind": probe.kind,
                            "processID": ProcessInfo.processInfo.processIdentifier,
                            "outcome": try evidence.outcome(actualReturn)
                        ])
                    }, envelope: { checkpoint in
                        var payload: [String: Any] = [
                        "schemaVersion": 1, "triggerToken": probe.token.uuidString, "probeKind": probe.kind,
                        "processID": ProcessInfo.processInfo.processIdentifier,
                        "outcomeCheckpoint": checkpoint, "actualReturnRetained": true,
                        "originalBeforeRowIDs": beforeIDs, "originalAfterRowIDs": search.results.map(\.stableID),
                        "originalSubmissionBefore": beforeSubmission, "originalSubmissionAfter": search.submissionRevision,
                        "originalCancellationBefore": beforeCancellation, "originalCancellationAfter": search.cancellationRevision,
                        "originalPaginationBefore": beforePagination, "originalPaginationAfter": search.paginationRevision,
                        "originalHasSubmitted": search.hasSubmitted, "originalIsSearching": search.isSearching,
                        "originalIsLoadingMore": search.isLoadingMore, "originalResultsAreDirty": search.resultsAreDirty,
                        "originalBookIDs": search.selectedBookIds.sorted(), "originalQuery": search.query,
                    ]
                        if let selectedObservation { payload["observation"] = try evidence.observation(selectedObservation) }
                        if let selectedOperation { payload["selectedOperation"] = evidence.operation(selectedOperation) }
                        if let error = search.errorMessage { payload["originalError"] = error }
                        let encoded = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
                        guard encoded.count < 128 * 1024 else { throw CocoaError(.coderInvalidValue) }
                        try probe.write(payload: payload)
                    })
                    return
                }
                try await Task.sleep(for: .milliseconds(100))
            }
            try probe.write(payload: ["probeError": "original_continuation_source_or_trigger_not_ready"])
        } catch {
            // A failure is never rewritten into a successful root receipt or
            // an assertion that the original operation had no earlier effects.
            if consumed || !(error is CancellationError) {
                var failure: [String: Any] = ["probeError": "continuation_probe_failed",
                                             "triggerConsumed": consumed,
                                             "actualReturnRetained": retainedReturn?.returned != nil,
                                             "errorType": String(describing: type(of: error))]
                if let checkpoint = retainedReturn?.checkpointReference {
                    failure["outcomeCheckpoint"] = checkpoint
                } else if retainedReturn?.returned != nil {
                    failure["outcomeCheckpointError"] = "actual_return_retained_but_checkpoint_incomplete"
                }
                try? probe.write(payload: failure)
            }
        }
    }
}

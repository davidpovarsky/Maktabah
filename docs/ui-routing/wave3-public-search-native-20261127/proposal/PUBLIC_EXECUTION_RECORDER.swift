extension MaktabahNativeRoutingComposition {
    // This observer is reached ONLY after the actual public entry has returned
    // its typed execution. The old probe dispatcher never invokes these kinds.
    // A diagnostic failure must neither erase that return nor change it.
    private func recordPublicSearchContinuationEvidence(
        _ request: NativeSearchContinuationIntentService.OpenRequest,
        execution: NativeSearchContinuationIntentService.Execution
    ) {
        let kind = request.target.reference.kind == .result ? "search-public-hit" : "search-public-page"
        guard let probe = MaktabahNativeActionAcceptanceProbe(kind: kind),
              !probe.hasResult, !MaktabahNativePublicSearchProbeReturn.hasCaptured else { return }
        var captured: MaktabahNativePublicSearchProbeReturn?
        do {
            let retained = try MaktabahNativePublicSearchProbeReturn.capture(kind: kind, token: probe.token,
                request: request, execution: execution)
            captured = retained
            let evidence = MaktabahNativeSearchContinuationProbeEvidence(probe)
            try retained.publish(checkpoint: { request, actualExecution in
                try probe.writeSearchContinuationCheckpoint([
                    "schemaVersion": 1, "diagnosticToken": probe.token.uuidString, "probeKind": probe.kind,
                    "processID": ProcessInfo.processInfo.processIdentifier,
                    "publicRequest": try evidence.publicRequest(request),
                    "execution": try evidence.publicExecution(actualExecution)
                ])
            }, envelope: { checkpoint in
                try probe.write(payload: ["schemaVersion": 1, "diagnosticToken": probe.token.uuidString,
                    "probeKind": probe.kind, "processID": ProcessInfo.processInfo.processIdentifier,
                    "outcomeCheckpoint": checkpoint, "actualExecutionRetained": true,
                    "delivery": "original-public-entry-return", "triggerConsumed": false])
            })
        } catch {
            var failure: [String: Any] = ["schemaVersion": 1, "diagnosticToken": probe.token.uuidString,
                "probeKind": probe.kind, "processID": ProcessInfo.processInfo.processIdentifier,
                "probeError": "public_search_evidence_failed", "triggerConsumed": false,
                "actualExecutionRetained": captured != nil,
                "errorType": String(describing: type(of: error))]
            if let checkpoint = captured?.checkpointReference { failure["outcomeCheckpoint"] = checkpoint }
            else if captured != nil { failure["outcomeCheckpointError"] = "actual_execution_retained_but_checkpoint_incomplete" }
            try? probe.write(payload: failure)
        }
    }
}

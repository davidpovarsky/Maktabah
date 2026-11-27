    // Immutable public metadata is evidence, never a substitute source token.
    func publicRequest(_ request: NativeSearchContinuationIntentService.OpenRequest) throws -> [String: Any] {
        let target = request.target, value = target.source
        let origin: [String: Any]
        switch request.origin {
        case .appIntent: origin = ["kind": "appIntent"]
        case .deepLink(let scene): origin = ["kind": "deepLink", "receivingSceneID": scene.rawValue]
        }
        var result: [String: Any] = [
            "referenceID": target.id, "kind": target.reference.kind.rawValue, "title": target.title,
            "origin": origin,
            "invocation": ["requestID": request.invocation.requestId.uuidString,
                "snapshot": try probe.json(request.invocation.snapshot),
                "deadlineUptimeNanoseconds": request.invocation.deadlineUptimeNanoseconds],
            "source": ["sceneID": value.sceneID, "snapshot": try probe.json(value.snapshot),
                "sessionID": value.sessionID.uuidString, "modelID": value.modelID.uuidString,
                "generation": value.generation, "sourceRevision": value.sourceRevision,
                "submissionRevision": value.submissionRevision, "cancellationRevision": value.cancellationRevision,
                "paginationRevision": value.paginationRevision, "pageRevision": value.pageRevision,
                "configuration": try data(value.configuration)]
        ]
        if let selected = target.hit {
            result["hit"] = ["stableID": selected.stableID, "locator": optional(selected.locator),
                "versionTitle": optional(selected.versionTitle), "language": optional(selected.language),
                "identity": try data(selected.identity)]
        } else { result["hit"] = NSNull() }
        return result
    }

    func publicExecution(_ value: NativeSearchContinuationIntentService.Execution) throws -> [String: Any] {
        ["command": try command(value.command), "outcome": try outcome(value.outcome)]
    }

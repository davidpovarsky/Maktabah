
// Actual public App Intents / system URL continuation acceptance. The DEBUG
// observer only retains the immutable return from that production caller.
// It has no executable trigger, source token, chooser or alternate executor.
extension NativeRoutingAcceptanceTests {
    private func publicSearchEvidenceFile(kind: String, token: UUID, suffix: String) throws -> URL {
        guard ["search-public-hit", "search-public-page"].contains(kind),
              ["result.json", "outcome.json", "trigger.txt"].contains(suffix) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return try continuationDocuments().appendingPathComponent("native-action-\(kind)-\(token.uuidString)-\(suffix)")
    }

    @MainActor private func publicSearchReturn(kind: String, token: UUID)
        throws -> (request: [String: Any], command: [String: Any], receipt: [String: Any], raw: Data) {
        let resultURL = try publicSearchEvidenceFile(kind: kind, token: token, suffix: "result.json")
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            FileManager.default.fileExists(atPath: resultURL.path)
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 45), .completed,
            "The evidence wait cannot renew the public command's original five-second deadline")
        let raw = try continuationRead(resultURL, maximum: 128 * 1024)
        continuationAttach(raw, name: "actual-public-search-envelope-\(kind)-\(token)")
        let envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: raw) as? [String: Any])
        let checkpointURL = try publicSearchEvidenceFile(kind: kind, token: token, suffix: "outcome.json")
        // Preserve the real returned failure/partial effects before requiring
        // an ACK, including when the later envelope reports an encoding error.
        let bytes = try continuationRead(checkpointURL, maximum: 128 * 1024)
        continuationAttach(bytes, name: "actual-public-search-return-\(kind)-\(token)")
        let checkpoint = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        try continuationAttachBlobs([envelope, checkpoint], kind: kind, token: token)
        let reference = try XCTUnwrap(envelope["outcomeCheckpoint"] as? [String: Any])
        XCTAssertEqual(reference["file"] as? String, checkpointURL.lastPathComponent)
        XCTAssertEqual(reference["bytes"] as? Int, bytes.count)
        XCTAssertEqual(reference["sha256"] as? String, continuationDigest(bytes))
        for value in [envelope, checkpoint] {
            XCTAssertEqual(value["schemaVersion"] as? Int, 1)
            XCTAssertEqual(value["diagnosticToken"] as? String, token.uuidString)
            XCTAssertEqual(value["probeKind"] as? String, kind)
            XCTAssertEqual(String(try XCTUnwrap(value["processID"] as? Int)), try targetProcessIdentifier())
        }
        XCTAssertEqual(envelope["actualExecutionRetained"] as? Bool, true)
        XCTAssertEqual(envelope["triggerConsumed"] as? Bool, false)
        XCTAssertEqual(envelope["delivery"] as? String, "original-public-entry-return")
        XCTAssertNil(envelope["probeError"], "A diagnostic serialization failure is not successful public acceptance")
        let execution = try XCTUnwrap(checkpoint["execution"] as? [String: Any])
        let outcome = try XCTUnwrap(execution["outcome"] as? [String: Any])
        XCTAssertEqual(outcome["kind"] as? String, "acknowledged", "Keep the actual refused/unqualified result attached")
        return (try XCTUnwrap(checkpoint["publicRequest"] as? [String: Any]),
            try XCTUnwrap(execution["command"] as? [String: Any]),
            try XCTUnwrap(outcome["receipt"] as? [String: Any]), raw)
    }

    private func publicSearchReference(_ id: String, page: Bool) throws -> String {
        let fields = id.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        XCTAssertEqual(fields.count, 6)
        guard fields.count == 6 else { throw CocoaError(.fileReadCorruptFile) }
        XCTAssertEqual(Array(fields.prefix(5)), ["maktabah", "search", page ? "nextPage" : "result", "v1", "otzaria"])
        let uuid = try XCTUnwrap(UUID(uuidString: fields[5]))
        XCTAssertEqual(uuid.uuidString.lowercased(), fields[5])
        return fields[5]
    }

    // This checks the real Get Link return without invoking an app decoder.
    // The opaque reference is metadata only; the system must deliver the URL.
    private func publicSearchLink(_ returned: URL, entityID: String, page: Bool, https: Bool) throws -> URL {
        let component = try XCTUnwrap(URLComponents(url: returned, resolvingAgainstBaseURL: false))
        let destination = page ? "native.search.nextPage" : "native.search.result"
        XCTAssertEqual(component.scheme, "maktabah-debug"); XCTAssertEqual(component.host, "action")
        XCTAssertNil(component.user); XCTAssertNil(component.password); XCTAssertNil(component.port); XCTAssertNil(component.fragment)
        XCTAssertEqual(component.percentEncodedPath, "/v2/" + destination)
        let queries = try XCTUnwrap(component.queryItems)
        XCTAssertEqual(queries.count, 1); XCTAssertEqual(queries.first?.name, "route")
        let encoded = try XCTUnwrap(queries.first?.value)
        XCTAssertLessThanOrEqual(encoded.utf8.count, 4096)
        var base64 = encoded.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        let bytes = try XCTUnwrap(Data(base64Encoded: base64))
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        XCTAssertEqual(Set(payload.keys), Set(["version", "destination", "backend", "presentation", "searchReference"]))
        XCTAssertEqual(payload["version"] as? Int, 2); XCTAssertEqual(payload["destination"] as? String, destination)
        XCTAssertEqual(payload["backend"] as? String, "otzaria"); XCTAssertEqual(payload["presentation"] as? String, "currentTab")
        XCTAssertEqual(payload["searchReference"] as? String, try publicSearchReference(entityID, page: page))
        XCTAssertFalse(String(decoding: bytes, as: UTF8.self).contains("אמר"))
        if !https { return returned }
        var universal = URLComponents()
        universal.scheme = "https"; universal.host = "davidpovarsky.github.io"
        universal.percentEncodedPath = "/chavrusatext/action" + component.percentEncodedPath
        universal.percentEncodedQuery = component.percentEncodedQuery
        return try XCTUnwrap(universal.url)
    }

    @MainActor private func actualPublicSearchTarget(_ system: IntentDefinitions,
        firstItems: [[String: Any]], ui: OriginalSearchContextUI, page: Bool, language: String)
        async throws -> (AnyAppEntity, [String: Any]?) {
        if page {
            let results = try await system.entities["NativeSearchContinuationEntity"].entities(
                matching: language == "he" ? "עמוד החיפוש הבא" : "Next search page")
            XCTAssertEqual(results.count, 1, "Require one real original next-page entity in the actual window")
            let entity = try XCTUnwrap(results.first)
            _ = try publicSearchReference(entity.identifier.instanceIdentifier, page: true)
            return (entity, nil)
        }
        let list = try ui.require("global-search-results")
        func prefix(_ item: [String: Any]) throws -> String {
            let title = try XCTUnwrap(item["bookTitle"] as? String)
            let reference = try XCTUnwrap(item["reference"] as? String)
            return [title, reference].filter { !$0.isEmpty }.joined(separator: " — ")
        }
        let prefixes = try firstItems.map(prefix)
        // A unique title/reference prefix only chooses an actual returned
        // system entity. Full opaque-ID -> original hit/source/SQL equality is
        // still checked independently after the real operation returns.
        for (index, item) in firstItems.enumerated().reversed() {
            let query = prefixes[index]
            guard !query.isEmpty,
                  prefixes.filter({ $0.localizedCaseInsensitiveContains(query) }).count == 1 else { continue }
            let id = try XCTUnwrap(item["id"] as? String)
            guard !continuationVisible(ui.control("search-result-preview-toggle-" + id), list: list, keyboard: false) else { continue }
            let entities = try await system.entities["NativeSearchContinuationEntity"].entities(matching: query)
            guard entities.count == 1 else { continue }
            let entity = try XCTUnwrap(entities.first)
            _ = try publicSearchReference(entity.identifier.instanceIdentifier, page: false)
            return (entity, item)
        }
        XCTFail("The original fixture must expose a unique genuinely offscreen qualified loaded result; no fabricated ID/order fallback")
        throw CocoaError(.fileReadCorruptFile)
    }

    @MainActor
    func runPublicSearchContinuation(expectedPad: Bool, page: Bool, delivery: String, language: String) async throws {
        XCTAssertTrue(["intent", "customURL", "https"].contains(delivery))
        XCTAssertTrue(["en", "he"].contains(language)); XCTAssertEqual(isPad, expectedPad)
        // ONE launch per selector: miniTest10's original writer uses the
        // original workspace namespace and appends to its exact trace file.
        let token = UUID(), traceNamespace = workspaceNamespace
        let kind = page ? "search-public-page" : "search-public-hit"
        let orientation = XCUIDevice.shared.orientation
        defer { XCUIDevice.shared.orientation = orientation }
        XCUIDevice.shared.orientation = .portrait
        launchWithTier(.realUI, scenario: "reader", backend: "otzaria",
            extraArgs: ["-preferredBackend", "otzaria", "-smokeBackend", "otzaria",
                "-ChavrusaTextFaithfulReaderUIEnabled", "YES", "-otzaria_reader_unit_mode", "line",
                "-studyWorkspaceTestingNamespace", workspaceNamespace, "-lastSelectedTab", "0",
                "-GlobalSearchNativeTraceEnabled", "YES", "-GlobalSearchNativeTraceNamespace", traceNamespace,
                "-nativeActionAcceptanceKind", kind, "-nativeActionAcceptanceToken", token.uuidString],
            language: language, locale: language == "he" ? "he_IL" : "en_US")
        XCTAssertFalse(app.launchArguments.contains("-smokeBypassBootstrap"))
        dismissAlertsIfNeeded()
        defer { capture("actual-public-search-\(delivery)-\(kind)-\(language)-final") }
        let oracle = try systemReaderOracleDocument()
        let initial = try XCTUnwrap(oracle.rows.first { $0.id == oracle.bootstrapRowID })
        XCTAssertEqual(ProcessInfo.processInfo.environment["R27_EXPECTED_OTZARIA_WORK_KEY"], "book:\(initial.bookId)")
        try requireReaderLocator("otzaria|book:\(initial.bookId)|line:\(initial.lineIndex)", timeout: 60)
        let ui = OriginalSearchContextUI(app: app, test: self)
        try ui.returnToOriginalSearch()
        try ui.require("global-search-mode").tap(); try ui.require("global-search-mode-advanced").tap()
        let field = try ui.require("global-search-query")
        XCTAssertTrue(field.elementType == .searchField || field.elementType == .textField)
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "global-search-query").count, 1)
        field.tap()
        let prior = (field.value as? String) ?? ""
        if !prior.isEmpty && prior != field.placeholderValue { field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: prior.count)) }
        field.typeText("אמר\n")
        try ui.wait("Require the genuine original first page before public discovery", timeout: 90) {
            guard !ui.control("global-search-loading").exists, !ui.control("global-search-cancel").exists,
                  !ui.control("global-search-error").exists, !ui.control("global-search-dirty").exists,
                  let events = try? self.continuationTrace(traceNamespace).1,
                  let last = events.last(where: { $0["event"] as? String == "published" }),
                  let items = last["items"] as? [[String: Any]], items.count > 20,
                  let count = try? ui.loadedCount() else { return false }
            return count == items.count
        }
        let process = try targetProcessIdentifier(), initialTrace = try continuationTrace(traceNamespace)
        let firstItems = try continuationValidatePages(initialTrace.1, namespace: traceNamespace, process: process, expectedPages: 1)
        let firstID = try XCTUnwrap(firstItems.first?["id"] as? String)
        try ui.assertOriginalSearchResize(rtl: language == "he", query: "אמר", firstStableID: firstID)
        let system = IntentDefinitions(bundleIdentifier: "com.davidpovarsky.chavrusatext")
        let (entity, expectedItem) = try await actualPublicSearchTarget(system, firstItems: firstItems, ui: ui, page: page, language: language)
        let entityID = entity.identifier.instanceIdentifier
        let opaqueReference = try publicSearchReference(entityID, page: page)
        let workspace = try actualReaderWorkspace(), current = try workspace.current()
        let sceneID = try XCTUnwrap(workspace.lastActiveSceneID)
        let documents = try originalWorkspaceSelectionDocuments(), rootReceipts = try actualNativeReceiptLines()
        let mode = try XCTUnwrap(ui.require("global-search-mode").value as? String)
        let books = try ui.require("global-search-books").label
        var deliveredURL: URL?
        if delivery != "intent" {
            let linkResult = try await system.intents["GetOriginalSearchLinkIntent"].makeIntent(target: entity).run()
            let originalURL: URL = try linkResult.value
            deliveredURL = try publicSearchLink(originalURL, entityID: entityID, page: page, https: delivery == "https")
            continuationAttach(Data(try XCTUnwrap(deliveredURL).absoluteString.utf8), name: "actual-system-public-search-URL", json: false)
        }
        let beforeTrace = try continuationTrace(traceNamespace)
        XCTAssertEqual(beforeTrace.0, initialTrace.0, "Metadata/Link discovery and geometry setup must not execute a page or result")
        XCTAssertEqual(try actualNativeReceiptLines(), rootReceipts)
        for suffix in ["trigger.txt", "result.json", "outcome.json"] {
            XCTAssertFalse(FileManager.default.fileExists(atPath: try publicSearchEvidenceFile(kind: kind, token: token, suffix: suffix).path))
        }
        // The only measured delivery: actual out-of-process App Intents or
        // exact owned simctl system-openurl. No direct perform/decoder call.
        var deliveryFailure: Error?
        do {
            if let deliveredURL { try openInExistingProcess(deliveredURL) }
            else if page { _ = try await system.intents["LoadNextOriginalSearchPageIntent"].makeIntent(page: entity).run() }
            else { _ = try await system.intents["RevealLoadedSearchResultIntent"].makeIntent(result: entity).run() }
        } catch { deliveryFailure = error }
        let returned = try publicSearchReturn(kind: kind, token: token)
        XCTAssertNil(deliveryFailure, "Real system delivery must also succeed after the actual caller returns: \(String(describing: deliveryFailure))")
        if let deliveryFailure { throw deliveryFailure }
        XCTAssertFalse(app.alerts["Unable to open link"].exists)
        XCTAssertFalse(FileManager.default.fileExists(atPath: try publicSearchEvidenceFile(kind: kind, token: token, suffix: "trigger.txt").path))
        let request = returned.request, command = returned.command, receipt = returned.receipt
        XCTAssertEqual(request["referenceID"] as? String, entityID)
        XCTAssertEqual(request["kind"] as? String, page ? "nextPage" : "result")
        XCTAssertFalse(try XCTUnwrap(request["title"] as? String).isEmpty)
        let origin = try XCTUnwrap(request["origin"] as? [String: Any])
        XCTAssertEqual(origin["kind"] as? String, delivery == "intent" ? "appIntent" : "deepLink")
        if delivery != "intent" { XCTAssertEqual(origin["receivingSceneID"] as? String, sceneID) }
        let invocation = try XCTUnwrap(request["invocation"] as? [String: Any])
        XCTAssertEqual(try continuationJSON(invocation), try continuationJSON(try XCTUnwrap(command["invocation"])))
        XCTAssertEqual(try continuationUUID(invocation["requestID"], "public invocation"),
                       try continuationUUID(receipt["requestID"], "actual receipt"))
        XCTAssertGreaterThan(try XCTUnwrap((invocation["deadlineUptimeNanoseconds"] as? NSNumber).flatMap { UInt64($0.stringValue) }), 0)
        let source = try XCTUnwrap(command["source"] as? [String: Any])
        let before = try XCTUnwrap(receipt["before"] as? [String: Any]), after = try XCTUnwrap(receipt["after"] as? [String: Any])
        XCTAssertEqual(try continuationJSON(source), try continuationJSON(before))
        let metadataSource = try XCTUnwrap(request["source"] as? [String: Any])
        for key in ["sceneID", "snapshot", "sessionID", "modelID", "generation", "sourceRevision", "submissionRevision", "cancellationRevision", "paginationRevision", "pageRevision", "configuration"] {
            XCTAssertEqual(try continuationJSON([key: try XCTUnwrap(metadataSource[key])]),
                           try continuationJSON([key: try XCTUnwrap(before[key])]), "Actual discovered source: " + key)
        }
        let originalPublication = try XCTUnwrap(beforeTrace.1.last { $0["event"] as? String == "published" })
        for value in [before, after] {
            XCTAssertEqual(value["sceneID"] as? String, sceneID)
            for key in ["observationID", "sessionID", "modelID"] { _ = try continuationUUID(value[key], key) }
            for key in ["generation", "sourceRevision", "pageRevision"] { _ = try XCTUnwrap((value[key] as? NSNumber).flatMap { UInt64($0.stringValue) }, key) }
            for key in ["submissionRevision", "cancellationRevision", "paginationRevision"] { _ = try XCTUnwrap(value[key] as? Int, key) }
        }
        let snapshot = try XCTUnwrap(before["snapshot"] as? [String: Any])
        XCTAssertEqual(snapshot["backend"] as? String, "otzaria")
        XCTAssertEqual(try XCTUnwrap(snapshot["generation"] as? NSNumber), try XCTUnwrap(originalPublication["backendGeneration"] as? NSNumber))
        XCTAssertEqual(try XCTUnwrap(before["submissionRevision"] as? Int), try XCTUnwrap(originalPublication["submissionRevision"] as? Int))
        for key in ["observationID", "sceneID", "snapshot", "sessionID", "modelID", "generation", "sourceRevision", "submissionRevision", "cancellationRevision", "configuration"] {
            XCTAssertEqual(try continuationJSON([key: try XCTUnwrap(before[key])]),
                           try continuationJSON([key: try XCTUnwrap(after[key])]), "Same retained source: " + key)
        }
        let operation = try XCTUnwrap(receipt["operation"] as? [String: Any])
        XCTAssertEqual(try continuationJSON(operation), try continuationJSON(try XCTUnwrap(command["operation"])))
        XCTAssertEqual(operation["kind"] as? String, page ? "nextOriginalPage" : "revealLoadedHit")
        XCTAssertNotEqual(try continuationUUID(operation["token"], "fresh original operation token").lowercased(), opaqueReference,
                          "An opaque public reference must never be reused as original execution authority")
        let effects = try XCTUnwrap(receipt["effects"] as? [[String: Any]])
        let visible = try XCTUnwrap(receipt["visible"] as? [String: Any])
        for key in ["witnessID", "listID"] { _ = try continuationUUID(visible[key], key) }
        XCTAssertGreaterThan(try XCTUnwrap((visible["layoutRevision"] as? NSNumber)?.uint64Value), 0)
        let list = try ui.require("global-search-results"), measuredRow: XCUIElement
        if page {
            XCTAssertTrue(request["hit"] is NSNull)
            XCTAssertEqual(effects.compactMap { $0["kind"] as? String }, ["pageRequested", "pageCommitted"])
            let committed = try XCTUnwrap(effects.last?["page"] as? [String: Any])
            XCTAssertEqual(try continuationUUID(effects.first?["attemptID"], "requested attempt"), try continuationUUID(committed["attemptID"], "committed attempt"))
            XCTAssertEqual(try continuationUUID(committed["modelID"], "committed model"), try continuationUUID(before["modelID"], "source model"))
            XCTAssertEqual(try XCTUnwrap(committed["generation"] as? NSNumber), try XCTUnwrap(before["generation"] as? NSNumber))
            let originalRequest = try XCTUnwrap(JSONSerialization.jsonObject(with: continuationBlob(committed["request"], kind: kind, token: token)) as? [String: Any])
            XCTAssertEqual(originalRequest["query"] as? String, "אמר"); XCTAssertEqual(originalRequest["limit"] as? Int, 100)
            let consumed = try XCTUnwrap((beforeTrace.1.last { $0["event"] as? String == "provider" })?["nextOffset"] as? Int)
            for key in ["requestOffset", "consumedBefore", "cursorBefore"] { XCTAssertEqual(committed[key] as? Int, consumed) }
            XCTAssertEqual(originalRequest["offset"] as? Int, consumed); XCTAssertEqual(committed["requestLimit"] as? Int, 100)
            let now = try continuationTrace(traceNamespace)
            let provider = try XCTUnwrap(now.1.last { $0["event"] as? String == "provider" })
            let rows = try XCTUnwrap((provider["page"] as? [String: Any])?["results"] as? [[String: Any]])
            XCTAssertEqual(committed["rawRowCount"] as? Int, rows.count); XCTAssertEqual(committed["mappedRowCount"] as? Int, rows.count)
            XCTAssertEqual(committed["consumedAfter"] as? Int, consumed + rows.count)
            XCTAssertEqual(try XCTUnwrap(committed["rawNextOffset"] as? Int), try XCTUnwrap(provider["nextOffset"] as? Int))
            if try XCTUnwrap(committed["hasMore"] as? Bool) { XCTAssertEqual(committed["normalizedNextOffset"] as? Int, consumed + rows.count) }
            else { XCTAssertTrue(committed["normalizedNextOffset"] is NSNull) }
            XCTAssertEqual(try XCTUnwrap(committed["pageRevision"] as? NSNumber), try XCTUnwrap(after["pageRevision"] as? NSNumber))
            XCTAssertEqual(try XCTUnwrap(after["paginationRevision"] as? Int), try XCTUnwrap(before["paginationRevision"] as? Int) + 1)
            XCTAssertTrue(visible["rowID"] is NSNull); XCTAssertTrue(visible["identity"] is NSNull)
            measuredRow = ui.control("search-result-preview-toggle-" + firstID)
        } else {
            let expected = try XCTUnwrap(expectedItem), hit = try XCTUnwrap(request["hit"] as? [String: Any])
            let id = try XCTUnwrap(expected["id"] as? String)
            XCTAssertEqual(hit["stableID"] as? String, id)
            XCTAssertEqual(try XCTUnwrap(hit["locator"] as? String), try XCTUnwrap(expected["locator"] as? String))
            XCTAssertEqual(effects.compactMap { $0["kind"] as? String }, ["hitSelectionApplied"])
            let applied = try XCTUnwrap(effects.first?["hit"] as? [String: Any])
            XCTAssertEqual(try continuationUUID(applied["token"], "applied original hit"), try continuationUUID(operation["token"], "operation"))
            for key in ["stableID", "locator", "versionTitle", "language", "identity"] {
                XCTAssertEqual(try continuationJSON([key: try XCTUnwrap(hit[key])]), try continuationJSON([key: try XCTUnwrap(applied[key])]))
            }
            let identityBytes = try continuationBlob(hit["identity"], kind: kind, token: token)
            let identity = try XCTUnwrap(JSONSerialization.jsonObject(with: identityBytes) as? [String: Any])
            XCTAssertEqual(identity["stableID"] as? String, id)
            XCTAssertEqual(try XCTUnwrap(identity["book"] as? Int), try XCTUnwrap(expected["bookID"] as? Int))
            XCTAssertEqual(try XCTUnwrap(identity["page"] as? Int), try XCTUnwrap(expected["lineIndex"] as? Int))
            XCTAssertEqual(try XCTUnwrap(identity["title"] as? String), try XCTUnwrap(expected["bookTitle"] as? String))
            XCTAssertEqual(continuationDigest(Data(try XCTUnwrap(identity["text"] as? String).utf8)), try XCTUnwrap(expected["snippetSHA256"] as? String))
            XCTAssertEqual(try continuationBlob(visible["identity"], kind: kind, token: token), identityBytes)
            _ = try continuationUUID(visible["rowID"], "actual original row")
            XCTAssertEqual(try XCTUnwrap(before["pageRevision"] as? NSNumber), try XCTUnwrap(after["pageRevision"] as? NSNumber))
            XCTAssertEqual(try XCTUnwrap(before["paginationRevision"] as? Int), try XCTUnwrap(after["paginationRevision"] as? Int))
            measuredRow = ui.control("search-result-preview-toggle-" + id)
            XCTAssertEqual(measuredRow.value as? String, "Expanded")
            let preview = app.scrollViews.matching(identifier: "search-result-expanded-preview-" + id).firstMatch
            XCTAssertTrue(preview.waitForExistence(timeout: 45)); XCTAssertTrue(preview.isHittable && !preview.frame.isEmpty)
        }
        let keyboard = app.keyboards.firstMatch.exists
        XCTAssertTrue(continuationVisible(measuredRow, list: list, keyboard: keyboard))
        let finalTrace = try continuationTrace(traceNamespace)
        XCTAssertEqual(finalTrace.0.prefix(beforeTrace.0.count), beforeTrace.0)
        let finalItems = try continuationValidatePages(finalTrace.1, namespace: traceNamespace, process: process, expectedPages: page ? 2 : 1)
        XCTAssertEqual(try ui.loadedCount(), finalItems.count)
        let stableFrame = measuredRow.frame
        let drift = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in MainActor.assumeIsolated {
            !self.continuationVisible(measuredRow, list: list, keyboard: keyboard)
                || abs(measuredRow.frame.minX - stableFrame.minX) > 1 || abs(measuredRow.frame.minY - stableFrame.minY) > 1
                || field.value as? String != "אמר" || ui.control("global-search-loading").exists
                || ui.control("global-search-cancel").exists || ui.control("global-search-error").exists
                || ui.control("global-search-dirty").exists || (try? ui.loadedCount()) != finalItems.count
                || (try? self.continuationTrace(traceNamespace).0) != finalTrace.0
                || (try? self.actualNativeReceiptLines()) != rootReceipts || (try? self.targetProcessIdentifier()) != process
        } }, object: nil)
        drift.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [drift], timeout: 2), .completed, "Require real post-ACK geometry and no queued extra page")
        continuationAttach(finalTrace.0, name: "actual-public-search-original-provider-trace", json: false)
        XCTAssertEqual(ui.control("global-search-mode").value as? String, mode); XCTAssertEqual(ui.control("global-search-books").label, books)
        try requirePreservedOriginalWorkspace(current); XCTAssertEqual(try originalWorkspaceSelectionDocuments(), documents)
        XCTAssertEqual(try actualNativeReceiptLines(), rootReceipts, "A generic Search root ACK cannot replace a typed result/page receipt")

        // A genuine successful cached reference must be one-use. It is not
        // replaced with a fabricated unknown entity for the refusal case.
        if let deliveredURL {
            try openInExistingProcess(deliveredURL)
            XCTAssertTrue(app.alerts["Unable to open link"].waitForExistence(timeout: 10), "Require explicit original public replay refusal")
        } else {
            var refused = false
            do {
                if page { _ = try await system.intents["LoadNextOriginalSearchPageIntent"].makeIntent(page: entity).run() }
                else { _ = try await system.intents["RevealLoadedSearchResultIntent"].makeIntent(result: entity).run() }
            } catch {
                refused = true
                continuationAttach(Data(String(describing: type(of: error)).utf8), name: "actual-cached-search-reference-refusal-type", json: false)
            }
            XCTAssertTrue(refused, "The same previously successful reference cannot be replayed")
        }
        let refusalDrift = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in MainActor.assumeIsolated {
            (try? self.continuationTrace(traceNamespace).0) != finalTrace.0
                || (try? self.actualNativeReceiptLines()) != rootReceipts
                || (try? self.originalWorkspaceSelectionDocuments()) != documents
                || (try? self.targetProcessIdentifier()) != process
                || (try? self.continuationRead(self.publicSearchEvidenceFile(kind: kind, token: token, suffix: "result.json"), maximum: 128 * 1024)) != returned.raw
        } }, object: nil)
        refusalDrift.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [refusalDrift], timeout: 5), .completed, "No late state/evidence/receipt after the full original command budget")
        try requirePreservedOriginalWorkspace(current)
        XCTAssertFalse(FileManager.default.fileExists(atPath: try publicSearchEvidenceFile(kind: kind, token: token, suffix: "trigger.txt").path))
    }
}

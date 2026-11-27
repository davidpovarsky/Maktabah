

// Focused DEBUG continuation acceptance. The original UI submits the search;
// the only probe input is a nonce. No query, offset, hit ID, receipt, or source
// answer is injected into the production continuation operation.
extension NativeRoutingAcceptanceTests {
    private func continuationJSON(_ value: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    }

    private func continuationDigest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func continuationUUID(_ value: Any?, _ name: String) throws -> String {
        let raw = try XCTUnwrap(value as? String, "Require typed original UUID: " + name)
        _ = try XCTUnwrap(UUID(uuidString: raw), "Require valid original UUID: " + name)
        return raw
    }

    private func continuationDocuments() throws -> URL {
        let value = try actualReaderLogURL().deletingLastPathComponent().deletingLastPathComponent()
        XCTAssertEqual(value.lastPathComponent, "Documents")
        return value
    }

    private func continuationFile(kind: String, token: UUID, suffix: String) throws -> URL {
        XCTAssertTrue(["search-continuation-hit", "search-continuation-page"].contains(kind))
        XCTAssertTrue(["trigger.txt", "result.json", "outcome.json"].contains(suffix))
        return try continuationDocuments().appendingPathComponent("native-action-\(kind)-\(token.uuidString)-\(suffix)")
    }

    private func continuationRead(_ url: URL, maximum: Int, allowEmpty: Bool = false) throws -> Data {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        XCTAssertEqual(values.isRegularFile, true); XCTAssertEqual(values.isSymbolicLink, false)
        let size = try XCTUnwrap(values.fileSize)
        XCTAssertGreaterThanOrEqual(size, allowEmpty ? 0 : 1); XCTAssertLessThanOrEqual(size, maximum)
        guard size >= (allowEmpty ? 0 : 1), size <= maximum, values.isRegularFile == true, values.isSymbolicLink == false else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let bytes = try Data(contentsOf: url)
        XCTAssertEqual(bytes.count, size)
        return bytes
    }

    private func continuationAttach(_ data: Data, name: String, json: Bool = true) {
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: json ? "public.json" : "public.data")
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    private func continuationBlob(_ reference: Any?, kind: String, token: UUID) throws -> Data {
        let ref = try XCTUnwrap(reference as? [String: Any])
        let hash = try XCTUnwrap(ref["sha256"] as? String), count = try XCTUnwrap(ref["bytes"] as? Int)
        XCTAssertEqual(hash.count, 64)
        XCTAssertTrue(hash.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) })
        let filename = "native-action-\(kind)-\(token.uuidString)-data-\(hash).bin"
        XCTAssertEqual(ref["file"] as? String, filename)
        guard ref["file"] as? String == filename, hash.count == 64,
              hash.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let data = try continuationRead(continuationDocuments().appendingPathComponent(filename), maximum: 4 * 1024 * 1024, allowEmpty: true)
        XCTAssertEqual(data.count, count); XCTAssertEqual(continuationDigest(data), hash)
        return data
    }

    // Attach every lossless source/effect byte even when the actual return was
    // refused/unqualified or observation-envelope reporting failed afterward.
    private func continuationAttachBlobs(_ objects: [Any], kind: String, token: UUID) throws {
        var references: [String: [String: Any]] = [:]
        func visit(_ value: Any, depth: Int = 0) throws {
            guard depth < 96 else { throw CocoaError(.fileReadCorruptFile) }
            if let dictionary = value as? [String: Any] {
                if let filename = dictionary["file"] as? String, filename.hasSuffix(".bin") {
                    if let old = references[filename] {
                        XCTAssertEqual(try continuationJSON(old), try continuationJSON(dictionary))
                    }
                    references[filename] = dictionary
                } else { for child in dictionary.values { try visit(child, depth: depth + 1) } }
            } else if let array = value as? [Any] {
                for child in array { try visit(child, depth: depth + 1) }
            }
        }
        for object in objects { try visit(object) }
        XCTAssertLessThanOrEqual(references.count, 512)
        guard references.count <= 512 else { throw CocoaError(.fileReadCorruptFile) }
        var bytes = 0
        for key in references.keys.sorted() {
            let data = try continuationBlob(references[key], kind: kind, token: token)
            bytes += data.count
            XCTAssertLessThanOrEqual(bytes, 8 * 1024 * 1024)
            guard bytes <= 8 * 1024 * 1024 else { throw CocoaError(.fileReadCorruptFile) }
            continuationAttach(data, name: key, json: false)
        }
    }

    @MainActor private func continuationProof(kind: String, token: UUID) throws -> ([String: Any], [String: Any]) {
        let url = try continuationFile(kind: kind, token: token, suffix: "result.json")
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            FileManager.default.fileExists(atPath: url.path)
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 45), .completed,
            "Diagnostic wait cannot renew the production operation's original five-second deadline")
        let data = try continuationRead(url, maximum: 128 * 1024)
        continuationAttach(data, name: "original-continuation-envelope-\(kind)-\(token)")
        let proof = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let checkpointURL = try continuationFile(kind: kind, token: token, suffix: "outcome.json")
        // Inspect the deterministic original checkpoint even when the later
        // result envelope reports an error. Missing/invalid evidence fails.
        let checkpointData = try continuationRead(checkpointURL, maximum: 128 * 1024)
        continuationAttach(checkpointData, name: "original-continuation-return-\(kind)-\(token)")
        let checkpoint = try XCTUnwrap(JSONSerialization.jsonObject(with: checkpointData) as? [String: Any])
        try continuationAttachBlobs([checkpoint, proof], kind: kind, token: token)
        let reference = try XCTUnwrap(proof["outcomeCheckpoint"] as? [String: Any])
        XCTAssertEqual(reference["file"] as? String, checkpointURL.lastPathComponent)
        XCTAssertEqual(reference["bytes"] as? Int, checkpointData.count)
        XCTAssertEqual(reference["sha256"] as? String, continuationDigest(checkpointData))
        for value in [proof, checkpoint] {
            XCTAssertEqual(value["schemaVersion"] as? Int, 1)
            XCTAssertEqual(value["triggerToken"] as? String, token.uuidString)
            XCTAssertEqual(value["probeKind"] as? String, kind)
            XCTAssertEqual(String(try XCTUnwrap(value["processID"] as? Int)), try targetProcessIdentifier())
        }
        XCTAssertEqual(proof["actualReturnRetained"] as? Bool, true)
        XCTAssertNil(proof["probeError"], "Reporting failure is not a successful continuation: \(proof)")
        let outcome = try XCTUnwrap(checkpoint["outcome"] as? [String: Any])
        XCTAssertEqual(outcome["kind"] as? String, "acknowledged", "Retain the original refusal/partial return; never replace it")
        return (proof, try XCTUnwrap(outcome["receipt"] as? [String: Any]))
    }

    private func continuationTraceURL(_ namespace: String) throws -> URL {
        try actualReaderLogURL().deletingLastPathComponent().appendingPathComponent("search-native-\(namespace).jsonl")
    }

    private func continuationTrace(_ namespace: String) throws -> (Data, [[String: Any]]) {
        let data = try continuationRead(continuationTraceURL(namespace), maximum: 8 * 1024 * 1024)
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(text.hasSuffix("\n"), "A partial original trace is not a complete observation")
        return (data, try text.split(separator: "\n").map {
            try XCTUnwrap(JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any])
        })
    }

    // The sealed SQL resource proves exact book/line/title identity. Original
    // provider text and every metadata field are retained separately; this does
    // not claim that the six-row Reader text oracle contains all search text.
    private func continuationValidatePages(_ events: [[String: Any]], namespace: String,
                                            process: String, expectedPages: Int) throws -> [[String: Any]] {
        let metadata = try readerSourceMetadata(), positions = Set(metadata.rows.map { "\($0[1]):\($0[2])" })
        let selected = events.filter { $0["engine"] as? String == "otzaria" }
        let pages = selected.filter { $0["event"] as? String == "provider" }
        XCTAssertEqual(pages.count, expectedPages)
        XCTAssertEqual(Set(selected.compactMap { $0["sessionID"] as? String }).count, 1)
        XCTAssertEqual(Set(selected.compactMap { ($0["searchGeneration"] as? NSNumber)?.uint64Value }).count, 1)
        for event in selected {
            XCTAssertEqual(event["namespace"] as? String, namespace)
            XCTAssertEqual(event["schemaVersion"] as? Int, 1)
            XCTAssertEqual(event["profileID"] as? String, "miniTest10")
            XCTAssertEqual(String(try XCTUnwrap(event["processID"] as? Int)), process)
        }
        var consumed = 0, order: [String] = [], originals: [String: [String: Any]] = [:]
        var previousRecords: [[String: Any]] = []
        for event in pages {
            let request = try XCTUnwrap(event["request"] as? [String: Any])
            XCTAssertNil(request["query"])
            XCTAssertEqual(request["querySHA256"] as? String, continuationDigest(Data("אמר".utf8)))
            XCTAssertEqual(request["offset"] as? Int, consumed); XCTAssertEqual(request["limit"] as? Int, 100)
            let page = try XCTUnwrap(event["page"] as? [String: Any])
            let rows = try XCTUnwrap(page["results"] as? [[String: Any]])
            XCTAssertFalse(rows.isEmpty); XCTAssertLessThanOrEqual(rows.count, 100)
            for row in rows {
                let path = try XCTUnwrap(row["filePath"] as? String)
                XCTAssertTrue(path.hasPrefix("otzaria-book:"))
                let book = try XCTUnwrap(Int(path.dropFirst("otzaria-book:".count)))
                let line = try XCTUnwrap(row["segment"] as? Int)
                let rawID = try XCTUnwrap((row["id"] as? NSNumber)?.uint64Value)
                let id = "otzaria:\(path):\(rawID):\(line)"
                XCTAssertTrue(positions.contains("\(book):\(line)"))
                XCTAssertEqual(row["title"] as? String, try XCTUnwrap(metadata.books[String(book)]))
                if let old = originals[id] { XCTAssertEqual(try continuationJSON(old), try continuationJSON(row)) }
                else { originals[id] = row; order.append(id) }
            }
            consumed += rows.count
            XCTAssertEqual(event["nextOffset"] as? Int, consumed)
            let records = try XCTUnwrap(event["retainedRecords"] as? [[String: Any]])
            XCTAssertEqual(records.count, order.count)
            XCTAssertEqual(try continuationJSON(Array(records.prefix(previousRecords.count))), try continuationJSON(previousRecords))
            for (id, record) in zip(order, records) {
                XCTAssertEqual(try continuationJSON(try XCTUnwrap(record["metadata"])),
                               try continuationJSON(try XCTUnwrap(originals[id])))
                let item = try XCTUnwrap(record["item"] as? [String: Any])
                let book = try XCTUnwrap(item["bookID"] as? Int), line = try XCTUnwrap(item["lineIndex"] as? Int)
                XCTAssertEqual(item["id"] as? String, id)
                XCTAssertTrue(positions.contains("\(book):\(line)"))
                XCTAssertEqual(item["bookTitle"] as? String, try XCTUnwrap(metadata.books[String(book)]))
                XCTAssertEqual(item["locator"] as? String, "otzaria|book:\(book)|line:\(line)")
            }
            previousRecords = records
        }
        let publication = try XCTUnwrap(selected.last { $0["event"] as? String == "published" })
        let items = try XCTUnwrap(publication["items"] as? [[String: Any]])
        XCTAssertEqual(items.compactMap { $0["id"] as? String }, order)
        XCTAssertEqual(try continuationJSON(items), try continuationJSON(try previousRecords.map {
            try XCTUnwrap($0["item"] as? [String: Any])
        }))
        return items
    }

    @MainActor private func continuationVisible(_ element: XCUIElement, list: XCUIElement, keyboard: Bool) -> Bool {
        guard element.exists, element.isHittable, !element.frame.isEmpty, list.exists,
              list.isHittable, !list.frame.isEmpty else { return false }
        var viewport = list.frame.intersection(app.frame)
        if keyboard {
            guard app.keyboards.count == 1, app.keyboards.firstMatch.exists else { return false }
            let top = app.keyboards.firstMatch.frame.minY
            viewport.size.height = max(0, min(viewport.maxY, top) - viewport.minY)
        }
        let intersection = element.frame.intersection(viewport)
        return !intersection.isNull && intersection.width * intersection.height >= element.frame.width * element.frame.height * 0.98
    }

    @MainActor private func continuationVoiceOver(expectedTitle: String, expectedSnippet: String,
                                                  ui: OriginalSearchContextUI) throws {
        let service = XCUIDevice.shared.voiceOverService
        XCTAssertFalse(service.isEnabled, "The test owns enabling and restoring the real service")
        try service.enable()
        defer { do { try service.disable() } catch { XCTFail("Could not restore VoiceOver: \(error)") } }
        XCTAssertTrue(service.isEnabled)
        func normalized(_ text: String) -> String { text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ") }
        let title = normalized(expectedTitle)
        let snippet = normalized(expectedSnippet).split(separator: " ").prefix(6).joined(separator: " ")
        XCTAssertGreaterThan(snippet.count, 12); XCTAssertFalse(title.isEmpty)
        var speech = [try service.currentSpeech().utterance]
        var sawTitle = false, sawText = false
        defer {
            let attachment = XCTAttachment(string: speech.enumerated().map { "\($0.offset): \($0.element)" }.joined(separator: "\n"))
            attachment.name = "actual-system-VoiceOver-continuation-speech"; attachment.lifetime = .keepAlways; add(attachment)
            ui.capture("actual-system-VoiceOver-continuation")
        }
        for _ in 0..<64 {
            let utterance = normalized(try XCTUnwrap(speech.last))
            sawTitle = sawTitle || utterance.contains(title)
            sawText = sawText || utterance.contains(snippet)
            if sawTitle && sawText { break }
            speech.append(try service.moveForward().utterance)
        }
        // Output exposes utterance, not focused-row identity. These are two
        // reachability checks on the original Search surface; they do not
        // uniquely attest traversal of this expanded row or its full context.
        XCTAssertTrue(sawTitle, "A retained original source title must be reachable in real VoiceOver speech")
        XCTAssertTrue(sawText, "A retained original provider snippet must be reachable on the original Search surface")
    }

    @MainActor
    func runOriginalSearchContinuation(expectedPad: Bool, page: Bool, keyboard: Bool = false,
                                       voiceOver: Bool = false) throws {
        let kind = page ? "search-continuation-page" : "search-continuation-hit"
        let priorOrientation = XCUIDevice.shared.orientation
        let service = XCUIDevice.shared.voiceOverService, priorVoiceOver = service.isEnabled
        if priorVoiceOver { try service.disable() }
        defer {
            XCUIDevice.shared.orientation = priorOrientation
            do {
                if priorVoiceOver && !service.isEnabled { try service.enable() }
                if !priorVoiceOver && service.isEnabled { try service.disable() }
            } catch { XCTFail("Could not restore actual accessibility service state: \(error)") }
        }
        for language in ["en", "he"] {
            let token = UUID(), traceNamespace = UUID().uuidString
            XCTAssertEqual(isPad, expectedPad)
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
            let oracle = try systemReaderOracleDocument()
            let initial = try XCTUnwrap(oracle.rows.first { $0.id == oracle.bootstrapRowID })
            XCTAssertEqual(ProcessInfo.processInfo.environment["R27_EXPECTED_OTZARIA_WORK_KEY"], "book:\(initial.bookId)")
            try requireReaderLocator("otzaria|book:\(initial.bookId)|line:\(initial.lineIndex)", timeout: 60)
            let ui = OriginalSearchContextUI(app: app, test: self)
            try ui.returnToOriginalSearch()
            try ui.require("global-search-mode").tap()
            try ui.require("global-search-mode-advanced").tap()
            let field = try ui.require("global-search-query")
            XCTAssertTrue(field.elementType == .searchField || field.elementType == .textField)
            XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "global-search-query").count, 1)
            field.tap()
            let old = (field.value as? String) ?? ""
            if !old.isEmpty && old != field.placeholderValue {
                field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count))
            }
            field.typeText("אמר\n")
            try ui.wait("Require one real original submitted first page before granting a continuation", timeout: 90) {
                guard !ui.control("global-search-loading").exists, !ui.control("global-search-cancel").exists,
                      !ui.control("global-search-error").exists, !ui.control("global-search-dirty").exists,
                      let events = try? self.continuationTrace(traceNamespace).1,
                      let last = events.last(where: { $0["event"] as? String == "published" }),
                      let items = last["items"] as? [[String: Any]], items.count > 20,
                      let count = try? ui.loadedCount() else { return false }
                return items.count == count
            }
            let process = try targetProcessIdentifier()
            let initialTrace = try continuationTrace(traceNamespace)
            let firstItems = try continuationValidatePages(initialTrace.1, namespace: traceNamespace, process: process, expectedPages: 1)
            let firstID = try XCTUnwrap(firstItems.first?["id"] as? String)
            let lastItem = try XCTUnwrap(firstItems.last), lastID = try XCTUnwrap(lastItem["id"] as? String)
            try ui.assertOriginalSearchResize(rtl: language == "he", query: "אמר", firstStableID: firstID)
            if keyboard {
                field.tap()
                XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10))
                XCTAssertEqual(field.value as? String, "אמר", "Focusing the original field must not edit or resubmit")
            }
            let list = try ui.require("global-search-results")
            if !page {
                XCTAssertFalse(continuationVisible(ui.control("search-result-preview-toggle-" + lastID), list: list, keyboard: keyboard),
                    "Require a genuinely offscreen loaded target; an already visible proxy cannot prove reveal")
            }
            let beforeTrace = try continuationTrace(traceNamespace)
            XCTAssertEqual(beforeTrace.0, initialTrace.0, "Resize/focus setup must not secretly fetch another page")
            let workspace = try actualReaderWorkspace(), current = try workspace.current()
            let sceneID = try XCTUnwrap(workspace.lastActiveSceneID)
            let savedDocuments = try originalWorkspaceSelectionDocuments()
            let rootReceipts = try actualNativeReceiptLines()
            let mode = try XCTUnwrap(ui.require("global-search-mode").value as? String)
            let books = try ui.require("global-search-books").label
            let trigger = try continuationFile(kind: kind, token: token, suffix: "trigger.txt")
            XCTAssertFalse(FileManager.default.fileExists(atPath: trigger.path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: try continuationFile(kind: kind, token: token, suffix: "result.json").path))
            try Data(token.uuidString.utf8).write(to: trigger, options: [.withoutOverwriting])
            let (proof, receipt) = try continuationProof(kind: kind, token: token)
            let before = try XCTUnwrap(receipt["before"] as? [String: Any])
            let after = try XCTUnwrap(receipt["after"] as? [String: Any])
            let observation = try XCTUnwrap(proof["observation"] as? [String: Any])
            XCTAssertEqual(try continuationJSON(try XCTUnwrap(observation["source"])), try continuationJSON(before))
            _ = try continuationUUID(receipt["requestID"], "requestID")
            XCTAssertEqual(before["sceneID"] as? String, sceneID)
            let backend = try XCTUnwrap(before["snapshot"] as? [String: Any])
            XCTAssertEqual(backend["backend"] as? String, "otzaria")
            let originalPublication = try XCTUnwrap(beforeTrace.1.last { $0["event"] as? String == "published" })
            XCTAssertEqual(try XCTUnwrap(backend["generation"] as? NSNumber),
                           try XCTUnwrap(originalPublication["backendGeneration"] as? NSNumber))
            XCTAssertEqual(try XCTUnwrap(before["submissionRevision"] as? Int),
                           try XCTUnwrap(originalPublication["submissionRevision"] as? Int))
            for value in [before, after] {
                for key in ["observationID", "sessionID", "modelID"] { _ = try continuationUUID(value[key], key) }
                for key in ["generation", "sourceRevision", "pageRevision"] {
                    _ = try XCTUnwrap((value[key] as? NSNumber).flatMap { UInt64($0.stringValue) }, key)
                }
                for key in ["submissionRevision", "cancellationRevision", "paginationRevision"] {
                    _ = try XCTUnwrap(value[key] as? Int, key)
                }
            }
            for key in ["observationID", "sceneID", "snapshot", "sessionID", "modelID", "generation", "sourceRevision", "submissionRevision", "cancellationRevision", "configuration"] {
                XCTAssertEqual(try continuationJSON([key: try XCTUnwrap(before[key])]),
                               try continuationJSON([key: try XCTUnwrap(after[key])]), "Exact original source field: " + key)
            }
            let operation = try XCTUnwrap(receipt["operation"] as? [String: Any])
            XCTAssertEqual(try continuationJSON(operation), try continuationJSON(try XCTUnwrap(proof["selectedOperation"])))
            XCTAssertEqual(operation["kind"] as? String, page ? "nextOriginalPage" : "revealLoadedHit")
            let effects = try XCTUnwrap(receipt["effects"] as? [[String: Any]])
            let visible = try XCTUnwrap(receipt["visible"] as? [String: Any])
            for key in ["witnessID", "listID"] { _ = try continuationUUID(visible[key], key) }
            XCTAssertGreaterThan(try XCTUnwrap((visible["layoutRevision"] as? NSNumber)?.uint64Value), 0)
            let loaded = try XCTUnwrap(observation["loadedHits"] as? [[String: Any]])
            XCTAssertEqual(loaded.compactMap { $0["stableID"] as? String }, firstItems.compactMap { $0["id"] as? String })
            var speechIdentity: [String: Any]?
            let measuredRow: XCUIElement
            if page {
                XCTAssertEqual(try continuationUUID(operation["token"], "operation token"),
                               try continuationUUID(observation["nextPageToken"], "original next-page token"))
                XCTAssertEqual(effects.compactMap { $0["kind"] as? String }, ["pageRequested", "pageCommitted"])
                let committed = try XCTUnwrap(effects.last?["page"] as? [String: Any])
                XCTAssertEqual(try continuationUUID(effects.first?["attemptID"], "requested attempt"),
                               try continuationUUID(committed["attemptID"], "committed attempt"))
                XCTAssertEqual(try continuationUUID(committed["modelID"], "page model"),
                               try continuationUUID(before["modelID"], "source model"))
                XCTAssertEqual(try XCTUnwrap(committed["generation"] as? NSNumber), try XCTUnwrap(before["generation"] as? NSNumber))
                XCTAssertTrue(committed["sourceEvidence"] is NSNull, "Original Otzaria page does not provide a separate provider-evidence Data value")
                let request = try XCTUnwrap(JSONSerialization.jsonObject(with: continuationBlob(committed["request"], kind: kind, token: token)) as? [String: Any])
                XCTAssertEqual(request["query"] as? String, "אמר")
                XCTAssertEqual(try XCTUnwrap(request["offset"] as? Int), try XCTUnwrap(committed["requestOffset"] as? Int))
                XCTAssertEqual(request["limit"] as? Int, 100)
                XCTAssertEqual(committed["requestLimit"] as? Int, 100)
                let rawBefore = try XCTUnwrap((beforeTrace.1.last { $0["event"] as? String == "provider" })?["nextOffset"] as? Int)
                XCTAssertEqual(committed["requestOffset"] as? Int, rawBefore)
                XCTAssertEqual(committed["consumedBefore"] as? Int, rawBefore)
                XCTAssertEqual(committed["cursorBefore"] as? Int, rawBefore)
                let now = try continuationTrace(traceNamespace)
                let provider = try XCTUnwrap(now.1.last { $0["event"] as? String == "provider" })
                let raw = try XCTUnwrap((provider["page"] as? [String: Any])?["results"] as? [[String: Any]])
                XCTAssertEqual(committed["rawRowCount"] as? Int, raw.count)
                XCTAssertEqual(committed["consumedAfter"] as? Int, rawBefore + raw.count)
                XCTAssertEqual(try XCTUnwrap(committed["rawNextOffset"] as? Int), try XCTUnwrap(provider["nextOffset"] as? Int))
                XCTAssertEqual(committed["mappedRowCount"] as? Int, raw.count,
                    "This original Otzaria adapter maps each raw row before retained-result deduplication")
                let hasMore = try XCTUnwrap(committed["hasMore"] as? Bool)
                if hasMore { XCTAssertEqual(committed["normalizedNextOffset"] as? Int, rawBefore + raw.count) }
                else { XCTAssertTrue(committed["normalizedNextOffset"] is NSNull) }
                XCTAssertEqual(try XCTUnwrap(committed["pageRevision"] as? NSNumber), try XCTUnwrap(after["pageRevision"] as? NSNumber))
                XCTAssertEqual(try XCTUnwrap(after["paginationRevision"] as? Int), try XCTUnwrap(before["paginationRevision"] as? Int) + 1)
                XCTAssertTrue(visible["rowID"] is NSNull); XCTAssertTrue(visible["identity"] is NSNull)
                measuredRow = ui.control("search-result-preview-toggle-" + firstID)
            } else {
                let hit = try XCTUnwrap(loaded.last)
                XCTAssertEqual(try continuationUUID(operation["token"], "operation token"),
                               try continuationUUID(hit["token"], "loaded hit token"))
                XCTAssertEqual(hit["stableID"] as? String, lastID)
                XCTAssertEqual(try XCTUnwrap(hit["locator"] as? String), try XCTUnwrap(lastItem["locator"] as? String))
                XCTAssertEqual(effects.compactMap { $0["kind"] as? String }, ["hitSelectionApplied"])
                XCTAssertEqual(try continuationJSON(try XCTUnwrap(effects.first?["hit"])), try continuationJSON(hit))
                let identityBytes = try continuationBlob(hit["identity"], kind: kind, token: token)
                let identity = try XCTUnwrap(JSONSerialization.jsonObject(with: identityBytes) as? [String: Any])
                speechIdentity = identity
                XCTAssertEqual(identity["stableID"] as? String, lastID)
                XCTAssertEqual(try XCTUnwrap(identity["book"] as? Int), try XCTUnwrap(lastItem["bookID"] as? Int))
                XCTAssertEqual(try XCTUnwrap(identity["page"] as? Int), try XCTUnwrap(lastItem["lineIndex"] as? Int))
                XCTAssertEqual(try XCTUnwrap(identity["title"] as? String), try XCTUnwrap(lastItem["bookTitle"] as? String))
                XCTAssertEqual(continuationDigest(Data(try XCTUnwrap(identity["text"] as? String).utf8)), lastItem["snippetSHA256"] as? String)
                XCTAssertEqual(try continuationBlob(visible["identity"], kind: kind, token: token), identityBytes)
                _ = try continuationUUID(visible["rowID"], "visible original row")
                XCTAssertEqual(try XCTUnwrap(before["pageRevision"] as? NSNumber), try XCTUnwrap(after["pageRevision"] as? NSNumber))
                XCTAssertEqual(try XCTUnwrap(before["paginationRevision"] as? Int), try XCTUnwrap(after["paginationRevision"] as? Int))
                measuredRow = ui.control("search-result-preview-toggle-" + lastID)
                XCTAssertEqual(measuredRow.value as? String, "Expanded")
                let preview = app.scrollViews.matching(identifier: "search-result-expanded-preview-" + lastID).firstMatch
                XCTAssertTrue(preview.waitForExistence(timeout: 45), "Require the original full-context scroll owner, not its small overlay marker")
                XCTAssertTrue(preview.isHittable && !preview.frame.isEmpty)
            }
            XCTAssertTrue(continuationVisible(measuredRow, list: list, keyboard: keyboard))
            let finalTrace = try continuationTrace(traceNamespace)
            XCTAssertEqual(finalTrace.0.prefix(beforeTrace.0.count), beforeTrace.0)
            let finalItems = try continuationValidatePages(finalTrace.1, namespace: traceNamespace,
                                                           process: process, expectedPages: page ? 2 : 1)
            XCTAssertEqual(proof["originalBeforeRowIDs"] as? [String], firstItems.compactMap { $0["id"] as? String })
            XCTAssertEqual(proof["originalAfterRowIDs"] as? [String], finalItems.compactMap { $0["id"] as? String })
            XCTAssertEqual(try ui.loadedCount(), finalItems.count)
            XCTAssertEqual(proof["originalQuery"] as? String, "אמר")
            for (name, key) in [("Submission", "submissionRevision"), ("Cancellation", "cancellationRevision"),
                                ("Pagination", "paginationRevision")] {
                XCTAssertEqual(try XCTUnwrap(proof["original\(name)Before"] as? Int), try XCTUnwrap(before[key] as? Int))
                XCTAssertEqual(try XCTUnwrap(proof["original\(name)After"] as? Int), try XCTUnwrap(after[key] as? Int))
            }
            XCTAssertEqual(proof["originalBookIDs"] as? [Int], [])
            XCTAssertEqual(proof["originalHasSubmitted"] as? Bool, true)
            for key in ["originalIsSearching", "originalIsLoadingMore", "originalResultsAreDirty"] {
                XCTAssertEqual(proof[key] as? Bool, false)
            }
            let stableFrame = measuredRow.frame
            let drift = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                MainActor.assumeIsolated {
                    !self.continuationVisible(measuredRow, list: list, keyboard: keyboard)
                        || abs(measuredRow.frame.minX - stableFrame.minX) > 1
                        || abs(measuredRow.frame.minY - stableFrame.minY) > 1
                        || field.value as? String != "אמר" || ui.control("global-search-loading").exists
                        || ui.control("global-search-error").exists || ui.control("global-search-dirty").exists
                        || (try? ui.loadedCount()) != finalItems.count
                        || (try? self.continuationTrace(traceNamespace).0) != finalTrace.0
                        || (try? self.actualNativeReceiptLines()) != rootReceipts
                        || (try? self.targetProcessIdentifier()) != process
                }
            }, object: nil)
            drift.isInverted = true
            XCTAssertEqual(XCTWaiter.wait(for: [drift], timeout: 2), .completed,
                "Require stable original post-ACK row/list and no queued automatic extra page")
            continuationAttach(finalTrace.0, name: "original-continuation-provider-trace-\(language)", json: false)
            XCTAssertEqual(try actualNativeReceiptLines(), rootReceipts, "A generic Search root receipt cannot replace continuation evidence")
            XCTAssertEqual(try targetProcessIdentifier(), process)
            XCTAssertEqual(field.value as? String, "אמר")
            XCTAssertEqual(ui.control("global-search-mode").value as? String, mode)
            XCTAssertEqual(ui.control("global-search-books").label, books)
            try requirePreservedOriginalWorkspace(current)
            XCTAssertEqual(try originalWorkspaceSelectionDocuments(), savedDocuments)
            ui.capture("original-continuation-\(kind)-\(language)-\(keyboard ? "keyboard" : "viewport")")
            if voiceOver {
                let identity = try XCTUnwrap(speechIdentity)
                try continuationVoiceOver(expectedTitle: XCTUnwrap(identity["title"] as? String),
                    expectedSnippet: XCTUnwrap(identity["text"] as? String), ui: ui)
                XCTAssertEqual(field.value as? String, "אמר")
                try requirePreservedOriginalWorkspace(current)
                XCTAssertEqual(try originalWorkspaceSelectionDocuments(), savedDocuments)
            }
        }
    }
}

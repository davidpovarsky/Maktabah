//
//  SefariaEmbeddedAcceptanceTests.swift
//  Maktabah-iOSUITests
//
//  Acceptance tests for Sefaria-Mobile embedded original runtime on iPad Simulator.
//

import XCTest

final class SefariaEmbeddedAcceptanceTests: MaktabahUITestBase {

    func testEmbeddedSefariaFullAcceptanceDiagnostic() throws {
        launchWithTier(
            .smoke,
            scenario: "embeddedAcceptance",
            backend: "sefariaEmbedded",
            extraArgs: ["-runSefariaEmbeddedAcceptance"]
        )
        dismissAlertsIfNeeded()

        let resultElement = app.descendants(matching: .any)["sefaria-embedded-acceptance-result"]
        XCTAssertTrue(resultElement.waitForExistence(timeout: 60.0), "sefaria-embedded-acceptance-result element must appear within 60s")

        // Wait until accessibilityValue or accessibilityLabel contains SUCCESS or FAILURE
        let predicate = NSPredicate(format: "value CONTAINS 'SUCCESS' OR value CONTAINS 'FAILURE' OR label CONTAINS 'SUCCESS' OR label CONTAINS 'FAILURE'")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: resultElement)
        let waitResult = XCTWaiter().wait(for: [expectation], timeout: 120.0)
        XCTAssertEqual(waitResult, .completed, "Acceptance runner timed out waiting for diagnostic completion")

        let rawString: String? = {
            if let val = resultElement.value as? String, val.contains("{") {
                return val
            }
            if resultElement.label.contains("{") {
                return resultElement.label
            }
            return (resultElement.value as? String) ?? resultElement.label
        }()

        guard let jsonString = rawString,
              let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Failed to parse sefaria-embedded-acceptance-result JSON: \(String(describing: rawString))")
            return
        }

        let status = json["status"] as? String
        let failedStage = json["failedStage"] as? String
        let errorMessage = json["errorMessage"] as? String
        let stages = json["stages"] as? [String: [String: Any]] ?? [:]

        print("=== Acceptance Diagnostics Report ===")
        print(jsonString)

        XCTAssertEqual(status, "SUCCESS", "Acceptance failed at stage '\(failedStage ?? "unknown")': \(errorMessage ?? "none")")

        // Assert all mandatory stages passed
        let requiredStages = [
            "waitForReady",
            "echoHebrew",
            "echoErrorInjection",
            "lateGenerationRejected",
            "runtimeInitialize",
            "catalogTOC",
            "textLoadGenesis",
            "textLoadBerakhot",
            "textOriginRemote",
            "navigationTextToc",
            "searchLive",
            "searchOpenResult",
            "fullReactSurface",
            "normalAppBootstrap",
            "backendSwitchRegression"
        ]

        for stage in requiredStages {
            guard let stageDict = stages[stage], stageDict["passed"] as? Bool == true else {
                XCTFail("Mandatory acceptance stage '\(stage)' failed or was skipped in report: \(jsonString)")
                return
            }
        }
    }

    func testEmbeddedSefariaCatalogAndAppLaunch() throws {
        // Launch with sefariaEmbedded backend and catalog scenario
        launchWithScenario("catalog", backend: "sefariaEmbedded")
        dismissAlertsIfNeeded()

        let libraryTab = findTabButton(hebrew: "ספר", english: "Library")
        XCTAssertTrue(waitForElement(libraryTab, timeout: 20.0), "Library tab must be present when launching with sefariaEmbedded")
    }

    func testEmbeddedSefariaReaderPresentation() throws {
        // Launch with sefariaEmbedded backend and reader scenario
        launchWithScenario("reader", backend: "sefariaEmbedded")
        dismissAlertsIfNeeded()

        let readerSurface = app.textViews["reader-text"]
        XCTAssertTrue(waitForElement(readerSurface, timeout: 20.0), "Reader surface must be presented for sefariaEmbedded")
    }

    func testThreeBackendSwitchRegression() throws {
        // Run full synthetic backend switch regression
        launchWithScenario("backendSwitchRegression", backend: "sefariaEmbedded")
        dismissAlertsIfNeeded()

        let libraryTab = findTabButton(hebrew: "ספר", english: "Library")
        XCTAssertTrue(waitForElement(libraryTab, timeout: 20.0), "App must complete backend switch scenario cleanly")
    }
}


// Source-backed Native coverage for the original Embedded TOC and the original
// Remote failure/retry path. These declarations are NOT_RUN until Apple runs them.
@MainActor
private final class SefariaTOCNativeObservation {
    let app: XCUIApplication
    init(_ app: XCUIApplication) { self.app = app }

    func visible(_ element: XCUIElement) -> Bool {
        let frame = element.frame
        return element.exists && element.isHittable && !frame.isEmpty
            && frame.minX.isFinite && frame.minY.isFinite
            && app.windows.firstMatch.frame.contains(frame)
    }

    func visibleIdentifier(_ identifier: String) -> Bool {
        app.descendants(matching: .any).matching(identifier: identifier)
            .allElementsBoundByIndex.filter { visible($0) }.count == 1
    }
}

private struct SefariaTOCFaultFiles: Sendable {
    let namespace: String
    let nonce: UUID
    let root: URL
    let metadataURL: URL
    let metadata: Data
    var documents: URL { root.appendingPathComponent("Documents", isDirectory: true) }
    var prefix: String { "sefaria-toc-" + namespace }
    var commandURL: URL { documents.appendingPathComponent(prefix + "-command.json") }
    func url(_ stage: String) -> URL {
        documents.appendingPathComponent(prefix + "-" + nonce.uuidString + "-" + stage + ".json")
    }
    func verifyOwner() throws {
        guard root.standardizedFileURL == root.resolvingSymlinksInPath().standardizedFileURL,
              UUID(uuidString: root.lastPathComponent) != nil,
              root.deletingLastPathComponent().lastPathComponent == "Application",
              documents.standardizedFileURL == documents.resolvingSymlinksInPath().standardizedFileURL,
              metadata == (try Self.read(metadataURL, limit: 65_536)) else {
            throw NSError(domain: "SefariaTOCAcceptanceOwner", code: 1)
        }
    }
    static func read(_ url: URL, limit: Int) throws -> Data {
        guard url.standardizedFileURL == url.resolvingSymlinksInPath().standardizedFileURL else {
            throw NSError(domain: "SefariaTOCAcceptanceOwner", code: 2)
        }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, size <= limit else {
            throw NSError(domain: "SefariaTOCAcceptanceOwner", code: 3)
        }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var data = Data()
        while data.count <= limit {
            guard let part = try handle.read(upToCount: limit + 1 - data.count), !part.isEmpty else { break }
            data.append(part)
        }
        guard data.count <= limit else { throw NSError(domain: "SefariaTOCAcceptanceOwner", code: 4) }
        return data
    }
    func proof(_ stage: String) throws -> [String: Any] {
        try verifyOwner()
        let data = try Self.read(url(stage), limit: 8_192)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys) == Set(["schemaVersion", "namespace", "nonce", "backend", "workKey",
                                      "ownerID", "stage", "method", "url", "timestamp", "errorCode"]),
              object["schemaVersion"] as? Int == 1,
              object["namespace"] as? String == namespace,
              object["nonce"] as? String == nonce.uuidString,
              object["backend"] as? String == "sefaria", object["workKey"] as? String == "Genesis",
              object["stage"] as? String == stage, object["method"] as? String == "GET",
              object["url"] as? String == "https://www.sefaria.org/api/v2/raw/index/Genesis",
              let owner = object["ownerID"] as? String, !owner.isEmpty,
              let timestamp = object["timestamp"] as? Double, timestamp.isFinite,
              object["errorCode"] as? Int == (stage == "failed" ? URLError.dataNotAllowed.rawValue : 0) else {
            throw NSError(domain: "SefariaTOCAcceptanceProof", code: 1)
        }
        return object
    }
}

class SefariaTOCNativeBase: R27NativeUIBase {
    @MainActor
    private func requireVisible(_ identifier: String, timeout: TimeInterval = 30) throws -> XCUIElement {
        let observation = SefariaTOCNativeObservation(app)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { observation.visibleIdentifier(identifier) }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: timeout), .completed,
                       "Require one actual visible, hittable original control: \(identifier)")
        let matches = app.descendants(matching: .any).matching(identifier: identifier)
            .allElementsBoundByIndex.filter { observation.visible($0) }
        return try XCTUnwrap(matches.count == 1 ? matches.first : nil)
    }

    @MainActor
    private func requireReader(backend: String, work: String, reference: String? = nil) throws {
        let locator = app.staticTexts["reader-current-locator"]
        XCTAssertTrue(locator.waitForExistence(timeout: 30))
        let expected = backend + "|" + work + "|ref:"
        let predicate = reference.map { NSPredicate(format: "label == %@", expected + $0) }
            ?? NSPredicate(format: "label BEGINSWITH %@", expected)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: locator)],
                                     timeout: 45), .completed,
                       "Require the original Reader's backend/work/canonical section")
        XCTAssertEqual(app.staticTexts.matching(identifier: "reader-current-locator").count, 1)
        assertReaderHasText() // Preserved original TextKit, glyph, native frame and real-title oracle.
    }

    @MainActor
    private func openOriginalBook(_ work: String, title: String, backend: String) throws {
        let launcher = readerLibraryPaletteLauncher()
        launcher.tap()
        let palette = try requireVisible("reader-library-command-palette", timeout: 20)
        let fields = palette.textFields
        XCTAssertEqual(fields.count, 1, "Original palette owns exactly one query field")
        let field = fields.firstMatch
        XCTAssertTrue(field.isHittable)
        field.tap()
        field.typeKey("a", modifierFlags: .command)
        field.typeText(title)
        XCTAssertEqual(field.value as? String, title)
        let rows = palette.scrollViews.buttons.matching(NSPredicate(format: "label == %@", title))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 30))
        let observation = SefariaTOCNativeObservation(app)
        let visible = rows.allElementsBoundByIndex.filter { observation.visible($0) }
        XCTAssertEqual(visible.count, 1, "Require the independently named original catalog work")
        let row = try XCTUnwrap(visible.count == 1 ? visible.first : nil)
        row.tap()
        try requireReader(backend: backend, work: work)
    }

    @MainActor
    private func showOriginalTOC() throws {
        let page = app.buttons["reader-sidebar-page-1"]
        if page.exists {
            let observation = SefariaTOCNativeObservation(app)
            if !observation.visible(page) {
                let toggle = readerSidebarToggle() // Original unique custom/native split owner.
                XCTAssertTrue(observation.visible(toggle))
                toggle.tap()
            }
            try requireVisible("reader-sidebar-page-1", timeout: 15).tap()
        } else {
            // Original compact Reader menu. No fabricated route or coordinates.
            try requireVisible("reader-more-menu", timeout: 15).tap()
            try requireVisible("reader-toc-toggle", timeout: 15).tap()
        }
        _ = try requireVisible("toc-content-list", timeout: 45)
        XCTAssertFalse(app.descendants(matching: .any)["toc-empty"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["toc-failure"].exists)
    }

    @MainActor
    private func selectStructure(_ title: String) throws {
        let picker = try requireVisible("toc-structure-picker", timeout: 20)
        let rows = picker.buttons.matching(NSPredicate(format: "label == %@", title))
        XCTAssertEqual(rows.count, 1, "Require the original localized structure label")
        let row = rows.firstMatch
        XCTAssertTrue(SefariaTOCNativeObservation(app).visible(row))
        row.tap()
        XCTAssertTrue(row.isSelected)
        _ = try requireVisible("toc-content-list", timeout: 20)
    }

    @MainActor
    private func row(_ label: String, scrolls: Int = 12) throws -> XCUIElement {
        let observation = SefariaTOCNativeObservation(app)
        for turn in 0...scrolls {
            let list = try requireVisible("toc-content-list", timeout: 15)
            let rows = list.buttons.matching(NSPredicate(
                format: "identifier BEGINSWITH %@ AND label == %@", "toc-row-", label))
            let visible = rows.allElementsBoundByIndex.filter { observation.visible($0) }
            if visible.count == 1 { return visible[0] }
            XCTAssertLessThanOrEqual(visible.count, 1, "A TOC label must identify one original visible row")
            if turn == scrolls { break }
            list.swipeUp(velocity: .slow)
        }
        XCTFail("Original TOC row did not become uniquely visible within \(scrolls) list swipes: \(label)")
        throw NSError(domain: "SefariaTOCOriginalRow", code: 1)
    }

    @MainActor
    private func expand(_ title: String, hebrew: Bool) throws {
        let parent = try row(title)
        XCTAssertTrue(parent.identifier.hasPrefix("toc-row-"))
        let id = String(parent.identifier.dropFirst("toc-row-".count))
        XCTAssertNotNil(Int(id), "Disclosure must belong to the same original LegacyIdentity node")
        let disclosure = try requireVisible("toc-expand-" + id, timeout: 15)
        XCTAssertEqual(disclosure.label, hebrew ? "הרחב את \(title)" : "Expand \(title)")
        if hebrew {
            XCTAssertLessThan(disclosure.frame.midX, parent.frame.midX,
                              "The original RTL row must keep its disclosure to the left of its label")
        }
        disclosure.tap()
        XCTAssertEqual(disclosure.label, hebrew ? "כווץ את \(title)" : "Collapse \(title)")
    }

    @MainActor
    fileprivate func exerciseEmbeddedTalmud(language: String) throws {
        let hebrew = language == "he"
        launchReader(backend: "sefariaEmbedded", language: language)
        try requireReader(backend: "sefariaEmbedded", work: "Genesis")
        for (work, title) in [("Berakhot", hebrew ? "ברכות" : "Berakhot"),
                              ("Eruvin", hebrew ? "עירובין" : "Eruvin")] {
            try openOriginalBook(work, title: title, backend: "sefariaEmbedded")
            try showOriginalTOC()
            try selectStructure(hebrew ? "דפים" : "Folios")
            for (address, display) in [("12a", hebrew ? "י״ב ע״א" : "12a"),
                                       ("12b", hebrew ? "י״ב ע״ב" : "12b")] {
                let target = try row(display)
                XCTAssertEqual(target.label, display)
                target.tap()
                try requireReader(backend: "sefariaEmbedded", work: work, reference: work + " " + address)
                capture("sefaria-mobile-\(language)-\(work)-\(address)")
                try showOriginalTOC()
                try selectStructure(hebrew ? "דפים" : "Folios")
            }
            if work == "Berakhot" {
                try selectStructure(hebrew ? "פרקים" : "Chapters")
                let title = hebrew ? "מאימתי" : "Chapter 1; MeEimatai"
                try row(title).tap()
                // Original wholeRef is Berakhot 2a:1-13a:15. The original
                // ReaderDestinationResolver bounds this to section 2a.
                try requireReader(backend: "sefariaEmbedded", work: work, reference: "Berakhot 2a")
                capture("sefaria-mobile-\(language)-Berakhot-original-chapter")
            }
        }
    }

    @MainActor
    fileprivate func exerciseEmbeddedComplex(language: String) throws {
        let hebrew = language == "he"
        launchReader(backend: "sefariaEmbedded", language: language)
        try requireReader(backend: "sefariaEmbedded", work: "Genesis")
        try showOriginalTOC()
        try selectStructure(hebrew ? "פרקים" : "Chapters")
        try row(hebrew ? "פרק ב׳" : "2").tap()
        try requireReader(backend: "sefariaEmbedded", work: "Genesis", reference: "Genesis 2")
        capture("sefaria-mobile-\(language)-Genesis-chapter-two")

        try openOriginalBook("Rashi on Genesis", title: hebrew ? "רש\"י על בראשית" : "Rashi on Genesis",
                             backend: "sefariaEmbedded")
        try showOriginalTOC()
        try selectStructure(hebrew ? "פרקים" : "Chapters")
        try expand(hebrew ? "פרק ב׳" : "2", hebrew: hebrew)
        try row(hebrew ? "א׳" : "1", scrolls: 2).tap()
        // Source node is Rashi on Genesis 2:1; the existing Reader resolver
        // presents its bounded chapter. No exact segment-focus claim is made.
        try requireReader(backend: "sefariaEmbedded", work: "Rashi on Genesis", reference: "Rashi on Genesis 2")
        capture("sefaria-mobile-\(language)-Rashi-original-child")

        try openOriginalBook("Pesach Haggadah", title: hebrew ? "הגדה של פסח" : "Pesach Haggadah",
                             backend: "sefariaEmbedded")
        try showOriginalTOC()
        let kadesh = try row(hebrew ? "קדש" : "Kadesh")
        XCTAssertEqual(kadesh.label, hebrew ? "קדש" : "Kadesh")
        try expand(hebrew ? "מגיד" : "Magid", hebrew: hebrew)
        try row(hebrew ? "כנגד ארבעה בנים" : "The Four Sons").tap()
        try requireReader(backend: "sefariaEmbedded", work: "Pesach Haggadah",
                          reference: "Pesach Haggadah, Magid, The Four Sons")
        capture("sefaria-mobile-\(language)-Haggadah-original-named-section")
    }

    @MainActor
    private func faultFiles() throws -> SefariaTOCFaultFiles {
        var root = try workspaceSidecarURL()
        for _ in 0..<6 { root.deleteLastPathComponent() }
        let metadataURL = root.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")
        let metadata = try SefariaTOCFaultFiles.read(metadataURL, limit: 65_536)
        let plist = try XCTUnwrap(try PropertyListSerialization.propertyList(from: metadata, format: nil) as? [String: Any])
        XCTAssertEqual(plist["MCMMetadataIdentifier"] as? String, "com.davidpovarsky.chavrusatext")
        guard plist["MCMMetadataIdentifier"] as? String == "com.davidpovarsky.chavrusatext",
              UUID(uuidString: workspaceNamespace) != nil else {
            throw NSError(domain: "SefariaTOCAcceptanceOwner", code: 5)
        }
        let files = SefariaTOCFaultFiles(namespace: workspaceNamespace, nonce: UUID(),
            root: root, metadataURL: metadataURL, metadata: metadata)
        try files.verifyOwner()
        XCTAssertFalse(FileManager.default.fileExists(atPath: files.commandURL.path))
        return files
    }

    @MainActor
    private func waitForProof(_ stage: String, files: SefariaTOCFaultFiles) throws -> [String: Any] {
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (try? files.proof(stage)) != nil
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 15), .completed,
                       "Actual original owner/TaskLocal/URL Loading proof must exist: \(stage)")
        let proof = try files.proof(stage)
        let attachment = XCTAttachment(data: try SefariaTOCFaultFiles.read(files.url(stage), limit: 8_192),
                                      uniformTypeIdentifier: "public.json")
        attachment.name = "sefaria-toc-\(stage)-" + files.nonce.uuidString
        attachment.lifetime = .keepAlways
        add(attachment)
        return proof
    }

    @MainActor
    fileprivate func exerciseRemoteFailureRetry(language: String) throws {
        let hebrew = language == "he"
        launchWithTier(.realUI, scenario: "reader", backend: "sefaria",
            extraArgs: ["-preferredBackend", "sefaria", "-smokeBackend", "sefaria",
                        "-ChavrusaTextFaithfulReaderUIEnabled", "YES",
                        "-studyWorkspaceTestingNamespace", workspaceNamespace,
                        "-SefariaTOCTransportAcceptance", "YES"],
            language: language, locale: hebrew ? "he_IL" : "en_US")
        XCTAssertFalse(app.launchArguments.contains("-smokeBypassBootstrap"))
        dismissAlertsIfNeeded()
        try requireReader(backend: "sefaria", work: "Genesis")
        let originalLocator = app.staticTexts["reader-current-locator"].label
        let originalTitle = app.staticTexts["reader-header-title"].label
        try showOriginalTOC()
        _ = try row(hebrew ? "פרק א׳" : "1")
        let files = try faultFiles()
        try files.verifyOwner()
        let command: [String: Any] = [
            "schemaVersion": 1, "namespace": files.namespace, "nonce": files.nonce.uuidString,
            "backend": "sefaria", "workKey": "Genesis", "operation": "reloadOwnedTOC"
        ]
        try JSONSerialization.data(withJSONObject: command, options: [.sortedKeys])
            .write(to: files.commandURL, options: [.atomic])
        let armed = try waitForProof("armed", files: files)
        let tagged = try waitForProof("tagged", files: files)
        let held = try waitForProof("held", files: files)
        XCTAssertEqual(armed["ownerID"] as? String, tagged["ownerID"] as? String)
        XCTAssertEqual(tagged["ownerID"] as? String, held["ownerID"] as? String)
        let loading = try requireVisible("toc-loading", timeout: 10)
        XCTAssertTrue(loading.staticTexts[hebrew ? "טוען את תוכן העניינים…" : "Loading Table of Contents..."].exists)
        XCTAssertFalse(app.descendants(matching: .any)["toc-empty"].exists,
                       "An actual held request must not be presented as a loaded empty TOC")
        XCTAssertFalse(app.descendants(matching: .any)["toc-failure"].exists)
        XCTAssertEqual(app.staticTexts["reader-current-locator"].label, originalLocator)
        capture("sefaria-remote-\(language)-actual-loading")
        try files.verifyOwner()
        let release: [String: Any] = [
            "schemaVersion": 1, "namespace": files.namespace, "nonce": files.nonce.uuidString,
            "operation": "releaseFault"
        ]
        try JSONSerialization.data(withJSONObject: release, options: [.sortedKeys])
            .write(to: files.url("release"), options: [.atomic])
        let failed = try waitForProof("failed", files: files)
        XCTAssertEqual(failed["ownerID"] as? String, held["ownerID"] as? String)
        let failure = try requireVisible("toc-failure", timeout: 15)
        XCTAssertTrue(failure.staticTexts[hebrew ? "תוכן העניינים אינו זמין" : "Table of Contents Unavailable"].exists)
        XCTAssertTrue(failure.staticTexts[hebrew ? "תוכן העניינים אינו זמין ללא חיבור לרשת."
            : "The table of contents is unavailable offline."].exists)
        XCTAssertFalse(app.descendants(matching: .any)["toc-empty"].exists)
        capture("sefaria-remote-\(language)-actual-transport-failure")
        let retry = try requireVisible("toc-retry", timeout: 10)
        XCTAssertEqual(retry.label, hebrew ? "נסה שוב" : "Retry")
        retry.tap() // Original user action, outside the one-shot TaskLocal scope.
        _ = try requireVisible("toc-content-list", timeout: 45)
        XCTAssertFalse(app.descendants(matching: .any)["toc-failure"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["toc-empty"].exists)
        XCTAssertEqual(app.staticTexts["reader-current-locator"].label, originalLocator)
        XCTAssertEqual(app.staticTexts["reader-header-title"].label, originalTitle)
        XCTAssertFalse(FileManager.default.fileExists(atPath: files.url("expired").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: files.url("cancelled").path))
        try selectStructure(hebrew ? "פרקים" : "Chapters")
        try row(hebrew ? "פרק ב׳" : "2").tap()
        try requireReader(backend: "sefaria", work: "Genesis", reference: "Genesis 2")
        try files.verifyOwner()
        capture("sefaria-remote-\(language)-original-retry-real-content")
    }
}

final class SefariaTOCLocalizationPadAcceptanceTests: SefariaTOCNativeBase {
    @MainActor func testEmbeddedHebrewTalmudTOCAndCanonicalNavigation() throws {
        XCTAssertTrue(isPad); try exerciseEmbeddedTalmud(language: "he")
    }
    @MainActor func testEmbeddedEnglishTalmudTOCAndCanonicalNavigation() throws {
        XCTAssertTrue(isPad); try exerciseEmbeddedTalmud(language: "en")
    }
    @MainActor func testEmbeddedHebrewChapterAndComplexTOC() throws {
        XCTAssertTrue(isPad); try exerciseEmbeddedComplex(language: "he")
    }
    @MainActor func testEmbeddedEnglishChapterAndComplexTOC() throws {
        XCTAssertTrue(isPad); try exerciseEmbeddedComplex(language: "en")
    }
    @MainActor func testRemoteHebrewLoadingFailureAndOriginalRetry() throws {
        XCTAssertTrue(isPad); try exerciseRemoteFailureRetry(language: "he")
    }
    @MainActor func testRemoteEnglishLoadingFailureAndOriginalRetry() throws {
        XCTAssertTrue(isPad); try exerciseRemoteFailureRetry(language: "en")
    }
}

final class SefariaTOCLocalizationPhoneAcceptanceTests: SefariaTOCNativeBase {
    @MainActor func testEmbeddedHebrewTalmudTOCAndCanonicalNavigationOnPhone() throws {
        XCTAssertFalse(isPad); try exerciseEmbeddedTalmud(language: "he")
    }
    @MainActor func testEmbeddedEnglishTalmudTOCAndCanonicalNavigationOnPhone() throws {
        XCTAssertFalse(isPad); try exerciseEmbeddedTalmud(language: "en")
    }
    @MainActor func testEmbeddedHebrewChapterAndComplexTOCOnPhone() throws {
        XCTAssertFalse(isPad); try exerciseEmbeddedComplex(language: "he")
    }
    @MainActor func testEmbeddedEnglishChapterAndComplexTOCOnPhone() throws {
        XCTAssertFalse(isPad); try exerciseEmbeddedComplex(language: "en")
    }
    @MainActor func testRemoteHebrewLoadingFailureAndOriginalRetryOnPhone() throws {
        XCTAssertFalse(isPad); try exerciseRemoteFailureRetry(language: "he")
    }
    @MainActor func testRemoteEnglishLoadingFailureAndOriginalRetryOnPhone() throws {
        XCTAssertFalse(isPad); try exerciseRemoteFailureRetry(language: "en")
    }
}

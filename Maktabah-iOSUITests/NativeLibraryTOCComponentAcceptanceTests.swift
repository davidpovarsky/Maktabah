import XCTest
import CryptoKit

/// Additional UI-03 selectors. Run each on its declared actual form factor;
/// the historical Native116 and Release114 selector sets are unchanged.
extension NativeRoutingAcceptanceTests {
    @MainActor
    func testSystemAppIntentLibraryContentsFromHistoryPreservesReader() async throws {
        try await runOriginalComponentSystemIntent(expectedPad: true, destination: "native.library",
            title: "Library contents", anchor: "native.library.contents", identifier: "library-contents-list")
    }

    @MainActor
    func testSystemAppIntentLibraryGroupingFromHistoryDoesNotOpenMenu() async throws {
        try await runOriginalComponentSystemIntent(expectedPad: true, destination: "native.library",
            title: "Group By", anchor: "native.library.grouping", identifier: "library-grouping")
        XCTAssertFalse(app.menus.firstMatch.exists, "Revealing the existing control must not execute its action")
    }

    @MainActor
    func testSystemAppIntentTOCContentsFromHistoryPreservesReader() async throws {
        try await runOriginalComponentSystemIntent(expectedPad: true, destination: "native.reader.toc",
            title: "Table of contents list", anchor: "native.reader.toc.contents", identifier: "toc-content-list")
    }
}

extension NativeRoutingPhoneAcceptanceTests {
    @MainActor
    func testPhoneSystemAppIntentLibraryContentsFromHistoryPreservesReader() async throws {
        try await runOriginalComponentSystemIntent(expectedPad: false, destination: "native.library",
            title: "Library contents", anchor: "native.library.contents", identifier: "library-contents-list")
    }

    @MainActor
    func testPhoneSystemAppIntentLibraryOptionsFromBackgroundDoesNotOpenMenu() async throws {
        try await runOriginalComponentSystemIntent(expectedPad: false, destination: "native.library",
            title: "Library Options", anchor: "native.library.options", identifier: "library-options",
            fromBackground: true)
        XCTAssertFalse(app.menus.firstMatch.exists, "Revealing the existing control must not execute its action")
    }
}


// These selectors resolve the fixed component through the actual system entity
// query. Expected private identity comes from sealed SQL and the ORIGINAL
// persisted locator registry, never from an acceptance response or new AX marker.
extension NativeRoutingAcceptanceTests {
    @MainActor
    func testSystemAppIntentCurrentTOCEntryFromHistoryPreservesReader() async throws {
        try await runExactOriginalTOCSelection(expectedPad: true)
    }

    @MainActor
    fileprivate func runExactOriginalTOCSelection(expectedPad: Bool,
                                                  fromBackground: Bool = false) async throws {
        let oracle = try currentTOCOracle()
        try await runOriginalComponentSystemIntent(expectedPad: expectedPad, destination: "native.reader.toc",
            title: "Current Table of Contents Entry", anchor: "native.reader.toc.currentSelection",
            identifier: "", fromBackground: fromBackground, expectedValue: "selected",
            originalTarget: { app in
                do { return try self.originalTOCTarget(oracle, in: app) }
                catch {
                    XCTFail("Cannot resolve the exact original SQL-bound TOC row: \(error)")
                    return app.buttons["invalid-unresolved-original-toc-source-\(UUID().uuidString)"]
                }
            })
        let target = try originalTOCTarget(oracle, in: app)
        XCTAssertEqual(target.label, oracle.path.last?.title)
        XCTAssertEqual(target.value as? String, "selected")
        XCTAssertTrue(target.isHittable && !target.frame.isEmpty)
        XCTAssertEqual(app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND value == %@", "toc-row-", "selected")).count, 1,
            "The exact SQL row must be the only original selected Button")
        if !expectedPad {
            let close = app.buttons["toc-close"]
            XCTAssertTrue(close.exists && close.isHittable,
                "Close the original phone TOC through its original toolbar")
            close.tap()
        }
        try requireUnchangedOriginalTOCReader(oracle)
    }
}

extension NativeRoutingPhoneAcceptanceTests {
    @MainActor
    func testPhoneSystemAppIntentTOCContentsFromHistoryPreservesReader() async throws {
        try await runOriginalComponentSystemIntent(expectedPad: false, destination: "native.reader.toc",
            title: "Table of contents list", anchor: "native.reader.toc.contents", identifier: "toc-content-list")
        let close = app.buttons["toc-close"]
        XCTAssertTrue(close.exists && close.isHittable)
        close.tap()
        try requireUnchangedOriginalTOCReader(currentTOCOracle())
    }

    @MainActor
    func testPhoneSystemAppIntentCurrentTOCEntryFromBackgroundPreservesReader() async throws {
        try await runExactOriginalTOCSelection(expectedPad: false, fromBackground: true)
    }
}

fileprivate struct OriginalTOCSourceOracle: Decodable {
    struct Locator: Decodable, Equatable {
        struct Position: Decodable, Equatable {
            let kind: String
            let integer: Int?
            let string: String?
        }
        let backend: String
        let workKey: String
        let position: Position
        var key: String {
            let location = position.integer.map { "line:\($0)" } ?? "ref:\(position.string ?? "")"
            return "\(backend)|\(workKey)|\(location)"
        }
    }
    struct Bootstrap: Decodable { let id: Int; let bookId: Int; let lineIndex: Int }
    struct Node: Decodable {
        let entryID: Int
        let parentEntryID: Int?
        let lineIndex: Int
        let title: String
        let locator: Locator
    }
    let profileID: String
    let profileVersion: Int
    let databaseSHA256: String
    let bootstrap: Bootstrap
    let defaultStructureID: String
    let path: [Node]
}

fileprivate struct OriginalTOCReaderOracle: Decodable {
    struct Row: Decodable {
        let id: Int
        let bookId: Int
        let lineIndex: Int
        let plainText: String
        let plainSHA256: String
    }
    let databaseSHA256: String
    let bootstrapRowID: Int
    let rows: [Row]
}

extension NativeRoutingAcceptanceTests {
    fileprivate func currentTOCOracle() throws -> OriginalTOCSourceOracle {
        let url = try XCTUnwrap(Bundle(for: NativeRoutingAcceptanceTests.self)
            .url(forResource: "canonical-miniTest10-toc-current-selection", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(digest, "9bc6fda67bbc4dc438753d9926c2c928562482f17ba234e17f7e09d0aab54905")
        let oracle = try JSONDecoder().decode(OriginalTOCSourceOracle.self, from: data)
        XCTAssertEqual(oracle.profileID, "miniTest10")
        XCTAssertEqual(oracle.profileVersion, 6)
        XCTAssertEqual(oracle.databaseSHA256, "d3d9bfcc2320a987a0391ad23fa72abcf6fd1fa0f3cba95adc05096e05a9edef")
        XCTAssertEqual(oracle.bootstrap.id, 3121121)
        XCTAssertEqual(oracle.bootstrap.bookId, 3891)
        XCTAssertEqual(oracle.bootstrap.lineIndex, 523)
        XCTAssertEqual(oracle.defaultStructureID, "default")
        XCTAssertEqual(oracle.path.map(\.entryID), [642933, 643037])
        XCTAssertEqual(oracle.path.map(\.lineIndex), [0, 522])
        XCTAssertNil(oracle.path.first?.parentEntryID)
        for (offset, node) in oracle.path.dropFirst().enumerated() {
            XCTAssertEqual(node.parentEntryID, oracle.path[offset].entryID)
        }
        for node in oracle.path {
            XCTAssertEqual(node.locator.backend, "otzaria")
            XCTAssertEqual(node.locator.workKey, "book:3891")
            XCTAssertEqual(node.locator.position.kind, "legacyLine")
            XCTAssertEqual(node.locator.position.integer, node.lineIndex)
        }
        let evidence = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        evidence.name = "independent-sql-current-toc-path"; evidence.lifetime = .keepAlways; add(evidence)
        return oracle
    }

    @MainActor
    fileprivate func originalTOCTarget(_ oracle: OriginalTOCSourceOracle,
                                       in app: XCUIApplication) throws -> XCUIElement {
        let parent = try workspaceContainerParent().standardizedFileURL
        let sidecar = try workspaceSidecarURL().standardizedFileURL
        XCTAssertTrue(sidecar.pathComponents.starts(with: parent.pathComponents))
        let containerID = try XCTUnwrap(sidecar.pathComponents.dropFirst(parent.pathComponents.count).first)
        let preferences = parent.appendingPathComponent(containerID)
            .appendingPathComponent("Library/Preferences/com.davidpovarsky.chavrusatext.plist")
        func readOriginalMapping() throws -> [(OriginalTOCSourceOracle.Node, Int)] {
            let data = try Data(contentsOf: preferences)
            guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                  let forward = plist["qualifiedLocatorSurrogates.v1"] as? [String: Int],
                  let reverseData = plist["qualifiedLocatorReverse.v1"] as? Data else {
                throw NSError(domain: "OriginalTOCSource", code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Original registry has not persisted both maps"])
            }
            let reverse = try JSONDecoder().decode([String: OriginalTOCSourceOracle.Locator].self, from: reverseData)
            return try oracle.path.map { node in
                guard let id = forward[node.locator.key], id < 0, reverse[String(id)] == node.locator else {
                    throw NSError(domain: "OriginalTOCSource", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Original forward/reverse locator identities disagree"])
                }
                return (node, id)
            }
        }
        // The ORIGINAL registry batches persistence. Wait on its actual file,
        // without changing the app's registry, timing or acceptance behavior.
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (try? readOriginalMapping()) != nil
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 10), .completed)
        let mapping = try readOriginalMapping()
        XCTAssertEqual(Set(mapping.map(\.1)).count, oracle.path.count,
            "The independent ancestor path must resolve to distinct actual registry identities")
        let selected = try XCTUnwrap(mapping.last)
        let evidence = mapping.map { node, id in
            "sqlEntry=\(node.entryID) locator=\(node.locator.key) originalRow=toc-row-\(id)"
        }.joined(separator: "\n")
        let attachment = XCTAttachment(string: evidence)
        attachment.name = "actual-original-registry-to-sql-toc-path"; attachment.lifetime = .keepAlways; add(attachment)
        return app.buttons.matching(identifier: "toc-row-\(selected.1)").firstMatch
    }

    @MainActor
    fileprivate func requireUnchangedOriginalTOCReader(_ toc: OriginalTOCSourceOracle) throws {
        let url = try XCTUnwrap(Bundle(for: NativeRoutingAcceptanceTests.self)
            .url(forResource: "canonical-miniTest10-reader-lines", withExtension: "json"))
        let data = try Data(contentsOf: url)
        XCTAssertEqual(SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(),
            "51632762100689aa2da6a6d360a6434d4fa4caf5e57971f4ad8e327ab6e173dc")
        let source = try JSONDecoder().decode(OriginalTOCReaderOracle.self, from: data)
        XCTAssertEqual(source.databaseSHA256, toc.databaseSHA256)
        XCTAssertEqual(source.bootstrapRowID, toc.bootstrap.id)
        let row = try XCTUnwrap(source.rows.first { $0.id == toc.bootstrap.id })
        XCTAssertEqual(row.bookId, toc.bootstrap.bookId)
        XCTAssertEqual(row.lineIndex, toc.bootstrap.lineIndex)
        XCTAssertEqual(SHA256.hash(data: Data(row.plainText.utf8)).map { String(format: "%02x", $0) }.joined(),
            row.plainSHA256)
        let expected = "otzaria|book:\(row.bookId)|line:\(row.lineIndex)"
        let text = app.textViews["reader-text"]
        XCTAssertTrue(text.waitForExistence(timeout: 15))
        let directionControls: Set<UInt32> = [0x200E, 0x200F, 0x202A, 0x202B, 0x202C, 0x202D, 0x202E,
                                             0x2066, 0x2067, 0x2068, 0x2069]
        let unchanged = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let value = text.value as? String else { return false }
            let plain = value.unicodeScalars.filter { !directionControls.contains($0.value) }.map(String.init)
                .joined().trimmingCharacters(in: .whitespacesAndNewlines)
            return plain == row.plainText
                && self.app.staticTexts["reader-current-locator"].label == expected
                && self.getRenderedHighlightSnapshot()?.locator == expected
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [unchanged], timeout: 15), .completed,
            "Revealing the exact existing TOC row must preserve the original private Reader line and TextKit text")
        XCTAssertGreaterThan(text.frame.width, 80); XCTAssertGreaterThan(text.frame.height, 80)
        XCTAssertGreaterThan(try XCTUnwrap(getRenderedHighlightSnapshot()).segmentSelectionCount, 0)
    }
}

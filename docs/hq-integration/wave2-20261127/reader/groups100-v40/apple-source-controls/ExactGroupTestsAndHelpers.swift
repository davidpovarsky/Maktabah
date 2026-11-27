import XCTest
import UIKit
import CryptoKit
import SQLite3
private struct FullV32ObservationFailure: Error {}
@MainActor
private enum NativeGeometryEvidence {
    static func frame(_ frame: CGRect) -> [String: Any] {
        let values: [String: Double] = [
            "x": Double(frame.origin.x), "y": Double(frame.origin.y),
            "width": Double(frame.size.width), "height": Double(frame.size.height),
            "minX": Double(frame.minX), "minY": Double(frame.minY),
            "maxX": Double(frame.maxX), "maxY": Double(frame.maxY)
        ]
        return [
            "decimal": values.mapValues { String($0) },
            "ieee754Hex": values.mapValues { String($0.bitPattern, radix: 16) },
            "finitePositive": GroupStressSnapshot.finitePositive(frame),
            "isNull": frame.isNull, "isInfinite": frame.isInfinite, "isEmpty": frame.isEmpty
        ]
    }

    static func element(_ element: any XCUIElementSnapshot) -> [String: Any] {
        ["identifier": element.identifier, "label": element.label,
         "type": String(describing: element.elementType), "enabled": element.isEnabled,
         "frame": frame(element.frame)]
    }

    static func text(_ value: Any) -> String {
        if let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
           let text = String(data: data, encoding: .utf8) { return text }
        return String(reflecting: value)
    }
}


// MARK: - One hundred original group transitions (additional Native acceptance)

extension FaithfulReaderUIBase {
    @MainActor
    fileprivate func prepareSingleBookForGroupStress() throws {
        try establishSingleBookOverviewFixture(phone: false)
    }
}

/// Read-only projection of the original persisted document/navigation identity.
/// Geometry checkpoints and revision are observed separately, never rewritten.
private struct GroupStressWorkspace: Decodable, Sendable {
    struct Profile: Decodable, Equatable, Sendable {
        let id: UUID
        let name: String
        let symbol: String
        let order: Int
        let color: String?
    }
    struct Locator: Decodable, Equatable, Sendable {
        struct Position: Decodable, Equatable, Sendable {
            let kind: String
            let integer: Int?
            let string: String?
        }
        let backend: String
        let workKey: String
        let position: Position
    }
    struct Document: Decodable, Equatable, Sendable {
        struct Session: Decodable, Equatable, Sendable {
            let id: UUID
            let bookId: Int
            let bookTitle: String?
            let backendLocator: Locator?
            let locator: Locator?
            let contentId: Int?
            let page: Int?
            let part: Int?
            let searchText: String?
            let searchModeRaw: Int?
            let nearDistance: Int?
            let highlightTerms: [String]?
        }
        let backend: String
        let session: Session
    }
    struct Group: Decodable, Equatable, Sendable {
        let id: UUID
        let profileID: UUID
        let name: String
        let order: Int
        let tabs: [Document]
        let activeTabID: UUID?
    }
    struct Scene: Decodable, Sendable {
        let profileID: UUID
        let groupID: UUID
        let activeTabIDsByGroup: [UUID: UUID]?
    }
    let version: Int
    let revision: UInt64
    let profiles: [Profile]
    let groups: [Group]
    let scenes: [String: Scene]
    let lastActiveSceneID: String?

    var current: (sceneID: String, scene: Scene, group: Group, document: Document)? {
        guard let sceneID = lastActiveSceneID, let scene = scenes[sceneID],
              let group = groups.first(where: { $0.id == scene.groupID && $0.profileID == scene.profileID }),
              let activeID = scene.activeTabIDsByGroup?[group.id] ?? group.activeTabID,
              let document = group.tabs.first(where: { $0.session.id == activeID }) else { return nil }
        return (sceneID, scene, group, document)
    }
}

@MainActor
private enum GroupStressSnapshot {
    // All attributes below come from one actual XCTest snapshot. No snapshot
    // survives a tap, workspace transition, or predicate evaluation.
    static func descendants(of root: any XCUIElementSnapshot) -> [any XCUIElementSnapshot] {
        var result: [any XCUIElementSnapshot] = []
        for child in root.children {
            result.append(child)
            result.append(contentsOf: descendants(of: child))
        }
        return result
    }

    static func matches(_ element: any XCUIElementSnapshot, identifying name: String) -> Bool {
        // Preserve XCUIElementQuery's string-subscript identifying properties.
        element.identifier == name || element.title == name || element.label == name
            || element.value as? String == name || element.placeholderValue == name
    }

    static func documentCards(under overview: any XCUIElementSnapshot) -> [any XCUIElementSnapshot] {
        @MainActor
        func visit(_ node: any XCUIElementSnapshot, insideCollection: Bool) -> [any XCUIElementSnapshot] {
            var result: [any XCUIElementSnapshot] = []
            for child in node.children {
                if insideCollection, child.elementType == .cell,
                   child.identifier.hasPrefix("tab-switcher-grid-cell-") {
                    result.append(child)
                }
                result.append(contentsOf: visit(child, insideCollection:
                    insideCollection || child.elementType == .collectionView))
            }
            return result
        }
        // The original scope is overview.collectionViews.cells, not all cards
        // anywhere in the app. Visit each descendant once even for nested lists.
        return visit(overview, insideCollection: false)
    }

    static func finitePositive(_ frame: CGRect) -> Bool {
        !frame.isNull && !frame.isInfinite && !frame.isEmpty
            && frame.minX.isFinite && frame.minY.isFinite
            && frame.width.isFinite && frame.height.isFinite
    }
}

@MainActor
private final class GroupStressNativeObservation {
    let application: XCUIApplication
    let url: URL
    let name: String
    let sceneID: String?
    let afterRevision: UInt64?

    init(application: XCUIApplication, url: URL, name: String, sceneID: String?, afterRevision: UInt64?) {
        self.application = application
        self.url = url
        self.name = name
        self.sceneID = sceneID
        self.afterRevision = afterRevision
    }

    func read() -> GroupStressWorkspace? {
        guard let bytes = try? Data(contentsOf: url),
              let workspace = try? JSONDecoder().decode(GroupStressWorkspace.self, from: bytes),
              let current = workspace.current, workspace.version == 1,
              current.group.name == name, current.group.tabs.count == 1,
              sceneID.map({ current.sceneID == $0 }) ?? true,
              afterRevision.map({ workspace.revision > $0 }) ?? true else { return nil }
        guard let snapshot = try? application.snapshot() else { return nil }
        let elements = GroupStressSnapshot.descendants(of: snapshot)
        let overviews = elements.filter { GroupStressSnapshot.matches($0, identifying: "study-groups-overview") }
        guard overviews.count == 1, let overviewSnapshot = overviews.first,
              !elements.contains(where: {
                  $0.elementType == .alert
                      && GroupStressSnapshot.matches($0, identifying: "לא ניתן לשנות את סביבת הלימוד")
              }) else { return nil }
        let segments = elements.filter {
            $0.elementType == .segmentedControl && GroupStressSnapshot.matches($0, identifying: "study-group-selector")
        }
        let controls = segments.isEmpty ? elements.filter {
            $0.elementType == .button && GroupStressSnapshot.matches($0, identifying: "study-group-selector")
        } : segments
        guard controls.count == 1, let controlSnapshot = controls.first,
              controlSnapshot.isEnabled, controlSnapshot.value as? String == name else { return nil }
        let cards = GroupStressSnapshot.documentCards(under: overviewSnapshot)
        let expectedCardID = "tab-switcher-grid-cell-" + current.document.session.id.uuidString
        guard cards.count == 1, let cardSnapshot = cards.first,
              cardSnapshot.identifier == expectedCardID, cardSnapshot.isSelected else { return nil }

        // Hittability is a live XCUIElement property, not a frame approximation
        // or snapshot attribute. Keep both original real hit-test requirements.
        let overview = application.descendants(matching: .any)["study-groups-overview"]
        let control = controlSnapshot.elementType == .segmentedControl
            ? application.segmentedControls["study-group-selector"]
            : application.buttons["study-group-selector"]
        let card = overview.collectionViews.cells.matching(NSPredicate(
            format: "identifier == %@", expectedCardID)).element
        guard control.isHittable, card.isHittable else { return nil }
        return workspace
    }
}

@MainActor
private final class GroupStressEvidence {
    var transitions: [[String: Any]] = []
    var completedTransitions = 0
    var coldRestoreVerified = false
    let emit: @MainActor (Data) -> Void

    init(emit: @escaping @MainActor (Data) -> Void) { self.emit = emit }

    func record(_ value: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
           let text = String(data: data, encoding: .utf8) {
            print("GROUP_STRESS_OBSERVATION " + text)
        }
    }

    func attachReport() {
        let value: [String: Any] = [
            "schema": 1, "requiredConsecutiveTransitions": 100,
            "completedTransitions": completedTransitions,
            "coldRestoreVerified": coldRestoreVerified,
            "timingScope": "XCTest tap, original commit and accessibility observation; not product p95",
            "transitions": transitions
        ]
        if let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) { emit(data) }
    }
}

// MARK: Actual app process observations for the original groups100 case

private struct GroupStressApplicationMetric: Codable, Sendable {
    let schema: Int
    let timingScope: String
    let memoryMetric: String
    let memoryScope: String
    let namespace: String
    let operationID: UUID
    let launchID: UUID
    let sequence: Int
    let processID: Int32
    let sceneID: String
    let fromGroupID: UUID?
    let toGroupID: UUID
    let observedGroupID: UUID?
    let fromDocumentID: UUID?
    let observedDocumentID: UUID?
    let beforeRevision: UInt64?
    let afterRevision: UInt64?
    let fromBackend: String
    let observedBackend: String
    let footprintBeforeBytes: UInt64?
    let footprintAfterBytes: UInt64?
    let elapsedSeconds: Double
    let returnedNormally: Bool
}

private struct GroupStressMetricExpectation: Sendable {
    let sceneID: String
    let fromGroupID: UUID
    let toGroupID: UUID
    let fromDocumentID: UUID
    let toDocumentID: UUID
    let observedBeforeRevision: UInt64
    let observedAfterRevision: UInt64
}

/// Reads the real app container's original reader log. Matching is independently
/// bound to the UI/sidecar observations, not to a flag claiming a successful test.
private struct GroupStressMetricReader: Sendable {
    enum Failure: Error { case missingOrInvalidEvidence }
    let url: URL
    let namespace: String
    let expected: [GroupStressMetricExpectation]

    func samples() throws -> [GroupStressApplicationMetric] {
        let resource = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard resource.isRegularFile == true, resource.isSymbolicLink == false else {
            throw Failure.missingOrInvalidEvidence
        }
        let text = try String(contentsOf: url, encoding: .utf8)
        let prefix = "[NativeGroupSwitchPerformance] "
        return try text.split(separator: "\n").compactMap { line in
            guard let range = line.range(of: prefix) else { return nil }
            let bytes = Data(line[range.upperBound...].utf8)
            let sample = try JSONDecoder().decode(GroupStressApplicationMetric.self, from: bytes)
            return sample.namespace == namespace ? sample : nil
        }
    }

    func matched() throws -> [GroupStressApplicationMetric] {
        let records = try samples()
        guard expected.count == 100 else { throw Failure.missingOrInvalidEvidence }
        var selected: [GroupStressApplicationMetric] = []
        for observation in expected {
            let matches = records.filter { sample in
                guard sample.sceneID == observation.sceneID,
                      sample.fromGroupID == observation.fromGroupID,
                      sample.toGroupID == observation.toGroupID,
                      sample.observedGroupID == observation.toGroupID,
                      sample.fromDocumentID == observation.fromDocumentID,
                      sample.observedDocumentID == observation.toDocumentID,
                      let before = sample.beforeRevision, let after = sample.afterRevision else { return false }
                // Ordinary checkpoints may advance revision between the UI
                // observations and tap. The actual commit must lie inside them.
                return before >= observation.observedBeforeRevision && after > before
                    && after <= observation.observedAfterRevision
            }
            guard matches.count == 1, let sample = matches.first,
                  sample.schema == 1, sample.returnedNormally,
                  sample.fromBackend == "otzaria", sample.observedBackend == "otzaria",
                  sample.processID > 0, sample.elapsedSeconds.isFinite, sample.elapsedSeconds >= 0,
                  sample.timingScope == "original group operation through ordinary session persistence",
                  sample.memoryMetric == "phys_footprint_bytes",
                  sample.memoryScope == "operation boundary samples; not continuous peak RSS",
                  (sample.footprintBeforeBytes ?? 0) > 0, (sample.footprintAfterBytes ?? 0) > 0 else {
                throw Failure.missingOrInvalidEvidence
            }
            selected.append(sample)
        }
        guard Set(selected.map(\.operationID)).count == 100,
              Set(selected.map(\.launchID)).count == 1,
              Set(selected.map(\.processID)).count == 1,
              let first = selected.first,
              selected.enumerated().allSatisfy({ $0.element.sequence == first.sequence + $0.offset }) else {
            throw Failure.missingOrInvalidEvidence
        }
        return selected
    }
}

// END Actual app process observations

/// Additional iPad/miniTest10 coverage. This does not replace any original case,
/// full-production-data acceptance, physical-device testing, or a latency gate.
final class StudyGroupStressNativeAcceptanceTests: R27NativeUIBase {
    override var readerTestTier: TestTier { .realUI }
    override var readerAdditionalLaunchArguments: [String] {
        super.readerAdditionalLaunchArguments + ["-StudyGroupPerformanceEnabled", "YES"]
    }

    @MainActor
    func testOneHundredConsecutiveOriginalGroupSwitchesPreserveDocumentsAndColdRestore() throws {
        XCTAssertTrue(isPad, "This additional case requires the original iPad group UI")
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader(backend: "otzaria", tier: .realUI)
        let initialLocator = try assertTarget(backend: "otzaria")
        let url = try verifiedGroupStressSidecar()
        // A fresh UUID sidecar can import real legacy tabs. Use the existing
        // original UI preparation only after the miniTest10/ownership gates.
        try prepareSingleBookForGroupStress()
        openGroupStressOverview()
        let initial = try readGroupStressWorkspace(url)
        XCTAssertEqual(initial.version, 1)
        XCTAssertEqual(initial.profiles.count, 1)
        XCTAssertEqual(initial.groups.count, 1)
        let original = try XCTUnwrap(initial.current)
        XCTAssertEqual(original.group.tabs.count, 1)
        XCTAssertEqual(original.document.backend, "otzaria")
        var workspace = try waitForOriginalGroup(named: original.group.name, at: url,
                                                 sceneID: original.sceneID, afterRevision: nil)
        let profileID = original.scene.profileID
        var names = [original.group.name]
        for name in ["רצף א", "רצף ב"] {
            XCTAssertFalse(workspace.groups.contains { $0.name == name })
            let beforeRevision = workspace.revision
            tap(app.buttons["study-group-actions-menu"])
            tap(app.buttons["קבוצה מהכרטיסיות הנוכחיות"])
            let prompt = app.alerts["שם קבוצת הכרטיסיות"]
            XCTAssertTrue(prompt.exists || prompt.waitForExistence(timeout: 10))
            prompt.textFields.firstMatch.typeText(name)
            tap(prompt.buttons["שמירה"])
            workspace = try waitForOriginalGroup(named: name, at: url,
                                                  sceneID: original.sceneID, afterRevision: beforeRevision)
            names.append(name)
        }
        XCTAssertEqual(workspace.groups.count, 3)
        XCTAssertEqual(Set(workspace.groups.map(\.id)).count, 3)
        XCTAssertTrue(workspace.groups.allSatisfy { $0.profileID == profileID && $0.tabs.count == 1 })
        XCTAssertEqual(Set(workspace.groups.flatMap { $0.tabs.map { $0.session.id } }).count, 3,
                       "Original copies must retain three different document owners, not one shared UUID")

        // Hydrate every original reader before pinning its durable navigation
        // state. These preparation transitions are explicitly not counted.
        var locators: [UUID: String] = [:]
        for name in names {
            let previous = try XCTUnwrap(workspace.current)
            XCTAssertNotEqual(previous.group.name, name)
            selectOriginalStressGroup(named: name)
            workspace = try waitForOriginalGroup(named: name, at: url,
                                                  sceneID: original.sceneID, afterRevision: workspace.revision)
            let current = try XCTUnwrap(workspace.current)
            closeGroupStressOverview()
            let locator = try assertTarget(backend: "otzaria")
            XCTAssertEqual(locator, initialLocator, "Copying a group preserves the actual original reading unit")
            locators[current.group.id] = locator
            openGroupStressOverview()
            workspace = try waitForOriginalGroup(named: name, at: url,
                                                  sceneID: original.sceneID, afterRevision: nil)
        }
        let baseline = workspace
        XCTAssertEqual(locators.count, 3)
        try assertOriginalGroupMembership(workspace, matches: baseline)
        try attachWorkspaceSnapshot("groups100-before-consecutive-switches")
        retainNativeEvidence("groups100-before-consecutive-switches")
        let evidence = GroupStressEvidence { [weak self] data in
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            attachment.name = "groups100-original-transition-observations"
            attachment.lifetime = .keepAlways
            self?.add(attachment)
        }
        addTeardownBlock { await evidence.attachReport() }

        var performanceExpectations: [GroupStressMetricExpectation] = []
        for step in 1...100 {
            let target = try XCTUnwrap(baseline.groups.first { $0.name == names[(step - 1) % names.count] })
            let previous = try XCTUnwrap(workspace.current)
            XCTAssertNotEqual(target.id, previous.group.id, "A same-group tap is not a counted transition")
            let targetDocument = try XCTUnwrap(target.tabs.first)
            XCTAssertNotEqual(targetDocument.session.id, previous.document.session.id)
            let start = ProcessInfo.processInfo.systemUptime
            var observation: [String: Any] = [
                "step": step, "state": "attempted", "sceneID": previous.sceneID,
                "profileID": profileID.uuidString,
                "fromGroupID": previous.group.id.uuidString, "toGroupID": target.id.uuidString,
                "fromDocumentID": previous.document.session.id.uuidString,
                "toDocumentID": targetDocument.session.id.uuidString,
                "beforeRevision": workspace.revision
            ]
            evidence.transitions.append(observation)
            evidence.record(observation)
            selectOriginalStressGroup(named: target.name)
            let selectionReturnedAt = ProcessInfo.processInfo.systemUptime
            workspace = try waitForOriginalGroup(named: target.name, at: url,
                                                  sceneID: original.sceneID, afterRevision: workspace.revision)
            let observationReturnedAt = ProcessInfo.processInfo.systemUptime
            observation["automationSelectionElapsedSeconds"] = selectionReturnedAt - start
            observation["automationObservationElapsedSeconds"] = observationReturnedAt - selectionReturnedAt
            let current = try XCTUnwrap(workspace.current)
            XCTAssertEqual(current.group.id, target.id)
            XCTAssertEqual(current.document.session.id, targetDocument.session.id)
            XCTAssertEqual(current.scene.profileID, profileID)
            try assertOriginalGroupMembership(workspace, matches: baseline)
            performanceExpectations.append(.init(
                sceneID: previous.sceneID, fromGroupID: previous.group.id, toGroupID: current.group.id,
                fromDocumentID: previous.document.session.id, toDocumentID: current.document.session.id,
                observedBeforeRevision: try XCTUnwrap(observation["beforeRevision"] as? UInt64),
                observedAfterRevision: workspace.revision))
            observation["state"] = "committed"
            observation["afterRevision"] = workspace.revision
            observation["observedGroupID"] = current.group.id.uuidString
            observation["observedDocumentID"] = current.document.session.id.uuidString
            observation["selectedOriginalCardID"] = "tab-switcher-grid-cell-" + current.document.session.id.uuidString
            observation["selectedOriginalGroupName"] = current.group.name
            observation["automationElapsedSeconds"] = ProcessInfo.processInfo.systemUptime - start
            evidence.transitions[step - 1] = observation
            evidence.completedTransitions += 1
            evidence.record(observation)
        }
        XCTAssertEqual(evidence.completedTransitions, 100)
        XCTAssertEqual(evidence.transitions.count, 100)
        try captureGroupApplicationMetrics(sidecar: url, expected: performanceExpectations)
        let final = try XCTUnwrap(workspace.current)
        try attachWorkspaceSnapshot("groups100-after-100-original-commits")
        retainNativeEvidence("groups100-after-100-original-commits")
        closeGroupStressOverview()
        XCTAssertEqual(try assertTarget(backend: "otzaria"), locators[final.group.id])

        app.terminate()
        launchReader(scenario: "catalog", backend: "otzaria", tier: .realUI)
        XCTAssertEqual(try verifiedGroupStressSidecar().standardizedFileURL, url.standardizedFileURL,
                       "Cold launch must retain this same installed app and owned namespace")
        let finalLocator = try XCTUnwrap(locators[final.group.id])
        let locator = app.staticTexts["reader-current-locator"]
        if locator.label != finalLocator {
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label == %@", finalLocator), object: locator)], timeout: 30), .completed)
        }
        XCTAssertEqual(try assertTarget(backend: "otzaria"), finalLocator)
        openGroupStressOverview()
        // A genuine cold launch may create a different system scene identifier.
        // Its restored group/profile/document must still be the exact final one.
        workspace = try waitForOriginalGroup(named: final.group.name, at: url,
                                              sceneID: nil, afterRevision: nil)
        let restored = try XCTUnwrap(workspace.current)
        XCTAssertEqual(restored.scene.profileID, profileID)
        XCTAssertEqual(restored.group.id, final.group.id)
        XCTAssertEqual(restored.document.session.id, final.document.session.id)
        try assertOriginalGroupMembership(workspace, matches: baseline)
        try attachWorkspaceSnapshot("groups100-after-cold-restore")
        retainNativeEvidence("groups100-after-cold-restore")
        closeGroupStressOverview()
        XCTAssertEqual(try assertTarget(backend: "otzaria"), finalLocator)
        evidence.coldRestoreVerified = true
    }


    @MainActor
    private func captureGroupApplicationMetrics(sidecar: URL, expected: [GroupStressMetricExpectation]) throws {
        var container = sidecar
        for _ in 0..<6 { container.deleteLastPathComponent() }
        let reader = GroupStressMetricReader(
            url: container.appendingPathComponent("Documents/OtzariaLogs/otzaria-reader.log"),
            namespace: workspaceNamespace, expected: expected)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (try? reader.matched()) != nil
        }, object: nil)
        let result = XCTWaiter.wait(for: [ready], timeout: 10)
        // Retain available real observations even if the additional evidence
        // requirement fails. Never substitute XCTest IPC duration or a constant.
        if let raw = try? reader.samples(), let bytes = try? JSONEncoder().encode(raw) {
            let attachment = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.json")
            attachment.name = "groups100-application-raw-boundary-samples"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        XCTAssertEqual(result, .completed, "Require 100 uniquely matched actual app operation/memory observations")
        let samples = try reader.matched()
        let elapsedMS = samples.map { $0.elapsedSeconds * 1000 }.sorted()
        func percentile(_ fraction: Double) -> Double {
            elapsedMS[max(0, Int(ceil(Double(elapsedMS.count) * fraction)) - 1)]
        }
        let footprint = samples.flatMap { [$0.footprintBeforeBytes!, $0.footprintAfterBytes!] }
        let value: [String: Any] = [
            "schema": 1, "namespace": workspaceNamespace, "count": samples.count,
            "timingScope": samples[0].timingScope, "percentileMethod": "nearest rank",
            "p50OperationMilliseconds": percentile(0.50),
            "p95OperationMilliseconds": percentile(0.95),
            "maxOperationMilliseconds": elapsedMS.last!,
            "memoryMetric": samples[0].memoryMetric, "memoryScope": samples[0].memoryScope,
            "boundarySampleCount": footprint.count,
            "firstFootprintBytes": samples[0].footprintBeforeBytes!,
            "lastFootprintBytes": samples.last!.footprintAfterBytes!,
            "maxObservedBoundaryFootprintBytes": footprint.max()!,
            "performanceThresholdDefined": false,
            "scope": "Debug iPad Simulator miniTest10; not first-pixel, physical-device, full-corpus, CPU or continuous-peak acceptance"
        ]
        let report = XCTAttachment(data: try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
                                  uniformTypeIdentifier: "public.json")
        report.name = "groups100-application-operation-memory-summary"
        report.lifetime = .keepAlways
        add(report)
    }

    @MainActor
    private func verifiedGroupStressSidecar() throws -> URL {
        XCTAssertEqual(readerTestTier, .realUI)
        XCTAssertNotNil(UUID(uuidString: workspaceNamespace))
        XCTAssertFalse(app.launchArguments.contains("-smokeBypassBootstrap"))
        for (key, expected) in [("-OtzariaDataProfile", "miniTest10"),
                                ("-studyWorkspaceTestingNamespace", workspaceNamespace),
                                ("-preferredBackend", "otzaria")] {
            let indexes = app.launchArguments.indices.filter { app.launchArguments[$0] == key }
            XCTAssertEqual(indexes.count, 1)
            let index = try XCTUnwrap(indexes.first)
            XCTAssertTrue(app.launchArguments.indices.contains(index + 1))
            XCTAssertEqual(app.launchArguments[index + 1], expected)
        }
        XCTAssertEqual(app.launchEnvironment["OTZARIA_DATA_PROFILE"], "miniTest10")
        XCTAssertEqual(app.launchEnvironment["SIMCTL_CHILD_OTZARIA_DATA_PROFILE"], "miniTest10")
        XCTAssertTrue(try XCTUnwrap(ProcessInfo.processInfo.environment["R27_EXPECTED_OTZARIA_WORK_KEY"]).hasPrefix("book:"),
                      "The original matrix must independently validate the installed miniTest10 fixture")
        let url = try workspaceSidecarURL().standardizedFileURL
        let suffix = ["Library", "Application Support", "ChavrusaText", "StudyWorkspace", "UITests", workspaceNamespace + ".json"]
        XCTAssertEqual(Array(url.pathComponents.suffix(suffix.count)), suffix)
        var container = url
        for _ in suffix { container.deleteLastPathComponent() }
        XCTAssertEqual(container.deletingLastPathComponent(), try workspaceContainerParent().standardizedFileURL)
        XCTAssertNotNil(UUID(uuidString: container.lastPathComponent))
        let metadata = try Data(contentsOf: container.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist"))
        let record = try XCTUnwrap(PropertyListSerialization.propertyList(from: metadata, format: nil) as? [String: Any])
        XCTAssertEqual(record["MCMMetadataIdentifier"] as? String, "com.davidpovarsky.chavrusatext")
        let resource = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        XCTAssertEqual(resource.isRegularFile, true)
        XCTAssertEqual(resource.isSymbolicLink, false)
        return url
    }

    private func readGroupStressWorkspace(_ url: URL) throws -> GroupStressWorkspace {
        try JSONDecoder().decode(GroupStressWorkspace.self, from: Data(contentsOf: url))
    }

    @MainActor
    private func openGroupStressOverview() {
        tap(app.buttons["reader-tabs-overview"])
        let overview = app.descendants(matching: .any)["study-groups-overview"]
        XCTAssertTrue(overview.exists || overview.waitForExistence(timeout: 15))
        let toggle = app.buttons["study-tabs-layout-toggle"]
        XCTAssertTrue(toggle.exists || toggle.waitForExistence(timeout: 10))
        if toggle.label == "תצוגת רשת" { tap(toggle) }
    }

    @MainActor
    private func closeGroupStressOverview() {
        let overview = app.descendants(matching: .any)["study-groups-overview"]
        tap(overview.buttons["סיום"])
        if overview.exists {
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == false"), object: overview)], timeout: 15), .completed)
        }
    }

    @MainActor
    private func retainOriginalGroupSelectionObservation(
        _ gate: String, expectedName: String,
        selectors: [any XCUIElementSnapshot], targets: [any XCUIElementSnapshot],
        window: (any XCUIElementSnapshot)?, snapshotSeconds: Double,
        live: [String: Any] = [:],
        attachmentName: String = "groups100-original-selection-failed-snapshot"
    ) {
        let selector = selectors.first
        let target = targets.first
        var value: [String: Any] = [
            "gate": gate, "expectedLabel": expectedName,
            "selectorCount": selectors.count, "targetCount": targets.count,
            "oneEnabledSelector": selectors.count == 1 && selector?.isEnabled == true,
            "oneExactLabelTarget": targets.count == 1,
            "windowPresent": window != nil,
            "selectors": selectors.map { NativeGeometryEvidence.element($0) },
            "targets": targets.map { NativeGeometryEvidence.element($0) },
            "snapshotSeconds": snapshotSeconds, "liveQueries": live
        ]
        if let window { value["window"] = NativeGeometryEvidence.element(window) }
        if let selector, let target, let window {
            value["allFramesFinitePositive"] = [selector.frame, target.frame, window.frame]
                .allSatisfy { GroupStressSnapshot.finitePositive($0) }
            value["selectorContainsTarget"] = selector.frame.contains(target.frame)
            value["windowContainsTarget"] = window.frame.contains(target.frame)
            let tapPoint = CGPoint(x: target.frame.midX, y: target.frame.midY)
            let components = ["x": Double(tapPoint.x), "y": Double(tapPoint.y)]
            value["requestedTapPoint"] = [
                "decimal": components.mapValues { String($0) },
                "ieee754Hex": components.mapValues { String($0.bitPattern, radix: 16) }
            ]
            value["targetEnabled"] = target.isEnabled
            value["selectorContainsRequestedTapPoint"] = selector.frame.contains(tapPoint)
            value["windowContainsRequestedTapPoint"] = window.frame.contains(tapPoint)
            value["observationContract"] = "Original midpoint interaction; whole-selector AX containment remains diagnostic"
        }
        let attachment = XCTAttachment(string: NativeGeometryEvidence.text(value))
        attachment.name = attachmentName
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func selectOriginalStressGroup(named name: String) {
        let snapshotStart = ProcessInfo.processInfo.systemUptime
        guard let snapshot = try? app.snapshot() else {
            retainOriginalGroupSelectionObservation("snapshot_unavailable", expectedName: name,
                selectors: [], targets: [], window: nil,
                snapshotSeconds: ProcessInfo.processInfo.systemUptime - snapshotStart)
            XCTFail("Require a fresh actual app snapshot before the original group action")
            return
        }
        let snapshotSeconds = ProcessInfo.processInfo.systemUptime - snapshotStart
        let elements = GroupStressSnapshot.descendants(of: snapshot)
        let selectors = elements.filter {
            $0.elementType == .segmentedControl && GroupStressSnapshot.matches($0, identifying: "study-group-selector")
        }
        if !selectors.isEmpty {
            guard selectors.count == 1, let selectorSnapshot = selectors.first,
                  selectorSnapshot.isEnabled else {
                retainOriginalGroupSelectionObservation("unique_enabled_selector", expectedName: name,
                    selectors: selectors, targets: [],
                    window: elements.first(where: { $0.elementType == .window }),
                    snapshotSeconds: snapshotSeconds)
                XCTFail("Require the unique enabled original segmented group selector")
                return
            }
            let targets = GroupStressSnapshot.descendants(of: selectorSnapshot).filter {
                $0.elementType == .button && $0.label == name
            }
            guard targets.count == 1, let target = targets.first,
                  let windowSnapshot = elements.first(where: { $0.elementType == .window }),
                  target.isEnabled,
                  [selectorSnapshot.frame, target.frame, windowSnapshot.frame].allSatisfy({ GroupStressSnapshot.finitePositive($0) }),
                  target.frame.midX.isFinite, target.frame.midY.isFinite,
                  selectorSnapshot.frame.contains(CGPoint(x: target.frame.midX, y: target.frame.midY)),
                  windowSnapshot.frame.contains(CGPoint(x: target.frame.midX, y: target.frame.midY)),
                  windowSnapshot.frame.contains(target.frame) else {
                retainOriginalGroupSelectionObservation("exact_snapshot_geometry", expectedName: name,
                    selectors: selectors, targets: targets,
                    window: elements.first(where: { $0.elementType == .window }),
                    snapshotSeconds: snapshotSeconds)
                XCTFail("Require the enabled original group button wholly inside the actual window and its requested midpoint inside the original selector")
                return
            }
            let selector = app.segmentedControls["study-group-selector"]
            let liveTarget = selector.buttons.matching(NSPredicate(format: "label == %@", name)).element
            let window = app.windows.firstMatch
            var live: [String: Any] = [:]
            var queryStart = ProcessInfo.processInfo.systemUptime
            let liveHittable = liveTarget.isHittable
            live["hittable"] = liveHittable
            live["hittableSeconds"] = ProcessInfo.processInfo.systemUptime - queryStart
            var targetCurrent = false
            var windowCurrent = false
            // Preserve the original short-circuit order and record each actual
            // queried value once; never replace it with a later failure snapshot.
            if liveHittable {
                queryStart = ProcessInfo.processInfo.systemUptime
                let frame = liveTarget.frame
                live["targetFrame"] = NativeGeometryEvidence.frame(frame)
                live["targetFrameSeconds"] = ProcessInfo.processInfo.systemUptime - queryStart
                targetCurrent = frame == target.frame
                if targetCurrent {
                    queryStart = ProcessInfo.processInfo.systemUptime
                    let frame = window.frame
                    live["windowFrame"] = NativeGeometryEvidence.frame(frame)
                    live["windowFrameSeconds"] = ProcessInfo.processInfo.systemUptime - queryStart
                    windowCurrent = frame == windowSnapshot.frame
                }
            }
            live["targetCurrent"] = targetCurrent
            live["windowCurrent"] = windowCurrent
            guard liveHittable, targetCurrent, windowCurrent else {
                retainOriginalGroupSelectionObservation("current_live_target", expectedName: name,
                    selectors: selectors, targets: targets, window: windowSnapshot,
                    snapshotSeconds: snapshotSeconds, live: live)
                XCTFail("The original group button and window must remain live and match the fresh snapshot")
                return
            }
            // Preserve the raw full-parent containment result, even when an
            // AX edge differs by one representable Double. This is interaction
            // evidence; it does not assert whole-control visual containment.
            retainOriginalGroupSelectionObservation("validated_original_midpoint",
                expectedName: name, selectors: selectors, targets: targets,
                window: windowSnapshot, snapshotSeconds: snapshotSeconds, live: live,
                attachmentName: "groups100-original-selection-observation")
            // A real XCTest tap at the same validated button midpoint, relative
            // to its original window. Preserve ordinary XCTest idle handling.
            window.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
                .withOffset(CGVector(dx: target.frame.midX - windowSnapshot.frame.minX,
                                     dy: target.frame.midY - windowSnapshot.frame.minY)).tap()
        } else {
            let menu = app.buttons["study-group-selector"]
            XCTAssertTrue(menu.exists && menu.isEnabled)
            tap(menu)
            let options = app.collectionViews.cells.buttons.matching(NSPredicate(format: "label == %@", name))
            XCTAssertTrue(options.firstMatch.exists || options.firstMatch.waitForExistence(timeout: 15))
            XCTAssertEqual(options.count, 1, "Only the exact original native group action may be selected")
            tap(options.element(boundBy: 0))
        }
    }

    @MainActor
    private func waitForOriginalGroup(named name: String, at url: URL,
                                      sceneID: String?, afterRevision: UInt64?) throws -> GroupStressWorkspace {
        // The predicate captures an explicitly actor-isolated observer, not a
        // local function that implicitly transfers XCTestCase/self in Swift 6.
        let observation = GroupStressNativeObservation(application: app, url: url, name: name,
                                                       sceneID: sceneID, afterRevision: afterRevision)
        if let workspace = observation.read() { return workspace }
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { observation.read() != nil }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 15), .completed,
                       "Require the same original scene, committed sidecar, enabled selected group, and selected original document card")
        return try XCTUnwrap(observation.read())
    }

    private func assertOriginalGroupMembership(_ workspace: GroupStressWorkspace,
                                               matches baseline: GroupStressWorkspace) throws {
        XCTAssertEqual(workspace.profiles, baseline.profiles)
        XCTAssertEqual(workspace.groups, baseline.groups,
                       "Group order, UUID membership, active documents, canonical locators and search state must remain unchanged")
        let current = try XCTUnwrap(workspace.current)
        for group in baseline.groups {
            let document = try XCTUnwrap(group.tabs.first)
            XCTAssertEqual(current.scene.activeTabIDsByGroup?[group.id], document.session.id,
                           "The original scene must retain each group's independent document owner")
        }
    }
}

// BEGIN ADDITIVE FULL-V40 ORIGINAL GROUPS100
private struct FullV40GroupTarget: Decodable {
    let key: String
    let bookID: Int
    let bookTitle: String
    let unitMode: String
    let unitStartLineIndex: Int
    let unitEndLineIndex: Int
    let unitRowCount: Int
    let sourceUTF16Length: Int
    let sourceSHA256: String
    let sourceFile: String
    let sectionLocator: String
}
private struct FullV40GroupCatalog: Decodable {
    let schema: Int
    let status: String
    let corpusProfile: String
    let databaseSHA256: String
    let targets: [FullV40GroupTarget]
}
private struct FullV40GroupCorpus {
    let target: FullV40GroupTarget
    let sidecar: URL
    let container: URL
    let database: URL
    let installationManifest: Data
    let ownerMetadata: Data
    let catalogSHA256: String
    let source: String
}

extension StudyGroupStressNativeAcceptanceTests {
    @MainActor
    func testOneHundredOriginalFullV40GroupSwitchesPreserveDocumentsAndColdRestore() throws {
        try groupV40Require(isPad, "The full-v40 case uses the actual original iPad groups UI")
        XCUIDevice.shared.orientation = .landscapeLeft
        try launchOriginalProductionGroups()
        let corpus = try verifiedProductionGroupCorpus()
        try openOriginalProductionGroupBook(corpus)
        let initialLocator = try assertOriginalProductionGroupReader(corpus)
        let url = corpus.sidecar
        try prepareProductionGroupSingleDocument(corpus)
        openGroupStressOverview()
        let initial = try readGroupStressWorkspace(url)
        XCTAssertEqual(initial.version, 1)
        XCTAssertEqual(initial.profiles.count, 1)
        XCTAssertEqual(initial.groups.count, 1)
        let original = try XCTUnwrap(initial.current)
        XCTAssertEqual(original.group.tabs.count, 1)
        XCTAssertEqual(original.document.backend, "otzaria")
        var workspace = try waitForOriginalGroup(named: original.group.name, at: url,
                                                 sceneID: original.sceneID, afterRevision: nil)
        let profileID = original.scene.profileID
        var names = [original.group.name]
        for name in ["v40 רצף א", "v40 רצף ב"] {
            XCTAssertFalse(workspace.groups.contains { $0.name == name })
            let beforeRevision = workspace.revision
            tap(app.buttons["study-group-actions-menu"])
            tap(app.buttons["קבוצה מהכרטיסיות הנוכחיות"])
            let prompt = app.alerts["שם קבוצת הכרטיסיות"]
            XCTAssertTrue(prompt.exists || prompt.waitForExistence(timeout: 10))
            prompt.textFields.firstMatch.typeText(name)
            tap(prompt.buttons["שמירה"])
            workspace = try waitForOriginalGroup(named: name, at: url,
                                                  sceneID: original.sceneID, afterRevision: beforeRevision)
            names.append(name)
        }
        XCTAssertEqual(workspace.groups.count, 3)
        XCTAssertEqual(Set(workspace.groups.map(\.id)).count, 3)
        XCTAssertTrue(workspace.groups.allSatisfy { $0.profileID == profileID && $0.tabs.count == 1 })
        XCTAssertEqual(Set(workspace.groups.flatMap { $0.tabs.map { $0.session.id } }).count, 3,
                       "Original copies must retain three different document owners, not one shared UUID")

        // Hydrate every original reader before pinning its durable navigation
        // state. These preparation transitions are explicitly not counted.
        var locators: [UUID: String] = [:]
        for name in names {
            let previous = try XCTUnwrap(workspace.current)
            XCTAssertNotEqual(previous.group.name, name)
            selectOriginalStressGroup(named: name)
            workspace = try waitForOriginalGroup(named: name, at: url,
                                                  sceneID: original.sceneID, afterRevision: workspace.revision)
            let current = try XCTUnwrap(workspace.current)
            closeGroupStressOverview()
            let locator = try assertOriginalProductionGroupReader(corpus)
            XCTAssertEqual(locator, initialLocator, "Copying a group preserves the actual original reading unit")
            locators[current.group.id] = locator
            openGroupStressOverview()
            workspace = try waitForOriginalGroup(named: name, at: url,
                                                  sceneID: original.sceneID, afterRevision: nil)
        }
        let baseline = workspace
        XCTAssertEqual(locators.count, 3)
        try assertOriginalGroupMembership(workspace, matches: baseline)
        try attachWorkspaceSnapshot("groups100-v40-before-consecutive-switches")
        retainNativeEvidence("groups100-v40-before-consecutive-switches")
        let evidence = GroupStressEvidence { [weak self] data in
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            attachment.name = "groups100-v40-original-transition-observations"
            attachment.lifetime = .keepAlways
            self?.add(attachment)
        }
        addTeardownBlock { await evidence.attachReport() }

        var performanceExpectations: [GroupStressMetricExpectation] = []
        var rssBoundaries: [[String: Any]] = []
        for step in 1...100 {
            let target = try XCTUnwrap(baseline.groups.first { $0.name == names[(step - 1) % names.count] })
            let previous = try XCTUnwrap(workspace.current)
            XCTAssertNotEqual(target.id, previous.group.id, "A same-group tap is not a counted transition")
            let targetDocument = try XCTUnwrap(target.tabs.first)
            XCTAssertNotEqual(targetDocument.session.id, previous.document.session.id)
            var observation: [String: Any] = [
                "step": step, "state": "attempted", "sceneID": previous.sceneID,
                "profileID": profileID.uuidString,
                "fromGroupID": previous.group.id.uuidString, "toGroupID": target.id.uuidString,
                "fromDocumentID": previous.document.session.id.uuidString,
                "toDocumentID": targetDocument.session.id.uuidString,
                "beforeRevision": workspace.revision
            ]
            evidence.transitions.append(observation)
            evidence.record(observation)
            let beforeRSS = try productionGroupRSS("begin", step: step, corpus: corpus, observation: observation)
            let start = ProcessInfo.processInfo.systemUptime
            selectOriginalStressGroup(named: target.name)
            let selectionReturnedAt = ProcessInfo.processInfo.systemUptime
            workspace = try waitForOriginalGroup(named: target.name, at: url,
                                                  sceneID: original.sceneID, afterRevision: workspace.revision)
            let observationReturnedAt = ProcessInfo.processInfo.systemUptime
            observation["automationSelectionElapsedSeconds"] = selectionReturnedAt - start
            observation["automationObservationElapsedSeconds"] = observationReturnedAt - selectionReturnedAt
            let current = try XCTUnwrap(workspace.current)
            XCTAssertEqual(current.group.id, target.id)
            XCTAssertEqual(current.document.session.id, targetDocument.session.id)
            XCTAssertEqual(current.scene.profileID, profileID)
            try assertOriginalGroupMembership(workspace, matches: baseline)
            performanceExpectations.append(.init(
                sceneID: previous.sceneID, fromGroupID: previous.group.id, toGroupID: current.group.id,
                fromDocumentID: previous.document.session.id, toDocumentID: current.document.session.id,
                observedBeforeRevision: try XCTUnwrap(observation["beforeRevision"] as? UInt64),
                observedAfterRevision: workspace.revision))
            observation["state"] = "committed"
            observation["afterRevision"] = workspace.revision
            observation["observedGroupID"] = current.group.id.uuidString
            observation["observedDocumentID"] = current.document.session.id.uuidString
            observation["selectedOriginalCardID"] = "tab-switcher-grid-cell-" + current.document.session.id.uuidString
            observation["selectedOriginalGroupName"] = current.group.name
            observation["automationElapsedSeconds"] = ProcessInfo.processInfo.systemUptime - start
            let afterRSS = try productionGroupRSS("end", step: step, corpus: corpus, observation: observation,
                                                  afterRevision: workspace.revision)
            rssBoundaries.append(["step": step, "begin": beforeRSS, "end": afterRSS])
            evidence.transitions[step - 1] = observation
            evidence.completedTransitions += 1
            evidence.record(observation)
        }
        XCTAssertEqual(evidence.completedTransitions, 100)
        XCTAssertEqual(evidence.transitions.count, 100)
        let cohortPID = try captureProductionGroupApplicationMetrics(sidecar: url, expected: performanceExpectations,
                                                                     rss: rssBoundaries, corpus: corpus)
        let final = try XCTUnwrap(workspace.current)
        try attachWorkspaceSnapshot("groups100-v40-after-100-original-commits")
        retainNativeEvidence("groups100-v40-after-100-original-commits")
        closeGroupStressOverview()
        XCTAssertEqual(try assertOriginalProductionGroupReader(corpus), locators[final.group.id])
        let preCold = try productionGroupColdPhase(corpus)
        try groupV40Require((preCold["processID"] as? NSNumber)?.int32Value == cohortPID,
                           "The original fresh source must belong to the exact 100-operation process")

        app.terminate()
        try launchOriginalProductionGroups()
        let restoredCorpus = try verifiedProductionGroupCorpus()
        try groupV40Require(restoredCorpus.sidecar == url && restoredCorpus.container == corpus.container
            && restoredCorpus.database == corpus.database && restoredCorpus.catalogSHA256 == corpus.catalogSHA256
            && restoredCorpus.installationManifest == corpus.installationManifest
            && restoredCorpus.ownerMetadata == corpus.ownerMetadata,
            "Cold launch must retain the exact same actual installation and owned namespace")
        let finalLocator = try XCTUnwrap(locators[final.group.id])
        let locator = app.staticTexts["reader-current-locator"]
        if locator.label != finalLocator {
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label == %@", finalLocator), object: locator)], timeout: 30), .completed)
        }
        XCTAssertEqual(try assertOriginalProductionGroupReader(corpus), finalLocator)
        openGroupStressOverview()
        // A genuine cold launch may create a different system scene identifier.
        // Its restored group/profile/document must still be the exact final one.
        workspace = try waitForOriginalGroup(named: final.group.name, at: url,
                                              sceneID: nil, afterRevision: nil)
        let restored = try XCTUnwrap(workspace.current)
        XCTAssertEqual(restored.scene.profileID, profileID)
        XCTAssertEqual(restored.group.id, final.group.id)
        XCTAssertEqual(restored.document.session.id, final.document.session.id)
        try assertOriginalGroupMembership(workspace, matches: baseline)
        try attachWorkspaceSnapshot("groups100-v40-after-cold-restore")
        retainNativeEvidence("groups100-v40-after-cold-restore")
        closeGroupStressOverview()
        XCTAssertEqual(try assertOriginalProductionGroupReader(corpus), finalLocator)
        let postCold = try productionGroupColdPhase(restoredCorpus)
        try groupV40Require((postCold["processID"] as? NSNumber)?.int32Value != cohortPID
            && postCold["requestID"] as? String != preCold["requestID"] as? String,
            "A cold launch requires a different actual app PID and a fresh original source request")
        for key in ["profileID", "groupID", "documentID", "canonicalLocator"] {
            try groupV40Require(postCold[key] as? String == preCold[key] as? String,
                               "Cold restoration must preserve the original " + key)
        }
        let cold = XCTAttachment(data: try JSONSerialization.data(withJSONObject: [
            "schema": 1, "namespace": workspaceNamespace, "catalogSHA256": corpus.catalogSHA256,
            "databaseSHA256": "8389709c1702753af6f0719ef1c98c09854450e48ebb05fe1f95486b26348b01",
            "installationManifestSHA256": groupV40Digest(corpus.installationManifest),
            "containerPath": corpus.container.path, "databasePath": corpus.database.path,
            "preCold": preCold, "postCold": postCold
        ], options: [.sortedKeys]), uniformTypeIdentifier: "public.json")
        cold.name = "groups100-v40-cold-process-and-installation-proof"; cold.lifetime = .keepAlways; add(cold)
        evidence.coldRestoreVerified = true
    }

    private var productionGroupViewportName: String { "full-v32-reader-" + workspaceNamespace }

    private func groupV40Require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { XCTFail(message); throw FullV32ObservationFailure() }
    }
    private func groupV40Digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    private func groupV40Bytes(_ url: URL, cap: Int) throws -> Data {
        let resource = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        try groupV40Require(resource.isRegularFile == true && resource.isSymbolicLink == false
            && url.standardizedFileURL == url.resolvingSymlinksInPath()
            && (resource.fileSize ?? cap + 1) > 0 && (resource.fileSize ?? cap + 1) <= cap,
            "Require bounded original regular production evidence")
        let data = try Data(contentsOf: url)
        try groupV40Require(data.count == resource.fileSize && data.count <= cap, "Evidence must retain its complete bounded bytes")
        return data
    }
    private func groupV40PinnedInput(_ key: String, cap: Int) throws -> (URL, Data) {
        let environment = ProcessInfo.processInfo.environment
        let url = URL(fileURLWithPath: try XCTUnwrap(environment[key + "_FILE"]))
        let expected = try XCTUnwrap(environment[key + "_SHA256"])
        let bytes = try groupV40Bytes(url, cap: cap)
        try groupV40Require(expected.count == 64 && groupV40Digest(bytes) == expected,
                           "The exact qualified production input changed: " + key)
        return (url, bytes)
    }

    @MainActor
    private func launchOriginalProductionGroups() throws {
        for key in ["OTZARIA_SHARED_ROOT_OVERRIDE", "OTZARIA_PRODUCTION_DB_PATH"] {
            try groupV40Require(ProcessInfo.processInfo.environment[key] == nil,
                               "Production Groups100 uses the actual managed installation")
        }
        launchWithTier(.production, backend: "otzaria", extraArgs: [
            "-studyWorkspaceTestingNamespace", workspaceNamespace,
            "-StudyGroupPerformanceEnabled", "YES", "-StudyGroupProductionPerformanceEnabled", "YES"
        ], extraEnvironment: [
            "CHAVRUSA_READER_VIEWPORT_REPORT": productionGroupViewportName,
            "CHAVRUSA_FULL_V32_SOURCE_OBSERVATION": "1"
        ])
        for (key, expected) in [("-OtzariaDataProfile", "production"),
            ("-studyWorkspaceTestingNamespace", workspaceNamespace), ("-preferredBackend", "otzaria"),
            ("-StudyGroupPerformanceEnabled", "YES"), ("-StudyGroupProductionPerformanceEnabled", "YES")] {
            let indices = app.launchArguments.indices.filter { app.launchArguments[$0] == key }
            try groupV40Require(indices.count == 1, "Exactly one original production launch setting is required")
            let index = try XCTUnwrap(indices.first)
            try groupV40Require(app.launchArguments.indices.contains(index + 1)
                && app.launchArguments[index + 1] == expected, "Do not substitute miniTest10 or another namespace")
        }
        try groupV40Require(!app.launchArguments.contains("-smokeBypassBootstrap")
            && !app.launchArguments.contains("-smokeScenario")
            && !app.launchArguments.contains("-otzaria_reader_unit_mode")
            && app.launchEnvironment["OTZARIA_DATA_PROFILE"] == "production"
            && app.launchEnvironment["SIMCTL_CHILD_OTZARIA_DATA_PROFILE"] == "production",
            "Use ordinary production bootstrap and original editable preferences")
        dismissAlertsIfNeeded()
    }

    @MainActor
    private func verifiedProductionGroupCorpus() throws -> FullV40GroupCorpus {
        let (catalogURL, catalogBytes) = try groupV40PinnedInput("GROUPS100_V40_CATALOG", cap: 131072)
        let catalog = try JSONDecoder().decode(FullV40GroupCatalog.self, from: catalogBytes)
        let databaseSHA = "8389709c1702753af6f0719ef1c98c09854450e48ebb05fe1f95486b26348b01"
        try groupV40Require(catalog.schema == 1 && catalog.status == "ORIGINAL_SOURCE_CATALOG_ONLY_NOT_UI"
            && catalog.corpusProfile == "full-v40" && catalog.databaseSHA256 == databaseSHA
            && catalog.targets.count == 10 && Set(catalog.targets.map(\.key)).count == 10,
            "Require the independently generated complete full-v40 catalog")
        let target = try XCTUnwrap(catalog.targets.first { $0.key == "103-first" })
        try groupV40Require(target.bookID == 103 && target.bookTitle == "ברכות" && target.unitMode == "chapter"
            && target.sectionLocator == "otzaria|book:103|line:\(target.unitStartLineIndex)",
            "Select the independently queried actual v40 Berakhot first chapter")
        let (_, receiptBytes) = try groupV40PinnedInput("GROUPS100_V40_INSTALLATION", cap: 8 * 1024 * 1024)
        let receipt = try XCTUnwrap(JSONSerialization.jsonObject(with: receiptBytes) as? [String: Any])
        let database = try XCTUnwrap(receipt["database"] as? [String: Any])
        let counts = try XCTUnwrap(receipt["counts"] as? [String: Any])
        try groupV40Require(database["sha256"] as? String == databaseSHA
            && (database["bytes"] as? NSNumber)?.int64Value == 4_355_063_808
            && (counts["book"] as? NSNumber)?.intValue == 8259
            && (counts["line"] as? NSNumber)?.intValue == 7_925_185
            && (counts["link"] as? NSNumber)?.intValue == 7_001_824,
            "The driver must independently admit the real complete installed v40 bytes and SQL counts")
        let sidecar = try workspaceSidecarURL().standardizedFileURL
        let suffix = ["Library", "Application Support", "ChavrusaText", "StudyWorkspace", "UITests", workspaceNamespace + ".json"]
        try groupV40Require(Array(sidecar.pathComponents.suffix(suffix.count)) == suffix,
                           "Use this original fresh namespace, never replace an existing sidecar")
        var container = sidecar
        for _ in suffix { container.deleteLastPathComponent() }
        let expectedParent = try workspaceContainerParent().standardizedFileURL
        try groupV40Require(container.deletingLastPathComponent() == expectedParent
            && UUID(uuidString: container.lastPathComponent) != nil, "The sidecar must belong to the actual installed app")
        let udid = try XCTUnwrap(ProcessInfo.processInfo.environment["SIMULATOR_UDID"])
        let simulator = container.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        try groupV40Require(UUID(uuidString: udid) != nil && simulator.lastPathComponent == "data"
            && simulator.deletingLastPathComponent().lastPathComponent.lowercased() == udid.lowercased(),
            "Do not borrow a corpus or workspace from another Simulator")
        let metadata = try groupV40Bytes(container.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist"), cap: 65536)
        let owner = try XCTUnwrap(PropertyListSerialization.propertyList(from: metadata, format: nil) as? [String: Any])
        try groupV40Require(owner["MCMMetadataIdentifier"] as? String == "com.davidpovarsky.chavrusatext",
                           "The namespace must be owned by the original app bundle")
        let originalDatabase = URL(fileURLWithPath: try XCTUnwrap(database["path"] as? String)).standardizedFileURL
        let pieces = originalDatabase.pathComponents
        let positions = pieces.indices.filter { index in
            index + 7 < pieces.count && pieces[index] == "Devices" && pieces[index + 1].lowercased() == udid.lowercased()
                && Array(pieces[(index + 2)..<(index + 6)]) == ["data", "Containers", "Data", "Application"]
        }
        try groupV40Require(positions.count == 1, "The retained database path must name this same owned installation")
        let position = try XCTUnwrap(positions.first)
        try groupV40Require(UUID(uuidString: pieces[position + 6]) != nil, "Original app container UUID is required")
        let relative = Array(pieces.dropFirst(position + 7))
        try groupV40Require(relative.count >= 2 && Array(relative.suffix(2)) == ["Otzaria", "seforim.db"]
            && !relative.contains(".."), "Preserve the original database relative location after an XCTest container relocation")
        let currentDatabase = container.appendingPathComponent(relative.joined(separator: "/"))
        let resource = try currentDatabase.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        try groupV40Require(resource.isRegularFile == true && resource.isSymbolicLink == false
            && resource.fileSize == 4_355_063_808
            && currentDatabase.standardizedFileURL == currentDatabase.resolvingSymlinksInPath(),
            "The original complete installed database must remain present")
        let manifest = try groupV40Bytes(currentDatabase.deletingLastPathComponent().appendingPathComponent("seforim-installation.json"), cap: 131072)
        let manifestWitness = try XCTUnwrap(receipt["installation_manifest"] as? [String: Any])
        try groupV40Require(groupV40Digest(manifest) == manifestWitness["sha256"] as? String
            && manifest.count == (manifestWitness["bytes"] as? NSNumber)?.intValue,
            "The actual installation manifest must match the driver-admitted current installation")
        let record = try XCTUnwrap(JSONSerialization.jsonObject(with: manifest) as? [String: Any])
        try groupV40Require(record["releaseTag"] as? String == "v40-20261123094345"
            && (record["releaseID"] as? NSNumber)?.int64Value == 455_390_662,
            "The original installed library must be the explicitly pinned v40 release")
        var connection: OpaquePointer?
        try groupV40Require(sqlite3_open_v2(currentDatabase.path, &connection, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK,
                           "Read the actual owned production SQL database without writing it")
        let db = try XCTUnwrap(connection); defer { sqlite3_close(db) }
        try groupV40Require(sqlite3_db_readonly(db, "main") == 1, "Database observation must be read-only")
        var statement: OpaquePointer?
        try groupV40Require(sqlite3_prepare_v2(db, "SELECT title,(SELECT COUNT(*) FROM line WHERE bookId=book.id) FROM book WHERE id=?", -1, &statement, nil) == SQLITE_OK,
                           "Independently query this real production book")
        let query = try XCTUnwrap(statement); defer { sqlite3_finalize(query) }
        try groupV40Require(sqlite3_bind_int64(query, 1, Int64(target.bookID)) == SQLITE_OK && sqlite3_step(query) == SQLITE_ROW,
                           "The selected catalog book must exist in the actual installed corpus")
        let title = String(cString: try XCTUnwrap(sqlite3_column_text(query, 0)))
        try groupV40Require(title == target.bookTitle && sqlite3_column_int64(query, 1) == 2875
            && sqlite3_step(query) == SQLITE_DONE, "Do not transfer a mini/v32 book identity into v40 acceptance")
        let sourceURL = catalogURL.deletingLastPathComponent().appendingPathComponent(target.sourceFile)
        try groupV40Require(sourceURL.deletingLastPathComponent() == catalogURL.deletingLastPathComponent(), "The source file must remain in the exact catalog directory")
        let sourceBytes = try groupV40Bytes(sourceURL, cap: 32 * 1024 * 1024)
        let source = try XCTUnwrap(String(data: sourceBytes, encoding: .utf8))
        try groupV40Require(groupV40Digest(sourceBytes) == target.sourceSHA256
            && source.utf16.count == target.sourceUTF16Length, "Use the whole unchanged original reading-unit source")
        return .init(target: target, sidecar: sidecar, container: container, database: currentDatabase,
                     installationManifest: manifest, ownerMetadata: metadata,
                     catalogSHA256: groupV40Digest(catalogBytes), source: source)
    }

    @MainActor
    private func openOriginalProductionGroupBook(_ corpus: FullV40GroupCorpus) throws {
        tap(readerLibraryPaletteLauncher())
        let palette = app.descendants(matching: .any)["reader-library-command-palette"]
        try groupV40Require(palette.waitForExistence(timeout: 30), "Open the actual original Library palette")
        let input = palette.textFields.firstMatch
        tap(input)
        input.typeKey(XCUIKeyboardKey(rawValue: "a"), modifierFlags: .command)
        input.typeText(corpus.target.bookTitle)
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", corpus.target.bookTitle), object: input)
        try groupV40Require(XCTWaiter.wait(for: [settled], timeout: 15) == .completed, "The actual Hebrew query must settle completely")
        let rows = palette.buttons.matching(NSPredicate(format: "label == %@", corpus.target.bookTitle))
        try groupV40Require(rows.firstMatch.waitForExistence(timeout: 30) && rows.count == 1, "Use the one actual hash-bound production book")
        tap(rows.firstMatch)
        try groupV40Require(app.textViews["reader-text"].waitForExistence(timeout: 60), "The original production reader must load")
        tap(app.buttons["reader-more-menu"])
        tap(app.buttons["reader-display-unit-menu"])
        tap(app.buttons["reader-display-unit-chapter"])
        tap(app.buttons["reader-more-menu"])
        tap(app.buttons["reader-toc-toggle"])
        let toc = app.descendants(matching: .any)["toc-content-list"]
        try groupV40Require(toc.waitForExistence(timeout: 60), "The original full book TOC must load")
        let rowsAtStart = app.buttons.matching(identifier: "toc-row-" + String(corpus.target.unitStartLineIndex))
        var choices: [XCUIElement] = []
        for _ in 0..<80 {
            choices = rowsAtStart.allElementsBoundByIndex.filter { $0.isHittable }
            if !choices.isEmpty { break }
            toc.swipeDown(velocity: .slow)
        }
        let first = try XCTUnwrap(choices.first, "Reach the actual catalog first-unit TOC row through original scrolling")
        tap(first)
        let close = app.buttons["toc-close"]
        if close.exists && close.isHittable { tap(close) }
        _ = try assertOriginalProductionGroupReader(corpus)
    }

    @MainActor
    @discardableResult
    private func assertOriginalProductionGroupReader(_ corpus: FullV40GroupCorpus) throws -> String {
        let locator = app.staticTexts["reader-current-locator"]
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", corpus.target.sectionLocator), object: locator)
        try groupV40Require(XCTWaiter.wait(for: [ready], timeout: 60) == .completed,
                           "Original Reader must show the exact catalog unit")
        assertReaderHasText()
        try groupV40Require(app.staticTexts["reader-header-title"].label == corpus.target.bookTitle,
                           "The actual native title must identify the independently queried book")
        let prefix = corpus.container.appendingPathComponent("Documents/" + productionGroupViewportName)
        let id = UUID().uuidString
        try id.write(to: URL(fileURLWithPath: prefix.path + ".request"), atomically: true, encoding: .utf8)
        var report: [String: Any]?
        let fresh = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let bytes = try? Data(contentsOf: URL(fileURLWithPath: prefix.path + ".viewport.json")), bytes.count <= 32768,
                  let value = (try? JSONSerialization.jsonObject(with: bytes)) as? [String: Any],
                  value["requestID"] as? String == id else { return false }
            report = value; return true
        }, object: nil)
        try groupV40Require(XCTWaiter.wait(for: [fresh], timeout: 15) == .completed, "Require a fresh original native source report")
        let value = try XCTUnwrap(report)
        let sample = try XCTUnwrap(value["fullV32SourceObservation"] as? [String: Any])
        let location = try XCTUnwrap((sample["rangeLocation"] as? NSNumber)?.intValue)
        let length = try XCTUnwrap((sample["rangeLength"] as? NSNumber)?.intValue)
        let source = corpus.source as NSString
        try groupV40Require((sample["schema"] as? NSNumber)?.intValue == 1
            && sample["status"] as? String == "AVAILABLE"
            && ((sample["processID"] as? NSNumber)?.int32Value ?? 0) > 0
            && (sample["observedUptime"] as? NSNumber)?.doubleValue.isFinite == true
            && ((sample["observedUptime"] as? NSNumber)?.doubleValue ?? 0) > 0
            && sample["scope"] as? String == "bounded original source sample; not first pixel or full rendered-body proof"
            && (sample["sourceUTF16Length"] as? NSNumber)?.intValue == source.length
            && location >= 0 && length > 0 && length <= 256 && location <= source.length && length <= source.length - location,
            "The actual reader must retain the complete exact source unit")
        let actual = try XCTUnwrap(sample["sourceUTF8"] as? String)
        try groupV40Require(Data(actual.utf8) == Data(source.substring(with: NSRange(location: location, length: length)).utf8)
            && value["usesTextKit2BeforeObservation"] as? Bool == true
            && value["usesTextKit2AfterObservation"] as? Bool == true, "Exact UTF16/UTF8 source observation must preserve the original TextKit 2 renderer")
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: [
            "catalogSHA256": corpus.catalogSHA256, "targetKey": corpus.target.key,
            "sourceSHA256": corpus.target.sourceSHA256, "viewport": value
        ], options: [.sortedKeys]), uniformTypeIdentifier: "public.json")
        attachment.name = "groups100-v40-original-source-" + id; attachment.lifetime = .keepAlways; add(attachment)
        return locator.label
    }

    @MainActor
    private func productionGroupColdPhase(_ corpus: FullV40GroupCorpus) throws -> [String: Any] {
        // Called immediately after assertOriginalProductionGroupReader issues
        // and validates a new original native source observation.
        let prefix = corpus.container.appendingPathComponent("Documents/" + productionGroupViewportName)
        let requested = try XCTUnwrap(String(data: groupV40Bytes(URL(fileURLWithPath: prefix.path + ".request"), cap: 64), encoding: .utf8))
        let bytes = try groupV40Bytes(URL(fileURLWithPath: prefix.path + ".viewport.json"), cap: 32768)
        let report = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        let source = try XCTUnwrap(report["fullV32SourceObservation"] as? [String: Any])
        let pid = try XCTUnwrap((source["processID"] as? NSNumber)?.int32Value)
        let uptime = try XCTUnwrap((source["observedUptime"] as? NSNumber)?.doubleValue)
        try groupV40Require(UUID(uuidString: requested) != nil && report["requestID"] as? String == requested
            && (source["schema"] as? NSNumber)?.intValue == 1 && source["status"] as? String == "AVAILABLE"
            && pid > 0 && uptime.isFinite && uptime > 0,
            "Use this exact current original source request and its actual process identity")
        let state = try readGroupStressWorkspace(corpus.sidecar)
        let current = try XCTUnwrap(state.current)
        try groupV40Require(current.document.backend == "otzaria"
            && current.document.session.bookId == corpus.target.bookID
            && app.staticTexts["reader-current-locator"].label == corpus.target.sectionLocator,
            "Bind the source process to the actual original persisted document and native canonical unit")
        return ["processID": pid, "requestID": requested, "observedUptime": uptime,
                "sceneID": current.sceneID, "profileID": current.scene.profileID.uuidString,
                "groupID": current.group.id.uuidString, "documentID": current.document.session.id.uuidString,
                "canonicalLocator": corpus.target.sectionLocator, "workspaceRevision": state.revision]
    }

    @MainActor
    private func prepareProductionGroupSingleDocument(_ corpus: FullV40GroupCorpus) throws {
        // This is a separate production preparation after full corpus admission.
        // Never call the existing miniTest10-only fixture helper for this case.
        openGroupStressOverview()
        let initial = try readGroupStressWorkspace(corpus.sidecar)
        let current = try XCTUnwrap(initial.current)
        try groupV40Require(initial.profiles.count == 1 && initial.groups.count == 1
            && current.document.session.bookId == corpus.target.bookID && current.group.tabs.count <= 32,
            "Bound cleanup to this fresh namespace's one observed original group")
        let overview = app.descendants(matching: .any)["study-groups-overview"]
        let cells = overview.collectionViews.cells.matching(NSPredicate(format: "identifier BEGINSWITH %@", "tab-switcher-grid-cell-"))
        let kept = current.document.session.id
        let expectedIDs = Set(current.group.tabs.map { $0.session.id })
        let nativeIDs = try Set(cells.allElementsBoundByIndex.map {
            try XCTUnwrap(UUID(uuidString: String($0.identifier.dropFirst("tab-switcher-grid-cell-".count))))
        })
        try groupV40Require(expectedIDs == nativeIDs && cells["tab-switcher-grid-cell-" + kept.uuidString].isSelected,
                           "Corroborate every original member and the selected UUID before closing anything")
        try attachWorkspaceSnapshot("groups100-v40-original-imported-members")
        var remaining = expectedIDs
        for id in expectedIDs.subtracting([kept]).sorted(by: { $0.uuidString < $1.uuidString }) {
            let cell = cells["tab-switcher-grid-cell-" + id.uuidString]
            try groupV40Require(cell.exists && cell.isHittable && !cell.isSelected, "Close only an observed noncurrent original document copy")
            cell.swipeRight()
            let vanished = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: cell)
            try groupV40Require(XCTWaiter.wait(for: [vanished], timeout: 15) == .completed, "The actual original swipe must close that UUID")
            remaining.remove(id)
            let desired = remaining
            let persisted = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                guard let bytes = try? Data(contentsOf: corpus.sidecar),
                      let state = try? JSONDecoder().decode(GroupStressWorkspace.self, from: bytes), let selected = state.current else { return false }
                return selected.group.id == current.group.id && selected.document.session.id == kept
                    && Set(selected.group.tabs.map { $0.session.id }) == desired
            }, object: nil)
            try groupV40Require(XCTWaiter.wait(for: [persisted], timeout: 15) == .completed,
                               "Each original close must preserve the selected real book and remove only that UUID")
        }
        try groupV40Require(cells.count == 1 && cells["tab-switcher-grid-cell-" + kept.uuidString].isSelected,
                           "The real source document must be the sole retained original member")
        closeGroupStressOverview()
        _ = try assertOriginalProductionGroupReader(corpus)
    }

    @MainActor
    private func productionGroupRSS(_ operation: String, step: Int, corpus: FullV40GroupCorpus,
                                    observation: [String: Any], afterRevision: UInt64? = nil) throws -> [String: Any] {
        let token = try XCTUnwrap(ProcessInfo.processInfo.environment["GROUPS100_V40_OBSERVER_TOKEN"])
        try groupV40Require(token.range(of: #"^[a-f0-9]{32}$"#, options: .regularExpression) != nil,
                           "A unique owned native RSS observer token is required")
        let nonce = UUID().uuidString
        let prefix = corpus.container.appendingPathComponent("Documents/groups100-v40-\(token)-\(nonce)")
        var request: [String: Any] = ["token": token, "nonce": nonce, "operation": operation,
                                     "namespace": workspaceNamespace, "step": step]
        for key in ["sceneID", "profileID", "fromGroupID", "toGroupID", "fromDocumentID", "toDocumentID", "beforeRevision"] {
            request[key] = try XCTUnwrap(observation[key])
        }
        if let afterRevision { request["afterRevision"] = afterRevision }
        let bytes = try JSONSerialization.data(withJSONObject: request, options: [.sortedKeys])
        try groupV40Require(bytes.count <= 16384, "Keep observational requests bounded")
        try bytes.write(to: URL(fileURLWithPath: prefix.path + ".request.json"), options: .atomic)
        let ackURL = URL(fileURLWithPath: prefix.path + ".ack.json")
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in FileManager.default.fileExists(atPath: ackURL.path) }, object: nil)
        try groupV40Require(XCTWaiter.wait(for: [ready], timeout: 30) == .completed,
                           "The actual owned app RSS observation must acknowledge this unique operation")
        let ackBytes = try groupV40Bytes(ackURL, cap: 32768)
        let ack = try XCTUnwrap(JSONSerialization.jsonObject(with: ackBytes) as? [String: Any])
        try groupV40Require(ack["nonce"] as? String == nonce && ack["operation"] as? String == operation
            && (ack["step"] as? NSNumber)?.intValue == step
            && ack["status"] as? String == "ORIGINAL_APP_RSS_SAMPLE"
            && ((ack["processID"] as? NSNumber)?.intValue ?? 0) > 0
            && ((ack["rssBytes"] as? NSNumber)?.int64Value ?? 0) > 0
            && (ack["hostMonotonic"] as? NSNumber)?.doubleValue.isFinite == true
            && !String(decoding: ackBytes, as: UTF8.self).contains(token),
            "A host ACK must carry this exact actual app/PID/RSS observation without the token")
        if operation == "end" {
            try groupV40Require((ack["operationID"] as? String).flatMap(UUID.init(uuidString:)) != nil,
                               "End RSS observation must bind the unique original application operation")
        }
        // Preserve both request and ACK files for the integration owner's archive.
        return ack
    }

    @MainActor
    private func captureProductionGroupApplicationMetrics(sidecar: URL, expected: [GroupStressMetricExpectation],
                                                          rss: [[String: Any]], corpus: FullV40GroupCorpus) throws -> Int32 {
        let reader = GroupStressMetricReader(url: corpus.container.appendingPathComponent("Documents/OtzariaLogs/otzaria-reader.log"),
                                            namespace: workspaceNamespace, expected: expected)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in (try? reader.matched()) != nil }, object: nil)
        try groupV40Require(XCTWaiter.wait(for: [ready], timeout: 15) == .completed,
                           "Require all 100 uniquely matched actual application operations and memory observations")
        let samples = try reader.matched()
        try groupV40Require(samples.count == 100 && rss.count == 100, "Retain every consecutive actual transition")
        for (index, sample) in samples.enumerated() {
            let before = try XCTUnwrap(rss[index]["begin"] as? [String: Any])
            let after = try XCTUnwrap(rss[index]["end"] as? [String: Any])
            try groupV40Require((rss[index]["step"] as? Int) == index + 1
                && (after["operationID"] as? String).flatMap(UUID.init(uuidString:)) == sample.operationID
                && (before["processID"] as? NSNumber)?.int32Value == sample.processID
                && (after["processID"] as? NSNumber)?.int32Value == sample.processID,
                "Both actual host RSS boundaries must identify the same original application operation and PID")
        }
        let actual = XCTAttachment(data: try JSONEncoder().encode(samples), uniformTypeIdentifier: "public.json")
        actual.name = "groups100-v40-application-matched-operation-samples"
        actual.lifetime = .keepAlways; add(actual)
        let boundaries = XCTAttachment(data: try JSONSerialization.data(withJSONObject: [
            "schema": 1, "namespace": workspaceNamespace, "catalogSHA256": corpus.catalogSHA256,
            "metric": "Darwin process RSS bytes", "scope": "host before/after snapshots of the original 100 UI transitions; not continuous peak RSS",
            "transitions": rss
        ], options: [.sortedKeys]), uniformTypeIdentifier: "public.json")
        boundaries.name = "groups100-v40-host-rss-boundary-samples"
        boundaries.lifetime = .keepAlways; add(boundaries)
        let elapsed = samples.map { $0.elapsedSeconds * 1000 }.sorted()
        let summary: [String: Any] = [
            "schema": 1, "namespace": workspaceNamespace, "count": 100, "corpusProfile": "full-v40",
            "timingScope": samples[0].timingScope, "p50OperationMilliseconds": elapsed[49],
            "p95OperationMilliseconds": elapsed[94], "maxOperationMilliseconds": elapsed[99],
            "percentileMethod": "nearest rank, all 100 actual observations",
            "applicationMemoryMetric": "phys_footprint_bytes", "applicationBoundarySampleCount": 200,
            "hostMemoryMetric": "Darwin RSS bytes", "hostBoundarySampleCount": 200,
            "performanceThresholdDefined": false,
            "scope": "Original Debug iPad Simulator on the actual full-v40 installation; no physical device, first-pixel, continuous peak or invented SLA claim"
        ]
        let report = XCTAttachment(data: try JSONSerialization.data(withJSONObject: summary, options: [.sortedKeys]), uniformTypeIdentifier: "public.json")
        report.name = "groups100-v40-application-operation-memory-summary"
        report.lifetime = .keepAlways; add(report)
        return samples[0].processID
    }
}
// END ADDITIVE FULL-V40 ORIGINAL GROUPS100


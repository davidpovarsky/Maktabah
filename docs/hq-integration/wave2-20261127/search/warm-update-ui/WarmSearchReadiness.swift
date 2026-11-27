
// Test-only original-control observation around the final ordinary Settings Retry.
// The Settings test owns the two calls and must not terminate/relaunch between them.
@MainActor
struct OriginalSearchDataUpdateReadiness {
    struct Observation {
        fileprivate let sequenceID: String
        fileprivate let processID: Int
        fileprivate let capturedAtUnix: TimeInterval
        fileprivate let hierarchySHA256: String
        fileprivate let statuses: [String: String]
    }

    let app: XCUIApplication
    let test: XCTestCase
    private var ui: OriginalSearchContextUI { OriginalSearchContextUI(app: app, test: test) }

    private func admitOriginalSettingsLaunch() throws {
        for (key, value) in [("-OtzariaDataProfile", "production"), ("-preferredBackend", "otzaria"),
                             ("-AppleLanguages", "(en)"), ("-AppleLocale", "en_US")] {
            let positions = app.launchArguments.indices.filter { app.launchArguments[$0] == key }
            try requireSearchDataFixture(positions.count == 1, "Require the original English production Settings launch")
            let index = try XCTUnwrap(positions.first)
            try requireSearchDataFixture(app.launchArguments.indices.contains(index + 1)
                && app.launchArguments[index + 1] == value, "Unexpected original Settings launch value: " + key)
        }
        try requireSearchDataFixture(app.launchEnvironment["OTZARIA_DATA_PROFILE"] == "production"
            && !app.launchArguments.contains("-smokeBypassBootstrap")
            && !app.launchArguments.contains("-studyWorkspaceTestingNamespace"), "Keep the actual ordinary production workspace")
        for key in ["OTZARIA_SHARED_ROOT_OVERRIDE", "OTZARIA_PRODUCTION_DB_PATH"] {
            try requireSearchDataFixture(app.launchEnvironment[key] == nil
                && app.launchEnvironment["SIMCTL_CHILD_" + key] == nil, "No alternate source is eligible for warm update readiness")
        }
    }

    private func observedProcess(_ name: String) throws -> (id: Int, hierarchySHA256: String) {
        try requireSearchDataFixture(app.state == .runningForeground, "Observe the original foreground application")
        let hierarchy = app.debugDescription
        // XCTest's public original application hierarchy reports its own pid.
        // Require that actual field; never substitute the UI-test runner PID.
        let expression = try NSRegularExpression(pattern: #"(?m)^\s*(?:Attributes:\s*)?(?:→\s*)?Application,[^\r\n]*?\bpid:\s*([0-9]+)\b"#)
        let range = NSRange(hierarchy.startIndex..<hierarchy.endIndex, in: hierarchy)
        let matches = expression.matches(in: hierarchy, range: range)
        let identities = Set(matches.compactMap { match -> Int? in
            guard let value = Range(match.range(at: 1), in: hierarchy) else { return nil }
            return Int(hierarchy[value])
        })
        try requireSearchDataFixture(!matches.isEmpty && identities.count == 1,
            "The original public XCTest hierarchy must identify exactly one application PID")
        let pid = try XCTUnwrap(identities.first)
        try requireSearchDataFixture(pid > 1 && pid != Int(ProcessInfo.processInfo.processIdentifier),
            "A UI-test runner PID is not the observed application")
        let attachment = XCTAttachment(string: hierarchy)
        attachment.name = name + "-actual-application-pid-hierarchy"
        attachment.lifetime = .keepAlways
        test.add(attachment)
        return (pid, searchDataDigest(Data(hierarchy.utf8)))
    }

    private func dismissOriginalSettingsIfPresent() throws {
        let done = ui.control("settings-done-button")
        let updates = app.navigationBars["Library Updates"]
        if updates.exists && !done.isHittable {
            let back = updates.buttons.matching(NSPredicate(format: "label == %@", "Settings"))
                .allElementsBoundByIndex.filter(\.isHittable)
            try requireSearchDataFixture(back.count == 1, "Return through the original Library Updates back action")
            back[0].tap()
        }
        if done.exists {
            try requireSearchDataFixture(done.isHittable, "The original Settings Done action must be usable")
            done.tap()
            try ui.wait("Original Settings must dismiss without relaunch") { !self.ui.control("settings-done-button").exists }
        }
        try requireSearchDataFixture(!updates.exists, "Dismiss the original update presentation before using root Search")
    }

    private func openOriginalSearchData() throws {
        try dismissOriginalSettingsIfPresent()
        try ui.returnToOriginalSearch()
        try ui.require("global-search-more").tap()
        try ui.require("global-search-data").tap()
        try ui.require("search-data-screen")
    }

    private func closeOriginalDataAndReturnToLibrary() throws {
        for _ in 0..<8 {
            if ui.control("search-data-close").isHittable { break }
            try ui.require("search-data-screen").swipeUp()
        }
        let close = try ui.require("search-data-close")
        try requireSearchDataFixture(close.isHittable, "Reach the original Search Data close control")
        close.tap()
        try ui.wait("Original Search Data must dismiss") { !self.ui.control("search-data-screen").exists }
        let tabs = app.tabBars.buttons.matching(NSPredicate(format: "label == %@", "Library"))
            .allElementsBoundByIndex.filter { $0.isHittable && $0.frame.intersects(app.frame) }
        try requireSearchDataFixture(tabs.count == 1, "Require one original root Library tab in the admitted English UI")
        tabs[0].tap()
        try ui.wait("Return to the existing original Library tab without opening a book") { tabs[0].isSelected }
    }

    private func record(_ observation: Observation, previous: Observation?, updatedDatabaseBytes: Int64?) throws {
        let stem = previous == nil ? "settings-update-warm-search-ready-before-final-retry"
            : "settings-update-warm-search-mismatch-after-final-retry"
        var value: [String: Any] = [
            "schemaVersion": 1, "sequenceID": observation.sequenceID,
            "processID": observation.processID, "capturedAtUnix": observation.capturedAtUnix,
            "applicationHierarchySHA256": observation.hierarchySHA256, "statuses": observation.statuses,
            "phase": previous == nil ? "ready-before-final-original-retry" : "mismatch-after-final-original-retry",
            "processIdentitySource": "actual public XCUIApplication.debugDescription Application pid field",
            "launchArguments": app.launchArguments,
            "scope": "same-process original Search Data readiness around the final Settings Retry; no query, download, repair, Reader navigation or localization acceptance"
        ]
        if let previous {
            value["previousProcessID"] = previous.processID
            value["previousCapturedAtUnix"] = previous.capturedAtUnix
            value["previousApplicationHierarchySHA256"] = previous.hierarchySHA256
        }
        if let updatedDatabaseBytes { value["actualUpdatedDatabaseBytes"] = updatedDatabaseBytes }
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
                                       uniformTypeIdentifier: "public.json")
        attachment.name = stem
        attachment.lifetime = .keepAlways
        test.add(attachment)
    }

    func captureReadyBeforeFinalRetry() throws -> Observation {
        try admitOriginalSettingsLaunch()
        let before = try observedProcess("settings-update-warm-before-navigation")
        try openOriginalSearchData()
        let books = try ui.require("search-data-books-status")
        let otzaria = try ui.require("search-data-otzaria-status")
        let zayit = try ui.require("search-data-zayit-status")
        // These runtime status strings are the exact original Source values,
        // including in en_US; this test does not claim their localization.
        try ui.wait("Both actual installed v40 packages must be Ready in this process before the final update", timeout: 180) {
            books.label == "מוכן" && otzaria.label == "האינדקס מוכן (7925185 מסמכים)"
                && zayit.label == "מוכן · v40-20261123094345"
        }
        let actual = try observedProcess("settings-update-warm-ready")
        try requireSearchDataFixture(actual.id == before.id, "Opening original Search Data must not relaunch the app")
        let observation = Observation(sequenceID: UUID().uuidString, processID: actual.id,
            capturedAtUnix: Date().timeIntervalSince1970, hierarchySHA256: actual.hierarchySHA256,
            statuses: ["books": books.label, "otzaria": otzaria.label, "zayit": zayit.label])
        ui.capture("settings-update-warm-original-search-data-ready")
        try closeOriginalDataAndReturnToLibrary()
        try requireSearchDataFixture(try observedProcess("settings-update-warm-ready-return").id == observation.processID,
            "The final original Retry must start in the process that observed both Ready packages")
        try record(observation, previous: nil, updatedDatabaseBytes: nil)
        return observation
    }

    func captureMismatchAfterFinalRetry(previous: Observation, updatedDatabaseBytes: Int64) throws -> Observation {
        try admitOriginalSettingsLaunch()
        try requireSearchDataFixture(updatedDatabaseBytes > 0, "Use the actual updated database file size")
        let before = try observedProcess("settings-update-warm-after-success-before-navigation")
        try requireSearchDataFixture(before.id == previous.processID,
            "A cold relaunch cannot satisfy same-process update readiness")
        try openOriginalSearchData()
        let books = try ui.require("search-data-books-status")
        let otzaria = try ui.require("search-data-otzaria-status")
        let zayit = try ui.require("search-data-zayit-status")
        let mismatch = updatedDatabaseBytes == 4_355_063_808
            ? "the index was built for a different DB release" : "database size/identity mismatch"
        let otzariaMismatch = "נדרש תיקון לאינדקס: זהות האינדקס אינה תואמת למסד, למנוע או למשאבים הפעילים."
        let zayitMismatches: Set<String> = ["אין עדיין חבילה תואמת לגרסת מסד זו",
                                           "נדרש תיקון · The Zayit index is incompatible: " + mismatch]
        try ui.wait("The same process must revoke both old v40 readiness states after actual Settings success", timeout: 180) {
            books.label == "מוכן" && otzaria.label == otzariaMismatch && zayitMismatches.contains(zayit.label)
        }
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { books.label != "מוכן" || otzaria.label != otzariaMismatch
                || !zayitMismatches.contains(zayit.label) }
        }, object: nil)
        changed.isInverted = true
        try requireSearchDataFixture(XCTWaiter.wait(for: [changed], timeout: 3) == .completed,
            "The mismatch must remain settled instead of restoring stale Ready state")
        let actual = try observedProcess("settings-update-warm-mismatch")
        try requireSearchDataFixture(actual.id == previous.processID, "Only the original Ready process can satisfy the warm rejection")
        let observation = Observation(sequenceID: previous.sequenceID, processID: actual.id,
            capturedAtUnix: Date().timeIntervalSince1970, hierarchySHA256: actual.hierarchySHA256,
            statuses: ["books": books.label, "otzaria": otzaria.label, "zayit": zayit.label])
        try requireSearchDataFixture(observation.capturedAtUnix > previous.capturedAtUnix, "The mismatch must follow the actual Ready observation")
        ui.capture("settings-update-warm-original-search-data-mismatch")
        try closeOriginalDataAndReturnToLibrary()
        try requireSearchDataFixture(try observedProcess("settings-update-warm-mismatch-return").id == previous.processID,
            "Return to Library in the same original process before the separate cold final check")
        try record(observation, previous: previous, updatedDatabaseBytes: updatedDatabaseBytes)
        return observation
    }
}

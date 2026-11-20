
@MainActor
final class OtzariaFileLogger {
    static let shared = OtzariaFileLogger()
    var records: [String] = []
    func log(_ message: String) { records.append(message) }
}

enum OtzariaDataProfileRegistry {
    static let activeProfileID = "miniTest10" // Explicit registry boundary double.
}

@main
struct Groups100PerformanceFixture {
    @MainActor
    static func main() throws {
        var checks: [[String: Any]] = []
        func check(_ condition: Bool, _ name: String) {
            checks.append(["name": name, "passed": condition])
            print((condition ? "PASS " : "FAIL ") + name)
        }
        let namespace = UUID().uuidString
        let args = ["fixture", "-StudyGroupPerformanceEnabled", "YES"]
        let env = ["OTZARIA_DATA_PROFILE": "miniTest10"]
        func admission(_ arguments: [String] = args, _ environment: [String: String] = env,
                       _ profile: String = "miniTest10", _ enabled: Bool = true,
                       _ value: String? = namespace) -> String? {
            StudyGroupSwitchPerformanceObservation.admittedNamespace(
                arguments: arguments, environment: environment, activeProfile: profile,
                enabled: enabled, namespace: value)
        }
        check(admission() == namespace, "explicit-mini-uuid-admitted")
        check(admission([]) == nil, "missing-explicit-process-flag-refused")
        check(admission(args, env, "miniTest10", false) == nil, "disabled-default-refused")
        check(admission(args, [:]) == nil, "missing-fixture-environment-refused")
        check(admission(args, ["OTZARIA_DATA_PROFILE": "production"]) == nil, "production-environment-refused")
        check(admission(args, env, "production") == nil, "production-registry-refused")
        check(admission(args, env, "miniTest10", true, nil) == nil, "missing-namespace-refused")
        check(admission(args, env, "miniTest10", true, "../../live") == nil, "non-uuid-namespace-refused")

        let defaults = UserDefaults.standard
        defaults.setVolatileDomain([
            "StudyGroupPerformanceEnabled": false,
            "studyWorkspaceTestingNamespace": namespace
        ], forName: UserDefaults.argumentDomain)
        let groups = (0..<3).map { _ in UUID() }
        let documents = (0..<3).map { _ in UUID() }
        let denied = StudyGroupSwitchPerformanceObservation.begin(
            sceneID: "owned-scene", fromGroupID: groups[0], toGroupID: groups[1],
            fromDocumentID: documents[0], beforeRevision: 1, backend: "otzaria")
        check(denied == nil && OtzariaFileLogger.shared.records.isEmpty, "actual-disabled-begin-does-not-write")
        defaults.setVolatileDomain([
            "StudyGroupPerformanceEnabled": true,
            "studyWorkspaceTestingNamespace": namespace
        ], forName: UserDefaults.argumentDomain)
        func record(_ returnedNormally: Bool, _ index: Int) {
            guard let token = StudyGroupSwitchPerformanceObservation.begin(
                sceneID: "owned-scene", fromGroupID: groups[index % 3], toGroupID: groups[(index + 1) % 3],
                fromDocumentID: documents[index % 3], beforeRevision: UInt64(index * 2), backend: "otzaria")
            else { return }
            StudyGroupSwitchPerformanceObservation.finish(
                token, returnedNormally: returnedNormally, observedGroupID: groups[(index + 1) % 3],
                observedDocumentID: documents[(index + 1) % 3], afterRevision: UInt64(index * 2 + 1),
                backend: "otzaria")
        }
        record(false, 0)
        record(true, 1)
        let actual = try OtzariaFileLogger.shared.records.map { text in
            try JSONDecoder().decode(GroupStressApplicationMetric.self,
                from: Data(text.dropFirst(StudyGroupSwitchPerformanceObservation.prefix.count).utf8))
        }
        check(actual.count == 2 && !actual[0].returnedNormally && actual[1].returnedNormally,
              "actual-probe-distinguishes-throw-from-normal-return")
        check(actual.count == 2 && actual.allSatisfy {
            $0.namespace == namespace && $0.processID == ProcessInfo.processInfo.processIdentifier
                && $0.elapsedSeconds.isFinite && $0.elapsedSeconds >= 0
        }, "actual-process-clock-pid-namespace-preserved")
        #if os(Windows)
        check(actual.count == 2 && actual.allSatisfy {
            $0.footprintBeforeBytes == nil && $0.footprintAfterBytes == nil
        }, "original-windows-memory-unavailable-is-not-invented")
        #endif
        for index in 2..<512 { record(true, index) }
        let beforeCap = OtzariaFileLogger.shared.records.count
        record(true, 512)
        check(beforeCap == 512 && OtzariaFileLogger.shared.records.count == beforeCap,
              "diagnostic-cap-refuses-extra-token-and-log")
        defaults.removeVolatileDomain(forName: UserDefaults.argumentDomain)

        // The following are explicit fake metric records for the independent
        // reader's rejection controls. They are not measured memory/UI samples.
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("groups100-metric-reader-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("reader.log")
        let launch = UUID()
        var expected: [GroupStressMetricExpectation] = []
        var rows: [[String: Any]] = []
        for index in 0..<100 {
            let from = index % 3
            let to = (index + 1) % 3
            expected.append(.init(
                sceneID: "owned-scene", fromGroupID: groups[from], toGroupID: groups[to],
                fromDocumentID: documents[from], toDocumentID: documents[to],
                observedBeforeRevision: UInt64(index * 2), observedAfterRevision: UInt64(index * 2 + 2)))
            rows.append([
                "schema": 1,
                "timingScope": "original group operation through ordinary session persistence",
                "memoryMetric": "phys_footprint_bytes",
                "memoryScope": "operation boundary samples; not continuous peak RSS",
                "namespace": namespace, "operationID": UUID().uuidString, "launchID": launch.uuidString,
                "sequence": index + 10, "processID": 1234, "sceneID": "owned-scene",
                "fromGroupID": groups[from].uuidString, "toGroupID": groups[to].uuidString,
                "observedGroupID": groups[to].uuidString,
                "fromDocumentID": documents[from].uuidString, "observedDocumentID": documents[to].uuidString,
                "beforeRevision": index * 2 + 1, "afterRevision": index * 2 + 2,
                "fromBackend": "otzaria", "observedBackend": "otzaria",
                "footprintBeforeBytes": 50_000_000 + index, "footprintAfterBytes": 50_001_000 + index,
                "elapsedSeconds": 0.001 + Double(index) / 100_000, "returnedNormally": true
            ])
        }
        let reader = GroupStressMetricReader(url: url, namespace: namespace, expected: expected)
        func write(_ records: [[String: Any]]) throws {
            var lines = ["original unrelated reader log"]
            for record in records {
                let data = try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
                lines.append("2026-11-20T00:00:00Z [NativeGroupSwitchPerformance] " +
                             String(decoding: data, as: UTF8.self))
            }
            try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
        }
        func reject(_ name: String, _ records: [[String: Any]]) throws {
            try write(records)
            do { _ = try reader.matched(); check(false, name) }
            catch { check(true, name) }
        }
        func changed(_ field: String, _ value: Any?, index: Int = 50) -> [[String: Any]] {
            var valueRows = rows
            valueRows[index][field] = value
            return valueRows
        }
        try write(rows)
        check(try reader.matched().count == 100, "one-hundred-distinct-ui-bound-fixture-records-match")
        var foreign = rows[0]
        foreign["namespace"] = UUID().uuidString
        try write([foreign] + rows)
        check(try reader.matched().count == 100, "foreign-valid-namespace-not-counted")
        try reject("ninety-nine-records-refused", Array(rows.dropLast()))
        try reject("duplicate-record-refused", rows + [rows[50]])
        try reject("stale-scene-refused", changed("sceneID", "other-scene"))
        try reject("wrong-from-document-refused", changed("fromDocumentID", UUID().uuidString))
        try reject("wrong-observed-document-refused", changed("observedDocumentID", UUID().uuidString))
        try reject("wrong-observed-group-refused", changed("observedGroupID", UUID().uuidString))
        try reject("commit-before-observation-refused", changed("beforeRevision", 0))
        try reject("commit-after-observation-refused", changed("afterRevision", 999_999))
        try reject("failed-original-operation-refused", changed("returnedNormally", false))
        try reject("missing-memory-refused", changed("footprintAfterBytes", nil))
        try reject("zero-memory-refused", changed("footprintBeforeBytes", 0))
        try reject("negative-duration-refused", changed("elapsedSeconds", -1.0))
        try reject("mixed-processes-refused", changed("processID", 4321))
        try reject("mixed-launches-refused", changed("launchID", UUID().uuidString))
        try reject("reused-operation-token-refused", changed("operationID", rows[0]["operationID"]))
        try reject("nonconsecutive-sequence-refused", changed("sequence", 1000))
        try reject("rss-substitution-refused", changed("memoryMetric", "rss"))
        try reject("first-pixel-substitution-refused", changed("timingScope", "first pixel"))
        try reject("unknown-schema-refused", changed("schema", 2))
        try reject("wrong-backend-refused", changed("observedBackend", "sefaria"))
        try write(rows)
        try "broken [NativeGroupSwitchPerformance] {not-json}\n".append(to: url)
        do { _ = try reader.matched(); check(false, "malformed-record-refused") }
        catch { check(true, "malformed-record-refused") }
        let shortReader = GroupStressMetricReader(url: url, namespace: namespace, expected: Array(expected.dropLast()))
        try write(rows)
        do { _ = try shortReader.matched(); check(false, "partial-ui-expectation-set-refused") }
        catch { check(true, "partial-ui-expectation-set-refused") }
        let failed = checks.filter { $0["passed"] as? Bool != true }.count
        let report: [String: Any] = [
            "scope": "Actual DEBUG probe + original memory reader + exact Native metric reader. Registry/writer boundaries and 100 fake metric rows explicit. No UI/Apple/physical/performance acceptance.",
            "executed": checks.count, "passed": checks.count - failed, "failed": failed,
            "checks": checks
        ]
        print(String(decoding: try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]), as: UTF8.self))
        if failed > 0 { throw FixtureFailed() }
    }
    struct FixtureFailed: Error {}
}

private extension String {
    func append(to url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(utf8))
    }
}

import Foundation

// Test-only disposable property lists. These controls execute the complete
// production XCTest observation helpers, not Apple Simulator/UIKit behavior.
@MainActor
@main
struct NativeHistoryObservationAcceptance {
    static var failures = 0
    static var passed = 0
    static let query = "בדיקת היסטוריה 1167448C-76EA-4BB7-8A42-42E7DB7AFAB3"
    static let namespace = UUID().uuidString
    static let bundleID = "com.davidpovarsky.chavrusatext"

    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        func run(_ name: String, _ body: (URL) throws -> Bool) {
            let parent = root.appendingPathComponent(name)
            do {
                try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
                let result = try body(parent)
                if result { passed += 1 } else { failures += 1 }
                FileHandle.standardOutput.write(Data(("CASE " + name + " " + (result ? "PASS" : "FAIL") + "\n").utf8))
            } catch {
                failures += 1
                FileHandle.standardOutput.write(Data(("CASE " + name + " FAIL\n").utf8))
            }
        }
        run("missing_installation_is_not_persistence") { parent in
            let result = observeNativeGlobalHistory(in: parent, namespace: namespace, query: query)
            return result.container == nil && !result.persistedExactlyOnce
        }
        run("foreign_bundle_preferences_are_not_accepted") { parent in
            _ = try installation(parent, bundle: "com.example.other", history: [query])
            let result = observeNativeGlobalHistory(in: parent, namespace: namespace, query: query)
            return result.container == nil && !result.persistedExactlyOnce
        }
        run("unique_installation_must_be_pinned_before_success") { parent in
            _ = try installation(parent, history: [query])
            let result = observeNativeGlobalHistory(in: parent, namespace: namespace, query: query)
            return result.container != nil && result.metadataBytes != nil && !result.persistedExactlyOnce
        }
        run("exact_pinned_query_and_original_namespace_are_accepted") { parent in
            let (container, metadata) = try installation(parent, history: [query])
            try sidecar(container)
            let result = observeNativeGlobalHistory(in: parent, namespace: namespace, query: query,
                                                     expectedContainer: container, expectedMetadata: metadata)
            return result.persistedExactlyOnce && result.details["submittedQueryCount"] as? Int == 1
        }
        run("another_query_does_not_satisfy_uuid_query") { parent in
            let (container, metadata) = try installation(parent, history: ["אמר", "בראשית"])
            return !observeNativeGlobalHistory(in: parent, namespace: namespace, query: query,
                expectedContainer: container, expectedMetadata: metadata).persistedExactlyOnce
        }
        run("duplicate_query_is_not_exact_once") { parent in
            let (container, metadata) = try installation(parent, history: [query, query])
            let result = observeNativeGlobalHistory(in: parent, namespace: namespace, query: query,
                expectedContainer: container, expectedMetadata: metadata)
            return !result.persistedExactlyOnce && result.details["submittedQueryCount"] as? Int == 2
        }
        run("two_original_metadata_candidates_fail_closed") { parent in
            let (container, metadata) = try installation(parent, history: [query])
            _ = try installation(parent, history: [query])
            let result = observeNativeGlobalHistory(in: parent, namespace: namespace, query: query,
                expectedContainer: container, expectedMetadata: metadata)
            return result.container == nil && !result.persistedExactlyOnce
        }
        run("same_path_with_changed_metadata_is_rejected") { parent in
            let (container, metadata) = try installation(parent, history: [query])
            var replacement = metadata
            replacement.append(contentsOf: [10, 32, 10])
            try replacement.write(to: container.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist"))
            return !observeNativeGlobalHistory(in: parent, namespace: namespace, query: query,
                expectedContainer: container, expectedMetadata: metadata).persistedExactlyOnce
        }
        run("foreign_namespace_sidecar_cannot_confirm_installation") { parent in
            let (container, metadata) = try installation(parent, history: [query])
            let (foreign, _) = try installation(parent, bundle: "com.example.other", history: [query])
            try sidecar(foreign)
            let result = observeNativeGlobalHistory(in: parent, namespace: namespace, query: query,
                expectedContainer: container, expectedMetadata: metadata)
            return result.container == nil && !result.persistedExactlyOnce
        }
        run("delayed_test_writer_requires_actual_bytes_without_sidecar") { parent in
            let (container, metadata) = try installation(parent, history: nil)
            let before = observeNativeGlobalHistory(in: parent, namespace: namespace, query: query,
                expectedContainer: container, expectedMetadata: metadata)
            try preferences(container, history: [query], recording: false)
            let after = observeNativeGlobalHistory(in: parent, namespace: namespace, query: query,
                expectedContainer: container, expectedMetadata: metadata)
            return !before.persistedExactlyOnce && after.persistedExactlyOnce &&
                after.details["recordSearchHistory"] as? Bool == false &&
                after.details["namespaceSidecarCount"] as? Int == 0
        }
        run("oversized_preferences_fail_closed") { parent in
            let (container, metadata) = try installation(parent, history: [query])
            try plist(["SearchHistory": [query], "padding": String(repeating: "x", count: 1024 * 1024)],
                      to: container.appendingPathComponent("Library/Preferences/" + bundleID + ".plist"))
            let result = observeNativeGlobalHistory(in: parent, namespace: namespace, query: query,
                expectedContainer: container, expectedMetadata: metadata)
            return !result.persistedExactlyOnce && result.details["preferenceReadable"] as? Bool == false
        }
        run("observation_leaves_owned_files_byte_identical") { parent in
            let (container, metadata) = try installation(parent, history: [query])
            try sidecar(container)
            let before = try allFileBytes(parent)
            for _ in 0..<5 {
                guard observeNativeGlobalHistory(in: parent, namespace: namespace, query: query,
                    expectedContainer: container, expectedMetadata: metadata).persistedExactlyOnce else { return false }
            }
            return try before == allFileBytes(parent)
        }
        print("SUMMARY passed=" + String(passed) + " failed=" + String(failures) + " native=0")
        // The Python driver seals every named result and returns failure when any control fails.
    }

    static func plist(_ value: [String: Any], to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try PropertyListSerialization.data(fromPropertyList: value, format: .xml, options: 0).write(to: url)
    }
    static func installation(_ parent: URL, bundle: String = "com.davidpovarsky.chavrusatext", history: [String]?) throws -> (URL, Data) {
        let container = parent.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        let path = container.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")
        try plist(["MCMMetadataIdentifier": bundle, "MCMMetadataUUID": container.lastPathComponent], to: path)
        if let history { try preferences(container, history: history) }
        return (container, try Data(contentsOf: path))
    }
    static func preferences(_ container: URL, history: [String], recording: Bool = true) throws {
        try plist(["SearchHistory": history, "recordSearchHistory": recording],
                  to: container.appendingPathComponent("Library/Preferences/" + bundleID + ".plist"))
    }
    static func sidecar(_ container: URL) throws {
        let path = container.appendingPathComponent("Library/Application Support/ChavrusaText/StudyWorkspace/UITests/" + namespace + ".json")
        try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: path)
    }
    static func allFileBytes(_ root: URL) throws -> [String: Data] {
        let paths = (FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey])?.allObjects as? [URL]) ?? []
        var result: [String: Data] = [:]
        for path in paths where (try path.resourceValues(forKeys: [.isRegularFileKey])).isRegularFile == true {
            result[path.path] = try Data(contentsOf: path)
        }
        return result
    }
}

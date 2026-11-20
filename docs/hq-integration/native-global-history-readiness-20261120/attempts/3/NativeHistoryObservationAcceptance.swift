import Foundation

private func matchingTestSidecars(in containers: URL, namespace: String) -> [URL] {
    guard UUID(uuidString: namespace) != nil,
          let candidates = try? FileManager.default.contentsOfDirectory(at: containers, includingPropertiesForKeys: nil) else { return [] }
    return candidates.map {
        $0.appendingPathComponent("Library/Application Support/ChavrusaText/StudyWorkspace/UITests/\(namespace).json")
    }.filter { FileManager.default.fileExists(atPath: $0.path) }
}



/// Read-only evidence from this Simulator installation. The runner's pre-install
/// container UUID is only a parent hint: XCTest may reinstall the app.
private struct NativeGlobalHistoryObservation {
    let container: URL?
    let metadataBytes: Data?
    let persistedExactlyOnce: Bool
    let details: [String: Any]
}

private func observeNativeGlobalHistory(
    in parent: URL, namespace: String, query: String,
    expectedContainer: URL? = nil, expectedMetadata: Data? = nil
) -> NativeGlobalHistoryObservation {
    let bundleID = "com.davidpovarsky.chavrusatext"
    func boundedRegularFile(_ url: URL, maximum: Int) -> Data? {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
              values.isRegularFile == true, values.isSymbolicLink == false,
              let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        do {
            var bytes = Data()
            while bytes.count <= maximum {
                guard let chunk = try handle.read(upToCount: min(65536, maximum + 1 - bytes.count)),
                      !chunk.isEmpty else { return bytes }
                bytes.append(chunk)
            }
        } catch { return nil }
        return nil
    }
    func dictionary(_ bytes: Data) -> [String: Any]? {
        (try? PropertyListSerialization.propertyList(from: bytes, format: nil)) as? [String: Any]
    }
    let root = parent.standardizedFileURL
    let children = (try? FileManager.default.contentsOfDirectory(
        at: root, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
        options: [.skipsHiddenFiles])) ?? []
    let candidates: [(URL, Data)] = children.compactMap { child in
        let container = child.standardizedFileURL
        guard UUID(uuidString: container.lastPathComponent) != nil,
              container.deletingLastPathComponent() == root,
              let values = try? container.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
              values.isDirectory == true, values.isSymbolicLink == false,
              let metadata = boundedRegularFile(
                container.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist"),
                maximum: 65536),
              dictionary(metadata)?["MCMMetadataIdentifier"] as? String == bundleID else { return nil }
        return (container, metadata)
    }
    var details: [String: Any] = [
        "metadataBundleIdentifier": bundleID,
        "matchingInstallationCount": candidates.count,
        "candidateContainerIDs": candidates.map { $0.0.lastPathComponent },
        "queryPersistedExactlyOnce": false
    ]
    guard candidates.count == 1, let (container, metadata) = candidates.first else {
        details["observationError"] = "missing_or_ambiguous_original_installation"
        return .init(container: nil, metadataBytes: nil, persistedExactlyOnce: false, details: details)
    }
    // Feature-off deliberately has no workspace sidecar. If the existing UUID
    // sidecar is present, it must corroborate this same original installation.
    let sidecars = matchingTestSidecars(in: root, namespace: namespace)
    let namespaceMatches = sidecars.isEmpty || (sidecars.count == 1 &&
        sidecars[0].standardizedFileURL.pathComponents.starts(with: container.pathComponents))
    let pinned = expectedContainer != nil && expectedMetadata != nil
    let installationMatches = pinned &&
        expectedContainer?.standardizedFileURL == container && expectedMetadata == metadata
    details["containerID"] = container.lastPathComponent
    details["metadataByteCount"] = metadata.count
    details["namespaceSidecarCount"] = sidecars.count
    details["namespaceMatchesInstallation"] = namespaceMatches
    details["installationPinned"] = pinned
    details["installationMatchesInitialBytes"] = installationMatches
    let preference = container.appendingPathComponent("Library/Preferences/" + bundleID + ".plist")
    let preferences = boundedRegularFile(preference, maximum: 1024 * 1024).flatMap(dictionary)
    let history = preferences?["SearchHistory"] as? [String] ?? []
    let count = history.filter { $0 == query }.count
    details["preferenceReadable"] = preferences != nil
    details["historyCount"] = history.count
    details["submittedQueryCount"] = count
    if let preferences {
        details["recordSearchHistory"] = preferences["recordSearchHistory"] as? Bool ?? true
    }
    let persisted = installationMatches && namespaceMatches && preferences != nil && count == 1
    details["queryPersistedExactlyOnce"] = persisted
    if !namespaceMatches { details["observationError"] = "namespace_installation_mismatch" }
    else if pinned && !installationMatches { details["observationError"] = "original_installation_changed" }
    else if preferences == nil { details["observationError"] = "original_preferences_unreadable" }
    return .init(container: namespaceMatches ? container : nil,
                 metadataBytes: namespaceMatches ? metadata : nil,
                 persistedExactlyOnce: persisted, details: details)
}


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
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true).appendingPathComponent(String(UUID().uuidString.prefix(8)), isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        func run(_ name: String, _ body: (URL) throws -> Bool) {
            let parent = root.appendingPathComponent(String(passed + failures), isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
                let result = try body(parent)
                if result { passed += 1 } else { failures += 1 }
                FileHandle.standardOutput.write(Data(("CASE " + name + " " + (result ? "PASS" : "FAIL") + "\n").utf8))
            } catch {
                failures += 1
                FileHandle.standardOutput.write(Data(("CASE " + name + " FAIL\nSETUP_OR_IO_ERROR " + String(describing: error) + "\n").utf8))
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

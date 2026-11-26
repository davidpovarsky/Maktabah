
let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("otzaria-history-" + UUID().uuidString)
try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: temporary) }
let container = temporary.appendingPathComponent(UUID().uuidString)
let prefs = container.appendingPathComponent("Library/Preferences/com.davidpovarsky.chavrusatext.plist")
try FileManager.default.createDirectory(at: prefs.deletingLastPathComponent(), withIntermediateDirectories: true)
let metadata = try PropertyListSerialization.data(fromPropertyList: ["MCMMetadataIdentifier": "com.davidpovarsky.chavrusatext"], format: .binary, options: 0)
try metadata.write(to: container.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist"))
let namespace = UUID().uuidString
let query = "בדיקת היסטוריה " + UUID().uuidString
var failures = 0
@MainActor private func check(_ label: String, _ valid: Bool) {
    print("\(valid ? "PASS" : "FAIL") \(label)")
    if !valid { failures += 1 }
}
@MainActor private func observe() -> NativeGlobalHistoryObservation {
    observeNativeGlobalHistory(in: temporary, namespace: namespace, query: query,
        expectedContainer: container, expectedMetadata: metadata)
}
@MainActor private func writePreferences(_ queries: [String], extra: Int = 0) throws -> Data {
    let data = try PropertyListSerialization.data(fromPropertyList: [
        "SearchHistory": queries, "qualifiedLocatorReverse.v1": Data(repeating: 65, count: extra)
    ], format: .binary, options: 0)
    try data.write(to: prefs, options: .atomic)
    return data
}
let small = try writePreferences([query])
check("small exact persisted history", observe().persistedExactlyOnce)
let large = try writePreferences([query], extra: 2 * 1024 * 1024)
private let largeObservation = observe()
check("valid preferences above former 1 MiB cap", largeObservation.persistedExactlyOnce)
check("original preference bytes unchanged", try Data(contentsOf: prefs) == large)
check("captured actual preference byte count", (largeObservation.details["preferenceFileRead"] as? [String: Any])?["bytesRead"] as? Int == large.count)
_ = try writePreferences([query, query])
check("duplicate query rejected", !observe().persistedExactlyOnce)
_ = try writePreferences([])
check("missing submitted query rejected", !observe().persistedExactlyOnce)
_ = try writePreferences([query])
private let changed = observeNativeGlobalHistory(in: temporary, namespace: namespace, query: query,
    expectedContainer: container, expectedMetadata: metadata + Data([0]))
check("changed installation metadata rejected", !changed.persistedExactlyOnce)
let other = temporary.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
try metadata.write(to: other.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist"))
check("ambiguous original installation rejected", !observe().persistedExactlyOnce)
try FileManager.default.removeItem(at: other)
try Data("not a property list".utf8).write(to: prefs, options: .atomic)
check("malformed preferences rejected", !observe().persistedExactlyOnce)
try FileManager.default.removeItem(at: prefs)
check("missing preferences rejected", !observe().persistedExactlyOnce)
let alias = temporary.appendingPathComponent("alias.plist")
try small.write(to: alias)
try FileManager.default.createSymbolicLink(at: prefs, withDestinationURL: alias)
check("symlink preferences rejected", !observe().persistedExactlyOnce)
try FileManager.default.removeItem(at: prefs)
_ = try writePreferences([query], extra: 8 * 1024 * 1024)
private let oversized = observe()
check("new finite budget enforced", !oversized.persistedExactlyOnce
    && (oversized.details["preferenceFileRead"] as? [String: Any])?["reason"] as? String == "oversize")
check("bounded reader rejects directory", observeNativeGlobalHistoryFile(container, maximum: 1024).data == nil)
print("RESULT failures=\(failures)")
exit(failures == 0 ? 0 : 1)

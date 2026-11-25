import Foundation

private enum Failure: Error { case failed(String) }
private func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw Failure.failed(message) }
}
private func refuses(_ body: () throws -> Void) throws {
    var refused = false
    do { try body() } catch { refused = true }
    try require(refused, "Unverified update was accepted")
}
private func changed<T: Codable>(_ value: T, _ mutate: (inout [String: Any]) -> Void) throws -> T {
    var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as! [String: Any]
    mutate(&object)
    return try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: object))
}

@main
private struct LibraryUpdateControls {
    static func main() throws {
        let fixtures = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let output = URL(fileURLWithPath: CommandLine.arguments[2])
        let v32 = try OtzariaLibraryReleaseClient.parseLatestRelease(
            data: Data(contentsOf: fixtures.appendingPathComponent("official-v32-release.json"))
        )
        let v40 = try OtzariaLibraryReleaseClient.parseLatestRelease(
            data: Data(contentsOf: fixtures.appendingPathComponent("official-v40-release.json")),
            multipartManifestData: Data(contentsOf: fixtures.appendingPathComponent("official-v40-manifest.json"))
        )
        let installed32 = OtzariaDatabaseInstallationManifest(release: v32, databaseFileSize: 3_821_240_320)
        let installed40 = OtzariaDatabaseInstallationManifest(release: v40, databaseFileSize: 4_000_000_000)
        var rows: [[String: String]] = []
        func run(_ name: String, _ body: () throws -> Void) {
            do { try body(); rows.append(["name": name, "status": "PASS"]); print("PASS " + name) }
            catch { rows.append(["name": name, "status": "FAIL", "error": String(describing: error)]); print("FAIL " + name + ": " + String(describing: error)) }
        }
        run("official_v32_to_v40_full_snapshot_available") {
            try require(try OtzariaLibraryUpdatePolicy.isNewer(v40, than: installed32), "Official newer snapshot was hidden")
        }
        run("identical_installed_snapshot_is_current") {
            try require(try !OtzariaLibraryUpdatePolicy.isNewer(v40, than: installed40), "Identical snapshot was offered again")
        }
        run("older_release_does_not_downgrade") {
            try require(try !OtzariaLibraryUpdatePolicy.isNewer(v32, than: installed40), "Older library was offered")
        }
        run("republished_installed_id_with_changed_digest_refused") {
            let altered: OtzariaDatabaseInstallationManifest = try changed(installed40) { $0["digest"] = "sha256:" + String(repeating: "0", count: 64) }
            try refuses { _ = try OtzariaLibraryUpdatePolicy.isNewer(v40, than: altered) }
        }
        run("foreign_provider_installation_refused") {
            let altered: OtzariaDatabaseInstallationManifest = try changed(installed32) { $0["repository"] = "Foreign/Library" }
            try refuses { _ = try OtzariaLibraryUpdatePolicy.isNewer(v40, than: altered) }
        }
        run("nonproduction_profile_refused") {
            let altered: OtzariaDatabaseInstallationManifest = try changed(installed32) { $0["profileID"] = "controlled-fixture" }
            try refuses { _ = try OtzariaLibraryUpdatePolicy.isNewer(v40, than: altered) }
        }
        run("unsupported_profile_version_refused") {
            let altered: OtzariaDatabaseInstallationManifest = try changed(installed32) { $0["profileVersion"] = 999 }
            try refuses { _ = try OtzariaLibraryUpdatePolicy.isNewer(v40, than: altered) }
        }
        run("foreign_sql_archive_identity_refused") {
            let altered: OtzariaDatabaseInstallationManifest = try changed(installed32) { $0["assetName"] = "book_update.sql" }
            try refuses { _ = try OtzariaLibraryUpdatePolicy.isNewer(v40, than: altered) }
        }
        run("untrusted_direct_download_host_refused") {
            let altered: OtzariaLibraryRelease = try changed(v32) {
                var asset = $0["asset"] as! [String: Any]
                asset["downloadURL"] = "https://example.invalid/seforim.db.zst"
                $0["asset"] = asset
            }
            try refuses { try OtzariaLibraryUpdatePolicy.validateRelease(altered) }
        }
        run("missing_archive_digest_refused") {
            let altered: OtzariaLibraryRelease = try changed(v32) {
                var asset = $0["asset"] as! [String: Any]
                asset.removeValue(forKey: "digest")
                $0["asset"] = asset
            }
            try refuses { try OtzariaLibraryUpdatePolicy.validateRelease(altered) }
        }
        run("malformed_version_tags_refused") {
            for tag in ["v040-20261123094345", "v40", "v-20261123094345", "v40-../arbitrary", "40-20261123094345"] {
                try require(OtzariaLibraryUpdatePolicy.version(in: tag) == nil, "Malformed tag accepted")
            }
        }
        run("multipart_aggregate_size_change_refused") {
            let altered: OtzariaLibraryRelease = try changed(v40) {
                var multipart = $0["multipart"] as! [String: Any]
                multipart["compressedSize"] = 17
                $0["multipart"] = multipart
            }
            try refuses { try OtzariaLibraryUpdatePolicy.validateRelease(altered) }
        }
        run("same_version_different_release_is_not_upgrade") {
            let altered: OtzariaLibraryRelease = try changed(v40) { $0["id"] = v40.id + 1 }
            try require(try !OtzariaLibraryUpdatePolicy.isNewer(altered, than: installed40), "Same content version was offered as upgrade")
        }
        run("official_monolithic_archive_remains_supported") {
            try OtzariaLibraryUpdatePolicy.validateRelease(v32)
            try OtzariaLibraryUpdatePolicy.validateInstalled(installed32)
        }
        run("original_installer_iso8601_manifest_roundtrip") {
            let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
            let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
            let restored = try decoder.decode(OtzariaDatabaseInstallationManifest.self, from: encoder.encode(installed32))
            try require(try OtzariaLibraryUpdatePolicy.isNewer(v40, than: restored), "Original manifest format could not be checked")
        }
        let failed = rows.filter { $0["status"] == "FAIL" }.count
        let report: [String: Any] = [
            "status": failed == 0 ? "APPLE_UPDATE_POLICY_PASS" : "APPLE_UPDATE_POLICY_FAIL",
            "counts": ["PASS": rows.count - failed, "FAIL": failed, "SKIP": 0],
            "cases": rows,
            "scope": "Original official metadata and real Swift update policy; no archive or database mutation",
            "native_app_update_acceptance": false,
            "fixture_database_size_v40_is_controlled": true
        ]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: output)
        if failed != 0 { exit(1) }
    }
}

import Foundation

@main
struct PinnedProductionReleaseControls {
    static func require(_ value: Bool, _ message: String) {
        if !value { fatalError(message) }
    }
    static func main() throws {
        let latest = OtzariaLibraryReleaseClient.latestReleaseURL
        var checks = 0
        func check(_ value: Bool, _ message: String) {
            require(value, message)
            checks += 1
        }
        let selected = [
            "OTZARIA_NATIVE_BOOTSTRAP_ACCEPTANCE": "install",
            "OTZARIA_NATIVE_BOOTSTRAP_RELEASE_ID": "409213893",
            "OTZARIA_DATA_PROFILE": "production"
        ]
        let normal = try OtzariaLibraryReleaseClient.releaseLookup(environment: [:])
        check(normal.url == latest && normal.expectedReleaseID == nil, "normal lookup changed")
        var ordinary = selected
        ordinary.removeValue(forKey: "OTZARIA_NATIVE_BOOTSTRAP_ACCEPTANCE")
        let noOptIn = try OtzariaLibraryReleaseClient.releaseLookup(environment: ordinary)
        check(noOptIn.url == latest && noOptIn.expectedReleaseID == nil, "ordinary launch honored native pin")
        var cancel = selected
        cancel["OTZARIA_NATIVE_BOOTSTRAP_ACCEPTANCE"] = "cancel"
        let otherPhase = try OtzariaLibraryReleaseClient.releaseLookup(environment: cancel)
        check(otherPhase.url == latest && otherPhase.expectedReleaseID == nil, "unselected phase changed")
        let frozen = try OtzariaLibraryReleaseClient.releaseLookup(environment: selected)
        #if DEBUG
        check(frozen.url.absoluteString == "https://api.github.com/repos/Otzaria/SeforimLibrary/releases/409213893"
              && frozen.expectedReleaseID == 409213893, "frozen official URL or identity mismatch")
        for raw in ["", "0", "-1", "+409213893", "0409213893", " 409213893",
                    "409213893/../latest", "9223372036854775808"] {
            var invalid = selected
            invalid["OTZARIA_NATIVE_BOOTSTRAP_RELEASE_ID"] = raw
            do {
                _ = try OtzariaLibraryReleaseClient.releaseLookup(environment: invalid)
                fatalError("invalid native ID accepted")
            } catch OtzariaDatabaseBootstrapError.invalidAssetMetadata {
                checks += 1
            }
        }
        var mini = selected
        mini["OTZARIA_DATA_PROFILE"] = "miniTest10"
        do {
            _ = try OtzariaLibraryReleaseClient.releaseLookup(environment: mini)
            fatalError("mini profile accepted production pin")
        } catch OtzariaDatabaseBootstrapError.invalidAssetMetadata {
            checks += 1
        }
        #else
        check(frozen.url == latest && frozen.expectedReleaseID == nil, "release build honored a native pin")
        #endif
        let bytes = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
        let official = try OtzariaLibraryReleaseClient.parseLatestRelease(data: bytes, expectedReleaseID: 409213893)
        check(official.id == 409213893 && official.tag == "v32-20261010190601", "authentic release identity changed")
        check(official.asset.id == 629048655 && official.asset.name == "seforim-schema6.db.zst"
              && official.asset.compressedSize == 1850679582, "authentic asset identity changed")
        check(official.expectedSHA256 == "6661911ac0a0d68b8b8bf931fabf7df3934ae0a82fc573d3d5eec999514f0c44",
              "authentic compressed digest changed")
        do {
            _ = try OtzariaLibraryReleaseClient.parseLatestRelease(data: bytes, expectedReleaseID: 455390662)
            fatalError("wrong returned official release accepted")
        } catch OtzariaDatabaseBootstrapError.invalidAssetMetadata {
            checks += 1
        }
        let value: [String: Any] = ["status": "ACTUAL_SOURCE_COMPONENT_CONTROLS_PASS",
            "checks": checks, "apple_app_or_native_install_acceptance": false]
        let encoded = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
        print(String(decoding: encoded, as: UTF8.self))
    }
}

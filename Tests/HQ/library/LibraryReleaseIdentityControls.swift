import Foundation
import Darwin

@main
enum LibraryReleaseIdentityControls {
    static func main() async throws {
        let releaseID = "455390662"
        let phaseKey = "OTZARIA_NATIVE_BOOTSTRAP_ACCEPTANCE"
        let idKey = "OTZARIA_NATIVE_BOOTSTRAP_RELEASE_ID"
        let profileKey = "OTZARIA_DATA_PROFILE"
        #if DEBUG
        let debug = true
        #else
        let debug = false
        #endif
        var cases: [(String, [String: String], Bool, Bool)] = []
        for phase in ["cancel", "install", "restore"] {
            cases.append(("\(phase)-same-official-release", [phaseKey: phase, idKey: releaseID, profileKey: "production"], debug, false))
            cases.append(("\(phase)-reject-noncanonical-id", [phaseKey: phase, idKey: "0455390662", profileKey: "production"], false, debug))
            cases.append(("\(phase)-reject-other-profile", [phaseKey: phase, idKey: releaseID, profileKey: "miniTest10"], false, debug))
            cases.append(("\(phase)-without-selection-keeps-latest", [phaseKey: phase, profileKey: "production"], false, false))
        }
        cases.append(("ordinary-launch-keeps-latest", [idKey: releaseID, profileKey: "production"], false, false))
        cases.append(("unknown-phase-keeps-latest", [phaseKey: "unknown", idKey: releaseID, profileKey: "production"], false, false))
        cases.append(("dictionary-phase-keeps-latest", [phaseKey: "dictionary", idKey: releaseID, profileKey: "production"], false, false))
        var results: [[String: Any]] = []
        for (name, environment, pinned, shouldThrow) in cases {
            do {
                let result = try OtzariaLibraryReleaseClient.releaseLookup(environment: environment)
                let expectedURL = pinned
                    ? "https://api.github.com/repos/Otzaria/SeforimLibrary/releases/\(releaseID)"
                    : OtzariaLibraryReleaseClient.latestReleaseURL.absoluteString
                let passed = !shouldThrow && result.url.absoluteString == expectedURL
                    && result.expectedReleaseID == (pinned ? Int64(releaseID) : nil)
                results.append(["case": name, "passed": passed, "url": result.url.absoluteString])
            } catch {
                results.append(["case": name, "passed": shouldThrow, "errorType": String(describing: type(of: error))])
            }
        }
        var report: [String: Any] = ["configuration": debug ? "Debug" : "Release", "cases": results,
                                    "passed": results.filter { $0["passed"] as? Bool == true }.count,
                                    "failed": results.filter { $0["passed"] as? Bool != true }.count,
                                    "scope": "Exact original release-client and data-profile sources; no application UI executed"]
        if CommandLine.arguments.contains("--live-v40") {
            let release = try await OtzariaLibraryReleaseClient().fetchLatestRelease()
            guard debug, release.id == 455390662, release.tag == "v40-20261123094345",
                  release.asset.id == 782942035, release.asset.compressedSize == 589,
                  release.compressedSize == 2_129_902_636, release.multipart?.parts.count == 2,
                  release.expectedSHA256 == "39a2b52129323ea53ac3629835c4721e25acff010a8fc971bf076a666a3b9587" else {
                throw OtzariaDatabaseBootstrapError.invalidAssetMetadata("Live release identity differs from qualified v40")
            }
            report["live_public_release"] = ["id": release.id, "tag": release.tag, "manifestAssetID": release.asset.id,
                                            "archiveBytes": release.compressedSize, "sha256": release.expectedSHA256 ?? ""]
        }
        print(String(decoding: try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys, .prettyPrinted]), as: UTF8.self))
        exit((report["failed"] as? Int == 0) ? 0 : 1)
    }
}

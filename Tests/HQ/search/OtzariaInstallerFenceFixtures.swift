import Foundation

// Explicit failure-injection boundaries; every installer method and file move is original.
enum FixtureWorld {
    nonisolated(unsafe) static var root = URL(fileURLWithPath: "unused")
    nonisolated(unsafe) static var profile = "admitted"
    nonisolated(unsafe) static var fingerprint = 1
    nonisolated(unsafe) static var scenario = ""
    nonisolated(unsafe) static var downloads = 0
    nonisolated(unsafe) static var extractions = 0
    nonisolated(unsafe) static var opened: Set<UUID> = []
    nonisolated(unsafe) static var closed: Set<UUID> = []
    nonisolated(unsafe) static var documentCount: UInt64 = 0
}
enum OtzariaDataProfileRegistry {
    static let productionID = "production"
    static var activeProfileID: String { FixtureWorld.profile }
}
struct OtzariaSearchArtifactStorage: Sendable {
    func stagingURL(databasePath: String) -> URL {
        OtzariaSearchIndexManager.shared.indexURL(for: databasePath).appendingPathExtension("installing")
    }
}
final class OtzariaSearchIndexManager: Sendable {
    static let shared = OtzariaSearchIndexManager()
    func indexURL(for path: String) -> URL { FixtureWorld.root.appendingPathComponent(FixtureWorld.profile) }
    func previousIndexURL(for path: String) -> URL { indexURL(for: path).appendingPathExtension("previous") }
    func currentFingerprint(databasePath: String) throws -> Int { FixtureWorld.fingerprint }
    func writeIdentity(_ identity: OtzariaIndexBuildIdentity, indexURL: URL) throws {
        try JSONEncoder().encode(identity).write(to: indexURL.appendingPathComponent("fixture_identity.json"))
    }
}
struct OtzariaIndexBuildIdentity: Codable {
    let database: Int
    let upstreamCommit: String
    let engineVersion: String
    let indexSchemaVersion: Int
    let defaultGenerationOrder: Int
    let adapterVersion: String
    let resourceHashes: [String: String]
    let catalogueHash: String
    let semanticArtifactIdentity: String?
}
struct FixtureBuild {
    let upstreamCommit = "EXPLICIT-ENGINE-DOUBLE"
    let engineVersion = "fixture"
    let indexSchemaVersion = 1
    let defaultGenerationOrder = 1
    let adapterVersion = "fixture"
    let resourceHashes: [String:String] = [:]
}
struct FixtureCompatibility { let compatible = true; let reason: String? = nil; let status = "fixture" }
enum FixtureError: Error { case injectedDocumentCount }
final class OtzariaSearchEngineBridge {
    let id = UUID()
    let indexURL: URL
    init(indexURL: URL) throws { self.indexURL = indexURL; FixtureWorld.opened.insert(id) }
    static func buildInfo() throws -> FixtureBuild { FixtureBuild() }
    static func checkCompatibility(indexURL: URL) throws -> FixtureCompatibility { FixtureCompatibility() }
    func documentCount() throws -> UInt64 {
        if FixtureWorld.scenario == "staging-count", indexURL.pathExtension == "installing" {
            throw FixtureError.injectedDocumentCount
        }
        if FixtureWorld.scenario == "promotion-count", indexURL.pathExtension != "installing" {
            throw FixtureError.injectedDocumentCount
        }
        return FixtureWorld.documentCount
    }
    func close() { FixtureWorld.closed.insert(id) }
}
struct OtzariaZstdStreamExtractor: Sendable {
    func extractPart(archiveURL: URL, outputURL: URL, expectedOffset: Int64,
                     expectedOutputBytes: Int64, progress: (Int64, Int64) -> Void) throws {
        // No compressed data or real index is claimed by this control-path fixture.
        FixtureWorld.extractions += 1
        try Data("EXPLICIT-EXTRACTION-DOUBLE".utf8).write(to: outputURL)
        progress(1, 1)
    }
}
enum OtzariaStorageErrorNormalizer { static func failure(for error: Error) -> Int? { nil } }
enum OtzariaIndexFileLogger {
    static func log(_ value: String) {}
    static func logError(_ value: String, error: Error) {}
}
struct OtzariaTantivySearchRepository: Sendable {
    static let shared = Self()
    func invalidate(databasePath: String) {}
}
enum FixtureTransfer {
    static func download(_ part: OtzariaSearchArtifactManifest.Part) async throws -> URL {
        FixtureWorld.downloads += 1
        let path = FixtureWorld.root.appendingPathComponent("part-\(FixtureWorld.downloads)")
        try Data("EXPLICIT-DOWNLOAD-DOUBLE".utf8).write(to: path)
        await Task.yield()
        if FixtureWorld.downloads == 1 {
            switch FixtureWorld.scenario {
            case "profile": FixtureWorld.profile = "other"
            case "fingerprint": FixtureWorld.fingerprint = 2
            case "cancellation": withUnsafeCurrentTask { $0?.cancel() }
            default: break
            }
        }
        return path
    }
}
@main struct InstallerAcceptance {
    @MainActor static func main() async throws {
        let base = URL(fileURLWithPath: CommandLine.arguments[1])
        let manifest = try JSONDecoder().decode(OtzariaSearchArtifactManifest.self,
            from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])))
        let artifact = OtzariaResolvedSearchArtifact(releaseID: 410332048,
            releaseTag: "otzaria-miniTest10-v6", manifest: manifest, partURLs: [:])
        var results: [[String:String]] = []
        func check(_ name: String, _ valid: Bool) {
            results.append(["name": name, "status": valid ? "PASS" : "FAIL"])
            print("\(valid ? "PASS" : "FAIL") \(name)")
        }
        func marker(_ profile: String) -> Data? {
            try? Data(contentsOf: FixtureWorld.root.appendingPathComponent(profile).appendingPathComponent("prior.marker"))
        }
        for scenario in ["profile", "fingerprint", "cancellation", "staging-count", "promotion-count", "success"] {
            FixtureWorld.root = base.appendingPathComponent(scenario)
            FixtureWorld.profile = "admitted"; FixtureWorld.fingerprint = 1
            FixtureWorld.scenario = scenario; FixtureWorld.downloads = 0; FixtureWorld.extractions = 0
            FixtureWorld.opened = []; FixtureWorld.closed = []; FixtureWorld.documentCount = manifest.lexicalArtifact.documentCount
            for profile in ["admitted", "other"] {
                let url = FixtureWorld.root.appendingPathComponent(profile)
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                try Data("prior-\(profile)".utf8).write(to: url.appendingPathComponent("prior.marker"))
            }
            // Cancellation is confined to this child task, leaving subsequent cases live.
            let outcome = await Task { () -> String in
                do { return "success:\(try await FixtureInvocation.install(artifact))" }
                catch { return "failure:\(error)" }
            }.value
            if ["profile", "fingerprint", "cancellation"].contains(scenario) {
                check("\(scenario): rejected before any extraction", outcome.hasPrefix("failure:") && FixtureWorld.extractions == 0)
                check("\(scenario): admitted prior bytes preserved", marker("admitted") == Data("prior-admitted".utf8))
            } else if scenario != "success" {
                check("\(scenario): injected count error is surfaced", outcome.hasPrefix("failure:"))
                check("\(scenario): every opened engine is closed", !FixtureWorld.opened.isEmpty && FixtureWorld.opened == FixtureWorld.closed)
                check("\(scenario): admitted prior bytes restored", marker("admitted") == Data("prior-admitted".utf8))
            } else {
                check("success: validated count returned", outcome == "success:\(manifest.lexicalArtifact.documentCount)")
                check("success: trusted manifest atomically promoted", FileManager.default.fileExists(atPath:
                    FixtureWorld.root.appendingPathComponent("admitted/otzaria_prebuilt_installation.json").path) && marker("admitted") == nil)
                check("success: both validation handles closed", FixtureWorld.opened.count == 2 && FixtureWorld.opened == FixtureWorld.closed)
            }
            check("\(scenario): unrelated profile bytes preserved", marker("other") == Data("prior-other".utf8))
            check("\(scenario): admitted staging removed", !FileManager.default.fileExists(atPath:
                FixtureWorld.root.appendingPathComponent("admitted.installing").path))
        }
        let passed = results.filter { $0["status"] == "PASS" }.count
        let report: [String:Any] = ["cases": results, "passed": passed, "failed": results.count-passed, "total": results.count,
            "real_file_moves": true, "real_search_engine": false, "real_extraction": false, "native_ui_executed": 0]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: base.appendingPathComponent("RESULT.json"))
        if passed != results.count { exit(1) }
    }
}

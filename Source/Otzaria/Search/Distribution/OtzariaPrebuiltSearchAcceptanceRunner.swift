import Foundation
import SQLite3

enum OtzariaPrebuiltSearchAcceptanceRunner {
    private struct Check: Codable {
        let mode: String
        let query: String
        let count: UInt32
        let firstFilePath: String?
    }

    private struct Report: Codable {
        let passed: Bool
        let phase: String
        let artifactIdentity: String
        let documentCount: UInt64
        let sourceCount: Int
        let checks: [Check]
        let localIndexingRan: Bool
        let stagingAbsent: Bool
        let error: String?
    }

    @MainActor
    static func run(environment: [String: String]) async {
        guard let manifestPath = environment["OTZARIA_PREBUILT_ACCEPTANCE_MANIFEST"],
              let partsPath = environment["OTZARIA_PREBUILT_ACCEPTANCE_PARTS"],
              let databasePath = environment["OTZARIA_PREBUILT_ACCEPTANCE_DATABASE"],
              let resultPath = environment["OTZARIA_PREBUILT_ACCEPTANCE_RESULT"] else { return }
        let phase = environment["OTZARIA_PREBUILT_ACCEPTANCE_PHASE"] ?? "install"
        var identity = "unknown"
        do {
            let manifest = try JSONDecoder().decode(
                OtzariaSearchArtifactManifest.self,
                from: Data(contentsOf: URL(fileURLWithPath: manifestPath))
            )
            identity = manifest.artifactIdentity
            let resolved = OtzariaResolvedSearchArtifact(
                releaseID: 0,
                releaseTag: "acceptance",
                manifest: manifest,
                partURLs: [:]
            )
            let parts = Dictionary(uniqueKeysWithValues: manifest.lexicalArtifact.parts.map {
                ($0.assetName, URL(fileURLWithPath: partsPath).appendingPathComponent($0.assetName))
            })
            let storage = try OtzariaSearchArtifactStorage()
            if phase == "install" {
                _ = try await Task.detached(priority: .utility) {
                    try OtzariaSearchArtifactInstaller().install(
                        artifact: resolved,
                        downloadedParts: parts,
                        databasePath: databasePath,
                        storage: storage,
                        progress: { _, _ in }
                    )
                }.value
            }
            let manager = OtzariaSearchIndexManager.shared
            let finalURL = manager.indexURL(for: databasePath)
            let engine = try OtzariaSearchEngineBridge(indexURL: finalURL)
            defer { engine.close() }
            let documentCount = try engine.documentCount()
            let paths = try engine.indexedFilePaths()
            guard documentCount == manifest.lexicalArtifact.documentCount,
                  paths.count == manifest.lexicalArtifact.sourceCount else {
                throw OtzariaSearchArtifactError.validationFailed("portable count mismatch")
            }
            let query = try sampleQuery(databasePath: databasePath)
            var checks: [Check] = []
            for mode in [OtzariaSearchMode.exact, .fuzzy, .advanced] {
                let page = try engine.search(OtzariaSearchRequest(
                    query: query,
                    mode: mode,
                    facets: ["/"],
                    limit: 10
                ))
                guard page.totalCount > 0,
                      page.results.first?.filePath.hasPrefix("otzaria-book:") == true,
                      page.results.first?.text.isEmpty == false else {
                    throw OtzariaSearchArtifactError.validationFailed("\(mode.rawValue) search failed")
                }
                checks.append(Check(
                    mode: mode.rawValue,
                    query: query,
                    count: page.totalCount,
                    firstFilePath: page.results.first?.filePath
                ))
            }
            let stagingAbsent = !FileManager.default.fileExists(
                atPath: storage.stagingURL(databasePath: databasePath).path
            )
            let localIndexingRan = FileManager.default.fileExists(
                atPath: manager.sentinelURL(for: databasePath).path
            ) || FileManager.default.fileExists(
                atPath: manager.buildingIndexURL(for: databasePath).path
            )
            guard stagingAbsent, !localIndexingRan else {
                throw OtzariaSearchArtifactError.validationFailed("local build/staging evidence exists")
            }
            try write(Report(
                passed: true,
                phase: phase,
                artifactIdentity: identity,
                documentCount: documentCount,
                sourceCount: paths.count,
                checks: checks,
                localIndexingRan: false,
                stagingAbsent: true,
                error: nil
            ), path: resultPath)
        } catch {
            try? write(Report(
                passed: false,
                phase: phase,
                artifactIdentity: identity,
                documentCount: 0,
                sourceCount: 0,
                checks: [],
                localIndexingRan: false,
                stagingAbsent: false,
                error: error.localizedDescription
            ), path: resultPath)
        }
    }

    private static func sampleQuery(databasePath: String) throws -> String {
        let database = try SQLiteDatabase(
            path: databasePath,
            flags: SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        )
        let lines = try database.fetch(
            query: "SELECT COALESCE(content, '') FROM line WHERE length(content) > 12 ORDER BY bookId, lineIndex LIMIT 100"
        ) { $0.string(at: 0) ?? "" }
        for line in lines {
            if let word = try OtzariaSearchEngineBridge.splitQueryWords(line).first(where: { $0.count >= 4 }) {
                return word
            }
        }
        throw OtzariaSearchArtifactError.validationFailed("no acceptance query")
    }

    private static func write<T: Encodable>(_ value: T, path: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(value).write(to: URL(fileURLWithPath: path), options: .atomic)
    }
}

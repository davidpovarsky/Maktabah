import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@main
enum SefariaNativeSmoke {
    static func main() async throws {
        guard CommandLine.arguments.contains("--run-network-smoke") else {
            print("Network smoke skipped; pass --run-network-smoke to opt in.")
            return
        }
        let config = SefariaNetworkConfiguration.production
        let client = SefariaHTTPClient()
        let catalog = try await client.get([SefariaTOCEntryDTO].self,
            url: config.apiURL(path: "/api/index"))
        guard !catalog.isEmpty else { throw LibraryBackendError.invalidResponse("empty catalog") }

        let textURL = try config.apiURL(pathPrefix: "/api/v3/texts/", pathComponent: "Genesis 1",
            queryItems: [URLQueryItem(name: "version", value: "primary")])
        let text = try await client.get(SefariaTextsV3DTO.self, url: textURL)
        guard !text.versions.isEmpty else { throw LibraryBackendError.invalidResponse("empty Texts v3 response") }

        let search = try await client.post(SefariaSearchResponseDTO.self,
            url: config.apiURL(path: "/api/search-wrapper"),
            body: SefariaSearchBody(query: "בראשית", start: 0, size: 1))
        guard search.hits.total.value > 0 else { throw LibraryBackendError.invalidResponse("empty search") }

        let root = SefariaExportContract.rootPath(schema: SefariaExportContract.currentSchema)
        let packages = try await client.get([SefariaPackageManifestEntry].self,
            url: config.readonlyURL(path: "\(root)/packages.json"))
        guard let package = packages.filter({ !$0.package.isCompleteLibrary }).min(by: { $0.size < $1.size }) else {
            throw LibraryBackendError.invalidResponse("no export package")
        }
        let bundlePaths = try await client.get([String].self,
            url: config.readonlyURL(path: "/packageData", queryItems: [
                URLQueryItem(name: "package", value: package.en),
                URLQueryItem(name: "schema_version", value: SefariaExportContract.currentSchema)
            ]))
        guard let bundlePath = bundlePaths.first else {
            throw LibraryBackendError.invalidResponse("package has no bundle")
        }
        let bundleURL: URL
        if let absolute = URL(string: bundlePath), absolute.scheme != nil {
            bundleURL = absolute
        } else {
            bundleURL = try config.readonlyURL(path: bundlePath)
        }
        let (temporary, _) = try await client.download(url: bundleURL)
        let workspace = FileManager.default.temporaryDirectory.appendingPathComponent("sefaria-smoke-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workspace) }
        let outer = workspace.appendingPathComponent("bundle.zip")
        try FileManager.default.moveItem(at: temporary, to: outer)
        try run("/usr/bin/ditto", ["-x", "-k", outer.path, workspace.path])
        guard let walker = FileManager.default.enumerator(at: workspace, includingPropertiesForKeys: nil) else {
            throw LibraryBackendError.corruptData("cannot enumerate outer bundle")
        }
        guard let bookZip = walker.compactMap({ $0 as? URL })
            .first(where: { $0.pathExtension.lowercased() == "zip" && $0 != outer }) else {
            throw LibraryBackendError.corruptData("outer bundle has no book ZIP")
        }
        let book = workspace.appendingPathComponent("book", isDirectory: true)
        try FileManager.default.createDirectory(at: book, withIntermediateDirectories: true)
        try run("/usr/bin/ditto", ["-x", "-k", bookZip.path, book.path])
        let files = try FileManager.default.contentsOfDirectory(at: book, includingPropertiesForKeys: nil)
        guard let metadataURL = files.first(where: { $0.lastPathComponent.hasSuffix(".metadata.json") }),
              let indexURL = files.first(where: { $0.lastPathComponent.hasSuffix("_index.json") }) else {
            throw LibraryBackendError.corruptData("book ZIP lacks metadata/index")
        }
        _ = try JSONDecoder().decode(SefariaOfflineMetadataDTO.self, from: Data(contentsOf: metadataURL))
        _ = try JSONDecoder().decode(SefariaOfflineIndexDTO.self, from: Data(contentsOf: indexURL))
        print("Sefaria network smoke passed using package \(package.en)")
    }

    private static func run(_ executable: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw LibraryBackendError.corruptData("archive extraction failed")
        }
    }
}

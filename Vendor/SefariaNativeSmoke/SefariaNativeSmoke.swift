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
        var contractFailures: [String] = []
        let catalog = try await client.get([SefariaTOCEntryDTO].self,
            url: config.apiURL(path: "/api/index"))
        guard !catalog.isEmpty else { throw LibraryBackendError.invalidResponse("empty catalog") }

        let textURL = try config.apiURL(pathPrefix: "/api/v3/texts/", pathComponent: "Genesis 1",
            queryItems: [
                URLQueryItem(name: "version", value: "source"),
                URLQueryItem(name: "version", value: "translation"),
                URLQueryItem(name: "fill_in_missing_segments", value: "1"),
                URLQueryItem(name: "return_format", value: "text_only")
            ])
        let text = try await client.get(SefariaTextsV3DTO.self, url: textURL)
        let section = SefariaSection(ref: text.ref, heRef: text.heRef, sectionRef: text.sectionRef,
            indexTitle: text.indexTitle, next: text.next, prev: text.prev, versions: text.versions,
            linksBySegment: [], origin: .remote).asLibrarySection()
        guard section.segments.count == 31,
              section.segments.first?.locator.position == .canonicalRef("Genesis 1:1"),
              section.segments.last?.locator.position == .canonicalRef("Genesis 1:31"),
              section.segments.contains(where: { $0.translation?.isEmpty == false }) else {
            throw LibraryBackendError.invalidResponse("source/translation segment contract changed")
        }

        let complexIndex = try await client.get(SefariaIndexDTO.self,
            url: config.apiURL(pathPrefix: "/api/v2/raw/index/", pathComponent: "Pesach Haggadah"))
        let complexShapes = try await client.get([SefariaShapeDTO].self,
            url: config.apiURL(pathPrefix: "/api/shape/", pathComponent: "Pesach Haggadah"))
        let complexNodes = SefariaNavigationParser.nodes(shapes: complexShapes, schema: complexIndex.schema,
            alternateStructures: complexIndex.alternateStructures, indexTitle: complexIndex.title)
        guard !complexNodes.isEmpty else {
            throw LibraryBackendError.invalidResponse("empty complex navigation")
        }
        let ref = try await client.get(SefariaJSONValue.self,
            url: config.apiURL(pathPrefix: "/api/ref/", pathComponent: "Berakhot 31a"))
        guard case .object(let refObject) = ref,
              case .object(let navigationRefs)? = refObject["navigation_refs"],
              navigationRefs["prev_section_ref"] == .string("Berakhot 30b"),
              navigationRefs["next_section_ref"] == .string("Berakhot 31b"),
              navigationRefs["first_subref"] == .string("Berakhot 31a:1"),
              navigationRefs["last_subref"] == .string("Berakhot 31a:28") else {
            throw LibraryBackendError.invalidResponse("Ref navigation metadata missing")
        }

        do {
            let search = try await client.post(SefariaSearchResponseDTO.self,
                url: config.apiURL(path: "/api/search-wrapper"),
                body: SefariaSearchBody(query: "בראשית", start: 0, size: 1))
            guard search.hits.total.value > 0 else {
                throw LibraryBackendError.invalidResponse("empty search")
            }
        } catch {
            contractFailures.append("search-wrapper: \(error.localizedDescription)")
            print("Sefaria search live contract FAILED: \(error.localizedDescription)")
        }

        let root = SefariaExportContract.rootPath(schema: SefariaExportContract.currentSchema)
        let packages = try await client.get([SefariaPackageManifestEntry].self,
            url: config.readonlyURL(path: "\(root)/packages.json"))
        guard let complete = packages.first(where: { $0.package.isCompleteLibrary }) else {
            throw LibraryBackendError.invalidResponse("complete-library export package missing")
        }
        let completeBundlePaths = try await client.get([String].self,
            url: config.readonlyURL(path: "/packageData", queryItems: [
                URLQueryItem(name: "package", value: complete.en),
                URLQueryItem(name: "schema_version", value: SefariaExportContract.currentSchema)
            ]))
        guard !completeBundlePaths.isEmpty else {
            throw LibraryBackendError.invalidResponse("complete-library package has no bundles")
        }
        print("Complete Library manifest path verified: \(completeBundlePaths.count) bundles, \(complete.size) compressed bytes; full download intentionally requires matching disk/bandwidth budget")

        guard let package = packages.filter({ !$0.package.isCompleteLibrary }).min(by: { $0.size < $1.size }) else {
            throw LibraryBackendError.invalidResponse("no export package")
        }
        let bundlePaths = try await client.get([String].self,
            url: config.readonlyURL(path: "/packageData", queryItems: [
                URLQueryItem(name: "package", value: package.en),
                URLQueryItem(name: "schema_version", value: SefariaExportContract.currentSchema)
            ]))
        guard !bundlePaths.isEmpty else {
            throw LibraryBackendError.invalidResponse("package has no bundle")
        }
        let workspace = FileManager.default.temporaryDirectory.appendingPathComponent("sefaria-smoke-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workspace) }

        for (index, bundlePath) in bundlePaths.enumerated() {
            let bundleURL: URL
            if let absolute = URL(string: bundlePath), absolute.scheme != nil {
                bundleURL = absolute
            } else {
                bundleURL = try config.readonlyURL(path: bundlePath)
            }
            let (temporary, _) = try await client.download(url: bundleURL)
            let outer = workspace.appendingPathComponent("bundle-\(index).zip")
            try FileManager.default.moveItem(at: temporary, to: outer)
            let payload = workspace.appendingPathComponent("payload-\(index)", isDirectory: true)
            try FileManager.default.createDirectory(at: payload, withIntermediateDirectories: true)
            try run("/usr/bin/ditto", ["-x", "-k", outer.path, payload.path])
        }
        guard let walker = FileManager.default.enumerator(at: workspace, includingPropertiesForKeys: nil) else {
            throw LibraryBackendError.corruptData("cannot enumerate installed bundles")
        }
        guard let bookZip = walker.compactMap({ $0 as? URL })
            .first(where: { $0.pathExtension.lowercased() == "zip" && !$0.lastPathComponent.hasPrefix("bundle-") }) else {
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
        let metadata = try JSONDecoder().decode(SefariaOfflineMetadataDTO.self, from: Data(contentsOf: metadataURL))
        guard !metadata.flattenedSections.isEmpty else {
            throw LibraryBackendError.corruptData("metadata has no readable flat or nested sections")
        }
        _ = try JSONDecoder().decode(SefariaOfflineIndexDTO.self, from: Data(contentsOf: indexURL))
        print("Sefaria network smoke passed using all \(bundlePaths.count) bundle(s) from package \(package.en)")
        if !contractFailures.isEmpty {
            throw LibraryBackendError.invalidResponse(contractFailures.joined(separator: "; "))
        }
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

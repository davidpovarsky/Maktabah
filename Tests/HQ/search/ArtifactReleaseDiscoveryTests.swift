import Foundation

private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw NSError(domain: "ArtifactReleaseDiscovery", code: 1,
                                   userInfo: [NSLocalizedDescriptionKey: message]) }
}

private final class ManifestURLProtocol: URLProtocol, @unchecked Sendable {
    final class State: @unchecked Sendable {
        private let lock = NSLock()
        private var payloads: [String: Data] = [:]
        private var requests: [String] = []

        func reset(_ payloads: [String: Data]) {
            lock.lock()
            defer { lock.unlock() }
            self.payloads = payloads
            requests = []
        }

        func load(_ url: String) -> Data? {
            lock.lock()
            defer { lock.unlock() }
            requests.append(url)
            return payloads[url]
        }

        func observedRequests() -> [String] {
            lock.lock()
            defer { lock.unlock() }
            return requests
        }
    }

    static let state = State()
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "artifact-acceptance.invalid"
    }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url else { return }
        let data = Self.state.load(url.absoluteString)
        let response = HTTPURLResponse(url: url, statusCode: data == nil ? 404 : 200,
                                       httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if let data { client?.urlProtocol(self, didLoad: data) }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@main
struct ArtifactReleaseDiscoveryTests {
    static func main() async throws {
        let original = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
        let manifest = try JSONDecoder().decode(OtzariaSearchArtifactManifest.self, from: original)
        let source = manifest.sourceDatabase
        let engine = manifest.lexicalEngine
        let database = OtzariaDatabaseInstallationManifest(
            release: .init(id: source.releaseID, tag: source.releaseTag,
                           asset: .init(id: source.assetID, name: source.assetName,
                                        downloadURL: URL(string: "https://artifact-acceptance.invalid/database")!,
                                        compressedSize: source.compressedBytes,
                                        digest: source.sourceAssetDigest, updatedAt: nil)),
            databaseFileSize: source.databaseBytes)
        let build = OtzariaSearchEngineBuildInfo(
            upstreamRepository: engine.repository, upstreamBranch: "refactor",
            upstreamCommit: engine.commit, engineVersion: engine.engineVersion,
            indexSchemaVersion: engine.indexSchemaVersion,
            defaultGenerationOrder: engine.defaultGenerationOrder, semanticEnabled: true,
            semanticSidecarRevision: engine.semanticSidecarRevision, syncedAt: "test-fixture",
            adapterVersion: engine.adapterVersion, resourceHashes: manifest.resources.mapValues(\.sha256))
        let firstTag = "otzaria-search-data-incompatible-newer"
        let expectedTag = "otzaria-search-data-\(source.releaseTag)-\(manifest.artifactIdentity.prefix(12))"
        let firstBase = "https://artifact-acceptance.invalid/\(firstTag)"
        let expectedBase = "https://artifact-acceptance.invalid/\(expectedTag)"
        let firstURL = firstBase + "/otzaria-search-manifest.json"
        let expectedURL = expectedBase + "/otzaria-search-manifest.json"
        // Deliberately use identical part names across the two different releases.
        // The transport must load each URL's bytes, never substitute the pinned manifest.
        func release(_ id: Int, _ tag: String, _ base: String) -> [String: Any] {
            let names = ["otzaria-search-manifest.json"] + manifest.lexicalArtifact.parts.map(\.assetName)
            return ["id": id, "tag_name": tag, "draft": false,
                    "assets": names.map { ["name": $0, "browser_download_url": base + "/" + $0] }]
        }
        let releases = try JSONSerialization.data(withJSONObject: [
            release(2, firstTag, firstBase), release(1, expectedTag, expectedBase)
        ])
        var incompatible = try JSONSerialization.jsonObject(with: original) as! [String: Any]
        var incompatibleSource = incompatible["sourceDatabase"] as! [String: Any]
        incompatibleSource["releaseTag"] = "different-database-version"
        incompatibleSource["releaseID"] = source.releaseID + 1
        incompatible["sourceDatabase"] = incompatibleSource
        let newerBytes = try JSONSerialization.data(withJSONObject: incompatible)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ManifestURLProtocol.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        let client = OtzariaSearchArtifactReleaseClient(session: session)

        for (label, firstBytes) in [
            ("different-database", Optional(newerBytes)),
            ("malformed-manifest", Optional(Data("{}".utf8))),
            ("HTTP-404", Optional<Data>.none)
        ] {
            var responses = [expectedURL: original]
            responses[firstURL] = firstBytes
            ManifestURLProtocol.state.reset(responses)
            let result = try await client.matchingArtifact(
                releasesData: releases, database: database,
                databaseBytes: source.databaseBytes, build: build)
            try require(result.releaseTag == expectedTag && result.manifest == manifest,
                        "\(label): selected a release with another URL's manifest")
            try require(ManifestURLProtocol.state.observedRequests() == [firstURL, expectedURL],
                        "\(label): did not request both candidate manifest URLs in order")
            try require(result.partURLs.allSatisfy { $0.value.absoluteString == expectedBase + "/" + $0.key },
                        "\(label): part URLs came from another release")
            print("PASS \(label): authentic per-URL transport, original compatibility, exact release and parts")
        }

        ManifestURLProtocol.state.reset([firstURL: newerBytes, expectedURL: newerBytes])
        do {
            _ = try await client.matchingArtifact(releasesData: releases, database: database,
                                                 databaseBytes: source.databaseBytes, build: build)
            throw NSError(domain: "ArtifactReleaseDiscovery", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "incompatible releases were accepted"])
        } catch let error as OtzariaSearchArtifactError {
            try require(error == .unavailable, "all incompatible candidates must remain unavailable")
        }
        try require(ManifestURLProtocol.state.observedRequests() == [firstURL, expectedURL],
                    "failed discovery did not examine each manifest URL")
        print("PASS all-incompatible: original discovery fails closed")
        print("4 transport regression scenarios PASS; synthetic HTTP fixtures, not Native/UI acceptance")
    }
}

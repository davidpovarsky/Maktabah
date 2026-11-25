import CryptoKit
import Foundation

private enum ControlFailure: Error { case failed(String) }
private func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw ControlFailure.failed(message) }
}
private func sha(_ bytes: Data) -> String {
    SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
}
private func encodeJSON(_ value: Any) throws -> Data {
    try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
}

private struct ControlledReply: Sendable {
    let data: Data
    var status: Int = 200
    var headers: [String: String] = [:]
    var hold: Bool = false
}
private struct RecordedRequest: Sendable {
    let url: String
    let range: String?
    let validator: String?
}
private final class ControlledTransport: @unchecked Sendable {
    typealias Route = @Sendable (URLRequest, Int) -> ControlledReply
    static let shared = ControlledTransport()
    private let lock = NSLock()
    private var routes: [String: Route] = [:]
    private var records: [RecordedRequest] = []
    private var stops: [String] = []
    private var onStop: (@Sendable (String) -> Void)?

    func configure(_ value: [String: Route], onStop: (@Sendable (String) -> Void)? = nil) {
        lock.lock(); defer { lock.unlock() }
        routes = value; records = []; stops = []; self.onStop = onStop
    }
    func response(_ request: URLRequest) -> ControlledReply? {
        lock.lock(); defer { lock.unlock() }
        let url = request.url!.absoluteString
        let ordinal = records.filter { $0.url == url }.count
        records.append(.init(url: url, range: request.value(forHTTPHeaderField: "Range"),
                             validator: request.value(forHTTPHeaderField: "If-Range")))
        return routes[url]?(request, ordinal)
    }
    func stopped(_ url: String) {
        lock.lock(); stops.append(url); let callback = onStop; lock.unlock()
        callback?(url)
    }
    func requests() -> [RecordedRequest] {
        lock.lock(); defer { lock.unlock() }; return records
    }
    func stopCount() -> Int {
        lock.lock(); defer { lock.unlock() }; return stops.count
    }
}

private final class ControlledURLProtocol: URLProtocol, @unchecked Sendable {
    private let stopLock = NSLock()
    private var stopped = false

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let reply = ControlledTransport.shared.response(request),
              let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: reply.status,
                                             httpVersion: "HTTP/1.1", headerFields: reply.headers) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        stopLock.lock(); let active = !stopped; stopLock.unlock()
        guard active else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if !reply.data.isEmpty { client?.urlProtocol(self, didLoad: reply.data) }
        if !reply.hold { client?.urlProtocolDidFinishLoading(self) }
    }

    override func stopLoading() {
        stopLock.lock(); stopped = true; stopLock.unlock()
        ControlledTransport.shared.stopped(request.url?.absoluteString ?? "")
    }
}

private func configuration() -> URLSessionConfiguration {
    let result = URLSessionConfiguration.ephemeral
    result.protocolClasses = [ControlledURLProtocol.self]
    return result
}

private func route(
    _ data: Data, behavior: String = "normal", prefix: Int = 512
) -> ControlledTransport.Route {
    { request, ordinal in
        let requested = request.value(forHTTPHeaderField: "Range")
            .flatMap { Int($0.dropFirst("bytes=".count).dropLast()) } ?? 0
        let ignore = behavior == "ignore-range" && ordinal == 0
        let offset = ignore ? 0 : requested
        var bytes = Data(data.dropFirst(offset))
        let status = offset > 0 ? 206 : 200
        var headers = ["ETag": "\"controlled-v1\"", "Content-Length": String(bytes.count)]
        if status == 206 {
            let start = behavior == "wrong-range" && ordinal == 0 ? offset + 1 : offset
            headers["Content-Range"] = "bytes \(start)-\(data.count - 1)/\(data.count)"
        }
        if behavior == "changed-etag", ordinal == 0 { headers["ETag"] = "\"controlled-v2\"" }
        if behavior == "corrupt", !bytes.isEmpty { bytes[bytes.startIndex] ^= 1 }
        if behavior == "oversize" { bytes.append(0) }
        let hold = behavior == "hold" && ordinal == 0
        if hold { bytes = Data(bytes.prefix(prefix)) }
        return ControlledReply(data: bytes, status: status, headers: headers, hold: hold)
    }
}

private func requireOwnedStop(_ stream: AsyncStream<Void>) async throws {
    let reached = await withTaskGroup(of: Bool.self) { group in
        group.addTask {
            var iterator = stream.makeAsyncIterator()
            return await iterator.next() != nil
        }
        group.addTask {
            do { try await Task.sleep(nanoseconds: 5_000_000_000) } catch { return false }
            return false
        }
        let first = await group.next() ?? false
        group.cancelAll()
        return first
    }
    try require(reached, "current owned manifest task was not cancelled within 5 seconds")
}

private struct ControlledArchive: Sendable {
    let payload: Data
    let manifest: Data
    let release: OtzariaLibraryRelease
    let parts: [Data]

    var joined: Data { parts.reduce(into: Data()) { $0.append($1) } }

    static func make(
        _ tag: String, parts: [Data] = [Data(repeating: 0x31, count: 4096),
                                      Data(repeating: 0x72, count: 1536)],
        archiveDigest: String? = nil
    ) throws -> ControlledArchive {
        let archive = "seforim-schema7.db.zst"
        let joined = parts.reduce(into: Data()) { $0.append($1) }
        let entries: [[String: Any]] = parts.enumerated().map { index, bytes in
            ["name": archive + String(format: ".part-%03d", index),
             "size": bytes.count, "sha256": sha(bytes)]
        }
        let manifest = try encodeJSON([
            "schemaVersion": 1, "archive": archive, "size": joined.count,
            "sha256": archiveDigest ?? sha(joined),
            "partSizeLimit": parts[0].count, "githubAssetLimit": 2_147_483_648,
            "parts": entries
        ])
        func asset(_ id: Int, _ name: String, _ bytes: Data) -> [String: Any] {
            ["id": id, "name": name, "size": bytes.count, "digest": "sha256:" + sha(bytes),
             "browser_download_url": "https://github.com/Otzaria/SeforimLibrary/releases/download/\(tag)/\(name)"]
        }
        var assets = [asset(900001, archive + ".manifest.json", manifest)]
        assets += parts.enumerated().map { index, bytes in
            asset(900002 + index, archive + String(format: ".part-%03d", index), bytes)
        }
        let payload = try encodeJSON(["id": 900000, "tag_name": tag, "assets": assets])
        let release = try OtzariaLibraryReleaseClient.parseLatestRelease(
            data: payload, multipartManifestData: manifest
        )
        return .init(payload: payload, manifest: manifest, release: release, parts: parts)
    }

    func routes(secondBehavior: String = "normal") -> [String: ControlledTransport.Route] {
        var result: [String: ControlledTransport.Route] = [:]
        for (index, asset) in release.multipart!.parts.enumerated() {
            result[asset.downloadURL.absoluteString] = route(parts[index], behavior: index == 1 ? secondBehavior : "normal")
        }
        return result
    }
}

private func rejectedParser(_ payload: Data, _ manifest: Data?) throws {
    do {
        _ = try OtzariaLibraryReleaseClient.parseLatestRelease(data: payload, multipartManifestData: manifest)
    } catch is OtzariaDatabaseBootstrapError { return }
    throw ControlFailure.failed("invalid metadata was accepted")
}
private func modifiedFixture(
    _ fixture: ControlledArchive,
    changeManifest: ((inout [String: Any]) -> Void)? = nil,
    changeRelease: ((inout [String: Any]) -> Void)? = nil
) throws -> (Data, Data) {
    var payload = try JSONSerialization.jsonObject(with: fixture.payload) as! [String: Any]
    var manifest = try JSONSerialization.jsonObject(with: fixture.manifest) as! [String: Any]
    if let changeManifest { changeManifest(&manifest) }
    let bytes = try encodeJSON(manifest)
    var assets = payload["assets"] as! [[String: Any]]
    assets[0]["size"] = bytes.count
    assets[0]["digest"] = "sha256:" + sha(bytes)
    payload["assets"] = assets
    if let changeRelease { changeRelease(&payload) }
    return (try encodeJSON(payload), bytes)
}
private func partWorkspace(_ root: URL, _ index: Int) -> URL {
    root.appendingPathComponent(OtzariaDatabaseDownloader.multipartDirectoryName)
        .appendingPathComponent(String(format: "part-%03d", index))
}
private func seed(_ root: URL, fixture: ControlledArchive, secondPrefix: Int) throws {
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try OtzariaDatabaseDownloader.writeMetadata(
        .init(release: fixture.release, downloadedBytes: 1),
        to: root.appendingPathComponent(OtzariaDatabaseDownloader.sidecarFileName)
    )
    for index in 0..<fixture.parts.count {
        let directory = partWorkspace(root, index)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let count = index == 0 ? fixture.parts[index].count : secondPrefix
        let bytes = Data(fixture.parts[index].prefix(count))
        try bytes.write(to: directory.appendingPathComponent(OtzariaDatabaseDownloader.partFileName))
        let release = OtzariaLibraryRelease(id: fixture.release.id, tag: fixture.release.tag,
                                           asset: fixture.release.multipart!.parts[index])
        var metadata = OtzariaDownloadResumeMetadata(release: release, downloadedBytes: Int64(count))
        metadata.etag = "\"controlled-v1\""
        try OtzariaDatabaseDownloader.writeMetadata(
            metadata, to: directory.appendingPathComponent(OtzariaDatabaseDownloader.sidecarFileName)
        )
    }
}

@MainActor
private final class ControlSuite {
    let root: URL
    var rows: [[String: String]] = []
    init(root: URL) { self.root = root }

    func run(_ name: String, _ body: @MainActor () async throws -> Void) async {
        do {
            try await body()
            rows.append(["name": name, "status": "PASS"])
            print("PASS " + name)
        } catch {
            rows.append(["name": name, "status": "FAIL", "error": String(describing: error)])
            print("FAIL " + name + ": " + String(describing: error))
        }
        fflush(stdout)
    }
    func workspace(_ name: String) throws -> URL {
        let path = root.appendingPathComponent(name, isDirectory: true)
        try require(!FileManager.default.fileExists(atPath: path.path), "owned fixture must start absent")
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        return path
    }
}

@main
private struct MultipartArchiveControls {
    @MainActor static func main() async throws {
        let fixtures = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        let suite = ControlSuite(root: output)
        let fixture = try ControlledArchive.make("controlled-parts")
        let realPayload = try Data(contentsOf: fixtures.appendingPathComponent("official-v40-release.json"))
        let realManifest = try Data(contentsOf: fixtures.appendingPathComponent("official-v40-manifest.json"))

        await suite.run("official_v40_manifest_and_two_same_release_parts") {
            let release = try OtzariaLibraryReleaseClient.parseLatestRelease(
                data: realPayload, expectedReleaseID: 455390662, multipartManifestData: realManifest
            )
            try require(release.asset.id == 782942035 && release.asset.name.hasSuffix(".manifest.json")
                        && release.asset.compressedSize == 589, "real manifest identity must stay exact")
            try require(release.archiveName == "seforim-schema7.db.zst"
                        && release.compressedSize == 2_129_902_636, "real archive metadata differs")
            try require(release.expectedSHA256 == "39a2b52129323ea53ac3629835c4721e25acff010a8fc971bf076a666a3b9587",
                        "real whole-archive hash differs")
            try require(release.multipart!.parts.map(\.id) == [782942221, 782993890], "real part order/IDs differ")
        }
        await suite.run("official_v32_monolithic_identity_preserved") {
            let data = try Data(contentsOf: fixtures.appendingPathComponent("official-v32-release.json"))
            let release = try OtzariaLibraryReleaseClient.parseLatestRelease(data: data, expectedReleaseID: 409213893)
            try require(release.multipart == nil && release.asset.id == 629048655
                        && release.archiveName == "seforim-schema6.db.zst"
                        && release.compressedSize == 1_850_679_582, "v32 original selection changed")
            try require(release.expectedSHA256 == "6661911ac0a0d68b8b8bf931fabf7df3934ae0a82fc573d3d5eec999514f0c44",
                        "v32 original digest changed")
        }
        await suite.run("frozen_release_id_mismatch_refused") {
            do {
                _ = try OtzariaLibraryReleaseClient.parseLatestRelease(
                    data: realPayload, expectedReleaseID: 409213893, multipartManifestData: realManifest
                )
            } catch is OtzariaDatabaseBootstrapError { return }
            throw ControlFailure.failed("explicit v32 lookup accepted v40")
        }
        await suite.run("manifest_missing_bytes_refused") {
            try rejectedParser(fixture.payload, nil)
        }
        await suite.run("manifest_content_digest_mismatch_refused") {
            var bytes = fixture.manifest; bytes[bytes.startIndex] ^= 1
            try rejectedParser(fixture.payload, bytes)
        }

        let manifestMutations: [(String, (inout [String: Any]) -> Void)] = [
            ("unsupported_manifest_version_refused", { $0["schemaVersion"] = 2 }),
            ("archive_name_mismatch_refused", { $0["archive"] = "../seforim-schema7.db.zst" }),
            ("aggregate_size_mismatch_refused", { $0["size"] = 1 }),
            ("part_order_mismatch_refused", { value in
                value["parts"] = Array((value["parts"] as! [[String: Any]]).reversed())
            }),
            ("part_duplicate_name_refused", { value in
                var parts = value["parts"] as! [[String: Any]]; parts[1]["name"] = parts[0]["name"]; value["parts"] = parts
            }),
            ("part_digest_mismatch_refused", { value in
                var parts = value["parts"] as! [[String: Any]]; parts[0]["sha256"] = String(repeating: "0", count: 64); value["parts"] = parts
            }),
            ("part_size_mismatch_refused", { value in
                var parts = value["parts"] as! [[String: Any]]; parts[1]["size"] = 10; value["parts"] = parts
            }),
            ("empty_parts_refused", { $0["parts"] = [] as [[String: Any]] })
        ]
        for (name, mutation) in manifestMutations {
            await suite.run(name) {
                let (payload, manifest) = try modifiedFixture(fixture, changeManifest: mutation)
                try rejectedParser(payload, manifest)
            }
        }
        let releaseMutations: [(String, (inout [String: Any]) -> Void)] = [
            ("part_missing_from_same_release_refused", { value in
                var assets = value["assets"] as! [[String: Any]]; assets.removeLast(); value["assets"] = assets
            }),
            ("part_duplicate_remote_id_refused", { value in
                var assets = value["assets"] as! [[String: Any]]; assets[2]["id"] = assets[1]["id"]; value["assets"] = assets
            }),
            ("part_foreign_release_url_refused", { value in
                var assets = value["assets"] as! [[String: Any]]
                assets[2]["browser_download_url"] = "https://github.com/other/repo/releases/download/x/part"
                value["assets"] = assets
            }),
            ("manifest_metadata_over_one_mib_refused", { value in
                var assets = value["assets"] as! [[String: Any]]; assets[0]["size"] = 1_048_577; value["assets"] = assets
            })
        ]
        for (name, mutation) in releaseMutations {
            await suite.run(name) {
                let (payload, manifest) = try modifiedFixture(fixture, changeRelease: mutation)
                try rejectedParser(payload, manifest)
            }
        }
        await suite.run("persisted_remote_and_archive_identities_are_separate") {
            let resume = OtzariaDownloadResumeMetadata(release: fixture.release)
            let installed = OtzariaDatabaseInstallationManifest(release: fixture.release, databaseFileSize: 12000)
            try require(resume.assetID == fixture.release.asset.id
                        && resume.assetName == fixture.release.asset.name
                        && resume.digest == fixture.release.asset.digest, "resume remote identity was relabeled")
            try require(installed.assetID == fixture.release.asset.id
                        && installed.assetName == fixture.release.asset.name
                        && installed.compressedSize == Int64(fixture.manifest.count), "installed remote identity was relabeled")
            try require(installed.archiveName == fixture.release.archiveName
                        && installed.archiveCompressedSize == Int64(fixture.joined.count)
                        && installed.archiveDigest == fixture.release.archiveDigest
                        && installed.hasValidProductionArchiveIdentity, "explicit installed archive identity invalid")
            let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
            let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
            let readback = try decoder.decode(OtzariaDatabaseInstallationManifest.self, from: encoder.encode(installed))
            try require(readback.hasValidProductionArchiveIdentity && readback.multipart == installed.multipart,
                        "multipart metadata did not survive persistence")
        }
        await suite.run("legacy_metadata_without_multipart_decodes_unchanged") {
            let data = try Data(contentsOf: fixtures.appendingPathComponent("official-v32-release.json"))
            let release = try OtzariaLibraryReleaseClient.parseLatestRelease(data: data)
            let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
            var stored = try JSONSerialization.jsonObject(with: encoder.encode(
                OtzariaDatabaseInstallationManifest(release: release, databaseFileSize: 12345)
            )) as! [String: Any]
            stored.removeValue(forKey: "multipart")
            let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
            let readback = try decoder.decode(OtzariaDatabaseInstallationManifest.self, from: encodeJSON(stored))
            try require(readback.multipart == nil && readback.assetID == release.asset.id
                        && readback.archiveName == release.asset.name
                        && readback.hasValidProductionArchiveIdentity, "legacy installation metadata changed")
        }
        await suite.run("storage_budget_includes_parts_assembly_and_output") {
            let total = fixture.release.compressedSize
            let required = DownloadCapacityFixture.requiredDownloadCapacity(release: fixture.release, existingPart: 1000)
            try require(required == total * 8 - 1000 + 1_073_741_824, "multipart peak storage was understated")
            let single = OtzariaLibraryRelease(id: 1, tag: "single", asset: fixture.release.multipart!.parts[0])
            let legacy = DownloadCapacityFixture.requiredDownloadCapacity(release: single, existingPart: 1000)
            try require(legacy == single.compressedSize * 7 - 1000 + 1_073_741_824, "monolithic budget changed")
        }
        await suite.run("storage_budget_overflow_refuses_with_saturated_requirement") {
            let asset = OtzariaLibraryRelease.Asset(id: 1, name: "seforim.db.zst",
                downloadURL: URL(string: "https://github.com/Otzaria/SeforimLibrary/releases/download/x/seforim.db.zst")!,
                compressedSize: Int64.max, digest: "sha256:" + String(repeating: "0", count: 64), updatedAt: nil)
            let release = OtzariaLibraryRelease(id: 1, tag: "x", asset: asset)
            try require(DownloadCapacityFixture.requiredDownloadCapacity(release: release, existingPart: 0) == Int64.max,
                        "overflow must fail capacity preflight")
        }

        await suite.run("fresh_parts_and_verified_archive_cache") {
            let root = try suite.workspace("fresh")
            ControlledTransport.shared.configure(fixture.routes())
            let downloader = OtzariaDatabaseDownloader(sessionConfiguration: configuration)
            let url = try await downloader.download(release: fixture.release, workspaceURL: root) { _, _, _ in }
            try require(try Data(contentsOf: url) == fixture.joined, "ordered assembly bytes differ")
            try require(try OtzariaDatabaseDownloader.verifyDownload(at: url, release: fixture.release) == sha(fixture.joined),
                        "original full archive verification differs")
            try require(ControlledTransport.shared.requests().count == 2, "fresh transfer must use exactly two actual part requests")
            ControlledTransport.shared.configure([:])
            let reused = try await downloader.download(release: fixture.release, workspaceURL: root) { _, _, _ in }
            try require(reused == url && ControlledTransport.shared.requests().isEmpty, "complete archive reuse performed network")
            try require(try OtzariaDatabaseDownloader.verifyDownload(at: reused, release: fixture.release) == sha(fixture.joined),
                        "cached archive must still pass the original verifier")
        }
        await suite.run("cross_part_resume_preserves_complete_part_and_validator") {
            let root = try suite.workspace("resume")
            try seed(root, fixture: fixture, secondPrefix: 512)
            let before = try Data(contentsOf: partWorkspace(root, 0).appendingPathComponent(OtzariaDatabaseDownloader.partFileName))
            try require(OtzariaDatabaseDownloader.existingPartialSize(workspaceURL: root, release: fixture.release) == 4608,
                        "resume must use actual per-part files, not stale parent counter")
            let offline = try OtzariaDatabaseDownloader.resumableProductionRelease(workspaceURL: root)
            try require(offline == fixture.release, "validated multipart offline resume identity differs")
            ControlledTransport.shared.configure(fixture.routes())
            let downloader = OtzariaDatabaseDownloader(sessionConfiguration: configuration)
            let url = try await downloader.download(release: fixture.release, workspaceURL: root) { _, _, _ in }
            try require(try Data(contentsOf: url) == fixture.joined, "resumed archive bytes differ")
            let requests = ControlledTransport.shared.requests()
            try require(requests.count == 1 && requests[0].range == "bytes=512-"
                        && requests[0].validator == "\"controlled-v1\""
                        && requests[0].url == fixture.release.multipart!.parts[1].downloadURL.absoluteString,
                        "range/validator escaped the current part")
            try require(try Data(contentsOf: partWorkspace(root, 0).appendingPathComponent(OtzariaDatabaseDownloader.partFileName)) == before,
                        "complete first part was rewritten")
        }
        for (name, behavior, expectedRequests) in [
            ("server_ignores_range_restarts_only_current_part", "ignore-range", 1),
            ("bad_content_range_restarts_only_current_part", "wrong-range", 2),
            ("changed_etag_restarts_without_mixing_bytes", "changed-etag", 2)
        ] {
            await suite.run(name) {
                let root = try suite.workspace(behavior)
                try seed(root, fixture: fixture, secondPrefix: 256)
                ControlledTransport.shared.configure(fixture.routes(secondBehavior: behavior))
                let downloader = OtzariaDatabaseDownloader(sessionConfiguration: configuration)
                let url = try await downloader.download(release: fixture.release, workspaceURL: root) { _, _, _ in }
                try require(try Data(contentsOf: url) == fixture.joined, "restart mixed old/current bytes")
                let requests = ControlledTransport.shared.requests()
                try require(requests.count == expectedRequests
                            && requests.allSatisfy { $0.url == fixture.release.multipart!.parts[1].downloadURL.absoluteString },
                            "restart touched a verified earlier part")
                try require(requests[0].range == "bytes=256-", "original range header missing")
                if expectedRequests == 2 {
                    try require(requests[1].range == nil && requests[1].validator == nil,
                                "fresh restart must not retain old range authority")
                }
            }
        }
        await suite.run("corrupt_part_never_publishes_archive") {
            let root = try suite.workspace("corrupt")
            ControlledTransport.shared.configure(fixture.routes(secondBehavior: "corrupt"))
            let downloader = OtzariaDatabaseDownloader(sessionConfiguration: configuration)
            do {
                _ = try await downloader.download(release: fixture.release, workspaceURL: root) { _, _, _ in }
                throw ControlFailure.failed("corrupt part accepted")
            } catch OtzariaDatabaseBootstrapError.digestMismatch { }
            try require(!FileManager.default.fileExists(atPath: root.appendingPathComponent(OtzariaDatabaseDownloader.partFileName).path),
                        "corrupt part reached assembled archive")
        }
        await suite.run("oversized_part_is_refused_before_assembly") {
            let root = try suite.workspace("oversize")
            ControlledTransport.shared.configure(fixture.routes(secondBehavior: "oversize"))
            let downloader = OtzariaDatabaseDownloader(sessionConfiguration: configuration)
            do {
                _ = try await downloader.download(release: fixture.release, workspaceURL: root) { _, _, _ in }
                throw ControlFailure.failed("oversized part accepted")
            } catch OtzariaDatabaseBootstrapError.downloadSizeMismatch { }
            try require(!FileManager.default.fileExists(atPath: root.appendingPathComponent(OtzariaDatabaseDownloader.partFileName).path),
                        "oversized part reached assembled archive")
        }
        await suite.run("wrong_aggregate_digest_refused_by_original_verifier") {
            let broken = try ControlledArchive.make("controlled-bad-aggregate", archiveDigest: String(repeating: "0", count: 64))
            let root = try suite.workspace("aggregate-digest")
            ControlledTransport.shared.configure(broken.routes())
            let downloader = OtzariaDatabaseDownloader(sessionConfiguration: configuration)
            let url = try await downloader.download(release: broken.release, workspaceURL: root) { _, _, _ in }
            try require(try Data(contentsOf: url) == broken.joined, "controlled parts must be intact")
            do {
                _ = try OtzariaDatabaseDownloader.verifyDownload(at: url, release: broken.release)
                throw ControlFailure.failed("full archive digest refusal was bypassed")
            } catch OtzariaDatabaseBootstrapError.digestMismatch { }
        }
        await suite.run("cancel_then_resume_uses_same_owned_partial_parts") {
            let root = try suite.workspace("cancel-resume")
            ControlledTransport.shared.configure(fixture.routes(secondBehavior: "hold"))
            let downloader = OtzariaDatabaseDownloader(sessionConfiguration: configuration)
            let boundary = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
            let transfer = Task {
                do {
                    return try await downloader.download(release: fixture.release, workspaceURL: root) { bytes, _, _ in
                        if bytes >= 4608 { boundary.continuation.yield(()) }
                    }
                } catch {
                    boundary.continuation.finish()
                    throw error
                }
            }
            var iterator = boundary.stream.makeAsyncIterator()
            let reached = await iterator.next()
            if reached == nil {
                _ = try await transfer.value
                throw ControlFailure.failed("held response finished without persisted boundary")
            }
            await downloader.cancel()
            switch await transfer.result {
            case .success:
                throw ControlFailure.failed("cancelled transfer returned success")
            case .failure(let error):
                guard let value = error as? OtzariaDatabaseBootstrapError, case .cancelled = value else { throw error }
            }
            boundary.continuation.finish()
            try require(OtzariaDatabaseDownloader.observedDownloadedBytes(workspaceURL: root) == 4608,
                        "actual native cancellation observation missed partial parts")
            try require(OtzariaDatabaseDownloader.existingPartialSize(workspaceURL: root, release: fixture.release) == 4608,
                        "cancel discarded a valid owned range")
            try require(!FileManager.default.fileExists(atPath: root.appendingPathComponent(OtzariaDatabaseDownloader.partFileName).path),
                        "cancel published an incomplete archive")
            ControlledTransport.shared.configure(fixture.routes())
            let url = try await downloader.download(release: fixture.release, workspaceURL: root) { _, _, _ in }
            try require(try Data(contentsOf: url) == fixture.joined, "post-cancel archive differs")
            let requests = ControlledTransport.shared.requests()
            try require(requests.count == 1 && requests[0].range == "bytes=512-",
                        "post-cancel resume replayed an already verified part or lost offset")
        }
        await suite.run("invalid_persisted_plan_refuses_before_io") {
            let root = try suite.workspace("invalid-plan")
            let marker = root.appendingPathComponent("unrelated-owner.txt")
            try Data("retain".utf8).write(to: marker)
            var release = fixture.release
            let original = release.multipart!
            var parts = original.parts
            let part = parts[1]
            parts[1] = .init(id: part.id, name: part.name, downloadURL: URL(string: "https://example.invalid/foreign")!,
                             compressedSize: part.compressedSize, digest: part.digest, updatedAt: part.updatedAt)
            release.multipart = .init(manifest: original.manifest, archiveName: original.archiveName,
                                      compressedSize: original.compressedSize, digest: original.digest, parts: parts)
            ControlledTransport.shared.configure([:])
            let downloader = OtzariaDatabaseDownloader(sessionConfiguration: configuration)
            do {
                _ = try await downloader.download(release: release, workspaceURL: root) { _, _, _ in }
                throw ControlFailure.failed("invalid cached URLs reached I/O")
            } catch OtzariaDatabaseBootstrapError.invalidAssetMetadata { }
            try require(ControlledTransport.shared.requests().isEmpty
                        && (try Data(contentsOf: marker)) == Data("retain".utf8), "refusal changed another owner's file")
        }
        await suite.run("legacy_single_asset_range_behavior_preserved") {
            let root = try suite.workspace("legacy-range")
            let bytes = Data(repeating: 0x55, count: 2048)
            let url = URL(string: "https://github.com/Otzaria/SeforimLibrary/releases/download/controlled-single/seforim.db.zst")!
            let release = OtzariaLibraryRelease(id: 11, tag: "controlled-single",
                asset: .init(id: 12, name: "seforim.db.zst", downloadURL: url,
                             compressedSize: Int64(bytes.count), digest: "sha256:" + sha(bytes), updatedAt: nil))
            try Data(bytes.prefix(128)).write(to: root.appendingPathComponent(OtzariaDatabaseDownloader.partFileName))
            var metadata = OtzariaDownloadResumeMetadata(release: release, downloadedBytes: 128)
            metadata.etag = "\"controlled-v1\""
            try OtzariaDatabaseDownloader.writeMetadata(metadata, to: root.appendingPathComponent(OtzariaDatabaseDownloader.sidecarFileName))
            try require(try OtzariaDatabaseDownloader.resumableProductionRelease(workspaceURL: root) == release,
                        "legacy validated offline metadata changed")
            ControlledTransport.shared.configure([url.absoluteString: route(bytes)])
            let downloader = OtzariaDatabaseDownloader(sessionConfiguration: configuration)
            let local = try await downloader.download(release: release, workspaceURL: root) { _, _, _ in }
            try require(try Data(contentsOf: local) == bytes, "legacy resumed bytes changed")
            try require(ControlledTransport.shared.requests().first?.range == "bytes=128-",
                        "legacy original Range semantics changed")
            try require(try OtzariaDatabaseDownloader.verifyDownload(at: local, release: release) == sha(bytes),
                        "legacy hash verification changed")
        }
        await suite.run("cleanup_removes_only_owned_download_files") {
            let root = try suite.workspace("cleanup")
            ControlledTransport.shared.configure(fixture.routes())
            let downloader = OtzariaDatabaseDownloader(sessionConfiguration: configuration)
            _ = try await downloader.download(release: fixture.release, workspaceURL: root) { _, _, _ in }
            let marker = root.appendingPathComponent("unrelated-owner.txt")
            try Data("retain".utf8).write(to: marker)
            await downloader.cleanupAfterSuccessfulInstall(workspaceURL: root)
            for name in [OtzariaDatabaseDownloader.partFileName, OtzariaDatabaseDownloader.sidecarFileName,
                         OtzariaDatabaseDownloader.multipartDirectoryName, OtzariaDatabaseDownloader.assemblyFileName] {
                try require(!FileManager.default.fileExists(atPath: root.appendingPathComponent(name).path),
                            "owned download component was not cleaned: " + name)
            }
            try require(try Data(contentsOf: marker) == Data("retain".utf8), "unrelated owned data was removed")
        }

        await suite.run("manifest_stream_success_and_remote_identity") {
            var routes: [String: ControlledTransport.Route] = [:]
            routes[OtzariaLibraryReleaseClient.latestReleaseURL.absoluteString] = { _, _ in
                .init(data: fixture.payload, headers: ["Content-Length": String(fixture.payload.count)])
            }
            routes[fixture.release.asset.downloadURL.absoluteString] = { _, _ in
                .init(data: fixture.manifest, headers: ["Content-Length": String(fixture.manifest.count)])
            }
            ControlledTransport.shared.configure(routes)
            let session = URLSession(configuration: configuration())
            defer { session.invalidateAndCancel() }
            let release = try await OtzariaLibraryReleaseClient(session: session).fetchLatestRelease()
            try require(release == fixture.release, "bounded streamed manifest changed remote/archived identity")
            try require(ControlledTransport.shared.requests().count == 2, "metadata lookup issued archive traffic")
        }
        for (name, overflow) in [
            ("manifest_stream_declared_length_mismatch_cancels", false),
            ("manifest_stream_actual_byte_overflow_cancels", true)
        ] {
            await suite.run(name) {
                // Unique URL binds the stop callback to this exact held request.
                let fixture = try ControlledArchive.make("controlled-manifest-" + name)
                var routes: [String: ControlledTransport.Route] = [:]
                routes[OtzariaLibraryReleaseClient.latestReleaseURL.absoluteString] = { _, _ in
                    .init(data: fixture.payload, headers: ["Content-Length": String(fixture.payload.count)])
                }
                let manifestURL = fixture.release.asset.downloadURL.absoluteString
                routes[manifestURL] = { _, _ in
                    var bytes = fixture.manifest
                    if overflow { bytes.append(0) }
                    return .init(data: bytes,
                                 headers: overflow ? [:] : ["Content-Length": String(fixture.manifest.count + 1)],
                                 hold: true)
                }
                let stopped = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
                ControlledTransport.shared.configure(routes, onStop: { url in
                    if url == manifestURL { stopped.continuation.yield(()) }
                })
                let session = URLSession(configuration: configuration())
                defer { session.invalidateAndCancel(); stopped.continuation.finish() }
                do {
                    _ = try await OtzariaLibraryReleaseClient(session: session).fetchLatestRelease()
                    throw ControlFailure.failed("out-of-bounds manifest was accepted")
                } catch OtzariaDatabaseBootstrapError.invalidAssetMetadata { }
                try await requireOwnedStop(stopped.stream)
            }
        }
        await suite.run("manifest_stream_truncation_refused") {
            var routes: [String: ControlledTransport.Route] = [:]
            routes[OtzariaLibraryReleaseClient.latestReleaseURL.absoluteString] = { _, _ in .init(data: fixture.payload) }
            routes[fixture.release.asset.downloadURL.absoluteString] = { _, _ in .init(data: Data(fixture.manifest.dropLast())) }
            ControlledTransport.shared.configure(routes)
            let session = URLSession(configuration: configuration())
            defer { session.invalidateAndCancel() }
            do {
                _ = try await OtzariaLibraryReleaseClient(session: session).fetchLatestRelease()
                throw ControlFailure.failed("truncated streamed manifest was accepted")
            } catch OtzariaDatabaseBootstrapError.invalidAssetMetadata { }
        }

        let failed = suite.rows.filter { $0["status"] == "FAIL" }.count
        let result: [String: Any] = [
            "status": failed == 0 ? "APPLE_COMPONENT_PASS" : "APPLE_COMPONENT_FAIL",
            "counts": ["PASS": suite.rows.count - failed, "FAIL": failed, "SKIP": 0],
            "cases": suite.rows,
            "platform_crypto": "Actual Apple CryptoKit SHA256",
            "transport": "Actual URLSession delegates with explicitly controlled URLProtocol responses",
            "public_network_requests": 0,
            "production_archive_payload_downloaded": false,
            "native_app_or_sqlite_installation_acceptance": false
        ]
        try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("RESULT.json"))
        if failed != 0 { exit(1) }
    }
}

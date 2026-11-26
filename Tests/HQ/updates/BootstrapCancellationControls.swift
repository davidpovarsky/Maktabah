import Foundation

private final class StalledRelease: URLProtocol, @unchecked Sendable {
    static let payload = Data((0..<4_096).map { UInt8($0 & 255) })
    static let durablePrefix = 1_024
    static let etag = "\"bootstrap-cancel-control\""
    static let stopped = AsyncStream<Void>.makeStream()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else { return }
        let range = request.value(forHTTPHeaderField: "Range")
        if let range {
            guard range == "bytes=\(Self.durablePrefix)-",
                  request.value(forHTTPHeaderField: "If-Range") == Self.etag else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
        }
        let initial = range == nil
        let start = initial ? 0 : Self.durablePrefix
        var headers = ["Content-Length": String(Self.payload.count - start), "ETag": Self.etag]
        if !initial { headers["Content-Range"] = "bytes \(start)-\(Self.payload.count - 1)/\(Self.payload.count)" }
        let response = HTTPURLResponse(url: url, statusCode: initial ? 200 : 206, httpVersion: "HTTP/1.1", headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        let bytes = initial ? Self.payload.prefix(Self.durablePrefix) : Self.payload.dropFirst(start)
        client?.urlProtocol(self, didLoad: Data(bytes))
        if !initial { client?.urlProtocolDidFinishLoading(self) }
    }
    override func stopLoading() { Self.stopped.continuation.yield(()) }
}

private enum ControlFailure: Error {
    case timedOut(String), completedDespiteCancellation, badResume
}

private func awaitSignal(_ signal: AsyncStream<Void>, name: String) async throws {
    let received = await withTaskGroup(of: Bool.self) { group in
        group.addTask {
            var iterator = signal.makeAsyncIterator()
            return await iterator.next() != nil
        }
        group.addTask {
            try? await Task.sleep(for: .seconds(4))
            return false
        }
        let first = await group.next() ?? false
        group.cancelAll()
        return first
    }
    guard received else { throw ControlFailure.timedOut(name) }
}

@main struct BootstrapCancellationControls {
    static func main() async {
        do {
            try await run()
        } catch {
            print("FAIL \(error)")
            exit(1)
        }
    }

    private static func run() async throws {
        let workspace = FileManager.default.temporaryDirectory
            .appendingPathComponent("OtzariaBootstrapCancellation-\(UUID())", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: workspace) }
        let downloader = OtzariaDatabaseDownloader {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [StalledRelease.self]
            return configuration
        }
        let asset = OtzariaLibraryRelease.Asset(
            id: 7, name: "seforim-schema7.db.zst",
            downloadURL: URL(string: "https://example.invalid/seforim-schema7.db.zst")!,
            compressedSize: Int64(StalledRelease.payload.count), digest: nil, updatedAt: nil
        )
        let release = OtzariaLibraryRelease(id: 42, tag: "v40-control", asset: asset)
        let prefixWritten = AsyncStream<Void>.makeStream()
        let installation = Task {
            try await downloader.download(release: release, workspaceURL: workspace) { written, _, _ in
                if written == Int64(StalledRelease.durablePrefix) { prefixWritten.continuation.yield(()) }
            }
        }
        try await awaitSignal(prefixWritten.stream, name: "Persisted download prefix")
        installation.cancel()
        try await awaitSignal(StalledRelease.stopped.stream, name: "URLSession cancellation")
        do {
            _ = try await installation.value
            throw ControlFailure.completedDespiteCancellation
        } catch OtzariaDatabaseBootstrapError.cancelled {
            print("PASS parent cancellation stopped the original stalled URLSession download")
        }
        let partial = OtzariaDatabaseDownloader.existingPartialSize(workspaceURL: workspace, release: release)
        guard partial == Int64(StalledRelease.durablePrefix) else { throw ControlFailure.badResume }
        let resumed = AsyncStream<Int64>.makeStream()
        let archive = try await downloader.download(release: release, workspaceURL: workspace) { _, _, offset in
            resumed.continuation.yield(offset)
        }
        resumed.continuation.finish()
        var progress = resumed.stream.makeAsyncIterator()
        guard await progress.next() == partial, try Data(contentsOf: archive) == StalledRelease.payload else {
            throw ControlFailure.badResume
        }
        print("PASS retry resumed with Range and If-Range and retained every original byte")
    }
}

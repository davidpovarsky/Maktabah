import Foundation

private final class StalledRelease: URLProtocol, @unchecked Sendable {
    static let started = AsyncStream<Void>.makeStream()
    static let stopped = AsyncStream<Void>.makeStream()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() { Self.started.continuation.yield(()) }
    override func stopLoading() { Self.stopped.continuation.yield(()) }
}

private enum ControlFailure: Error { case timedOut(String), completedDespiteCancellation }

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
            compressedSize: 4096, digest: nil, updatedAt: nil
        )
        let release = OtzariaLibraryRelease(id: 42, tag: "v40-control", asset: asset)
        let installation = Task {
            try await downloader.download(release: release, workspaceURL: workspace) { _, _, _ in }
        }
        try await awaitSignal(StalledRelease.started.stream, name: "URLSession request")
        installation.cancel()
        try await awaitSignal(StalledRelease.stopped.stream, name: "URLSession cancellation")
        do {
            _ = try await installation.value
            throw ControlFailure.completedDespiteCancellation
        } catch OtzariaDatabaseBootstrapError.cancelled {
            print("PASS parent cancellation stopped the original stalled URLSession download")
        }
    }
}

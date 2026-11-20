
#if DEBUG && SEFARIA_TOC_TRANSPORT_ACCEPTANCE_TESTS
private struct TOCTransportFixtureReply: Decodable, Sendable { let value: Int }

private final class TOCTransportFixtureObservation: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func record() { lock.lock(); count += 1; lock.unlock() }
    func observed() -> Int { lock.lock(); defer { lock.unlock() }; return count }
}

private final class TOCTransportSuccessFixture: URLProtocol {
    static let observation = TOCTransportFixtureObservation()
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.absoluteString == "https://www.sefaria.org/api/v2/raw/index/Genesis"
    }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.observation.record()
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
                                       headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(#"{"value":17}"#.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

extension SefariaTOCTransportAcceptance {
    fileprivate static func fixtureAdmissionChecks(_ configuration: Configuration, nonce: UUID) throws -> [[String: Any]] {
        var rows: [[String: Any]] = []
        func check(_ name: String, _ value: Bool) { rows.append(["name": name, "passed": value]) }
        let context = Context(configuration: configuration, nonce: nonce, workKey: "Genesis", ownerID: "fixture-owner")
        let gate = Admission()
        check("admission.arm-once", gate.arm(context) && !gate.arm(context))
        let unrelated = URLRequest(url: URL(string: "https://www.sefaria.org/api/shape/Genesis")!)
        check("admission.reject-shape", !gate.tag(context, request: unrelated))
        var post = URLRequest(url: URL(string: context.expectedURL)!)
        post.httpMethod = "POST"
        check("admission.reject-post", !gate.tag(context, request: post))
        var body = URLRequest(url: URL(string: context.expectedURL)!)
        body.httpBody = Data("body".utf8)
        check("admission.reject-body", !gate.tag(context, request: body))
        var query = URLRequest(url: URL(string: context.expectedURL + "?another=1")!)
        query.httpMethod = "GET"
        check("admission.exact-url", !gate.tag(context, request: query))
        let foreign = Context(configuration: configuration, nonce: UUID(), workKey: "Genesis", ownerID: "fixture-owner")
        let get = URLRequest(url: URL(string: context.expectedURL)!)
        check("admission.exact-nonce", !gate.tag(foreign, request: get))
        check("admission.tag-once", gate.tag(context, request: get) && !gate.tag(context, request: get))
        check("admission.no-untagged-claim", gate.matches(get, claim: true) == nil)
        let mutable = (get as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        URLProtocol.setProperty(nonce.uuidString, forKey: propertyKey, in: mutable)
        let tagged = mutable as URLRequest
        check("admission.property-local-not-header",
              URLProtocol.property(forKey: propertyKey, in: tagged) as? String == nonce.uuidString
              && !(tagged.allHTTPHeaderFields?.values.contains(nonce.uuidString) ?? false))
        check("admission.can-init-is-passive", gate.matches(tagged, claim: false) != nil && gate.matches(tagged, claim: false) != nil)
        check("admission.claim-once", gate.matches(tagged, claim: true) != nil && gate.matches(tagged, claim: true) == nil)
        let valid: [String: Any] = ["schemaVersion": 1, "namespace": configuration.namespace.uuidString,
            "nonce": nonce.uuidString, "backend": "sefaria", "workKey": "Genesis", "operation": "reloadOwnedTOC"]
        try JSONSerialization.data(withJSONObject: valid).write(to: configuration.commandURL)
        check("command.valid-exact-schema", command(configuration: configuration) == nonce)
        var wrong = valid; wrong["namespace"] = UUID().uuidString
        try JSONSerialization.data(withJSONObject: wrong).write(to: configuration.commandURL)
        check("command.foreign-namespace-rejected", command(configuration: configuration) == nil)
        wrong = valid; wrong["unrequested"] = true
        try JSONSerialization.data(withJSONObject: wrong).write(to: configuration.commandURL)
        check("command.extra-field-rejected", command(configuration: configuration) == nil)
        try Data(repeating: 32, count: 4_097).write(to: configuration.commandURL)
        check("command.bounded-bytes", command(configuration: configuration) == nil)
        try FileManager.default.removeItem(at: configuration.commandURL)
        return rows
    }
}

/// Explicit client double for rejected-request lifecycle only. It never supplies
/// successful URL loading data and is not a URLSession/Native execution claim.
private final class TOCTransportFailureClient: NSObject, URLProtocolClient, @unchecked Sendable {
    private let lock = NSLock()
    private var failures: [Int] = []
    private var unexpected = 0
    private let reentrantStop: Bool

    init(reentrantStop: Bool = false) { self.reentrantStop = reentrantStop }

    func snapshot() -> (failures: [Int], unexpected: Int) {
        lock.lock(); defer { lock.unlock() }
        return (failures, unexpected)
    }
    private func rejectUnexpected() { lock.lock(); unexpected += 1; lock.unlock() }
    func urlProtocol(_ proto: URLProtocol, didFailWithError error: Error) {
        lock.lock(); failures.append((error as NSError).code); lock.unlock()
        if reentrantStop { proto.stopLoading() }
    }
    func urlProtocol(_ proto: URLProtocol, wasRedirectedTo request: URLRequest, redirectResponse: URLResponse) { rejectUnexpected() }
    func urlProtocol(_ proto: URLProtocol, cachedResponseIsValid cachedResponse: CachedURLResponse) { rejectUnexpected() }
    func urlProtocol(_ proto: URLProtocol, didReceive response: URLResponse, cacheStoragePolicy policy: URLCache.StoragePolicy) { rejectUnexpected() }
    func urlProtocol(_ proto: URLProtocol, didLoad data: Data) { rejectUnexpected() }
    func urlProtocolDidFinishLoading(_ proto: URLProtocol) { rejectUnexpected() }
    func urlProtocol(_ proto: URLProtocol, didReceive challenge: URLAuthenticationChallenge) { rejectUnexpected() }
    func urlProtocol(_ proto: URLProtocol, didCancel challenge: URLAuthenticationChallenge) { rejectUnexpected() }
}

private enum TOCTransportLifetimeControls {
    static func run() -> [[String: Any]] {
        let request = URLRequest(url: URL(string: "https://invalid.example/owned-declined-request")!)
        var rows: [[String: Any]] = []
        func check(_ name: String, _ value: Bool) { rows.append(["name": name, "passed": value]) }
        do {
            let client = TOCTransportFailureClient()
            let proto = SefariaTOCFailureURLProtocol(request: request, cachedResponse: nil, client: client)
            proto.stopLoading()
            proto.startLoading()
            let observed = client.snapshot()
            check("lifetime.stop-before-rejected-start", observed.failures.isEmpty && observed.unexpected == 0)
        }
        do {
            let client = TOCTransportFailureClient()
            let proto = SefariaTOCFailureURLProtocol(request: request, cachedResponse: nil, client: client)
            proto.startLoading()
            proto.startLoading()
            let observed = client.snapshot()
            check("lifetime.declined-start-completes-once",
                  observed.failures == [URLError.cancelled.rawValue] && observed.unexpected == 0)
        }
        do {
            let client = TOCTransportFailureClient(reentrantStop: true)
            let proto = SefariaTOCFailureURLProtocol(request: request, cachedResponse: nil, client: client)
            proto.startLoading() // Original completion calls this client's stopLoading reentrantly.
            proto.startLoading()
            proto.stopLoading()
            let observed = client.snapshot()
            check("lifetime.reentrant-stop-prevents-late-callback",
                  observed.failures == [URLError.cancelled.rawValue] && observed.unexpected == 0)
        }
        return rows
    }
}

@main enum TOCTransportFoundationAcceptance {
    @MainActor
    static func main() async throws {
        let mode = CommandLine.arguments[1]
        if mode == "lifetime" {
            let rows = TOCTransportLifetimeControls.run()
            FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: rows, options: [.sortedKeys]))
            FileHandle.standardOutput.write(Data("\n".utf8))
            exit(rows.allSatisfy { $0["passed"] as? Bool == true } ? 0 : 1)
        }
        let directory = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        let configuration = SefariaTOCTransportAcceptance.Configuration(namespace: UUID(), documents: directory)
        let nonce = UUID()
        var rows = try SefariaTOCTransportAcceptance.fixtureAdmissionChecks(configuration, nonce: nonce)
        func check(_ name: String, _ passed: Bool) { rows.append(["name": name, "passed": passed]) }
        check("runtime.real-app-configuration-not-enabled", SefariaTOCTransportAcceptance.configuration == nil)
        let context = SefariaTOCTransportAcceptance.arm(configuration: configuration, nonce: nonce,
                                                        ownerID: "whole-client-child-task-fixture")!
        let sessionConfig = URLSessionConfiguration.ephemeral
        // Only successful retry transport bytes are a fixture boundary. The
        // original failure URLProtocol/client/TaskLocal path below is whole source.
        sessionConfig.protocolClasses = [SefariaTOCFailureURLProtocol.self, TOCTransportSuccessFixture.self]
        let session = URLSession(configuration: sessionConfig)
        let client = SefariaHTTPClient(session: session)
        defer { session.invalidateAndCancel() }
        var completed = false
        let worker = SefariaTOCTransportAcceptance.$context.withValue(context) {
            // Explicit Foundation control for the original owner's child-Task
            // shape, not a claim that SwiftUI/BookTOCViewModel ran here.
            Task { @MainActor in
                defer { completed = true }
                do {
                    let reply = try await client.get(TOCTransportFixtureReply.self,
                        url: URL(string: context.expectedURL)!, timeoutInterval: 5, maxAttempts: 3)
                    return "success:\(reply.value)"
                } catch is CancellationError { return "cancelled" }
                catch LibraryBackendError.unavailableOffline { return "unavailableOffline" }
                catch { return "other:\(type(of: error))" }
            }
        }
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while !FileManager.default.fileExists(atPath: configuration.url(nonce: nonce, stage: "held").path),
              ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        let held = FileManager.default.fileExists(atPath: configuration.url(nonce: nonce, stage: "held").path)
        check("runtime.actual-urlprotocol-held", held)
        check("runtime.tasklocal-inherited-by-child", FileManager.default.fileExists(
            atPath: configuration.url(nonce: nonce, stage: "tagged").path))
        check("runtime.no-completion-before-release", !completed)
        check("runtime.success-boundary-not-called-while-held", TOCTransportSuccessFixture.observation.observed() == 0)
        if mode == "failure-retry", held {
            let release: [String: Any] = ["schemaVersion": 1, "namespace": configuration.namespace.uuidString,
                "nonce": nonce.uuidString, "operation": "releaseFault"]
            try JSONSerialization.data(withJSONObject: release).write(
                to: configuration.url(nonce: nonce, stage: "release"))
        } else { worker.cancel() }
        let result = await worker.value
        check(mode == "failure-retry" ? "runtime.original-offline-error-mapping" : "runtime.held-cancellation",
              result == (mode == "failure-retry" ? "unavailableOffline" : "cancelled"))
        check("runtime.no-automatic-success-retry", TOCTransportSuccessFixture.observation.observed() == 0)
        check("runtime.no-fake-success-response", completed && result != "success:17")
        if mode == "failure-retry" {
            check("runtime.actual-failure-receipt", FileManager.default.fileExists(
                atPath: configuration.url(nonce: nonce, stage: "failed").path))
        } else {
            check("runtime.cancel-does-not-publish-failure", !FileManager.default.fileExists(
                atPath: configuration.url(nonce: nonce, stage: "failed").path))
        }
        do {
            let reply = try await client.get(TOCTransportFixtureReply.self,
                url: URL(string: context.expectedURL)!, timeoutInterval: 5, maxAttempts: 1)
            check("runtime.retry-outside-tasklocal-uses-original-session", reply.value == 17
                  && TOCTransportSuccessFixture.observation.observed() == 1)
        } catch { check("runtime.retry-outside-tasklocal-uses-original-session", false) }
        let late = try await SefariaTOCTransportAcceptance.$context.withValue(context) {
            try await client.get(TOCTransportFixtureReply.self,
                url: URL(string: context.expectedURL)!, timeoutInterval: 5, maxAttempts: 1)
        }
        check("runtime.consumed-token-cannot-steal-later-request", late.value == 17
              && TOCTransportSuccessFixture.observation.observed() == 2)
        FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: rows, options: [.sortedKeys]))
        FileHandle.standardOutput.write(Data("\n".utf8))
        exit(rows.allSatisfy { $0["passed"] as? Bool == true } ? 0 : 1)
    }
}
#endif

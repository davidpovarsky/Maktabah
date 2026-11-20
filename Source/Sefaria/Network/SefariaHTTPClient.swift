import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

actor SefariaHTTPClient {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let maximumAttempts = 3

    init(session: URLSession = .shared) {
        #if DEBUG && (targetEnvironment(simulator) || SEFARIA_TOC_TRANSPORT_ACCEPTANCE_TESTS)
        self.session = SefariaTOCTransportAcceptance.session(replacingShared: session)
        #else
        self.session = session
        #endif
        self.decoder = JSONDecoder()
    }

    func get<T: Decodable & Sendable>(
        _ type: T.Type,
        url: URL,
        timeoutInterval: TimeInterval = 30,
        maxAttempts: Int? = nil
    ) async throws -> T {
        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        request.setValue("Maktabah/1 SefariaNative", forHTTPHeaderField: "User-Agent")
        #if DEBUG && (targetEnvironment(simulator) || SEFARIA_TOC_TRANSPORT_ACCEPTANCE_TESTS)
        SefariaTOCTransportAcceptance.tag(&request)
        #endif
        return try await send(type, request: request, maxAttempts: maxAttempts ?? maximumAttempts)
    }

    func post<T: Decodable & Sendable, Body: Encodable & Sendable>(
        _ type: T.Type, url: URL, body: Body,
        timeoutInterval: TimeInterval = 30, maxAttempts: Int? = nil
    ) async throws -> T {
        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Maktabah/1 SefariaNative", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONEncoder().encode(body)
        return try await send(type, request: request, maxAttempts: maxAttempts ?? maximumAttempts)
    }

    func postData<Body: Encodable & Sendable>(url: URL, body: Body) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url, timeoutInterval: 300)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Maktabah/1 SefariaNative", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONEncoder().encode(body)
        do {
            let (data, response) = try await session.data(for: request)
            try validate(response)
            guard let http = response as? HTTPURLResponse else {
                throw LibraryBackendError.invalidResponse("missing HTTP response")
            }
            return (data, http)
        } catch {
            throw Self.userFacing(error)
        }
    }

    func data(url: URL) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: 120)
        request.setValue("Maktabah/1 SefariaNative", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await session.data(for: request)
            try validate(response)
            return data
        } catch {
            throw Self.userFacing(error)
        }
    }

    func download(url: URL) async throws -> (URL, HTTPURLResponse) {
        var request = URLRequest(url: url, timeoutInterval: 300)
        request.setValue("Maktabah/1 SefariaNative", forHTTPHeaderField: "User-Agent")
        do {
            let (temporary, response) = try await session.download(for: request)
            try validate(response)
            guard let response = response as? HTTPURLResponse else {
                throw LibraryBackendError.invalidResponse("missing HTTP response")
            }
            return (temporary, response)
        } catch {
            throw Self.userFacing(error)
        }
    }

    private func send<T: Decodable>(
        _ type: T.Type,
        request: URLRequest,
        maxAttempts: Int = 3
    ) async throws -> T {
        var attempt = 1
        while true {
            try Task.checkCancellation()
            do {
                let (data, response) = try await session.data(for: request)
                try validate(response)
                do { return try decoder.decode(type, from: data) }
                catch { throw LibraryBackendError.invalidResponse(String(describing: error)) }
            } catch {
                try Task.checkCancellation()
                guard attempt < maxAttempts, Self.isTransient(error) else {
                    throw Self.userFacing(error)
                }
                try await Task.sleep(nanoseconds: UInt64(attempt) * 500_000_000)
                try Task.checkCancellation()
                attempt += 1
            }
        }
    }

    nonisolated static func userFacing(_ error: Error) -> Error {
        guard let urlError = error as? URLError else { return error }
        switch urlError.code {
        case .timedOut, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost,
             .dnsLookupFailed, .notConnectedToInternet, .internationalRoamingOff,
             .dataNotAllowed:
            return LibraryBackendError.unavailableOffline
        default:
            return error
        }
    }

    private nonisolated static func isTransient(_ error: Error) -> Bool {
        if let backendError = error as? LibraryBackendError,
           case .httpStatus(let status) = backendError {
            return status == 429 || status == 500 || status == 502 || status == 503 || status == 504
        }
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .timedOut, .networkConnectionLost, .cannotConnectToHost,
             .dnsLookupFailed, .notConnectedToInternet:
            return true
        default:
            return false
        }
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw LibraryBackendError.invalidResponse("missing HTTP status")
        }
        guard (200...299).contains(http.statusCode) else {
            throw LibraryBackendError.httpStatus(http.statusCode)
        }
    }
}

#if DEBUG && (targetEnvironment(simulator) || SEFARIA_TOC_TRANSPORT_ACCEPTANCE_TESTS)
/// Disposable Simulator acceptance only. This never supplies response bytes:
/// one original Remote TOC request is held and fails at URL Loading; retry
/// returns to the unchanged original transport. Embedded Hermes is not covered.
enum SefariaTOCTransportAcceptance {
    struct Configuration: Sendable {
        let namespace: UUID
        let documents: URL

        var prefix: String { "sefaria-toc-" + namespace.uuidString }
        var commandURL: URL { documents.appendingPathComponent(prefix + "-command.json") }
        func url(nonce: UUID, stage: String) -> URL {
            documents.appendingPathComponent(prefix + "-" + nonce.uuidString + "-" + stage + ".json")
        }
    }

    struct Context: Sendable {
        let configuration: Configuration
        let nonce: UUID
        let workKey: String
        let ownerID: String
        var expectedURL: String { "https://www.sefaria.org/api/v2/raw/index/" + workKey }
    }

    @TaskLocal static var context: Context?

    private final class Admission: @unchecked Sendable {
        private let lock = NSLock()
        private var context: Context?
        private var tagged = false
        private var claimed = false

        func arm(_ value: Context) -> Bool {
            lock.lock(); defer { lock.unlock() }
            guard context == nil else { return false }
            context = value
            return true
        }
        func tag(_ value: Context, request: URLRequest) -> Bool {
            lock.lock(); defer { lock.unlock() }
            guard context?.nonce == value.nonce, !tagged, !claimed,
                  request.httpMethod == nil || request.httpMethod == "GET",
                  request.httpBody == nil, request.url?.absoluteString == value.expectedURL else { return false }
            tagged = true
            return true
        }
        func matches(_ request: URLRequest, claim: Bool) -> Context? {
            lock.lock(); defer { lock.unlock() }
            guard let context, tagged, !claimed,
                  let nonce = URLProtocol.property(forKey: propertyKey, in: request) as? String,
                  nonce == context.nonce.uuidString,
                  request.url?.absoluteString == context.expectedURL,
                  request.httpMethod == nil || request.httpMethod == "GET",
                  request.httpBody == nil else { return nil }
            if claim { claimed = true }
            return context
        }
    }

    private static let propertyKey = "org.maktabah.native-toc-one-shot"
    private static let admission = Admission()

    static let configuration: Configuration? = {
        #if targetEnvironment(simulator)
        let environment = ProcessInfo.processInfo.environment
        guard environment["OTZARIA_DATA_PROFILE"] == "miniTest10",
              Bundle.main.bundleIdentifier == "com.davidpovarsky.chavrusatext",
              ProcessInfo.processInfo.arguments.contains("-SefariaTOCTransportAcceptance"),
              UserDefaults.standard.bool(forKey: "SefariaTOCTransportAcceptance"),
              UserDefaults.standard.string(forKey: "preferredBackend") == "sefaria",
              let namespace = UserDefaults.standard.string(forKey: "studyWorkspaceTestingNamespace")
                .flatMap(UUID.init(uuidString:)),
              let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let canonical = documents.standardizedFileURL.resolvingSymlinksInPath()
        guard canonical.pathComponents.contains("Application"),
              canonical.lastPathComponent == "Documents",
              UUID(uuidString: canonical.deletingLastPathComponent().lastPathComponent) != nil,
              (try? canonical.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { return nil }
        return Configuration(namespace: namespace, documents: canonical)
        #else
        return nil
        #endif
    }()

    private static let configuredSession: URLSession? = {
        guard Self.configuration != nil else { return nil }
        let sessionConfiguration = URLSession.shared.configuration
        sessionConfiguration.protocolClasses = [SefariaTOCFailureURLProtocol.self]
            + (sessionConfiguration.protocolClasses ?? [])
        return URLSession(configuration: sessionConfiguration)
    }()

    static func session(replacingShared session: URLSession) -> URLSession {
        guard session === URLSession.shared else { return session }
        return configuredSession ?? session
    }

    static func tag(_ request: inout URLRequest) {
        guard let context, admission.tag(context, request: request),
              let mutable = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else { return }
        URLProtocol.setProperty(context.nonce.uuidString, forKey: propertyKey, in: mutable)
        request = mutable as URLRequest
        record(context, stage: "tagged")
    }

    static func command(configuration: Configuration) -> UUID? {
        guard let object = object(at: configuration.commandURL),
              Set(object.keys) == Set(["schemaVersion", "namespace", "nonce", "backend", "workKey", "operation"]),
              object["schemaVersion"] as? Int == 1,
              object["namespace"] as? String == configuration.namespace.uuidString,
              object["backend"] as? String == "sefaria",
              object["workKey"] as? String == "Genesis",
              object["operation"] as? String == "reloadOwnedTOC",
              let nonce = (object["nonce"] as? String).flatMap(UUID.init(uuidString:)) else { return nil }
        return nonce
    }

    static func arm(configuration: Configuration, nonce: UUID, ownerID: String) -> Context? {
        let context = Context(configuration: configuration, nonce: nonce,
                              workKey: "Genesis", ownerID: ownerID)
        guard admission.arm(context) else { return nil }
        record(context, stage: "armed")
        return context
    }

    fileprivate static func matching(_ request: URLRequest, claim: Bool) -> Context? {
        admission.matches(request, claim: claim)
    }

    fileprivate static func released(_ context: Context) -> Bool {
        guard let object = object(at: context.configuration.url(nonce: context.nonce, stage: "release")),
              Set(object.keys) == Set(["schemaVersion", "namespace", "nonce", "operation"]),
              object["schemaVersion"] as? Int == 1,
              object["namespace"] as? String == context.configuration.namespace.uuidString,
              object["nonce"] as? String == context.nonce.uuidString,
              object["operation"] as? String == "releaseFault" else { return false }
        return true
    }

    /// Bounded regular-file reads; no preference, response, corpus or cache writes.
    private static func object(at url: URL) -> [String: Any]? {
        guard url.standardizedFileURL == url.resolvingSymlinksInPath().standardizedFileURL,
              let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
              values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, size <= 4_096,
              let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var bytes = Data()
        do {
            while bytes.count <= 4_096 {
                guard let part = try handle.read(upToCount: 4_097 - bytes.count), !part.isEmpty else { break }
                bytes.append(part)
            }
            guard bytes.count <= 4_096 else { return nil }
            return try JSONSerialization.jsonObject(with: bytes) as? [String: Any]
        } catch { return nil }
    }

    fileprivate static func record(_ context: Context, stage: String) {
        guard ["armed", "tagged", "held", "failed", "cancelled", "expired"].contains(stage) else { return }
        let object: [String: Any] = [
            "schemaVersion": 1, "namespace": context.configuration.namespace.uuidString,
            "nonce": context.nonce.uuidString, "backend": "sefaria", "workKey": context.workKey,
            "ownerID": context.ownerID, "stage": stage, "method": "GET",
            "url": context.expectedURL, "timestamp": Date().timeIntervalSince1970,
            "errorCode": stage == "failed" ? URLError.dataNotAllowed.rawValue : 0
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else { return }
        let url = context.configuration.url(nonce: context.nonce, stage: stage)
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        try? data.write(to: url, options: [.atomic])
    }
}

private final class SefariaTOCFailureURLProtocol: URLProtocol {
    /// URLProtocol itself is not Sendable. The worker retains only this lifetime,
    /// whose state and weak callback owner are always accessed under one lock.
    /// A recursive lock permits URL Loading to call stopLoading synchronously
    /// from the failure callback, without allowing a callback after stop returns.
    private final class Lifetime: @unchecked Sendable {
        private let lock = NSRecursiveLock()
        private weak var owner: SefariaTOCFailureURLProtocol?
        private var worker: Task<Void, Never>?
        private var stopped = false
        private var finished = false

        func begin(owner: SefariaTOCFailureURLProtocol) -> Bool {
            lock.lock(); defer { lock.unlock() }
            guard !stopped, !finished, self.owner == nil else { return false }
            self.owner = owner
            return true
        }

        func install(_ task: Task<Void, Never>) {
            lock.lock()
            if stopped || finished {
                lock.unlock()
                task.cancel()
            } else {
                worker = task
                lock.unlock()
            }
        }

        func markHeld(_ context: SefariaTOCTransportAcceptance.Context) -> Bool {
            lock.lock(); defer { lock.unlock() }
            guard !stopped, !finished, owner != nil else { return false }
            SefariaTOCTransportAcceptance.record(context, stage: "held")
            return true
        }

        func complete(_ context: SefariaTOCTransportAcceptance.Context?,
                      stage: String, error: URLError.Code) {
            lock.lock(); defer { lock.unlock() }
            guard !stopped, !finished else { return }
            finished = true
            worker = nil
            guard let owner else { return }
            if let context {
                SefariaTOCTransportAcceptance.record(context, stage: stage)
            }
            owner.client?.urlProtocol(owner, didFailWithError: URLError(error))
            self.owner = nil
        }

        func stop() {
            lock.lock()
            stopped = true
            owner = nil
            let task = worker
            worker = nil
            lock.unlock()
            task?.cancel()
        }
    }

    private let lifetime = Lifetime()

    override class func canInit(with request: URLRequest) -> Bool {
        SefariaTOCTransportAcceptance.matching(request, claim: false) != nil
    }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let lifetime = self.lifetime
        guard lifetime.begin(owner: self) else { return }
        guard let context = SefariaTOCTransportAcceptance.matching(request, claim: true) else {
            lifetime.complete(nil, stage: "cancelled", error: .cancelled)
            return
        }
        let task = Task.detached { [lifetime] in
            guard !Task.isCancelled, lifetime.markHeld(context) else { return }
            let deadline = ContinuousClock.now.advanced(by: .seconds(25))
            while !Task.isCancelled, ContinuousClock.now < deadline {
                if SefariaTOCTransportAcceptance.released(context) {
                    lifetime.complete(context, stage: "failed", error: .dataNotAllowed)
                    return
                }
                do { try await Task.sleep(for: .milliseconds(50)) }
                catch { break }
            }
            lifetime.complete(context, stage: Task.isCancelled ? "cancelled" : "expired",
                              error: .cancelled)
        }
        lifetime.install(task)
    }

    override func stopLoading() {
        lifetime.stop()
    }
}
#endif

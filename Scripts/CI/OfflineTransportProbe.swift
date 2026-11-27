import Foundation

// Independently compiled command-line transport witness. No application module,
// provider override, URLProtocol replacement, proxy setting or private API.
private final class Probe: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private let finished = DispatchSemaphore(value: 0)
    private var bytes = 0
    private var response: HTTPURLResponse?
    private var error: NSError?
    private var transactions: [[String: Any]] = []
    private var redirects: [String] = []
    private var completed = false

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        lock.lock(); self.response = response as? HTTPURLResponse; lock.unlock()
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock(); bytes += data.count; let oversized = bytes > 4 * 1024 * 1024; lock.unlock()
        if oversized { dataTask.cancel() } // Cancellation never qualifies as unavailable transport.
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        lock.lock(); redirects.append(request.url?.absoluteString ?? "missing URL"); lock.unlock()
        completionHandler(nil)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        lock.lock()
        transactions = metrics.transactionMetrics.map { metric in
            let source: String
            switch metric.resourceFetchType {
            case .networkLoad: source = "networkLoad"
            case .localCache: source = "localCache"
            case .serverPush: source = "serverPush"
            default: source = "unknown"
            }
            var value: [String: Any] = ["resourceFetchType": source,
                                       "requestURL": metric.request.url?.absoluteString ?? "",
                                       "reusedConnection": metric.isReusedConnection,
                                       "proxyConnection": metric.isProxyConnection]
            for (name, date) in [("fetchStartUnix", metric.fetchStartDate),
                                  ("domainLookupStartUnix", metric.domainLookupStartDate),
                                  ("connectStartUnix", metric.connectStartDate),
                                  ("connectEndUnix", metric.connectEndDate),
                                  ("requestStartUnix", metric.requestStartDate),
                                  ("responseStartUnix", metric.responseStartDate),
                                  ("responseEndUnix", metric.responseEndDate)] {
                value[name] = date?.timeIntervalSince1970 ?? NSNull()
            }
            return value
        }
        lock.unlock()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock(); self.error = error as NSError?; completed = true; lock.unlock()
        finished.signal()
    }

    func run(url: URL) -> [String: Any] {
        let started = Date().timeIntervalSince1970
        let uptime = ProcessInfo.processInfo.systemUptime
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 10
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: queue)
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 8)
        request.setValue("no-store, no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("OtzariaIndependentTransportObservation/1", forHTTPHeaderField: "User-Agent")
        let task = session.dataTask(with: request)
        task.resume()
        let deadlineExpired = finished.wait(timeout: .now() + 12) != .success
        if deadlineExpired { task.cancel() }
        lock.lock()
        let result: [String: Any] = [
            "startedUnix": started, "finishedUnix": Date().timeIntervalSince1970,
            "startedUptime": uptime, "finishedUptime": ProcessInfo.processInfo.systemUptime,
            "HTTPStatus": response?.statusCode ?? NSNull(), "responseBytes": bytes,
            "errorDomain": error?.domain ?? NSNull(), "errorCode": error?.code ?? NSNull(),
            "errorDescription": error?.localizedDescription ?? NSNull(),
            "transactions": transactions, "redirects": redirects,
            "deadlineExpired": deadlineExpired, "taskCompleted": completed,
            "ephemeral": true, "URLCacheDisabled": true, "waitsForConnectivity": false
        ]
        lock.unlock()
        session.invalidateAndCancel()
        return result
    }
}

@main
private enum TransportMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard arguments.count == 8 else { throw NSError(domain: "ProbeArguments", code: 1) }
        var options: [String: String] = [:]
        for index in stride(from: 0, to: arguments.count, by: 2) {
            guard options[arguments[index]] == nil else { throw NSError(domain: "ProbeArguments", code: 2) }
            options[arguments[index]] = arguments[index + 1]
        }
        guard Set(options.keys) == Set(["--window", "--phase", "--nonce", "--endpoint"]),
              let window = options["--window"], window.range(of: "^[0-9a-f]{32}$", options: .regularExpression) != nil,
              let nonce = options["--nonce"], nonce.range(of: "^[0-9a-f]{32}$", options: .regularExpression) != nil,
              let phase = options["--phase"], ["before", "during", "after"].contains(phase),
              let endpoint = options["--endpoint"] else { throw NSError(domain: "ProbeArguments", code: 3) }
        let endpoints = [
            "github-v40": "https://api.github.com/repos/Otzaria/SeforimLibrary/releases/455390662",
            "sefaria-psalms": "https://www.sefaria.org/api/index/Psalms"
        ]
        guard let base = endpoints[endpoint], let url = URL(string: base + "?otzariaOfflineNonce=" + nonce) else {
            throw NSError(domain: "ProbeArguments", code: 4)
        }
        var result = Probe().run(url: url)
        result["schema"] = "otzaria.foundation-transport-probe/1"
        result["windowID"] = window
        result["phase"] = phase
        result["nonce"] = nonce
        result["endpoint"] = endpoint
        result["requestedURL"] = url.absoluteString
        result["processID"] = ProcessInfo.processInfo.processIdentifier
        #if targetEnvironment(simulator)
        result["environment"] = "simulator"
        result["simulatorUDID"] = ProcessInfo.processInfo.environment["SIMULATOR_UDID"] ?? NSNull()
        #elseif os(macOS)
        result["environment"] = "host"
        result["simulatorUDID"] = NSNull()
        #else
        throw NSError(domain: "ProbePlatform", code: 1)
        #endif
        let data = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data([10]))
    }
}

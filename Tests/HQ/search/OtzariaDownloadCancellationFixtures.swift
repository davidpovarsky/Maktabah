@MainActor final class TransferResult { var outcome: String? }
@main struct OtzariaDownloadCancellationFixtures {
    static func classify(_ error: Error) -> String {
        if error is CancellationError { return "cancelled" }
        if (error as? URLError)?.code == .cancelled { return "cancelled" }
        return String(describing:error)
    }
    @MainActor static func main() async throws {
        let root=URL(fileURLWithPath:CommandLine.arguments[1],isDirectory:true)
        let base=URL(string:CommandLine.arguments[2])!
        var cases:[[String:String]]=[]
        func check(_ name:String,_ value:Bool) {
            print((value ? "PASS " : "FAIL ")+name)
            cases.append(["name":name,"status":value ? "PASS" : "FAIL"])
        }
        func wait(_ seconds:Double,_ predicate:()->Bool) async {
            let until=Date().addingTimeInterval(seconds)
            while !predicate() && Date()<until {try? await Task.sleep(nanoseconds:20_000_000)}
        }
        func setup(_ name:String)->(OtzariaArtifactDownloadDelegate,URLSession,URLSessionDataTask) {
            let delegate=OtzariaArtifactDownloadDelegate(outputURL:root.appendingPathComponent(name+".part"),
                requestedOffset:0,expectedBytes:1,progress:{_ in})
            let queue=OperationQueue();queue.maxConcurrentOperationCount=1
            let session=URLSession(configuration:.ephemeral,delegate:delegate,delegateQueue:queue)
            return (delegate,session,session.dataTask(with:base.appendingPathComponent(name)))
        }
        let (delegate,session,network)=setup("held")
        let first=TransferResult()
        let call=Task { @MainActor in
            do {_ = try await delegate.run(task:network);first.outcome="unexpected-success"}
            catch {first.outcome=classify(error)}
        }
        await wait(5) {FileManager.default.fileExists(atPath:root.appendingPathComponent("held.started").path)}
        check("actual URLSession reaches held HTTP server",
            FileManager.default.fileExists(atPath:root.appendingPathComponent("held.started").path))
        let began=Date()
        call.cancel()
        await wait(2) {first.outcome != nil}
        let elapsed=Date().timeIntervalSince(began)
        check("caller cancellation aborts held network before release",first.outcome=="cancelled")
        network.cancel();await call.value;session.invalidateAndCancel()

        // Deterministic terminal-callback/continuation ordering boundary.
        // This callback is injected; it is distinct from the actual HTTP case.
        let (earlyDelegate,earlySession,earlyNetwork)=setup("early")
        earlyDelegate.urlSession(earlySession,task:earlyNetwork,didCompleteWithError:URLError(.cancelled))
        let early=TransferResult()
        let earlyCall=Task { @MainActor in
            do {_ = try await earlyDelegate.run(task:earlyNetwork);early.outcome="unexpected-success"}
            catch {early.outcome=classify(error)}
        }
        await wait(0.5) {early.outcome != nil}
        check("terminal callback before continuation is retained",early.outcome=="cancelled")
        check("already terminal delegate does not start a request",
            !FileManager.default.fileExists(atPath:root.appendingPathComponent("early.started").path))
        earlyNetwork.cancel();await earlyCall.value;earlySession.invalidateAndCancel()

        let (preDelegate,preSession,preNetwork)=setup("precancel")
        let pre=TransferResult();let barrier=AsyncStream<Void>.makeStream()
        let preCall=Task { @MainActor in
            for await _ in barrier.stream {break}
            do {_ = try await preDelegate.run(task:preNetwork);pre.outcome="unexpected-success"}
            catch {pre.outcome=classify(error)}
        }
        preCall.cancel();barrier.continuation.finish()
        await wait(0.5) {pre.outcome != nil}
        check("pre-cancelled caller returns promptly",pre.outcome=="cancelled")
        check("pre-cancelled caller starts no network request",
            !FileManager.default.fileExists(atPath:root.appendingPathComponent("precancel.started").path))
        preNetwork.cancel();await preCall.value;preSession.invalidateAndCancel()
        let failed=cases.filter{$0["status"]=="FAIL"}.count
        let report:[String:Any]=["total":cases.count,"passed":cases.count-failed,"failed":failed,
            "cases":cases,"held_cancellation_seconds":elapsed,"actual_http_case":true,
            "terminal_ordering_case":"injected callback, not real network completion",
            "native_ui_executed":0,"archive_verified":false,"engine_opened":false]
        try JSONSerialization.data(withJSONObject:report,options:[.sortedKeys,.prettyPrinted])
            .write(to:root.appendingPathComponent("RESULT.json"))
        if failed>0 {exit(1)}
    }
}

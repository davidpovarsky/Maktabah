import Foundation

@MainActor final class CompletionEvidence {
    var first: String?
    var second: String?
}
@main struct RunTransfer {
    @MainActor static func main() async throws {
        let arguments=CommandLine.arguments
        let owned=URL(fileURLWithPath:arguments[1],isDirectory:true)
        let index=URL(fileURLWithPath:arguments[2],isDirectory:true)
        let manifestData=try Data(contentsOf:URL(fileURLWithPath:arguments[3]))
        let manifest=try JSONDecoder().decode(ZayitSearchArtifactManifest.self,from:manifestData)
        FixtureWorld.root=owned.appendingPathComponent("state",isDirectory:true)
        let storage=try ZayitSearchArtifactStorage()
        try FileManager.default.createDirectory(at:storage.root,withIntermediateDirectories:true)
        try FileManager.default.copyItem(at:index,to:storage.finalIndex)
        try manifestData.write(to:storage.installedManifest)
        let originalMeta=try Data(contentsOf:storage.finalIndex.appendingPathComponent("meta.json"))
        let service=ZayitSearchArtifactService(manifest,URL(string:arguments[4])!)
        let source=owned.appendingPathComponent("authority-boundary-source")
        let completion=CompletionEvidence()
        var results:[[String:String]]=[]
        func record(_ name:String,_ passed:Bool) {
            print((passed ? "PASS " : "FAIL ")+name)
            results.append(["name":name,"status":passed ? "PASS" : "FAIL"])
        }
        func wait(seconds:Double,until predicate:() -> Bool) async throws -> Bool {
            let end=Date().addingTimeInterval(seconds)
            while !predicate() && Date()<end {try await Task.sleep(for:.milliseconds(40))}
            return predicate()
        }
        let first=Task { @MainActor in
            do {try await service.install(databaseURL:source,lexicalDatabaseURL:source){_ in};completion.first="unexpected-success"}
            catch {completion.first=String(describing:error)}
        }
        let actualHTTPStarted=try await wait(seconds:20) {
            FileManager.default.fileExists(atPath:owned.appendingPathComponent("http-request-1.json").path)
        }
        guard actualHTTPStarted else {throw NSError(domain:"NoActualHTTPRequest",code:1)}
        record("actual URLSession request reaches held HTTP server",actualHTTPStarted)
        _=await service.status(databaseURL:source)
        record("status during actual transfer preserves staging",
               FileManager.default.fileExists(atPath:storage.installingIndex.path))
        let second=Task { @MainActor in
            do {try await service.install(databaseURL:source,lexicalDatabaseURL:source){_ in};completion.second="unexpected-success"}
            catch {completion.second=String(describing:error)}
        }
        _=try await wait(seconds:1.5) {completion.second != nil}
        record("second installation is rejected before another download",
               completion.second?.contains("operationInProgress")==true
               && !FileManager.default.fileExists(atPath:owned.appendingPathComponent("http-request-2.json").path))
        var refused=false
        do {try await service.remove()} catch {refused=String(describing:error).contains("operationInProgress")}
        record("remove refuses to race active installation",refused)
        let retained=try? Data(contentsOf:storage.finalIndex.appendingPathComponent("meta.json"))
        record("original installed index survives rejected removal",retained==originalMeta)
        let cancellationStarted=Date()
        await service.cancel()
        let promptlyFinished=try await wait(seconds:2) {completion.first != nil}
        record("cancel aborts held URLSession before response release",
               promptlyFinished && completion.first?.contains("cancelled")==true)
        let cancellationDuration=Date().timeIntervalSince(cancellationStarted)
        try Data("cleanup release only after cancellation assertion".utf8).write(to:owned.appendingPathComponent("release-all"))
        await first.value;await second.value
        record("cancelled operation cannot report successful promotion",
               completion.first?.contains("cancelled")==true && completion.first != "unexpected-success")
        let failed=results.filter{$0["status"]=="FAIL"}.count
        let report:[String:Any]=["total":results.count,"passed":results.count-failed,"failed":failed,"cases":results,
                               "first_outcome":completion.first ?? "missing","second_outcome":completion.second ?? "missing",
                               "cancellation_observation_seconds":cancellationDuration,"native_ui_executed":0]
        try JSONSerialization.data(withJSONObject:report,options:[.sortedKeys,.prettyPrinted])
            .write(to:owned.appendingPathComponent("RESULT.json"))
        if failed>0 {exit(1)}
    }
}

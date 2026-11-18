import Foundation

@MainActor final class InstallOutcomes {
    var first: String?
    var second: String?
    var recovered = false
}
@main struct OtzariaInstallOwnershipFixtures {
    @MainActor static func main() async throws {
        FixtureWorld.root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        FixtureWorld.manifest = try JSONDecoder().decode(OtzariaSearchArtifactManifest.self,
            from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])))
        let service = OtzariaSearchArtifactService()
        let storage = try OtzariaSearchArtifactStorage()
        try storage.prepare()
        guard let artifact = FixtureWorld.manifest else { throw NSError(domain: "MissingVerifiedFixtureManifest", code: 1) }
        let workspace = storage.workspaceURL(artifactIdentity: artifact.artifactIdentity)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        let retainedParts = artifact.lexicalArtifact.parts.prefix(2).map {
            workspace.appendingPathComponent("\($0.sha256).part")
        }
        for url in retainedParts { try Data([7]).write(to: url) }
        let final = OtzariaSearchIndexManager.shared.indexURL(for: "fixture.db")
        try FileManager.default.createDirectory(at: final, withIntermediateDirectories: true)
        let marker = final.appendingPathComponent("owned-test-marker")
        try Data("prior-fixture-state".utf8).write(to: marker)
        var cases: [[String: String]] = []
        func check(_ name: String, _ pass: Bool) {
            print((pass ? "PASS " : "FAIL ") + name)
            cases.append(["name":name,"status":pass ? "PASS" : "FAIL"])
        }
        func wait(_ seconds: Double, _ predicate: () -> Bool) async {
            let until = Date().addingTimeInterval(seconds)
            while !predicate() && Date() < until { try? await Task.sleep(for: .milliseconds(20)) }
        }
        _ = try await service.checkAvailability(databasePath: "fixture.db")
        check("availability retains all existing partial downloads",
            retainedParts.allSatisfy { FileManager.default.fileExists(atPath:$0.path) })
        let outcomes = InstallOutcomes()
        let first = Task { @MainActor in
            do { _ = try await service.install(databasePath:"fixture.db") { _ in }; outcomes.first = "unexpected-success" }
            catch { outcomes.first = String(describing:error) }
        }
        let started = FixtureWorld.root.appendingPathComponent("started-1")
        await wait(3) { FileManager.default.fileExists(atPath:started.path) }
        check("admitted operation reaches controlled transfer",
            FileManager.default.fileExists(atPath:started.path))
        let installing = storage.stagingURL(databasePath:"fixture.db")
        let originalStage = installing.appendingPathComponent("first-owner")
        let originalStageData = try Data(contentsOf:originalStage)
        let recovery = Task { @MainActor in
            await FixtureReadiness.recover(service:service,path:"fixture.db",storage:storage)
            outcomes.recovered = true
        }
        try await Task.sleep(for:.milliseconds(100))
        check("status recovery preserves active staging",
            FileManager.default.fileExists(atPath:originalStage.path))
        let second = Task { @MainActor in
            do { _ = try await service.install(databasePath:"fixture.db") { _ in }; outcomes.second = "unexpected-success" }
            catch { outcomes.second = String(describing:error) }
        }
        await wait(0.5) { outcomes.second != nil }
        check("second installation is refused before second transfer",
            outcomes.second?.contains("operationInProgress") == true
            && !FileManager.default.fileExists(atPath:FixtureWorld.root.appendingPathComponent("started-2").path))
        check("active staging retains its first owner",
            (try? Data(contentsOf:originalStage)) == originalStageData)
        // Caller cancellation must reach any owned child task. The transfer
        // double cooperates with task cancellation; actual URLSession is separate.
        first.cancel()
        await service.cancel()
        await wait(2) { outcomes.first != nil }
        check("cancelled admitted operation finishes",outcomes.first?.contains("cancel") == true
            || outcomes.first?.contains("CancellationError") == true)
        await FixtureGate.shared.finish()
        await first.value; await second.value; await recovery.value
        check("recovery returns after operation finishes",outcomes.recovered)
        check("prior final fixture remains unchanged",
            (try? Data(contentsOf:marker)) == Data("prior-fixture-state".utf8))
        let failed=cases.filter{$0["status"]=="FAIL"}.count
        let result: [String:Any] = ["cases":cases,"total":cases.count,
            "passed":cases.count-failed,"failed":failed,
            "first":outcomes.first ?? "missing","second":outcomes.second ?? "missing",
            "native_ui_executed":0,"real_network_executed":0,"real_engine_executed":0]
        try JSONSerialization.data(withJSONObject:result,options:[.sortedKeys,.prettyPrinted])
            .write(to:FixtureWorld.root.appendingPathComponent("RESULT.json"))
        if failed > 0 { exit(1) }
    }
}

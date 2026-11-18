#!/usr/bin/env python3
"""Exact original artifact-service control flow with explicit provider/transfer/engine boundaries.
Actual filesystem and Swift actor/task scheduling. No network, archive, index or Native acceptance.
"""
from pathlib import Path
import argparse,datetime,hashlib,json,os,runpy,subprocess,uuid
ROOT=Path(__file__).resolve().parents[1]
method=runpy.run_path(str(ROOT/"tools/hq-zayit-package-readiness.py"))["method"]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    ap=argparse.ArgumentParser();ap.add_argument("--artifacts-dir",required=True,type=Path);ap.add_argument("--baseline")
    args=ap.parse_args();out=args.artifacts_dir.resolve();out.mkdir(parents=True,exist_ok=True)
    manifest=ROOT/"Tests/HQ/search/Fixtures/otzaria-miniTest10-v6-manifest.json"
    assert sha(manifest)=="ae3bd170dc4650806a9fdda1beefe682eeefb5abde886363d6feac999603f8d4"
    owned=ROOT/"build"/("oio-"+uuid.uuid4().hex[:12]);owned.mkdir()
    paths=["Source/Otzaria/Search/Distribution/OtzariaSearchArtifactService.swift",
        "Source/Otzaria/Search/Distribution/OtzariaSearchArtifactDownloader.swift",
        "Source/Otzaria/Search/Distribution/OtzariaSearchArtifactInstaller.swift",
        "Source/Otzaria/Search/Distribution/OtzariaSearchArtifactManifest.swift",
        "Source/Otzaria/Search/OtzariaTextSearchViewModel.swift"]
    raw={p:subprocess.check_output(["git","show",args.baseline+":"+p],cwd=ROOT) if args.baseline else (ROOT/p).read_bytes() for p in paths}
    text={p:b.decode("utf-8-sig") for p,b in raw.items()}
    service=text[paths[0]];context=method(service,"    func context(")
    service=service.replace(context,"    func context(databasePath: String) throws -> Context { .init(databaseManifest: 0, databaseBytes: 1, build: 0) }")
    models=text[paths[3]].split("extension OtzariaSearchArtifactError:",1)[0]
    downloader=text[paths[1]];installer=text[paths[2]]
    downloader_methods="\n".join(method(downloader,"    func "+name+"(") for name in ["existingBytes","prepareStreamingWorkspace"])
    downloader_methods+="\n"+method(downloader,"    func partURL(")+"\n"+method(downloader,"    func fileSize(")
    recover=method(installer,"    func recover(")
    vm=text[paths[4]]
    if "await artifactService.recoverInterruptedInstallation(" in vm:
        line=next(l.strip() for l in vm.splitlines() if "await artifactService.recoverInterruptedInstallation(" in l)
        recovery=line.replace("artifactService.","service.")
    else:
        line=next(l.strip() for l in vm.splitlines() if "OtzariaSearchArtifactInstaller().recover(" in l)
        recovery=line
    boundary=r"""
import Foundation
enum FixtureWorld {
    nonisolated(unsafe) static var root = URL(fileURLWithPath:"unused")
    nonisolated(unsafe) static var manifest: OtzariaSearchArtifactManifest!
}
enum OtzariaDataProfileRegistry {
    static let productionID = "production"
    static let activeProfileID = "miniTest10"
}
typealias OtzariaDatabaseInstallationManifest = Int
typealias OtzariaSearchEngineBuildInfo = Int
enum OtzariaIndexFileLogger {
    static func log(_ value:String) {}
    static func logError(_ value:String,error:Error) {}
}
struct FixtureFingerprint: Equatable, Sendable { let path:String }
final class OtzariaSearchIndexManager: Sendable {
    static let shared=OtzariaSearchIndexManager()
    func indexURL(for path:String)->URL { FixtureWorld.root.appendingPathComponent("final") }
    func previousIndexURL(for path:String)->URL { FixtureWorld.root.appendingPathComponent("previous") }
    func currentFingerprint(databasePath:String)throws->FixtureFingerprint { .init(path:databasePath) }
}
struct OtzariaSearchArtifactStorage: Sendable {
    let indexRootURL=FixtureWorld.root
    let downloadsRootURL=FixtureWorld.root.appendingPathComponent("downloads")
    init() throws {}
    func prepare() throws {
        try FileManager.default.createDirectory(at:indexRootURL,withIntermediateDirectories:true)
        try FileManager.default.createDirectory(at:downloadsRootURL,withIntermediateDirectories:true)
    }
    func workspaceURL(artifactIdentity:String)->URL { downloadsRootURL.appendingPathComponent(artifactIdentity) }
    func stagingURL(databasePath:String)->URL { FixtureWorld.root.appendingPathComponent("installing") }
    func availableCapacity()->Int64 { Int64.max }
}
enum OtzariaSearchArtifactPolicy {
    static func requiredInstallCapacity(manifest:OtzariaSearchArtifactManifest,alreadyDownloadedBytes:Int64,existingFinalBytes:Int64)->Int64 { 1 }
}
struct OtzariaSearchArtifactReleaseClient: Sendable {
    func matchingArtifact(database:Int,databaseBytes:Int64,build:Int) async throws -> OtzariaResolvedSearchArtifact {
        .init(releaseID:410332048,releaseTag:"otzaria-miniTest10-v6",manifest:FixtureWorld.manifest,
              partURLs:Dictionary(uniqueKeysWithValues:FixtureWorld.manifest.lexicalArtifact.parts.map { ($0.assetName,URL(string:"https://fixture.invalid/"+$0.assetName)!) }))
    }
}
actor FixtureGate {
    static let shared=FixtureGate()
    private let stream=AsyncStream<Void>.makeStream()
    private var started=0
    func waitForCancellation() async throws -> URL {
        started += 1
        try Data("controlled-transfer".utf8).write(to:FixtureWorld.root.appendingPathComponent("started-\(started)"))
        for await _ in stream.stream { break }
        try Task.checkCancellation()
        throw OtzariaSearchArtifactError.cancelled
    }
    func finish() { stream.continuation.finish() }
}
actor OtzariaSearchArtifactDownloader {
"""
    boundary+=downloader_methods+r"""
    func downloadAndVerifyPart(artifact:OtzariaResolvedSearchArtifact,part:OtzariaSearchArtifactManifest.Part,
        workspaceURL:URL,progress:@escaping @Sendable(Int64)->Void) async throws ->URL {
        try await FixtureGate.shared.waitForCancellation()
    }
    func cleanup(workspaceURL:URL) { try? FileManager.default.removeItem(at:workspaceURL) }
    func cancel() async { await FixtureGate.shared.finish() }
}
struct OtzariaSearchArtifactInstaller: Sendable {
    func installStreaming(artifact:OtzariaResolvedSearchArtifact,databasePath:String,storage:OtzariaSearchArtifactStorage,
        validateContext:@escaping @Sendable()throws->Void = {},
        downloadPart:@escaping @Sendable(OtzariaSearchArtifactManifest.Part)async throws->URL,
        progress:@escaping @Sendable(Int64,Int64)->Void) async throws->UInt64 {
        try validateContext()
        let stage=storage.stagingURL(databasePath:databasePath)
        if FileManager.default.fileExists(atPath:stage.path) { try FileManager.default.removeItem(at:stage) }
        try FileManager.default.createDirectory(at:stage,withIntermediateDirectories:true)
        try Data(UUID().uuidString.utf8).write(to:stage.appendingPathComponent("first-owner"))
        defer { try? FileManager.default.removeItem(at:stage) }
        _ = try await downloadPart(artifact.manifest.lexicalArtifact.parts[0])
        fatalError("Extraction/promotion must remain unexecuted")
    }
"""
    boundary+=recover+"\n}\nenum FixtureReadiness {\nstatic func recover(service:OtzariaSearchArtifactService,path:String,storage:OtzariaSearchArtifactStorage) async {\nlet profile=OtzariaDataProfileRegistry.activeProfileID\n"+recovery+"\n}\n}\n"
    (owned/"Service.swift").write_bytes(service.encode("utf-8"))
    (owned/"Models.swift").write_bytes(models.encode("utf-8"))
    (owned/"Boundary.swift").write_bytes(boundary.encode("utf-8"))
    fixture=ROOT/"Tests/HQ/search/OtzariaInstallOwnershipFixtures.swift"
    exe=owned/("ownership.exe" if os.name=="nt" else "ownership")
    command=["swiftc","-parse-as-library","-swift-version","6","-strict-concurrency=complete",
        str(owned/"Service.swift"),str(owned/"Models.swift"),str(owned/"Boundary.swift"),str(fixture),"-o",str(exe)]
    report=dict(observed_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),
        source_ref=args.baseline or subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip(),
        source_sha256={p:hashlib.sha256(b).hexdigest() for p,b in raw.items()},
        fixture_sha256=sha(fixture),manifest_sha256=sha(manifest),owned_fixture=str(owned),
        original_vm_recovery_line=line,generated_service_sha256=sha(owned/"Service.swift"),
        boundaries=["Original complete service except context provider/storage authority method",
            "Exact downloader partial-file observation/cleanup methods, real filesystem",
            "Controlled async transfer/installer, no real archive or engine",
            "Actual VM recovery invocation and exact installer recovery body; no UI/Combine pipeline",
            "Capacity/provenance/logging context are explicit test doubles"],
        native_ui_executed=0,real_network_executed=0,real_engine_executed=0)
    build=subprocess.run(command,capture_output=True,text=True,encoding="utf-8",timeout=120)
    (out/"compile.log").write_bytes((build.stdout+build.stderr).encode("utf-8"));report["compile_exit"]=build.returncode
    code=build.returncode
    if code:print(build.stderr[-6000:])
    else:
        run=subprocess.run([str(exe),str(owned/"state"),str(manifest)],capture_output=True,text=True,encoding="utf-8",timeout=30)
        (out/"tests.log").write_bytes((run.stdout+run.stderr).encode("utf-8"));print(run.stdout);print(run.stderr[-3000:])
        code=run.returncode;report["execute_exit"]=code
        if (owned/"state/RESULT.json").exists():report["cases"]=json.loads((owned/"state/RESULT.json").read_text(encoding="utf-8"))
    report["status"]="CONTROL_OWNERSHIP_PASS_NOT_NATIVE" if code==0 else "FAILED"
    (out/"RESULT.json").write_bytes((json.dumps(report,indent=2)+"\n").encode("utf-8"))
    print(json.dumps({"status":report["status"],"cases":report.get("cases",{})}));return code
if __name__=="__main__":raise SystemExit(main())

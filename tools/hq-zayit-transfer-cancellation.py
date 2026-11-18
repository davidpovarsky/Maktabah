#!/usr/bin/env python3
"""Exact production install/download/cancel methods against a held loopback HTTP response.

Real URLSession and actual filesystem; provider resolution, lexical authorization,
capacity and successful extraction are explicit boundaries. No app/Native claim.
"""
from pathlib import Path
import argparse,datetime,hashlib,http.server,json,os,runpy,shutil,subprocess,threading,time,uuid
ROOT=Path(__file__).resolve().parents[1]
method=runpy.run_path(str(ROOT/"tools/hq-zayit-package-readiness.py"))["method"]
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    parser=argparse.ArgumentParser();parser.add_argument("--artifacts-dir",type=Path,required=True)
    parser.add_argument("--baseline");args=parser.parse_args()
    out=args.artifacts_dir.resolve();out.mkdir(parents=True,exist_ok=True)
    fixture=ROOT/"build/hq-zayit-official-mini-v6"
    manifest_path=fixture/"zayit-search-manifest.json"
    if digest(manifest_path)!="3c7dd1358954ac8a026dcdb575b404afe1ea2d37a6aebe0523cc5617fc47bc7d":
        raise RuntimeError("Run the official readiness fixture preparation first")
    manifest=json.loads(manifest_path.read_text(encoding="utf-8"))
    source_path="Source/ZayitSearch/ZayitSearchDistribution.swift"
    raw=subprocess.check_output(["git","show",args.baseline+":"+source_path],cwd=ROOT) if args.baseline else (ROOT/source_path).read_bytes()
    source=raw.decode("utf-8-sig")
    owned=ROOT/"build"/("ztf-"+uuid.uuid4().hex[:12]);owned.mkdir()
    snippets={}
    for name in ["status","installedManifest","validateStaging","install","cancel","remove","download","checkCancellation","fileSize"]:
        snippets[name]=method(source,"    func "+name+"(")
    if "    private func performInstall(" in source:
        snippets["performInstall"]=method(source,"    private func performInstall(")
    models=source[source.index("struct ZayitSearchArtifactManifest:"):source.index("extension ZayitSearchDistributionError:")]
    storage=source[source.index("struct ZayitSearchArtifactStorage:"):source.index("    func availableCapacity()")]
    safe_source=(ROOT/"Source/Otzaria/Search/Distribution/OtzariaSearchArtifactPolicy.swift").read_text(encoding="utf-8")
    safe=method(safe_source,"    static func validateSafeRelativePath(")
    fields="\n".join(line for line in source.splitlines() if line.strip().startswith(("private var activeTask:","private var installTask:","private var cancelled =")))
    generated=owned/"ActualTransferMethods.swift"
    body="import Foundation\n#if canImport(FoundationNetworking)\nimport FoundationNetworking\n#endif\n"+models+"\n"+storage+"""
    func availableCapacity() -> Int64 { Int64.max }
    private func exclude(_ url: URL) throws {}
}
enum OtzariaSearchArtifactPolicy {
"""+safe+"\n}\n"+"""
actor ZayitSearchArtifactService {
    let fixtureManifest: ZayitSearchArtifactManifest
    let remoteBase: URL
    typealias Progress = @Sendable (ZayitSearchPackageState) -> Void
    init(_ manifest: ZayitSearchArtifactManifest, _ remote: URL) { fixtureManifest=manifest; remoteBase=remote }
"""+fields+"\n"+"\n".join(snippets.values())+"""
    func resolveArtifact(matching databaseURL: URL?) async throws -> FixtureTransferArtifact {
        .init(manifest:fixtureManifest,partURLs:Dictionary(uniqueKeysWithValues:fixtureManifest.parts.map{($0.assetName,remoteBase.appendingPathComponent($0.assetName))}))
    }
    func validateCompatibility(_ manifest: ZayitSearchArtifactManifest, databaseURL: URL) throws {}
    func validateLexicalDatabase(_ manifest: ZayitSearchArtifactManifest, url: URL) throws { try checkCancellation() }
    func verify(_ url: URL, part: ZayitSearchArtifactManifest.Part) throws {
        try checkCancellation()
        fatalError("This held-response test must cancel before archive verification")
    }
    func extract(_ part: ZayitSearchArtifactManifest.Part, archive: URL, root: URL, progress: @escaping @Sendable (Int64) -> Void) throws { fatalError("Extraction boundary must remain unexecuted") }
    func promote(storage: ZayitSearchArtifactStorage, manifest: ZayitSearchArtifactManifest) throws { fatalError("Promotion boundary must remain unexecuted") }
}
"""
    generated.write_text(body,encoding="utf-8")
    support=(ROOT/"Tests/HQ/search/ZayitPackageReadinessFixtures.swift").read_text(encoding="utf-8").split("@main struct RunReadiness",1)[0]
    (owned/"FixtureAuthority.swift").write_text(support+"\nstruct FixtureTransferArtifact: Sendable {let manifest:ZayitSearchArtifactManifest;let partURLs:[String:URL]}\n",encoding="utf-8")
    executable=owned/("transfer.exe" if os.name=="nt" else "transfer")
    command=["swiftc","-parse-as-library","-swift-version","6","-strict-concurrency=complete",str(generated),str(owned/"FixtureAuthority.swift"),
             str(ROOT/"Source/ZayitSearch/ZayitInstallCapacityPolicy.swift"),
             str(ROOT/"Tests/HQ/search/ZayitTransferCancellationFixtures.swift"),"-o",str(executable)]
    build=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,encoding="utf-8",timeout=120)
    (out/"compile.log").write_text(build.stdout+build.stderr,encoding="utf-8")
    report={"observed_at":datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "source_ref":args.baseline or subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip(),
            "source_sha256":hashlib.sha256(raw).hexdigest(),"test_sha256":digest(ROOT/"Tests/HQ/search/ZayitTransferCancellationFixtures.swift"),
            "methods_sha256":{k:hashlib.sha256(v.encode()).hexdigest() for k,v in snippets.items()},
            "compile_exit":build.returncode,"native_ui_executed":0,"real_urlsession":True,"owned_fixture":str(owned),
            "boundaries":["Exact original selected method bodies; real local HTTP connection and filesystem",
                          "Provider resolution, lexical DB authority, capacity, backup attribute and storage lock are explicit doubles",
                          "Archive verification must receive cancellation; extraction/promotion fail immediately if unexpectedly called"]}
    code=build.returncode
    if code==0:
        requests=[];lock=threading.Lock();stop=threading.Event()
        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                name=self.path.strip("/")
                part=next((p for p in manifest["parts"] if p["assetName"]==name),None)
                if part is None:self.send_error(404);return
                with lock:
                    number=len(requests)+1;requests.append({"request":number,"asset":name,"started_at":time.time()})
                    (owned/f"http-request-{number}.json").write_text(json.dumps(requests[-1]),encoding="utf-8")
                deadline=time.monotonic()+25
                while not stop.is_set() and not (owned/"release-all").exists() and time.monotonic()<deadline:
                    stop.wait(.05)
                if stop.is_set():return
                data=(fixture/name).read_bytes()
                try:
                    self.send_response(200);self.send_header("Content-Length",str(len(data)));self.end_headers();self.wfile.write(data)
                except (BrokenPipeError,ConnectionResetError,ConnectionAbortedError):pass
            def log_message(self,*args):pass
        server=http.server.ThreadingHTTPServer(("127.0.0.1",0),Handler);server.daemon_threads=True
        thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
        try:
            run=subprocess.run([str(executable),str(owned),str(fixture/"index"),str(manifest_path),
                                f"http://127.0.0.1:{server.server_address[1]}"],cwd=ROOT,capture_output=True,text=True,encoding="utf-8",timeout=90)
            (out/"tests.log").write_text(run.stdout+run.stderr,encoding="utf-8");print(run.stdout);code=run.returncode
            report["execute_exit"]=code
            if (owned/"RESULT.json").is_file():report["cases"]=json.loads((owned/"RESULT.json").read_text(encoding="utf-8"))
        finally:
            stop.set();server.shutdown();server.server_close()
        report["actual_http_requests"]=requests
    else:print(build.stderr[-6000:])
    report["status"]="REAL_TRANSFER_CONTROL_PASS_NOT_NATIVE" if code==0 else "FAILED"
    (out/"RESULT.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"status":report["status"],"compile_exit":build.returncode,"cases":report.get("cases",{})}))
    return code
if __name__=="__main__":raise SystemExit(main())

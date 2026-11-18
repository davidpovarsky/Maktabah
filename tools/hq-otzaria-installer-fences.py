#!/usr/bin/env python3
"""Whole original installer and actual file promotion/rollback, explicit engine/extractor doubles."""
from pathlib import Path
import argparse,datetime,hashlib,json,os,runpy,subprocess,uuid
ROOT=Path(__file__).resolve().parents[1]
method=runpy.run_path(str(ROOT/"tools/hq-zayit-package-readiness.py"))["method"]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    ap=argparse.ArgumentParser();ap.add_argument("--artifacts-dir",required=True,type=Path);ap.add_argument("--baseline")
    args=ap.parse_args();out=args.artifacts_dir.resolve();out.mkdir(parents=True,exist_ok=True)
    owned=ROOT/"build"/("oif-"+uuid.uuid4().hex[:12]);owned.mkdir()
    path="Source/Otzaria/Search/Distribution/OtzariaSearchArtifactInstaller.swift"
    raw=subprocess.check_output(["git","show",args.baseline+":"+path],cwd=ROOT) if args.baseline else (ROOT/path).read_bytes()
    source=raw.decode("utf-8-sig");body=source[source.index("struct OtzariaSearchArtifactInstaller:"):]
    (owned/"Installer.swift").write_bytes(("import Foundation\n"+body).encode("utf-8"))
    modelpath="Source/Otzaria/Search/Distribution/OtzariaSearchArtifactManifest.swift"
    models=(subprocess.check_output(["git","show",args.baseline+":"+modelpath],cwd=ROOT).decode("utf-8-sig") if args.baseline
        else (ROOT/modelpath).read_text(encoding="utf-8-sig")).split("extension OtzariaSearchArtifactError:",1)[0]
    (owned/"Models.swift").write_bytes(models.encode("utf-8"))
    policy=(ROOT/"Source/Otzaria/Search/Distribution/OtzariaSearchArtifactPolicy.swift").read_text(encoding="utf-8-sig")
    safe=method(policy,"    static func validateSafeRelativePath(")
    servicepath=ROOT/"Source/Otzaria/Search/Distribution/OtzariaSearchArtifactService.swift"
    service=servicepath.read_text(encoding="utf-8-sig")
    capture=service[service.index("        let profile = OtzariaDataProfileRegistry.activeProfileID",service.index("    func install(")):service.index("        let task = Task {",service.index("    func install("))]
    has_fence="validateContext:" in body[body.index("    func installStreaming("):body.index("    func recover(")]
    call='validateContext: validateContext,\n' if has_fence else ''
    invoke="import Foundation\nenum OtzariaSearchArtifactPolicy {\n"+safe+"\n}\nenum FixtureInvocation {\nstatic func install(_ artifact:OtzariaResolvedSearchArtifact) async throws->UInt64 {\nlet databasePath=\"fixture-database\"\n"
    if has_fence:invoke+=capture
    invoke+='return try await OtzariaSearchArtifactInstaller().installStreaming(artifact:artifact,databasePath:databasePath,storage:OtzariaSearchArtifactStorage(),\n'+call+'downloadPart:{ try await FixtureTransfer.download($0) },progress:{_,_ in})\n}\n}\n'
    (owned/"Invocation.swift").write_bytes(invoke.encode("utf-8"))
    fixture=ROOT/"Tests/HQ/search/OtzariaInstallerFenceFixtures.swift"
    manifest=ROOT/"Tests/HQ/search/Fixtures/otzaria-miniTest10-v6-manifest.json"
    assert sha(manifest)=="ae3bd170dc4650806a9fdda1beefe682eeefb5abde886363d6feac999603f8d4"
    exe=owned/("installer.exe" if os.name=="nt" else "installer")
    command=["swiftc","-parse-as-library","-swift-version","6","-strict-concurrency=complete",
        str(owned/"Installer.swift"),str(owned/"Models.swift"),str(owned/"Invocation.swift"),str(fixture),"-o",str(exe)]
    build=subprocess.run(command,capture_output=True,text=True,encoding="utf-8",timeout=120)
    (out/"compile.log").write_bytes((build.stdout+build.stderr).encode("utf-8"))
    report=dict(observed_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),
        source_ref=args.baseline or subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip(),
        installer_source_sha256=hashlib.sha256(raw).hexdigest(),installer_body_sha256=hashlib.sha256(body.encode("utf-8")).hexdigest(),
        invocation_sha256=sha(owned/"Invocation.swift"),fixture_sha256=sha(fixture),manifest_sha256=sha(manifest),
        context_capture_sha256=hashlib.sha256(capture.encode("utf-8")).hexdigest() if has_fence else None,
        owned_fixture=str(owned),compile_exit=build.returncode,language_mode=6,
        boundaries=["Whole original installer methods unchanged; storage-capacity wrapper not compiled",
            "Actual filesystem creation/move/rollback and original relative-path validation",
            "Engine, extraction, transfer, fingerprint/profile and repository are explicit failure-injection doubles",
            "New source receives exact context capture from original service; baseline has no fence parameter",
            "Official unmodified manifest metadata only; no actual compressed payload/index/engine query or UI"])
    code=build.returncode
    if code:print(build.stderr[-7000:])
    else:
        state=owned/"state";state.mkdir()
        run=subprocess.run([str(exe),str(state),str(manifest)],capture_output=True,text=True,encoding="utf-8",timeout=30)
        code=run.returncode;(out/"tests.log").write_bytes((run.stdout+run.stderr).encode("utf-8"))
        print(run.stdout);print(run.stderr[-3000:]);report["execute_exit"]=code
        if (state/"RESULT.json").exists():report["cases"]=json.loads((state/"RESULT.json").read_text(encoding="utf-8"))
    report["status"]="ACTUAL_INSTALLER_CONTROL_PASS_NOT_ENGINE" if code==0 else "FAILED"
    (out/"RESULT.json").write_bytes((json.dumps(report,indent=2)+"\n").encode("utf-8"))
    print(json.dumps({"status":report["status"],"cases":report.get("cases",{})}));return code
if __name__=="__main__":raise SystemExit(main())

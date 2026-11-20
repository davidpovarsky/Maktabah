#!/usr/bin/env python3
"""Original Reader models/coordinator/resolver and native projection methods; explicit UI/manager/Action DTO doubles."""
import argparse, datetime, hashlib, json, os, pathlib, re, shutil, subprocess, time
ROOT = pathlib.Path(__file__).resolve().parents[1]
PROJECTION = "Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSceneProjection.swift"
COORDINATOR = "Source/ChavrusaText/Navigation/ReaderContentLoadCoordinator.swift"
COPIED = ["Source/LibraryBackend/LibraryBackendModels.swift", COORDINATOR,
          "Source/ChavrusaText/Navigation/ReaderDestinationResolver.swift"]
BOUNDARY = "Tests/HQ/hanlin-native-source/HanlinCurrentWorkSourceBoundary.swift"
TESTS = "Tests/HQ/hanlin-native-source/HanlinCurrentWorkSourceAcceptance.swift"
def digest(data): return hashlib.sha256(data).hexdigest()
def block(source, marker):
    assert source.count(marker) == 1, marker
    start = source.index(marker); end = source.index("{", start) + 1; depth = 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}"); end += 1
    return source[start:end]
def main():
    p=argparse.ArgumentParser()
    p.add_argument("--artifacts-dir",type=pathlib.Path,required=True)
    p.add_argument("--source-ref")
    p.add_argument("--timeout",type=int,default=180)
    a=p.parse_args()
    if a.source_ref and not re.fullmatch("[0-9a-f]{40}",a.source_ref): raise SystemExit("Exact source SHA required")
    out=a.artifacts_dir.resolve();out.mkdir(parents=True,exist_ok=True)
    if any(out.iterdir()): raise SystemExit("Preserve earlier attempts")
    sources=out/"sources";sources.mkdir()
    inputs={}
    def read(path):
        raw=(subprocess.check_output(["git","show",a.source_ref+":"+path],cwd=ROOT) if a.source_ref else (ROOT/path).read_bytes())
        inputs[path]={"sha256":digest(raw),"bytes":len(raw),"source":a.source_ref or "worktree"}
        return raw
    for path in COPIED: (sources/pathlib.Path(path).name).write_bytes(read(path))
    projection=read(PROJECTION).decode("utf-8")
    surface=block(projection,"func surface(_ surface:")
    current_marker="func hanlinCurrentWorkReadSource()"
    candidate=current_marker in projection
    current=(block(projection,"struct HanlinCurrentWorkReadSource:")+"\n"+block(projection,current_marker)) if candidate else ""
    boundary=(ROOT/BOUNDARY).read_text(encoding="utf-8")
    boundary=boundary.replace("// ACTUAL_SURFACE",surface).replace("// ACTUAL_CURRENT_WORK_SOURCE",current)
    if candidate:
        selection="""guard let value = try projection.hanlinCurrentWorkReadSource() else { return nil }
    return .init(readerOwner: value.readerOwner, requested: value.requested, loaded: value.loaded,
        requestToken: value.requestToken)"""
    else:
        # Exactly the old hanlinSource selection: session.surface(.reader)?.content.
        # The baseline scope requires original Otzaria, unique active tab and matching book work.
        # This boundary does not claim to execute scene/SDK registration or Core authorization.
        selection="""guard let content = try projection.surface(.reader)?.content,
          content.sectionLocator.backend == .otzaria,
          let active = projection.manager.activeTabId else { return nil }
    let tabs = projection.manager.openTabs.filter { $0.id == active }
    guard tabs.count == 1, let tab = tabs.first, let book = tab.book.backendLocator,
          book.backend == .otzaria, book.workKey == content.sectionLocator.workKey else { return nil }
    let original = LibraryReaderDestination(sectionLocator: content.sectionLocator, focusLocator: content.focusLocator)
    return .init(readerOwner: ObjectIdentifier(tab.viewModel), requested: original, loaded: original, requestToken: nil)"""
    boundary=boundary.replace("// ACTUAL_CONSUMER_SELECTION",selection)
    (sources/"Boundary.swift").write_text(boundary,encoding="utf-8")
    test_raw=(ROOT/TESTS).read_bytes();(sources/"Acceptance.swift").write_bytes(test_raw)
    expected=re.findall(r'check\("([^"]+)"',test_raw.decode())
    assert expected and len(set(expected))==len(expected)
    report={"status":"RUNNING","head":subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip(),
        "source_ref":a.source_ref or "worktree","candidate_current_work_method":candidate,
        "started_utc":datetime.datetime.now(datetime.timezone.utc).isoformat(),"source_inputs":inputs,
        "fixture_inputs":{p:digest((ROOT/p).read_bytes()) for p in [BOUNDARY,TESTS]},
        "method_sha256":{"surface":digest(surface.encode()),"current_work":digest(current.encode()) if candidate else None},
        "expected":expected,"expected_count":len(expected),"native_passes":0,
        "boundary":"Real full LibraryBackendModels, ReaderDestinationResolver, ReaderContentLoadCoordinator; original entire surface method and candidate current-work method extracted byte-for-byte. Explicit UIKit/SwiftUI/manager and Action/UI DTO doubles. Baseline uses the original Hanlin reader-surface selection, not a native app/SDK/Core permission run. No DB, network, provider or physical-device acceptance."}
    def save(): (out/"RESULT.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    save()
    exe=out/("HanlinCurrentWorkSourceAcceptance.exe" if os.name=="nt" else "HanlinCurrentWorkSourceAcceptance")
    command=[shutil.which("swiftc"),"-swift-version","6","-strict-concurrency=complete","-parse-as-library",
             *map(str,sorted(sources.glob("*.swift"))),"-o",str(exe)]
    report["command"]=command;start=time.monotonic()
    with (out/"compile.log").open("w",encoding="utf-8") as log:
        proc=subprocess.Popen(command,cwd=ROOT,stdin=subprocess.DEVNULL,stdout=log,stderr=subprocess.STDOUT)
        report["compiler_pid"]=proc.pid;save()
        try: report["compile_exit"]=proc.wait(timeout=a.timeout)
        except subprocess.TimeoutExpired:
            report["compile_timeout"]=True
            if os.name=="nt": subprocess.run(["taskkill","/PID",str(proc.pid),"/T","/F"],capture_output=True)
            else: proc.kill()
            proc.wait();report["compile_exit"]=124
    report["compile_seconds"]=round(time.monotonic()-start,3)
    report["compiler_warnings"]=(out/"compile.log").read_text(encoding="utf-8",errors="replace").count("warning:")
    passed=[];failed=[];executed=[]
    if report["compile_exit"]==0:
        start=time.monotonic()
        result=subprocess.run([str(exe)],cwd=ROOT,capture_output=True,text=True,encoding="utf-8",timeout=30)
        text=result.stdout+result.stderr;(out/"tests.log").write_text(text,encoding="utf-8")
        report.update(test_exit=result.returncode,test_seconds=round(time.monotonic()-start,3),executable_sha256=digest(exe.read_bytes()))
        executed=re.findall(r"^(?:PASS|FAIL) (\S+)",text,re.M)
        passed=re.findall(r"^PASS (\S+)$",text,re.M);failed=re.findall(r"^FAIL (\S+) ::",text,re.M)
    unchanged=all(digest((subprocess.check_output(["git","show",a.source_ref+":"+p],cwd=ROOT) if a.source_ref else (ROOT/p).read_bytes()))==v["sha256"] for p,v in inputs.items())
    report.update(passed=passed,failed=failed,executed=executed,executed_count=len(executed),source_inputs_unchanged=unchanged)
    ok=report["compile_exit"]==0 and report.get("test_exit")==0 and executed==expected and not failed and unchanged
    report.update(status="PASS_SOURCE_METHODS_ONLY" if ok else "FAIL",finished_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
    save();print(json.dumps(report));return 0 if ok else 1
if __name__=="__main__": raise SystemExit(main())

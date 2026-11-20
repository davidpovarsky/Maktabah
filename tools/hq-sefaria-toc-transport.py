#!/usr/bin/env python3
"""Whole original HTTPClient + its DEBUG URLProtocol; explicit Foundation-only boundaries.
Copies the complete production file, asserts that prefix before/after, then
appends same-file test access. Only the successful retry HTTP payload is a
declared canned transport; no Apple/UIKit, real-network or Hermes claim.
"""
import argparse, datetime as dt, hashlib, importlib.util, json, shutil, subprocess, sys, time
from pathlib import Path

def sha(raw): return hashlib.sha256(raw).hexdigest()
def utc(): return dt.datetime.now(dt.timezone.utc).isoformat()
def main():
    p=argparse.ArgumentParser()
    p.add_argument("--root",type=Path,default=Path(__file__).resolve().parents[1])
    p.add_argument("--output",type=Path,required=True)
    p.add_argument("--module-cache",type=Path,required=True)
    p.add_argument("--lifetime-only",action="store_true")
    p.add_argument("--http-client-snapshot",type=Path)
    p.add_argument("--http-client-sha256")
    a=p.parse_args();root=a.root.resolve();out=a.output.resolve()
    if out.exists() or not a.module_cache.is_dir():raise RuntimeError("Need new output and existing module cache")
    if bool(a.http_client_snapshot) != bool(a.http_client_sha256):
        raise RuntimeError("An immutable HTTP source snapshot requires its exact SHA256")
    out.mkdir(parents=True);inputs=out/"inputs";inputs.mkdir()
    spec=importlib.util.spec_from_file_location("original_language_driver",root/"tools/hq-sefaria-navigation-language.py")
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    relative=module.PRODUCTION+["Source/Sefaria/Network/SefariaHTTPClient.swift"]
    records=[]; paths=[]; observed=[]
    appendix_path=root/"Tests/HQ/sefaria-mobile-navigation/TOCTransportAcceptanceAppendix.swift"
    appendix=appendix_path.read_bytes()
    for rel in relative:
        source=(a.http_client_snapshot if rel.endswith("SefariaHTTPClient.swift") and a.http_client_snapshot else root/rel)
        raw=source.read_bytes()
        if source==a.http_client_snapshot and sha(raw)!=a.http_client_sha256:
            raise RuntimeError("HTTP source snapshot SHA256 mismatch")
        target=inputs/rel;target.parent.mkdir(parents=True,exist_ok=True)
        whole=raw+(b"\n"+appendix if rel.endswith("SefariaHTTPClient.swift") else b"")
        target.write_bytes(whole)
        assert target.read_bytes()[:len(raw)]==raw
        records.append({"path":rel,"bytes":len(raw),"sha256":sha(raw),"canonicalLFSHA256":sha(raw.replace(b"\r\n",b"\n")),
                        "snapshotSHA256":sha(whole),"originalWholePrefixExact":True,"sourceOrigin":str(source)})
        observed.append((source,sha(raw)));paths.append(str(target))
    records.append({"path":str(appendix_path.relative_to(root)),"bytes":len(appendix),"sha256":sha(appendix)})
    observed.append((appendix_path,sha(appendix)))
    (out/"INPUTS.json").write_text(json.dumps(records,indent=2),encoding="utf-8")
    result={"startedAt":utc(),"native":"NOT_RUN","appleSDK":"NOT_RUN","realNetwork":"NOT_RUN","embeddedHermes":"NOT_RUN",
            "boundary":"Explicit owned temporary documents and child-Task shape; original entire HTTPClient/TaskLocal/admission/URLProtocol. Successful retry bytes only are canned.",
            "productionExtraction":"NONE; original whole prefix before test-only same-file appendix", "freeBytesBefore":shutil.disk_usage(root).free,
            "modeSelection":"lifetime-only" if a.lifetime_only else "transport-and-lifetime",
            "httpSnapshot":str(a.http_client_snapshot) if a.http_client_snapshot else None}
    common=["admission.arm-once","admission.reject-shape","admission.reject-post","admission.reject-body",
            "admission.exact-url","admission.exact-nonce","admission.tag-once","admission.no-untagged-claim",
            "admission.property-local-not-header","admission.can-init-is-passive","admission.claim-once",
            "command.valid-exact-schema","command.foreign-namespace-rejected","command.extra-field-rejected",
            "command.bounded-bytes","runtime.real-app-configuration-not-enabled","runtime.actual-urlprotocol-held",
            "runtime.tasklocal-inherited-by-child","runtime.no-completion-before-release",
            "runtime.success-boundary-not-called-while-held"]
    modes={"failure-retry":common+["runtime.original-offline-error-mapping","runtime.no-automatic-success-retry",
                 "runtime.no-fake-success-response","runtime.actual-failure-receipt",
                 "runtime.retry-outside-tasklocal-uses-original-session","runtime.consumed-token-cannot-steal-later-request"],
           "cancel-held":common+["runtime.held-cancellation","runtime.no-automatic-success-retry",
                 "runtime.no-fake-success-response","runtime.cancel-does-not-publish-failure",
                 "runtime.retry-outside-tasklocal-uses-original-session","runtime.consumed-token-cannot-steal-later-request"]}
    lifetime={"lifetime":["lifetime.stop-before-rejected-start","lifetime.declined-start-completes-once",
                          "lifetime.reentrant-stop-prevents-late-callback"]}
    modes=lifetime if a.lifetime_only else {**modes,**lifetime}
    (out/"CASES_EXPECTED.json").write_text(json.dumps(modes,indent=2),encoding="utf-8")
    try:
        exe=out/"toc-transport-foundation.exe"
        cmd=[shutil.which("swiftc"),"-j1","-swift-version","6","-strict-concurrency=complete",
             "-D","DEBUG","-D","SEFARIA_TOC_TRANSPORT_ACCEPTANCE_TESTS",
             "-module-cache-path",str(a.module_cache),*paths,"-o",str(exe)]
        (out/"COMMANDS.json").write_text(json.dumps({"compile":cmd,"compileTimeout":180,"runtimeTimeoutPerMode":20},indent=2),encoding="utf-8")
        start=time.monotonic();r=subprocess.run(cmd,capture_output=True,timeout=180)
        result["compile"]={"returncode":r.returncode,"seconds":time.monotonic()-start}
        (out/"compile.stdout.log").write_bytes(r.stdout);(out/"compile.stderr.log").write_bytes(r.stderr)
        if r.returncode:raise RuntimeError("compile failure")
        result["executableSHA256"]=sha(exe.read_bytes());result["modes"]={}
        for mode,names in modes.items():
            folder=out/mode;folder.mkdir()
            start=time.monotonic();r=subprocess.run([str(exe),mode,str(folder)],capture_output=True,timeout=20)
            (folder/"runtime.stdout.log").write_bytes(r.stdout);(folder/"runtime.stderr.log").write_bytes(r.stderr)
            rows=json.loads(r.stdout.decode("utf-8"))
            if [row["name"] for row in rows]!=names:raise RuntimeError("Exact unique inventory mismatch "+mode)
            (folder/"CASES.json").write_text(json.dumps(rows,indent=2),encoding="utf-8")
            result["modes"][mode]={"returncode":r.returncode,"seconds":time.monotonic()-start,
                 "executed":len(rows),"passed":sum(row["passed"] for row in rows),
                 "failed":[row["name"] for row in rows if not row["passed"]]}
        result["executed"]=sum(x["executed"] for x in result["modes"].values())
        result["passed"]=sum(x["passed"] for x in result["modes"].values())
        result["status"]="PASS" if all(x["returncode"]==0 and not x["failed"] for x in result["modes"].values()) else "FAIL"
    except Exception as e:
        result["status"]="ERROR";result["error"]=str(e);result.setdefault("executed",0)
    result["inputHashesUnchanged"]=all(sha(path.read_bytes())==digest for path,digest in observed)
    result["finishedAt"]=utc();result["freeBytesAfter"]=shutil.disk_usage(root).free
    if not result["inputHashesUnchanged"]:result["status"]="ERROR"
    (out/"RESULT.json").write_text(json.dumps(result,indent=2),encoding="utf-8");print(json.dumps(result,indent=2))
    return 0 if result["status"]=="PASS" else 1
if __name__=="__main__":sys.exit(main())

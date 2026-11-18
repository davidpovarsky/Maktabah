#!/usr/bin/env python3
"""Exact original URLSession delegate, held actual HTTP plus explicit ordering controls.
No index/manifest/archive verification, UIKit or Apple concurrency acceptance.
"""
from pathlib import Path
import argparse,datetime,hashlib,http.server,json,os,subprocess,threading,time,uuid
ROOT=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    ap=argparse.ArgumentParser();ap.add_argument("--artifacts-dir",type=Path,required=True);ap.add_argument("--baseline")
    args=ap.parse_args();out=args.artifacts_dir.resolve();out.mkdir(parents=True,exist_ok=True)
    owned=ROOT/"build"/("odc-"+uuid.uuid4().hex[:12]);owned.mkdir()
    source_path="Source/Otzaria/Search/Distribution/OtzariaSearchArtifactDownloader.swift"
    raw=subprocess.check_output(["git","show",args.baseline+":"+source_path],cwd=ROOT) if args.baseline else (ROOT/source_path).read_bytes()
    source=raw.decode("utf-8-sig")
    delegate=source[source.index("private enum OtzariaArtifactDownloadOutcome"):]
    fixture=ROOT/"Tests/HQ/search/OtzariaDownloadCancellationFixtures.swift"
    generated=owned/"Delegate.swift"
    support="""import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
enum OtzariaSearchArtifactError: Error {
    case downloadFailed(String), sizeMismatch(asset:String,expected:Int64,actual:Int64)
}
"""
    generated.write_bytes((support+delegate+"\n"+fixture.read_text(encoding="utf-8")).encode("utf-8"))
    exe=owned/("download.exe" if os.name=="nt" else "download")
    command=["swiftc","-parse-as-library","-swift-version","5","-strict-concurrency=complete",str(generated),"-o",str(exe)]
    build=subprocess.run(command,capture_output=True,text=True,encoding="utf-8",timeout=120)
    (out/"compile.log").write_bytes((build.stdout+build.stderr).encode("utf-8"))
    report=dict(observed_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),
        source_ref=args.baseline or subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip(),
        original_source_sha256=hashlib.sha256(raw).hexdigest(),delegate_sha256=hashlib.sha256(delegate.encode("utf-8")).hexdigest(),
        fixture_sha256=sha(fixture),generated_sha256=sha(generated),owned_fixture=str(owned),compile_exit=build.returncode,
        compiler=subprocess.check_output(["swiftc","--version"],text=True).strip(),language_mode=5,
        boundaries=["Exact delegate/enum body; two error DTO cases supplied by harness",
            "Actual URLSession + held loopback HTTP; no response body released during cancellation assertion",
            "Terminal callback-before-run case is explicitly injected",
            "Windows FoundationNetworking Swift5 language mode, not Apple concurrency/build acceptance"],
        native_ui_executed=0,archive_verified=False,engine_opened=False)
    code=build.returncode
    if code:print(build.stderr[-7000:])
    else:
        stop=threading.Event();requests=[]
        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                name=self.path.strip("/")
                if name not in ["held","early","precancel"]:self.send_error(404);return
                requests.append(dict(path=name,started_at=time.time()))
                (owned/(name+".started")).write_bytes(b"actual-http-request\n")
                stop.wait(20)
            def log_message(self,*args):pass
        server=http.server.ThreadingHTTPServer(("127.0.0.1",0),Handler);server.daemon_threads=True
        thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
        try:
            run=subprocess.run([str(exe),str(owned),f"http://127.0.0.1:{server.server_address[1]}"],
                capture_output=True,text=True,encoding="utf-8",timeout=35)
            code=run.returncode;(out/"tests.log").write_bytes((run.stdout+run.stderr).encode("utf-8"))
            print(run.stdout);print(run.stderr[-4000:]);report["execute_exit"]=code
            if (owned/"RESULT.json").exists():report["cases"]=json.loads((owned/"RESULT.json").read_text(encoding="utf-8"))
        finally:stop.set();server.shutdown();server.server_close()
        report["actual_http_requests"]=requests
    report["status"]="ACTUAL_URLSESSION_CANCELLATION_PASS_NOT_NATIVE" if code==0 else "FAILED"
    (out/"RESULT.json").write_bytes((json.dumps(report,indent=2)+"\n").encode("utf-8"))
    print(json.dumps({"status":report["status"],"cases":report.get("cases",{})}));return code
if __name__=="__main__":raise SystemExit(main())

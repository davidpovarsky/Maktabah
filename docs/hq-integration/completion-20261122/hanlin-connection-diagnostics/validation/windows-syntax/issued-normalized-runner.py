from pathlib import Path
import hashlib,json,subprocess,shutil,sys,time,datetime,platform
root=Path(r"C:\Users\DAVID\AppData\Local\Temp\otzaria-hanlin-live7-diagnostic-validation-20261122")
result=root/"windows-syntax"
assert not result.exists(),"Preserve existing syntax execution"
result.mkdir()
runner=Path(__file__).read_bytes()
(result/"issued-normalized-runner.py").write_bytes(runner)
inputs=json.loads((root/"INPUTS.json").read_bytes())
def sha(raw):return hashlib.sha256(raw).hexdigest()
for row in inputs["files"]:
    raw=(root/"inputs"/row["path"]).read_bytes()
    assert len(raw)==row["bytes"] and sha(raw)==row["sha256"],row["path"]
swift=Path(shutil.which("swiftc"))
assert swift.is_file()
frontend=swift.parent/"swift-frontend.exe"
environment={"platform":platform.platform(),"pythonExecutable":sys.executable,"pythonVersion":sys.version,"swiftc":{"path":str(swift),"bytes":swift.stat().st_size,"sha256":sha(swift.read_bytes())},"swiftFrontend":{"path":str(frontend),"bytes":frontend.stat().st_size,"sha256":sha(frontend.read_bytes())},"runnerSHA256":sha(runner)}
commands=[]
def run(name,cmd,timeout=45):
    start=datetime.datetime.now(datetime.timezone.utc).isoformat(); t=time.monotonic()
    p=subprocess.run(cmd,cwd=root,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=timeout)
    (result/(name+".stdout")).write_bytes(p.stdout);(result/(name+".stderr")).write_bytes(p.stderr)
    item={"name":name,"command":cmd,"cwd":str(root),"startedUTC":start,"elapsedSeconds":time.monotonic()-t,"exitCode":p.returncode,"stdoutSHA256":sha(p.stdout),"stderrSHA256":sha(p.stderr)}
    commands.append(item)
    (result/"EXECUTION.json").write_text(json.dumps({"environment":environment,"commands":commands},indent=2)+"\n",encoding="utf-8")
    return p.returncode
version=run("swift-version",[str(swift),"--version"])
for n,row in enumerate((r for r in inputs["files"] if r["path"].endswith(".swift")),1):
    run("parse-"+str(n),[str(swift),"-frontend","-parse","-D","DEBUG","-target","arm64-apple-ios27.2-simulator",str(root/"inputs"/row["path"])])
for row in inputs["files"]:
    raw=(root/"inputs"/row["path"]).read_bytes()
    assert len(raw)==row["bytes"] and sha(raw)==row["sha256"]
summary={"status":"PASS" if all(x["exitCode"]==0 for x in commands) else "FAIL","completeSwiftFiles":4,"commands":commands,"sourceUnchanged":True,"scope":"Windows Swift frontend syntax parse of four complete candidates with DEBUG and iOS Simulator target flags. No Apple SDK import resolution, semantic typecheck, link, runtime, storage or Simulator qualification."}
(result/"RESULT.json").write_text(json.dumps(summary,indent=2)+"\n",encoding="utf-8")
print(json.dumps(summary))
sys.exit(0 if summary["status"]=="PASS" else 1)

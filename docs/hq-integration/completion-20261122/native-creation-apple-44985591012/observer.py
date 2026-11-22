from pathlib import Path
import subprocess,json,hashlib,time,os,zipfile,io
root=Path(r"C:\Users\DAVID\Code\Maktabah-native-creation-apple-prep-20261122")
out=root/"build/native-creation-fence-apple-44985591012-observer"
out.mkdir(parents=True,exist_ok=False)
(out/"observer.py").write_bytes(Path(__file__).read_bytes())
repo="davidpovarsky/Maktabah";rid="44985591012";expected="d2c63c336f8c07602871283c26bfb89468d97901"
def run(args,check=True,timeout=90):
    r=subprocess.run(args,cwd=root,capture_output=True,timeout=timeout)
    if check and r.returncode: raise RuntimeError(json.dumps({"command":args,"exit":r.returncode,"stderr":r.stderr.decode(errors="replace")}))
    return r
def api(path): return json.loads(run(["gh","api",path]).stdout)
def put(name,value): (out/name).write_text(json.dumps(value,indent=2)+"\n",encoding="utf-8",newline="\n")
initial=api("repos/"+repo+"/actions/runs/"+rid)
assert initial["head_sha"]==expected and initial["event"]=="push" and initial["run_attempt"]==1
put("INITIAL_RUN.json",initial)
put("OBSERVER_START.json",{"pid":os.getpid(),"run_id":rid,"head":expected,"started_utc":time.strftime("%Y-%m-%dT%H:%M:%SZ",time.gmtime()),"deadline_seconds":2200,"observer_sha256":hashlib.sha256((out/"observer.py").read_bytes()).hexdigest()})
with (out/"watch.stdout.log").open("wb") as so,(out/"watch.stderr.log").open("wb") as se:
    watched=subprocess.run(["gh","run","watch",rid,"--repo",repo,"--exit-status","--interval","30"],cwd=root,stdout=so,stderr=se,timeout=2100)
terminal=api("repos/"+repo+"/actions/runs/"+rid)
assert terminal["status"]=="completed" and terminal["head_sha"]==expected and terminal["run_attempt"]==1
put("TERMINAL_RUN.json",terminal)
jobs=api("repos/"+repo+"/actions/runs/"+rid+"/jobs?per_page=100")
put("JOBS.json",jobs)
arts=api("repos/"+repo+"/actions/runs/"+rid+"/artifacts?per_page=100")
put("ARTIFACTS.json",arts)
retained=[]
for a in arts["artifacts"]:
    assert not a["expired"]
    assert a["size_in_bytes"]<=12_000_000,{"unexpected_artifact_size":a["size_in_bytes"],"name":a["name"]}
    data=run(["gh","api","repos/"+repo+"/actions/artifacts/"+str(a["id"])+"/zip"],timeout=120).stdout
    archive=out/(str(a["id"])+".zip");archive.write_bytes(data)
    extract=out/"artifacts"/str(a["id"]);extract.mkdir(parents=True)
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        assert z.testzip() is None
        for m in z.infolist():
            target=(extract/m.filename).resolve()
            assert target.is_relative_to(extract.resolve())
            assert not (m.external_attr>>16)&0o170000==0o120000
        z.extractall(extract)
    files=[{"path":p.relative_to(out).as_posix(),"sha256":hashlib.sha256(p.read_bytes()).hexdigest(),"bytes":p.stat().st_size} for p in sorted(extract.rglob("*")) if p.is_file()]
    retained.append({"id":a["id"],"name":a["name"],"api_size":a["size_in_bytes"],"downloaded_bytes":len(data),"sha256":hashlib.sha256(data).hexdigest(),"files":files})
logs=run(["gh","run","view",rid,"--repo",repo,"--log"],check=False,timeout=120)
(out/"github-job.log").write_bytes(logs.stdout)
(out/"github-log.stderr.log").write_bytes(logs.stderr)
put("RETENTION.json",retained)
results=[]
for p in (out/"artifacts").rglob("*.json") if (out/"artifacts").exists() else []:
    try:
        v=json.loads(p.read_bytes())
        if isinstance(v,dict) and "status" in v:results.append({"path":p.relative_to(out).as_posix(),"status":v["status"],"keys":list(v)})
    except Exception:pass
summary={"run_id":rid,"head":expected,"conclusion":terminal["conclusion"],"watch_exit":watched.returncode,"run_attempt":terminal["run_attempt"],"artifact_count":len(retained),"artifacts":[{k:v for k,v in a.items() if k!="files"} for a in retained],"results":results,"evidence_directory":str(out),"ci_dispatches":0}
put("OBSERVER_RESULT.json",summary)
print(json.dumps(summary))

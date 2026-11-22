from pathlib import Path
import hashlib,json,subprocess,sys,time,platform
root=Path(r"C:\Users\DAVID\Code\Maktabah-original-owner-sqlite-controls-20261122")
packet=root/"docs/hq-integration/completion-20261122/original-owner-exclusive-sqlite"
borrowed=packet.parent/"original-owner-sqlite"
head="f81213dc5bba73272c9d0aa9873a7ef1e05e1528"
def git(*args):return subprocess.check_output(["git",*args],cwd=root,text=True,timeout=45).strip()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,v):p.write_text(json.dumps(v,indent=2)+"\n",encoding="utf-8",newline="\n")
assert git("rev-parse","HEAD")==head
assert git("status","--porcelain")==""
assert sha(packet/"OriginalOwnerExclusiveSQLiteControls.swift")=="5d4cb2744a4d03d8a46808618ccd78052d316ab7dedffd462cf22bdaf42066ed"
assert sha(packet/"run-exclusive-owner-sqlite-controls.py")=="179e4ad274200ca436134b0017153b769cc536bb04fd2f6251e22285d9d9c8b3"
manifest=json.loads((borrowed/"PRODUCTION_INPUTS.json").read_bytes())
closure=[borrowed/"inputs"/row["name"]for row in manifest["inputs"]]+[borrowed/"PRODUCTION_INPUTS.json",borrowed/"OriginalOwnerSQLiteAcceptance.swift",packet/"OriginalOwnerExclusiveSQLiteControls.swift",packet/"run-exclusive-owner-sqlite-controls.py"]
assert len(closure)==13
before={}
for p in closure:
    rel=p.relative_to(root).as_posix()
    blob=subprocess.check_output(["git","show",head+":"+rel],cwd=root,timeout=45)
    assert p.read_bytes()==blob,rel
    before[rel]=sha(p)
assert git("diff","--name-only","8894bd50ba7cc6529ecd36a053c1682b492869cf",head,"--",borrowed.relative_to(root).as_posix())==""
evidence=packet/"evidence";evidence.mkdir(exist_ok=False)
(evidence/"EXECUTION_WRAPPER.py").write_bytes(Path(__file__).read_bytes())
write(evidence/"SOURCE_FROZEN.json",{"head":head,"platform":platform.platform(),"execution_inputs":before,"old_six_packet_unchanged":True,"selected_new_controls":2,"old_assertions_executed":False})
out=packet/"validation/windows-exclusive-two-20261122"
command=[sys.executable,str(packet/"run-exclusive-owner-sqlite-controls.py"),"--result-dir",str(out)]
start=time.monotonic()
with (evidence/"wrapper.stdout.log").open("wb")as stdout,(evidence/"wrapper.stderr.log").open("wb")as stderr:
    process=subprocess.Popen(command,cwd=root,stdout=stdout,stderr=stderr)
    write(evidence/"OWNED_PROCESS.json",{"pid":process.pid,"command":command,"head":head})
    try:code=process.wait(timeout=780)
    except subprocess.TimeoutExpired:
        # Only our exact child process tree; no other host process is addressed.
        subprocess.run(["taskkill","/PID",str(process.pid),"/T","/F"],capture_output=True,timeout=30)
        raise
receipt={"head":head,"command":command,"exit_code":code,"seconds":time.monotonic()-start,"runner_pid":process.pid,"sources_unchanged":before=={p.relative_to(root).as_posix():sha(p)for p in closure},"stdout_sha256":sha(evidence/"wrapper.stdout.log"),"stderr_sha256":sha(evidence/"wrapper.stderr.log"),"result_exists":(out/"RESULT.json").is_file(),"old_six_packet_unchanged":git("diff","--name-only","8894bd50ba7cc6529ecd36a053c1682b492869cf","--",borrowed.relative_to(root).as_posix())==""}
write(evidence/"WRAPPER_RECEIPT.json",receipt)
if (out/"RESULT.json").is_file():
    result=json.loads((out/"RESULT.json").read_bytes())
    receipt["result_sha256"]=sha(out/"RESULT.json")
    receipt["status"]=result["status"]
    receipt["cases"]=[{"name":x["name"],"status":x["status"],"ownerOutcome":x["ownerOutcome"],"durableRows":x.get("durableRows")}for x in result.get("cases",[])]
    receipt["writer"]=result.get("writer")
    receipt["reopen"]=result.get("reopen")
    receipt["error"]=result.get("error")
print(json.dumps(receipt,indent=2))
assert code==0 and receipt["sources_unchanged"] and receipt["old_six_packet_unchanged"]

from pathlib import Path
import hashlib,json,subprocess,sys,time
root=Path(r"C:\Users\DAVID\Code\Maktabah-original-owner-sqlite-controls-20261122")
parent=root/"docs/hq-integration/completion-20261122"
packet=parent/"original-owner-exclusive-positive"
initial=parent/"original-owner-exclusive-sqlite"
six=parent/"original-owner-sqlite"
head="558fdd787b26b6c9dc33b6fb59da7c080fa2671c"
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def git(*args):return subprocess.check_output(["git",*args],cwd=root,text=True,timeout=60).strip()
def write(p,v):p.write_text(json.dumps(v,indent=2)+"\n",encoding="utf-8",newline="\n")
assert git("rev-parse","HEAD")==head and git("status","--porcelain")==""
assert sha(packet/"PositiveOnly.swift")=="3b7982e006d48e85d3281a4b04f96291ade1a543aa125db37ab688a2ea981383"
assert sha(packet/"run-positive-only.py")=="541e949476da377116dd81c89389741a3de76272b3d563962ace1a2a17581cd5"
assert git("diff","--name-only","d8b0b6ae2a69eb0049bbfa524a2f34f878109dbf","--",initial.relative_to(root).as_posix())==""
assert git("diff","--name-only","8894bd50ba7cc6529ecd36a053c1682b492869cf","--",six.relative_to(root).as_posix())==""
for row in json.loads((initial/"EVIDENCE_RED_INDEX.json").read_bytes())["payloads"]:assert sha(initial/row["path"])==row["sha256"]
evidence=packet/"evidence";evidence.mkdir(exist_ok=False)
(evidence/"EXECUTION_WRAPPER.py").write_bytes(Path(__file__).read_bytes())
out=packet/"validation/p2"
command=[sys.executable,str(packet/"run-positive-only.py"),"--result-dir",str(out)]
start=time.monotonic()
with (evidence/"wrapper.stdout.log").open("wb")as stdout,(evidence/"wrapper.stderr.log").open("wb")as stderr:
    process=subprocess.Popen(command,cwd=root,stdout=stdout,stderr=stderr)
    write(evidence/"OWNED_PROCESS.json",{"pid":process.pid,"head":head,"command":command})
    try:code=process.wait(timeout=800)
    except subprocess.TimeoutExpired:
        subprocess.run(["taskkill","/PID",str(process.pid),"/T","/F"],capture_output=True,timeout=30)
        raise
receipt={"head":head,"command":command,"exit_code":code,"seconds":time.monotonic()-start,"runner_pid":process.pid,"stdout_sha256":sha(evidence/"wrapper.stdout.log"),"stderr_sha256":sha(evidence/"wrapper.stderr.log"),"result_exists":(out/"RESULT.json").is_file()}
write(evidence/"WRAPPER_RECEIPT.json",receipt)
if (out/"RESULT.json").is_file():
    r=json.loads((out/"RESULT.json").read_bytes())
    receipt.update(status=r["status"],result_sha256=sha(out/"RESULT.json"),executable_sha256=r.get("executable_sha256"),cases=r.get("cases"),writer=r.get("writer"),positive_reopen=r.get("positive_reopen"),negative_reopen=r.get("negative_reopen"),prior_writer=r.get("prior_writer"),error=r.get("error"))
print(json.dumps(receipt,indent=2))
assert code==0

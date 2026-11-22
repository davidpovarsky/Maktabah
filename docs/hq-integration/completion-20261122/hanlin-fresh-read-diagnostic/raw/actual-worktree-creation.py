from pathlib import Path
import subprocess,json,datetime,hashlib
origin=Path(r"C:\Users\DAVID\Code\Maktabah-hanlin-diagnostics-20261122")
target=Path(r"C:\Users\DAVID\Code\Maktabah-hanlin-fresh-read-diagnostic-20261122")
branch="codex/otzaria-hanlin-fresh-read-diagnostic-20261122"
base="ce5d11335c4b4769a25e0e8f48ba1d6f7efc6749"
temp=Path(r"C:\Users\DAVID\AppData\Local\Temp\otzaria-hanlin-fresh-read-diagnostic-20261122")
temp.mkdir(exist_ok=True)
assert not target.exists()
p=subprocess.run(["git","show-ref","--verify","--quiet","refs/heads/"+branch],cwd=origin,capture_output=True,timeout=30);assert p.returncode==1
cmd=["git","-c","core.autocrlf=false","worktree","add","-b",branch,str(target),base]
start=datetime.datetime.now(datetime.timezone.utc).isoformat()
p=subprocess.run(cmd,cwd=origin,capture_output=True,timeout=240)
(temp/"worktree.stdout").write_bytes(p.stdout);(temp/"worktree.stderr").write_bytes(p.stderr)
r={"command":cmd,"started":start,"finished":datetime.datetime.now(datetime.timezone.utc).isoformat(),"exitCode":p.returncode,"base":base,"target":str(target),"branch":branch}
(temp/"WORKTREE_CREATION.json").write_text(json.dumps(r,indent=2)+"\n",encoding="utf8",newline="\n")
(temp/"actual-worktree-creation.py").write_bytes(Path(__file__).read_bytes())
assert p.returncode==0,r
head=subprocess.check_output(["git","rev-parse","HEAD"],cwd=target).decode().strip();assert head==base
status=subprocess.check_output(["git","-c","core.autocrlf=false","status","--porcelain"],cwd=target).decode()
assert not status,status
print(json.dumps(r|{"head":head,"clean":True,"receiptSHA256":hashlib.sha256((temp/"WORKTREE_CREATION.json").read_bytes()).hexdigest()}))
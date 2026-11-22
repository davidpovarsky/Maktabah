from pathlib import Path
import json,hashlib,subprocess,time,datetime
work=Path(r"C:\Users\DAVID\Code\Maktabah-hanlin-diagnostics-20261122")
temp=Path(r"C:\Users\DAVID\AppData\Local\Temp\otzaria-hanlin-live7-diagnostic-implementation-20261122")
packet_rel=Path("docs/hq-integration/completion-20261122/hanlin-connection-diagnostics")
packet=work/packet_rel
source=json.loads((temp/"SOURCE_RECEIPT.json").read_bytes())
binding=json.loads((temp/"BINDING_RECEIPT.json").read_bytes())
assert not (temp/"FINAL_RECEIPT.json").exists()
(temp/"evidence-retention-continuation-runner.py").write_bytes(Path(__file__).read_bytes())
commands=[]
def git(args,input=None):
    t=time.monotonic();p=subprocess.run(["git",*args],cwd=work,input=input,capture_output=True,timeout=120)
    row={"command":["git",*args],"exitCode":p.returncode,"elapsedSeconds":time.monotonic()-t,"stdoutBytes":len(p.stdout),"stdoutSHA256":hashlib.sha256(p.stdout).hexdigest(),"stderrBytes":len(p.stderr),"stderrSHA256":hashlib.sha256(p.stderr).hexdigest()}
    if len(p.stdout)<4096:row["stdout"]=p.stdout.decode("utf-8","replace")
    commands.append(row)
    (temp/"EVIDENCE_CONTINUATION_COMMANDS.json").write_bytes((json.dumps(commands,indent=2)+"\n").encode())
    assert p.returncode==0,row
    return p.stdout
assert git(["rev-parse","HEAD"]).decode().strip()==binding["bindingCommit"]
assert not git(["diff","--name-only"])
prior=(packet/"FILE_INDEX.json").read_bytes()
for row in json.loads(prior)["files"]:
    raw=(packet/row["path"]).read_bytes()
    assert len(raw)==row["bytes"] and hashlib.sha256(raw).hexdigest()==row["sha256"]
(packet/"implementation/PACKET_INDEX_BEFORE_WHITESPACE_FIX.json").write_bytes(prior)
old_attributes=(packet/".gitattributes").read_bytes()
assert old_attributes==b"* -text\n*.patch -whitespace\n*.diff -whitespace\n*.swift whitespace=cr-at-eol\n"
new_attributes=b"* -text whitespace=cr-at-eol\n*.patch -whitespace\n*.diff -whitespace\nvalidation/linux-posix/diagnostic_boundary_controls.py whitespace=cr-at-eol,-blank-at-eof\nvalidation/linux-posix/run_diagnostic_controls.py whitespace=cr-at-eol,-blank-at-eof\nvalidation/linux-posix/execute_once.py whitespace=cr-at-eol,-blank-at-eof\nimplementation/EVIDENCE_WHITESPACE_GATE.stdout -whitespace\n"
(packet/".gitattributes").write_bytes(new_attributes)
for name in ["EVIDENCE_FIRST_ATTEMPT_FAILURE.json","EVIDENCE_WHITESPACE_GATE.stdout","EVIDENCE_WHITESPACE_GATE.stderr","EVIDENCE_WHITESPACE_DIAGNOSIS.json","evidence-retention-continuation-runner.py"]:
    (packet/"implementation"/name).write_bytes((temp/name).read_bytes())
correction="""

## Raw-evidence whitespace retention

The first evidence staging preserved every indexed byte and then failed the formatting gate because raw Windows receipts retained CRLF and three executed Linux control files retained their original trailing blank line. The full failed output, original packet index and exact per-file diagnosis are retained. Only this packet's attributes now recognize CR at EOL; three named executed control files preserve their existing EOF, and the retained raw whitespace diagnostic output is exempt from reformatting. No source, assertion, result, prior index or compiler output was rewritten. The final changed packet metadata was rehashed and actual staged Git blobs verified before commit.
"""
with (packet/"README.md").open("ab") as stream:stream.write(correction.encode())
for row in json.loads(prior)["files"]:
    if row["path"] in [".gitattributes","README.md"]:continue
    raw=(packet/row["path"]).read_bytes()
    assert len(raw)==row["bytes"] and hashlib.sha256(raw).hexdigest()==row["sha256"]
rows=[]
for path in sorted(packet.rglob("*")):
    if path.is_file() and path!=packet/"FILE_INDEX.json":
        assert not path.is_symlink();raw=path.read_bytes()
        rows.append({"path":path.relative_to(packet).as_posix(),"bytes":len(raw),"sha256":hashlib.sha256(raw).hexdigest()})
manifest={"schemaVersion":1,"applicationSource":source["source"],"bindingCommit":binding["bindingCommit"],"files":rows,"scope":"Actual bounded diagnostic source/reviews/validation; no Native/Live acceptance"}
index=(json.dumps(manifest,indent=2)+"\n").encode()
(packet/"FILE_INDEX.json").write_bytes(index)
git(["-c","core.autocrlf=false","add","--",packet_rel.as_posix()])
allrows=[*rows,{"path":"FILE_INDEX.json","bytes":len(index),"sha256":hashlib.sha256(index).hexdigest()}]
assert set(git(["diff","--cached","--name-only"]).decode().splitlines())=={packet_rel.as_posix()+"/"+r["path"] for r in allrows}
requests=b"".join((":"+packet_rel.as_posix()+"/"+r["path"]+"\n").encode() for r in allrows)
blob=git(["cat-file","--batch"],input=requests);offset=0
for row in allrows:
    end=blob.index(b"\n",offset);header=blob[offset:end].decode().split();offset=end+1
    assert len(header)==3 and header[1]=="blob";size=int(header[2]);body=blob[offset:offset+size];offset+=size+1
    assert size==row["bytes"] and hashlib.sha256(body).hexdigest()==row["sha256"],row["path"]
assert offset==len(blob)
gate=subprocess.run(["git","diff","--cached","--check"],cwd=work,capture_output=True,timeout=60)
(temp/"EVIDENCE_FINAL_GATE.stdout").write_bytes(gate.stdout)
(temp/"EVIDENCE_FINAL_GATE.stderr").write_bytes(gate.stderr)
assert gate.returncode==0,{"exitCode":gate.returncode,"stdout":gate.stdout.decode("utf-8","replace")[:5000]}
git(["commit","-m","Retain source-bound Hanlin diagnostic privacy validation"])
head=git(["rev-parse","HEAD"]).decode().strip()
assert git(["rev-parse","HEAD^"]).decode().strip()==binding["bindingCommit"]
assert not git(["status","--porcelain=v1","--untracked-files=all"])
for path,tree in source["trees"].items():assert git(["rev-parse",head+":"+path]).decode().strip()==tree
result={"schemaVersion":1,"status":"SOURCE_BINDING_EVIDENCE_COMMITTED_LOCAL_ONLY","base":source["base"],"source":source["source"],"binding":binding["bindingCommit"],"head":head,"branch":source["branch"],"worktree":str(work),"packetPath":packet_rel.as_posix(),"packetPayloads":len(rows),"packetFilesIncludingIndex":len(rows)+1,"packetBytes":sum(r["bytes"] for r in rows),"indexSHA256":hashlib.sha256(index).hexdigest(),"allPayloadStagedGitBlobsVerified":True,"applicationTrees":source["trees"],"clean":True,"sourceTestsReplayed":False,"whitespaceGate":0,"noPushNoSecretNoCI":True}
(temp/"FINAL_RECEIPT.json").write_bytes((json.dumps(result,indent=2)+"\n").encode())
print(json.dumps(result))

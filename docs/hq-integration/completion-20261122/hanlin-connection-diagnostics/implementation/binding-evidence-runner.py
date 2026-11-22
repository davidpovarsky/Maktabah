from pathlib import Path
import hashlib,json,subprocess,datetime,time,shutil,copy
work=Path(r"C:\Users\DAVID\Code\Maktabah-hanlin-diagnostics-20261122")
temp=Path(r"C:\Users\DAVID\AppData\Local\Temp\otzaria-hanlin-live7-diagnostic-implementation-20261122")
proposal=Path(r"C:\Users\DAVID\AppData\Local\Temp\otzaria-hanlin-live7-diagnostic-proposal-20261122")
validation=Path(r"C:\Users\DAVID\AppData\Local\Temp\otzaria-hanlin-live7-diagnostic-validation-20261122")
source_receipt=json.loads((temp/"SOURCE_RECEIPT.json").read_bytes())
source=source_receipt["source"];base=source_receipt["base"]
assert not (temp/"FINAL_RECEIPT.json").exists()
(temp/"binding-evidence-runner.py").write_bytes(Path(__file__).read_bytes())
commands=[]
def git(args,timeout=120,input=None):
    t=time.monotonic()
    p=subprocess.run(["git",*args],cwd=work,capture_output=True,timeout=timeout,input=input)
    row={"command":["git",*args],"cwd":str(work),"exitCode":p.returncode,"elapsedSeconds":time.monotonic()-t,"stdoutBytes":len(p.stdout),"stdoutSHA256":hashlib.sha256(p.stdout).hexdigest(),"stderr":p.stderr.decode("utf-8","replace")}
    if len(p.stdout)<8192:row["stdout"]=p.stdout.decode("utf-8","replace")
    if input is not None:row.update(stdinBytes=len(input),stdinSHA256=hashlib.sha256(input).hexdigest())
    commands.append(row)
    (temp/"BINDING_COMMANDS.json").write_text(json.dumps(commands,indent=2)+"\n",encoding="utf-8")
    assert p.returncode==0,row
    return p.stdout
assert git(["rev-parse","HEAD"]).decode().strip()==source
assert not git(["status","--porcelain=v1","--untracked-files=all"])
paths=["Scripts/CI/hq-stage2-focused-apple.inputs.json","Scripts/CI/runtime27-hanlin-live.py"]
old_source="0ea7218331d1441d37d06d43333e579f267056e3"
changes=[]
for path in paths:
    before=git(["show",source+":"+path])
    checked=(work/path).read_bytes()
    assert checked==before or checked.replace(b"\r\n",b"\n")==before
    if path.endswith(".inputs.json"):
        old=json.loads(before)
        assert old["application_source_sha"]==old_source
        new=copy.deepcopy(old)
        new["application_source_sha"]=source
        new["application_trees"]={key:source_receipt["trees"][key] for key in old["application_trees"]}
        after=json.dumps(new,ensure_ascii=False,indent=2).encode()+b"\n"
        check=copy.deepcopy(new);check["application_source_sha"]=old["application_source_sha"];check["application_trees"]=old["application_trees"]
        assert check==old
    else:
        literal=('REVIEWED_SOURCE = "'+old_source+'"').encode()
        assert before.count(literal)==1
        replacement=('REVIEWED_SOURCE = "'+source+'"').encode()
        after=before.replace(literal,replacement)
        assert after.replace(replacement,literal)==(proposal/"candidate"/path).read_bytes()
    (work/path).write_bytes(after)
    changes.append({"path":path,"beforeBytes":len(before),"beforeSHA256":hashlib.sha256(before).hexdigest(),"afterBytes":len(after),"afterSHA256":hashlib.sha256(after).hexdigest()})
assert set(git(["diff","--name-only"]).decode().splitlines())==set(paths)
git(["diff","--check"])
binding_diff=git(["diff","--binary","--",*paths])
(temp/"BINDINGS.diff").write_bytes(binding_diff)
git(["-c","core.autocrlf=false","add","--",*paths])
for row in changes:
    raw=git(["show",":"+row["path"]])
    assert len(raw)==row["afterBytes"] and hashlib.sha256(raw).hexdigest()==row["afterSHA256"]
git(["commit","-m","Bind focused Hanlin diagnostics to its reviewed application source"])
binding=git(["rev-parse","HEAD"]).decode().strip()
assert git(["rev-parse","HEAD^"]).decode().strip()==source
assert not git(["status","--porcelain=v1","--untracked-files=all"])
for path,tree in source_receipt["trees"].items():
    assert git(["rev-parse",binding+":"+path]).decode().strip()==tree
binding_receipt={"schemaVersion":1,"status":"BOUND_LOCAL_ONLY","applicationSource":source,"bindingCommit":binding,"parent":source,"applicationTrees":source_receipt["trees"],"files":changes,"diffSHA256":hashlib.sha256(binding_diff).hexdigest(),"driverOnlyDifferenceFromTestedCandidate":"REVIEWED_SOURCE immutable SHA literal","allOriginalAcceptanceRequirementsUnchanged":True,"final116And114ManifestsUnchanged":True,"oldConsentSelectorSourceUnchanged":True,"pendingOriginalEditorRouteUnchanged":True,"noKeyNoCI":True}
(temp/"BINDING_RECEIPT.json").write_text(json.dumps(binding_receipt,indent=2)+"\n",encoding="utf-8")
(temp/"BINDING_COMMANDS_UNTIL_FREEZE.json").write_bytes((temp/"BINDING_COMMANDS.json").read_bytes())
packet_rel=Path("docs/hq-integration/completion-20261122/hanlin-connection-diagnostics")
packet=work/packet_rel
assert not packet.exists()
packet.mkdir(parents=True)
(packet/".gitattributes").write_bytes(b"* -text\n*.patch -whitespace\n*.diff -whitespace\n*.swift whitespace=cr-at-eol\n")
for source_dir,destination_name,indexsha in [(proposal,"proposal","d776979563668e1766a3e94377a0b1880ce6d954019ae462a392aa9cf1999193"),(validation,"validation","e4d3bd2d017f9ba74c9f7eddaff5415918255b2f69b6d44882278892e8773c98")]:
    raw=(source_dir/"FILE_INDEX.json").read_bytes()
    assert hashlib.sha256(raw).hexdigest()==indexsha
    index=json.loads(raw)
    for item in index["files"]:
        data=(source_dir/item["path"]).read_bytes()
        assert len(data)==item["bytes"] and hashlib.sha256(data).hexdigest()==item["sha256"]
        target=packet/destination_name/item["path"]
        target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
    (packet/destination_name/"FILE_INDEX.json").write_bytes(raw)
retained=["SOURCE_RECEIPT.json","SOURCE.diff","SOURCE_COMMANDS.json","SOURCE_CONTINUATION_COMMANDS.json","FIRST_ATTEMPT_FAILURE.json","CHECKOUT_EOL_DIAGNOSIS.json","source-implementation-runner.py","source-continuation-runner.py","BINDING_RECEIPT.json","BINDINGS.diff","BINDING_COMMANDS_UNTIL_FREEZE.json","binding-evidence-runner.py"]
for name in retained:
    target=packet/"implementation"/name
    target.parent.mkdir(parents=True,exist_ok=True)
    target.write_bytes((temp/name).read_bytes())
readme=f"""# Bounded original Hanlin connection diagnostics

## Frozen source and bindings

Base: {base}. Application source: {source}. Binding commit: {binding}.

The application commit contains exactly the reviewed four downstream Hanlin/composition Swift files and the existing Live evidence driver. No UI, Vendor or Xcode project file changed. The binding commit changes only ordinary HQ source/tree declarations and the existing Live REVIEWED_SOURCE literal. Their application trees are:

{json.dumps(source_receipt["trees"],indent=2)}

The original five candidates are byte-identical to proposal dbc19b2b105a969fb5c8126abe2e3d8f8222d2c9c9cc276cc5a9c7dc0185b672. The bound driver differs from its tested candidate only in the immutable source SHA literal. Exact forward/inverse replacements and all original bytes remain in proposal.

## Actual new validation

The validation folder preserves the complete frozen42-payload packet, index e4d3bd2d017f9ba74c9f7eddaff5415918255b2f69b6d44882278892e8773c98:34 new Python controls passed once, full Python AST passed, and four complete Swift syntax parses passed once. The two actual Windows/Apple sysroot warnings are preserved. This is not Apple semantic compilation or Simulator runtime/storage qualification.

Actual POSIX controls reject wrong/stale nonce paths, unsafe permissions/symlinks/containment, unknown or malformed schemas, enum/sequence/size/count errors and raw/base64 synthetic privacy canaries. Explicit external source/matrix probes in three complete-main controls do not claim Native execution. A valid journal cannot replace the original final witness, source ownership, read consent or acceptance gate.

Independent source reviews are retained unchanged: 265156d3 for the exact proposal and 1a35c4fc for passive boolean operands. Observable reads can perform normal tracking; the added operands invoke no setter, validation, source acquisition, consent or navigation action.

## Bookkeeping failure and precise continuation

The first source-application attempt stopped before any product write because a new clean Windows checkout used the repository's existing core.autocrlf=true. All five differences were proved to be CRLF checkout expansion only, while the actual Git preimages matched exactly. The original failure, raw command receipt and per-file byte/line-ending diagnosis are retained. The continuation applied exact reviewed candidate bytes, staged using per-command core.autocrlf=false, and verified all five immutable Git blobs. No global configuration, old worktree, original candidate or test execution changed.

## Acceptance remains open

Live7 run44993301949 remains a failure on77c7/app0ea; its actual case lasted78.00888001918793s and stopped at the source-qualified dismissal assertion before any verified completed provider conversation. Its separate frozen failure/cleanup packet is already owned by the coordinator at428706; it is not duplicated here.

The journal is enabled only by the consumed one-use DEBUG Simulator Live input, is bounded to fixed enum/boolean fields, and is captured before the unchanged final-witness requirement. It cannot grant access or count as provider success. Credential scanning, the fixed allowlist and cleanup remain unchanged except the one permitted typed JSON filename.

No secret, CI or provider action was taken. The original Native/Host/component PASS results were not rerun or reattributed to these changed source bytes. Final Native116/Release114 manifests, the already-executed consent route and pending original-editor route remain unchanged. Actual Apple build and the affected one-case Live journey remain pending the coordinator's source review and owned lifecycle.
"""
(packet/"README.md").write_bytes(readme.encode("utf-8"))
payloads=[]
for path in sorted(packet.rglob("*")):
    if path.is_file():
        assert not path.is_symlink()
        raw=path.read_bytes()
        payloads.append({"path":path.relative_to(packet).as_posix(),"bytes":len(raw),"sha256":hashlib.sha256(raw).hexdigest()})
manifest={"schemaVersion":1,"applicationSource":source,"bindingCommit":binding,"files":payloads,"scope":"Actual bounded diagnostic source/reviews/validation; no Native/Live acceptance"}
indexpath=packet/"FILE_INDEX.json"
indexpath.write_bytes((json.dumps(manifest,indent=2)+"\n").encode())
git(["-c","core.autocrlf=false","add","--",packet_rel.as_posix()])
staged=git(["diff","--cached","--name-only"]).decode().splitlines()
allrows=[*payloads,{"path":"FILE_INDEX.json","bytes":indexpath.stat().st_size,"sha256":hashlib.sha256(indexpath.read_bytes()).hexdigest()}]
expected={packet_rel.as_posix()+"/"+x["path"] for x in allrows}
assert set(staged)==expected,(len(staged),len(expected))
requests=b"".join((":"+packet_rel.as_posix()+"/"+r["path"]+"\n").encode() for r in allrows)
batch=git(["cat-file","--batch"],input=requests)
offset=0
for row in allrows:
    end=batch.index(b"\n",offset);header=batch[offset:end].decode().split();offset=end+1
    assert len(header)==3 and header[1]=="blob",header
    size=int(header[2]);blob=batch[offset:offset+size];offset+=size+1
    assert size==row["bytes"] and hashlib.sha256(blob).hexdigest()==row["sha256"],row["path"]
assert offset==len(batch)
git(["diff","--cached","--check"])
git(["commit","-m","Retain source-bound Hanlin diagnostic privacy validation"])
head=git(["rev-parse","HEAD"]).decode().strip()
assert git(["rev-parse","HEAD^"]).decode().strip()==binding
assert not git(["status","--porcelain=v1","--untracked-files=all"])
for path,tree in source_receipt["trees"].items():
    assert git(["rev-parse",head+":"+path]).decode().strip()==tree
result={"schemaVersion":1,"status":"SOURCE_BINDING_EVIDENCE_COMMITTED_LOCAL_ONLY","base":base,"source":source,"binding":binding,"head":head,"branch":source_receipt["branch"],"worktree":str(work),"packetPath":packet_rel.as_posix(),"packetPayloads":len(payloads),"packetFilesIncludingIndex":len(payloads)+1,"packetBytes":sum(r["bytes"] for r in payloads),"indexSHA256":hashlib.sha256(indexpath.read_bytes()).hexdigest(),"allPayloadStagedGitBlobsVerified":True,"applicationTrees":source_receipt["trees"],"clean":True,"noPushNoSecretNoCI":True}
(temp/"FINAL_RECEIPT.json").write_bytes((json.dumps(result,indent=2)+"\n").encode())
print(json.dumps(result))

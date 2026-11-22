from pathlib import Path,PurePosixPath
import hashlib,json,subprocess,io,datetime
R=Path(r"C:\Users\DAVID\Code\Maktabah-completion-20261122")
S=Path(r"C:\Users\DAVID\Code\Maktabah-hanlin-fresh-read-diagnostic-20261122")
BEFORE="3889c5c037f6d5a2e7b7ea33deb8e4569f410ca7"
INCOMING="997bc6872fed666daef8f720ddd1f847647be80c"
APP="7eb9d2a5c8ac7ccb184e3cc50fb36b6272475ff1"
PK="docs/hq-integration/completion-20261122/hanlin-fresh-read-diagnostic"
D=S/PK
P=R/"docs/hq-integration/completion-20261122/hanlin-fresh-read-integration"
def sha(raw):return hashlib.sha256(raw).hexdigest()
def cmd(repo,*args):
 p=subprocess.run(["git","-c","core.autocrlf=false",*args],cwd=repo,capture_output=True,timeout=45)
 if p.returncode:raise RuntimeError((args,p.returncode,p.stdout.decode(errors="replace"),p.stderr.decode(errors="replace")))
 return p.stdout
def git(repo,*args):return cmd(repo,*args).decode().strip()
def write(p,x):p.write_bytes((json.dumps(x,indent=2,ensure_ascii=False)+"\n").encode())
assert git(R,"rev-parse","HEAD")==BEFORE and not git(R,"status","--porcelain")
assert git(S,"rev-parse","HEAD")==INCOMING and not git(S,"status","--porcelain")
assert not P.exists()
idxraw=(D/"FILE_INDEX.json").read_bytes()
assert sha(idxraw)=="0de80f647fbc1b6d128f82cbf27564c7e6979ac54b6edc2bf273d7682126044e"
idx=json.loads(idxraw);assert len(idx["payloads"])==88 and idx["payloadBytes"]==1063935
expected={x["path"] for x in idx["payloads"]}|{"FILE_INDEX.json"}
assert len(expected)==89
assert expected=={p.relative_to(D).as_posix() for p in D.rglob("*") if p.is_file()}
for x in idx["payloads"]:
 p=PurePosixPath(x["path"]);assert not p.is_absolute() and ".." not in p.parts
 f=D/x["path"];assert f.is_file() and not f.is_symlink()
 raw=f.read_bytes();assert len(raw)==x["bytes"] and sha(raw)==x["sha256"],x["path"]
tree=cmd(S,"ls-tree","-r","-z",INCOMING,"--",PK)
entries={}
for line in tree.split(b"\0"):
 if not line:continue
 meta,path=line.split(b"\t",1);mode,kind,blob=meta.decode().split()
 assert mode=="100644" and kind=="blob"
 entries[path.decode()[len(PK)+1:]]=blob
assert set(entries)==expected
p=subprocess.run(["git","cat-file","--batch"],cwd=S,input=("\n".join(INCOMING+":"+PK+"/"+x for x in entries)+"\n").encode(),capture_output=True,check=True,timeout=30)
stream=io.BytesIO(p.stdout)
for rel,expected_blob in entries.items():
 header=stream.readline().decode().split();assert len(header)==3 and header[1]=="blob" and header[0]==expected_blob
 raw=stream.read(int(header[2]));assert stream.read(1)==b"\n"
 assert raw==(D/rel).read_bytes()
assert not stream.read()
source_review=(D/"ROOT_SOURCE_REVIEW.json").read_bytes()
assert sha(source_review)=="85a7a20c05818af511c25492f92083eb6cf47aac65a8112fdb31344ab57a0ef8"
assert source_review==Path(r"C:\Users\DAVID\AppData\Local\Temp\otzaria-continuation-20261122\fresh-read-root-source-review.json").read_bytes()
binding=json.loads((D/"SOURCE_BINDING.json").read_bytes())
admit=json.loads((D/"raw/admission/RESULT.json").read_bytes())
source_before=json.loads((D/"raw/admission/outputs/build/artifacts/continuation-focused/source-before.json").read_bytes())
inputs=source_before["execution_inputs"];assert len(inputs)==279 and source_before["application_source_sha"]==APP
observed={}
for path,row in inputs.items():
 actual=(S/path).read_bytes()
 assert sha(actual)==row["sha256"] and len(actual)==row["bytes"]
 assert hashlib.sha1(b"blob "+str(len(actual)).encode()+b"\0"+actual).hexdigest()==row["blob"]
 observed[path]=row["blob"]
tree_names=["Source","Vendor","Maktabah.xcodeproj","Maktabah-iOSUITests"]
trees={x:git(S,"rev-parse",INCOMING+":"+x) for x in tree_names}
assert all(trees[x]==git(S,"rev-parse",APP+":"+x) for x in tree_names)
assert all(trees[x]==git(R,"rev-parse",BEFORE+":"+x) for x in tree_names[:3])
expected_changes={"Maktabah-iOSUITests/HanlinConsumerAcceptanceTests.swift","Scripts/CI/completion-focused-native.py",".github/workflows/otzaria-completion-focused-native.yml","Scripts/CI/hq-stage2-focused-apple.inputs.json"}
changed=git(S,"diff","--name-only",BEFORE,INCOMING).splitlines()
assert {x for x in changed if not x.startswith("docs/")}==expected_changes
assert all(x.startswith(PK+"/") for x in changed if x.startswith("docs/"))
assert git(S,"diff","--name-only","7495ef0395f0f675d7f7fea3e22804e065aa85c8",INCOMING).splitlines()==sorted(git(S,"diff","--name-only","7495ef0395f0f675d7f7fea3e22804e065aa85c8",INCOMING).splitlines())
cmd(R,"fetch",str(S),"codex/otzaria-hanlin-fresh-read-diagnostic-20261122")
assert git(R,"rev-parse","FETCH_HEAD")==INCOMING
cmd(R,"merge","--no-ff","-m","Merge source-bound fresh Hanlin read diagnostic",INCOMING)
merge=git(R,"rev-parse","HEAD")
assert git(R,"show","-s","--format=%P",merge).split()==[BEFORE,INCOMING]
assert not git(R,"status","--porcelain")
for path,tree in trees.items():assert git(R,"rev-parse",merge+":"+path)==tree
for path,blob in observed.items():
 assert git(R,"rev-parse",merge+":"+path)==blob
 assert sha((R/path).read_bytes())==inputs[path]["sha256"]
assert git(R,"rev-parse",merge+":"+PK)==git(R,"rev-parse",INCOMING+":"+PK)
P.mkdir()
(P/"ROOT_SOURCE_REVIEW.json").write_bytes(source_review)
(P/"ACTUAL_ROOT_INTEGRATION.py").write_bytes(Path(__file__).read_bytes())
native_run=json.loads("{\"url\":\"https://github.com/davidpovarsky/Maktabah/actions/runs/45006363282\",\"id\":45006363282,\"attempt\":1,\"event\":\"push\",\"head\":\"997bc6872fed666daef8f720ddd1f847647be80c\",\"status\":\"in_progress\",\"conclusion\":null,\"created\":\"2026-11-22T09:12:00Z\",\"observedAt\":\"2026-11-22T09:16:00Z\",\"source\":\"Independent GitHub actions run API read; observation time rounded, not terminal evidence\"}")
write(P/"GITHUB_RUN_OBSERVATION.json",native_run)
receipt={"schema":"otzaria.fresh-read-root-integration/1","utc":datetime.datetime.now(datetime.timezone.utc).isoformat(),
 "status":"SOURCE_AND_EVIDENCE_INTEGRATED_NATIVE_OUTCOME_PENDING","before":BEFORE,"incoming":INCOMING,"merge":merge,
 "parents":[BEFORE,INCOMING],"applicationSource":APP,"applicationTrees":trees,"threeProductionTreesUnchanged":True,
 "packetPayloads":88,"packetBytes":1063935,"exactPacketGitBlobs":89,"packetIndexSHA256":sha(idxraw),
 "admissionResultSHA256":sha((D/"raw/admission/RESULT.json").read_bytes()),"sourceReviewSHA256":sha(source_review),
 "executionGitInputsVerified":279,"changedNonDocumentationPaths":sorted(expected_changes),
 "oneNewCase":"HanlinReaderConsumerAcceptanceTests/testOriginalIPadFreshCurrentWorkReadConnectionWithoutSending",
 "nativeRun":45006363282,"nativeRunOwner":"/root/native_completion","soleObserver":"job_d061e56c2cea",
 "newTestExecutionsForMerge":0,"newArtifactDownloadsForMerge":0,"newProviderKeys":0,
 "limits":["One syntax parse and source-only admission; no new Native pass is claimed before actual result.",
 "Existing Live8 failure and completed204/404 cleanup remain unchanged.",
 "Static no-send constructor audit is not an instrumented whole-application network silence claim."]}
write(P/"INTEGRATION.json",receipt)
(P/"README.md").write_bytes("""# Fresh Hanlin read diagnostic integration

This true merge integrates the reviewed new no-key, no-Send first-conversation Native case and its exact one-case workflow. It changes one original UI-test file, the dedicated selector/route and the application-source binding. The three production source/Vendor/project trees are unchanged; the new original UI-test snapshot is 7eb9d2a5c8ac7ccb184e3cc50fb36b6272475ff1.

Root verified every byte of the 88-payload packet and its 89 exact Git blobs, the retained root source review, all 279 execution-input bytes and Git identities, both source-bound admission receipts and the exact post-merge trees. The original test bytes are recovered by removing only the added 71-line case. No test, preflight, artifact download or provider-key operation was repeated for this merge.

The new case enters the real reader, fills normal connection fields with explicitly unused values, operates the original native consent child, taps Connect and retains safe AX/screenshots before the unchanged strict end-book-access assertion. It does not send a prompt or use private Live input. No saved-history workaround, product identifier change or acceptance fallback is added.

Run45006363282/attempt1 was independently observed in progress at checkout997bc6872fed666daef8f720ddd1f847647be80c. The native_completion agent owns the sole finite observer and resulting artifact intake. This packet records source integration only; the actual Native outcome is pending and full Native116/Release114/Live acceptance remain open.

The original Live8 failure, private-input cleanup and successful secret DELETE204/GET404 evidence remain frozen. The two earlier source/packaging bookkeeping failures in the incoming packet are retained without re-executing passing work.
""".encode())
(P/".gitattributes").write_bytes(b"*.py -text whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol\n")
files=[{"path":p.name,"bytes":p.stat().st_size,"sha256":sha(p.read_bytes())} for p in sorted(P.iterdir()) if p.is_file()]
write(P/"FILE_INDEX.json",{"schema":"otzaria.fresh-read-root-integration-evidence/1","payloadCount":len(files),"payloads":files})
cmd(R,"add","--",P.relative_to(R).as_posix())
cmd(R,"diff","--cached","--check")
cmd(R,"commit","-m","Record independent fresh-read diagnostic integration")
head=git(R,"rev-parse","HEAD")
assert not git(R,"status","--porcelain")
assert all(git(R,"rev-parse",head+":"+p)==value for p,value in trees.items())
print(json.dumps({"status":receipt["status"],"merge":merge,"head":head,"packetPayloads":88,"packetGitBlobs":89,"inputs":279,"proofFiles":len(files)+1,"proofIndexSHA256":sha((P/"FILE_INDEX.json").read_bytes()),"newTestRuns":0,"nativeRun":45006363282,"clean":True}))

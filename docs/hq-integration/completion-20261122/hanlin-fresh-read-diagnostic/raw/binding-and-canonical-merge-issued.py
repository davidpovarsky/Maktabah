from pathlib import Path
import subprocess,json,hashlib,ast,datetime,difflib
repo=Path(r"C:\Users\DAVID\Code\Maktabah-hanlin-fresh-read-diagnostic-20261122")
temp=Path(r"C:\Users\DAVID\AppData\Local\Temp\otzaria-hanlin-fresh-read-diagnostic-20261122")
source="7eb9d2a5c8ac7ccb184e3cc50fb36b6272475ff1"
base="ce5d11335c4b4769a25e0e8f48ba1d6f7efc6749"
incoming="3889c5c037f6d5a2e7b7ea33deb8e4569f410ca7"
paths=["Scripts/CI/completion-focused-native.py",".github/workflows/otzaria-completion-focused-native.yml","Scripts/CI/hq-stage2-focused-apple.inputs.json"]
logs=[]
def sha(b):return hashlib.sha256(b).hexdigest()
def git(*a):
 p=subprocess.run(["git",*a],cwd=repo,capture_output=True,timeout=90)
 logs.append({"args":["git",*a],"exitCode":p.returncode,"stdout":p.stdout.decode("utf8",errors="replace"),"stderr":p.stderr.decode("utf8",errors="replace")})
 assert p.returncode==0,logs[-1];return p.stdout
assert git("rev-parse","HEAD").decode().strip()==source
assert not git("diff","--cached","--name-only").strip()
git("merge-base","--is-ancestor",base,incoming)
changes=git("diff","--name-only",base,incoming).decode().splitlines()
assert all(x.startswith("docs/") for x in changes),changes
for p in ["Source","Vendor","Maktabah.xcodeproj","Maktabah-iOSUITests"]:
 assert git("rev-parse",base+":"+p)==git("rev-parse",incoming+":"+p)
driver=repo/paths[0];old=driver.read_bytes()
assert old.count(b"PENDING_FRESH_READ_TEST_SOURCE")==1
driver.write_bytes(old.replace(b"PENDING_FRESH_READ_TEST_SOURCE",source.encode()))
hq=repo/paths[2];hqold=hq.read_bytes()
assert json.loads(hqold)["application_source_sha"]=="6aa953048453b64a0013621ce76e095770eb7e7d"
assert hqold.count(b"6aa953048453b64a0013621ce76e095770eb7e7d")==1
hq.write_bytes(hqold.replace(b"6aa953048453b64a0013621ce76e095770eb7e7d",source.encode(),1))
tree=ast.parse(driver.read_bytes())
values={}
for n in tree.body:
 if isinstance(n,ast.Assign) and len(n.targets)==1 and isinstance(n.targets[0],ast.Name) and n.targets[0].id in ("SOURCE","GROUPS"):
  values[n.targets[0].id]=ast.literal_eval(n.value)
selector="HanlinReaderConsumerAcceptanceTests/testOriginalIPadFreshCurrentWorkReadConnectionWithoutSending"
assert values["SOURCE"]==source
assert values["GROUPS"]==[{"label":"11-reader","size":"11","hid_comparison":False,"case_ids":[selector]}]
configuration=json.loads(hq.read_bytes())
for p in ["Source","Vendor","Maktabah.xcodeproj"]:
 assert configuration["application_trees"][p]==git("rev-parse",source+":"+p).decode().strip()
workflow=(repo/paths[1]).read_text()
assert "branches: [codex/otzaria-hanlin-fresh-read-diagnostic-20261122]" in workflow
assert "OTZARIA_LIVE_GEMINI_API_KEY" not in workflow
git("-c","core.autocrlf=false","add","--",*paths)
assert set(git("diff","--cached","--name-only").decode().splitlines())==set(paths)
for p in paths:assert git("show",":"+p)==(repo/p).read_bytes()
git("diff","--cached","--check")
git("commit","-m","ci: bind one fresh no-send read diagnostic to exact test source")
binder=git("rev-parse","HEAD").decode().strip()
assert not git("-c","core.autocrlf=false","status","--porcelain").strip()
git("merge","--no-ff",incoming,"-m","merge: retain canonical Live8 failure before fresh-read diagnostic")
head=git("rev-parse","HEAD").decode().strip()
parents=git("rev-list","--parents","-n","1","HEAD").decode().split()[1:]
assert parents==[binder,incoming],parents
for p in ["Source","Vendor","Maktabah.xcodeproj","Maktabah-iOSUITests"]:
 assert git("rev-parse",head+":"+p)==git("rev-parse",source+":"+p)
assert not git("-c","core.autocrlf=false","status","--porcelain").strip()
payload=[]
for p in paths:
 b=(repo/p).read_bytes();pre=git("show",base+":"+p)
 diff="".join(difflib.unified_diff(pre.decode().splitlines(keepends=True),b.decode().splitlines(keepends=True),fromfile="a/"+p,tofile="b/"+p)).encode()
 key="BOUND_DRIVER" if p==paths[0] else "BOUND_WORKFLOW" if p==paths[1] else "HQ_BINDING"
 (temp/(key+".patch")).write_bytes(diff);(temp/(key+"_CANDIDATE")).write_bytes(b)
 payload.append({"path":p,"bytes":len(b),"sha256":sha(b),"patchSHA256":sha(diff)})
receipt={"schema":"otzaria.fresh-read-bound-route/1","status":"FROZEN_LOCAL_NOT_PUSHED","applicationSource":source,"binderCommit":binder,"checkout":head,"parents":parents,"integratedCanonical":incoming,"canonicalIncomingPaths":changes,"selectedCases":[selector],"declarationCount":1,"driverAST":"PASS","files":payload,"sourceTreesUnchangedAfterMetadataMerge":True,"nativeExecuted":False,"commands":logs}
(temp/"BOUND_ROUTE.json").write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+"\n",encoding="utf8",newline="\n")
(temp/"actual-binding-and-canonical-merge.py").write_bytes(Path(__file__).read_bytes())
print(json.dumps({k:v for k,v in receipt.items() if k not in ("commands","canonicalIncomingPaths")}|{"incomingPathCount":len(changes),"receiptSHA256":sha((temp/"BOUND_ROUTE.json").read_bytes())},ensure_ascii=False))
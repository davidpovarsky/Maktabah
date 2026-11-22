import json,hashlib,subprocess,datetime
from pathlib import Path
repo=Path(r"C:\Users\DAVID\Code\Maktabah-hanlin-fresh-read-keyboard-20261122")
base="ae9f63b17b6f9df91d2d125700dc8b62d2aa2cc4"
temp=Path(r"C:\Users\DAVID\AppData\Local\Temp\otzaria-hanlin-fresh-read-keyboard-20261122")/"source-and-binding";temp.mkdir(exist_ok=False)
candidate=Path(r"C:\Users\DAVID\AppData\Local\Temp\otzaria-hanlin-fresh-read-keyboard-20261122\r1\HanlinConsumerAcceptanceTests.swift")
path="Maktabah-iOSUITests/HanlinConsumerAcceptanceTests.swift"
def sha(b):return hashlib.sha256(b).hexdigest()
def git(*a):return subprocess.check_output(["git","-c","core.autocrlf=false",*a],cwd=repo,timeout=90)
assert git("rev-parse","HEAD").decode().strip()==base and git("status","--porcelain=v1").decode()==""
b=candidate.read_bytes();assert sha(b)=="9413eed5741bf3fec8b6c97da86ecb6caed026c7f9e85d80219beb57d037b0a7"
old=git("show",base+":"+path);assert sha(old)=="10b913029739ae3f9f5ca94a220eaaf0329cf07c1b3bb9f62f823d833a5f7c2b"
assert (repo/path).read_bytes()==old
(repo/path).write_bytes(b);git("add","--",path);assert git("show",":"+path)==b
assert git("diff","--cached","--name-only").decode().strip()==path
git("diff","--cached","--check")
(temp/"TEST_SOURCE.patch").write_bytes(git("diff","--cached","--binary"))
git("commit","-m","test: dismiss original keyboard before book consent")
app=git("rev-parse","HEAD").decode().strip()
trees={p:git("rev-parse",app+":"+p).decode().strip() for p in ["Source","Vendor","Maktabah.xcodeproj","Maktabah-iOSUITests"]}
for p in ["Source","Vendor","Maktabah.xcodeproj"]:assert trees[p]==git("rev-parse",base+":"+p).decode().strip()
assert trees["Maktabah-iOSUITests"]!=git("rev-parse",base+":Maktabah-iOSUITests").decode().strip()
driver="Scripts/CI/completion-focused-native.py";hq="Scripts/CI/hq-stage2-focused-apple.inputs.json";workflow=".github/workflows/otzaria-completion-focused-native.yml"
oldsource=b"7eb9d2a5c8ac7ccb184e3cc50fb36b6272475ff1"
for p in [driver,hq]:
 a=(repo/p).read_bytes();assert a.count(oldsource)==1
 c=a.replace(oldsource,app.encode());(repo/p).write_bytes(c)
 (temp/(Path(p).name+".before")).write_bytes(a);(temp/(Path(p).name+".after")).write_bytes(c)
oldbranch=b"codex/otzaria-hanlin-fresh-read-diagnostic-20261122";newbranch=b"codex/otzaria-hanlin-fresh-read-keyboard-native-20261122"
w=(repo/workflow).read_bytes();assert w.count(oldbranch)==1
(repo/workflow).write_bytes(w.replace(oldbranch,newbranch))
(temp/"workflow.before.yml").write_bytes(w);(temp/"workflow.after.yml").write_bytes((repo/workflow).read_bytes())
git("add","--",driver,hq,workflow)
assert set(git("diff","--cached","--name-only").decode().splitlines())=={driver,hq,workflow}
git("diff","--cached","--check");(temp/"BINDING.patch").write_bytes(git("diff","--cached","--binary"))
for p in [driver,hq,workflow]:assert git("show",":"+p)==(repo/p).read_bytes()
git("commit","-m","ci: bind one original fresh-read keyboard continuation")
head=git("rev-parse","HEAD").decode().strip();assert git("status","--porcelain=v1").decode()==""
assert all(git("rev-parse",head+":"+p).decode().strip()==v for p,v in trees.items())
manifest={"schema":"otzaria.fresh-read-keyboard-source-binding/1","status":"FROZEN_NOT_DISPATCHED","created":datetime.datetime.now(datetime.timezone.utc).isoformat(),"base":base,"applicationSource":app,"checkout":head,"applicationTrees":trees,"neutralBranch":git("branch","--show-current").decode().strip(),"triggerBranch":newbranch.decode(),"selector":"HanlinReaderConsumerAcceptanceTests/testOriginalIPadFreshCurrentWorkReadConnectionWithoutSending","source":{"path":path,"sha256":sha(b),"bytes":len(b),"addedLines":12,"priorAllAssertionsUnchanged":True},"bindingOnlyPaths":[driver,hq,workflow],"workflowSha256":sha((repo/workflow).read_bytes()),"driverSha256":sha((repo/driver).read_bytes()),"hqInputsSha256":sha((repo/hq).read_bytes()),"sourceDiffSha256":sha((temp/"TEST_SOURCE.patch").read_bytes()),"bindingDiffSha256":sha((temp/"BINDING.patch").read_bytes()),"testsExecuted":0,"pushed":False}
(temp/"RESULT.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8",newline="\n")
print(json.dumps(manifest))

from pathlib import Path
import subprocess,json,hashlib,datetime,time
repo=Path(r"C:\Users\DAVID\Code\Maktabah-hanlin-fresh-read-diagnostic-20261122")
temp=Path(r"C:\Users\DAVID\AppData\Local\Temp\otzaria-hanlin-fresh-read-diagnostic-20261122")
target="Maktabah-iOSUITests/HanlinConsumerAcceptanceTests.swift"
expected="10b913029739ae3f9f5ca94a220eaaf0329cf07c1b3bb9f62f823d833a5f7c2b"
base="ce5d11335c4b4769a25e0e8f48ba1d6f7efc6749"
swift=Path(r"C:\Users\DAVID\AppData\Local\Programs\Swift\Toolchains\6.3.3+Asserts\usr\bin\swiftc.exe")
def sha(b):return hashlib.sha256(b).hexdigest()
assert sha((repo/target).read_bytes())==expected
assert not (temp/"PARSE_RESULT.json").exists()
args=[str(swift),"-frontend","-parse",str(repo/target)]
start=datetime.datetime.now(datetime.timezone.utc).isoformat();clock=time.monotonic()
p=subprocess.run(args,cwd=repo,capture_output=True,timeout=120)
duration=round(time.monotonic()-clock,3)
(temp/"parse.stdout").write_bytes(p.stdout);(temp/"parse.stderr").write_bytes(p.stderr)
result={"status":"PASS_SYNTAX_ONLY" if p.returncode==0 else "FAIL","command":args,"startedAt":start,"finishedAt":datetime.datetime.now(datetime.timezone.utc).isoformat(),"durationSeconds":duration,"exitCode":p.returncode,"compiler":{"path":str(swift),"bytes":swift.stat().st_size,"sha256":sha(swift.read_bytes())},"candidateSHA256":expected,"stdoutSHA256":sha(p.stdout),"stderrSHA256":sha(p.stderr),"scope":"Complete Swift file parsing only; no Apple/XCTest semantic build or native execution"}
(temp/"PARSE_RESULT.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf8",newline="\n")
assert p.returncode==0,result
logs=[]
def git(*a):
 p=subprocess.run(["git",*a],cwd=repo,capture_output=True,timeout=60)
 logs.append({"args":["git",*a],"exitCode":p.returncode,"stdout":p.stdout.decode("utf8",errors="replace"),"stderr":p.stderr.decode("utf8",errors="replace")})
 assert p.returncode==0,logs[-1];return p.stdout
assert git("rev-parse","HEAD").decode().strip()==base
assert not git("diff","--cached","--name-only").strip()
assert set(git("-c","core.autocrlf=false","diff","--name-only").decode().splitlines())=={target,"Scripts/CI/completion-focused-native.py",".github/workflows/otzaria-completion-focused-native.yml"}
git("-c","core.autocrlf=false","add","--",target)
assert git("diff","--cached","--name-only").decode().splitlines()==[target]
assert sha(git("show",":"+target))==expected
git("-c","core.whitespace=cr-at-eol","diff","--cached","--check")
git("commit","-m","test: capture original fresh read connection without sending")
source=git("rev-parse","HEAD").decode().strip()
trees={x:git("rev-parse",source+":"+x).decode().strip() for x in ["Source","Vendor","Maktabah.xcodeproj","Maktabah-iOSUITests"]}
for x in ["Source","Vendor","Maktabah.xcodeproj"]:assert trees[x]==git("rev-parse",base+":"+x).decode().strip()
assert sha(git("show",source+":"+target))==expected
receipt={"status":"SOURCE_ONLY_LOCAL_NOT_PUSHED","sourceCommit":source,"parent":base,"trees":trees,"candidateSHA256":expected,"parseResultSHA256":sha((temp/"PARSE_RESULT.json").read_bytes()),"commands":logs,"nativeExecuted":False,"productSourceChanged":False}
(temp/"SOURCE_COMMIT.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf8",newline="\n")
(temp/"actual-parse-and-source-seal.py").write_bytes(Path(__file__).read_bytes())
print(json.dumps({"parse":result,"source":{k:v for k,v in receipt.items() if k!="commands"}},ensure_ascii=False))
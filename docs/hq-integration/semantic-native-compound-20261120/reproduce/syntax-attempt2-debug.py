
import pathlib,subprocess,json,hashlib,datetime,os
r=pathlib.Path(r"C:\Users\DAVID\Code\Maktabah-semantic-compound-20261120")
out=r/"build/semantic-native-20261120/syntax-attempt2-debug";out.mkdir(parents=True,exist_ok=True)
compiler=pathlib.Path(r"C:\Users\DAVID\AppData\Local\Programs\Swift\Toolchains\6.3.3+Asserts\usr\bin\swiftc.exe")
paths=[
"Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeRoutingComposition.swift",
"Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSceneSession.swift",
"Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift"]
record={"scope":"DEBUG_SYNTAX_ONLY; no Apple typecheck or Native execution","startedAt":datetime.datetime.now(datetime.timezone.utc).isoformat(),"compiler":str(compiler),"files":[]}
for p in paths:
 raw=(r/p).read_bytes(); args=[str(compiler),"-frontend","-parse","-D","DEBUG","-target","arm64-apple-ios27.0-simulator",str(r/p)]
 cp=subprocess.run(args,cwd=r,capture_output=True,text=True,encoding="utf-8",errors="replace",timeout=60)
 name=pathlib.Path(p).stem
 (out/(name+".stdout.log")).write_text(cp.stdout,encoding="utf-8",newline="\n")
 (out/(name+".stderr.log")).write_text(cp.stderr,encoding="utf-8",newline="\n")
 record["files"].append({"path":p,"sha256":hashlib.sha256(raw).hexdigest(),"command":args,"exitCode":cp.returncode,"warnings":cp.stderr.count("warning:"),"stderr":cp.stderr,"sourceUnchanged":raw==(r/p).read_bytes()})
record["completedAt"]=datetime.datetime.now(datetime.timezone.utc).isoformat()
record["passed"]=all(f["exitCode"]==0 and f["sourceUnchanged"] for f in record["files"])
(out/"RESULT.json").write_text(json.dumps(record,ensure_ascii=False,indent=2)+"\n",encoding="utf-8",newline="\n")
print(json.dumps(record,ensure_ascii=False))

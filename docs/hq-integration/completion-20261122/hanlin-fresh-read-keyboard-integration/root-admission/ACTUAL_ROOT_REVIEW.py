from pathlib import Path
import subprocess,json,hashlib,difflib,datetime,shutil
repo=Path(r"C:\Users\DAVID\Code\Maktabah-hanlin-fresh-read-keyboard-20261122")
prefix="docs/hq-integration/completion-20261122/hanlin-fresh-read-keyboard"
p=repo/prefix
out=Path(r"C:\Users\DAVID\AppData\Local\Temp\otzaria-continuation-20261122\fresh-keyboard-root-admission")
out.mkdir(parents=True,exist_ok=False)
head="cad3742628a37ad4f9eaa3cdbd522d70cb6d0bd1";admitted="aec8162c34598c859c9dc61b6e8b298b5d5d36e6";app="d49cedb3d5c163b7a008248d94b80a2eda28e3ce";prior="ae9f63b17b6f9df91d2d125700dc8b62d2aa2cc4"
ui="Maktabah-iOSUITests/HanlinConsumerAcceptanceTests.swift"
def sha(x):return hashlib.sha256(x).hexdigest()
def git(*args,data=None):
 c=subprocess.run(["git",*args],cwd=repo,input=data,capture_output=True,timeout=30);assert c.returncode==0,(args,c.stderr.decode("utf-8","replace"));return c.stdout
assert git("rev-parse","HEAD").decode().strip()==head and not git("status","--porcelain")
assert git("branch","--show-current").decode().strip()=="codex/otzaria-hanlin-fresh-read-keyboard-evidence-20261122"
for a,b in [(head,admitted),(admitted,app),(app,prior)]:assert git("show","-s","--format=%P",a).decode().split()==[b]
assert git("diff","--name-only",prior,app).decode().splitlines()==[ui]
indexraw=(p/"FILE_INDEX.json").read_bytes();assert sha(indexraw)=="58259786c0bc094034e2b7bc2d14b4f26c47b15e047e093f26f69365ef8e3282"
index=json.loads(indexraw);assert len(index["files"])==index["payloadCount"]==51
assert sum(x["bytes"] for x in index["files"])==index["payloadBytes"]==539164
admission=json.loads((p/"raw/admission/RESULT.json").read_bytes())
assert sha((p/"raw/admission/RESULT.json").read_bytes())=="dd412e45fc7f2ad77ba6131cd402acd3f1139ec189ebc749b2bfc88b95dd7877"
snapshot=json.loads((p/"raw/admission/outputs/build/artifacts/continuation-focused/source-before.json").read_bytes())
assert snapshot["checkout_sha"]==admitted and snapshot["application_source_sha"]==app
source=snapshot["execution_inputs"];assert len(source)==279
tree={}
for row in git("ls-tree","-r","-z",head).split(b"\0"):
 if row:
  meta,path=row.split(b"\t",1);mode,kind,oid=meta.decode().split();tree[path.decode()]=(mode,kind,oid)
wanted=sorted(set(source)|{prefix+"/"+x["path"] for x in index["files"]}|{prefix+"/FILE_INDEX.json"})
batch=git("cat-file","--batch",data=("\n".join(tree[x][2] for x in wanted)+"\n").encode());offset=0;blobs={};bindings=[]
for path in wanted:
 end=batch.index(b"\n",offset);hdr=batch[offset:end].decode().split();n=int(hdr[2]);offset=end+1;raw=batch[offset:offset+n];offset+=n+1
 assert hdr[0]==tree[path][2] and hdr[1]=="blob" and tree[path][0] in ["100644","100755"]
 blobs[path]=raw
 bindings.append({"path":path,"git_blob":hdr[0],"bytes":len(raw),"sha256":sha(raw)})
assert offset==len(batch)
for path,x in source.items():assert tree[path][2]==x["blob"] and sha(blobs[path])==x["sha256"] and len(blobs[path])==x["bytes"],path
for x in index["files"]:
 name=prefix+"/"+x["path"];raw=blobs[name]
 assert sha(raw)==x["sha256"] and len(raw)==x["bytes"] and raw==(p/x["path"]).read_bytes(),name
assert blobs[prefix+"/FILE_INDEX.json"]==indexraw
original=git("show","7eb9d2a5c8ac7ccb184e3cc50fb36b6272475ff1:"+ui)
candidate=blobs[ui]
assert sha(original)=="10b913029739ae3f9f5ca94a220eaaf0329cf07c1b3bb9f62f823d833a5f7c2b"
assert sha(candidate)=="9413eed5741bf3fec8b6c97da86ecb6caed026c7f9e85d80219beb57d037b0a7"
patch="".join(difflib.unified_diff(original.decode().splitlines(True),candidate.decode().splitlines(True),fromfile="a/"+ui,tofile="b/"+ui)).encode()
assert patch==(p/"raw/r1/CANDIDATE.patch").read_bytes() and sha(patch)=="4e0dff5f128b6cce594c14029023ef433678398988e21d2b1ec25411a38912f5"
assert len(candidate.splitlines())-len(original.splitlines())==12
assert b'keyboard.buttons.matching(NSPredicate(format: "label == %@", "Hide keyboard"))' in candidate
bindingpatch=git("diff",app,admitted)
assert bindingpatch==(p/"raw/source-and-binding/BINDING.patch").read_bytes() and sha(bindingpatch)=="0a8e529a9ded1ebccd6572f48273cca401c167d8296113b3ca21668d17127b51"
workflow=".github/workflows/otzaria-completion-focused-native.yml";driver="Scripts/CI/completion-focused-native.py";hq="Scripts/CI/hq-stage2-focused-apple.inputs.json"
assert sorted(git("diff","--name-only",app,admitted).decode().splitlines())==sorted([workflow,driver,hq])
assert sha(blobs[workflow])=="e2306ded02ab66b6c9d0acbaa144c630cbc7d5b44d5230a604241fb521a91b4c"
assert sha(blobs[driver])=="a355447144d28a0f6bc09def3a3b8bb1cfd055a2b9f383cb2b275e5579342fea"
assert blobs[workflow].replace(b"codex/otzaria-hanlin-fresh-read-keyboard-native-20261122",b"codex/otzaria-hanlin-fresh-read-diagnostic-20261122")==git("show",app+":"+workflow)
for path in [driver,hq]:assert blobs[path].replace(app.encode(),b"7eb9d2a5c8ac7ccb184e3cc50fb36b6272475ff1")==git("show",app+":"+path)
assert b"OTZARIA_LIVE_GEMINI_API_KEY" not in blobs[workflow] and b"OTZARIA_LIVE_GEMINI_API_KEY" not in blobs[driver]
for root,oid in snapshot["application_trees"].items():
 assert git("rev-parse",head+":"+root).decode().strip()==oid==git("rev-parse",app+":"+root).decode().strip()
 if root!="Maktabah-iOSUITests":assert oid==git("rev-parse","7eb9d2a5c8ac7ccb184e3cc50fb36b6272475ff1:"+root).decode().strip()
parse=json.loads((p/"raw/r1/RESULT.json").read_bytes())
assert parse["status"]=="PASS" and parse["returncode"]==0 and parse["ownedPID"]==9764 and parse["testsExecuted"]==0
assert parse["source"]["candidateSha256"]==sha(candidate)
compiler=Path(parse["compiler"]["path"]);assert sha(compiler.read_bytes())==parse["compiler"]["sha256"]=="e1d0a0b20d95a92b22f4906e7ca331a7c8b89be86b2d9a2d215ac24f753e945a"
assert admission["status"]=="PASS_SOURCE_ADMISSION_ONLY" and admission["checkout"]==admitted and admission["newTestsExecuted"]==0
assert [c["label"] for c in admission["commands"]]==["focused-prepare","hq-preflight","host48-reuse"]
for c in admission["commands"]:
 assert c["returncode"]==0 and c["durationSeconds"]<c["timeoutSeconds"]
 for stream in ["stdout","stderr"]:
  x=c[stream];raw=(p/"raw/admission"/x["path"]).read_bytes();assert sha(raw)==x["sha256"] and len(raw)==x["bytes"]
for x in admission["retainedOutputs"]:
 raw=(p/"raw/admission"/x["path"]).read_bytes();assert sha(raw)==x["sha256"] and len(raw)==x["bytes"]
selected=json.loads((p/"raw/admission/outputs/build/artifacts/continuation-focused/selection.json").read_bytes())
case="HanlinReaderConsumerAcceptanceTests/testOriginalIPadFreshCurrentWorkReadConnectionWithoutSending"
assert selected["execution_case_ids"]==admission["selectedCases"]==[case] and len(selected["execution_groups"])==1
assert admission["hostReuse"]["newTestsExecuted"]==0 and admission["hostReuse"]["originalTestsPassed"]==48
first=repo/"docs/hq-integration/completion-20261122/hanlin-fresh-read-terminal/raw/FILE_INDEX.json"
assert sha(first.read_bytes())=="20cf00a31cc7c70492380f7e4d02c0d0c8daab6d53b1760bd70385032940699a"
shutil.copyfile(__file__,out/"ACTUAL_ROOT_REVIEW.py")
(out/"GIT_BLOB_BINDINGS.json").write_bytes((json.dumps(bindings,indent=2)+"\n").encode())
result={"schema":"otzaria.fresh-keyboard-root-admission/1","status":"PASS_FOR_ONE_NO_SEND_NATIVE_DIAGNOSTIC","observed_at":datetime.datetime.now(datetime.timezone.utc).isoformat(),"head":head,"admitted_checkout":admitted,"application_source":app,"parent_failure_publication":prior,
 "source_evidence_payloads_verified":51,"source_evidence_index_sha256":sha(indexraw),"execution_inputs_independently_git_verified":279,
 "exact_original_test_inverse":True,"added_lines":12,"native_query":"Unique actual original keyboard button label Hide keyboard; normal native tap then bounded absence before unchanged original consent/Connect/reopen assertions.",
 "three_product_trees_unchanged":True,"all_four_app_trees_bound":True,"binder_delta":"Only focused source SHA, HQ application source SHA and dedicated trigger branch.","actual_local_commands":[{"label":c["label"],"exit_code":c["returncode"],"seconds":c["durationSeconds"]} for c in admission["commands"]],
 "actual_full_file_parse_exit":0,"actual_host48_reuse_not_replay":True,"native_tests_executed_by_review":0,"case":case,"temporary_live_key_needed":False,"provider_send":False,
 "actual_failure_evidence":"Original AX keyboard/window geometry and exact failed hit-test were read. Actual finalPNG1aafa427 viewed by root has no visible keyboard0.410s later; no pixel-proved occlusion or Live8 root cause is inferred.",
 "next_action":"Sole Native owner may push this exact head once to codex/otzaria-hanlin-fresh-read-keyboard-native-20261122; one finite observer and one eventual artifact intake. No other Native/Live tests."}
raw=(json.dumps(result,indent=2)+"\n").encode();(out/"ROOT_REVIEW.json").write_bytes(raw)
print(json.dumps({"status":result["status"],"path":str(out/"ROOT_REVIEW.json"),"sha256":sha(raw),"head":head,"inputs":279,"payloads":51,"observed_at":result["observed_at"]}))

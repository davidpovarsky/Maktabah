import pathlib,subprocess,json,hashlib,zipfile,datetime,traceback
r=pathlib.Path(r"C:\Users\DAVID\Code\anytype-original-editor-package-seal-20261121")
prefix="docs/pinkha/torah-integration/evidence/original-editor-indentation-visibility-20261122"
d=r/prefix
out=pathlib.Path(r"C:\Users\DAVID\AppData\Local\Temp\otzaria-continuation-20261122\visibility71-root-admission")
assert not out.exists(),"receipt destination already exists"
out.mkdir(parents=True)
(out/"ACTUAL_REVIEW_SCRIPT.py").write_bytes(pathlib.Path(__file__).read_bytes())
def sha(b):return hashlib.sha256(b).hexdigest()
def git(*args,input=None):
 p=subprocess.run(["git","-c","core.autocrlf=false",*args],cwd=r,input=input,capture_output=True,timeout=45);p.check_returncode();return p.stdout
def readj(name):return json.loads((d/name).read_bytes())
result={"schema":1,"status":"STARTED","started_at":datetime.datetime.now(datetime.timezone.utc).isoformat(),"tests_executed":0,"artifact_downloads":0,"source_mutations":0}
try:
 head="5c1d08e327bb8155248885e496cf64200932a812"
 assert git("rev-parse","HEAD").decode().strip()==head
 status=git("status","--porcelain=v1").decode("utf-8")
 assert not status.strip(),status
 idx=readj("INDEX.json")
 assert sha((d/"INDEX.json").read_bytes())=="a58b350b7637d1c449894b4435983718ec8a55d3683605786029c22ee0523350"
 assert idx["count"]==len(idx["files"])==70
 wanted={x["path"]:x for x in idx["files"]}
 assert len(wanted)==70
 for n,x in wanted.items():
  p=pathlib.PurePosixPath(n)
  assert not p.is_absolute() and ".." not in p.parts and (d/n).is_file()
  b=(d/n).read_bytes();assert len(b)==x["bytes"] and sha(b)==x["sha256"],n
 actual={p.relative_to(d).as_posix() for p in d.rglob("*") if p.is_file()}
 assert actual==set(wanted)|{"INDEX.json"}
 paths=[prefix+"/"+n for n in sorted(actual)]
 raws=git("cat-file","--batch",input=("\n".join(head+":"+p for p in paths)+"\n").encode("utf-8"))
 offset=0;bindings=[]
 for p in paths:
  nl=raws.index(b"\n",offset);header=raws[offset:nl].decode("ascii").split();assert len(header)==3 and header[1]=="blob"
  n=int(header[2]);b=raws[nl+1:nl+1+n];assert b==(r/p).read_bytes(),p;assert raws[nl+1+n:nl+2+n]==b"\n"
  offset=nl+2+n;bindings.append({"path":p,"git_blob":header[0],"bytes":n,"sha256":sha(b)})
 assert offset==len(raws)
 (out/"GIT_BLOB_BINDINGS.json").write_text(json.dumps(bindings,indent=2)+"\n",encoding="utf-8")
 inputs=readj("COMPILER_INPUTS_V2.json")
 assert sha((d/"COMPILER_INPUTS_V2.json").read_bytes())=="fe33d37e071d97ac07c277a222bb42d153d07ccc523e6296ee924511d10c5f46"
 for x in inputs["compiled_inputs"]:
  b=(d/x["path"]).read_bytes();assert len(b)==x["bytes"] and sha(b)==x["sha256"]
 for x in inputs["original_inputs"]:
  b=git("show",inputs["source_ref"]+":"+x["path"])
  assert b==(d/x["snapshot"]).read_bytes() and sha(b)==x["sha256"]
 before=(d/"BlockIndentationStyle.before.swift").read_bytes()
 candidate=(d/"BlockIndentationStyle.candidate.swift").read_bytes()
 assert before.count(b"public enum BlockIndentationStyle:")==1
 assert before.replace(b"public enum BlockIndentationStyle:",b"enum BlockIndentationStyle:",1)==candidate
 product="Anytype/Sources/PresentationLayer/TextEditor/EditorPage/FlowLayout/Models/BlockIndentationStyle.swift"
 assert git("show",head+":"+product)==candidate==(r/product).read_bytes()
 for mapping in inputs["import_mapping"]:
  raw=(d/mapping["original_input"]).read_bytes()
  portable=(d/mapping["portable_input"]).read_bytes()
  assert raw.count(b"import CoreFoundation")==1
  assert raw.replace(b"import CoreFoundation",b"import Foundation",1)==portable
 gate="tools/original_editor_sdk/framework_products.py"
 gatepaths=git("ls-tree","-r","--name-only",head,"--","tools").decode("utf-8").splitlines()
 matches=[p for p in gatepaths if p.endswith("/framework_products.py")]
 assert len(matches)==1,matches
 gate=matches[0]
 assert git("show",head+":"+gate)==git("show",inputs["source_ref"]+":"+gate)
 assert sha(pathlib.Path(inputs["compiler"]["path"]).read_bytes())==inputs["compiler"]["sha256"]
 execution=readj("COMPILER_EXECUTION_V2.json")
 assert execution["runner_sha256"]==sha((d/"run_visibility_boundary_v2.py").read_bytes())==inputs["runner_sha256"]
 assert execution["inputs_sha256"]==sha((d/"COMPILER_INPUTS_V2.json").read_bytes())
 commands=execution["commands"]
 assert [x["label"] for x in commands]==["complete-original-candidate-syntax","portable-original-candidate-module","expected-external-visibility-rejection-v2"]
 assert [x["returncode"] for x in commands]==[0,0,1]
 for x in commands:
  assert x["phase"]=="TERMINAL" and not x["timed_out"] and x["all_inputs_unchanged"]
  assert x["child_pid"]>0
  for stream in ["stdout","stderr"]:
   b=(d/(x["label"]+"."+stream+".log")).read_bytes()
   assert sha(b)==x[stream+"_sha256"]
 errors=[x for x in (d/"expected-external-visibility-rejection-v2.stderr.log").read_text(encoding="utf-8").splitlines() if " error: " in x]
 assert len(errors)==1 and "cannot find type 'BlockIndentationStyle' in scope" in errors[0],errors
 red=readj("COMPILER_EXECUTION.json")
 assert len(red["commands"])==1 and red["commands"][0]["returncode"]==1 and not red["commands"][0]["timed_out"]
 assert b"no such module 'CoreFoundation'" in (d/"complete-original-candidate-module.stderr.log").read_bytes()
 module=readj("ACTUAL_COMPILER_MODULE.json")
 zbytes=(d/"actual-visibility-compiler-module.zip").read_bytes()
 assert sha(zbytes)==module["archive_sha256"]
 with zipfile.ZipFile(d/"actual-visibility-compiler-module.zip") as z:
  assert z.testzip() is None
  assert len(z.infolist())==len(module["files"])==3
  for x in module["files"]:
   b=z.read(x["name"]);assert sha(b)==x["sha256"] and len(b)==x["bytes"]
 oldbuild=readj("prior-7b59/selected/framework-build.command.json")
 assert oldbuild["returncode"]==0 and not oldbuild["timed_out"]
 assert readj("prior-7b59/selected/macro-trust/macro-restoration.json")["status"]=="EXACT_ORIGINAL_MACRO_TRUST_RESTORED"
 assert sha((d/"prior-7b59/github-artifact-14747819041.zip").read_bytes())==inputs["prior_actual_apple_graph"]["archive_sha256"]
 assert git("rev-parse","HEAD").decode().strip()==head and git("status","--porcelain=v1").decode("utf-8")==status
 result.update(status="PASS",head=head,payload_count=70,exact_git_blobs=71,payload_bytes=sum(x["bytes"] for x in wanted.values()),index_sha256=sha((d/"INDEX.json").read_bytes()),original_git_inputs_verified=3,new_compiler_commands_verified=3,module_files_independently_rehashed=3,raw_first_red_preserved=True,product_delta="exact removal of one public keyword",portable_import_delta="exact two original CoreFoundation imports mapped to genuine Foundation; actual product unchanged",strict_surface_gate_unchanged=True,prior_apple_framework_build={"returncode":0,"started_at":oldbuild["started_at"],"finished_at":oldbuild["finished_at"]},limitations=["Windows module compilation does not establish Apple symbolgraph qualification or Native UI.","Prior Apple xcodebuild PASS retained with actual later public-graph failure; consumer NOT_RUN.","Current SDK run is separately observed by its sole owner; this receipt does not predict its result."])
except Exception:
 result.update(status="FAIL",error=traceback.format_exc())
finally:
 result["finished_at"]=datetime.datetime.now(datetime.timezone.utc).isoformat()
 b=(json.dumps(result,indent=2)+"\n").encode("utf-8");(out/"ROOT_ADMISSION.json").write_bytes(b)
 print(json.dumps({"receipt":str(out/"ROOT_ADMISSION.json"),"receipt_sha256":sha(b),"result":result}))
if result["status"]!="PASS":raise SystemExit(1)

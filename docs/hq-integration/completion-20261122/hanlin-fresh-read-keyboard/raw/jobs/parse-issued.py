import json,hashlib,difflib,subprocess,datetime,time,shutil
from pathlib import Path
root=Path(r"C:\Users\DAVID\AppData\Local\Temp\otzaria-hanlin-fresh-read-keyboard-20261122")
out=root/"r1";out.mkdir(exist_ok=False)
original=(root/"original.swift").read_bytes();prior=(root/"candidate.swift").read_bytes()
assert hashlib.sha256(prior).hexdigest()=="a441c24faf9783c0c643e61267c20c4979143b7ed5e05be4990d9e759a9affb4"
old=b'keyboard.buttons.matching(identifier: "Hide keyboard")'
new=b'keyboard.buttons.matching(NSPredicate(format: "label == %@", "Hide keyboard"))'
assert prior.count(old)==1
candidate=prior.replace(old,new);anchor=b'        key.typeText("ui-no-send-credential")\n'
start=candidate.index(anchor)+len(anchor);end=candidate.index(b'        let form = ',start)
assert candidate[:start]+candidate[end:]==original
path="Maktabah-iOSUITests/HanlinConsumerAcceptanceTests.swift"
(out/"HanlinConsumerAcceptanceTests.swift").write_bytes(candidate)
patch="".join(difflib.unified_diff(original.decode().splitlines(True),candidate.decode().splitlines(True),fromfile="a/"+path,tofile="b/"+path))
delta="".join(difflib.unified_diff(prior.decode().splitlines(True),candidate.decode().splitlines(True),fromfile="candidate-v0.swift",tofile="candidate-v1.swift"))
(out/"CANDIDATE.patch").write_text(patch,encoding="utf-8",newline="\n");(out/"QUERY_CORRECTION.patch").write_text(delta,encoding="utf-8",newline="\n")
compiler=shutil.which("swiftc");assert compiler
version=subprocess.run([compiler,"--version"],stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=30)
(out/"compiler-version.stdout").write_bytes(version.stdout);(out/"compiler-version.stderr").write_bytes(version.stderr);assert version.returncode==0
cmd=[compiler,"-frontend","-parse",str(out/"HanlinConsumerAcceptanceTests.swift")]
t=time.monotonic();started=datetime.datetime.now(datetime.timezone.utc).isoformat()
with (out/"parse.stdout").open("wb") as so,(out/"parse.stderr").open("wb") as se:
 process=subprocess.Popen(cmd,stdout=so,stderr=se);pid=process.pid;code=process.wait(timeout=60)
sha=lambda b:hashlib.sha256(b).hexdigest()
result={"status":"PASS" if code==0 else "FAIL","created":datetime.datetime.now(datetime.timezone.utc).isoformat(),"started":started,"duration":time.monotonic()-t,"command":cmd,"ownedPID":pid,"returncode":code,"source":{"path":path,"originalSha256":sha(original),"previousCandidateSha256":sha(prior),"candidateSha256":sha(candidate),"candidateBytes":len(candidate),"candidatePatchSha256":sha(patch.encode()),"queryCorrectionSha256":sha(delta.encode()),"addedLines":12,"exactInverseRestoresOriginal":True},"compiler":{"path":compiler,"sha256":sha(Path(compiler).read_bytes()),"version":version.stdout.decode(errors="replace")},"platform":"Windows full-file Swift syntax parse only; not Apple module typechecking or native runtime qualification.","testsExecuted":0,"productFilesChanged":0}
(out/"RESULT.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8",newline="\n")
print(json.dumps(result));assert code==0

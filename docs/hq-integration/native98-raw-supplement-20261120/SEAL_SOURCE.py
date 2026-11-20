import ast,collections,datetime,gzip,hashlib,json,re,zipfile
from pathlib import Path
ROOT=Path("/workspace/scratch/8c31d602ec0a/native98-raw-supplement-20261120")
SUMMARY=Path("/workspace/scratch/8c31d602ec0a/native98-observed-summary-20261120/packet/docs/hq-integration/native98-observed-summary-20261120")
D=ROOT/"packet/docs/hq-integration/native98-raw-supplement-20261120"
F="60a57972acb28739ec738565083bf17fb7503028"
M="87b783ac3f0257e8461762e0ea9dfa5248dd06e8"
BASE="421af5c303b09c13811ff5a687404fa3db1765c6"
ZIP=ROOT/"native98-evidence-14632383919.zip"
def sha(b): return hashlib.sha256(b).hexdigest()
def gitblob(b): return hashlib.sha1(b"blob "+str(len(b)).encode()+b"\0"+b).hexdigest()
def write(p,b):
 p.parent.mkdir(parents=True,exist_ok=True)
 if isinstance(b,str):b=b.encode()
 p.write_bytes(b)
def writej(p,v):write(p,json.dumps(v,ensure_ascii=False,indent=2)+"\n")
def walk(v):
 if isinstance(v,list):
  for n in v:yield from walk(n)
 elif isinstance(v,dict):
  if v.get("nodeType")=="Test Case":yield v
  for n in v.values():
   if isinstance(n,(dict,list)):yield from walk(n)
D.mkdir(parents=True,exist_ok=True)
ev=json.loads((SUMMARY/"EVALUATION.json").read_bytes())
manifest_raw=(SUMMARY/"FROZEN_R27_CASES.json").read_bytes()
manifest=json.loads(manifest_raw)
old_leaves=json.loads((SUMMARY/"ACTUAL_LEAF_PROJECTION.json").read_bytes())
assert sha(manifest_raw)=="e4f3fd204cdbc40c3aaa1616e84046ff6aaf4238f776cb41912838987af6cd75"
assert manifest["source_test_commit"]==M and manifest["app_source"]==M
assert len(manifest["execution_case_ids"])==98 and len(set(manifest["execution_case_ids"]))==98
assert ev["run"]["head"]==F and ev["run"]["appSource"]==M
assert ev["run"]["conclusion"]=="cancelled"
assert {x["caseID"] for x in ev["cases"]}==set(manifest["execution_case_ids"])
assert collections.Counter(x["result"] for x in ev["cases"])=={"Passed":22,"Failed":9,"RAW_FAILED":1,"UNKNOWN_AFTER_START":1,"NOT_OBSERVED_STARTED":65}
zip_bytes=ZIP.read_bytes()
assert len(zip_bytes)==35944918
assert sha(zip_bytes)=="1dec4baa131deaa5cfdb1f2f62b3dea6a84ee7713bccf67a2e62a41f1ff72310"
payloads=[]
def payload(name,data,origin,compress=True):
 rel="raw/"+name+(".gz" if compress else "")
 b=gzip.compress(data,compresslevel=6,mtime=0) if compress else data
 assert (gzip.decompress(b) if compress else b)==data
 write(D/rel,b)
 payloads.append({"path":rel,"origin":origin,"originalBytes":len(data),"originalSHA256":sha(data),"storedBytes":len(b),"storedSHA256":sha(b),"gitBlob":gitblob(b),"compression":"gzip_mtime0" if compress else "none"})
part_size=8_388_576
parts=[]
for offset in range(0,len(zip_bytes),part_size):
 part=zip_bytes[offset:offset+part_size]
 name=f"archive/runtime27-evidence-14632383919.zip.part{len(parts)+1:02d}"
 payload(name,part,"Contiguous unchanged original ZIP bytes",False)
 parts.append({"path":"raw/"+name,"offset":offset,"bytes":len(part),"sha256":sha(part),"gitBlob":gitblob(part)})
writej(D/"ARCHIVE_REASSEMBLY.json",{"artifactID":14632383919,"originalBytes":len(zip_bytes),"originalSHA256":sha(zip_bytes),"originalGitBlob":gitblob(zip_bytes),"parts":parts,"reason":"Git connector MCP request body has a 16 MiB limit; original ZIP bytes are preserved exactly in ordered parts"})
old_copy=D/"raw/runtime27-evidence-14632383919.zip"
if old_copy.exists():
 assert old_copy.read_bytes()==zip_bytes and ZIP.is_file()
 old_copy.unlink()
verification=[];leaves=[];members=[]
selected=[
"hq-stage2/result.json","hq-stage2/actual-source-inputs.json","hq-stage2/simulator-build-for-testing.log",
"artifacts/test-simulator-11.log","artifacts/test-simulator-11-search.log","artifacts/test-simulator-11-index.log",
"artifacts/test-case-execution-11.json","artifacts/test-case-execution-11-search.json",
"artifacts/faithful-ipad-matrix.json","artifacts/native-routing-logs-11/otzaria-reader.log",
"artifacts/runtime27/native-matrix-driver.log","artifacts/runtime27/selected-test-declarations.json",
"artifacts/runtime27/toolchain-selection.json","artifacts/miniTest10-native-fixture-install-11-index.json",
"artifacts/runtime27/fixture-oracle-11-index.json"]
with zipfile.ZipFile(ZIP) as z:
 assert len(z.infolist())==102 and z.testzip() is None
 assert len({i.filename for i in z.infolist()})==102
 for i in z.infolist():
  assert not Path(i.filename).is_absolute() and ".." not in Path(i.filename).parts
  b=z.read(i)
  members.append({"path":i.filename,"bytes":len(b),"compressedBytes":i.compress_size,"crc32":f"{i.CRC:08x}","sha256":sha(b)})
 for group,passed,failed in (("11",2,7),("11-search",20,2)):
  prefix=f"artifacts/runtime27/verified-{group}."
  receipt=json.loads(z.read(prefix+"json"))
  for suffix,key in (("summary.json","summary_sha256"),("tests.json","tests_sha256")):
   b=z.read(prefix+suffix);v=json.loads(b);canonical=json.dumps(v,sort_keys=True).encode()
   assert sha(canonical)==receipt[key]
   assert sha(b)!=sha(canonical)
   verification.append({"path":prefix+suffix,"rawBytes":len(b),"rawSHA256":sha(b),"receiptHashRepresentation":"SHA256(json.dumps(value, sort_keys=True).encode())","canonicalBytes":len(canonical),"canonicalSHA256":sha(canonical),"receiptExpected":receipt[key],"match":True,"rawBytesUnmodified":True})
  summary=json.loads(z.read(prefix+"summary.json"))
  assert summary["passedTests"]==passed and summary["failedTests"]==failed and summary["skippedTests"]==0
  nodes=list(walk(json.loads(z.read(prefix+"tests.json"))))
  assert len(nodes)==passed+failed
  for n in nodes:
   cid=n["nodeIdentifier"].removesuffix("()")
   old=next(x for x in old_leaves if x["caseID"]==cid)
   assert old["group"]==group and old["result"]==n["result"] and old["durationSeconds"]==n["durationInSeconds"]
   leaves.append({"caseID":cid,"group":group,"result":n["result"],"durationSeconds":n["durationInSeconds"],"rawSource":prefix+"tests.json"})
  selected.extend(prefix+s for s in ("json","summary.json","tests.json"))
 build=json.loads(z.read("hq-stage2/result.json"))
 assert build["status"]=="SIMULATOR_BUILD_FOR_REAL_UI_PASS"
 assert build["checkout_sha"]==F and build["application_source_sha"]==M
 assert build["actual_source_inputs_verified"]==996
 rawindex=z.read("artifacts/test-simulator-11-index.log").decode()
 assert re.search(r"testCorruptIndexShowsRepairRequiredAndOriginalRepairSurvivesColdLaunch.*failed \(203\.536 seconds\)",rawindex)
 assert re.search(r"testHealthySearchDataAndColdLaunchMatchInstalledDocumentCount.*started",rawindex)
 assert not re.search(r"testHealthySearchDataAndColdLaunchMatchInstalledDocumentCount.*(?:passed|failed|skipped) \(",rawindex)
 for rel in selected:payload("selected/"+rel,z.read(rel),"Exact ZIP member: "+rel)
assert len(leaves)==31 and len({x["caseID"] for x in leaves})==31
assert {x["caseID"] for x in leaves}=={x["caseID"] for x in old_leaves}
assert collections.Counter(x["result"] for x in leaves)=={"Passed":22,"Failed":9}
old_finalizer=(ROOT/"previous-finalizer-not-executed.py").read_text()
node=next(n for n in ast.parse(old_finalizer).body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=="ATTEMPTS_JSON" for t in n.targets))
attempts=json.loads(ast.literal_eval(node.value))
assert len(attempts)==3
attempt_info=[]
for a in attempts:
 r=a["result"];assert r["status"]=="failed"
 payload("sealing/"+a["name"]+"-result.json",(json.dumps(r,ensure_ascii=False,indent=2)+"\n").encode(),"Actual Sentinel evidence-packaging receipt; no test execution")
 payload("sealing/"+a["name"]+"-source.py",a["source"].encode(),"Exact submitted evidence-only script; attempt3 failed before process launch")
 attempt_info.append({"attempt":a["name"],"jobID":r["id"],"status":r["status"],"exitCode":r.get("exit_code"),"error":r.get("error"),"scope":"EVIDENCE_PACKAGING_ONLY"})
payload("source/windows-finalizer-NOT_EXECUTED.py",old_finalizer.encode(),"Prepared after attempt3; never executed while host offline")
writej(D/"ZIP_MEMBERS_SHA256.json",{"members":members,"memberCount":102,"allCRCVerified":True})
writej(D/"RAW_CANONICAL_HASH_VERIFICATION.json",{"rawAndCanonicalDistinct":True,"records":verification})
writej(D/"RECHECKED_LEAVES.json",leaves)
write(D/"LOCAL_TRANSFER_VERIFICATION.json",(ROOT/"LOCAL_TRANSFER_VERIFICATION.json").read_bytes())
writej(D/"EVIDENCE_RECHECK.json",{
"verifiedAtUTC":datetime.datetime.now(datetime.timezone.utc).isoformat(),"baseSummaryCommit":BASE,"run":ev["run"],
"selection":{"count":98,"manifestSHA256":sha(manifest_raw),"manifestSource":"../native98-observed-summary-20261120/FROZEN_R27_CASES.json"},
"build":{"reportedStatus":build["status"],"reportedActualSourceInputsVerified":996,"checkout":F,"applicationSource":M,"applicationTrees":build["application_trees"],"xcode":build["xcode"],"swift":build["swift"],"sdk":build["sdk_version"],"scope":"Original build record revalidated; no new compilation"},
"verifiedLeaves":{"total":31,"passed":22,"failed":9,"skipped":0,"devices":"iPad only"},
"incomplete":{"rawIndexFailure":1,"rawStartedWithoutCompletion":1,"notObservedStarted":65,"totalWithoutCompleteXCresult":67},
"workflowConclusion":"cancelled","full98Acceptance":"INCOMPLETE","HID":"NOT_REACHED","phoneVerifiedLeaves":0,
"smallArtifact":{"id":14632383919,"bytes":len(zip_bytes),"sha256":sha(zip_bytes),"zipMembers":102,"allMemberCRCPass":True,"publishedExactZIP":True},
"captureArtifact":{"id":14632274701,"fullArchiveDownloaded":False,"fullArchiveSHAVerified":False,"selectedRangeEvidenceStillOnOfflineWindows":True,"priorAuthenticatedProjectionSummary":BASE},
"sealingAttempts":attempt_info,"appTestsRerun":False,"currentSourceAcceptanceTransferred":False,
"limitations":["No final source Native credit","No attribution of cancellation actor or cause","Range/capture original bytes are not included in this supplement","This rechecks exported evidence and does not run the app, engine, build, or tests"]})
writej(D/"ARTIFACTS.json",{"schema":1,"entries":payloads})
write(D/"README.md",f"""# Native98 exact raw artifact supplement

This docs-only supplement completes durable publication of the **original small evidence ZIP** for run 44723902453. It follows summary commit {BASE}. It does not run or retry a test.

- Checkout: {F}; app/tests: {M}; attempt 1.
- Workflow conclusion: **cancelled**. The actor and cause remain unknown.
- Original Simulator build: SIMULATOR_BUILD_FOR_REAL_UI_PASS, with 996 source inputs reported verified by the original build record.
- Complete XCresult exports: **31 unique iPad leaves: 22 PASS, 9 FAIL, 0 SKIP**.
- Remaining 67 selected cases: one completed raw INDEX failure, one raw start with no terminal result, and 65 whose start is not observed in retained logs. iPhone and HID acceptance are not established.
- Full 98-case acceptance remains incomplete. No result is transferred to a newer source.

## Byte integrity

ARCHIVE_REASSEMBLY.json binds five ordered parts under raw/archive that reconstruct the complete unchanged 35,944,918-byte artifact: SHA256 1dec4baa131deaa5cfdb1f2f62b3dea6a84ee7713bccf67a2e62a41f1ff72310. Splitting is necessary because the Git connector rejects requests over 16 MiB; no original byte is omitted or transformed. All 102 ZIP members passed CRC and are individually SHA-bound in ZIP_MEMBERS_SHA256.json. The partial INDEX .mp4.sb member is retained exactly as received; its presence does not prove a complete video or additional test outcome.

ARTIFACTS.json binds the original ZIP and selected lossless gzip payloads by original and stored byte lengths, SHA256, and canonical Git blob IDs. The selected payloads retain full build output, all three raw test logs, complete XCresult trees/summaries/receipts, the matrix and original Reader log.

The four original verified receipts describe canonical JSON hashes, while the ZIP members contain pretty JSON. RAW_CANONICAL_HASH_VERIFICATION.json proves both independently without rewriting any raw byte. This was a packaging comparison error, not a failed Native test.

## Preserved failed packaging attempts

The exact sources and actual receipts of job_11a81e864442, job_50418e0d76b8, and job_4f77deafc2da are included. They respectively failed on raw-versus-canonical hash comparison, an absent optional input path after source/leaf checks, and Windows argument length before process launch. The later Windows finalizer is explicitly marked NOT_EXECUTED. The local validator included here only checks evidence.

## Capture boundary

This supplement does **not** download or publish the 775,094,118-byte capture archive. Its previously selected, range-authenticated original bytes still reside on the disconnected Windows host. Summary {BASE} preserves the prior observations and this publication limit. The full capture-archive digest remains advertised-only, not independently verified.

## Reproduction

Run python3 VERIFY_PACKET.py from this directory. It verifies the packet SHA/Git identities, all gzip round trips, the complete ZIP and CRCs, all four canonical receipt hashes, the 31 named leaves and 98-case classification, and both raw INDEX observations. This is evidence validation; it grants no compile, UI, HID, physical-device, or final-source acceptance.
""")
write(D/"SEAL_SOURCE.py",Path(__file__).read_bytes())
print(json.dumps({"status":"SEALED_LOCAL_RAW","directory":str(D),"payloads":len(payloads),"bytes":sum(p.stat().st_size for p in D.rglob("*") if p.is_file()),"leaves":len(leaves),"testExecution":False}))

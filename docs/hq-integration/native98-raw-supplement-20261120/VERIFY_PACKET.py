"""Read-only byte/source/result validation. This does not run app code or tests."""
import collections,gzip,hashlib,io,json,re,zipfile
from pathlib import Path
D=Path(__file__).resolve().parent
def sha(b):return hashlib.sha256(b).hexdigest()
def blob(b):return hashlib.sha1(b"blob "+str(len(b)).encode()+b"\0"+b).hexdigest()
def load(name):return json.loads((D/name).read_bytes())
def walk(v):
 if isinstance(v,list):
  for x in v:yield from walk(x)
 elif isinstance(v,dict):
  if v.get("nodeType")=="Test Case":yield v
  for x in v.values():
   if isinstance(x,(dict,list)):yield from walk(x)
index=load("PACKET_INDEX.json")
entries=index["files"]
assert len({x["path"] for x in entries})==len(entries)
assert {x["path"] for x in entries}=={p.relative_to(D).as_posix() for p in D.rglob("*") if p.is_file() and p.name!="PACKET_INDEX.json"}
for item in entries:
 b=(D/item["path"]).read_bytes()
 assert len(b)==item["bytes"] and sha(b)==item["sha256"] and blob(b)==item["gitBlob"],item["path"]
plan=load("ARCHIVE_REASSEMBLY.json")
archive=bytearray()
for item in plan["parts"]:
 b=(D/item["path"]).read_bytes()
 assert item["offset"]==len(archive)
 assert len(b)==item["bytes"] and sha(b)==item["sha256"] and blob(b)==item["gitBlob"]
 archive.extend(b)
assert len(archive)==plan["originalBytes"]==35944918
assert sha(archive)==plan["originalSHA256"]=="1dec4baa131deaa5cfdb1f2f62b3dea6a84ee7713bccf67a2e62a41f1ff72310"
assert blob(archive)==plan["originalGitBlob"]
for item in load("ARTIFACTS.json")["entries"]:
 b=(D/item["path"]).read_bytes()
 assert len(b)==item["storedBytes"] and sha(b)==item["storedSHA256"] and blob(b)==item["gitBlob"]
 data=gzip.decompress(b) if item["compression"]=="gzip_mtime0" else b
 assert len(data)==item["originalBytes"] and sha(data)==item["originalSHA256"]
recheck=load("EVIDENCE_RECHECK.json")
summary=D.parent/"native98-observed-summary-20261120"
manifest_bytes=(summary/"FROZEN_R27_CASES.json").read_bytes()
assert sha(manifest_bytes)==recheck["selection"]["manifestSHA256"]
manifest=json.loads(manifest_bytes)
expected_ids=manifest["execution_case_ids"]
assert len(expected_ids)==98 and len(set(expected_ids))==98
prior=json.loads((summary/"EVALUATION.json").read_bytes())
assert {x["caseID"] for x in prior["cases"]}==set(expected_ids)
assert collections.Counter(x["result"] for x in prior["cases"])=={"Passed":22,"Failed":9,"RAW_FAILED":1,"UNKNOWN_AFTER_START":1,"NOT_OBSERVED_STARTED":65}
leaves=[]
with zipfile.ZipFile(io.BytesIO(archive)) as z:
 assert len(z.infolist())==102 and z.testzip() is None
 members=load("ZIP_MEMBERS_SHA256.json")["members"]
 assert {i.filename for i in z.infolist()}=={i["path"] for i in members}
 for m in members:
  b=z.read(m["path"]);i=z.getinfo(m["path"])
  assert len(b)==m["bytes"] and sha(b)==m["sha256"] and f"{i.CRC:08x}"==m["crc32"]
 for v in load("RAW_CANONICAL_HASH_VERIFICATION.json")["records"]:
  b=z.read(v["path"]);canonical=json.dumps(json.loads(b),sort_keys=True).encode()
  assert sha(b)==v["rawSHA256"] and sha(canonical)==v["canonicalSHA256"]==v["receiptExpected"]
  assert sha(b)!=sha(canonical)
 for group,p,f in (("11",2,7),("11-search",20,2)):
  prefix=f"artifacts/runtime27/verified-{group}."
  s=json.loads(z.read(prefix+"summary.json"))
  assert (s["passedTests"],s["failedTests"],s["skippedTests"])==(p,f,0)
  for n in walk(json.loads(z.read(prefix+"tests.json"))):
   leaves.append({"caseID":n["nodeIdentifier"].removesuffix("()"),"group":group,"result":n["result"],"durationSeconds":n["durationInSeconds"],"rawSource":prefix+"tests.json"})
 assert leaves==load("RECHECKED_LEAVES.json")
 assert len(leaves)==31 and len({x["caseID"] for x in leaves})==31
 assert {x["caseID"] for x in leaves}.issubset(expected_ids)
 assert collections.Counter(x["result"] for x in leaves)=={"Passed":22,"Failed":9}
 build=json.loads(z.read("hq-stage2/result.json"))
 assert build["checkout_sha"]==recheck["run"]["head"]=="60a57972acb28739ec738565083bf17fb7503028"
 assert build["application_source_sha"]==recheck["run"]["appSource"]==manifest["app_source"]=="87b783ac3f0257e8461762e0ea9dfa5248dd06e8"
 assert build["status"]=="SIMULATOR_BUILD_FOR_REAL_UI_PASS" and build["actual_source_inputs_verified"]==996
 raw=z.read("artifacts/test-simulator-11-index.log").decode()
 assert re.search(r"testCorruptIndexShowsRepairRequiredAndOriginalRepairSurvivesColdLaunch.*failed \(203\.536 seconds\)",raw)
 assert re.search(r"testHealthySearchDataAndColdLaunchMatchInstalledDocumentCount.*started",raw)
 assert not re.search(r"testHealthySearchDataAndColdLaunchMatchInstalledDocumentCount.*(?:passed|failed|skipped) \(",raw)
for i,job in enumerate(("job_11a81e864442","job_50418e0d76b8","job_4f77deafc2da"),1):
 r=json.loads(gzip.decompress((D/f"raw/sealing/attempt{i}-result.json.gz").read_bytes()))
 assert r["id"]==job and r["status"]=="failed"
print(json.dumps({"status":"EVIDENCE_BYTES_AND_ACCOUNTING_VERIFIED","packetFiles":len(entries)+1,"archiveBytes":len(archive),"zipMembers":102,"zipCRC":"PASS","canonicalReceiptChecks":4,"uniqueXCresultLeaves":31,"passed":22,"failed":9,"skipped":0,"withoutCompleteLeaves":67,"workflow":"cancelled","packagingFailuresRetained":3,"appOrTestsExecuted":False,"NativeAcceptance":"INCOMPLETE","captureFullArchiveVerified":False},sort_keys=True))

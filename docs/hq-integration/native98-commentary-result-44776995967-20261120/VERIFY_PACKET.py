#!/usr/bin/env python3
"""Recheck retained processor result; does not download or execute Native."""
import argparse,hashlib,importlib.util,json,pathlib,zipfile
p=argparse.ArgumentParser();p.add_argument("--root",type=pathlib.Path,required=True);a=p.parse_args()
root=a.root.resolve();doc=pathlib.Path(__file__).resolve().parent
manifest=json.loads((doc/"MANIFEST.json").read_text())
for f in manifest["files"]:
 d=(doc/f["path"]).read_bytes()
 assert len(d)==f["bytes"] and hashlib.sha256(d).hexdigest()==f["sha256"],f["path"]
run=json.loads((doc/"PROCESSOR_RUN.json").read_text()); jobs=json.loads((doc/"PROCESSOR_JOBS.json").read_text()); git=json.loads((doc/"PROCESSOR_SOURCE.json").read_text())
assert run["id"]==44776995967 and run["head_sha"]=="d749a2222ff06ae723d14bb174ead19331004e91" and run["event"]=="push" and run["run_attempt"]==1 and run["conclusion"]=="success"
assert run["repository"]["id"]==1280062128 and len(jobs["jobs"])==1
job=jobs["jobs"][0];assert job["id"]==136429340664 and job["head_sha"]==run["head_sha"] and job["conclusion"]=="success"
assert all(s["conclusion"]=="success" for s in job["steps"])
for f in git["inputs"]:
 d=(root/f["path"]).read_bytes();assert len(d)==f["bytes"] and hashlib.sha256(d).hexdigest()==f["sha256"]
 assert hashlib.sha1(b"blob "+str(len(d)).encode()+b"\0"+d).hexdigest()==f["gitBlob"]
meta=json.loads((doc/"ARTIFACT_METADATA.json").read_text());blob=(doc/"raw/artifact.zip").read_bytes()
assert len(blob)==683830==meta["size_in_bytes"] and hashlib.sha256(blob).hexdigest()=="f2772aa98ca34e31029eecd6b7e3f7a1ff5681c46ab09718d448167ca3b094bf"
driver=root/"Scripts/CI/native98-commentary-evidence.py";s=importlib.util.spec_from_file_location("historical_processor",driver);m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
contract=json.loads(driver.with_suffix(".json").read_text())
with zipfile.ZipFile(doc/"raw/artifact.zip") as z:
 assert len(z.namelist())==len(set(z.namelist()))==16 and z.testzip() is None
 read=lambda n:json.loads(z.read(n))
 result=read("RESULT.json");before=read("SOURCE_BEFORE.json");after=read("SOURCE_AFTER.json")
 assert before==after and before["head"]==run["head_sha"] and before["tree"]==git["tree"] and str(before["runId"])==str(run["id"])
 assert len(before["inputs"])==4 and {f["path"]:f for f in before["inputs"]}=={f["path"]:f for f in git["inputs"]}
 for when in ["BEFORE","AFTER"]:m.validate_metadata(*(read("SOURCE_"+k+"_"+when+".json") for k in ["RUN","ARTIFACT","JOB"]),contract)
 assert result["qualified"] is True and result["nativeExecutions"]==result["applicationTestExecutions"]==0 and result["sourceRunConclusion"]=="cancelled"
 proof=read("EXTRACTION_PROOF.json");assert result["extraction"]==proof
 entries=read("FULL_ARCHIVE_MEMBER_VERIFICATION.json");assert len(entries)==proof["archiveMemberCount"]==3686 and all(e["crcVerified"] for e in entries)
 index={e["path"]:e for e in entries};assert len(index)==len(entries)
 assert proof["archiveBytes"]==775094118 and proof["archiveSha256"]=="7ce28dc10dbdfb6a52fe15e0eb0ec4bfaef746f8165974d060367cf61594a69d"
 assert proof["fullArchiveHashVerifiedBeforeAndAfter"] and proof["allMembersCRCVerified"]
 assert {e["path"] for e in proof["selected"]}=={e["path"] for e in contract["selectedMembers"]}
 for e in proof["selected"]:
  b=z.read("entries/"+e["path"]);assert len(b)==e["bytes"] and hashlib.sha256(b).hexdigest()==e["sha256"] and index[e["path"]]==e
  assert (doc/"captures"/pathlib.PurePosixPath(e["path"]).name).read_bytes()==b
 receipt=read("DOWNLOAD_RECEIPT.json");assert receipt["bytes"]==775094118 and receipt["sha256"]==proof["archiveSha256"] and receipt["authorizationForwardedToStorage"] is False
 controls=z.read("python-controls.log").decode();assert "Ran 40 tests" in controls and controls.rstrip().endswith("OK")
print(json.dumps({"sealed_files":len(manifest["files"]),"processor_run":run["id"],"small_zip_crc":16,"canonical_processor_inputs":4,"ci_original_archive_verified_bytes":775094118,"ci_original_members_crc":3686,"selected_original_files":3,"new_native_executions":0,"original_native_conclusion":"cancelled","scope":"Result/provenance replay only; full original ZIP was verified by the recorded CI run, not downloaded by this replay."},sort_keys=True))

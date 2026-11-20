#!/usr/bin/env python3
"""Verify sealed bytes, source inverse and actual recorded outcomes; never run Native UI."""
import argparse,gzip,hashlib,json,pathlib,struct,subprocess
ROOT=pathlib.Path(__file__).resolve().parents[3]
REL="docs/hq-integration/normal-ios-orientation-44716258538-20261120"
P=argparse.ArgumentParser();P.add_argument("--git-ref");A=P.parse_args()
def read(path):
 if A.git_ref:
  return subprocess.run(["git","-C",str(ROOT),"show",A.git_ref+":"+path],check=True,capture_output=True).stdout
 return (ROOT/path).read_bytes()
def local(path):return read(REL+"/"+path)
def raw_json(path):return json.loads(gzip.decompress(local(path)))
def sha(b):return hashlib.sha256(b).hexdigest()
manifest=json.loads(local("MANIFEST.json"))
for entry in manifest["files"]:
 b=local(entry["path"]);assert len(b)==entry["bytes"] and sha(b)==entry["sha256"],entry["path"]
baseline=gzip.decompress(local("source/BASELINE.sh.gz")).decode()
candidate=gzip.decompress(local("source/CANDIDATE.sh.gz")).decode()
proof=raw_json("raw/repair/SOURCE_INVERSE.json.gz")
assert sha(baseline.encode())==proof["baselineSHA256"]
assert sha(candidate.encode())==proof["candidateSHA256"]
assert read("Scripts/run-ipad-simulator-acceptance.sh").replace(b"\r\n",b"\n")==candidate.encode()
restored=candidate.replace(proof["addedComment"],"",1).replace(proof["newFailureWording"],proof["oldFailureWording"],1)
restored=restored.replace("set_orientation() {",proof["removedFunction"]+"set_orientation() {",1)
anchors=[
 '  xcrun simctl io "$UDID" screenshot "$SCREENSHOT_DIR/$output" >/dev/null 2>&1 || echo "Warning: failed to capture $output"\n',
 '  xcrun simctl io "$UDID" screenshot "$SCREENSHOT_DIR/$name" >/dev/null\n',
 'xcrun simctl io "$UDID" screenshot "$SCREENSHOT_DIR/orientation-probe-landscape.png" >/dev/null\n']
for anchor,call in zip(anchors,proof["removedCalls"]):
 assert restored.count(anchor)==1;restored=restored.replace(anchor,anchor+call,1)
assert restored==baseline
red=raw_json("raw/repair/baseline-attempt1/RESULT.json.gz")
green=raw_json("raw/repair/candidate-attempt1/RESULT.json.gz")
assert (red["executed"],red["passed"],red["failed"],red["errors"],red["skipped"])==(23,17,6,0,0)
assert (green["executed"],green["passed"],green["failed"],green["errors"],green["skipped"])==(23,23,0,0,0)
assert [x["case"] for x in red["cases"]]==[x["case"] for x in green["cases"]]
assert len(set(x["case"] for x in green["cases"]))==23
assert red["testDriverSHA256"]==green["testDriverSHA256"]==sha(read("Scripts/CI/test-normal-ios-raw-capture.py").replace(b"\r\n",b"\n"))
assert green["sourceSHA256"]==sha(candidate.encode())
run=raw_json("raw/completion/RUN.json.gz")
assert (run["id"],run["head_sha"],run["run_attempt"],run["conclusion"])==(44716258538,"e9050ad8998a070c92c73a881b0d7deb6e216e88",1,"failure")
artifacts=raw_json("raw/completion/ARTIFACT_VERIFICATIONS.json.gz")
for item in artifacts:
 assert item["fullArchiveHashVerified"] and item["allEntryCRCVerified"]
 assert item["archiveSHA256"]==item["artifact"]["digest"].split(":",1)[1]
 assert item["artifact"]["workflow_run"]["id"]==run["id"]
 assert item["artifact"]["workflow_run"]["head_sha"]==run["head_sha"]
entries=json.loads(local("ARCHIVE_ENTRY_TRANSFER.json"))
for item in entries:
 b=local(item["sealedPath"])
 if item["gzip"]:b=gzip.decompress(b)
 assert len(b)==item["originalBytes"] and sha(b)==item["originalSHA256"]
png=local("raw/artifacts/14625246106/orientation-probe-landscape.png")
assert sha(png)=="f943a3895a70b33818fd5fc4bff627a79dcd0f6af73deea98d56698e15ee55cc"
assert struct.unpack(">II",png[16:24])==(2064,2752)
for aid in ("14623734717","14624375558"):
 app=raw_json("raw/artifacts/"+aid+"/normal-ios-embedded/verify-app.json.gz")
 assert app["status"]=="BUILT_APP_ORIGINAL_INPUTS_VERIFIED" and app["app_build_executed"] is True
 assert app["checkout_sha"]==run["head_sha"] and app["actual_source_inputs_verified"]==996
print(json.dumps({"status":"PASS_SEALED_SOURCE_AND_RECORDED_EVIDENCE_ONLY","sealedFiles":len(manifest["files"]),"archiveEntries":len(entries),"baselineExecuted":23,"baselinePassed":17,"candidateExecuted":23,"candidatePassed":23,"nativeRepairExecuted":0,"appleRepairExecuted":0,"gitRef":A.git_ref}))

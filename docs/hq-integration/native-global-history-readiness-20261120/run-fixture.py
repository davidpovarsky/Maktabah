#!/usr/bin/env python3
"""Execute the unchanged complete XCTest file-observation helpers on owned plists.
Boundary: simulated file layout only; no Simulator, app, CFPreferences or Native claim.
"""
from pathlib import Path
import hashlib,json,subprocess,sys,datetime,shutil
repo=Path(__file__).resolve().parents[3]
source=repo/"Maktabah-iOSUITests/FaithfulReaderUIAcceptanceTests.swift"
evidence=Path(__file__).resolve().parent
out=repo/"build/native-global-history-readiness-20261120/fixture-attempt4"
out.mkdir(parents=True,exist_ok=True)
raw=source.read_bytes()
text=raw.decode("utf-8").replace("\r\n","\n")
markers=[
 ("private func matchingTestSidecars(", "/// Read-only evidence from this Simulator installation."),
 ("/// Read-only evidence from this Simulator installation.", "/// Runs the supplied prototype in its own app, never demo code in Maktabah.")
]
parts=[]
for begin,end in markers:
 assert text.count(begin)==1 and text.count(end)==1,(begin,end)
 start=text.index(begin);stop=text.index(end,start)
 parts.append(text[start:stop])
case_source=(evidence/"fixture/Acceptance.swift").read_bytes().decode("utf-8")
generated="import Foundation\n\n"+"\n".join(parts)+"\n"+case_source
candidate=out/"NativeHistoryObservationAcceptance.swift"
candidate.write_bytes(generated.encode("utf-8"))
swift=shutil.which("swiftc");assert swift
executable=out/"NativeHistoryObservationAcceptance.exe"
records={"source":str(source),"workingSourceSHA256":hashlib.sha256(raw).hexdigest(),
 "gitLFSourceSHA256":hashlib.sha256(text.encode()).hexdigest(),
 "extractedCompleteBlocksSHA256":[hashlib.sha256(p.encode()).hexdigest() for p in parts],
 "generatedSHA256":hashlib.sha256(generated.encode()).hexdigest(),
 "boundary":"Complete source helpers; explicit disposable test-owned XML plists. No app/CFPreferences/Simulator/Apple/Native execution.",
 "diskFreeBefore":shutil.disk_usage(repo).free,"commands":[]}
assert records["diskFreeBefore"]>64*1024*1024
commands=[
 ([swift,"-parse-as-library","-j","1",str(candidate),"-o",str(executable)],"compile",120),
 ([str(executable),str(repo/"build/ghp")],"runtime",30)
]
failed=False
for command,kind,limit in commands:
 start=datetime.datetime.now(datetime.timezone.utc).isoformat()
 try:
  run=subprocess.run(command,cwd=repo,capture_output=True,text=True,encoding="utf-8",timeout=limit)
  output=run.stdout+run.stderr
  code=run.returncode
 except subprocess.TimeoutExpired as error:
  output=str(error);code=-999
 (out/(kind+".log")).write_bytes(output.encode("utf-8"))
 records["commands"].append({"kind":kind,"command":command,"startedUTC":start,
   "finishedUTC":datetime.datetime.now(datetime.timezone.utc).isoformat(),"returncode":code,
   "warningCount":output.count("warning:"),"outputSHA256":hashlib.sha256(output.encode()).hexdigest()})
 if code!=0:failed=True;break
assert source.read_bytes()==raw
records["sourceUnchanged"]=True
if not failed:
 output=(out/"runtime.log").read_text(encoding="utf-8")
 cases=[line.split() for line in output.splitlines() if line.startswith("CASE ")]
 expected=[
 "missing_installation_is_not_persistence","foreign_bundle_preferences_are_not_accepted",
 "unique_installation_must_be_pinned_before_success","exact_pinned_query_and_original_namespace_are_accepted",
 "another_query_does_not_satisfy_uuid_query","duplicate_query_is_not_exact_once",
 "two_original_metadata_candidates_fail_closed","same_path_with_changed_metadata_is_rejected",
 "foreign_namespace_sidecar_cannot_confirm_installation","delayed_test_writer_requires_actual_bytes_without_sidecar",
 "oversized_preferences_fail_closed","observation_leaves_owned_files_byte_identical"]
 inventory=(len(cases)==12 and [c[1] for c in cases]==expected and len(set(c[1] for c in cases))==12)
 records["caseNames"]=[c[1] for c in cases];records["caseResults"]=cases
 records["passed"]=sum(c[2]=="PASS" for c in cases);records["failed"]=sum(c[2]!="PASS" for c in cases)
 records["exactCaseInventory"]=inventory
 records["nativeExecuted"]=0
 failed=not inventory or records["failed"]!=0
records["status"]="FAIL" if failed else "PASS"
(out/"RESULT.json").write_bytes((json.dumps(records,indent=2)+"\n").encode())
print(json.dumps(records))
sys.exit(1 if failed else 0)

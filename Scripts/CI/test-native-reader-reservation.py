#!/usr/bin/env python3
"""Compile the original mapping owner policy; no app/SDK/native UI claim."""
import hashlib,json,os,re,subprocess,tempfile
from pathlib import Path
root=Path(__file__).resolve().parents[2]
original=(root/"Scripts/run-chavrusa-component-tests.sh").read_text(encoding="utf-8")
sources=[v for v in re.findall(r'\$\{REPO_ROOT\}/([^"\r\n]+\.swift)',original) if v!="tools/test_chavrusa_text_components.swift"]
sources += ["Source/ChavrusaText/StudyWorkspace/StudyWorkspaceModels.swift",
            "Source/ChavrusaText/StudyWorkspace/StudyWorkspacePersistence.swift",
            "Source/ChavrusaText/StudyWorkspace/StudyWorkspaceMappingOwnership.swift",
            "Source/ChavrusaText/StudyWorkspace/StudyWorkspaceStore.swift",
            "tools/test_native_reader_reservation.swift"]
artifacts=root/"build/artifacts";artifacts.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix="reader-reservation-") as directory:
    exe=Path(directory)/("reservation.exe" if os.name=="nt" else "reservation")
    commands=[["swiftc","-parse-as-library","-swift-version","6","-strict-concurrency=complete",
               *[str(root/p)for p in sources],"-o",str(exe)],[str(exe)]]
    results=[]
    for i,cmd in enumerate(commands):
        result=subprocess.run(cmd,cwd=root,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding="utf-8",errors="replace")
        log=artifacts/("reader-reservation-"+("compile" if i==0 else "results")+".log")
        log.write_text(result.stdout,encoding="utf-8");print(result.stdout,end="",flush=True)
        results.append({"command":cmd,"exit_code":result.returncode,"log_sha256":hashlib.sha256(log.read_bytes()).hexdigest()})
        if result.returncode:break
    report={"boundary":"Actual Foundation mapping reservation policy; synthetic owner/projection inputs; native UI0",
            "source_sha256":{p:hashlib.sha256((root/p).read_bytes()).hexdigest()for p in sources},
            "commands":results,"status":"PASS" if len(results)==2 and all(x["exit_code"]==0 for x in results) else "FAIL"}
    (artifacts/"reader-reservation-proof.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    raise SystemExit(0 if report["status"]=="PASS" else 1)

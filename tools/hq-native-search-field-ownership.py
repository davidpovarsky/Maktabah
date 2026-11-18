"""Run unchanged ownership race controls on exact original app methods.
Explicit UIKit/presentation/directory boundary doubles; not Native acceptance.
"""
from pathlib import Path
import argparse, subprocess, json, hashlib, re, sys, datetime
p=argparse.ArgumentParser()
p.add_argument("--source-ref")
p.add_argument("--artifacts-dir",type=Path,required=True)
a=p.parse_args()
repo=Path(__file__).resolve().parent.parent
rel="Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSceneSession.swift"
raw=(subprocess.check_output(["git","show",a.source_ref+":"+rel],cwd=repo) if a.source_ref else (repo/rel).read_bytes())
source=raw.decode("utf-8")
start=source.index("    func attachSearchField(")
end=source.index("    private var searchFieldAvailable:",start)
actual=source[start:end]
fixture=(repo/"Tests/HQ/navigation/NativeSearchFieldOwnerFixtures.swift").read_text(encoding="utf-8")
assert fixture.count("// ACTUAL_OWNERSHIP_METHODS")==1
out=a.artifacts_dir.resolve();out.mkdir(parents=True,exist_ok=True)
unit=out/"ExactOwnershipMethods.swift"
unit.write_text(fixture.replace("// ACTUAL_OWNERSHIP_METHODS",actual),encoding="utf-8",newline="\n")
exe=out/("ownership.exe" if sys.platform=="win32" else "ownership")
command=["swiftc","-swift-version","6","-strict-concurrency=complete","-parse-as-library",str(unit),"-o",str(exe)]
compile=subprocess.run(command,cwd=repo,capture_output=True,text=True,encoding="utf-8",timeout=120)
(out/"compile.log").write_text(compile.stdout+compile.stderr,encoding="utf-8")
run=None
if compile.returncode==0:
 run=subprocess.run([str(exe)],capture_output=True,text=True,encoding="utf-8",timeout=30)
 (out/"tests.log").write_text(run.stdout+run.stderr,encoding="utf-8")
passed=re.findall(r"^PASS (.+)$",run.stdout,re.M) if run else []
failed=re.findall(r"^FAIL (.+)$",run.stdout,re.M) if run else []
code=compile.returncode or (run.returncode if run else 1)
if code==0 and (len(passed)!=9 or failed):code=1
result={"observed_at":datetime.datetime.now(datetime.timezone.utc).isoformat(),"source_ref":a.source_ref or "WORKTREE",
 "source_sha256":hashlib.sha256(raw).hexdigest(),"actual_methods_sha256":hashlib.sha256(actual.encode()).hexdigest(),
 "fixture_sha256":hashlib.sha256(fixture.encode()).hexdigest(),"compile_exit":compile.returncode,
 "test_exit":run.returncode if run else None,"warnings":compile.stderr.count("warning:"),
 "passed":passed,"failed":failed,"status":"PASS" if code==0 else "FAIL",
 "boundary":"Exact original app ownership methods, real Swift6/MainActor scheduling, explicit UIKit/presentation/directory revision boundary doubles; not actual UIKit, Core grant or Native acceptance."}
(out/"RESULT.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
print(json.dumps(result));sys.exit(code)

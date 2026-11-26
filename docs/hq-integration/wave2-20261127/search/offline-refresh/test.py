#!/usr/bin/env python3
"""Run the original refresh method against controlled service outcomes.
This is a controller-state regression check, not network or native UI evidence.
"""
from pathlib import Path
import hashlib,json,subprocess,tempfile
root=Path(__file__).resolve().parents[5]
output=Path(__file__).resolve().parent
path="Source/ZayitSearch/ZayitSearchDistribution.swift"
template=(output/"fixture.swift").read_text()
baseline=subprocess.run(["git","-C",str(root),"show","29a731e273f9a757c743c49e182fece0e8047d46:"+path],check=True,capture_output=True,text=True).stdout
candidate=(root/path).read_text()
reports={}
for label,source in [("baseline",baseline),("candidate",candidate)]:
    state=source[source.index("enum ZayitSearchPackageState:"):source.index("enum ZayitSearchDistributionError:")]
    error=source[source.index("enum ZayitSearchDistributionError:"):source.index("extension ZayitSearchDistributionError:")]
    start=source.index("    func refresh(discover: Bool = false) async {")
    method=source[start:source.index("    func install() async {",start)]
    program=template.replace("__ACTUAL_PACKAGE_STATE__",state).replace("__ACTUAL_DISTRIBUTION_ERROR__",error).replace("__ACTUAL_REFRESH_METHOD__",method)
    with tempfile.TemporaryDirectory(prefix="search-refresh-") as raw:
        scratch=Path(raw);swift=scratch/"control.swift";swift.write_text(program)
        build=subprocess.run(["/usr/local/bin/swiftc","-parse-as-library","-module-cache-path",str(scratch/"module-cache"),str(swift),"-o",str(scratch/"control")],capture_output=True,text=True)
        (output/(label+"-compile.log")).write_text(build.stdout+build.stderr)
        report={"source_sha256":hashlib.sha256(source.encode()).hexdigest(),"method_sha256":hashlib.sha256(method.encode()).hexdigest(),"compile_exit":build.returncode}
        if build.returncode==0:
            run=subprocess.run([str(scratch/"control")],capture_output=True,text=True)
            (output/(label+"-run.log")).write_text(run.stdout+run.stderr)
            report.update(run_exit=run.returncode,passes=sum(x.startswith("PASS ") for x in run.stdout.splitlines()),failures=sum(x.startswith("FAIL ") for x in run.stdout.splitlines()))
        reports[label]=report
result={"scope":"Original controller method with service error fixtures only. No public-network or UI acceptance.","checks":reports}
(output/"RESULT.json").write_text(json.dumps(result,indent=2)+"\n")
print(json.dumps(result,indent=2))
assert reports["baseline"].get("passes")==6 and reports["baseline"].get("failures")==2
assert reports["candidate"].get("passes")==8 and reports["candidate"].get("failures")==0

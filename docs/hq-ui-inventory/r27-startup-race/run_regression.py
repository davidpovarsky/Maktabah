"""Compile real non-UI adapter logic/store against explicit actor-port doubles.

The ONLY production source transform is SwiftUI import -> Foundation/Observation;
the complete adapter body is unchanged. No app renderer/provider/UI claims.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
ADAPTER = "Source/ChavrusaText/StudyWorkspace/StudyWorkspaceNavigationAdapter.swift"
SESSION = "Source/ChavrusaText/Navigation/BackendSessionIntegrityRepair.swift"
IDENTITY = "Source/ChavrusaText/Navigation/TargetBackendBookResolver.swift"
MODELS = ["Source/ChavrusaText/StudyWorkspace/" + x + ".swift" for x in
          ["StudyWorkspaceModels", "StudyWorkspacePersistence", "StudyWorkspaceStore"]]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--adapter-ref", help="Read the complete adapter from an immutable Git ref instead of the worktree")
parser.add_argument("--label", default="", help="Prefix evidence file names (for a preserved baseline)")
args = parser.parse_args()
assert not args.label or all(c.isalnum() or c in "-_" for c in args.label)
prefix = args.label + "-" if args.label else ""
source_bytes = (subprocess.check_output(["git", "show", args.adapter_ref + ":" + ADAPTER], cwd=ROOT)
                if args.adapter_ref else (ROOT / ADAPTER).read_bytes())
source = source_bytes.decode("utf-8").replace("\r\n", "\n")

with tempfile.TemporaryDirectory(prefix="r27-startup-controlflow-") as directory:
    work = Path(directory)
    assert source.count("import SwiftUI") == 1
    (work / "Adapter.swift").write_text(source.replace("import SwiftUI", "import Foundation\nimport Observation", 1), encoding="utf-8")
    session = (ROOT / SESSION).read_text(encoding="utf-8")
    session = session[session.index("struct iOSReaderTabSession:"):session.index("// MARK: - Backend Session Integrity Repair")]
    (work / "Session.swift").write_text("import Foundation\n" + session, encoding="utf-8")
    identity = (ROOT / IDENTITY).read_text(encoding="utf-8")
    identity = identity[:identity.index("/// Validates whether a Sefaria workKey")]
    (work / "Identity.swift").write_text(identity, encoding="utf-8")
    executable = work / ("regression.exe" if os.name == "nt" else "regression")
    command = ["swiftc", "-swift-version", "6", "-strict-concurrency=complete", "-parse-as-library",
               str(work / "Adapter.swift"), str(work / "Session.swift"), str(work / "Identity.swift"),
               *[str(ROOT / p) for p in MODELS], str(HERE / "FixturePorts.swift"), str(HERE / "Regression.swift"), "-o", str(executable)]
    built = subprocess.run(command, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (HERE / (prefix + "compile.log")).write_text(built.stdout.rstrip() + "\n", encoding="utf-8")
    if built.returncode:
        print(built.stdout)
        raise SystemExit(built.returncode)
    result = subprocess.run([str(executable)], cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (HERE / (prefix + "results.log")).write_text(result.stdout, encoding="utf-8")
    report = {"source_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT).decode().strip(),
              "adapter_ref": args.adapter_ref or "worktree",
              "adapter_sha256": hashlib.sha256(source_bytes).hexdigest(),
              "adapter_lf_sha256": hashlib.sha256(source.encode("utf-8")).hexdigest(),
              "executed": "real adapter control flow + real models/store/JSON persistence; controlled actor-port doubles",
              "native_UI_tests_executed": 0, "exit_code": result.returncode}
    (HERE / (prefix + "report.json")).write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(result.stdout)
    print(json.dumps(report))
    raise SystemExit(result.returncode)

#!/usr/bin/env python3
"""Exercise the exact retained original Inspector owner; explicit app DTO doubles."""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import os
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SOURCE = "Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSceneBindings.swift"
FIXTURE = "Tests/HQ/navigation/NativeInspectorOwnerFixtures.swift"
parser = argparse.ArgumentParser()
parser.add_argument("--artifacts-dir", type=Path, required=True)
args = parser.parse_args()
output = args.artifacts_dir.resolve()
output.mkdir(parents=True, exist_ok=True)
if any(output.iterdir()):
    raise SystemExit("Retain prior evidence; use an empty artifacts directory")
raw = (ROOT / SOURCE).read_bytes()
text = raw.decode("utf-8")
start = "// BEGIN NATIVE INSPECTOR OWNER BINDING"
end = "// END NATIVE INSPECTOR OWNER BINDING"
assert text.count(start) == text.count(end) == 1
actual = text[text.index(start):text.index(end) + len(end)]
fixture = (ROOT / FIXTURE).read_text(encoding="utf-8")
assert fixture.count("// ACTUAL_INSPECTOR_BINDING") == 1
unit = output / "ExactInspectorOwner.swift"
unit.write_bytes(fixture.replace("// ACTUAL_INSPECTOR_BINDING", actual).encode("utf-8"))
executable = output / ("inspector-owner.exe" if os.name == "nt" else "inspector-owner")
command = [shutil.which("swiftc"), "-swift-version", "6", "-strict-concurrency=complete",
           "-parse-as-library", str(unit), "-o", str(executable)]
build = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", timeout=120)
(output / "compile.log").write_bytes((build.stdout + build.stderr).encode("utf-8"))
run = None
if build.returncode == 0:
    run = subprocess.run([str(executable)], capture_output=True, text=True, encoding="utf-8", timeout=30)
    (output / "tests.log").write_bytes((run.stdout + run.stderr).encode("utf-8"))
passed = re.findall(r"^PASS (.+)$", run.stdout, re.M) if run else []
failed = re.findall(r"^FAIL (.+)$", run.stdout, re.M) if run else []
code = build.returncode or (run.returncode if run else 1)
if len(passed) != 17 or failed:
    code = 1
report = {"observed_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
          "source_path": SOURCE, "source_sha256": hashlib.sha256(raw).hexdigest(),
          "actual_binding_sha256": hashlib.sha256(actual.encode()).hexdigest(),
          "fixture_sha256": hashlib.sha256(fixture.encode()).hexdigest(),
          "command": command, "compile_exit": build.returncode, "warnings": build.stderr.count("warning:"),
          "test_exit": run.returncode if run else None, "passed": passed, "failed": failed,
          "status": "PASS" if code == 0 else "FAIL", "native_passes": 0,
          "boundary": "Exact app binding with real Swift6/MainActor, explicit model/backend DTO doubles. No UIKit, Core permission, database or native presentation acceptance."}
(output / "RESULT.json").write_bytes((json.dumps(report, ensure_ascii=False, indent=2) + "\n").encode("utf-8"))
print(json.dumps(report, ensure_ascii=False))
raise SystemExit(code)

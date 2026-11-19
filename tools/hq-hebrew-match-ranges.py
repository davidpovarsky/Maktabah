#!/usr/bin/env python3
"""Check exact Hebrew source ranges using the complete production String extension."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
NAME = "Source/Otzaria/Core/String+OtzariaText.swift"
FIXTURE = "Tests/HQ/reader/HebrewMatchingRangesTests.swift"

def digest(data):
    return hashlib.sha256(data).hexdigest()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--artifacts-dir", type=Path, required=True)
    parser.add_argument("--source-ref")
    args = parser.parse_args()
    output = args.artifacts_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    if any(output.iterdir()):
        raise SystemExit("Retain previous evidence; use a new empty artifacts directory")
    if args.source_ref:
        if not re.fullmatch(r"[a-f0-9]{40}", args.source_ref):
            raise SystemExit("An immutable source SHA is required")
        raw = subprocess.check_output(["git", "show", args.source_ref + ":" + NAME], cwd=ROOT)
    else:
        raw = (ROOT / NAME).read_bytes()
    source = output / "String+OtzariaText.swift"
    source.write_bytes(raw)
    executable = output / ("hebrew-ranges.exe" if os.name == "nt" else "hebrew-ranges")
    command = [shutil.which("swiftc"), "-parse-as-library", "-swift-version", "6",
               "-Xfrontend", "-strict-concurrency=complete", str(source), str(ROOT / FIXTURE), "-o", str(executable)]
    built = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", timeout=180)
    (output / "compile.log").write_bytes((built.stdout + built.stderr).encode("utf-8"))
    report = {"source_path": NAME, "source_ref": args.source_ref, "source_sha256": digest(raw),
              "fixture_sha256": digest((ROOT / FIXTURE).read_bytes()),
              "swift": subprocess.check_output([command[0], "--version"], text=True).strip(),
              "command": command, "compile_exit": built.returncode, "native_passes": 0}
    if built.returncode == 0:
        tested = subprocess.run([str(executable)], capture_output=True, text=True, encoding="utf-8", timeout=30)
        (output / "tests.log").write_bytes((tested.stdout + tested.stderr).encode("utf-8"))
        report.update(test_exit=tested.returncode, actual=json.loads(tested.stdout))
    (output / "RESULT.json").write_bytes((json.dumps(report, ensure_ascii=False, indent=2) + "\n").encode("utf-8"))
    print(json.dumps(report, ensure_ascii=False))
    return report.get("test_exit", 1)

if __name__ == "__main__":
    raise SystemExit(main())

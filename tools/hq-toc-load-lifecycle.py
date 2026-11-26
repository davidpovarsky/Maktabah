#!/usr/bin/env python3
"""Actual TOC owner lifecycle, with controlled transport/database boundaries.

Prepare on the source host, copy the small output directory to the Apple host,
and execute there. Production source is never edited or extracted by this runner.
"""
import argparse
import datetime
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

PRODUCTION = [
    "Source/Features/Reader/ViewModel/BookTOCViewModel.swift",
    "Source/Features/Reader/Models/TOCNode.swift",
]
TESTS = [
    "Tests/HQ/reader/TOCLoadLifecycleSupport.swift",
    "Tests/HQ/reader/TOCLoadLifecycleTests.swift",
]


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--source-ref", default="HEAD")
    parser.add_argument("--execute", type=Path)
    args = parser.parse_args()
    if not args.execute:
        root = (args.root or Path(__file__).resolve().parents[1]).resolve()
        output = args.output.resolve()
        if output.exists():
            raise RuntimeError("Use a distinct evidence directory")
        output.mkdir(parents=True)
        source = subprocess.check_output(["git", "-C", str(root), "rev-parse", args.source_ref + "^{commit}"], text=True).strip()
        files = []
        for relative in PRODUCTION + TESTS:
            # Tests are the current controlled regression; production comes from
            # the requested immutable source for the before/after comparison.
            raw = (subprocess.check_output(["git", "-C", str(root), "show", source + ":" + relative])
                   if relative in PRODUCTION else (root / relative).read_bytes())
            name = Path(relative).name
            (output / name).write_bytes(raw)
            files.append({"path": relative, "snapshot": name, "sha256": sha(raw), "bytes": len(raw)})
        manifest = {
            "source": source, "files": files,
            "boundary": "Actual complete production TOC owner and node; controlled backend transport/database/model boundaries; real Apple SwiftUI, Observation, Foundation and OSLog; zero app UI or full-corpus acceptance.",
        }
        (output / "INPUTS.json").write_text(json.dumps(manifest, indent=2) + "\n")
        shutil.copyfile(__file__, output / "runner.py")
        print(json.dumps(manifest))
        return 0

    output = args.execute.resolve()
    manifest = json.loads((output / "INPUTS.json").read_text())
    for item in manifest["files"]:
        raw = (output / item["snapshot"]).read_bytes()
        if sha(raw) != item["sha256"] or len(raw) != item["bytes"]:
            raise RuntimeError("Input changed: " + item["path"])
    compiler = subprocess.check_output(["xcrun", "--find", "swiftc"], text=True).strip()
    binary = output / "toc-load-lifecycle"
    command = [compiler, "-swift-version", "6", "-strict-concurrency=complete", "-O", "-parse-as-library"]
    command += [str(output / item["snapshot"]) for item in manifest["files"]]
    command += ["-o", str(binary)]
    result = {
        "source": manifest["source"], "boundary": manifest["boundary"],
        "startedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "toolchain": subprocess.check_output([compiler, "--version"], text=True),
        "xcode": subprocess.check_output(["xcodebuild", "-version"], text=True),
        "command": command, "appUIExecuted": 0,
    }
    with (output / "compile.stdout.log").open("wb") as out, (output / "compile.stderr.log").open("wb") as err:
        compiled = subprocess.run(command, stdout=out, stderr=err, timeout=90)
    result["compileExit"] = compiled.returncode
    result["status"] = "COMPILE_FAILED"
    if compiled.returncode == 0:
        result["binarySHA256"] = sha(binary.read_bytes())
        with (output / "run.stdout.log").open("wb") as out, (output / "run.stderr.log").open("wb") as err:
            ran = subprocess.run([str(binary)], stdout=out, stderr=err, timeout=30)
        result["runExit"] = ran.returncode
        rows = json.loads((output / "run.stdout.log").read_text())
        if len({row["name"] for row in rows}) != len(rows):
            raise RuntimeError("Duplicate regression case")
        result["executed"] = len(rows)
        result["passed"] = sum(row["passed"] for row in rows)
        result["failed"] = [row["name"] for row in rows if not row["passed"]]
        if ran.returncode != (1 if result["failed"] else 0):
            raise RuntimeError("Exit disagrees with checks")
        result["status"] = "FAIL" if result["failed"] else "PASS"
    result["inputsUnchanged"] = all(sha((output / item["snapshot"]).read_bytes()) == item["sha256"] for item in manifest["files"])
    result["finishedAt"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    (output / "RESULT.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result))
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())

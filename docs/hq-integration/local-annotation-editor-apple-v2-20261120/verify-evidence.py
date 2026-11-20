#!/usr/bin/env python3
"""Verify retained real failure and corrected source; optionally replay Python only."""
from pathlib import Path, PurePosixPath
import argparse
import hashlib
import io
import json
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import zipfile


def digest(data):
    return hashlib.sha256(data).hexdigest()


def blob(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def safe(path):
    value = PurePosixPath(path)
    if path != value.as_posix() or value.is_absolute() or "\\" in path or any(
            part in ("", ".", "..") for part in path.split("/")):
        raise ValueError("Unsafe evidence member")
    return value


def read_tar(data):
    result = {}
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as archive:
        for item in archive:
            safe(item.name)
            if not item.isfile() or item.name in result or item.size > 10_000_000:
                raise ValueError("Invalid evidence member")
            value = archive.extractfile(item).read()
            if len(value) != item.size:
                raise ValueError("Truncated evidence member")
            result[item.name] = value
    return result


def record(data):
    return {"bytes": len(data), "sha256": digest(data)}


def require(value, message):
    if not value:
        raise ValueError(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--replay-python", action="store_true")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent
    manifest = json.loads((root / "MANIFEST.json").read_bytes())
    for relative, expected in manifest["files"].items():
        safe(relative)
        require(record((root / relative).read_bytes()) == expected, "Sealed file differs: " + relative)
    raw = read_tar((root / "raw-evidence.tar.gz").read_bytes())
    inventory = json.loads((root / "RAW_INVENTORY.json").read_bytes())["files"]
    require(set(raw) == set(inventory), "Raw inventory differs")
    for relative, expected in inventory.items():
        require(record(raw[relative]) == expected, "Raw input differs: " + relative)
    require(not any("DOWNLOAD_INPUT" in path for path in raw), "Signed URL receipt must not be included")
    original_zip = raw["failure/artifact.zip"]
    require(len(original_zip) == 815530 and digest(original_zip) ==
            "55036c390406f18a1c82a49b5537b7d73885aba695fc41ad0a9b235e83423976", "Wrong authentic failure ZIP")
    with zipfile.ZipFile(io.BytesIO(original_zip)) as archive:
        require(len(archive.infolist()) == 81 and archive.testzip() is None, "Original ZIP CRC/count mismatch")
        require(len(set(archive.namelist())) == 81, "Duplicate original ZIP member")
        for name in archive.namelist():
            safe(name)
        local = json.loads(archive.read("local-annotation-editor-acceptance/RESULT.json"))
        exchange = json.loads(archive.read("local-annotation-editor-exchange-regression/RESULT.json"))
        before = json.loads(archive.read("local-annotation-editor-route/before.json"))
        after = json.loads(archive.read("local-annotation-editor-route/after.json"))
        original_source = read_tar(archive.read("local-annotation-editor-route/source-before.tar.gz"))
        require(original_source == read_tar(archive.read("local-annotation-editor-route/source-after.tar.gz")),
                "Actual original source changed during failed run")
        compiler = re.sub(r"\x1b\[[0-9;]*m", "", archive.read("local-annotation-editor-acceptance/compile.log").decode())
    require(local["status"] == "FAILED" and local["cases"] == [] and
            local["commands"][0]["exit_code"] == 1, "Local failure was misclassified")
    diagnostics = [line for line in compiler.splitlines() if re.search(r"\.swift:\d+:\d+: error:", line)]
    require(len(diagnostics) == 5 and all("cannot find type 'AnnotationNode' in scope" in line for line in diagnostics),
            "Original diagnostic classification differs")
    require(exchange["status"] == "PASS_ACTUAL_SQLITE_COMPONENT" and exchange["passed_cases"] == 28 and
            exchange["failed_cases"] == 0 and len(exchange["cases"]) == 28 and
            all(row["status"] == "PASS" for row in exchange["cases"]), "Original exchange result differs")
    termination = exchange["process_termination_checks"]
    require([row["phase"] for row in termination] == ["after", "before"] and all(
        row["status"] == "PASS" and row["terminated_exit"] == 73 and row["verify_exit"] == 0
        for row in termination), "Original exchange termination/reopen result differs")
    require(after["status"] == "FAILED" and after["workflow_step_outcomes"] ==
            {"toolchain": "success", "local": "failure", "exchange": "success"}, "Final gate must remain failed")
    proof = json.loads(raw["failure/SOURCE_GIT_PROOF.json"])
    require(proof["commit"] == "1bde04bfbabbf1b1df714668785b580c9141a3b8" and len(proof["files"]) == 83,
            "Wrong original source Git proof")
    require(set(original_source) == {row["path"] for row in proof["files"]}, "Original source inventory differs")
    for row in proof["files"]:
        require(blob(original_source[row["path"]]) == row["sha"], "Original Git blob differs: " + row["path"])
    publication = json.loads((root / "SOURCE_PUBLICATION.json").read_bytes())
    candidates = {path.removeprefix("candidate/"): data for path, data in raw.items() if path.startswith("candidate/")}
    require(set(candidates) == {row["path"] for row in publication["files"]}, "Candidate source set differs")
    for row in publication["files"]:
        require(blob(candidates[row["path"]]) == row["git_blob"] and digest(candidates[row["path"]]) == row["sha256"],
                "Published candidate differs")
    originals = {path.removeprefix("original-model/"): data for path, data in raw.items() if path.startswith("original-model/")}
    expected_models = {"Source/Features/Annotations/Models/AnnotationNode.swift": "aefdacf6d13ea0c13d6fde3ed0b160421006290a",
                       "Source/Features/Annotations/Models/Annotation.xcstrings": "238e8bb2a3e2a676fb59e2af888a96e8c93553ff"}
    require(set(originals) == set(expected_models) and all(blob(originals[path]) == expected for path, expected in expected_models.items()),
            "Whole original Node/catalog changed")
    python = json.loads(raw["python-controls/RESULT.json"])
    require(python["status"] == "PASS" and python["tests"] == 32 and
            (python["failures"], python["errors"], python["skipped"]) == (0, 0, 0) and
            python["source_before"] == python["source_after"], "Original Python32 receipt differs")
    with tempfile.TemporaryDirectory(prefix="local43-v2-verified-") as directory:
        work = Path(directory)
        source = work / "candidate"
        for relative, data in original_source.items() | originals.items():
            path = source / safe(relative); path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(data)
        for relative, data in candidates.items():
            (source / relative).write_bytes(data)
        for relative, expected in python["source_before"].items():
            data = (source / relative).read_bytes()
            require({**record(data), "git_blob": blob(data)} == expected, "Python tested source differs: " + relative)
        inverse = work / "inverse"
        shutil.copytree(source, inverse)
        patch = work / "source.patch"; patch.write_bytes(raw["evidence/CANDIDATE.patch"])
        result = subprocess.run(["git", "apply", "--reverse", str(patch)], cwd=inverse, capture_output=True, timeout=30)
        require(result.returncode == 0, "Candidate whole inverse rejected")
        for relative, data in original_source.items() | originals.items():
            require((inverse / relative).read_bytes() == data, "Inverse changed original source: " + relative)
        if args.replay_python:
            result = subprocess.run([sys.executable, str(source / "Scripts/CI/test-local-annotation-editor-apple.py"),
                                     "--artifacts-dir", str(work / "python-replay")], capture_output=True, text=True, timeout=120)
            require(result.returncode == 0, "Python replay failed: " + result.stdout + result.stderr)
            replay = json.loads((work / "python-replay/RESULT.json").read_bytes())
            require(replay["status"] == "PASS" and replay["tests"] == 32 and
                    replay["source_before"] == python["source_before"] == replay["source_after"], "Python replay source/result differs")
    print(json.dumps({"status": "VERIFIED", "authentic_run": 44774181751, "local43": "NOT_RUN_COMPILE_FAILURE",
                      "original_exchange_cases": 28, "original_exchange_reopen_gates": 2,
                      "source_inverse": "EXACT", "python_replayed": 32 if args.replay_python else 0,
                      "candidate_swift_executed": 0, "candidate_apple_executed": 0}, sort_keys=True))


if __name__ == "__main__":
    main()

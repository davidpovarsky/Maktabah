#!/usr/bin/env python3
"""Darwin Foundation ownership checks with an explicit native constructor double.

The complete original Repository/Bridge/Models/OccurrenceOperation are compiled.
Only the complete StorageLock enum and the two generation-observation methods
are extracted from app files; all extraction hashes and whole inputs are retained.
No real C/Rust engine, index corpus, SQLite database, app UI or Native credit.
"""
from __future__ import annotations

import argparse
import datetime as dt
import gzip
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import signal
import subprocess
import sys
import time
import zipfile

ROOT_INPUTS = "Tests/HQ/cold-search-ownership/OWNERSHIP_INPUTS.json"
FIXTURES = "Tests/HQ/cold-search-ownership"
SEARCH = "Source/Otzaria/Search/"
WHOLE = [SEARCH + name + ".swift" for name in (
    "OtzariaTantivySearchRepository", "OtzariaSearchEngineBridge", "OtzariaSearchModels",
    "OtzariaSearchMode", "OtzariaSearchSnippetRenderer", "OtzariaExactOccurrenceModels",
    "OtzariaExactOccurrenceOperation")]
STORAGE = "Source/Otzaria/Storage/ITorahSharedContainer.swift"
APP = "Source/Otzaria/App/OtzariaAppContainer.swift"
RED_CASE = "constructor_generation_switch_stops_further_native_work"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def extract_block(source, marker):
    if source.count(marker) != 1:
        raise ValueError("Ambiguous extraction marker: " + marker)
    start = source.index(marker)
    opening = source.index("{", start)
    depth = 0
    quote = False
    escaped = False
    comment = False
    index = opening
    while index < len(source):
        character = source[index]
        if comment:
            if character == "\n":
                comment = False
        elif quote:
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == '"':
                quote = False
        elif source[index:index + 2] == "//":
            comment = True
            index += 1
        elif character == '"':
            quote = True
        elif character == "{":
            depth += 1
        elif character == "}":
            depth -= 1
            if depth == 0:
                return source[start:index + 1]
        index += 1
    raise ValueError("Unclosed extraction block")


def verify(root, manifest):
    if manifest.get("schema_version") != 1 or manifest.get("native_engine_boundary") != "EXPLICIT_CONSTRUCTOR_DOUBLE":
        raise ValueError("Unexpected ownership contract")
    witnessed = []
    for row in manifest["inputs"]:
        path = root / row["path"]
        if not path.is_file() or path.is_symlink():
            raise ValueError("Missing/indirect input: " + row["path"])
        data = path.read_bytes()
        if sha(data) != row["sha256"] or len(data) != row["bytes"]:
            raise ValueError("Input changed: " + row["path"])
        witnessed.append(row)
    actual_cases = re.findall(r'await checks\.run\("([a-z0-9_]+)"\)', (root / FIXTURES / "OwnershipCases.swift").read_text())
    if len(actual_cases) != 32 or len(set(actual_cases)) != 32 or actual_cases != manifest["cases"]:
        raise ValueError("The exact 32 case declarations changed")
    if manifest["baseline_case"] != RED_CASE or manifest["baseline_failure_code"] != "stale_constructor_performed_more_native_work":
        raise ValueError("Baseline failure contract changed")
    storage = (root / STORAGE).read_text()
    app = (root / APP).read_text()
    chunks = {
        "StorageLock": extract_block(storage, "enum ITorahStorageLock {"),
        "OriginalWithLock": extract_block(storage, "static func withLock<T>"),
        "OriginalGenerationSnapshot": extract_block(app, "func generationSnapshot() -> UInt64"),
        "TryGenerationSnapshot": extract_block(app, "func tryGenerationSnapshot() -> UInt64?"),
    }
    for key, value in chunks.items():
        if sha(value.encode()) != manifest["extractions"][key]["sha256"]:
            raise ValueError("Extracted original source changed: " + key)
    raw = gzip.decompress((root / FIXTURES / "pre-publication-Repository.swift.gz").read_bytes())
    if sha(raw) != manifest["unpublished_pre_guard_repository_sha256"]:
        raise ValueError("Unpublished pre-guard comparison source changed")
    return witnessed, chunks


def process(command, cwd, log, timeout, env=None):
    start = time.monotonic()
    started = dt.datetime.now(dt.timezone.utc).isoformat()
    with log.open("wb") as output:
        child = subprocess.Popen(command, cwd=cwd, stdout=output, stderr=subprocess.STDOUT,
                                 start_new_session=True, env=env)
        timed_out = False
        try:
            code = child.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            try:
                os.killpg(child.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                code = child.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(child.pid, signal.SIGKILL)
                code = child.wait(timeout=10)
    return {"command": command, "started_at": started, "elapsed_seconds": time.monotonic() - start,
            "returncode": code, "timed_out": timed_out, "log_sha256": sha(log.read_bytes())}


def qualify(actual, run, expected):
    if not isinstance(actual, dict) or actual.get("scope") != "FOUNDATION_OWNERSHIP_WITH_EXPLICIT_NATIVE_CONSTRUCTOR_DOUBLE":
        return False
    if actual.get("actualCOrRustEngineExecuted") != 0 or actual.get("nativeUIExecuted") != 0:
        return False
    rows = actual.get("checks", [])
    if (len(rows) != len(expected) or len({row.get("id") for row in rows}) != len(expected)
            or {row.get("id"): row.get("outcome") for row in rows} != expected):
        return False
    failure = "failed" in expected.values()
    if failure and (rows != [{"id": RED_CASE, "outcome": "failed", "code": "stale_constructor_performed_more_native_work"}]):
        return False
    return not run["timed_out"] and run["returncode"] == (1 if failure else 0)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--output", type=Path, default=Path("build/cold-search-ownership"))
    parser.add_argument("--expected-inputs-sha256", required=True)
    parser.add_argument("--generate-only", action="store_true")
    args = parser.parse_args()
    root, output = args.repo.resolve(), args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    result = {"status": "SETUP_NOT_COMPLETED", "scope": "DARWIN_FOUNDATION_WITH_EXPLICIT_NATIVE_CONSTRUCTOR_DOUBLE",
              "actual_c_or_rust_engine_executed": 0, "native_ui_executed": 0, "stages": {}}
    try:
        raw = (root / ROOT_INPUTS).read_bytes()
        if sha(raw) != args.expected_inputs_sha256:
            raise ValueError("Pinned ownership manifest changed")
        manifest = json.loads(raw)
        before, chunks = verify(root, manifest)
        save(output / "source-before.json", before)
        result["input_manifest_sha256"] = sha(raw)
        generated = output / "generated"
        generated.mkdir()
        for path in WHOLE:
            shutil.copyfile(root / path, generated / Path(path).name)
        (generated / "StorageLock.swift").write_text("import Foundation\nimport Darwin\n" + chunks["StorageLock"] + "\n")
        boundary = (root / FIXTURES / "OwnershipBoundary.swift").read_text()
        if boundary.count("// ORIGINAL_GENERATION_METHODS") != 1:
            raise ValueError("Generation fixture marker changed")
        boundary = boundary.replace("// ORIGINAL_GENERATION_METHODS",
            chunks["OriginalGenerationSnapshot"] + "\n    " + chunks["TryGenerationSnapshot"])
        (generated / "OwnershipBoundary.swift").write_text(boundary)
        shutil.copyfile(root / FIXTURES / "OwnershipCases.swift", generated / "OwnershipCases.swift")
        native = (root / FIXTURES / "NativeConstructorDouble.c").read_text()
        declared = set()
        for name in ("OtzariaSearchEngineBridge.swift", "OtzariaExactOccurrenceOperation.swift"):
            declared.update(re.findall(r'@_silgen_name\("([A-Za-z0-9_]+)"\)', (generated / name).read_text()))
        supplied = set(re.findall(r'\b(otzaria_search_engine_\w+)\s*\(', native))
        for name in sorted(declared - supplied):
            native += "\nvoid " + name + "(void) { fputs(\"UNEXPECTED_NATIVE_API:" + name + "\\n\", stderr); abort(); }\n"
        (generated / "NativeConstructorDouble.c").write_text(native)
        generated_rows = [{"path": p.name, "bytes": p.stat().st_size, "sha256": sha(p.read_bytes())}
                          for p in sorted(generated.iterdir())]
        save(output / "GENERATED_INPUTS.json", {"files": generated_rows, "whole_original_files": WHOLE,
            "extractions": manifest["extractions"], "native_declarations": sorted(declared),
            "implemented_double_symbols": sorted(supplied), "abort_only_symbols": sorted(declared - supplied),
            "boundary": "EXPLICIT_APP_METADATA_AND_NATIVE_CONSTRUCTOR_DOUBLES"})
        if args.generate_only:
            result["status"] = "PASS_GENERATION_ONLY_ZERO_SWIFT_EXECUTION"
            return 0
        if sys.platform != "darwin":
            raise ValueError("Real Darwin Foundation/flock required")
        result["github"] = {key: os.environ.get(key) for key in
                            ("GITHUB_REPOSITORY", "GITHUB_REF", "GITHUB_SHA", "GITHUB_RUN_ID", "GITHUB_RUN_ATTEMPT")}
        result["swift_identity"] = process(["xcrun", "swiftc", "--version"], root, output / "swift-version.log", 30)
        if result["swift_identity"]["returncode"] != 0:
            raise ValueError("Swift compiler identity unavailable")
        with zipfile.ZipFile(output / "SOURCE_INPUTS.zip", "x", compression=zipfile.ZIP_DEFLATED) as archive:
            for relative in sorted({row["path"] for row in before} | {ROOT_INPUTS}):
                archive.write(root / relative, relative)
        c_object = output / "NativeConstructorDouble.o"
        native_compile = process(["xcrun", "clang", "-std=c11", "-c", str(generated / "NativeConstructorDouble.c"), "-o", str(c_object)],
                                 root, output / "native-double-compile.log", 60)
        result["native_double_compile"] = native_compile
        if native_compile["returncode"] != 0 or native_compile["timed_out"]:
            raise ValueError("Explicit C boundary did not compile")
        candidate_repository = (generated / "OtzariaTantivySearchRepository.swift").read_bytes()
        old_repository = gzip.decompress((root / FIXTURES / "pre-publication-Repository.swift.gz").read_bytes())
        for name, source, only, expected in (
            ("pre-guard1", old_repository, RED_CASE, {RED_CASE: "failed"}),
            ("candidate32", candidate_repository, None, {case: "passed" for case in manifest["cases"]}),
        ):
            (generated / "OtzariaTantivySearchRepository.swift").write_bytes(source)
            stage_before = {p.name: sha(p.read_bytes()) for p in generated.iterdir() if p.is_file()}
            save(output / (name + ".source-before.json"), stage_before)
            app = output / (name + ".app") / "Contents"
            executable = app / "MacOS/OwnershipAcceptance"
            executable.parent.mkdir(parents=True)
            resources = app / "Resources"; resources.mkdir()
            for dictionary in ("dictionary.json", "Acronyms.json"):
                (resources / dictionary).write_bytes(b"{}\n")
            (app / "Info.plist").write_bytes(plistlib.dumps({"CFBundleIdentifier": "test.otzaria.ownership",
                "CFBundleName": "OwnershipAcceptance", "CFBundleExecutable": "OwnershipAcceptance", "CFBundlePackageType": "APPL"}))
            command = ["xcrun", "swiftc", "-swift-version", "6", "-strict-concurrency=complete", "-parse-as-library",
                       "-D", "OTZARIA_OCCURRENCE_TESTING", "-j", "1", *map(str, sorted(generated.glob("*.swift"))), str(c_object), "-o", str(executable)]
            compiled = process(command, root, output / (name + ".compile.log"), 300)
            stage = {"compile": compiled, "actual_completed": 0, "qualified": False}
            if compiled["returncode"] == 0 and not compiled["timed_out"]:
                report = output / (name + ".CHECKS.json")
                environment = dict(os.environ, COLD_OWNERSHIP_ROOT=str(output / (name + "-owned-files")),
                                   COLD_OWNERSHIP_REPORT=str(report))
                environment.pop("COLD_OWNERSHIP_ONLY", None)
                if only:
                    environment["COLD_OWNERSHIP_ONLY"] = only
                executed = process([str(executable)], root, output / (name + ".run.log"), 90, env=environment)
                checks = json.loads(report.read_bytes()) if report.is_file() else {}
                stage.update(runtime=executed, actual_completed=len(checks.get("checks", [])),
                             qualified=qualify(checks, executed, expected), checks=checks)
            stage_after = {p.name: sha(p.read_bytes()) for p in generated.iterdir() if p.is_file()}
            stage["source_unchanged"] = stage_after == stage_before
            stage["qualified"] &= stage["source_unchanged"]
            save(output / (name + ".source-after.json"), stage_after)
            result["stages"][name] = stage
            save(output / (name + ".result.json"), stage)
            save(output / "RESULT.json", result)
        after, _ = verify(root, manifest)
        save(output / "source-after.json", after)
        if before != after:
            raise ValueError("Original source inputs changed during execution")
        good = all(stage["qualified"] for stage in result["stages"].values())
        result["status"] = "PASS_DARWIN_OWNERSHIP_BOUNDARY_ONLY" if good else "FAIL_ACTUAL_OWNERSHIP_ACCEPTANCE"
        return 0 if good else 1
    except Exception as error:
        result["status"] = "FAIL_SETUP_OR_EXECUTION"
        result["error"] = type(error).__name__ + ": " + str(error)
        return 1
    finally:
        save(output / "RESULT.json", result)
        print(json.dumps({"status": result["status"], "actual_c_or_rust_engine_executed": 0,
                          "native_ui_executed": 0, "stages": {name: {key: stage[key] for key in ("actual_completed", "qualified")}
                                                             for name, stage in result["stages"].items()}}, sort_keys=True))


if __name__ == "__main__":
    raise SystemExit(main())

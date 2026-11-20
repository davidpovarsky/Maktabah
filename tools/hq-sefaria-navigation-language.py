#!/usr/bin/env python3
"""Compile whole original Sefaria navigation sources; never open user data.
The focused suite extracts only the complete test-only cases block. Production
files and TestSupport are always compiled in full. Full regression reuses the
original workflow's exact source list/define and all seven existing fixtures.
"""
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

PRODUCTION = [
    "Source/LibraryBackend/LibraryBackendModels.swift",
    "Source/LibraryBackend/LibraryPresentationPolicy+Display.swift",
    "Source/Sefaria/Domain/SefariaModels.swift",
    "Source/Sefaria/Domain/SefariaNavigationParser.swift",
    "Source/Sefaria/Network/SefariaDTOs.swift",
    "Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift",
    "Source/ChavrusaText/Localization/TalmudHebrewAddressFormatter.swift",
]
SUPPORT = "Vendor/SefariaNativeTests/TestSupport.swift"
TESTS = "Vendor/SefariaNativeTests/NavigationAndPackageTests.swift"
FIXTURES = [
    "index-complex.json", "offline-metadata.json", "packages.json", "search.json",
    "texts-berakhot.json", "texts-commentary.json", "texts-genesis.json",
]
EXPECTED_CASES = ["schema.hebrew.root","schema.english.root","schema.hebrew.nested","schema.english.nested","schema.hebrew.canonical-tree","schema.english.canonical-tree","schema.hebrew.missing-empty-whitespace","schema.english.missing-empty-whitespace","schema.hebrew.primary-over-alias","schema.english.primary-over-alias","schema.hebrew.default-wholeRef-identity","schema.english.default-wholeRef-identity","shape.hebrew.complex-root","shape.english.complex-root","shape.hebrew.missing-empty-whitespace","shape.english.missing-empty-whitespace","shape.hebrew.canonical-roots","shape.english.canonical-roots","shape-child.hebrew.titles-and-fallbacks","shape-child.english.titles-and-fallbacks","shape-child.hebrew.canonical-tree","shape-child.english.canonical-tree","adjacent.talmud.hebrew","adjacent.talmud.english","adjacent.talmud.canonical-both","adjacent.alternate.hebrew","adjacent.alternate.english","adjacent.alternate.canonical-both","adjacent.dictionary.literal-headword-both","adjacent.dictionary.canonical-both","default.follows-original-language-policy"]
BEGIN = "// BEGIN SEFARIA_NAVIGATION_LANGUAGE_CASES"
END = "// END SEFARIA_NAVIGATION_LANGUAGE_CASES"
STAGES = [
    "LocatorAndRefTests", "DecodingTests", "NavigationAndPackageTests",
    "LegacyIdentityRegistryTests", "BackendCoordinatorTests", "UnifiedSearchArchitectureTests",
]

def sha(data):
    return hashlib.sha256(data).hexdigest()

def utc():
    return dt.datetime.now(dt.timezone.utc).isoformat()

def git(root, *args):
    return subprocess.check_output(["git", "-C", str(root), *args])

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--module-cache", type=Path, required=True)
    parser.add_argument("--baseline-ref")
    parser.add_argument("--full-regression", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()
    output = args.output.resolve()
    if output.exists():
        raise RuntimeError("Evidence output already exists; choose a distinct attempt directory")
    if not args.module_cache.is_dir():
        raise RuntimeError("Requested previously existing module cache is absent")
    if args.full_regression and args.baseline_ref:
        raise RuntimeError("Focused RED uses original source; full regression is current candidate only")
    output.mkdir(parents=True)
    inputs = output / "inputs"
    inputs.mkdir()
    command_log = {}
    snapshot = []
    observed = {}
    started = utc()
    clock_start = time.monotonic()
    result = {
        "startedAt": started, "mode": "original-regression" if args.full_regression else "focused-language",
        "baselineRef": args.baseline_ref, "head": git(root, "rev-parse", "HEAD").decode().strip(),
        "productionExtraction": "NONE: each production file is complete",
        "nativeAcceptance": "NOT_RUN", "liveRemoteOrOfflineStore": "NOT_RUN",
        "moduleCache": str(args.module_cache), "freeBytesBefore": shutil.disk_usage(root).free,
    }

    def copy(rel, baseline=False):
        local = root / rel
        raw = git(root, "show", f"{args.baseline_ref}:{rel}") if baseline else local.read_bytes()
        destination = inputs / rel
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(raw)
        snapshot.append({"path": rel, "size": len(raw), "sha256": sha(raw),
                         "canonicalLFSHA256": sha(raw.replace(b"\r\n", b"\n")),
                         "baseGitBlob": git(root, "rev-parse",
                                        f"{args.baseline_ref or 'HEAD'}:{rel}").decode().strip()})
        if not baseline:
            observed[rel] = sha(raw)
        return str(destination)

    try:
        if args.full_regression:
            workflow = git(root, "show", "HEAD:.github/workflows/ios-build.yml").decode()
            label = "      - name: Test Inspector backend mappings\n"
            if workflow.count(label) != 1:
                raise RuntimeError("Original workflow step delimiter is not unique")
            section = workflow.split(label, 1)[1].split("      - name:", 1)[0]
            if section.count("xcrun swiftc -D OTZARIA_INSPECTOR_MAPPING_TESTS") != 1:
                raise RuntimeError("Original compiler contract changed")
            sources = re.findall(r"^\s+((?:Source|Vendor)/\S+\.swift)\s*\\\s*$", section, re.M)
            if len(sources) != 38 or len(set(sources)) != 38:
                raise RuntimeError(f"Expected 38 unique original source inputs; found {len(sources)}")
            (output / "ORIGINAL_WORKFLOW_STEP.txt").write_text(section, encoding="utf-8", newline="\n")
            compile_inputs = [copy(rel) for rel in sources]
            defines = ["-D", "OTZARIA_INSPECTOR_MAPPING_TESTS"]
            result["workflowStepSHA256"] = sha(section.encode())
        else:
            compile_inputs = [copy(rel, baseline=bool(args.baseline_ref)) for rel in PRODUCTION]
            compile_inputs.append(copy(SUPPORT))
            test_data = (root / TESTS).read_bytes()
            test_text = test_data.decode().replace("\r\n", "\n")
            if test_text.count(BEGIN) != 1 or test_text.count(END) != 1:
                raise RuntimeError("Focused test block delimiters must be unique")
            block = test_text.split(BEGIN, 1)[1].split(END, 1)[0]
            block_path = inputs / "SefariaNavigationLanguageCases.swift"
            block_path.write_text("import Foundation\n" + block, encoding="utf-8", newline="\n")
            result["testBlock"] = {
                "wholeOriginalTestFile": TESTS, "wholeRawSHA256": sha(test_data),
                "blockSHA256": sha(block.encode()), "expectedUniqueCases": EXPECTED_CASES,
            }
            observed[TESTS] = sha(test_data)
            main_path = inputs / "SefariaNavigationLanguageMain.swift"
            main_path.write_text(
                'import Foundation\n'
                '@main enum SefariaNavigationLanguageMain {\n'
                '    static func main() throws {\n'
                '        let checks = try sefariaNavigationLanguageChecks()\n'
                '        let rows: [[String: Any]] = checks.map {\n'
                '            ["name": $0.name, "passed": $0.passed, "actual": $0.actual, "expected": $0.expected]\n'
                '        }\n'
                '        let data = try JSONSerialization.data(withJSONObject: rows, options: [.sortedKeys])\n'
                '        FileHandle.standardOutput.write(data)\n'
                '        FileHandle.standardOutput.write(Data("\\n".utf8))\n'
                '        exit(checks.allSatisfy(\\.passed) ? 0 : 1)\n'
                '    }\n'
                '}\n', encoding="utf-8", newline="\n")
            compile_inputs += [str(block_path), str(main_path)]
            defines = ["-swift-version", "6", "-strict-concurrency=complete"]

        for name in FIXTURES:
            copy("Vendor/SefariaMobileReference/Fixtures/" + name)
        swiftc = shutil.which("swiftc")
        if swiftc is None:
            raise RuntimeError("swiftc is unavailable")
        result["toolchain"] = subprocess.check_output([swiftc, "--version"], text=True)
        exe = output / ("sefaria-navigation-language.exe" if os.name == "nt" else "sefaria-navigation-language")
        command = [swiftc, "-j1", "-module-cache-path", str(args.module_cache), *defines, *compile_inputs, "-o", str(exe)]
        command_log["compile"] = command
        command_log["compileTimeoutSeconds"] = 240
        (output / "COMMANDS.json").write_text(json.dumps(command_log, indent=2), encoding="utf-8")
        (output / "INPUTS.json").write_text(json.dumps(snapshot, indent=2), encoding="utf-8")
        compilation_start = time.monotonic()
        with (output / "compile.stdout.log").open("wb") as stdout, (output / "compile.stderr.log").open("wb") as stderr:
            compiled = subprocess.run(command, cwd=inputs, stdout=stdout, stderr=stderr, timeout=240)
        result["compile"] = {"returncode": compiled.returncode, "elapsedSeconds": time.monotonic() - compilation_start}
        if compiled.returncode:
            result["status"] = "COMPILE_FAILED"
            return 2
        result["executable"] = {"size": exe.stat().st_size, "sha256": sha(exe.read_bytes())}
        runtime_start = time.monotonic()
        runtime_limit = 120 if args.full_regression else 30
        command_log["execute"] = [str(exe)]
        command_log["runtimeTimeoutSeconds"] = runtime_limit
        (output / "COMMANDS.json").write_text(json.dumps(command_log, indent=2), encoding="utf-8")
        with (output / "runtime.stdout.log").open("wb") as stdout, (output / "runtime.stderr.log").open("wb") as stderr:
            ran = subprocess.run([str(exe)], cwd=inputs, stdout=stdout, stderr=stderr, timeout=runtime_limit)
        result["runtime"] = {"returncode": ran.returncode, "elapsedSeconds": time.monotonic() - runtime_start}
        if args.full_regression:
            stderr = (output / "runtime.stderr.log").read_text(encoding="utf-8")
            actual_pass = re.findall(r"^STAGE PASS (\w+)$", stderr, re.M)
            result["stages"] = actual_pass
            result["status"] = "PASS" if ran.returncode == 0 and actual_pass == STAGES else "FAIL"
        else:
            rows = json.loads((output / "runtime.stdout.log").read_text(encoding="utf-8"))
            actual_names = [row["name"] for row in rows]
            if actual_names != EXPECTED_CASES or len(set(actual_names)) != len(EXPECTED_CASES):
                raise RuntimeError("Case names/order/uniqueness do not match the sealed inventory")
            if any(type(row["passed"]) is not bool or row["passed"] != (row["actual"] == row["expected"]) for row in rows):
                raise RuntimeError("Malformed or internally inconsistent check result")
            result.update({"executed": len(rows), "passed": sum(row["passed"] for row in rows),
                           "failed": [row["name"] for row in rows if not row["passed"]]})
            expected_rc = 0 if not result["failed"] else 1
            if ran.returncode != expected_rc:
                raise RuntimeError("Executable exit status disagrees with actual check rows")
            result["status"] = "PASS" if not result["failed"] else "FAIL"
            (output / "CASES.json").write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8")
        return 0 if result["status"] == "PASS" else 1
    except Exception as exc:
        result["status"] = "ERROR"
        result["error"] = str(exc)
        raise
    finally:
        result["inputHashesUnchanged"] = all(sha((root / rel).read_bytes()) == digest for rel, digest in observed.items())
        result["snapshotInputHashesUnchanged"] = all(sha((inputs / item["path"]).read_bytes()) == item["sha256"] for item in snapshot)
        result["finishedAt"] = utc()
        result["elapsedSeconds"] = time.monotonic() - clock_start
        result["freeBytesAfter"] = shutil.disk_usage(root).free
        (output / "RESULT.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
        print(json.dumps(result, ensure_ascii=False))
        if not result["inputHashesUnchanged"] or not result["snapshotInputHashesUnchanged"]:
            raise RuntimeError("Source files changed while fixture was executing")

if __name__ == "__main__":
    sys.exit(main())

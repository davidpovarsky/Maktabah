#!/usr/bin/env python3
"""Before/after Apple source control for original Sefaria-Mobile TOC payloads."""
import argparse
import datetime
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

PRODUCTION = [
    "Source/LibraryBackend/LibraryBackendModels.swift",
    "Source/LibraryBackend/LibraryBackendProtocols.swift",
    "Source/LibraryBackend/LibraryPresentationPolicy+Display.swift",
    "Source/Sefaria/Domain/SefariaModels.swift",
    "Source/Sefaria/Domain/SefariaNavigationParser.swift",
    "Source/Sefaria/Network/SefariaDTOs.swift",
    "Source/Sefaria/Offline/SefariaExportModels.swift",
    "Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift",
    "Source/ChavrusaText/Localization/TalmudHebrewAddressFormatter.swift",
    "Source/SefariaEmbedded/Bridge/SefariaRPCModels.swift",
    "Source/SefariaEmbedded/Bridge/SefariaJSRPCBridge.swift",
    "Source/SefariaEmbedded/Adapters/SefariaEmbeddedNavigationAdapter.swift",
]
TEST_ROOT = "Tests/HQ/sefaria-mobile-navigation"
TESTS = [TEST_ROOT + "/Boundary.swift", TEST_ROOT + "/MobileNavigationAcceptance.swift"]
BOUNDARY = ("Whole original adapter, bridge, parser, models and localized-title resolver, "
            "with original retained textToc payloads. Only Hermes/UIKit startup and JavaScript "
            "transport use the existing explicit fixture boundary. Zero app UI acceptance.")

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
        source = subprocess.check_output(
            ["git", "-C", str(root), "rev-parse", args.source_ref + "^{commit}"], text=True).strip()
        files = []
        def copy(relative, snapshot, production=False):
            raw = (subprocess.check_output(["git", "-C", str(root), "show", source + ":" + relative])
                   if production else (root / relative).read_bytes())
            target = output / snapshot
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(raw)
            files.append({"path": relative, "snapshot": snapshot,
                          "sha256": sha(raw), "bytes": len(raw)})
        for relative in PRODUCTION + TESTS:
            copy(relative, Path(relative).name, relative in PRODUCTION)
        copy(TEST_ROOT + "/CASES.json", "CASES.json")
        copy(TEST_ROOT + "/Fixtures/PROVENANCE.json", "Fixtures/PROVENANCE.json")
        provenance = json.loads((output / "Fixtures/PROVENANCE.json").read_text())
        for item in provenance["payloads"]:
            raw = (root / TEST_ROOT / "Fixtures" / item["file"]).read_bytes()
            if sha(raw) != item["sha256"] or len(raw) != item["bytes"]:
                raise RuntimeError("Original fixture differs from its retained provenance")
            copy(TEST_ROOT + "/Fixtures/" + item["file"], "Fixtures/" + item["file"])
        manifest = {"source": source, "files": files, "boundary": BOUNDARY}
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
    binary = output / "sefaria-mobile-labels"
    command = [compiler, "-swift-version", "6", "-strict-concurrency=complete",
               "-D", "MOBILE_LANGUAGE_CASES", "-O", "-parse-as-library"]
    command += [str(output / item["snapshot"]) for item in manifest["files"]
                if item["snapshot"].endswith(".swift")]
    command += ["-o", str(binary)]
    result = {
        "source": manifest["source"], "boundary": manifest["boundary"],
        "startedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "toolchain": subprocess.check_output([compiler, "--version"], text=True),
        "xcode": subprocess.check_output(["xcodebuild", "-version"], text=True),
        "command": command, "appUIExecuted": 0,
    }
    with (output / "compile.stdout.log").open("wb") as out, (output / "compile.stderr.log").open("wb") as err:
        compiled = subprocess.run(command, stdout=out, stderr=err, timeout=120)
    result["compileExit"] = compiled.returncode
    result["status"] = "COMPILE_FAILED"
    if compiled.returncode == 0:
        result["binarySHA256"] = sha(binary.read_bytes())
        with (output / "run.stdout.log").open("wb") as out, (output / "run.stderr.log").open("wb") as err:
            ran = subprocess.run([str(binary)], cwd=output, stdout=out, stderr=err, timeout=45)
        result["runExit"] = ran.returncode
        rows = json.loads((output / "run.stdout.log").read_text())
        inventory = json.loads((output / "CASES.json").read_text())
        expected = inventory["shared"] + inventory["lang"]
        names = [row["name"] for row in rows]
        if names != expected or len(set(names)) != len(expected):
            raise RuntimeError("Exact original plus added case inventory disagrees")
        if any(type(row["passed"]) is not bool or row["passed"] != (row["actual"] == row["expected"])
               for row in rows):
            raise RuntimeError("Malformed or inconsistent result")
        result["executed"] = len(rows)
        result["passed"] = sum(row["passed"] for row in rows)
        result["failed"] = [row["name"] for row in rows if not row["passed"]]
        if ran.returncode != (1 if result["failed"] else 0):
            raise RuntimeError("Exit disagrees with checks")
        result["status"] = "FAIL" if result["failed"] else "PASS"
    result["inputsUnchanged"] = all(
        sha((output / item["snapshot"]).read_bytes()) == item["sha256"] for item in manifest["files"])
    result["finishedAt"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    (output / "RESULT.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result))
    return 0 if result["status"] == "PASS" else 1

if __name__ == "__main__":
    sys.exit(main())

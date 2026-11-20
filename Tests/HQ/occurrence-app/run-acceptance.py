#!/usr/bin/env python3
"""Compile whole app occurrence/owner source with actual original C/Rust and Core."""
from pathlib import Path
import argparse
import datetime
import gzip
import hashlib
import json
import os
import shutil
import subprocess
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
ENGINE = ROOT / "Vendor/OtzariaSearchEngine"
PRODUCTION = [
    "Source/Otzaria/Search/OtzariaSearchMode.swift",
    "Source/Otzaria/Search/OtzariaSearchModels.swift",
    "Source/Otzaria/Search/OtzariaSearchEngineBridge.swift",
    "Source/Otzaria/Search/OtzariaExactOccurrenceModels.swift",
    "Source/Otzaria/Search/OtzariaExactOccurrenceOperation.swift",
    "Source/Otzaria/Search/OtzariaTantivySearchRepository.swift",
    "Source/Otzaria/Search/Distribution/OtzariaSearchArtifactManifest.swift",
    "Source/Otzaria/Search/Distribution/OtzariaSearchArtifactPolicy.swift",
    "Source/Otzaria/Bootstrap/OtzariaDatabaseDownloadModels.swift",
    "Source/Otzaria/DataProfiles/OtzariaDataProfile.swift",
    "Source/Otzaria/DataProfiles/OtzariaDataProfileRegistry.swift",
    "Source/Otzaria/Core/OtzariaDatabaseAccessController.swift",
    "Source/Core/Database/SQLiteDatabase.swift",
    "Source/Otzaria/Actions/Integration/ActionOccurrenceCoveragePolicy.swift",
    "Source/Otzaria/Actions/Integration/ActionLiveOccurrenceCounter.swift",
]
REMOTE_PINS = {
    "swift-crypto": ("https://github.com/apple/swift-crypto.git", "1b6b2e274e85105bfa155183145a1dcfd63331f1"),
    "swift-asn1": ("https://github.com/apple/swift-asn1.git", "917b472dbe53ba699cbb0495f9a95a084bc6364d"),
}

def digest(path):
    value = hashlib.sha256()
    with Path(path).open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()

def output(command, cwd=ROOT, env=None):
    return subprocess.run(command, cwd=cwd, env=env, check=True, capture_output=True,
                          text=True, encoding="utf-8", errors="replace", timeout=45).stdout.strip()

def exact_pins(path):
    value = json.loads(path.read_text(encoding="utf-8"))
    pins = {p["identity"]: (p["location"], p["state"]["revision"]) for p in value["pins"]}
    assert pins == REMOTE_PINS and len(value["pins"]) == len(REMOTE_PINS), "Unexpected official dependency lock"
    return value

def verified_dependencies(scratch):
    result = {}
    for name, (official, revision) in REMOTE_PINS.items():
        checkout = scratch / "checkouts" / name
        assert output(["git", "-C", str(checkout), "rev-parse", "HEAD"]) == revision
        assert output(["git", "-C", str(checkout), "status", "--porcelain"]) == ""
        remote = output(["git", "-C", str(checkout), "remote", "get-url", "origin"])
        source = remote
        if source != official:
            cache = Path(source)
            assert cache.is_dir() and cache.parent.resolve() == (scratch / "repositories").resolve()
            source = output(["git", "-C", str(cache), "remote", "get-url", "origin"])
        assert source == official, "Dependency cache does not derive from the pinned official repository"
        result[name] = {"head": revision, "clean": True, "checkout": str(checkout),
                        "checkoutOrigin": remote, "officialOrigin": source}
    return result

def sqlite_module(package):
    kits = Path(r"C:\Program Files (x86)\Windows Kits\10")
    versions = sorted((kits / "Include").iterdir(), reverse=True)
    for candidate in versions:
        header = candidate / "um/winsqlite/winsqlite3.h"
        library = kits / "Lib" / candidate.name / "um/x64"
        if header.is_file() and (library / "winsqlite3.lib").is_file():
            break
    else:
        raise AssertionError("Installed original Windows SQLite module not found")
    module = package / "SQLite3"
    module.mkdir(exist_ok=True)
    (module / "module.modulemap").write_text(
        'module SQLite3 [system] {\n header "' + header.as_posix() +
        '"\n link "winsqlite3"\n export *\n}\n', encoding="utf-8")
    return header, library

def verify_payload(descriptor):
    root = Path(descriptor["root"])
    assert root.name.startswith("owned-mini-")
    assert (root / "OWNER").read_text(encoding="utf-8") == descriptor["ownerMarker"]
    assert digest(root / "seforim.db") == descriptor["databaseSHA256"]
    receipt = json.loads((root / "INPUT_VERIFIED.json").read_text(encoding="utf-8"))
    for name, proof in receipt["published_files"].items():
        assert digest(root / "index" / name) == proof["sha256"], "Published original payload changed: " + name
    return receipt["published_files"]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-record", type=Path, required=True)
    parser.add_argument("--engine-checkout", type=Path, required=True)
    parser.add_argument("--native-library-dir", type=Path, required=True)
    parser.add_argument("--scratch-path", type=Path, required=True)
    parser.add_argument("--descriptor", type=Path, required=True)
    parser.add_argument("--qualification", choices=["unqualified", "qualified"], required=True)
    parser.add_argument("--expected-cases", type=int, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    assert os.name == "nt", "This driver records Windows, not Apple acceptance"
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    package = ROOT / "build/occurrence-app-20261120/package"
    package.mkdir(parents=True, exist_ok=True)
    sources_dir = package / "Sources"
    sources_dir.mkdir(exist_ok=True)
    record = {
        "startedUTC": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "status": "FAILED", "AppleSDK": "NOT_RUN", "NativeUI": "NOT_RUN",
        "unsafeUserIndexDiagnostics": "NOT_RUN", "qualificationExpected": args.qualification,
    }
    started = time.monotonic()
    try:
        commit = output(["git", "rev-parse", "HEAD"])
        manifest = json.loads((ENGINE / "Upstream/UPSTREAM_MANIFEST.json").read_text(encoding="utf-8"))
        build = json.loads(args.build_record.read_text(encoding="utf-8"))
        library = Path(build["artifact"])
        assert build["exit"] == 0 and build["engineSource"] == manifest["commit"]
        assert digest(library) == build["artifactSHA256"]
        checkout = args.engine_checkout.resolve()
        assert output(["git", "-C", str(checkout), "rev-parse", "HEAD"]) == manifest["commit"]
        assert output(["git", "-C", str(checkout), "status", "--porcelain"]) == ""
        descriptor = json.loads(args.descriptor.read_text(encoding="utf-8"))
        record["inputPayload"] = verify_payload(descriptor)
        native = build["nativeLibraries"][0].split("native-static-libs:", 1)[1].strip().split()
        env = os.environ.copy()
        env.update({
            "OTZARIA_OCCURRENCE_STATIC_LIBRARY": str(library),
            "OTZARIA_OCCURRENCE_NATIVE_LIB_DIR": str(args.native_library_dir.resolve()),
            "OTZARIA_OCCURRENCE_NATIVE_LIBS": json.dumps(native),
            "OTZARIA_OCCURRENCE_ACTION_CORE_ROOT": str(ROOT / "Source/Otzaria/Actions"),
            "OTZARIA_DATA_PROFILE": "miniTest10",
        })
        (package / "Package.swift").write_bytes((HERE / "Package.swift").read_bytes())
        header, sqlite_library = sqlite_module(package)
        env["OTZARIA_OCCURRENCE_SQLITE_LIB_DIR"] = str(sqlite_library)
        seed_lock = HERE / "Package.resolved"
        if not seed_lock.exists():
            seed_lock = ROOT / "Vendor/OtzariaSearchEngine/Tests/OccurrenceSwift/Package.resolved"
        exact_pins(seed_lock)
        resolved = package / "Package.resolved"
        if not resolved.exists():
            resolved.write_bytes(seed_lock.read_bytes())
        exact_pins(resolved)
        source_files = [ROOT / p for p in PRODUCTION]
        source_files += sorted(HERE.glob("OccurrenceApp*.swift"))
        source_files += [ROOT / "Tests/HQ/sqlite/UnusedZstdBoundary.swift"]
        snapshot = out / "source-snapshot"
        snapshot.mkdir()
        inventory = {}
        appendix = (HERE / "OwnerTestAccess.swift").read_bytes()
        for source in source_files:
            data = source.read_bytes()
            staged = sources_dir / source.name
            staged_data = data + appendix if source.name == "OtzariaDatabaseAccessController.swift" else data
            staged.write_bytes(staged_data)
            assert staged.read_bytes() == staged_data
            assert staged_data[:len(data)] == data
            relative = source.relative_to(ROOT).as_posix()
            inventory[relative] = {
                "sha256Raw": hashlib.sha256(data).hexdigest(),
                "sha256LF": hashlib.sha256(data.replace(b"\r\n", b"\n")).hexdigest(),
                "stagedSHA256": hashlib.sha256(staged_data).hexdigest(),
                "testOnlyAppendix": source.name == "OtzariaDatabaseAccessController.swift",
            }
            (snapshot / (source.name + ".gz")).write_bytes(gzip.compress(data, mtime=0))
        assert {p.name for p in sources_dir.glob("*.swift")} == {p.name for p in source_files}
        core = ROOT / "Source/Otzaria/Actions"
        core_inventory = {}
        for source in sorted((core / "Sources").rglob("*")):
            if source.is_file():
                core_inventory[source.relative_to(core).as_posix()] = digest(source)
        core_inventory["Package.swift"] = digest(core / "Package.swift")
        fixture_inventory = {}
        for source in [HERE / "OwnerTestAccess.swift", HERE / "Package.swift", HERE / "CASES.json", HERE / "run-acceptance.py", HERE / "prepare-input.py"]:
            fixture_inventory[source.relative_to(ROOT).as_posix()] = digest(source)
            (snapshot / (source.name + ".gz")).write_bytes(gzip.compress(source.read_bytes(), mtime=0))
        record["fixtureInventory"] = fixture_inventory
        record.update({
            "sourceCommit": commit, "sourceInventory": inventory, "originalCoreInventory": core_inventory,
            "wholeOriginalProductionPrefixByteIdentical": True,
            "ownerAppendixSHA256": hashlib.sha256(appendix).hexdigest(),
            "staticLibrarySHA256": build["artifactSHA256"], "engineCommit": manifest["commit"],
            "engineCheckout": str(checkout), "sqliteHeader": str(header),
            "sqliteHeaderSHA256": digest(header), "officialDependencies": REMOTE_PINS,
        })
        swift = shutil.which("swift")
        common = ["--package-path", str(package), "--scratch-path", str(args.scratch_path.resolve())]
        # Exact remote revisions are already immutable and cached. Resolution
        # may update the root manifest hash for the new local Core dependency;
        # remote pins must remain byte-for-byte identical identities afterward.
        resolve = [swift, "package", *common, "--skip-update", "resolve"]
        record["resolveCommand"] = resolve
        with (out / "resolve.log").open("w", encoding="utf-8", newline="\n") as log:
            result = subprocess.run(resolve, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=180)
        record["resolveExit"] = result.returncode
        assert result.returncode == 0, "Pinned dependency resolution failed"
        exact_pins(resolved)
        record["dependencyCheckoutsBefore"] = verified_dependencies(args.scratch_path.resolve())
        command = [swift, "build", *common, "--disable-automatic-resolution",
                   "--product", "OtzariaOccurrenceAppAcceptance", "--jobs", "1"]
        record["compileCommand"] = command
        with (out / "compile.log").open("w", encoding="utf-8", newline="\n") as log:
            result = subprocess.run(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=1200)
        record["compileExit"] = result.returncode
        assert result.returncode == 0, "Whole original source compile/link failed"
        bin_path = Path(output([swift, "build", *common, "--disable-automatic-resolution", "--show-bin-path"], env=env).splitlines()[-1])
        resources = [
            ENGINE / "Resources/dictionary.json", ENGINE / "Resources/Acronyms.json",
            ROOT / "Source/Otzaria/DataProfiles/miniTest10.profile.json",
        ]
        record["resources"] = {}
        for source in resources:
            target = bin_path / source.name
            target.write_bytes(source.read_bytes())
            assert digest(target) == digest(source)
            record["resources"][source.name] = {"source": str(source), "sha256": digest(source), "bytes": source.stat().st_size}
        executable = bin_path / "OtzariaOccurrenceAppAcceptance.exe"
        record["executableSHA256"] = digest(executable)
        runtime = [str(executable), str(args.descriptor.resolve()), str(out / "runtime-result.json"),
                   args.qualification, commit]
        record["runtimeCommand"] = runtime
        with (out / "runtime.log").open("w", encoding="utf-8", newline="\n") as log:
            result = subprocess.run(runtime, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=180)
        record["runtimeExit"] = result.returncode
        if (out / "runtime-result.json").exists():
            record["runtime"] = json.loads((out / "runtime-result.json").read_text(encoding="utf-8"))
        assert result.returncode == 0, "Actual runtime assertions failed"
        assert record["runtime"]["failed"] == 0 and record["runtime"]["passed"] == args.expected_cases
        assert len(record["runtime"]["cases"]) == args.expected_cases
        expected_names = json.loads((HERE / "CASES.json").read_text(encoding="utf-8"))[args.qualification]
        actual_names = [case["name"] for case in record["runtime"]["cases"]]
        assert len(set(expected_names)) == len(expected_names) == args.expected_cases
        assert len(set(actual_names)) == len(actual_names) and actual_names == expected_names, "Exact case inventory differs"
        record["exactUniqueCaseInventoryVerified"] = True
        record["caseManifestSHA256"] = digest(HERE / "CASES.json")
        verify_payload(descriptor)
        assert digest(library) == build["artifactSHA256"]
        assert output(["git", "-C", str(checkout), "status", "--porcelain"]) == ""
        for relative, proof in inventory.items():
            assert digest(ROOT / relative) == proof["sha256Raw"], "Source changed during execution: " + relative
        for relative, proof in core_inventory.items():
            assert digest(core / relative) == proof, "Original Core changed during execution: " + relative
        for relative, proof in fixture_inventory.items():
            assert digest(ROOT / relative) == proof, "Fixture changed during execution: " + relative
        record["dependencyCheckoutsAfter"] = verified_dependencies(args.scratch_path.resolve())
        exact_pins(resolved)
        record["publishedPayloadHashesBeforeAfterEqual"] = True
        record["status"] = "PASS"
    except Exception as error:
        record["error"] = repr(error)
    finally:
        record["seconds"] = round(time.monotonic() - started, 3)
        record["finishedUTC"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        (out / "verification.json").write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        if (package / "Package.resolved").exists():
            shutil.copyfile(package / "Package.resolved", out / "Package.resolved")
        print(json.dumps(record, ensure_ascii=False))
    return 0 if record["status"] == "PASS" else 1

if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Compile byte-identical whole production Swift files against the real C engine."""
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
ENGINE = HERE.parents[1]
ROOT = ENGINE.parents[1]
PRODUCTION = [
    "Source/Otzaria/Search/OtzariaSearchMode.swift",
    "Source/Otzaria/Search/OtzariaSearchModels.swift",
    "Source/Otzaria/Search/OtzariaSearchEngineBridge.swift",
    "Source/Otzaria/Search/OtzariaExactOccurrenceModels.swift",
    "Source/Otzaria/Search/OtzariaExactOccurrenceOperation.swift",
]


def digest(path):
    value = hashlib.sha256()
    with Path(path).open("rb") as source:
        for data in iter(lambda: source.read(1024 * 1024), b""):
            value.update(data)
    return value.hexdigest()


def command_output(command, cwd=ROOT, env=None):
    return subprocess.run(command, cwd=cwd, env=env, check=True,
                          capture_output=True, text=True, encoding="utf-8",
                          errors="replace", timeout=30).stdout.strip()


def git(*arguments):
    return command_output(["git", "-C", str(ENGINE / "Checkout/otzaria_search_engine"), *arguments])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-record", type=Path, required=True)
    parser.add_argument("--native-library-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--expected-cases", type=int, required=True)
    args = parser.parse_args()
    if os.name != "nt":
        parser.error("This executable link driver records Windows/MSVC, not Apple acceptance")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    package = ROOT / "build/occurrence-bridge-20261120/swift/package"
    package.mkdir(parents=True, exist_ok=True)
    staged = package / "Sources"
    staged.mkdir(exist_ok=True)
    record = {
        "startedUTC": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "status": "FAILED", "AppleSDK": "NOT_RUN", "NativeUI": "NOT_RUN",
        "appCapability": "NOT_CONNECTED", "unsafeOriginalDiagnostics": "NOT_RUN",
    }
    started = time.monotonic()
    try:
        manifest = json.loads((ENGINE / "Upstream/UPSTREAM_MANIFEST.json").read_text(encoding="utf-8"))
        build = json.loads(args.build_record.read_text(encoding="utf-8"))
        library = Path(build["artifact"])
        assert build["exit"] == 0 and build["engineSource"] == manifest["commit"]
        assert digest(library) == build["artifactSHA256"]
        assert git("rev-parse", "HEAD") == manifest["commit"] and git("status", "--porcelain") == ""
        native = build["nativeLibraries"][0].split("native-static-libs:", 1)[1].strip().split()
        env = os.environ.copy()
        env["OTZARIA_OCCURRENCE_STATIC_LIBRARY"] = str(library)
        env["OTZARIA_OCCURRENCE_NATIVE_LIB_DIR"] = str(args.native_library_dir.resolve())
        env["OTZARIA_OCCURRENCE_NATIVE_LIBS"] = json.dumps(native)
        (package / "Package.swift").write_bytes((HERE / "Package.swift").read_bytes())
        resolved = package / "Package.resolved"
        pinned = (HERE / "Package.resolved").read_bytes()
        pinned_value = json.loads(pinned)
        expected_pins = {
            "swift-crypto": (
                "https://github.com/apple/swift-crypto.git",
                "1b6b2e274e85105bfa155183145a1dcfd63331f1",
            ),
            "swift-asn1": (
                "https://github.com/apple/swift-asn1.git",
                "917b472dbe53ba699cbb0495f9a95a084bc6364d",
            ),
        }
        actual_pins = {
            pin["identity"]: (pin["location"], pin["state"]["revision"])
            for pin in pinned_value["pins"]
        }
        assert len(pinned_value["pins"]) == len(expected_pins)
        assert actual_pins == expected_pins, "Unexpected official dependency lock"
        if not resolved.exists():
            resolved.write_bytes(pinned)
        assert json.loads(resolved.read_bytes()) == pinned_value, "Existing package lock differs; review it explicitly"
        initial_pins = pinned_value["pins"]
        record["committedPackageResolvedSHA256"] = hashlib.sha256(pinned).hexdigest()
        probe = staged / "dependency-probe.swift"
        if probe.exists():
            assert probe.read_text(encoding="utf-8") == 'import Crypto\nprint(SHA256.hash(data: [UInt8]()))\n'
            probe.unlink()
        sources = [ROOT / path for path in PRODUCTION] + sorted(HERE.glob("Occurrence*.swift"))
        inventory = {}
        snapshot = output / "source-snapshot"
        snapshot.mkdir(exist_ok=True)
        for source in sources:
            data = source.read_bytes()
            target = staged / source.name
            target.write_bytes(data)
            assert target.read_bytes() == data
            relative = str(source.relative_to(ROOT)).replace("\\", "/")
            inventory[relative] = {
                "sha256Raw": hashlib.sha256(data).hexdigest(),
                "sha256LF": hashlib.sha256(data.replace(b"\r\n", b"\n")).hexdigest(),
            }
            (snapshot / (source.name + ".gz")).write_bytes(gzip.compress(data, mtime=0))
        assert set(p.name for p in staged.glob("*.swift")) == set(p.name for p in sources)
        record.update({
            "sourceInventory": inventory, "wholeProductionFilesByteIdentical": True,
            "engineCommit": manifest["commit"], "staticLibrarySHA256": build["artifactSHA256"],
            "officialDependencyPins": initial_pins,
        })
        command = [
            shutil.which("swift"), "build", "--package-path", str(package),
            "--disable-automatic-resolution", "--product", "OtzariaOccurrenceSwiftAcceptance",
            "--jobs", "2",
        ]
        record["compileCommand"] = command
        with (output / "compile.log").open("w", encoding="utf-8", newline="\n") as log:
            compiled = subprocess.run(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=900)
        record["compileExit"] = compiled.returncode
        assert compiled.returncode == 0, "Whole-Bridge compile/link failed; see compile.log"
        bin_path = command_output([
            shutil.which("swift"), "build", "--package-path", str(package),
            "--disable-automatic-resolution", "--show-bin-path",
        ], env=env).splitlines()[-1]
        executable = Path(bin_path) / "OtzariaOccurrenceSwiftAcceptance.exe"
        record["executableSHA256"] = digest(executable)
        runtime_command = [
            str(executable), str(ENGINE / "Upstream/UPSTREAM_MANIFEST.json"),
            str(output / "runtime-result.json"),
        ]
        record["runtimeCommand"] = runtime_command
        with (output / "runtime.log").open("w", encoding="utf-8", newline="\n") as log:
            ran = subprocess.run(runtime_command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=180)
        record["runtimeExit"] = ran.returncode
        result_path = output / "runtime-result.json"
        if result_path.exists():
            record["runtime"] = json.loads(result_path.read_text(encoding="utf-8"))
        assert ran.returncode == 0, "Actual runtime failed; see runtime.log/result"
        assert record["runtime"]["failed"] == 0
        assert record["runtime"]["passed"] == args.expected_cases
        assert len(record["runtime"]["cases"]) == args.expected_cases
        assert json.loads(resolved.read_text(encoding="utf-8"))["pins"] == initial_pins
        assert digest(library) == build["artifactSHA256"]
        assert git("status", "--porcelain") == ""
        for relative, hashes in inventory.items():
            assert digest(ROOT / relative) == hashes["sha256Raw"], "Source changed while running: " + relative
        record["engineCheckoutPristineAfter"] = True
        record["status"] = "PASS"
    except Exception as error:
        record["error"] = repr(error)
    finally:
        record["seconds"] = round(time.monotonic() - started, 3)
        (output / "verification.json").write_text(
            json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8",
        )
        if (package / "Package.resolved").exists():
            shutil.copyfile(package / "Package.resolved", output / "Package.resolved")
        print(json.dumps(record, ensure_ascii=False))
    return 0 if record["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())

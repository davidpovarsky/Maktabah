#!/usr/bin/env python3
"""Compile the independent transport witness only; never run it or change PF."""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import time


def digest(path):
    raw = path.read_bytes()
    return {"path": str(path), "bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True)
    parser.add_argument("--module-cache", required=True)
    parser.add_argument("--source", default=str(Path(__file__).with_name("OfflineTransportProbe.swift")))
    args = parser.parse_args()
    if sys.platform != "darwin":
        raise ValueError("Actual Apple SDK compilation requires the coordinated Mac")
    source, output, cache = Path(args.source), Path(args.output), Path(args.module_cache)
    if not source.is_absolute() or source.resolve() != source or not source.is_file():
        raise ValueError("Require the actual canonical source file")
    if not output.is_absolute() or output.exists() or output.parent.resolve() != output.parent:
        raise ValueError("Use a fresh output directory")
    if not cache.is_absolute() or cache.resolve() != cache or not cache.is_dir():
        raise ValueError("Reuse an existing coordinated module cache")
    output.mkdir(mode=0o700)
    copied = output / "OfflineTransportProbe.swift"
    copied.write_bytes(source.read_bytes())
    report = {"schema": "otzaria.independent-foundation-probe-build/1",
              "scope": "compile only; no transport requests, Simulator, PF or launchd operation",
              "source": digest(copied), "sourceBeforeCopy": digest(source),
              "compilerDriverSource": digest(Path(__file__).resolve()), "builds": [],
              "startedAt": datetime.datetime.now(datetime.timezone.utc).isoformat()}
    for kind, sdk, target, platform in (("host", "macosx", "arm64-apple-macosx27.0", "MACOS"),
                                         ("simulator", "iphonesimulator", "arm64-apple-ios27.0-simulator", "IOSSIMULATOR")):
        sdk_path = subprocess.check_output(["xcrun", "--sdk", sdk, "--show-sdk-path"], text=True, timeout=5).strip()
        sdk_version = subprocess.check_output(["xcrun", "--sdk", sdk, "--show-sdk-version"], text=True, timeout=5).strip()
        if sdk_version != "27.0":
            raise ValueError("Unqualified current SDK")
        binary = output / ("probe-" + kind)
        command = ["xcrun", "--sdk", sdk, "swiftc", "-parse-as-library", "-swift-version", "6",
                   "-strict-concurrency=complete", "-sdk", sdk_path, "-target", target,
                   "-module-cache-path", str(cache), str(copied), "-o", str(binary)]
        started = time.monotonic()
        actual = subprocess.run(command, capture_output=True, timeout=60)
        (output / (kind + ".stdout.log")).write_bytes(actual.stdout)
        (output / (kind + ".stderr.log")).write_bytes(actual.stderr)
        row = {"kind": kind, "command": command, "sdkPath": sdk_path, "sdkVersion": sdk_version,
               "exit": actual.returncode, "seconds": time.monotonic() - started,
               "stdoutSHA256": hashlib.sha256(actual.stdout).hexdigest(),
               "stderrSHA256": hashlib.sha256(actual.stderr).hexdigest()}
        if actual.returncode == 0:
            row["binary"] = digest(binary)
            signing = subprocess.run(["/usr/bin/codesign", "--verify", "--strict", str(binary)], capture_output=True, text=True, timeout=5)
            row["codeSignVerify"] = {"exit": signing.returncode, "stdout": signing.stdout, "stderr": signing.stderr}
            built = subprocess.run(["xcrun", "vtool", "-show-build", str(binary)], capture_output=True, text=True, timeout=5)
            row["actualMachOBuildVersion"] = {"exit": built.returncode, "stdout": built.stdout, "stderr": built.stderr}
            platforms = re.findall(r"(?m)^\s*platform\s+(\w+)\s*$", built.stdout)
            sdks = re.findall(r"(?m)^\s*sdk\s+([0-9.]+)\s*$", built.stdout)
            row["actualPlatform"] = platforms[0] if built.returncode == 0 and platforms == [platform] and sdks == ["27.0"] else None
        report["builds"].append(row)
        (output / "BUILD.json").write_text(json.dumps(report, indent=2) + "\n")
        if actual.returncode != 0:
            break
    good = len(report["builds"]) == 2 and all(row["exit"] == 0 and row["codeSignVerify"]["exit"] == 0
        and row["actualPlatform"] == ("MACOS" if row["kind"] == "host" else "IOSSIMULATOR")
        for row in report["builds"])
    report["status"] = "COMPILED_ONLY_NO_NETWORK_OR_NATIVE_UI" if good else "COMPILE_FAILED_OR_UNQUALIFIED"
    report["completedAt"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    report["originalSourceUnchanged"] = digest(source) == report["sourceBeforeCopy"]
    (output / "BUILD.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report))
    if not good or not report["originalSourceUnchanged"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()

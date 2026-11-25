#!/usr/bin/env python3
"""Run focused Swift snapshot-update policy checks on the owner's Apple host.

Original 37 multipart controls remain separately scoped; this runner neither
relabels them nor substitutes these policy checks for native update acceptance.
"""
from __future__ import annotations
import argparse, datetime, hashlib, json, os, pathlib, platform, subprocess, sys, uuid

ROOT = pathlib.Path(__file__).resolve().parents[3]
INPUTS = [
    "Source/Otzaria/DataProfiles/OtzariaDataProfile.swift",
    "Source/Otzaria/DataProfiles/OtzariaDataProfileRegistry.swift",
    "Source/Otzaria/Bootstrap/OtzariaDatabaseDownloadModels.swift",
    "Source/Otzaria/Bootstrap/OtzariaLibraryReleaseClient.swift",
    "Source/Otzaria/Bootstrap/OtzariaLibraryUpdatePolicy.swift",
    "Tests/HQ/updates/LibraryUpdateControls.swift",
    "Tests/HQ/updates/run_library_update_apple.py",
    "Tests/HQ/latest-multipart/official-v32-release.json",
    "Tests/HQ/latest-multipart/official-v40-release.json",
    "Tests/HQ/latest-multipart/official-v40-manifest.json",
]

def identity(data):
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}

def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args], timeout=30)

def inputs():
    result = {}
    for name in INPUTS:
        data = (ROOT / name).read_bytes()
        if data != git("show", "HEAD:" + name):
            raise RuntimeError("Input differs from committed source: " + name)
        result[name] = identity(data)
    return result

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--expected-sha", required=True)
    parser.add_argument("--prepare-only", action="store_true")
    args = parser.parse_args()
    head = git("rev-parse", "HEAD").decode().strip()
    if head != args.expected_sha or len(args.expected_sha) != 40:
        raise RuntimeError("Actual source differs from explicitly selected commit")
    if git("status", "--porcelain", "--untracked-files=no").strip():
        raise RuntimeError("Tracked source must be clean")
    before = inputs()
    out = ROOT / "build" / ("library-update-policy-" + uuid.uuid4().hex)
    out.mkdir(parents=True)
    report = {
        "source_commit": head, "inputs_before": before, "platform": platform.platform(),
        "status": "SOURCE_PREPARED_NOT_COMPILED", "native_app_update_acceptance": False,
        "output": str(out), "commands": [],
    }
    def command(name, argv, timeout=30, env=None):
        p = subprocess.run(argv, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           timeout=timeout, env=env)
        log = out / (name + ".log"); log.write_bytes(p.stdout)
        report["commands"].append({"name": name, "argv": list(map(str, argv)),
            "exit_code": p.returncode, "log": log.name, **identity(p.stdout)})
        if p.returncode:
            raise RuntimeError(name + " failed; see " + str(log))
        return p.stdout.decode().strip()
    exit_code = 0
    try:
        if not args.prepare_only:
            if sys.platform != "darwin":
                raise RuntimeError("Real Apple host required")
            report["xcode"] = command("xcode", ["xcodebuild", "-version"])
            report["swift"] = command("swift", ["xcrun", "swiftc", "--version"])
            sdk = command("sdk", ["xcrun", "--sdk", "macosx", "--show-sdk-path"])
            binary = out / "LibraryUpdateControls"
            argv = ["xcrun", "swiftc", "-sdk", sdk, "-swift-version", "5", "-parse-as-library",
                    "-Onone", "-module-cache-path", str(out / "modules")]
            argv += [str(ROOT / name) for name in INPUTS if name.endswith(".swift")]
            argv += ["-o", str(binary)]
            command("compile", argv, timeout=300)
            report["binary"] = identity(binary.read_bytes())
            env = dict(os.environ, OTZARIA_DATA_PROFILE="production")
            result = out / "CONTROLS.json"
            command("controls", [str(binary), str(ROOT / "Tests/HQ/latest-multipart"), str(result)],
                    timeout=60, env=env)
            actual = json.loads(result.read_text())
            if actual["counts"] != {"PASS": 15, "FAIL": 0, "SKIP": 0}:
                raise RuntimeError("The exact focused controls did not all pass")
            if actual["native_app_update_acceptance"] is not False:
                raise RuntimeError("Policy-only scope was expanded")
            report["status"] = actual["status"]
            report["counts"] = actual["counts"]
    except Exception as exc:
        report["status"] = "APPLE_UPDATE_POLICY_FAIL"
        report["error"] = str(exc)
        exit_code = 1
    finally:
        try:
            report["inputs_after"] = inputs()
            if before != report["inputs_after"] or git("rev-parse", "HEAD").decode().strip() != head:
                raise RuntimeError("Source changed during execution")
        except Exception as exc:
            report["status"] = "SOURCE_CHANGED"
            report["source_error"] = str(exc)
            exit_code = 1
        report["finished_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        (out / "RESULT.json").write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
        print(json.dumps({key: report.get(key) for key in ("status", "source_commit", "counts", "error", "output")}))
    return exit_code

if __name__ == "__main__":
    sys.exit(main())

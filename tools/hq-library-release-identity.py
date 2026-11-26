#!/usr/bin/env python3
"""Compile exact original release/profile sources and preserve real Apple results.
This control does not install a database or execute the application's UI.
"""
import argparse, hashlib, json, os, pathlib, subprocess, sys
ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCES = [
    "Source/Otzaria/Bootstrap/OtzariaDatabaseDownloadModels.swift",
    "Source/Otzaria/Bootstrap/OtzariaLibraryReleaseClient.swift",
    "Source/Otzaria/DataProfiles/OtzariaDataProfile.swift",
    "Source/Otzaria/DataProfiles/OtzariaDataProfileRegistry.swift",
]
TEST = "Tests/HQ/library/LibraryReleaseIdentityControls.swift"
def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=pathlib.Path, required=True)
    parser.add_argument("--source-ref")
    parser.add_argument("--live-v40", action="store_true")
    args = parser.parse_args()
    if sys.platform != "darwin":
        parser.error("Actual Apple compiler required")
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    source = out / "sources"
    source.mkdir()
    records = {}
    paths = []
    for name in SOURCES:
        data = (subprocess.check_output(["git", "-C", str(ROOT), "show", args.source_ref + ":" + name])
                if args.source_ref else (ROOT / name).read_bytes())
        path = source / pathlib.Path(name).name
        path.write_bytes(data)
        paths.append(str(path))
        records[name] = {"sha256": sha(path), "bytes": len(data)}
    test = source / pathlib.Path(TEST).name
    test.write_bytes((ROOT / TEST).read_bytes())
    records[TEST] = {"sha256": sha(test), "bytes": test.stat().st_size}
    report = {"scope": "Original native release-client controls; zero application UI",
              "source_ref": args.source_ref or subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", "HEAD"], text=True).strip(),
              "sources": records, "configurations": {},
              "xcode": subprocess.check_output(["xcodebuild", "-version"], text=True).strip(),
              "swift": subprocess.check_output(["xcrun", "swiftc", "--version"], text=True).strip()}
    failures = 0
    for config in ["Debug", "Release"]:
        binary = out / ("release-identity-" + config.lower())
        command = ["xcrun", "swiftc", "-parse-as-library", "-swift-version", "6", *paths, str(test), "-o", str(binary)]
        if config == "Debug":
            command[2:2] = ["-D", "DEBUG"]
        row = {"compile_command": command}
        with (out / (config + "-compile.log")).open("wb") as stream:
            result = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT)
        row["compile_exit"] = result.returncode
        if result.returncode == 0:
            env = os.environ.copy()
            env.update(OTZARIA_NATIVE_BOOTSTRAP_ACCEPTANCE="cancel",
                       OTZARIA_NATIVE_BOOTSTRAP_RELEASE_ID="455390662", OTZARIA_DATA_PROFILE="production")
            run = [str(binary)]
            if config == "Debug" and args.live_v40:
                run.append("--live-v40")
            result = subprocess.run(run, capture_output=True, text=True, env=env, timeout=120)
            (out / (config + "-run.log")).write_text(result.stdout + result.stderr)
            row["run_exit"] = result.returncode
            row["binary_sha256"] = sha(binary)
            try:
                row["result"] = json.loads(result.stdout)
            except ValueError:
                row["result"] = {"unparsed_failure": True}
        if row.get("compile_exit") != 0 or row.get("run_exit") != 0:
            failures += 1
        report["configurations"][config] = row
    report["failed_configurations"] = failures
    (out / "RESULT.json").write_text(json.dumps(report, ensure_ascii=False, sort_keys=True, indent=2) + "\n")
    print(json.dumps({"output": str(out), "failed_configurations": failures, "results": {
        k: {f: v.get(f) for f in ["compile_exit", "run_exit"]} for k, v in report["configurations"].items()}}))
    return 1 if failures else 0
if __name__ == "__main__":
    sys.exit(main())

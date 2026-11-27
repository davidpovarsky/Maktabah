#!/usr/bin/env python3
"""Run the original nine SQLite controls plus one retained-marker regression.
A failing test remains a nonzero exit; this diagnostic does not grant acceptance.
"""
import argparse, datetime, hashlib, json, pathlib, platform, subprocess, sys

def digest(path):
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--prepared-dir", type=pathlib.Path, required=True)
    args = parser.parse_args()
    root = args.prepared_dir.resolve()
    if sys.platform != "darwin":
        raise RuntimeError("Original Apple compiler and filesystem are required")
    contract = json.loads((root / "REPRODUCTION_INPUTS.json").read_text())
    actual = {name: digest(root / name) for name in contract["inputs"]}
    if actual != contract["inputs"]:
        raise RuntimeError("Exact prepared source bytes differ")
    result = {
        "scope": "real-filesystem-SQLite-negative-control",
        "product_sha": contract["product_sha"],
        "original_evidence_sha": contract["original_evidence_sha"],
        "control_sha256": digest(root / "Controls.swift")["sha256"],
        "inputs": actual, "runner": digest(pathlib.Path(__file__)),
        "started_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "host": platform.platform(), "ui_acceptance": False,
        "product_acceptance": False, "commands": []
    }
    result_path = root / "RESULT.json"
    for command in [["xcodebuild", "-version"], ["xcrun", "swiftc", "--version"],
                    ["df", "-k", "/System/Volumes/Data"]]:
        run = subprocess.run(command, text=True, capture_output=True, timeout=30)
        result["commands"].append({"command": command, "exit": run.returncode,
                                  "stdout": run.stdout, "stderr": run.stderr})
        run.check_returncode()
    sources = [str(root / ("Controls.swift" if name == contract["original_control"] else name))
               for name in contract["source_files"]]
    binary = root / "LibraryRecoveryRetainedMarker"
    command = ["xcrun", "swiftc", "-swift-version", "5", "-parse-as-library",
               "-module-cache-path", str(root / "modules"), "-L", "/opt/homebrew/lib", "-lzstd",
               *sources, str(root / "ComponentBoundary.swift"), "-o", str(binary)]
    with (root / "compile.log").open("x") as log:
        run = subprocess.run(command, cwd=root, stdout=log, stderr=subprocess.STDOUT, timeout=180)
    result["commands"].append({"command": command, "exit": run.returncode})
    if run.returncode:
        result["status"] = "COMPILE_FAILED"
        result_path.write_text(json.dumps(result, indent=2) + "\n")
        print((root / "compile.log").read_text())
        return run.returncode
    result["binary"] = digest(binary)
    run = subprocess.run([str(binary)], cwd=root, text=True, capture_output=True, timeout=60,
                         env={"PATH": "/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin",
                              "HOME": str(pathlib.Path.home()), "OTZARIA_DATA_PROFILE": "production"})
    (root / "run.log").write_text(run.stdout + run.stderr)
    rows = [json.loads(line) for line in run.stdout.splitlines() if line.startswith("{")]
    result["test_exit"] = run.returncode
    result["rows"] = rows
    result["inputs_after"] = {name: digest(root / name) for name in contract["inputs"]}
    expected = "consecutive_update_retained_cleanup_marker"
    failed = [row for row in rows if row.get("status") == "FAIL"]
    summaries = [row for row in rows if "passed" in row]
    reproduced = (run.returncode != 0 and len(failed) == 1 and failed[0].get("case") == expected
                  and "Recovery accepted the second database" in failed[0].get("error", "")
                  and len(summaries) == 1 and summaries[0]["passed"] == 9
                  and summaries[0]["failed"] == 1 and summaries[0]["skipped"] == 0
                  and result["inputs_after"] == actual)
    result["status"] = "NEGATIVE_CONTROL_REPRODUCED" if reproduced else (
        "CONTROL_PASSED" if run.returncode == 0 else "UNEXPECTED_TEST_FAILURE")
    result["finished_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    space = subprocess.run(["df", "-k", "/System/Volumes/Data"], text=True, capture_output=True, check=True)
    result["disk_after"] = space.stdout
    result_path.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"status": result["status"], "test_exit": run.returncode,
                      "result": str(result_path), "result_digest": digest(result_path),
                      "summaries": summaries}, indent=2))
    return run.returncode

if __name__ == "__main__":
    raise SystemExit(main())

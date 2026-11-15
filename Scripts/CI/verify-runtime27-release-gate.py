#!/usr/bin/env python3
"""Require exact, recent, complete real UI artifacts before TestFlight signing."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import runpy
import stat
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[2]
GUARD = runpy.run_path(str(ROOT / "tools/verify_xcresult_zero_skips.py"))


def require(value, reason):
    if not value:
        raise ValueError(reason)


def read(root, relative):
    part = PurePosixPath(relative)
    require(not part.is_absolute() and ".." not in part.parts, "Unsafe evidence path")
    path = (root / relative).resolve()
    require(path.is_relative_to(root.resolve()) and path.is_file(), "Required evidence missing: " + relative)
    return path


def verify(run, root, expected_sha, manifest, manifest_sha, application_trees, now=None):
    require(manifest.get("full_release_acceptance_required") is True and manifest.get("configurations"), "Missing full release requirements")
    require(re.fullmatch(r"[a-f0-9]{40}", expected_sha) is not None, "Missing exact candidate SHA")
    require(run.get("status") == "completed" and run.get("conclusion") == "success", "UI acceptance run did not complete successfully")
    require(run.get("head_sha") == expected_sha, "Stale/different acceptance checkout")
    require(run.get("event") == "workflow_dispatch", "Unexpected acceptance trigger")
    require(run.get("path", "").split("@")[0] == ".github/workflows/sefaria-embedded-validation.yml", "Unexpected acceptance workflow")
    completed = datetime.fromisoformat(run["updated_at"].replace("Z", "+00:00"))
    age = ((now or datetime.now(timezone.utc)) - completed).total_seconds()
    require(0 <= age <= manifest["max_age_hours"] * 3600, "Stale/future acceptance result")
    result = json.loads(read(root, "artifacts/runtime27/result.json").read_text())
    require(result.get("status") == "EXECUTED_PASS" and result.get("full_release_acceptance") is True,
            "Missing full real UI acceptance; focused subsets/build/probe do not satisfy release")
    require(result.get("checkout_sha") == expected_sha, "Acceptance artifact checkout mismatch")
    require(result.get("release_manifest_sha256") == manifest_sha, "Missing/stale full acceptance manifest")
    require(result.get("scope") == manifest["scope"] == "full-release-ui", "Partial/non-release UI scope")
    build = json.loads(read(root, "hq-stage2/result.json").read_text())
    require(build.get("status") == "SIMULATOR_BUILD_FOR_REAL_UI_PASS" and build.get("checkout_sha") == expected_sha, "Missing actual matching app/test build")
    require(build.get("application_trees") == application_trees, "Application/dependency project fingerprints changed")
    require(build.get("actual_source_inputs_verified", 0) > 0 and len(build.get("actual_package_checkouts", {})) == 6,
            "Missing actual app/package input audit")
    for package, revision in build.get("package_pins", {}).items():
        require(build["actual_package_checkouts"].get(package) == {"head": revision, "status": "CLEAN"}, "Actual pinned package source mismatch")
    require(len(build.get("package_pins", {})) == 6, "Missing package revision manifest")
    required_configs = {row["id"]: row for row in manifest["configurations"]}
    configs = result.get("configurations", [])
    require(len(configs) == len(required_configs) and {row.get("id") for row in configs} == required_configs.keys(),
            "Missing/duplicate/partial device configurations")
    passed = 0
    for actual in configs:
        required = required_configs[actual["id"]]
        require(actual.get("status") == "EXECUTED_PASS" and actual.get("device_size") == required["device_size"], "Device acceptance incomplete")
        require(str(actual.get("os_version", "")).split(".")[0] == str(manifest["required_os_major"])
                and actual.get("os_build") and actual.get("device_udid"), "Missing/wrong actual OS/device fingerprint")
        require(actual.get("data_profile") == required["data_profile"], "Wrong/missing data profile")
        for field in ["content_size", "configuration"]:
            if field in required:
                require(actual.get(field) == required[field], "Wrong/missing actual " + field)
        require(actual.get("locale") and actual.get("orientations") and actual.get("app_binary_sha256")
                and actual.get("test_binary_sha256"), "Missing locale/orientation/binary fingerprints")
        summary = json.loads(read(root, actual["summary_path"]).read_text())
        tree = json.loads(read(root, actual["tests_path"]).read_text())
        devices = tree.get("devices", [])
        require(len(devices) == 1 and devices[0].get("deviceId") == actual["device_udid"]
                and devices[0].get("osVersion") == actual["os_version"], "xcresult actual device/OS does not match configuration")
        log = read(root, actual["log_path"]).read_text()
        checked = GUARD["verify"](summary, tree, log, required["required_ui_cases"], len(required["required_ui_cases"]))
        passed += checked["required_ui_passed"]
        data = json.loads(read(root, actual["data_evidence_path"]).read_text())
        require(data.get("passed") is True and data.get("profileID") == required["data_profile"]
                and data.get("shaMatched") is True and data.get("expectedSHA256")
                and data.get("expectedSHA256") == data.get("actualSHA256")
                and data.get("quickCheck", "").lower() == "ok" and data.get("bookCount", 0) > 0,
                "Missing positive real native data installation evidence")
        if required["data_profile"] == "production":
            require(data.get("bookCount", 0) >= 7000 and data.get("extractedBytes", 0) >= 1_500_000_000,
                    "Production UI gate lacks full real corpus evidence")
    return {"status": "RELEASE_UI_GATE_PASS", "checkout_sha": expected_sha, "required_ui_passed": passed,
            "configurations": sorted(required_configs), "release_manifest_sha256": manifest_sha,
            "database_effect_claim": "NONE; actual data report and real UI assertions checked separately"}


def api(path):
    return json.loads(subprocess.check_output(["gh", "api", path], text=True))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", required=True)
    parser.add_argument("--expected-sha", required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    report = {"status": "FAIL", "distribution_started": False}
    try:
        require(re.fullmatch(r"[1-9][0-9]*", args.run) is not None, "A successful full UI acceptance run ID is mandatory")
        repository = os.environ.get("GITHUB_REPOSITORY")
        require(repository == "davidpovarsky/Maktabah", "Unexpected repository")
        run = api(f"repos/{repository}/actions/runs/{args.run}")
        # Reject stale/failure before downloading potentially large artifacts.
        require(run.get("head_sha") == args.expected_sha and run.get("conclusion") == "success", "UI run failed or candidate changed")
        artifacts = api(f"repos/{repository}/actions/runs/{args.run}/artifacts?per_page=100")["artifacts"]
        selected = [v for v in artifacts if v["name"] == "runtime27-evidence" and not v["expired"]]
        require(len(selected) == 1, "Exactly one live runtime27-evidence artifact is mandatory")
        artifact = selected[0]
        with tempfile.TemporaryDirectory(prefix="runtime27-release-gate-") as folder:
            folder = Path(folder)
            archive = folder / "evidence.zip"
            with archive.open("wb") as output:
                subprocess.run(["gh", "api", f"repos/{repository}/actions/artifacts/{artifact['id']}/zip"], stdout=output, check=True)
            digest = hashlib.sha256(archive.read_bytes()).hexdigest()
            require(artifact.get("digest") == "sha256:" + digest, "Artifact ZIP digest missing/mismatched")
            destination = folder / "extracted"
            with zipfile.ZipFile(archive) as value:
                require(sum(member.file_size for member in value.infolist()) < 8 * 1024**3, "Oversized UI evidence")
                for member in value.infolist():
                    part = PurePosixPath(member.filename)
                    require(not part.is_absolute() and ".." not in part.parts and not stat.S_ISLNK(member.external_attr >> 16), "Unsafe artifact member")
                value.extractall(destination)
            manifest_path = ROOT / "Scripts/CI/runtime27-release-manifest.json"
            manifest = json.loads(manifest_path.read_text())
            manifest_sha = hashlib.sha256(manifest_path.read_bytes()).hexdigest()
            trees = {path: subprocess.check_output(["git", "rev-parse", "HEAD:" + path], text=True).strip()
                     for path in ["Source", "Vendor", "Maktabah.xcodeproj"]}
            report.update(verify(run, destination, args.expected_sha, manifest, manifest_sha, trees))
            report.update(acceptance_run=args.run, artifact_id=artifact["id"], artifact_zip_sha256=digest)
    except (ValueError, KeyError, OSError, subprocess.SubprocessError) as error:
        report["error"] = str(error)
        print("::error::" + str(error), file=sys.stderr)
    finally:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps(report, indent=2))
    return 0 if report["status"] == "RELEASE_UI_GATE_PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())

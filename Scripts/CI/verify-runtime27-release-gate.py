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
import copy
import shutil

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


def verify(run, root, expected_sha, manifest, manifest_sha, application_trees, now=None, reuse_proof=None):
    require(manifest.get("full_release_acceptance_required") is True and manifest.get("configurations"), "Missing full release requirements")
    require(re.fullmatch(r"[a-f0-9]{40}", expected_sha) is not None, "Missing exact candidate SHA")
    require(run.get("status") == "completed" and run.get("conclusion") == "success", "UI acceptance run did not complete successfully")
    tested_sha = run.get("head_sha")
    if tested_sha != expected_sha:
        require(reuse_proof and reuse_proof.get("kind") == "DOCUMENTATION_ONLY_DESCENDANT"
                and reuse_proof.get("tested_sha") == tested_sha and reuse_proof.get("candidate_sha") == expected_sha
                and all(path.startswith("docs/hq-integration/") for path in reuse_proof.get("changed_paths", [])),
                "Stale/different acceptance checkout without bounded input-equivalence proof")
    require(run.get("event") == "workflow_dispatch", "Unexpected acceptance trigger")
    require(run.get("path", "").split("@")[0] == ".github/workflows/sefaria-embedded-validation.yml", "Unexpected acceptance workflow")
    completed = datetime.fromisoformat(run["updated_at"].replace("Z", "+00:00"))
    age = ((now or datetime.now(timezone.utc)) - completed).total_seconds()
    require(0 <= age <= manifest["max_age_hours"] * 3600, "Stale/future acceptance result")
    result = json.loads(read(root, "artifacts/runtime27/result.json").read_text())
    require(result.get("status") == "EXECUTED_PASS" and result.get("full_release_acceptance") is True,
            "Missing full real UI acceptance; focused subsets/build/probe do not satisfy release")
    require(result.get("checkout_sha") == tested_sha, "Acceptance artifact checkout mismatch")
    require(result.get("release_manifest_sha256") == manifest_sha, "Missing/stale full acceptance manifest")
    require(result.get("scope") == manifest["scope"] == "full-release-ui", "Partial/non-release UI scope")
    build = json.loads(read(root, "hq-stage2/result.json").read_text())
    require(build.get("status") == "SIMULATOR_BUILD_FOR_REAL_UI_PASS" and build.get("checkout_sha") == tested_sha, "Missing actual matching app/test build")
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
    return {"status": "RELEASE_UI_GATE_PASS", "checkout_sha": expected_sha, "tested_checkout_sha": tested_sha,
            "bounded_reuse_proof": reuse_proof, "required_ui_passed": passed,
            "configurations": sorted(required_configs), "release_manifest_sha256": manifest_sha,
            "database_effect_claim": "NONE; actual data report and real UI assertions checked separately"}


def api(path):
    return json.loads(subprocess.check_output(["gh", "api", path], text=True))


def documentation_reuse(tested_sha, candidate_sha):
    require(re.fullmatch(r"[a-f0-9]{40}", tested_sha or "") is not None, "Missing tested SHA")
    if tested_sha == candidate_sha:
        return None
    subprocess.run(["git", "merge-base", "--is-ancestor", tested_sha, candidate_sha], check=True)
    delta = subprocess.check_output(["git", "diff", "--name-only", tested_sha, candidate_sha], text=True).splitlines()
    require(all(path.startswith("docs/hq-integration/") for path in delta),
            "Changed app/test/data/dependency/tool/configuration inputs require affected-case validation")
    diff = subprocess.check_output(["git", "diff", "--binary", tested_sha, candidate_sha])
    return {"kind": "DOCUMENTATION_ONLY_DESCENDANT", "tested_sha": tested_sha, "candidate_sha": candidate_sha,
            "changed_paths": delta, "diff_sha256": hashlib.sha256(diff).hexdigest(),
            "impact": "All application, test, data-profile, dependency, tool and execution configuration bytes unchanged"}


def sha256(path):
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def verify_prepared_inputs(approved_path):
    approved = json.loads(approved_path.read_text())
    build = copy.deepcopy(approved["tested_build_report"])
    native = build["native_context"]
    require(subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip() == approved["candidate_sha"], "Candidate moved after UI gate")
    for path, expected in [("Podfile", native["podfile_sha256"]), ("Podfile.lock", native["pod_lock_sha256"]),
                           ("Vendor/SefariaMobile/Upstream/package-lock.json", native["npm_lock_sha256"]),
                           ("Maktabah.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved", build["package_resolved_sha256"])]:
        require(sha256(ROOT / path) == expected, "Prepared input differs from real UI acceptance: " + path)
    require(subprocess.check_output(["git", "-C", "Vendor/SefariaMobile/Upstream", "rev-parse", "HEAD"], text=True).strip() == native["gitlink"], "Sefaria source pin changed")
    for command, expected in [(["xcodebuild", "-version"], build["xcode"]), (["node", "--version"], native["node"]),
                              (["pod", "--version"], native["cocoapods"])]:
        require(subprocess.check_output(command, text=True).strip() == expected.strip(), "Prepared toolchain differs from real UI acceptance")
    for provider in native["generated_expo_providers"]:
        require(sha256(ROOT / provider["path"]) == provider["sha256"], "Generated Expo source differs from UI acceptance")
    for generated in build.get("generated_configuration", []):
        require(sha256(ROOT / generated["path"]) == generated["compiled_sha256"], "Generated source context differs from UI acceptance")
    # Reuse the existing actual-files/package auditor. No duplicate source guard
    # or blanket dirty-source exception is introduced for the signing workflow.
    helper = runpy.run_path(str(ROOT / "Scripts/CI/hq-stage2-focused-apple.py"))
    evidence = approved_path.parent / "runtime27-prepared-inputs"
    evidence.mkdir(parents=True, exist_ok=True)
    helper["verify_actual_sources"].__globals__["OUT"] = evidence
    helper["verify_actual_sources"](build)
    return {"status": "RELEASE_UI_INPUTS_PASS", "checkout_sha": approved["candidate_sha"],
            "tested_checkout_sha": approved["tested_sha"], "actual_source_inputs_verified": build["actual_source_inputs_verified"],
            "actual_package_checkouts": build["actual_package_checkouts"]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run")
    parser.add_argument("--expected-sha")
    parser.add_argument("--check-prepared-inputs", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    report = {"status": "FAIL", "distribution_started": False}
    try:
        if args.check_prepared_inputs:
            report.update(verify_prepared_inputs(args.check_prepared_inputs))
            return 0
        require(re.fullmatch(r"[1-9][0-9]*", args.run or "") is not None, "A successful full UI acceptance run ID is mandatory")
        require(subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip() == args.expected_sha, "Candidate SHA must match the actual checkout")
        repository = os.environ.get("GITHUB_REPOSITORY")
        require(repository == "davidpovarsky/Maktabah", "Unexpected repository")
        run = api(f"repos/{repository}/actions/runs/{args.run}")
        # Reject stale/failure before downloading potentially large artifacts.
        require(run.get("conclusion") == "success", "UI run failed")
        reuse = documentation_reuse(run.get("head_sha"), args.expected_sha)
        artifacts = api(f"repos/{repository}/actions/runs/{args.run}/artifacts?per_page=100")["artifacts"]
        selected = [v for v in artifacts if v["name"] == "runtime27-evidence" and not v["expired"]]
        require(len(selected) == 1, "Exactly one live runtime27-evidence artifact is mandatory")
        artifact = selected[0]
        with tempfile.TemporaryDirectory(prefix="runtime27-release-gate-") as folder:
            folder = Path(folder)
            archive = folder / "evidence.zip"
            with archive.open("wb") as output:
                subprocess.run(["gh", "api", f"repos/{repository}/actions/artifacts/{artifact['id']}/zip"], stdout=output, check=True)
            with archive.open("rb") as source:
                digest = hashlib.file_digest(source, "sha256").hexdigest()
            require(artifact.get("digest") == "sha256:" + digest, "Artifact ZIP digest missing/mismatched")
            destination = folder / "extracted"
            with zipfile.ZipFile(archive) as value:
                require(sum(member.file_size for member in value.infolist()) < 8 * 1024**3, "Oversized UI evidence")
                for member in value.infolist():
                    part = PurePosixPath(member.filename.replace("\\", "/"))
                    require(not part.is_absolute() and ".." not in part.parts and not re.match(r"^[A-Za-z]:", member.filename)
                            and not stat.S_ISLNK(member.external_attr >> 16), "Unsafe artifact member")
                value.extractall(destination)
            manifest_path = ROOT / "Scripts/CI/runtime27-release-manifest.json"
            manifest = json.loads(manifest_path.read_text())
            manifest_sha = hashlib.sha256(manifest_path.read_bytes()).hexdigest()
            trees = {path: subprocess.check_output(["git", "rev-parse", "HEAD:" + path], text=True).strip()
                     for path in ["Source", "Vendor", "Maktabah.xcodeproj"]}
            verified = verify(run, destination, args.expected_sha, manifest, manifest_sha, trees, reuse_proof=reuse)
            build = json.loads(read(destination, "hq-stage2/result.json").read_text())
            lock = read(destination, "hq-stage2/resolved-Podfile.lock")
            require(sha256(lock) == build["native_context"]["pod_lock_sha256"], "UI Podfile.lock bytes missing/mismatched")
            candidate_lock = ROOT / "Podfile.lock"
            require(not candidate_lock.is_symlink(), "Occupied native lock path is a symlink")
            require(not candidate_lock.exists() or sha256(candidate_lock) == sha256(lock), "Committed/current native lock differs from tested UI")
            shutil.copyfile(lock, candidate_lock)
            args.out.parent.mkdir(parents=True, exist_ok=True)
            (args.out.parent / "runtime27-approved-inputs.json").write_text(json.dumps({"candidate_sha": args.expected_sha,
                "tested_sha": run["head_sha"], "tested_build_report": build}, indent=2) + "\n")
            report.update(verified, acceptance_run=args.run, artifact_id=artifact["id"], artifact_zip_sha256=digest)
    except (ValueError, KeyError, OSError, subprocess.SubprocessError) as error:
        report.update(status="FAIL", error=str(error))
        print("::error::" + str(error), file=sys.stderr)
    finally:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps(report, indent=2))
    return 0 if report["status"] == "RELEASE_UI_GATE_PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())

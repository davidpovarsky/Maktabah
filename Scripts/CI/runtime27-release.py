#!/usr/bin/env python3
"""Produce full-release evidence from existing real native runners.

No signing, distribution, artificial run status, invented database, or PASS
substitution. The independent release gate still checks the completed GitHub run.
"""
import copy
import hashlib
import json
import os
from pathlib import Path
import re
import runpy
import sys

ROOT = Path(__file__).resolve().parents[2]
CONFIG_IDS = {"ipad11-native", "ipad13-native", "ipad13-largest-text",
              "iphone-native", "ipad13-production-release"}


def require(value, message):
    if not value:
        raise ValueError(message)


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def digest(path):
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def requires_native_hid(selected_cases):
    # This original case sends real A/Delete/Escape HID events. A Release
    # manifest uses no R27 execution-group object, but still needs that transport.
    return "R27NativePadTests/testNormalBootstrapNativeWindowResizePaletteAndInspector" in selected_cases


def load_manifest(root=ROOT):
    manifest = read_json(root / "Scripts/CI/runtime27-release-manifest.json")
    rows = manifest.get("configurations", [])
    require(manifest.get("scope") == "full-release-ui"
            and manifest.get("full_release_acceptance_required") is True
            and manifest.get("required_os_major") == 27,
            "Missing full-release OS27 contract")
    require(len(rows) == len(CONFIG_IDS) and {row.get("id") for row in rows} == CONFIG_IDS,
            "Missing or duplicate full release configurations")
    identities = []
    for row in rows:
        ui = row.get("required_ui_cases", [])
        selected = ui + row.get("required_oracle_cases", [])
        require(ui and len(selected) == len(set(selected))
                and all(re.fullmatch(r"\w+/test\w+", identity) for identity in selected),
                "Missing, duplicated or invalid native test declarations")
        require(row["device_size"] in {"11", "13", "phone"}
                and row["data_profile"] in {"miniTest10", "production"},
                "Invalid actual-device or corpus configuration")
        if row["id"] == "ipad13-production-release":
            require(row["device_size"] == "13" and row["data_profile"] == "production"
                    and row.get("configuration") == "Release",
                    "Full production Release configuration is mandatory")
        elif row["id"] == "ipad13-largest-text":
            require(row["device_size"] == "13" and row["data_profile"] == "miniTest10"
                    and row.get("content_size") == "accessibility-extra-extra-extra-large",
                    "Actual largest accessibility text size is mandatory")
        identities.extend(selected)
    declarations = runpy.run_path(str(root / "Scripts/CI/verify-faithful-xctest.py"))["validate_selections"](
        sorted(set(identities)), root / "Maktabah-iOSUITests")
    require(declarations["status"] == "DECLARATIONS_MATCH",
            "Full release XCTest methods are missing from the actual target")
    for source in manifest.get("prepared_source_requirements", []):
        path = root / source["path"]
        observed = digest(path) if path.is_file() else "MISSING"
        require(path.is_file() and path.resolve().is_relative_to((root / "Maktabah-iOSUITests").resolve())
                and observed == source["sha256"],
                "Prepared test does not match the current registered native target: "
                + source["path"] + "; expected " + source["sha256"] + "; observed " + observed)
        require(set(source["required_cases"]) <= set(identities),
                "Prepared native test omitted from release execution")
    return manifest


def runtime_configuration_observations(log):
    """Only real XCTest runner observations; locale source remains explicit."""
    records = []
    for line in log.splitlines():
        if "R27_RUNTIME_CONFIGURATION " not in line:
            continue
        try:
            value, _ = json.JSONDecoder().raw_decode(line.split("R27_RUNTIME_CONFIGURATION ", 1)[1].strip())
        except ValueError:
            raise ValueError("Malformed native runtime configuration observation") from None
        require(value.get("bundle_id") == "com.davidpovarsky.chavrusatext"
                and value.get("locale_source") == "XCUIApplication.launchArguments/-AppleLocale"
                and value.get("orientation_source") == "XCUIDevice.shared.orientation"
                and value.get("test"), "Unexpected runtime configuration provenance")
        if value.get("foreground") is True:
            records.append(value)
    orientations = {1: "portrait", 2: "portraitUpsideDown", 3: "landscapeLeft", 4: "landscapeRight"}
    locales = sorted({value["locale"] for value in records if value.get("locale")})
    actual_orientations = sorted({orientations[value["orientation"]] for value in records
                                  if value.get("orientation") in orientations})
    require(locales and actual_orientations,
            "No foreground native locale-argument/orientation observations; cannot invent them")
    return {"locale": {"identifiers": locales, "source": "XCUIApplication.launchArguments/-AppleLocale",
                       "rendering_acceptance": "Separate required localized UI and RTL assertions"},
            "orientations": actual_orientations, "observation_count": len(records)}


def collect_configurations(root, report, manifest, *, native_only=False):
    artifacts = root / "build/artifacts"
    matrix = read_json(artifacts / "faithful-ipad-matrix.json")
    production = None if native_only else read_json(artifacts / "production-release-acceptance.json")
    manifest_sha = digest(root / "Scripts/CI/runtime27-release-manifest.json")
    require(matrix.get("appSHA") == report["checkout_sha"] and not matrix.get("baseline")
            and matrix.get("fullMatrixAcceptance") is True
            and not matrix.get("diagnosticCases")
            and matrix.get("releaseManifestSHA256") == manifest_sha,
            "The native matrix is partial, stale or belongs to another source")
    devices = {value["size"]: value for value in matrix.get("devices", [])}
    require(len(matrix.get("devices", [])) == 3 and set(devices) == {"11", "13", "phone"},
            "Missing or duplicate full native device configurations")
    if not native_only:
        require(production.get("appSHA") == report["checkout_sha"]
                and production.get("configuration") == "Release"
                and production.get("dataProfile") == "production"
                and production.get("status") == "EXECUTED_PASS",
                "No passing full-corpus Release UI execution on this source")
    configurations = []
    for required in manifest["configurations"]:
        production_case = required["data_profile"] == "production"
        if native_only and production_case:
            continue
        large = "content_size" in required
        device = production if production_case else devices[required["device_size"]]
        state = device.get("largeText", {}) if large else device
        require(state.get("status") == "EXECUTED_PASS", "Native configuration did not pass")
        if not production_case:
            require(device.get("ownedSimulatorCleanup") == "PASS",
                    "Disposable native simulator cleanup was not verified")
        label = "production-release" if production_case else "13-large-text" if large else required["device_size"]
        configuration = "Release" if production_case else "Debug"
        products = f"build/{'ReleaseDerivedData' if production_case else 'DerivedData'}/Build/Products/{configuration}-iphonesimulator/"
        binaries = production.get("built_binary_sha256", {}) if production_case else report.get("built_binary_sha256", {})
        app_hash = binaries.get(products + "Maktabah.app")
        test_hash = binaries.get(products + "Maktabah-iOSUITests-Runner.app/PlugIns/Maktabah-iOSUITests.xctest")
        require(re.fullmatch(r"[a-f0-9]{64}", app_hash or "") and re.fullmatch(r"[a-f0-9]{64}", test_hash or ""),
                "Missing actual built app or native test binary fingerprint")
        runtime = device["runtime"]
        log_path = "artifacts/production-release-tests.log" if production_case else f"artifacts/test-simulator-{label}.log"
        observed = runtime_configuration_observations((root / "build" / log_path).read_text(encoding="utf-8"))
        actual = {"id": required["id"], "device_size": required["device_size"], "status": "EXECUTED_PASS",
                  "configuration": configuration, "data_profile": required["data_profile"],
                  "device_udid": device["udid"], "os_version": runtime["version"],
                  "os_build": runtime.get("buildversion") or runtime.get("buildVersion"),
                  "app_binary_sha256": app_hash, "test_binary_sha256": test_hash, **observed,
                  "summary_path": f"artifacts/runtime27/verified-{label}.summary.json",
                  "tests_path": f"artifacts/runtime27/verified-{label}.tests.json", "log_path": log_path,
                  "data_evidence_path": ("artifacts/production-native-fixture-install.json" if production_case
                                         else f"artifacts/miniTest10-native-fixture-install-{required['device_size']}.json")}
        if large:
            require(state.get("actual") == required["content_size"],
                    "The actual system accessibility text size differs from the requirement")
            actual["content_size"] = state["actual"]
        configurations.append(actual)
    return configurations


def run(report, run_logged, controller):
    root = ROOT
    out = root / "build/artifacts/runtime27"
    manifest = load_manifest(root)
    manifest_path = root / "Scripts/CI/runtime27-release-manifest.json"
    manifest_sha = digest(manifest_path)
    report.update(full_release_acceptance=False, scope="full-release-ui",
                  release_manifest_sha256=manifest_sha,
                  requested_ui_case_count=sum(len(row["required_ui_cases"]) for row in manifest["configurations"]),
                  phase_native_scope="Separate R27_CASES acceptance remains mandatory; this run executes the full release manifest")
    (out / "release-manifest.json").write_bytes(manifest_path.read_bytes())
    for path in ["Scripts/CI/runtime27-release.py", "Scripts/CI/runtime27-release-manifest.json",
                 "Scripts/CI/run-faithful-production-release.py", "Scripts/CI/build-faithful-prototype-reference.py",
                 "Scripts/CI/verify-runtime27-release-gate.py", "Scripts/CI/runtime27-release-stages.py",
                 "Scripts/CI/runtime27_release_handoff.py"]:
        report["helper_inputs_sha256"][path] = digest(root / path)
    require(not os.environ.get("FAITHFUL_RUNTIME27_MANIFEST") and not os.environ.get("FAITHFUL_DIAGNOSTIC_CASES"),
            "Release cannot inherit a partial diagnostic selection")
    os.environ["VALIDATING_BASELINE"] = "false"
    os.environ["FAITHFUL_RUNTIME27_RELEASE_MANIFEST"] = str(manifest_path)
    if run_logged([sys.executable, "Scripts/CI/build-faithful-prototype-reference.py"],
                  "release-prototype-build.log", 900, interrupt_controller=controller):
        raise RuntimeError("The byte-identical separate prototype oracle did not build")
    stage = os.environ.get("RUNTIME27_RELEASE_STAGE")
    require(stage in {None, "build"}, "Unknown Release build stage")
    if stage == "build":
        # Later jobs consume these exact products; this stage executes no UI.
        reverify_original_inputs(root, report, out / "after-release-build-inputs")
        report.update(status="RELEASE_BUILD_ONLY_PASS", release_stage="build",
                      full_release_acceptance=False, executed_ui_pass=0,
                      executed_ui_fail=0, executed_ui_skip=0,
                      ui_not_run=report["requested_ui_case_count"])
        return 0
    if run_logged([sys.executable, "Scripts/CI/run-faithful-ipad-matrix.py"],
                  "release-native-matrix-driver.log", 12600, interrupt_controller=controller):
        raise RuntimeError("The complete native matrix failed; production Release and distribution remain blocked")
    if run_logged([sys.executable, "Scripts/CI/run-faithful-production-release.py"],
                  "release-production-driver.log", 7200, interrupt_controller=controller):
        raise RuntimeError("The genuine full-corpus Release UI gate failed or did not execute")
    build = reverify_original_inputs(root, report, out / "after-release-inputs")
    return complete_release(root, report, manifest, manifest_sha, build)


def reverify_original_inputs(root, report, after):
    """The original final source auditor, also retained at the build handoff."""
    build = read_json(root / "build/hq-stage2/result.json")
    helper = runpy.run_path(str(root / "Scripts/CI/hq-stage2-focused-apple.py"))
    after.mkdir(parents=True, exist_ok=True)
    helper["verify_actual_sources"].__globals__["OUT"] = after
    verified_build = copy.deepcopy(build)
    helper["verify_actual_sources"](verified_build)
    (after / "source-review.json").write_text(json.dumps({
        "checkout_sha": report["checkout_sha"],
        "actual_source_inputs_verified": verified_build["actual_source_inputs_verified"],
        "actual_package_checkouts": verified_build["actual_package_checkouts"]
    }, indent=2) + "\n", encoding="utf-8")
    return build


def complete_release(root, report, manifest, manifest_sha, build):
    """Only the original full five-configuration strict gate can grant release."""
    candidate = {**report, "status": "EXECUTED_PASS", "full_release_acceptance": True,
                 "configurations": collect_configurations(root, report, manifest)}
    gate = runpy.run_path(str(root / "Scripts/CI/verify-runtime27-release-gate.py"))
    checked = gate["verify_artifact_evidence"](
        root / "build", report["checkout_sha"], manifest, manifest_sha, build["application_trees"],
        required_inputs=gate["candidate_dependency_requirements"](), result=candidate)
    report.update(candidate, executed_ui_pass=checked["required_ui_passed"], executed_ui_fail=0,
                  executed_ui_skip=0, ui_not_run=0, separate_oracle_executed=checked["separate_oracle_executed"],
                  local_evidence_verification=checked,
                  distribution=False)
    return 0

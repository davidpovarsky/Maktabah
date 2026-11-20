#!/usr/bin/env python3
"""Build -> exact-products native matrix -> original production Release.

Every intermediate result remains partial. Only complete_release's original
five-configuration verifier can publish EXECUTED_PASS/full_release_acceptance.
"""
import argparse
import copy
import json
import os
from pathlib import Path
import runpy
import shutil
import sys

import runtime27_interruption
import runtime27_release_handoff as transfer

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build/artifacts/runtime27"
SELF = Path(__file__).resolve()
MATRIX_BUDGET_SECONDS = 16200
INPUT_RESTORATION_BUDGET_SECONDS = 4200
PRODUCTION_BUDGET_SECONDS = 7200
HID_PREPARATION_BUDGET_SECONDS = 360


def require(value, reason):
    transfer.require(value, reason)


def module(name):
    return runpy.run_path(str(ROOT / "Scripts/CI" / name))


def set_release_environment():
    require(not os.environ.get("FAITHFUL_RUNTIME27_MANIFEST")
            and not os.environ.get("FAITHFUL_DIAGNOSTIC_CASES")
            and os.environ.get("VALIDATING_BASELINE") != "true", "Release cannot inherit scoped diagnostics")
    os.environ["FAITHFUL_RUNTIME27_RELEASE_MANIFEST"] = str(ROOT / "Scripts/CI/runtime27-release-manifest.json")
    os.environ["VALIDATING_BASELINE"] = "false"


def expected_build_report():
    report = transfer.read_json(OUT / "release-build-result.json")
    build = transfer.read_json(ROOT / "build/hq-stage2/result.json")
    current = transfer.context(ROOT)
    require(report.get("status") == "RELEASE_BUILD_ONLY_PASS" and report.get("release_stage") == "build"
            and report.get("full_release_acceptance") is False
            and report.get("checkout_sha") == current["checkout_sha"], "Missing exact partial build result")
    require(build.get("status") == "SIMULATOR_BUILD_FOR_REAL_UI_PASS"
            and build.get("checkout_sha") == current["checkout_sha"], "Original Debug build was not successful")
    require(build.get("application_trees") == {key: current["trees"][key]
                                              for key in ["Source", "Vendor", "Maktabah.xcodeproj"]},
            "Original Debug build source trees differ")
    require(report.get("release_manifest_sha256") == current["release_manifest_sha256"],
            "Build selected a different full Release manifest")
    return report, build


def build_evidence_paths():
    paths = [ROOT / name for name in transfer.PRODUCT_ROOTS]
    paths.extend([OUT / "release-build-result.json", OUT / "release-manifest.json",
                  OUT / "after-release-build-inputs"])
    base = ROOT / "build/hq-stage2"
    for path in sorted(base.iterdir()):
        if path.is_file() and (path.suffix in {".json", ".log", ".diff", ".xcprivacy", ".resolved", ".swift"}
                               or path.name in {"resolved-Podfile.lock", "generated-Maktabah-project.pbxproj"}):
            paths.append(path)
    for name in ["privacy-dependency-inputs", "rebuilt-zayit"]:
        if (base / name).exists():
            paths.append(base / name)
    return paths


def pack_build():
    report = transfer.read_json(OUT / "result.json")
    require(report.get("status") == "RELEASE_BUILD_ONLY_PASS" and report.get("full_release_acceptance") is False,
            "Cannot hand off a failed or full-acceptance build report")
    transfer.write_json(OUT / "release-build-result.json", report)
    expected_build_report()
    products = transfer.product_inventory(ROOT)
    probe = {"products": products}
    transfer.original_xctestrun(ROOT, probe)
    receipt = transfer.pack(ROOT, ROOT / "build/runtime27-handoff/build", "build", build_evidence_paths(),
                            transfer.context(ROOT), report["status"], products=products)
    # Every image, resource, original test-run file and executable mode is bound.
    transfer.verify_products(ROOT, receipt)
    github_output("archive_sha256", receipt["archive"]["sha256"])
    return receipt


def strict_native_configurations(report, manifest):
    release = module("runtime27-release.py")
    rows = release["collect_configurations"](ROOT, report, manifest, native_only=True)
    required = {row["id"]: row for row in manifest["configurations"] if row["data_profile"] == "miniTest10"}
    require(len(rows) == len(required) == 4 and {row["id"] for row in rows} == set(required),
            "Native predecessor did not execute all four required configurations")
    guard = runpy.run_path(str(ROOT / "tools/verify_xcresult_zero_skips.py"))
    count = oracles = 0
    for actual in rows:
        selected = required[actual["id"]]
        oracle_cases = selected.get("required_oracle_cases", [])
        summary = transfer.read_json(ROOT / "build" / actual["summary_path"])
        tree = transfer.read_json(ROOT / "build" / actual["tests_path"])
        log = (ROOT / "build" / actual["log_path"]).read_text(encoding="utf-8")
        checked = guard["verify"](summary, tree, log, selected["required_ui_cases"],
                                   len(selected["required_ui_cases"]),
                                   min_total_tests=len(selected["required_ui_cases"]) + len(oracle_cases),
                                   required_executed_cases=oracle_cases)
        count += checked["required_ui_passed"]
        oracles += len(oracle_cases)
    return {"configurations": rows, "required_ui_passed": count, "separate_oracle_executed": oracles,
            "full_release_acceptance": False}


def native_stage(args, run_logged, controller):
    import_handoff("build", args.build_artifact, args.build_archive_sha, "native", run_logged, controller)
    build_receipt = transfer.read_json(ROOT / "build/runtime27-handoff/imported-build.json")
    report, _ = expected_build_report()
    report = copy.deepcopy(report)
    report.update(status="FAIL", release_stage="native", full_release_acceptance=False,
                  executed_ui_pass=None, executed_ui_fail=None, executed_ui_skip=None, ui_not_run=None)
    try:
        report["original_products_before_native"] = transfer.verify_products(ROOT, build_receipt)
        original_run = transfer.original_xctestrun(ROOT, build_receipt)
        set_release_environment()
        os.environ["FAITHFUL_RELEASE_XCTESTRUN"] = str(original_run)
        release = module("runtime27-release.py")
        manifest = release["load_manifest"](ROOT)
        selected = [case for row in manifest["configurations"] for case in row["required_ui_cases"]]
        if release["requires_native_hid"](selected):
            # Tool paths from the earlier Mac are never reused. The unchanged
            # pinned installer verifies tools on this actual native-execution host.
            code = run_logged([sys.executable, "Scripts/CI/runtime27-hid.py", "prepare",
                               "--out", str(OUT / "hid-tools.json")], "release-hid-prepare.log",
                              HID_PREPARATION_BUDGET_SECONDS, interrupt_controller=controller)
            require(code == 0, "Original required Release HID preflight failed; matrix NOT_RUN")
            report["release_hid_preparation"] = {"status": "ORIGINAL_PINNED_JOB_LOCAL_TOOLS_PREPARED",
                                                "native_ui_executed": 0}
        code = run_logged([sys.executable, "Scripts/CI/run-faithful-ipad-matrix.py"],
                          "release-native-matrix-driver.log", MATRIX_BUDGET_SECONDS,
                          interrupt_controller=controller)
        report["original_products_after_native"] = transfer.verify_products(ROOT, build_receipt)
        require(code == 0, "Original full native matrix failed; production remains blocked")
        checked = strict_native_configurations(report, manifest)
        report.update(status="RELEASE_NATIVE_MATRIX_ONLY_PASS", native_predecessor_verification=checked,
                      executed_ui_pass=checked["required_ui_passed"], executed_ui_fail=0, executed_ui_skip=0,
                      separate_oracle_executed=checked["separate_oracle_executed"],
                      ui_not_run=sum(len(row["required_ui_cases"]) for row in manifest["configurations"]
                                     if row["data_profile"] == "production"))
        return 0
    except BaseException as error:
        report["error"] = {"type": type(error).__name__, "message": str(error)}
        raise
    finally:
        controller.apply_metadata(report)
        transfer.write_json(OUT / "release-native-result.json", report)
        transfer.write_json(OUT / "result.json", report)


def native_evidence_paths():
    paths = []
    for path in sorted((ROOT / "build/artifacts").rglob("*")):
        if not path.is_file():
            continue
        relative = path.relative_to(ROOT / "build/artifacts")
        if any(part.endswith(".xcresult") or part.startswith("visual-") for part in relative.parts):
            continue
        if path.suffix == ".mp4" or path == OUT / "result.json":
            continue
        paths.append(path)
    return paths


def pack_native():
    report = transfer.read_json(OUT / "release-native-result.json")
    require(report.get("status") == "RELEASE_NATIVE_MATRIX_ONLY_PASS"
            and report.get("full_release_acceptance") is False, "Native stage is incomplete")
    manifest = module("runtime27-release.py")["load_manifest"](ROOT)
    strict_native_configurations(report, manifest)
    transfer.verify_products(ROOT, transfer.read_json(ROOT / "build/runtime27-handoff/imported-build.json"))
    receipt = transfer.pack(ROOT, ROOT / "build/runtime27-handoff/native", "native", native_evidence_paths(),
                            transfer.context(ROOT), report["status"])
    github_output("archive_sha256", receipt["archive"]["sha256"])
    return receipt


def verify_restored_input_context(build, restored, original_sources, restored_sources):
    require(restored.get("status") == "PREPARED_ORIGINAL_INPUTS_ONLY"
            and restored.get("app_build_executed") is False, "Unexpected Debug rebuild during Release restoration")
    for key in ["checkout_sha", "application_source_sha", "application_trees", "validator_sha256",
                "inputs_sha256", "workflow_sha256", "package_pins", "package_resolved_sha256",
                "hanlin_gitlink", "hanlin_sdk_source", "actual_package_checkouts", "actual_source_inputs_verified",
                "native_context", "resource_inputs"]:
        require(key in build and restored.get(key) == build[key], "Restored original input differs: " + key)
    require(original_sources and restored_sources == original_sources,
            "Prepared actual source bytes differ from the accepted Debug compilation")


def production_stage(args, run_logged, controller):
    import_handoff("build", args.build_artifact, args.build_archive_sha, "production", run_logged, controller)
    import_handoff("native", args.native_artifact, args.native_archive_sha, "production", run_logged, controller)
    build_receipt = transfer.read_json(ROOT / "build/runtime27-handoff/imported-build.json")
    report, build = expected_build_report()
    native = transfer.read_json(OUT / "release-native-result.json")
    require(native.get("status") == "RELEASE_NATIVE_MATRIX_ONLY_PASS"
            and native.get("full_release_acceptance") is False
            and native.get("checkout_sha") == report["checkout_sha"]
            and native.get("built_binary_sha256") == report.get("built_binary_sha256"),
            "Production requires the successful exact-products native predecessor")
    report = copy.deepcopy(report)
    report.update(status="FAIL", release_stage="production", full_release_acceptance=False,
                  executed_ui_pass=None, executed_ui_fail=None, executed_ui_skip=None, ui_not_run=None)
    try:
        set_release_environment()
        release = module("runtime27-release.py")
        manifest = release["load_manifest"](ROOT)
        report["native_predecessor_verification"] = strict_native_configurations(native, manifest)
        report["original_products_before_restoration"] = transfer.verify_products(ROOT, build_receipt)
        # Rehydrate source/dependencies using the original helper sequence only.
        # The first job's Debug products and hq-stage2 proofs are never replaced.
        lock = ROOT / "build/hq-stage2/resolved-Podfile.lock"
        destination = ROOT / "Podfile.lock"
        require(not destination.is_symlink()
                and (not destination.exists() or transfer.digest(destination) == transfer.digest(lock)),
                "Refusing to replace a different native lock")
        shutil.copyfile(lock, destination)
        prepared = OUT / "production-inputs"
        code = run_logged([sys.executable, "Scripts/CI/hq-stage2-focused-apple.py", "--build-for-testing",
                           "--prepare-inputs-only", "--preparation-evidence-dir", str(prepared.relative_to(ROOT))],
                          "release-input-restoration.log", INPUT_RESTORATION_BUDGET_SECONDS,
                          interrupt_controller=controller)
        require(code == 0, "Original Release input restoration failed")
        restored = transfer.read_json(prepared / "result.json")
        verify_restored_input_context(build, restored,
                                      transfer.read_json(ROOT / "build/hq-stage2/actual-source-inputs.json"),
                                      transfer.read_json(prepared / "actual-source-inputs.json"))
        report["original_products_after_restoration"] = transfer.verify_products(ROOT, build_receipt)
        report["input_restoration"] = {"status": "EXACT_ORIGINAL_INPUTS_WITHOUT_DEBUG_REBUILD",
                                       "report_sha256": transfer.digest(prepared / "result.json")}
        # The helper's subprocess environment does not propagate to this parent.
        # Retain its original fixed React build environment for the Release child.
        upstream = ROOT / "Vendor/SefariaMobile/Upstream"
        os.environ.update(PROJECT_ROOT=str(upstream), NODE_PATH=str(upstream / "node_modules"),
                          RCT_NO_LAUNCH_PACKAGER="1", SKIP_BUNDLING="1", FAIL_ON_MISSING_BUNDLE="1",
                          GOOGLE_SERVICES_FILE=str(ROOT / "Source/GoogleService-Info.plist"))
        # The original runner still independently requires the complete native
        # matrix, provisions via the exact Debug app, and upgrades its same UDID
        # and ordinary data container to the freshly built Release binary.
        code = run_logged([sys.executable, "Scripts/CI/run-faithful-production-release.py"],
                          "release-production-driver.log", PRODUCTION_BUDGET_SECONDS,
                          interrupt_controller=controller)
        require(code == 0, "Original full-corpus Release acceptance failed")
        report["original_products_after_production"] = transfer.verify_products(ROOT, build_receipt)
        release_bundle = ROOT / "build/ReleaseDerivedData/Build/Products/Release-iphonesimulator/Maktabah.app/main.jsbundle"
        require(transfer.digest(release_bundle) == build["resource_inputs"]["jsbundle_sha256"],
                "Release bundled a different original Embedded resource")
        release["reverify_original_inputs"](ROOT, report, OUT / "after-release-inputs")
        report["release_stage"] = "complete"
        return release["complete_release"](ROOT, report, manifest,
                                           transfer.digest(ROOT / "Scripts/CI/runtime27-release-manifest.json"), build)
    except BaseException as error:
        report["error"] = {"type": type(error).__name__, "message": str(error)}
        raise
    finally:
        controller.apply_metadata(report)
        transfer.write_json(OUT / "release-production-result.json", report)
        transfer.write_json(OUT / "result.json", report)


def import_handoff(kind, artifact, archive_sha, consumer, run_logged, controller):
    require(artifact and archive_sha, "Missing successful predecessor outputs")
    code = run_logged([sys.executable, str(SELF), "import", "--kind", kind, "--artifact", str(artifact),
                       "--archive-sha", archive_sha, "--consumer", consumer],
                      f"release-{kind}-handoff-import-{consumer}.log", 1200, interrupt_controller=controller)
    require(code == 0, "Authenticated predecessor handoff failed")


def github_output(key, value):
    require(os.environ.get("GITHUB_OUTPUT"), "Missing GitHub output destination")
    with Path(os.environ["GITHUB_OUTPUT"]).open("a", encoding="utf-8") as stream:
        stream.write(key + "=" + value + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", choices=["pack-build", "import", "native", "pack-native", "production"])
    parser.add_argument("--kind", choices=sorted(transfer.KINDS))
    parser.add_argument("--artifact", type=int)
    parser.add_argument("--archive-sha")
    parser.add_argument("--consumer", choices=["native", "production"])
    parser.add_argument("--build-artifact", type=int)
    parser.add_argument("--build-archive-sha")
    parser.add_argument("--native-artifact", type=int)
    parser.add_argument("--native-archive-sha")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    if args.stage == "import":
        transfer.fetch(ROOT, args.kind, args.artifact, args.archive_sha, args.consumer)
        return 0
    if args.stage == "pack-build":
        pack_build()
        return 0
    if args.stage == "pack-native":
        pack_native()
        return 0
    controller = runtime27_interruption.InterruptController().install()
    runtime = module("runtime27.py")
    try:
        if args.stage == "native":
            return native_stage(args, runtime["run_logged"], controller)
        return production_stage(args, runtime["run_logged"], controller)
    except BaseException as error:
        if isinstance(error, KeyboardInterrupt):
            controller.mark_interrupted(error)
        failure = {"status": "FAIL", "release_stage": args.stage, "full_release_acceptance": False,
                   "checkout_sha": os.environ.get("EXPECTED_CHECKOUT_SHA"),
                   "error": {"type": type(error).__name__, "message": str(error)},
                   "acceptance_effect": "NONE; retain raw observations, do not infer unverified test counts"}
        controller.apply_metadata(failure)
        transfer.write_json(OUT / ("release-" + args.stage + "-failure.json"), failure)
        # Import can fail before the stage has a complete source-bound report.
        # Never leave an inherited build PASS in the consumer's result slot.
        stage_result = OUT / ("release-" + args.stage + "-result.json")
        if not stage_result.exists():
            transfer.write_json(stage_result, failure)
            transfer.write_json(OUT / "result.json", failure)
        raise
    finally:
        controller.restore()


if __name__ == "__main__":
    raise SystemExit(main())

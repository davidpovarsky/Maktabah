#!/usr/bin/env python3
"""Use the existing Embedded preparation for normal iOS builds, without replacing their same-run engines/packages."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build/normal-ios-embedded"
INPUTS = ROOT / "Scripts/CI/hq-stage2-focused-apple.inputs.json"
PROJECT_LOCK = "Maktabah.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
WORKSPACE_LOCK = "Maktabah.xcworkspace/xcshareddata/swiftpm/Package.resolved"
RESOURCE_NAME = "sefaria-embedded-validation-manifests"
UPSTREAM = "Vendor/SefariaMobile/Upstream"
RESOURCE_ROOT = "Vendor/SefariaMobile"
OVERLAY = RESOURCE_ROOT + "/Integration/JS/chavrusaRPCFacade.js"
ENV_KEYS = ("PROJECT_ROOT", "NODE_PATH", "RCT_NO_LAUNCH_PACKAGER", "SKIP_BUNDLING",
            "FAIL_ON_MISSING_BUNDLE", "GOOGLE_SERVICES_FILE")


def original_driver():
    path = ROOT / "Scripts/CI/hq-stage2-focused-apple.py"
    spec = importlib.util.spec_from_file_location("original_focused_ios", path)
    driver = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(driver)
    driver.OUT = OUT
    return driver


def resource_only_config(driver, config):
    """The normal workflow already restored its own engines and SwiftPM sources.

    Reuse only the focused driver's pinned resource archive/metadata restoration;
    do not run its separate framework preflight or restore historical engines/packages.
    """
    matches = [item for item in config["artifacts"] if item["name"] == RESOURCE_NAME]
    driver.require(len(matches) == 1, "Expected exactly one pinned Embedded resource archive")
    item = matches[0]
    driver.require("tar" not in item and "destination" not in item
                   and type(item.get("id")) is int and item["id"] > 0
                   and re.fullmatch(r"[0-9a-f]{64}", item.get("sha256", "")),
                   "Resource-only restoration cannot restore a framework or SwiftPM archive")
    return {**config, "artifacts": [dict(item)]}


def ensure_resource_producer(driver, config, report):
    producer = config["resource_producer_sha"]
    driver.require(re.fullmatch(r"[0-9a-f]{40}", producer), "Invalid pinned resource producer")
    present = subprocess.run(["git", "cat-file", "-e", producer + "^{commit}"], cwd=ROOT,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
    if not present:
        # Default Actions checkout is shallow. Fetch just this immutable source
        # comparison, never a moving branch or the repository's full history.
        driver.logged(["git", "fetch", "--no-tags", "--depth", "1", "origin", producer],
                      "resource-producer-source.log", report)
        driver.require(driver.capture("git", "rev-parse", "FETCH_HEAD") == producer,
                       "Fetched resource source differs from the pinned producer")
    driver.require(driver.capture("git", "rev-parse", producer + "^{commit}") == producer,
                   "Missing exact resource producer commit")


def embedded_source_plan(driver, config):
    """Same Sefaria source/overlay contract as the original focused preflight."""
    driver.require(driver.capture("git", "rev-parse", "HEAD:" + UPSTREAM) == config["sefaria_gitlink"],
                   "Sefaria pin drift")
    tree = driver.capture("git", "rev-parse", "HEAD:" + RESOURCE_ROOT)
    overlays = config.get("embedded_js_overlay_paths", [])
    if overlays:
        driver.require(overlays == [OVERLAY], "Unreviewed Embedded resource overlay")
        changed = driver.capture("git", "diff", "--name-only", config["resource_producer_sha"],
                                 "HEAD", "--", RESOURCE_ROOT).splitlines()
        driver.require(changed == overlays, "Embedded overlay changed unrelated resource sources")
        return {"mode": "REBUILD_EXACT_REVIEWED_JS", "overlay_paths": overlays, "source_tree": tree}
    driver.require(driver.capture("git", "rev-parse", config["resource_producer_sha"] + ":" + RESOURCE_ROOT) == tree,
                   "Bundled JS producer source differs")
    return {"mode": "UNCHANGED_PINNED_BUNDLE", "overlay_paths": [], "source_tree": tree}


def verify_locks(driver, report):
    native = report["native_context"]
    for relative, expected in [(PROJECT_LOCK, report["package_resolved_sha256"]),
                               ("Podfile", native["podfile_sha256"]),
                               ("Podfile.lock", native["pod_lock_sha256"]),
                               ("Maktabah.xcodeproj/project.pbxproj", native["generated_project_sha256"]),
                               ("Maktabah.xcworkspace/contents.xcworkspacedata", native["workspace_sha256"]),
                               (UPSTREAM + "/package-lock.json", native["npm_lock_sha256"])]:
        driver.require(driver.digest(ROOT / relative) == expected, "Build input lock changed: " + relative)
    driver.require(driver.pins(ROOT / WORKSPACE_LOCK) == report["package_pins"], "Workspace package revisions changed")
    driver.require(driver.capture("git", "-C", str(ROOT / UPSTREAM), "rev-parse", "HEAD") == native["gitlink"],
                   "Original React upstream changed")


def export_environment(driver, destination):
    values = {key: os.environ[key] for key in ENV_KEYS}
    driver.require(all("\n" not in value and "\r" not in value for value in values.values()),
                   "Unsafe multiline build environment")
    with destination.open("a", encoding="utf-8") as output:
        for key, value in values.items():
            output.write(key + "=" + value + "\n")


def prepare(driver, config, report, github_env):
    checkout = driver.capture("git", "rev-parse", "HEAD")
    driver.require(not os.environ.get("GITHUB_SHA") or os.environ["GITHUB_SHA"] == checkout, "Wrong workflow checkout")
    report.update(checkout_sha=checkout, inputs_sha256=driver.digest(INPUTS),
                  original_driver_sha256=driver.digest(ROOT / "Scripts/CI/hq-stage2-focused-apple.py"),
                  preparation_scope="ORIGINAL_EMBEDDED_ONLY_SAME_RUN_ENGINE_AND_SWIFTPM_INPUTS_RETAINED",
                  package_resolved_sha256=driver.digest(ROOT / PROJECT_LOCK), package_pins=driver.pins(ROOT / PROJECT_LOCK))
    driver.require(driver.capture("git", "rev-parse", "HEAD:Vendor/HanlinSDK") == config["hanlin_gitlink"],
                   "Original Hanlin pin differs from preparation inputs")
    report["hanlin_sdk_source"] = json.loads((ROOT / "build/logs/hanlin-sdk-source.json").read_text())
    selected = resource_only_config(driver, config)
    ensure_resource_producer(driver, config, report)
    report["embedded_bundle_build"] = embedded_source_plan(driver, config)
    driver.prepare_react_sources(config, report)
    driver.restore(selected, report)
    driver.prepare_matching_embedded_bundle(config, report)
    driver.install_real_pods(report)
    help_result = subprocess.run(["xcodebuild", "-help"], cwd=ROOT, stdout=subprocess.PIPE,
                                 stderr=subprocess.STDOUT, text=True)
    driver.require("-onlyUsePackageVersionsFromResolvedFile" in help_result.stdout,
                   "Installed Xcode lacks pinned-only package resolution")
    driver.logged(["xcodebuild", "-resolvePackageDependencies", "-workspace", "Maktabah.xcworkspace",
                   "-scheme", "Maktabah-iOS", "-clonedSourcePackagesDirPath", "build/SourcePackages",
                   "-onlyUsePackageVersionsFromResolvedFile"], "workspace-resolve-packages.log", report)
    verify_locks(driver, report)
    driver.verify_actual_sources(report)
    driver.prepare_original_hanlin(config, report, verify_only=True)
    shutil.copyfile(ROOT / PROJECT_LOCK, OUT / "resolved-Package.resolved")
    shutil.copyfile(ROOT / WORKSPACE_LOCK, OUT / "workspace-Package.resolved")
    export_environment(driver, github_env)
    report.update(status="PREPARED_ORIGINAL_WORKSPACE_ONLY", app_build_executed=False, runtime="NOT_RUN")


def verify_app(driver, report, app):
    driver.require(report.get("status") == "PREPARED_ORIGINAL_WORKSPACE_ONLY", "Missing successful workspace preparation")
    driver.require(driver.capture("git", "rev-parse", "HEAD") == report["checkout_sha"], "Checkout changed after preparation")
    driver.require(driver.digest(INPUTS) == report["inputs_sha256"], "Pinned inputs changed after preparation")
    driver.require(driver.digest(ROOT / "Scripts/CI/hq-stage2-focused-apple.py") == report["original_driver_sha256"],
                   "Original preparation driver changed")
    bundle = app / "main.jsbundle"
    driver.require(bundle.is_file(), "Built app has no original Embedded bundle")
    driver.require(driver.digest(bundle) == report["resource_inputs"]["jsbundle_sha256"],
                   "Built app copied a nonmatching Embedded bundle")
    verify_locks(driver, report)
    driver.verify_actual_sources(report)
    driver.prepare_original_hanlin(json.loads(INPUTS.read_text()), report, verify_only=True)
    report.update(status="BUILT_APP_ORIGINAL_INPUTS_VERIFIED", app_build_executed=True, runtime="NOT_RUN",
                  built_app_path=str(app.relative_to(ROOT)), built_app_embedded_bundle_sha256=driver.digest(bundle))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify-app", type=Path)
    parser.add_argument("--github-env", type=Path)
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    driver = original_driver()
    report_path = OUT / ("verify-app.json" if args.verify_app else "preparation.json")
    report = {"status": "FAIL", "app_build_executed": False, "runtime": "NOT_RUN"}
    try:
        if args.verify_app:
            app = args.verify_app.resolve()
            driver.require(app.is_relative_to((ROOT / "build").resolve()) and app.suffix == ".app" and app.is_dir(),
                           "Expected the actual normal workflow app under build/")
            report = json.loads((OUT / "preparation.json").read_text())
            verify_app(driver, report, app)
        else:
            driver.require(args.github_env is not None, "An explicit GITHUB_ENV destination is required")
            prepare(driver, json.loads(INPUTS.read_text()), report, args.github_env)
        return 0
    except Exception as error:
        report.update(status="FAIL", error=str(error))
        print(str(error), file=sys.stderr)
        return 1
    finally:
        report_path.write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps({key: report.get(key) for key in ("status", "checkout_sha", "error")}), flush=True)


if __name__ == "__main__":
    raise SystemExit(main())

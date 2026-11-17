#!/usr/bin/env python3
"""One real unsigned app build; immutable prebuilt inputs, no data/runtime stages."""
import argparse
import hashlib
import inspect
import json
import os
from pathlib import Path, PurePosixPath
import plistlib
import re
import shutil
import subprocess
import sys
import tarfile
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build/hq-stage2"
INPUTS = Path(__file__).with_suffix(".inputs.json")


def capture(*args):
    return subprocess.check_output(args, cwd=ROOT, text=True, encoding="utf-8").strip()


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def pins(path):
    return {p["identity"]: p["state"]["revision"] for p in json.loads(path.read_text())["pins"]}


def zayit_build_plan(config):
    """Only the reviewed downstream lexical fix may replace a baseline binary."""
    rebuild = config.get("rebuild_zayit_framework", False)
    require(type(rebuild) is bool, "Zayit rebuild mode must be boolean")
    root = "Vendor/ZayitSearchPort/Rust"
    changed = capture("git", "diff", "--name-only", config["engine_producer_sha"], "HEAD", "--", root).splitlines()
    compiled = [path for path in changed if not path.startswith(root + "/tests/")]
    if rebuild:
        require(compiled == [root + "/src/magic_dictionary_index.rs"], "Unreviewed Zayit production source overlay")
    else:
        require(not compiled, "Changed Zayit production source requires a matching rebuilt framework")
    script = "Vendor/ZayitSearchPort/Scripts/build-ios-xcframework.sh"
    require(not capture("git", "diff", "--name-only", config["engine_producer_sha"], "HEAD", "--", script),
            "Unreviewed Zayit build script change")
    return {"mode": "REBUILD_EXACT_REVIEWED_RUST" if rebuild else "UNCHANGED_PRODUCTION_PREBUILT",
            "source_tree": capture("git", "rev-parse", "HEAD:" + root),
            "baseline_producer_sha": config["engine_producer_sha"], "changed_paths": changed,
            "build_script": script, "build_script_git_blob": capture("git", "rev-parse", "HEAD:" + script)}


def preflight(config):
    result = {"checkout_sha": capture("git", "rev-parse", "HEAD"), "application_source_sha": config["application_source_sha"],
              "validator_sha256": digest(Path(__file__)), "inputs_sha256": digest(INPUTS),
              "workflow_sha256": digest(ROOT / ".github/workflows/sefaria-embedded-validation.yml"),
              "project_sha256": digest(ROOT / "Maktabah.xcodeproj/project.pbxproj"), "application_trees": {}}
    expected = os.environ.get("EXPECTED_CHECKOUT_SHA")
    require(not expected or result["checkout_sha"] == expected, "Wrong immutable checkout")
    for path, expected_tree in config["application_trees"].items():
        actual = capture("git", "rev-parse", "HEAD:" + path)
        require(actual == expected_tree, "Application tree drift: " + path)
        result["application_trees"][path] = actual
    for path, expected_tree in config["engine_trees"].items():
        require(capture("git", "rev-parse", config["engine_producer_sha"] + ":" + path) == expected_tree,
                "Prebuilt engine producer source differs: " + path)
        if path != "Vendor/ZayitSearchPort/Rust":
            require(capture("git", "rev-parse", "HEAD:" + path) == expected_tree,
                    "Unreviewed prebuilt engine source drift: " + path)
    result["zayit_framework"] = zayit_build_plan(config)
    require(capture("git", "rev-parse", "HEAD:Vendor/SefariaMobile/Upstream") == config["sefaria_gitlink"], "Sefaria pin drift")
    resource_tree = capture("git", "rev-parse", "HEAD:Vendor/SefariaMobile")
    overlays = config.get("embedded_js_overlay_paths", [])
    if overlays:
        # The old immutable resource artifact remains a verified baseline, not
        # a matching bundle for new JS. Rebuild only this reviewed downstream
        # facade overlay using the unchanged pinned upstream and npm lock.
        require(overlays == ["Vendor/SefariaMobile/Integration/JS/chavrusaRPCFacade.js"], "Unreviewed Embedded resource overlay")
        changed = capture("git", "diff", "--name-only", config["resource_producer_sha"], "HEAD", "--", "Vendor/SefariaMobile").splitlines()
        require(changed == overlays, "Embedded overlay changed unrelated resource sources")
        result["embedded_bundle_build"] = {"mode": "REBUILD_EXACT_REVIEWED_JS", "overlay_paths": overlays, "source_tree": resource_tree}
    else:
        require(capture("git", "rev-parse", config["resource_producer_sha"] + ":Vendor/SefariaMobile") ==
                resource_tree, "Bundled JS producer source differs")
    lock = ROOT / "Maktabah.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
    result["package_resolved_sha256"] = digest(lock)
    result["package_pins"] = pins(lock)
    return result


def checked_path(base, name):
    part = PurePosixPath(name)
    require(not part.is_absolute() and ".." not in part.parts, "Unsafe input archive member")
    target = (base / name).resolve()
    require(target.is_relative_to(base.resolve()), "Archive escaped validation workspace")
    return target


def restore(config, report):
    cache = OUT / "inputs"
    cache.mkdir(parents=True, exist_ok=True)
    report["artifact_inputs"] = []
    for item in config["artifacts"]:
        archive = cache / (str(item["id"]) + ".zip")
        with archive.open("wb") as output:
            subprocess.run(["gh", "api", f"repos/davidpovarsky/Maktabah/actions/artifacts/{item['id']}/zip"],
                           cwd=ROOT, stdout=output, check=True, timeout=600)
        actual = digest(archive)
        require(actual == item["sha256"], "Artifact ZIP digest mismatch: " + item["name"])
        role = ("BASELINE_ONLY_REBUILT_BEFORE_LINK" if item.get("destination") == "Vendor/ZayitSearchPort/build"
                and report["zayit_framework"]["mode"] == "REBUILD_EXACT_REVIEWED_RUST" else "PINNED_INPUT")
        report["artifact_inputs"].append({**item, "verified_sha256": actual, "role": role})
        with zipfile.ZipFile(archive) as zipped:
            if "tar" in item:
                matches = [n for n in zipped.namelist() if PurePosixPath(n).name == item["tar"]]
                require(len(matches) == 1, "Ambiguous prebuilt archive payload")
                payload = cache / item["tar"]
                with zipped.open(matches[0]) as src, payload.open("wb") as dst:
                    shutil.copyfileobj(src, dst)
                destination = ROOT / item["destination"]
                destination.mkdir(parents=True, exist_ok=True)
                with tarfile.open(payload) as packed:
                    for member in packed.getmembers():
                        checked_path(destination, member.name)
                        require(not member.isdev(), "Device member in input archive")
                    require("filter" in inspect.signature(packed.extractall).parameters, "Python requires safe tar extraction support")
                    packed.extractall(destination, filter="data")
            else:
                for entry in zipped.infolist():
                    if entry.is_dir() or not entry.filename.startswith("build/jsbundle/"):
                        continue
                    target = checked_path(ROOT, entry.filename)
                    target.parent.mkdir(parents=True, exist_ok=True)
                    with zipped.open(entry) as src, target.open("wb") as dst:
                        shutil.copyfileobj(src, dst)
                require(digest(ROOT / "build/jsbundle/main.jsbundle") == config["resource_bundle_sha256"], "Real JS bundle digest mismatch")
    for name, entry in config["resources"].items():
        require(PurePosixPath(name).parts[0] == "sources", "Unexpected upstream metadata resource")
        suffix = PurePosixPath(name).name
        target = checked_path(ROOT / "Vendor/SefariaMobile/Upstream/ios/sources", suffix)
        target.parent.mkdir(parents=True, exist_ok=True)
        url = f"https://raw.githubusercontent.com/Sefaria/Sefaria-Mobile/{config['sefaria_gitlink']}/ios/sources/{suffix}"
        with urllib.request.urlopen(url, timeout=120) as src, target.open("wb") as dst:
            shutil.copyfileobj(src, dst)
        require(target.stat().st_size == entry["size"] and digest(target) == entry["sha256"], "Pinned upstream metadata digest mismatch: " + name)
    report["resource_inputs"] = {"gitlink": config["sefaria_gitlink"], "json_files": config["resources"],
                                 "jsbundle_sha256": config["resource_bundle_sha256"], "no_book_database_payload": True}


def logged(command, filename, report, cwd=None):
    report.setdefault("commands", []).append(command)
    path = OUT / filename
    with path.open("w", encoding="utf-8") as log:
        result = subprocess.run(command, cwd=cwd or ROOT, stdout=log, stderr=subprocess.STDOUT)
    print(f"command_exit={result.returncode} log={path.relative_to(ROOT)}", flush=True)
    print("\n".join(path.read_text(errors="replace").splitlines()[-100:]), flush=True)
    require(result.returncode == 0, "Focused command failed; inspect " + str(path.relative_to(ROOT)))


def rebuild_matching_zayit_framework(report):
    plan = report["zayit_framework"]
    if plan["mode"] != "REBUILD_EXACT_REVIEWED_RUST":
        return
    plan["rustc"] = capture("rustc", "-Vv")
    plan["cargo"] = capture("cargo", "-V")
    plan["rustup"] = capture("rustup", "--version")
    plan["free_bytes_before"] = shutil.disk_usage(ROOT).free
    lock = ROOT / "Vendor/ZayitSearchPort/Rust/Cargo.lock"
    lock_before = digest(lock)
    build = checked_path(ROOT / "Vendor/ZayitSearchPort", "build")
    baseline = checked_path(OUT, "zayit-prebuilt-baseline")
    require(build.is_dir() and not build.is_symlink() and not baseline.exists(), "Expected fresh Zayit baseline staging")
    # Preserve the verified old framework. The unchanged production script owns
    # a fresh disposable output path and must not inherit the baseline library.
    build.rename(baseline)
    plan["preserved_baseline"] = str(baseline.relative_to(ROOT))
    logged(["cargo", "metadata", "--locked", "--no-deps", "--format-version", "1", "--manifest-path",
            "Vendor/ZayitSearchPort/Rust/Cargo.toml"], "zayit-locked-metadata.log", report)
    logged(["bash", plan["build_script"]], "matching-zayit-framework.log", report)
    require(digest(lock) == lock_before, "Zayit build changed the committed dependency lock")
    require(capture("git", "rev-parse", "HEAD:Vendor/ZayitSearchPort/Rust") == plan["source_tree"], "Zayit build source drift")
    framework = build / "MaktabahZayitSearch.xcframework"
    require(framework.is_dir() and (framework / "Info.plist").is_file(), "Matching Zayit framework was not produced")
    files = sorted(path for path in framework.rglob("*") if path.is_file())
    require(sum(path.suffix == ".a" for path in files) == 2 and not any(path.is_symlink() for path in framework.rglob("*")),
            "Unexpected matching Zayit framework layout")
    plan["built_files_sha256"] = {str(path.relative_to(ROOT)): digest(path) for path in files}
    plan["cargo_lock_sha256"] = lock_before
    # Retain the actual newly built slices for later source-qualified reuse.
    retained = checked_path(OUT, "rebuilt-zayit")
    retained.mkdir()
    archive = retained / "MaktabahZayitSearch.xcframework.tar"
    with tarfile.open(archive, "w") as packed:
        packed.add(framework, arcname=framework.name)
    plan["retained_archive"] = str(archive.relative_to(ROOT))
    plan["retained_archive_sha256"] = digest(archive)
    plan["status"] = "BUILT_FROM_EXACT_REVIEWED_SOURCE_NOT_YET_APP_ACCEPTANCE"


def verify_selected_zayit_files(report):
    for name, expected in report["zayit_framework"].get("built_files_sha256", {}).items():
        require(digest(ROOT / name) == expected, "Selected Zayit framework changed before/after app link: " + name)


def prepare_react_sources(config, report):
    """Restore the real pinned native sources required by the existing Podfile."""
    vendor = ROOT / "Vendor/SefariaMobile/Upstream"
    logged(["git", "submodule", "update", "--init", "--depth", "1", "Vendor/SefariaMobile/Upstream"], "react-source-checkout.log", report)
    require(capture("git", "-C", str(vendor), "rev-parse", "HEAD") == config["sefaria_gitlink"], "React upstream checkout drift")
    npm_lock = vendor / "package-lock.json"
    before = digest(npm_lock)
    report["native_context"] = {"gitlink": config["sefaria_gitlink"], "npm_lock_sha256": before,
                                "podfile_sha256": digest(ROOT / "Podfile"), "node": capture("node", "--version"),
                                "cocoapods": capture("pod", "--version"), "ruby": capture("ruby", "--version")}
    logged([sys.executable, "Scripts/CI/prepare-pinned-sharp-libvips.py"], "pinned-sharp-inputs.log", report)
    logged(["npm", "ci", "--legacy-peer-deps"], "npm-ci.log", report, cwd=vendor)
    require(digest(npm_lock) == before, "npm changed pinned source lock")
    os.environ.update(PROJECT_ROOT=str(vendor), NODE_PATH=str(vendor / "node_modules"),
                      RCT_NO_LAUNCH_PACKAGER="1", SKIP_BUNDLING="1", FAIL_ON_MISSING_BUNDLE="1",
                      GOOGLE_SERVICES_FILE=str(ROOT / "Source/GoogleService-Info.plist"))
    for link, target in [(ROOT / "node_modules", vendor / "node_modules"),
                         (ROOT.parent / "node_modules", vendor / "node_modules"),
                         *[(ROOT / name, vendor / name) for name in ["package.json", "app.json", "metro.config.js", "babel.config.js"]]]:
        require(target.exists(), "Missing real React build input: " + str(target))
        if link.exists() or link.is_symlink():
            require(link.is_symlink() and link.resolve() == target.resolve(), "Occupied native input path: " + str(link))
        else:
            link.symlink_to(target, target_is_directory=target.is_dir())
    for destination in [ROOT / "GoogleService-Info.plist", vendor / "ios/GoogleService-Info.plist"]:
        shutil.copyfile(ROOT / "Source/GoogleService-Info.plist", destination)
    logged(["chmod", "-R", "+x", str(vendor / "node_modules/.bin"), str(vendor / "node_modules/expo/bin")], "native-script-permissions.log", report)


def install_real_pods(report):
    logged(["pod", "install"], "pod-install.log", report)
    require((ROOT / "Maktabah.xcworkspace/contents.xcworkspacedata").is_file(), "Real Pods workspace missing")
    require((ROOT / "Pods/Headers/Public/React-Core/React/RCTBridgeModule.h").is_file()
            or any(p.is_file() for p in (ROOT / "Pods").rglob("RCTBridgeModule.h")), "Real React header was not restored")
    report["native_context"]["pod_lock_sha256"] = digest(ROOT / "Podfile.lock")
    report["native_context"]["generated_project_sha256"] = digest(ROOT / "Maktabah.xcodeproj/project.pbxproj")
    shutil.copyfile(ROOT / "Maktabah.xcodeproj/project.pbxproj", OUT / "generated-Maktabah-project.pbxproj")
    report["native_context"]["workspace_sha256"] = digest(ROOT / "Maktabah.xcworkspace/contents.xcworkspacedata")
    report["native_context"]["generated_expo_providers"] = []
    for provider in (ROOT / "Pods").rglob("ExpoModulesProvider.swift"):
        report["native_context"]["generated_expo_providers"].append({"path": str(provider.relative_to(ROOT)), "sha256": digest(provider)})
        require(len(report["native_context"]["generated_expo_providers"]) == 1, "Ambiguous generated Expo provider")
        shutil.copyfile(provider, OUT / "ExpoModulesProvider.swift")
    (OUT / "generated-pods-project.diff").write_text(capture("git", "diff", "--", "Maktabah.xcodeproj/project.pbxproj") + "\n")
    shutil.copyfile(ROOT / "Podfile.lock", OUT / "resolved-Podfile.lock")
    # The generated workspace has its own SwiftPM lock location. Restore the
    # exact committed project lock instead of allowing cached revisions to win.
    committed_lock = ROOT / "Maktabah.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
    workspace_lock = ROOT / "Maktabah.xcworkspace/xcshareddata/swiftpm/Package.resolved"
    workspace_lock.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(committed_lock, workspace_lock)
    report["native_context"]["staged_workspace_package_lock_sha256"] = digest(workspace_lock)
    require(pins(workspace_lock) == report["package_pins"], "Generated workspace pin drift")


def prepare_matching_embedded_bundle(config, report):
    if not config.get("embedded_js_overlay_paths"):
        return
    vendor = ROOT / "Vendor/SefariaMobile/Upstream"
    bundle = ROOT / "build/jsbundle/main.jsbundle"
    historical = digest(bundle)
    logged(["npx", "--no-install", "react-native", "bundle",
            "--config", "../Integration/metro.config.embedded.js", "--platform", "ios", "--dev", "false",
            "--entry-file", "../Integration/index.embedded.js", "--bundle-output", str(bundle),
            "--assets-dest", str(bundle.parent)], "matching-embedded-bundle.log", report, cwd=vendor)
    require(bundle.is_file() and bundle.stat().st_size > 0, "Matching Metro bundle is missing or empty")
    require(capture("git", "rev-parse", "HEAD:Vendor/SefariaMobile") == report["embedded_bundle_build"]["source_tree"], "Embedded source changed during bundling")
    report["embedded_bundle_build"].update(historical_bundle_sha256=historical, bundle_sha256=digest(bundle),
        overlay_source_sha256={path: digest(ROOT / path) for path in config["embedded_js_overlay_paths"]})
    report["resource_inputs"]["jsbundle_sha256"] = digest(bundle)


def verify_actual_sources(report):
    entries = subprocess.check_output(["git", "ls-tree", "-r", "-z", "HEAD", "--", "Source", "Vendor"], cwd=ROOT)
    expected = {}
    for entry in entries.split(b"\0"):
        if not entry:
            continue
        meta, path = entry.split(b"\t", 1)
        if meta.split()[1] == b"blob":
            expected[path.decode()] = meta.split()[2].decode()
    paths = list(expected)
    actual = subprocess.check_output(["git", "hash-object", "--no-filters", "--stdin-paths"], cwd=ROOT,
                                     input=("\n".join(paths) + "\n").encode()).decode().splitlines()
    require(len(actual) == len(paths), "Actual source hash inventory incomplete")
    mismatches = [path for path, blob in zip(paths, actual) if blob != expected[path]]
    if "Source/PrivacyInfo.xcprivacy" in mismatches:
        audit_generated_privacy(report, expected["Source/PrivacyInfo.xcprivacy"])
        mismatches.remove("Source/PrivacyInfo.xcprivacy")
    require(not mismatches, "Dependency setup changed tracked app input: " + ", ".join(mismatches[:10]))
    report["actual_source_inputs_verified"] = len(paths)
    (OUT / "actual-source-inputs.json").write_text(json.dumps(dict(zip(paths, actual)), indent=2) + "\n")
    checkouts = ROOT / "build/SourcePackages/checkouts"
    folders = {p.name.casefold(): p for p in checkouts.iterdir() if p.is_dir()}
    report["actual_package_checkouts"] = {}
    for identity, revision in report["package_pins"].items():
        require(identity.casefold() in folders, "Pinned package checkout missing: " + identity)
        folder = folders[identity.casefold()]
        head = capture("git", "-C", str(folder), "rev-parse", "HEAD")
        dirty = capture("git", "-C", str(folder), "status", "--porcelain")
        require(head == revision and not dirty, "Pinned package source differs/dirty: " + identity)
        report["actual_package_checkouts"][identity] = {"head": head, "status": "CLEAN"}


def privacy_categories(document):
    result = {}
    for row in document.get("NSPrivacyAccessedAPITypes", []):
        require(set(row) == {"NSPrivacyAccessedAPIType", "NSPrivacyAccessedAPITypeReasons"}, "Unexpected generated privacy schema")
        category, reasons = row["NSPrivacyAccessedAPIType"], row["NSPrivacyAccessedAPITypeReasons"]
        require(isinstance(category, str) and category.startswith("NSPrivacyAccessedAPICategory"), "Invalid privacy API category")
        require(isinstance(reasons, list) and bool(reasons) and all(isinstance(r, str) and re.fullmatch(r"[A-Z0-9]{4}\.[0-9]+", r) for r in reasons), "Invalid privacy reason schema")
        require(category not in result and len(reasons) == len(set(reasons)), "Duplicate generated API category/reason")
        result.setdefault(category, set()).update(reasons)
    return result


def validate_privacy_delta(before, after, evidence):
    require({k: v for k, v in before.items() if k != "NSPrivacyAccessedAPITypes"} ==
            {k: v for k, v in after.items() if k != "NSPrivacyAccessedAPITypes"}, "Setup changed non-API privacy declarations")
    old, new = privacy_categories(before), privacy_categories(after)
    require(all(category in new and reasons <= new[category] for category, reasons in old.items()), "Setup removed original API reasons")
    added = []
    for category, reasons in new.items():
        for reason in sorted(reasons - old.get(category, set())):
            require((category, reason) in evidence, "Generated API reason lacks real dependency provenance: " + category + "/" + reason)
            added.append({"category": category, "reason": reason, "dependency_inputs": evidence[(category, reason)]})
    return added


def audit_generated_privacy(report, original_blob):
    path = "Source/PrivacyInfo.xcprivacy"
    before_bytes = subprocess.check_output(["git", "show", "HEAD:" + path], cwd=ROOT)
    after_bytes = (ROOT / path).read_bytes()
    (OUT / "privacy-original.xcprivacy").write_bytes(before_bytes)
    (OUT / "privacy-generated.xcprivacy").write_bytes(after_bytes)
    (OUT / "generated-privacy.diff").write_text(capture("git", "diff", "--", path) + "\n")
    lock = json.loads(capture("ruby", "-rjson", "-ryaml", "-e",
        "puts JSON.generate(YAML.load_file(ARGV[0], permitted_classes: [Symbol], aliases: true))", "Podfile.lock"))
    roots = [("installed Pods", ROOT / "Pods")]
    for pod, values in lock.get("EXTERNAL SOURCES", {}).items():
        source = values.get(":path") or values.get("path")
        if source:
            root = (ROOT / source).resolve()
            require(root.is_relative_to(ROOT.resolve()), "External Pod source escaped workspace")
            roots.append((pod, root))
    evidence, seen = {}, set()
    for pod, root in roots:
        for candidate in root.rglob("*.xcprivacy"):
            if candidate.resolve() in seen:
                continue
            seen.add(candidate.resolve())
            try:
                declared = privacy_categories(plistlib.loads(candidate.read_bytes()))
            except (ValueError, OSError, RuntimeError):
                continue
            for category, reasons in declared.items():
                for reason in reasons:
                    evidence.setdefault((category, reason), []).append({"pod_source": pod, "path": str(candidate.relative_to(ROOT)), "sha256": digest(candidate)})
    added = validate_privacy_delta(plistlib.loads(before_bytes), plistlib.loads(after_bytes), evidence)
    retained = OUT / "privacy-dependency-inputs"
    retained.mkdir(exist_ok=True)
    for pair in added:
        for item in pair["dependency_inputs"]:
            source = checked_path(ROOT, item["path"])
            require(digest(source) == item["sha256"], "Dependency privacy input changed during audit")
            destination = retained / (item["sha256"] + ".xcprivacy")
            if not destination.exists():
                shutil.copyfile(source, destination)
            item["artifact_path"] = str(destination.relative_to(OUT))
    report.setdefault("generated_configuration", []).append({"path": path, "origin": "Original React Native CocoaPods privacy aggregation",
        "original_git_blob": original_blob, "original_sha256": hashlib.sha256(before_bytes).hexdigest(),
        "compiled_sha256": hashlib.sha256(after_bytes).hexdigest(), "all_other_declarations_unchanged": True,
        "all_original_reasons_retained": True, "added_reasons": added})


def verify_zayit_test_metadata(report, test_bundle=None):
    """Seal source and Xcode-built resource; never modify a signed test bundle."""
    name = "canonical-miniTest10-metadata.json"
    expected = "c6ca39044f6a62728f8f7e40e86d4080c89dc8927ced5ae6d724079efb5f896b"
    source = ROOT / "Maktabah-iOSUITests" / name
    require(source.is_file() and source.stat().st_size == 349131 and digest(source) == expected,
            "Canonical Zayit test metadata source differs from the sealed handoff")
    receipt = report.setdefault("zayit_test_metadata", {
        "source": str(source.relative_to(ROOT)), "sha256": expected, "bytes": 349131,
        "native_process_read": "NOT_RUN; requires XCTest attachment from the installed bundle"})
    if test_bundle is not None:
        resource = test_bundle / name
        require(resource.is_file() and resource.read_bytes() == source.read_bytes(),
                "Xcode did not package exact canonical Zayit metadata in the UITest bundle")
        receipt["built_resource"] = str(resource.relative_to(ROOT))
        receipt["built_resource_sha256"] = digest(resource)
    return receipt


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preflight-only", action="store_true", help="Source/input closure only; no SDK or downloads")
    ap.add_argument("--build-for-testing", action="store_true", help="Same exact inputs, real UI runner, simulator-only ad-hoc signing")
    ap.add_argument("--derived-data", default="build/hq-stage2/DerivedData")
    args = ap.parse_args()
    config = json.loads(INPUTS.read_text())
    if args.preflight_only:
        print(json.dumps(preflight(config), indent=2))
        return 0
    OUT.mkdir(parents=True, exist_ok=True)
    report = dict(status="FAILED", scope="ONE_UNSIGNED_REAL_IOS_APP_BUILD", device="NOT_RUN", runtime="NOT_RUN",
                  no_fixture_or_app_model_mocks=True, signing=False, archive=False, distribution=False)
    if args.build_for_testing:
        report.update(scope="SIMULATOR_BUILD_FOR_REAL_UI", signing="SIMULATOR_AD_HOC_ONLY")
    try:
        report.update(preflight(config))
        if args.build_for_testing:
            verify_zayit_test_metadata(report)
        require(sys.platform == "darwin", "Actual Apple check requires macOS/Xcode")
        report["xcode"] = capture("xcodebuild", "-version")
        report["swift"] = capture("xcrun", "swiftc", "--version")
        report["sdk_path"] = capture("xcrun", "--sdk", "iphonesimulator", "--show-sdk-path")
        report["sdk_version"] = capture("xcrun", "--sdk", "iphonesimulator", "--show-sdk-version")
        report["developer_dir"] = os.environ.get("DEVELOPER_DIR") or capture("xcode-select", "-p")
        prepare_react_sources(config, report)
        restore(config, report)
        rebuild_matching_zayit_framework(report)
        prepare_matching_embedded_bundle(config, report)
        install_real_pods(report)
        for framework, header in [("Vendor/OtzariaSearchEngine/OtzariaSearchEngine.xcframework", "otzaria_search_engine.h"),
                                  ("Vendor/ZayitSearchPort/build/MaktabahZayitSearch.xcframework", "maktabah_zayit_search.h")]:
            logged(["bash", "Scripts/CI/verify-xcframework.sh", framework, header], header + ".log", report)
        logged([sys.executable, "Scripts/CI/verify-otzaria-xcode-project.py"], "target-membership.log", report)
        common = ["-workspace", "Maktabah.xcworkspace", "-scheme", "Maktabah-iOS", "-clonedSourcePackagesDirPath", "build/SourcePackages"]
        help_text = subprocess.run(["xcodebuild", "-help"], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True).stdout
        require("-onlyUsePackageVersionsFromResolvedFile" in help_text, "Installed Xcode lacks pinned-only package resolution")
        logged(["xcodebuild", "-resolvePackageDependencies", *common, "-onlyUsePackageVersionsFromResolvedFile"], "resolve-packages.log", report)
        lock = ROOT / "Maktabah.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
        require(pins(lock) == report["package_pins"], "Xcode changed committed package revisions")
        require(pins(ROOT / "Maktabah.xcworkspace/xcshareddata/swiftpm/Package.resolved") == report["package_pins"], "Workspace changed committed package revisions")
        verify_actual_sources(report)
        verify_selected_zayit_files(report)
        derived_data = checked_path(ROOT / "build", str(Path(args.derived_data).relative_to("build")))
        signing = (["CODE_SIGNING_ALLOWED=YES", "CODE_SIGNING_REQUIRED=YES", "CODE_SIGN_IDENTITY=-"] if args.build_for_testing
                   else ["CODE_SIGNING_ALLOWED=NO", "CODE_SIGNING_REQUIRED=NO", "CODE_SIGN_IDENTITY="])
        command = ["xcodebuild", "build-for-testing" if args.build_for_testing else "build", *common, "-configuration", "Debug", "-sdk", "iphonesimulator",
                   "-destination", "generic/platform=iOS Simulator", "-derivedDataPath", str(derived_data),
                   "-disableAutomaticPackageResolution", "-jobs", "2", "-showBuildTimingSummary",
                   *signing,
                   "ARCHS=arm64", "ONLY_ACTIVE_ARCH=YES", "ENABLE_USER_SCRIPT_SANDBOXING=NO",
                   "RCT_NO_LAUNCH_PACKAGER=1", "SKIP_BUNDLING=1", "FAIL_ON_MISSING_BUNDLE=1"]
        logged(command, "simulator-build-for-testing.log" if args.build_for_testing else "unsigned-app-build.log", report)
        verify_selected_zayit_files(report)
        if args.build_for_testing:
            verify_zayit_test_metadata(report, derived_data /
                "Build/Products/Debug-iphonesimulator/Maktabah-iOSUITests-Runner.app/PlugIns/Maktabah-iOSUITests.xctest")
        built_bundle = derived_data / "Build/Products/Debug-iphonesimulator/Maktabah.app/main.jsbundle"
        require(built_bundle.is_file(), "Built app has no Embedded bundle")
        require(digest(built_bundle) == report["resource_inputs"]["jsbundle_sha256"], "Built app copied a nonmatching Embedded bundle")
        report["built_app_embedded_bundle_sha256"] = digest(built_bundle)
        require(pins(lock) == report["package_pins"], "Build changed committed package revisions")
        report["package_resolved_after_sha256"] = digest(lock)
        report["status"] = "SIMULATOR_BUILD_FOR_REAL_UI_PASS" if args.build_for_testing else "UNSIGNED_APP_BUILD_PASS"
        return 0
    except Exception as error:
        report["error"] = str(error)
        print(str(error), file=sys.stderr)
        return 1
    finally:
        (OUT / "result.json").write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps({key: report.get(key) for key in ["status", "checkout_sha", "sdk_version", "xcode", "error"]}, indent=2), flush=True)


if __name__ == "__main__":
    raise SystemExit(main())

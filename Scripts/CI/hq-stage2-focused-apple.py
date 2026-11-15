#!/usr/bin/env python3
"""One real unsigned app build; immutable prebuilt inputs, no data/runtime stages."""
import argparse
import hashlib
import inspect
import json
import os
from pathlib import Path, PurePosixPath
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
    require(capture("git", "rev-parse", "HEAD:Vendor/SefariaMobile/Upstream") == config["sefaria_gitlink"], "Sefaria pin drift")
    require(capture("git", "rev-parse", config["resource_producer_sha"] + ":Vendor/SefariaMobile") ==
            capture("git", "rev-parse", "HEAD:Vendor/SefariaMobile"), "Bundled JS producer source differs")
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
        report["artifact_inputs"].append({**item, "verified_sha256": actual})
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
    report["native_context"]["workspace_sha256"] = digest(ROOT / "Maktabah.xcworkspace/contents.xcworkspacedata")
    (OUT / "generated-pods-project.diff").write_text(capture("git", "diff", "--", "Maktabah.xcodeproj/project.pbxproj") + "\n")
    shutil.copyfile(ROOT / "Podfile.lock", OUT / "resolved-Podfile.lock")


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
    require(not mismatches, "Dependency setup changed tracked app input: " + ", ".join(mismatches[:10]))
    report["actual_source_inputs_verified"] = len(paths)
    (OUT / "actual-source-inputs.json").write_text(json.dumps(expected, indent=2) + "\n")
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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preflight-only", action="store_true", help="Source/input closure only; no SDK or downloads")
    args = ap.parse_args()
    config = json.loads(INPUTS.read_text())
    if args.preflight_only:
        print(json.dumps(preflight(config), indent=2))
        return 0
    OUT.mkdir(parents=True, exist_ok=True)
    report = dict(status="FAILED", scope="ONE_UNSIGNED_REAL_IOS_APP_BUILD", device="NOT_RUN", runtime="NOT_RUN",
                  no_fixture_or_app_model_mocks=True, signing=False, archive=False, distribution=False)
    try:
        report.update(preflight(config))
        require(sys.platform == "darwin", "Actual Apple check requires macOS/Xcode")
        report["xcode"] = capture("xcodebuild", "-version")
        report["swift"] = capture("xcrun", "swiftc", "--version")
        report["sdk_path"] = capture("xcrun", "--sdk", "iphonesimulator", "--show-sdk-path")
        report["sdk_version"] = capture("xcrun", "--sdk", "iphonesimulator", "--show-sdk-version")
        report["developer_dir"] = os.environ.get("DEVELOPER_DIR") or capture("xcode-select", "-p")
        prepare_react_sources(config, report)
        restore(config, report)
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
        verify_actual_sources(report)
        command = ["xcodebuild", "build", *common, "-configuration", "Debug", "-sdk", "iphonesimulator",
                   "-destination", "generic/platform=iOS Simulator", "-derivedDataPath", "build/hq-stage2/DerivedData",
                   "-disableAutomaticPackageResolution", "-jobs", "2", "-showBuildTimingSummary",
                   "CODE_SIGNING_ALLOWED=NO", "CODE_SIGNING_REQUIRED=NO", "CODE_SIGN_IDENTITY=",
                   "ARCHS=arm64", "ONLY_ACTIVE_ARCH=YES", "ENABLE_USER_SCRIPT_SANDBOXING=NO",
                   "RCT_NO_LAUNCH_PACKAGER=1", "SKIP_BUNDLING=1", "FAIL_ON_MISSING_BUNDLE=1"]
        logged(command, "unsigned-app-build.log", report)
        require(pins(lock) == report["package_pins"], "Build changed committed package revisions")
        report["package_resolved_after_sha256"] = digest(lock)
        report["status"] = "UNSIGNED_APP_BUILD_PASS"
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

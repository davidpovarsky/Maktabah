#!/usr/bin/env python3
"""Retain and admit exact local preparation inputs for a later real SDK app build."""
import argparse
import copy
import datetime
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import stat
import subprocess
import sys

SCHEMA = "otzaria.mac-prepared-inputs/1"
BUILD_STATUS = "SIMULATOR_BUILD_FOR_REAL_UI_PASS"
PRODUCT_PATHS = [
    "build/DerivedData/Build/Products/Debug-iphonesimulator/Maktabah.app",
    "build/DerivedData/Build/Products/Debug-iphonesimulator/Maktabah-iOSUITests-Runner.app",
    "build/DerivedData/Build/Products/Debug-iphonesimulator/Maktabah-iOSUITests-Runner.app/PlugIns/Maktabah-iOSUITests.xctest",
]
INPUT_ROOTS = [
    "Pods", "Podfile", "Podfile.lock",
    "Vendor/SefariaMobile/Upstream/node_modules",
    "Vendor/SefariaMobile/Upstream/package-lock.json",
    "Vendor/SefariaMobile/Upstream/ios/sources",
    "Vendor/SefariaMobile/Upstream/ios/GoogleService-Info.plist",
    "Vendor/OtzariaSearchEngine/OtzariaSearchEngine.xcframework",
    "Vendor/ZayitSearchPort/build/MaktabahZayitSearch.xcframework",
    "build/SourcePackages/checkouts", "build/SourcePackages/artifacts",
    "build/SourcePackages/prebuilts", "build/SourcePackages/workspace-state.json",
    "build/jsbundle", "build/generated/ios",
    "Maktabah.xcodeproj/project.pbxproj",
    "Maktabah.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved",
    "Maktabah.xcworkspace/contents.xcworkspacedata",
    "Maktabah.xcworkspace/xcshareddata/swiftpm/Package.resolved",
    "Source/PrivacyInfo.xcprivacy", "Source/GoogleService-Info.plist",
    "GoogleService-Info.plist", "node_modules", "package.json",
    "app.json", "babel.config.js", "metro.config.js", ".xcode.env", ".xcode.env.local",
]
OPTIONAL_ROOTS = {"build/SourcePackages/artifacts", "build/SourcePackages/prebuilts"}

def require(value, message):
    if not value:
        raise RuntimeError(message)

def sha(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()

def record(path):
    path = Path(path)
    return {"bytes": path.stat().st_size, "sha256": sha(path)}

def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, sort_keys=True, indent=2) + "\n")

def git(root, *args):
    return subprocess.check_output(["git", "-C", str(root), *args], text=True).strip()

def owned(root, relative, *, output=False):
    relative = Path(relative)
    require(not relative.is_absolute() and ".." not in relative.parts
            and relative.as_posix() != ".", "Invalid owned input path")
    require(not output or relative.parts[0] == "build", "Evidence must be in owned build output")
    path = root / relative
    require(path.resolve().is_relative_to(root), "Owned input escaped the source root")
    require(not any(p.is_symlink() for p in [path, *path.parents] if p.is_relative_to(root)),
            "Evidence path contains a symlink")
    return path

def inventory(root, paths):
    """Hash all prepared files; preserve links but never follow an escaping link."""
    records = {}
    seen = set()
    for relative in paths:
        start = root / relative
        if not start.exists() and not start.is_symlink():
            require(relative in OPTIONAL_ROOTS, "Missing prepared input: " + relative)
            records[relative] = {"kind": "absent"}
            continue
        pending = [start]
        while pending:
            path = pending.pop()
            name = path.relative_to(root).as_posix()
            if name in seen:
                continue
            seen.add(name)
            # Git object/index bookkeeping is not a compiler input. Exact pinned
            # HEAD/CLEAN checks remain mandatory in the original build driver.
            if ".git" in Path(name).parts:
                continue
            info = path.lstat()
            mode = stat.S_IMODE(info.st_mode)
            if stat.S_ISLNK(info.st_mode):
                target = path.resolve(strict=True)
                require(target.is_relative_to(root), "Prepared symlink escaped source root: " + name)
                require(".git" not in target.relative_to(root).parts, "Prepared link selects Git bookkeeping")
                records[name] = {"kind": "symlink", "target": os.readlink(path),
                                 "resolved": target.relative_to(root).as_posix(), "mode": mode}
                pending.append(target)
            elif stat.S_ISDIR(info.st_mode):
                records[name] = {"kind": "directory", "mode": mode}
                pending.extend(sorted(path.iterdir(), reverse=True))
            else:
                require(stat.S_ISREG(info.st_mode), "Special prepared input: " + name)
                records[name] = {"kind": "file", "mode": mode, **record(path)}
    return records

def compare_inventory(expected, actual):
    require(expected == actual, "Prepared input inventory changed: " + ", ".join(
        key for key in sorted(set(expected) | set(actual)) if expected.get(key) != actual.get(key))[:1500])

def command(argv):
    p = subprocess.run(argv, text=True, capture_output=True, timeout=90, check=True)
    return (p.stdout + p.stderr).strip()

def toolchain():
    require(sys.platform == "darwin", "Prepared Apple input reuse requires the actual Mac")
    developer = os.environ.get("DEVELOPER_DIR") or command(["xcode-select", "-p"])
    sdk_path = command(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-path"])
    probes = {
        "xcodebuild": (command(["xcrun", "--find", "xcodebuild"]), ["xcodebuild", "-version"]),
        "swiftc": (command(["xcrun", "--find", "swiftc"]), ["xcrun", "swiftc", "--version"]),
        "node": (shutil.which("node"), ["node", "--version"]),
        "ruby": (shutil.which("ruby"), ["ruby", "--version"]),
        "pod": (shutil.which("pod"), ["pod", "--version"]),
        "python": (sys.executable, [sys.executable, "--version"]),
    }
    values = {"developer_dir": developer, "sdk_path": sdk_path,
              "sdk_version": command(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"]),
              "developer_info": record(Path(developer).parent / "Info.plist"),
              "sdk_settings": record(Path(sdk_path) / "SDKSettings.json"), "tools": {}}
    for name, (path, argv) in probes.items():
        require(path is not None, "Missing prepared tool: " + name)
        actual = Path(path).resolve(strict=True)
        values["tools"][name] = {"path": str(actual), "version": command(argv), **record(actual)}
    macros = Path.home() / "Library/org.swift.swiftpm/security/macros.json"
    require(macros.is_file() and not macros.is_symlink(), "Exact existing macro authorization is absent")
    entries = json.loads(macros.read_bytes())
    expected = {"fingerprint": "597c2bb34af0c51331eb3b5e705f942d8ee20daa",
                "packageIdentity": "equatable", "targetName": "EquatableMacros"}
    require(isinstance(entries, list) and expected in entries, "Original pinned Equatable macro authorization changed")
    values["macros"] = {"path": str(macros), "required_entry": expected, **record(macros)}
    return values

def canonical_project(root):
    path = "Maktabah.xcodeproj/project.pbxproj"
    raw = subprocess.check_output(["git", "-C", str(root), "show", "HEAD:" + path])
    return {"git_blob": git(root, "rev-parse", "HEAD:" + path),
            "bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}

def code_images(root):
    result, required = {}, []
    magic = {b"\xce\xfa\xed\xfe", b"\xcf\xfa\xed\xfe", b"\xfe\xed\xfa\xce", b"\xfe\xed\xfa\xcf",
             b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca", b"\xca\xfe\xba\xbf", b"\xbf\xba\xfe\xca"}
    for name in PRODUCT_PATHS:
        bundle = root / name
        info = plistlib.loads((bundle / "Info.plist").read_bytes())
        required.append((bundle / info["CFBundleExecutable"]).relative_to(root).as_posix())
        for path in bundle.rglob("*"):
            require(not path.is_symlink(), "Prior native product contains an unexpected alias")
            if not path.is_file():
                continue
            with path.open("rb") as stream:
                header = stream.read(8)
            if header[:4] in magic or header == b"!<arch>\n":
                result[path.relative_to(root).as_posix()] = record(path)
    require(all(path in result for path in required), "Prior original app/UI-runner images are absent")
    return result

def assert_qualified_receipt(receipt):
    require(receipt.get("status") == BUILD_STATUS and receipt.get("scope") == "SIMULATOR_BUILD_FOR_REAL_UI",
            "Only a successful original real app/UI-runner build qualifies prepared inputs")
    require(re.fullmatch(r"[0-9a-f]{40}", receipt.get("checkout_sha", "")) is not None,
            "Successful preparation receipt has no real source commit")
    require(receipt.get("actual_source_inputs_verified", 0) > 0 and receipt.get("actual_package_checkouts"),
            "Successful build lacks actual source/package admission")

def capture(root, output):
    root = Path(root).resolve(strict=True)
    output = owned(root, output, output=True)
    require(not output.exists(), "Prepared evidence may not overwrite a prior capture")
    source = root / "build/hq-stage2/result.json"
    raw = source.read_bytes()
    receipt = json.loads(raw)
    assert_qualified_receipt(receipt)
    head = git(root, "rev-parse", "HEAD")
    require(head == receipt["checkout_sha"], "Capture must precede changing the successful source checkout")
    generated = root / "Maktabah.xcodeproj/project.pbxproj"
    require(sha(generated) == receipt["native_context"]["generated_project_sha256"],
            "Prepared CocoaPods project no longer matches the actual build")
    tools = toolchain()
    require(tools["tools"]["xcodebuild"]["version"] == receipt["xcode"]
            and tools["sdk_version"] == receipt["sdk_version"], "Successful toolchain changed before capture")
    prepared_inventory = inventory(root, INPUT_ROOTS)
    prepared_images = code_images(root)
    directory = output.parent
    directory.mkdir(parents=True, exist_ok=True)
    previous = output.with_name(output.stem + ".prior-build.json")
    require(not previous.exists(), "Prior receipt destination is occupied")
    previous.write_bytes(raw)
    original_inputs = root / "build/hq-stage2/actual-source-inputs.json"
    inputs_copy = output.with_name(output.stem + ".prior-source-inputs.json")
    require(not inputs_copy.exists(), "Prior source proof destination is occupied")
    inputs_copy.write_bytes(original_inputs.read_bytes())
    value = {"schema": SCHEMA, "status": "SUCCESSFUL_BUILD_PREPARATION_CAPTURED",
             "root": str(root), "captured_checkout_sha": head,
             "captured_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
             "capture_driver_sha256": sha(Path(__file__)),
             "prior_build": {"path": previous.relative_to(root).as_posix(), **record(previous)},
             "prior_source_inputs": {"path": inputs_copy.relative_to(root).as_posix(), **record(inputs_copy)},
             "canonical_project": canonical_project(root),
             "generated_project_sha256": sha(generated),
             "generated_configuration": receipt.get("generated_configuration", []),
             "prior_code_images": prepared_images, "toolchain": tools,
             "input_roots": INPUT_ROOTS, "inventory": prepared_inventory,
             "scope": "Exact preparation inputs only; next SDK integration and native compilation remain mandatory"}
    write(output, value)
    return {"status": value["status"], "path": str(output), **record(output),
            "prior_build_sha256": value["prior_build"]["sha256"], "prepared_entries": len(value["inventory"])}

def admit(root, manifest_relative, expected_sha256, config, report):
    root = Path(root).resolve(strict=True)
    path = owned(root, manifest_relative, output=True)
    require(re.fullmatch(r"[0-9a-f]{64}", expected_sha256 or "") is not None
            and sha(path) == expected_sha256, "Prepared manifest identity differs from the reviewed capture")
    value = json.loads(path.read_bytes())
    require(value.get("schema") == SCHEMA and value.get("status") == "SUCCESSFUL_BUILD_PREPARATION_CAPTURED"
            and value.get("root") == str(root) and value.get("input_roots") == INPUT_ROOTS
            and value.get("capture_driver_sha256") == sha(Path(__file__)),
            "Unsupported or relocated prepared-input capture")
    prior_path = owned(root, value["prior_build"]["path"], output=True)
    require(record(prior_path) == {k:value["prior_build"][k] for k in ("bytes", "sha256")},
            "Prior actual build receipt changed")
    prior = json.loads(prior_path.read_bytes())
    assert_qualified_receipt(prior)
    require(prior["checkout_sha"] == value["captured_checkout_sha"], "Prior source identity changed")
    subprocess.run(["git", "-C", str(root), "merge-base", "--is-ancestor", prior["checkout_sha"], "HEAD"], check=True)
    prior_inputs = owned(root, value["prior_source_inputs"]["path"], output=True)
    require(record(prior_inputs) == {k:value["prior_source_inputs"][k] for k in ("bytes", "sha256")},
            "Prior actual source proof changed")
    for key in ("package_pins", "hanlin_gitlink"):
        require(prior[key] == report[key], "Prepared dependency identity changed: " + key)
    for key in ("Vendor", "Maktabah.xcodeproj"):
        require(prior["application_trees"][key] == report["application_trees"][key],
                "Prepared dependency/project source tree changed: " + key)
    require(prior["resource_inputs"]["json_files"] == config["resources"],
            "Prepared source resources changed")
    artifacts = {row["name"]: row for row in prior["artifact_inputs"]}
    require(set(artifacts) == {row["name"] for row in config["artifacts"]},
            "Prepared artifact inventory changed")
    for row in config["artifacts"]:
        require(all(artifacts[row["name"]].get(k) == v for k,v in row.items())
                and artifacts[row["name"]]["verified_sha256"] == row["sha256"],
                "Prepared original artifact pin changed: " + row["name"])
    require(value["canonical_project"] == canonical_project(root), "Canonical project source changed")
    compare_inventory(value["inventory"], inventory(root, INPUT_ROOTS))
    require(value["toolchain"] == toolchain(), "Prepared toolchain or exact macro authorization changed")
    require(value["prior_code_images"] == code_images(root), "Prior code images changed before original SDK integration")
    for key in ("native_context", "artifact_inputs", "resource_inputs", "embedded_bundle_build",
                "zayit_framework", "hanlin_sdk_source"):
        if key in prior:
            report[key] = copy.deepcopy(prior[key])
    report["canonical_project_sha256"] = value["canonical_project"]["sha256"]
    report["prepared_project_entry_sha256"] = value["generated_project_sha256"]
    report["prepared_input_reuse"] = {
        "manifest": path.relative_to(root).as_posix(), "manifest_sha256": expected_sha256,
        "prior_build_receipt": value["prior_build"],
        "prior_source_inputs": value["prior_source_inputs"],
        "prior_checkout_sha": prior["checkout_sha"], "current_checkout_sha": report["checkout_sha"],
        "verified_prepared_entries": len(value["inventory"]),
        "prior_build_status": prior["status"], "native_build_skipped": False,
        "original_sdk_admission_required": True,
        "scope": "Only unchanged preparation reused; original SDK admission, package/source checks and real xcodebuild follow"}
    return value

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["capture"])
    parser.add_argument("--output", required=True, help="New relative build/ JSON destination")
    args = parser.parse_args()
    print(json.dumps(capture(Path(__file__).resolve().parents[2], args.output), indent=2))

if __name__ == "__main__":
    main()

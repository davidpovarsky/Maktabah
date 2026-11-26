"""Inspect actual consumer images while preserving the original Sefaria engine.

The original Maktabah application already embeds Expo/React Native for Sefaria.
Their unchanged source closure is recorded separately. The new MiniApps bridge
must not add another runtime owner, a NativeScript/V8 image, or a Hanlin engine.
This grants no native UI or device-signing acceptance.
"""
import gzip
import hashlib
import json
from pathlib import Path
import plistlib
import re
import runpy
import subprocess

SYMBOLS = runpy.run_path(str(Path(__file__).with_name("macho_symbol_coverage.py")))

HISTORICAL_SOURCE = "d3da55417a30e9a06b0255e2d0b561955034b260"
IMAGE_MAGIC = {b"\xce\xfa\xed\xfe", b"\xcf\xfa\xed\xfe", b"\xfe\xed\xfa\xce", b"\xfe\xed\xfa\xcf",
               b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca", b"\xca\xfe\xba\xbf", b"\xbf\xba\xfe\xca"}
NEW_ENGINE_NAMES = (
    "HanlinNativeScriptCoreSupport", "HanlinNativeScriptRuntime", "HanlinNativeScriptUI",
    "HanlinReactNativeHost", "HanlinExpoHost", "HanlinExpoRuntime", "HanlinExpoNativeAPI",
    "HanlinExpoNativeAPICore", "HanlinExpoWorklets", "HanlinExpoWidgetNative",
    "NativeScript", "NativeScriptSDK", "TNSRuntime", "TNSWidgets", "NSCWinterTC",
)
NEW_ENGINE_NAME = re.compile(
    r"(?:^|[/\s])(?:lib)?(?:" + "|".join(map(re.escape, NEW_ENGINE_NAMES)) + r"|[vV]8)(?:[./\s]|$)")
NEW_ENGINE_SYMBOL = re.compile("|".join(map(re.escape, NEW_ENGINE_NAMES)) + r"|_ZN2v8")
ORIGINAL_ENGINE_NAME = re.compile(
    r"(?:^|[/\s])(?:lib)?(?:Expo\w*|EX\w*|React(?:[-_]\w*|Common|Native)?|RCT\w*|hermes)(?:[./\s]|$)")
ORIGINAL_ENGINE_SYMBOL = re.compile(
    r"ExpoModulesCore|_ZN8facebook(?:5react|6hermes)"
    r"|OBJC_CLASS_\$_(?:RCTBridge|RCTCxxBridge|RCTRootView|RCTSurface|RCTHost|EXAppContext|EXReactDelegate)")
SHARED_NAMES = ("HanlinMiniAppsBridge", "HanlinMiniAppsPicker")
KNOWN_FAMILIES = ("HanlinChatCore", "HanlinChatUI", "HanlinAgentCore", "HanlinHostContracts",
                  "HanlinPlatformContracts", "HanlinPersistenceAdapters", "HanlinPresentationKit",
                  "HanlinScriptUI", "HanlinScriptingJSC", "SwiftAISDK", "JavaScriptCore")
HOSTED_TEST_POD_ADDITION = (
    "\n  target 'Maktabah-iOSNativeTests' do\n"
    "    inherit! :search_paths\n"
    "  end\n"
)


def require(value, message):
    if not value:
        raise RuntimeError(message)


def sha(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(4_194_304), b""):
            h.update(block)
    return h.hexdigest()


def source(root, revision, path):
    return subprocess.check_output(["git", "show", revision + ":" + path], cwd=root, timeout=90)


def application_engine_image(app, executable):
    """Locate Xcode's real split Debug executable by observed Mach-O commands."""
    stub, debug = app / executable, app / (executable + ".debug.dylib")
    if not debug.exists() and not debug.is_symlink():
        return executable, None
    require(debug.is_file() and not debug.is_symlink() and stub.is_file() and not stub.is_symlink(),
            "Aliased Xcode split executable")
    argv = ["xcrun", "otool"]
    loads = subprocess.check_output([*argv, "-L", str(stub)], text=True, timeout=60)
    image_id = subprocess.check_output([*argv, "-D", str(debug)], text=True, timeout=60)
    section = subprocess.check_output([*argv, "-s", "__TEXT", "__debug_dylib", str(stub)], text=True, timeout=60)
    reference = "@rpath/" + debug.name
    rows = section.splitlines()
    require(rows[:2] == [str(stub) + ":", "Contents of (__TEXT,__debug_dylib) section"],
            "Missing real Xcode stub section")
    address = None
    section_bytes = bytearray()
    for line in rows[2:]:
        columns = line.split()
        require(len(columns) > 1 and re.fullmatch(r"[a-fA-F0-9]+", columns[0])
                and all(re.fullmatch(r"[a-fA-F0-9]{2}|[a-fA-F0-9]{4}|[a-fA-F0-9]{8}", word)
                        for word in columns[1:]), "Invalid Xcode stub-section bytes")
        current = int(columns[0], 16)
        require(address is None or address == current, "Incomplete Xcode stub-section bytes")
        data = b"".join(bytes.fromhex(word)[::-1] for word in columns[1:])
        section_bytes.extend(data)
        address = current + len(data)
    require(section_bytes.rstrip(b"\0") == debug.name.encode()
            and image_id.splitlines() == [str(debug) + ":", reference]
            and [line.strip().split(" (", 1)[0] for line in loads.splitlines()[1:]].count(reference) == 1,
            "Actual Xcode executable does not own its split Debug image")
    return debug.name, {"stub_sha256": sha(stub), "implementation_sha256": sha(debug),
                        "install_name": reference, "stub_section_sha256": hashlib.sha256(section_bytes).hexdigest()}


def original_pod_resources(root, app, pods):
    name = app.parent.name
    require(name.endswith("-iphonesimulator"), "Expected owned Simulator products")
    config = name.removesuffix("-iphonesimulator")
    require(config in {"Debug", "Release"}, "Unknown original CocoaPods resource configuration")
    folder = root / "Pods/Target Support Files/Pods-Maktabah-iOS"
    prefix = "Pods-Maktabah-iOS-resources-" + config + "-"
    source_list = folder / (prefix + "input-files.xcfilelist")
    output_list = folder / (prefix + "output-files.xcfilelist")
    require(all(p.is_file() and not p.is_symlink() for p in (source_list, output_list)),
            "Missing original generated CocoaPods resource routes")
    outputs = output_list.read_text().splitlines()
    result = {}

    def payload(directory):
        require(directory.is_dir() and not directory.is_symlink(), "Missing original CocoaPods resource bundle")
        files = {}
        for entry in sorted(directory.rglob("*")):
            relative = entry.relative_to(directory)
            require(not entry.is_symlink(), "Aliased original CocoaPods resource")
            if relative.parts[0] == "_CodeSignature" or not entry.is_file():
                continue
            with entry.open("rb") as stream:
                header = stream.read(8)
            require(header[:4] not in IMAGE_MAGIC and header != b"!<arch>\n",
                    "A CocoaPods resource bundle contains an additional original engine image")
            files[relative.as_posix()] = sha(entry)
        require("Info.plist" in files, "Missing original CocoaPods resource bundle metadata")
        return files

    for row in source_list.read_text().splitlines():
        match = re.fullmatch(r"\$\{PODS_CONFIGURATION_BUILD_DIR\}/([A-Za-z0-9_+.-]+)/([A-Za-z0-9_+.-]+\.bundle)", row)
        if not match:
            continue
        pod, bundle = match.groups()
        if not ORIGINAL_ENGINE_NAME.search(bundle):
            continue
        expected = "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/" + bundle
        require(pod in pods and outputs.count(expected) == 1 and bundle not in result,
                "An original engine resource lacks a unique locked CocoaPods route")
        files = payload(app.parent / pod / bundle)
        require(files == payload(app / bundle), "An embedded original engine resource differs from CocoaPods: " + bundle)
        result[bundle] = {"pod": pod, "version": pods[pod], "files": files}
    return {"input_list_sha256": sha(source_list), "output_list_sha256": sha(output_list), "bundles": result}


def original_engine_provenance(root, app):
    old = source(root, HISTORICAL_SOURCE, "Podfile")
    current = source(root, "HEAD", "Podfile")
    require(current == old or (
        current.count(HOSTED_TEST_POD_ADDITION.encode()) == 1
        and current.replace(HOSTED_TEST_POD_ADDITION.encode(), b"", 1) == old),
        "The original Sefaria CocoaPods runtime declaration changed")
    require(all(value in old for value in (
        b"use_expo_modules!(", b"use_react_native!(", b"Vendor/SefariaMobile/Upstream")),
        "Historical original engine ownership is absent")
    historical_tree = subprocess.check_output(
        ["git", "rev-parse", HISTORICAL_SOURCE + ":Vendor/SefariaMobile"], cwd=root, timeout=90).strip()
    current_tree = subprocess.check_output(
        ["git", "rev-parse", "HEAD:Vendor/SefariaMobile"], cwd=root, timeout=90).strip()
    require(historical_tree == current_tree, "Original Sefaria source or upstream pin changed")
    lock = root / "Podfile.lock"
    installed = root / "Pods/Manifest.lock"
    require(lock.is_file() and installed.is_file() and lock.read_bytes() == installed.read_bytes(),
            "Actual installed CocoaPods closure is missing or differs from its lock")
    text = lock.read_text()
    require(text.startswith("PODS:\n"), "Unexpected actual CocoaPods lock format")
    pods = {}
    for line in text.split("\n\n", 1)[0].splitlines()[1:]:
        match = re.fullmatch(r"  - ([A-Za-z0-9_./+-]+) \(([^)]+)\):?", line)
        if match:
            name, version = match.groups()
            base = name.split("/")[0]
            require(base not in pods or pods[base] == version, "Ambiguous installed Pod version")
            pods[base] = version
    required = {"ExpoModulesCore", "React-Core"}
    require(required <= set(pods), "Original Expo/React Native Pod versions are not recorded")
    modules = {name.replace("-", "_").replace("+", "_") for name in pods}
    if "hermes-engine" in pods:
        modules.add("hermes")
    info = plistlib.loads((app / "Info.plist").read_bytes())
    executable = info["CFBundleExecutable"]
    require(isinstance(executable, str) and Path(executable).name == executable,
            "Malformed original application executable")
    node_versions = {}
    for name in ["react-native", "expo"]:
        path = root / "Vendor/SefariaMobile/Upstream/node_modules" / name / "package.json"
        require(path.is_file(), "Actual original runtime package is missing: " + name)
        package = json.loads(path.read_bytes())
        require(package.get("name") == name and isinstance(package.get("version"), str),
                "Malformed installed original runtime identity")
        node_versions[name] = {"version": package["version"], "package_json_sha256": sha(path)}
    require(pods["React-Core"] == node_versions["react-native"]["version"],
            "Actual React Native Pod and original installed package versions differ")
    engine_image, split_debug = application_engine_image(app, executable)
    resources = original_pod_resources(root, app, pods)
    return {
        "source": HISTORICAL_SOURCE,
        "historical_podfile_sha256": hashlib.sha256(old).hexdigest(),
        "current_committed_podfile_sha256": hashlib.sha256(current).hexdigest(),
        "only_allowed_podfile_delta": "Original hosted native-test target inherits existing search paths",
        "sefaria_tree": historical_tree.decode(),
        "podfile_lock_sha256": sha(lock),
        "installed_manifest_sha256": sha(installed),
        "resolved_pod_versions": pods,
        "installed_original_engine_packages": node_versions,
        "application_executable": executable, "application_engine_image": engine_image,
        "application_split_debug": split_debug, "original_pod_resources": resources,
        "allowed_original_framework_modules": sorted(modules),
    }


def original_image_owner(name, provenance):
    """Only the original executable or a direct framework from actual locked Pods."""
    if name == provenance.get("application_engine_image", provenance["application_executable"]):
        return "ORIGINAL_SEFARIA_STATIC_LINK_IN_APPLICATION"
    parts = Path(name).parts
    if len(parts) >= 2 and parts[0] == "Frameworks" and parts[1].endswith(".framework"):
        module = parts[1][:-len(".framework")]
        if (module in provenance["allowed_original_framework_modules"]
                and not any(part.endswith(".framework") for part in parts[2:])):
            return "ORIGINAL_SEFARIA_LOCKED_POD_FRAMEWORK"
    return None


def audit(root, app, evidence):
    root, app, evidence = Path(root), Path(app), Path(evidence)
    require(app.is_dir() and not app.is_symlink(), "Missing actual original consumer product")
    evidence.mkdir(parents=True, exist_ok=False)
    provenance = original_engine_provenance(root, app)
    image_rows, aliases, violations, original_observations = {}, {}, [], []
    for path in sorted(app.rglob("*")):
        name = path.relative_to(app).as_posix()
        if NEW_ENGINE_NAME.search(name):
            violations.append({"path": name, "kind": "NEW_MINIAPPS_ENGINE_PRODUCT"})
        if ORIGINAL_ENGINE_NAME.search(name):
            owner = original_image_owner(name, provenance)
            if Path(name).parts[0] in provenance["original_pod_resources"]["bundles"]:
                owner = "ORIGINAL_SEFARIA_LOCKED_POD_RESOURCE"
            destination = original_observations if owner else violations
            destination.append({"path": name, "kind": owner or "EXTRA_ORIGINAL_ENGINE_PRODUCT_OWNER"})
        if path.is_symlink():
            resolved = path.resolve(strict=True)
            require(resolved.is_relative_to(app.resolve()), "Consumer image alias escapes the original app")
            aliases[name] = resolved.relative_to(app.resolve()).as_posix()
            continue
        if not path.is_file():
            continue
        with path.open("rb") as stream:
            header = stream.read(8)
        if header[:4] in IMAGE_MAGIC or header == b"!<arch>\n":
            image_rows[name] = {"bytes": path.stat().st_size, "sha256": sha(path)}
    require(image_rows, "No actual consumer code images")
    observed_shared, observed_families = set(), set()
    for index, (name, row) in enumerate(image_rows.items()):
        image = app / name
        owner = original_image_owner(name, provenance)
        if owner == "ORIGINAL_SEFARIA_LOCKED_POD_FRAMEWORK":
            parts = Path(name).parts
            module = parts[1][:-len(".framework")]
            if len(parts) != 3 or parts[2] != module:
                owner = None  # An additional executable nested in a Pod is a separate code owner.
        loads = subprocess.run(["xcrun", "otool", "-L", str(image)],
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
        require(loads.returncode == 0, "Cannot inspect actual consumer load commands: " + name)
        load_path = evidence / f"{index:03d}-loads.txt"
        load_path.write_bytes(loads.stdout)
        load_text = loads.stdout.decode("utf-8", errors="replace")
        new_loads = [line for line in load_text.splitlines() if NEW_ENGINE_NAME.search(line)]
        old_loads = [line for line in load_text.splitlines() if ORIGINAL_ENGINE_NAME.search(line)]
        violations.extend({"image": name, "kind": "NEW_MINIAPPS_ENGINE_LOAD", "line": line} for line in new_loads)
        for line in old_loads:
            match = re.search(r"(?:@rpath|@loader_path|@executable_path)/((?:Frameworks/)?[^ ]+\.framework/[^ ]+)", line)
            if match:
                relative = match.group(1)
                if not relative.startswith("Frameworks/"):
                    relative = "Frameworks/" + relative
                allowed = owner and original_image_owner(relative, provenance)
            else:
                # otool's image heading is recorded too; it must be an approved original owner.
                allowed = owner and line.rstrip().endswith(":")
            (original_observations if allowed else violations).append(
                {"image": name, "kind": "ORIGINAL_SEFARIA_ENGINE_LOAD" if allowed else "EXTRA_ENGINE_LOAD_OWNER",
                 "line": line})
        observed_shared.update(item for item in SHARED_NAMES if item in name or item in load_text)
        observed_families.update(item for item in KNOWN_FAMILIES if item in name or item in load_text)
        coverage = SYMBOLS["inspect"](image, evidence, f"{index:03d}")
        require(coverage["binary_sha256"] == row["sha256"],
                "Actual image changed after the product inventory: " + name)
        lines, new_symbols, old_symbols = 0, [], 0
        for stream in coverage["symbol_streams"]:
            for line in SYMBOLS["lines"](evidence / stream["path"]):
                lines += 1
                if NEW_ENGINE_SYMBOL.search(line):
                    new_symbols.append(line.strip())
                if ORIGINAL_ENGINE_SYMBOL.search(line):
                    old_symbols += 1
                    if not owner:
                        violations.append({"image": name, "kind": "EXTRA_ENGINE_SYMBOL_OWNER",
                                           "symbol": line.strip()})
                observed_shared.update(item for item in SHARED_NAMES if item in line)
                observed_families.update(item for item in KNOWN_FAMILIES if item in line)
        violations.extend({"image": name, "kind": "NEW_MINIAPPS_ENGINE_SYMBOL", "symbol": line}
                          for line in new_symbols)
        row.update(
            original_engine_owner=owner if old_symbols or old_loads else None,
            loads={"path": load_path.name, "sha256": sha(load_path), "bytes": load_path.stat().st_size,
                   "returncode": loads.returncode, "new_engine_matches": new_loads,
                   "original_engine_matches": old_loads},
            symbols={"coverage": coverage, "line_count": lines,
                     "new_engine_match_count": len(new_symbols),
                     "original_sefaria_engine_match_count": old_symbols})
    historical = source(root, HISTORICAL_SOURCE, "Maktabah.xcodeproj/project.pbxproj").decode()
    current = (root / "Maktabah.xcodeproj/project.pbxproj").read_text()
    names = lambda text: sorted(set(re.findall(r'productName\s*=\s*"?([A-Za-z0-9_-]+)"?;', text)))
    before, after = names(historical), names(current)
    added = set(after) - set(before)
    require(not (added & set(NEW_ENGINE_NAMES)), "A new active MiniApps engine product entered the original consumer")
    passed = not violations and set(SHARED_NAMES) <= observed_shared
    report = {
        "schema": "otzaria.miniapps.actual-consumer-runtime-closure/3",
        "status": "ACTUAL_ORIGINAL_CONSUMER_NO_NEW_MINIAPPS_RUNTIME_PASS" if passed else "FAIL",
        "app": str(app), "images": image_rows, "in_app_aliases": aliases,
        "new_or_unowned_runtime_matches": violations,
        "original_sefaria_engine_provenance": provenance,
        "original_sefaria_engine_observations": original_observations,
        "required_shared_packages_observed": sorted(observed_shared),
        "hanlin_ai_and_frozen_legacy_families_observed": sorted(observed_families),
        "historical_project_package_products": before, "current_project_package_products": after,
        "added_project_package_products": sorted(added),
        "native_tests_executed": 0, "physical_signing_acceptance": "NOT_CLAIMED",
        "scope": "Actual image/load/symbol inspection; preserve unchanged original Sefaria Expo/React Native ownership and reject newly introduced MiniApps runtimes or additional engine owners",
    }
    path = evidence / "result.json"
    path.write_text(json.dumps(report, sort_keys=True, indent=2) + "\n")
    require(passed, "Consumer has new/unowned runtime evidence or lacks the actual shared Bridge/Picker: " + str(path))
    return {"path": str(path.relative_to(root)), "sha256": sha(path), "status": report["status"],
            "image_count": len(image_rows), "shared_packages": sorted(observed_shared)}

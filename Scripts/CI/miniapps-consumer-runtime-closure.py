"""Audit the actual consumer product for active MiniApps engines.

This examines every embedded Mach-O/archive image, load commands and full symbol
tables. It grants no native UI, device signing or runtime acceptance.
"""
import gzip
import hashlib
import json
from pathlib import Path
import re
import subprocess

IMAGE_MAGIC = {b"\xce\xfa\xed\xfe", b"\xcf\xfa\xed\xfe", b"\xfe\xed\xfa\xce", b"\xfe\xed\xfa\xcf",
               b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca", b"\xca\xfe\xba\xbf", b"\xbf\xba\xfe\xca"}
ENGINE_NAME = re.compile(
    r"(?:^|[/\s])(?:lib)?(?:Expo(?:ModulesCore)?|React(?:[-_]Core|Common|Native|[-_]RCT\w*)?"
    r"|hermes|NativeScript(?:SDK)?|TNSRuntime|[vV]8|HanlinNativeScriptRuntime"
    r"|HanlinNativeScriptUI|HanlinReactNativeHost|HanlinExpoHost)(?:[./\s]|$)")
ENGINE_SYMBOL = re.compile(
    r"HanlinNativeScriptRuntime|HanlinNativeScriptUI|HanlinReactNativeHost|HanlinExpoHost"
    r"|ExpoModulesCore|_ZN2v8|_ZN8facebook(?:5react|6hermes)"
    r"|OBJC_CLASS_\$_(?:RCTBridge|RCTCxxBridge|RCTRootView|RCTSurface|RCTHost|EXAppContext|EXReactDelegate|TNSRuntime)")
SHARED_NAMES = ("HanlinMiniAppsBridge", "HanlinMiniAppsPicker")
KNOWN_FAMILIES = ("HanlinChatCore", "HanlinChatUI", "HanlinAgentCore", "HanlinHostContracts",
                  "HanlinPlatformContracts", "HanlinPersistenceAdapters", "HanlinPresentationKit",
                  "HanlinScriptUI", "HanlinScriptingJSC", "SwiftAISDK", "JavaScriptCore")


def require(value, message):
    if not value:
        raise RuntimeError(message)


def sha(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(4_194_304), b""):
            h.update(block)
    return h.hexdigest()


def audit(root, app, evidence):
    root, app, evidence = Path(root), Path(app), Path(evidence)
    require(app.is_dir() and not app.is_symlink(), "Missing actual original consumer product")
    evidence.mkdir(parents=True, exist_ok=False)
    image_rows, aliases, forbidden_names = {}, {}, []
    for path in sorted(app.rglob("*")):
        name = path.relative_to(app).as_posix()
        if ENGINE_NAME.search(name):
            forbidden_names.append(name)
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
    forbidden_symbols = []
    for index, (name, row) in enumerate(image_rows.items()):
        image = app / name
        loads = subprocess.run(["xcrun", "otool", "-L", str(image)],
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
        require(loads.returncode == 0, "Cannot inspect actual consumer load commands: " + name)
        load_path = evidence / f"{index:03d}-loads.txt"
        load_path.write_bytes(loads.stdout)
        load_text = loads.stdout.decode("utf-8", errors="replace")
        violations = [line for line in load_text.splitlines() if ENGINE_NAME.search(line)]
        observed_shared.update(item for item in SHARED_NAMES if item in name or item in load_text)
        observed_families.update(item for item in KNOWN_FAMILIES if item in name or item in load_text)
        symbol_path = evidence / f"{index:03d}-symbols.txt.gz"
        lines, symbol_matches = 0, []
        process = subprocess.Popen(["xcrun", "nm", "-a", str(image)],
                                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        try:
            with gzip.open(symbol_path, "wb", compresslevel=1) as output:
                for raw in process.stdout:
                    output.write(raw)
                    lines += 1
                    line = raw.decode("utf-8", errors="replace")
                    if ENGINE_SYMBOL.search(line):
                        symbol_matches.append(line.strip())
                    observed_shared.update(item for item in SHARED_NAMES if item in line)
                    observed_families.update(item for item in KNOWN_FAMILIES if item in line)
            exit_code = process.wait(timeout=120)
        except BaseException:
            process.kill()
            process.wait(timeout=10)
            raise
        require(exit_code == 0, "Cannot inspect actual full consumer symbols: " + name)
        forbidden_symbols.extend({"image": name, "symbol": line} for line in symbol_matches)
        row.update(loads={"path": load_path.name, "sha256": sha(load_path), "bytes": load_path.stat().st_size,
                          "returncode": loads.returncode, "engine_matches": violations},
                   symbols={"path": symbol_path.name, "sha256": sha(symbol_path),
                            "compressed_bytes": symbol_path.stat().st_size,
                            "line_count": lines, "returncode": exit_code,
                            "engine_match_count": len(symbol_matches)})
        forbidden_names.extend(name + ": " + line for line in violations)
    historical = subprocess.check_output(
        ["git", "show", "d3da55417a30e9a06b0255e2d0b561955034b260:Maktabah.xcodeproj/project.pbxproj"],
        cwd=root, timeout=90).decode()
    current = (root / "Maktabah.xcodeproj/project.pbxproj").read_text()
    names = lambda text: sorted(set(re.findall(r"productName\s*=\s*\"?([A-Za-z0-9_-]+)\"?;", text)))
    before, after = names(historical), names(current)
    passed = not forbidden_names and not forbidden_symbols and set(SHARED_NAMES) <= observed_shared
    report = {"schema": "otzaria.miniapps.actual-consumer-runtime-closure/1",
              "status": "ACTUAL_ORIGINAL_CONSUMER_RUNTIME_CLOSURE_PASS" if passed else "FAIL",
              "app": str(app), "images": image_rows, "in_app_aliases": aliases,
              "active_engine_product_or_load_matches": forbidden_names,
              "active_engine_symbol_matches": forbidden_symbols,
              "required_shared_packages_observed": sorted(observed_shared),
              "hanlin_ai_and_frozen_legacy_families_observed": sorted(observed_families),
              "historical_project_source": "d3da55417a30e9a06b0255e2d0b561955034b260",
              "historical_project_package_products": before,
              "current_project_package_products": after,
              "added_project_package_products": sorted(set(after) - set(before)),
              "native_tests_executed": 0, "physical_signing_acceptance": "NOT_CLAIMED",
              "scope": "Actual embedded image, load and symbol audit; pre-existing AI and frozen legacy names are recorded separately from forbidden active Expo/React Native/NativeScript/V8 engines"}
    path = evidence / "result.json"
    path.write_text(json.dumps(report, sort_keys=True, indent=2) + "\n")
    require(passed, "Consumer contains an active runtime or lacks its actual shared Bridge/Picker image/symbol evidence: " + str(path))
    return {"path": str(path.relative_to(root)), "sha256": sha(path), "status": report["status"],
            "image_count": len(image_rows), "shared_packages": sorted(observed_shared)}

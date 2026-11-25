#!/usr/bin/env python3
"""Configure a genuine hosted XCTest to import the already admitted app SDK.

This changes one generated Debug test configuration, never app settings, SDK
ownership, identity, entitlements, or a production acceptance selector. Restore
the exact generated project before continuing another app acceptance route.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

import original_editor_sdk_routes as routes

ROOT = Path(__file__).resolve().parents[2]
APP_TARGET = "F30576DD2FA46222005732C6"
TEST_TARGET = "9A7A8DF8CEC43F196DDCD80A"
TEST_CONFIG = "F47AEF17D4EACBE870FB9727"
TEST_NAME = "Maktabah-iOSNativeTests"
BUNDLE = "com.davidpovarsky.chavrusatext"
TEST_HOST = "$(BUILT_PRODUCTS_DIR)/Maktabah.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Maktabah"
KEYS = ("FRAMEWORK_SEARCH_PATHS", "SWIFT_INCLUDE_PATHS",
        "LIBRARY_SEARCH_PATHS", "HEADER_SEARCH_PATHS", "OTHER_SWIFT_FLAGS")


def require(value, message):
    if not value:
        raise ValueError(message)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def write_json(path, value):
    path.write_text(json.dumps(value, sort_keys=True, indent=2) + "\n")


def parsed(path):
    return json.loads(subprocess.check_output(
        ["plutil", "-convert", "json", "-o", "-", str(path)], timeout=20))


def atom(value):
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=True)
    if isinstance(value, list) and all(isinstance(x, str) for x in value):
        return "(\n" + "".join("\t\t\t\t\t" + atom(x) + ",\n" for x in value) + "\t\t\t\t)"
    raise ValueError("Unexpected generated setting value")


def project_path():
    path = ROOT / "Maktabah.xcodeproj/project.pbxproj"
    require(path.is_file() and not path.is_symlink(), "Expected the original generated project")
    return path


def prepare(route_path, route_sha, evidence):
    require(sys.platform == "darwin", "This projection must inspect Apple's real generated project")
    require(not evidence.exists(), "Retain the existing attempt; do not overwrite evidence")
    row, admitted = routes.admitted_route(
        ROOT, route_path, route_sha, "Debug", "iphonesimulator")
    project = project_path()
    raw = project.read_bytes()
    before = parsed(project)
    objects = before["objects"]
    app = objects[APP_TARGET]
    test = objects[TEST_TARGET]
    require(app["name"] == "Maktabah-iOS"
            and app["productType"] == "com.apple.product-type.application",
            "The host must be the actual application target")
    require(test["name"] == TEST_NAME
            and test["productType"] == "com.apple.product-type.bundle.unit-test",
            "Expected the dedicated genuine hosted unit target")
    require(any(objects[x].get("target") == APP_TARGET for x in test["dependencies"]),
            "The hosted XCTest must depend on the actual app")
    app_configs = [objects[x] for x in objects[app["buildConfigurationList"]]["buildConfigurations"]
                   if objects[x]["name"] == "Debug"]
    require(len(app_configs) == 1, "Ambiguous actual app Debug configuration")
    app_settings = app_configs[0]["buildSettings"]
    require(app_settings["PRODUCT_BUNDLE_IDENTIFIER"] == BUNDLE,
            "The application's original bundle identity changed")
    original = objects[TEST_CONFIG]
    settings = original["buildSettings"]
    require(original["name"] == "Debug" and TEST_CONFIG in
            objects[test["buildConfigurationList"]]["buildConfigurations"],
            "Wrong hosted test configuration")
    require(settings["TEST_HOST"] == TEST_HOST
            and settings["BUNDLE_LOADER"] == "$(TEST_HOST)"
            and settings["TEST_TARGET_NAME"] == "Maktabah-iOS"
            and settings["PRODUCT_BUNDLE_IDENTIFIER"] == BUNDLE + "." + TEST_NAME,
            "Hosted test identity or loader changed")
    require("baseConfigurationReference" in original,
            "Run the original Pod installation: hosted test needs inherit! search_paths")
    proof_path = routes.owned(ROOT, row["evidence"] + "/app-target-configuration.json", "build/")
    proof_raw = proof_path.read_bytes()
    proof = json.loads(proof_raw)
    require(proof["after_project_sha256"] == sha(raw)
            and proof["all_other_objects_unchanged"] is True
            and proof["whole_project_inverse_exact"] is True,
            "The original app SDK project projection is not the exact current one")
    require(any(objects[x].get("name") == "[Otzaria] Embed admitted original editor"
                for x in app["buildPhases"]), "Missing the actual app SDK embed phase")
    distribution = routes.owned(ROOT, admitted["distribution_root"], "build/")
    require((distribution / "Frameworks/AnytypeOriginalEditor.framework").is_dir()
            and (distribution / "Modules").is_dir(),
            "The exact admitted SDK inputs are absent")
    adjusted = dict(settings)
    for key in KEYS:
        require(key in app_settings, "Actual SDK import setting is absent: " + key)
        require(isinstance(app_settings[key], (str, list)), "Unexpected app import shape")
        adjusted[key] = app_settings[key]
    # Only the genuine framework is linked directly. The already built Host
    # owns its original static/shared implementations; none are duplicated here.
    require(settings["OTHER_LDFLAGS"] == ["$(inherited)", "-framework", "AnytypeOriginalEditor"],
            "Unreviewed hosted test linker inputs")
    source = raw.decode()
    pattern = re.compile(r"(\t\t" + TEST_CONFIG +
                         r" /\* [^\n]+ \*/ = \{\n"
                         r"(?:\t\t\t(?!buildSettings = )[^\n]*\n)*"
                         r"\t\t\tbuildSettings = \{)(.*?)(\n\t\t\t\};)", re.S)
    matches = list(pattern.finditer(source))
    require(len(matches) == 1, "Ambiguous generated hosted test settings block")
    match = matches[0]
    body = "".join("\n\t\t\t\t" + key + " = " + atom(value) + ";"
                   for key, value in sorted(adjusted.items()))
    altered = (source[:match.start(2)] + body + source[match.end(2):]).encode()
    require(altered != raw, "Hosted SDK projection is already present")
    evidence.mkdir(parents=True)
    backup = evidence / "project.before.pbxproj"
    candidate = evidence / "project.projected.pbxproj"
    backup.write_bytes(raw)
    candidate.write_bytes(altered)
    after = parsed(candidate)
    expected = json.loads(json.dumps(before))
    expected["objects"][TEST_CONFIG]["buildSettings"] = adjusted
    require(after == expected, "Projection changed another object or test setting")
    inverse = (altered.decode()[:match.start(2)] + match.group(2) +
               altered.decode()[match.start(2) + len(body):]).encode()
    require(inverse == raw, "Hosted project inverse is not byte exact")
    receipt = {
        "schema": "otzaria.original-editor.hosted-test-import-projection/1",
        "status": "EXACT_TEST_IMPORT_PROJECTION_ONLY",
        "sdk_source_sha": admitted["source_sha"],
        "route_path": route_path, "route_sha256": route_sha,
        "app_admission_receipt_path": row["path"],
        "app_admission_receipt_sha256": row["sha256"],
        "app_project_receipt_sha256": sha(proof_raw),
        "before_project_sha256": sha(raw), "after_project_sha256": sha(altered),
        "only_changed_object": TEST_CONFIG, "only_changed_keys": list(KEYS),
        "all_app_objects_unchanged": True, "whole_project_inverse_exact": True,
        "app_identity": BUNDLE, "hosted_target": TEST_NAME,
        "sdk_implementation_copies_added": 0,
        "tests_executed": 0, "ordinary_ui_credit": False,
        "backup": str(backup.relative_to(ROOT)),
    }
    require(project.read_bytes() == raw, "Another actor changed the generated project")
    temporary = project.with_name(".otzaria-hosted-tests-pbx.tmp")
    require(not temporary.exists(), "A previous project write is still present")
    temporary.write_bytes(altered)
    os.replace(temporary, project)
    write_json(evidence / "projection.json", receipt)
    return receipt


def restore(evidence):
    require(sys.platform == "darwin", "Restore on the original Mac")
    receipt_path = evidence / "projection.json"
    receipt = json.loads(receipt_path.read_bytes())
    require(receipt["schema"] == "otzaria.original-editor.hosted-test-import-projection/1"
            and receipt["only_changed_object"] == TEST_CONFIG,
            "Wrong hosted projection receipt")
    backup = routes.owned(ROOT, receipt["backup"], "build/")
    require(backup.parent == evidence, "Backup belongs to another evidence directory")
    raw = backup.read_bytes()
    require(sha(raw) == receipt["before_project_sha256"], "Original project backup changed")
    project = project_path()
    require(sha(project.read_bytes()) == receipt["after_project_sha256"],
            "Refusing to overwrite another actor's project changes")
    temporary = project.with_name(".otzaria-hosted-tests-pbx.tmp")
    require(not temporary.exists(), "A previous project write is still present")
    temporary.write_bytes(raw)
    os.replace(temporary, project)
    require(project.read_bytes() == raw, "Project restore did not retain the original bytes")
    result = {"status": "EXACT_ORIGINAL_APP_PROJECT_RESTORED",
              "sha256": sha(raw), "tests_executed": 0}
    write_json(evidence / "restore.json", result)
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("command", choices=["prepare", "restore"])
    parser.add_argument("--evidence", required=True)
    parser.add_argument("--routes")
    parser.add_argument("--routes-sha256")
    args = parser.parse_args()
    evidence = routes.owned(ROOT, args.evidence, "build/")
    if args.command == "prepare":
        require(args.routes and args.routes_sha256, "Exact admitted routes are required")
        result = prepare(args.routes, args.routes_sha256, evidence)
    else:
        require(not args.routes and not args.routes_sha256, "Restore uses its retained exact receipt")
        result = restore(evidence)
    print(json.dumps(result, sort_keys=True, indent=2))

#!/usr/bin/env python3
"""Source/result boundary for four unchanged original native diagnostics.

The original runtime27.py owns all full-app compilation, Simulator lifecycle,
XCTest execution, deadlines, raw xcresult verification and collection. This
wrapper grants neither full Native116 nor Release114 acceptance.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
BASE = "1bf1da14c0c3d74bb790331d8df365accac905f9"
REF = "refs/heads/codex/otzaria-reader-inspector-focused-native-v3-20261120"
DOCS = "docs/hq-integration/reader-inspector-focused-native-v3-20261120/"
WORKFLOW = ".github/workflows/otzaria-reader-inspector-focused-native-v3.yml"
SELF = "Scripts/CI/reader-inspector-focused-native.py"
TESTS = "Scripts/CI/test-reader-inspector-focused-native.py"
MANIFEST = "docs/hq-integration/runtime27/R27_CASES.json"
INPUTS = "Scripts/CI/hq-stage2-focused-apple.inputs.json"
ADDITIONS = "Scripts/CI/hq-stage2-otzaria-test-additions.json"
RUNTIME = "Scripts/CI/runtime27.py"
ALLOWED = {WORKFLOW, SELF, TESTS, MANIFEST, INPUTS, ADDITIONS, RUNTIME}
TREES = {
    "Source": "3e2541b84ee83a4fed5ec7f93cc5ac488c7c2169",
    "Vendor": "4065c0e62af325e83a65fe0c70270985229807ae",
    "Maktabah.xcodeproj": "ebf00ef1e0e466b083f476be9a9bf1a06c7d2b72",
    "Maktabah-iOSUITests": "6ab7629c1dee420d7a6e6118d2d72759fe1fafc8",
}
SELECTED = [
    "NativeRoutingAcceptanceTests/testCoreCommentaryOpensVerifiedSourceLinkAndPreservesBaseOnPad",
    "FaithfulReaderUIAcceptanceTests/testCandidateTrimmedOriginalInspectorLandscape",
    "FaithfulReaderUIAcceptanceTests/testCandidateTrimmedOriginalInspectorPortrait",
    "FaithfulReaderUIAcceptanceTests/testSystemReduceMotionKeepsOriginalPaletteUsable",
]
OLD_R27 = "53f9db5b97784b9003eacf1bafc69e51bb64dd0580e426f0d8a17d32f4d9de9b"
NEW_R27 = "b81034f6e6f83089c9a2cf6294468abfde382af156879f8a7161599539bb87ed"
OLD_PROJECT = "2741615644741d39b0b19c6146f9c459323dabab"
NEW_PROJECT = "489fd95080cd47c8b2138f70bc9ab72e5e4879f0"
OUT = ROOT / "build/artifacts/reader-inspector-focused-native"


def require(ok, message):
    if not ok:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def blob(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, timeout=120)


def frozen_json(path):
    return json.loads(git("show", BASE + ":" + path))


def read_json(path):
    return json.loads((ROOT / path).read_bytes())


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def validate_identity(head, expected, ref, parents, trees, changed):
    require(len(expected) == 40 and all(c in "0123456789abcdef" for c in expected), "Missing exact expected checkout")
    require(head == expected and ref == REF, "Wrong immutable checkout/ref")
    require(parents == [BASE], "This route requires exactly one reviewed child of M")
    require(trees == TREES, "Application, dependency, project or XCTest tree changed")
    require(set(changed) >= ALLOWED, "Missing required focused source/pins")
    require(all(p in ALLOWED or p.startswith(DOCS) for p in changed), "Unreviewed changed path")


def validate_manifest(current, original):
    old_rows = original["cases"] + original["supplemental_cases"]
    rows = current["cases"] + current["supplemental_cases"]
    require(len(old_rows) == 116 and rows[:116] == old_rows, "Original116 rows/oracles changed")
    require(len(rows) == 119 and len({r["case_id"] for r in rows}) == 119, "Diagnostic catalog must contain116+3 unique rows")
    require([r["case_id"] for r in rows[116:]] == SELECTED[1:], "Wrong existing Release diagnostic rows")
    require(all(r["device"] == "ipad11" and r["status"] == "NOT_RUN" for r in rows[116:]), "New rows may not carry execution credit")
    require(current["execution_case_ids"] == SELECTED, "Wrong diagnostic selection/order")
    require(current["execution_groups"] == [{"label": "11-reader", "size": "11", "case_ids": SELECTED}], "Wrong original matrix partition")
    require(current["expected_per_device"] == {"ipad11": 4, "ipad13": 0, "iphone": 0}, "Wrong per-device count")
    require(current["required_nonzero_cases"] == 4 and current["native_cases_executed"] == 0, "Wrong execution count")
    require(current["diagnostic_only"] is True and current["hid_comparison"] is False, "Wrong focused mode")
    require(all(current[k] == BASE for k in ("source_test_commit", "app_source", "application_source_sha")), "Source/test pins do not bind M")
    history = current["reader_inspector_diagnostic_20261120"]
    require(history["original_execution_case_ids"] == original["execution_case_ids"], "Original full selection not retained")
    require(history["source_snapshot"] == BASE and history["additional_existing_release_rows"] == rows[116:], "Diagnostic provenance mismatch")
    require(history["full_native116_acceptance"] is False and history["full_release114_acceptance"] is False
            and history["new_native_executions"] == 0, "Unexecuted or full-phase credit")
    allowed = {"source_test_commit", "app_source", "application_source_sha", "scope", "native_cases_executed",
               "required_nonzero_cases", "expected_per_device", "diagnostic_only", "hid_comparison", "execution_case_ids",
               "execution_groups", "selected_scope_reason", "diagnostic_purpose", "supplemental_cases",
               "reader_inspector_diagnostic_20261120"}
    require({k: v for k, v in current.items() if k not in allowed} ==
            {k: v for k, v in original.items() if k not in allowed}, "Unrelated manifest contract changed")


def validate_pins(inputs, old_inputs, additions_bytes, old_additions_bytes, runtime, old_runtime):
    require(old_runtime.count(OLD_R27.encode()) == 1 and runtime == old_runtime.replace(OLD_R27.encode(), NEW_R27.encode()),
            "Original runtime driver changed beyond reviewed test hash")
    require(old_additions_bytes.count(OLD_PROJECT.encode()) == 1
            and additions_bytes == old_additions_bytes.replace(OLD_PROJECT.encode(), NEW_PROJECT.encode()),
            "Exact78 test additions/build exclusions changed beyond actual project proof pin")
    allowed = {"application_source_sha", "application_trees", "otzaria_test_additions_sha256"}
    require({k: v for k, v in inputs.items() if k not in allowed} ==
            {k: v for k, v in old_inputs.items() if k not in allowed}, "Engine/resource/SDK/package inputs changed")
    require(inputs["application_source_sha"] == BASE, "Wrong app source")
    require(inputs["application_trees"] == {k: TREES[k] for k in ("Source", "Vendor", "Maktabah.xcodeproj")}, "Wrong app trees")
    require(inputs["otzaria_test_additions_sha256"] == sha(additions_bytes), "Unbound exact additions manifest")
    require(inputs["hanlin_gitlink"] == "e00498e33f106cc43be0476ffa2e09329c8ca300", "Original Hanlin changed")


def exact_working_inputs(paths):
    records = {}
    entries = git("ls-tree", "-r", "-z", "HEAD", "--", *paths)
    for row in entries.split(b"\0"):
        if not row:
            continue
        meta, name = row.split(b"\t", 1)
        mode, kind, object_id = meta.decode().split()
        if kind != "blob":
            continue
        path = name.decode()
        p = ROOT / path
        # Tracked source links, if any, are hashed as the original link target.
        actual = os.readlink(p).encode() if mode == "120000" and p.is_symlink() else p.read_bytes()
        require(blob(actual) == object_id, "Dirty tracked execution input: " + path)
        records[path] = {"blob": object_id, "bytes": len(actual), "sha256": sha(actual)}
    require(records, "Empty execution source closure")
    return records


def validate_outcomes(ui, build, summary, leaves, expected):
    require(ui.get("checkout_sha") == build.get("checkout_sha") == expected, "Outcome checkout mismatch")
    require(build.get("status") == "SIMULATOR_BUILD_FOR_REAL_UI_PASS", "No complete actual full-app/test build")
    require(build.get("application_source_sha") == BASE and build.get("application_trees") ==
            {k: TREES[k] for k in ("Source", "Vendor", "Maktabah.xcodeproj")}, "Build source mismatch")
    require(ui.get("status") == "SELECTED_UI_EXECUTED_PASS" and ui.get("mode") == "ui", "Selected diagnostic execution did not pass")
    require(ui.get("full_release_acceptance") is False and ui.get("distribution") is False, "Invalid full/distribution credit")
    require(ui.get("test_source_commit") == BASE and ui.get("test_tree") == TREES["Maktabah-iOSUITests"], "Actual test source mismatch")
    require(ui.get("requested_ui_case_count") == ui.get("executed_ui_pass") == 4, "Incomplete selected UI execution")
    require(all(ui.get(k) == 0 for k in ("executed_ui_fail", "executed_ui_skip", "ui_not_run")), "Failed/skipped/unverified original case")
    outcomes = ui.get("case_outcomes", [])
    require(len(outcomes) == 4 and {r["case_id"] for r in outcomes} == set(SELECTED)
            and all(r["actual"] == "Passed" and r["device"] == "ipad11" and r["configuration_label"] == "11-reader" for r in outcomes),
            "Wrong actual case identities/outcomes")
    require(summary.get("passedTests") == 4 and all(summary.get(k) == 0 for k in ("failedTests", "skippedTests", "expectedFailures")),
            "Raw xcresult summary is not four ordinary passes")
    require(len(leaves) == 4 and {x[0] for x in leaves} == set(SELECTED) and all(x[1] == "Passed" for x in leaves),
            "Raw xcresult leaves differ or duplicate")


def source_check(phase, expected, ref):
    head = git("rev-parse", "HEAD").decode().strip()
    parents = git("show", "-s", "--format=%P", "HEAD").decode().split()
    trees = {p: git("rev-parse", "HEAD:" + p).decode().strip() for p in TREES}
    changed = git("diff", "--name-only", BASE, "HEAD").decode().splitlines()
    validate_identity(head, expected, ref, parents, trees, changed)
    manifest = read_json(MANIFEST)
    validate_manifest(manifest, frozen_json(MANIFEST))
    validate_pins(read_json(INPUTS), frozen_json(INPUTS), (ROOT / ADDITIONS).read_bytes(), git("show", BASE + ":" + ADDITIONS),
                  (ROOT / RUNTIME).read_bytes(), git("show", BASE + ":" + RUNTIME))
    require(sha((ROOT / "Maktabah-iOSUITests/R27NativeInteractionAcceptanceTests.swift").read_bytes()) == NEW_R27, "Pinned actual R27 source differs")
    require(git("rev-parse", "HEAD:Maktabah.xcodeproj/project.pbxproj").decode().strip() == NEW_PROJECT, "Pinned original project differs")
    records = exact_working_inputs(["Scripts/CI", ".github/workflows", "Maktabah-iOSUITests", "tools"])
    if phase == "before":
        product = exact_working_inputs(list(TREES))
    else:
        # Reuse the original package/pristine/privacy audit after actual UI.
        # CocoaPods' reviewed project/privacy generation is not a source rewrite.
        build = read_json("build/hq-stage2/result.json")
        hq = runpy.run_path(str(ROOT / "Scripts/CI/hq-stage2-focused-apple.py"))
        hq["verify_actual_sources"](build)
        native = build.get("native_context", {})
        require(sha((ROOT / "Maktabah.xcodeproj/project.pbxproj").read_bytes()) == native.get("generated_project_sha256"), "Generated original Pod integration project changed")
        require(sha((ROOT / "Maktabah.xcworkspace/contents.xcworkspacedata").read_bytes()) == native.get("workspace_sha256"), "Original workspace changed")
        hq["prepare_original_hanlin"](read_json(INPUTS), build, verify_only=True)
        product = {"original_helper_actual_source_count": build["actual_source_inputs_verified"],
                   "package_checkouts": build["actual_package_checkouts"],
                   "generated_configuration": build.get("generated_configuration", [])}
        write(OUT / "original-post-ui-input-audit.json", build)
        before = read_json("build/artifacts/reader-inspector-focused-native/SOURCE_BEFORE.json")
        require(records == before["execution_inputs"], "CI/test bytes changed across original execution")
    return {"status": "SOURCE_BOUND_ONLY", "head": head, "application_and_tests": BASE, "ref": ref, "phase": phase,
            "trees": trees, "changed_paths": changed, "execution_inputs": records, "product_inputs": product,
            "native_pass_credit": 0, "full_native116_acceptance": False, "full_release114_acceptance": False}


def qualify(expected):
    ui = read_json("build/artifacts/runtime27/result.json")
    build = read_json("build/hq-stage2/result.json")
    summary = read_json("build/artifacts/runtime27/verified-11-reader.summary.json")
    tree = read_json("build/artifacts/runtime27/verified-11-reader.tests.json")
    case_id = runpy.run_path(str(ROOT / "tools/verify_xcresult_zero_skips.py"))["case_id"]
    leaves = []
    def visit(node, suite=None):
        if node.get("nodeType") == "Test Suite":
            suite = node["name"].split(".")[-1]
        if node.get("nodeType") == "Test Case":
            leaves.append((case_id(node.get("nodeIdentifier") or f"{suite}/{node['name']}"), node.get("result")))
        for child in node.get("children", []):
            visit(child, suite)
    for node in tree.get("testNodes", []):
        visit(node)
    validate_outcomes(ui, build, summary, leaves, expected)
    require(ui.get("case_manifest_sha256") == sha((ROOT / MANIFEST).read_bytes()), "Execution used different selected scope")
    require(ui.get("helper_inputs_sha256", {}).get(RUNTIME) == sha((ROOT / RUNTIME).read_bytes()), "Execution used different original runtime")
    return {"status": "FOUR_SELECTED_ORIGINAL_NATIVE_CASES_PASS", "head": expected, "application_and_tests": BASE,
            "case_outcomes": ui["case_outcomes"], "selected_count": 4, "original_native_catalog_preserved": 116,
            "full_native116_acceptance": False, "full_release114_acceptance": False,
            "scope": "Full actual app build; only four original iPad cases qualified. No physical-device or full-phase credit."}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("phase", choices=["before", "after"])
    args = parser.parse_args()
    expected = os.environ.get("EXPECTED_CHECKOUT_SHA", "")
    report = {"status": "FAIL", "phase": args.phase, "head": expected, "application_and_tests": BASE,
              "selected_count": 4, "full_native116_acceptance": False, "full_release114_acceptance": False}
    try:
        source = source_check(args.phase, expected, os.environ.get("GITHUB_REF", ""))
        write(OUT / ("SOURCE_" + args.phase.upper() + ".json"), source)
        report.update(source_status=source["status"])
        if args.phase == "after":
            report.update(qualify(expected))
        else:
            report.update(status="SOURCE_PREFLIGHT_PASS", native_pass_credit=0)
        return 0
    except Exception as error:
        report["error"] = str(error)
        print(type(error).__name__ + ": " + str(error), file=sys.stderr)
        return 1
    finally:
        write(OUT / ("RESULT_" + args.phase.upper() + ".json"), report)
        print(json.dumps({k: report.get(k) for k in ("status", "phase", "head", "selected_count", "error")}, indent=2))


if __name__ == "__main__":
    raise SystemExit(main())

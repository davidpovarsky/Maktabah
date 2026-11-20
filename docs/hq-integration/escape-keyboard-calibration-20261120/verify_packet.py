#!/usr/bin/env python3
"""Read-only source/collector/selection integrity; never runs Swift or UI."""
import argparse
import ast
import gzip
import hashlib
import json
from pathlib import Path

PREFIX = "docs/hq-integration/escape-keyboard-calibration-20261120"
CALIBRATION = "R27NativePadTests/testNormalBootstrapPaletteKeyboardDispatchCalibration"
POINTER = "FaithfulReaderUIAcceptanceTests/testPointerHoverClickAndHardwareKeyboardDismissal"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def blob(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True)
    args = parser.parse_args()
    root = args.root.resolve()
    docs = root / PREFIX
    manifest = json.loads((docs / "ARTIFACTS.json").read_text())
    for row in manifest["files"]:
        data = (root / row["path"]).read_bytes()
        assert len(data) == row["bytes"] and sha(data) == row["sha256"] and blob(data) == row["git_blob"], row["path"]
    authority = json.loads((docs / "SOURCE_AUTHORITY.json").read_text())
    inputs = {}
    for row in authority["inputs"]:
        data = gzip.decompress((docs / row["retained"]).read_bytes())
        assert len(data) == row["bytes"] and sha(data) == row["sha256"] and blob(data) == row["git_blob"], row["path"]
        inputs[row["path"]] = data
    edits = json.loads((docs / "EXACT_EDIT.json").read_text())
    new = (root / edits["path"]).read_bytes()
    expected = authority["candidate"]
    assert sha(new) == expected["sha256"] and blob(new) == expected["git_blob"]
    old = inputs[edits["path"]]
    inverse = new.decode()
    for edit in reversed(edits["replacements"]):
        assert inverse.count(edit["after"]) == 1
        inverse = inverse.replace(edit["after"], edit["before"], 1)
    assert inverse.encode() == old
    source = new.decode()
    assert source.count("private var recordsPaletteEscapeCalibration = false") == 1
    assert source.count("recordsPaletteEscapeCalibration = true") == 1
    start = "    func testNormalBootstrapPaletteKeyboardDispatchCalibration() throws {\n"
    end = "    /// Separate delivery comparison."
    original_body = old.decode().split(start, 1)[1].split(end, 1)[0]
    current_body = source.split(start, 1)[1].split(end, 1)[0]
    assert current_body.replace("        recordsPaletteEscapeCalibration = true\n", "", 1) == original_body
    assert current_body.index("recordsPaletteEscapeCalibration = true") < current_body.index("launchReader(")
    assert "super.readerAdditionalLaunchArguments\n            + (recordsPaletteEscapeCalibration ?" in source
    assert " + readerAdditionalLaunchArguments," in source
    for key in ("downArrow", "upArrow", "escape"):
        assert current_body.count("typeKey(XCUIKeyboardKey." + key) == original_body.count("typeKey(XCUIKeyboardKey." + key)
    assert "sendNativeHID" not in current_body

    matrix_source = inputs["Scripts/CI/run-faithful-ipad-matrix.py"].decode()
    tree = ast.parse(matrix_source)
    function = next(node for node in tree.body if isinstance(node, ast.FunctionDef)
                    and node.name == "requires_native_log_collection")
    scope = {}
    exec(compile(ast.Module(body=[function], type_ignores=[]), "original-collector", "exec"), scope)
    collector = scope["requires_native_log_collection"]
    assert collector([CALIBRATION]) is False
    assert collector([POINTER]) is True
    assert collector([CALIBRATION, POINTER]) is True
    assert 'Documents/OtzariaLogs/otzaria-reader.log' in matrix_source

    native = json.loads(inputs["docs/hq-integration/runtime27/R27_CASES.json"])
    release = json.loads(inputs["Scripts/CI/runtime27-release-manifest.json"])
    assert len(native["execution_case_ids"]) == 116
    assert sum(len(row["required_ui_cases"]) for row in release["configurations"]) == 114
    assert sum(len(row.get("required_oracle_cases", [])) for row in release["configurations"]) == 2
    proposal = json.loads((docs / "SELECTION_PROPOSAL.json").read_text())
    assert proposal["single_calibration"]["case_ids"] == [CALIBRATION]
    assert proposal["paired_diagnostic"]["case_ids"] == [CALIBRATION, POINTER]
    for case in (CALIBRATION, POINTER):
        assert case not in native["execution_case_ids"]
        actual = [row["id"] for row in release["configurations"] if case in row["required_ui_cases"]]
        assert proposal["current_selection_crosswalk"][case]["release114_configurations"] == actual
    assert not proposal["activation_authorized_by_this_packet"]
    assert not proposal["single_calibration"]["original_native_log_collection"]
    assert proposal["paired_diagnostic"]["original_native_log_collection"]
    search = json.loads(gzip.decompress((docs / "raw/CALIBRATION_RETAINED_SEARCH.json.gz").read_bytes()))
    assert search["query"] == CALIBRATION.split("/")[1] and search["files_read"] == 325 and search["hits"] == []
    assert len(search["inventory"]) == 325
    print(json.dumps({"status": "PASS_SOURCE_INVERSE_COLLECTOR_AND_SELECTION_ONLY",
                      "manifested_files": len(manifest["files"]), "canonical_base_inputs": len(inputs),
                      "whole_file_inverse_exact": True, "original_calibration_body_preserved": True,
                      "native116_selections_unchanged": 116, "release114_ui_executions_unchanged": 114,
                      "release_oracles_unchanged": 2, "single_calibration_log_collection": False,
                      "paired_diagnostic_log_collection": True, "swift_parse": "NOT_RUN",
                      "apple_typecheck": "NOT_RUN", "native_executions": 0}, indent=2))


if __name__ == "__main__":
    main()

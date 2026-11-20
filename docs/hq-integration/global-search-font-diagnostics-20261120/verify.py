#!/usr/bin/env python3
"""Verify Git-bound preservation and retained Python controls; no Swift/UI claim."""
from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import re
from pathlib import Path


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def git_blob(data: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def strip_added_debug_blocks(source: str) -> str:
    output = []
    in_debug = False
    for line in source.splitlines(keepends=True):
        if line.strip() == "#if DEBUG":
            assert not in_debug, "Unexpected nested DEBUG section"
            in_debug = True
        elif in_debug and line.strip() == "#endif":
            in_debug = False
        elif not in_debug:
            output.append(line)
    assert not in_debug, "Unclosed DEBUG section"
    return "".join(output)


def verify(repo: Path, evidence: Path) -> dict:
    base_info = json.loads((evidence / "BASE_PROOF.json").read_text())
    base = {}
    for row in base_info["files"]:
        data = gzip.decompress((evidence / "raw/baseline" / (row["path"] + ".gz")).read_bytes())
        assert len(data) == row["bytes"] and digest(data) == row["sha256"], row["path"]
        assert git_blob(data) == row["git_blob"], row["path"]
        base[row["path"]] = data.decode("utf-8")

    field_path = "Source/ChavrusaText/Search/UI/NativeGlobalSearchField.swift"
    field = (repo / field_path).read_text()
    assert "#if DEBUG" not in base[field_path], "Baseline needs a separately reviewed inverse"
    assert strip_added_debug_blocks(field) == base[field_path], "Product statements changed outside new DEBUG blocks"

    test_path = "Maktabah-iOSUITests/GlobalSearchNativeAcceptanceTests.swift"
    tests = (repo / test_path).read_text()
    test_inverse = tests
    replacements = [
        ("recordNativePages: Bool = false, recordNativeFonts: Bool = false) throws {",
         "recordNativePages: Bool = false) throws {"),
        ('(recordNativePages ? ["-GlobalSearchNativeTraceEnabled", "YES"] : [])\n'
         '                           + (recordNativeFonts ? ["-GlobalSearchFontDiagnosticsEnabled", "YES"] : []),',
         '(recordNativePages ? ["-GlobalSearchNativeTraceEnabled", "YES"] : []),'),
        ("try launchSearch(recordNativeFonts: true)", "try launchSearch()"),
    ]
    for before, after in replacements:
        assert test_inverse.count(before) == 1, before
        test_inverse = test_inverse.replace(before, after)
    assert test_inverse == base[test_path], "Any original test statement, audit callback or oracle changed"
    test_ids = re.findall(r"\bfunc (test\w+)\s*\(", tests)
    assert test_ids == re.findall(r"\bfunc (test\w+)\s*\(", base[test_path])

    matrix_path = "Scripts/CI/run-faithful-ipad-matrix.py"
    matrix = (repo / matrix_path).read_text()
    extra = ('        if suite == "GlobalSearchNativeAcceptanceTests" and (\n'
             '                not separator or method == "testHeaderAndHistoryNativeAccessibilityAudit"):\n'
             '            return True\n')
    assert matrix.count(extra) == 1
    matrix_inverse = matrix.replace(extra, "").replace(
        '"""Retain the original log for routing and explicit Escape/font diagnostics."""',
        '"""Retain the original persistent log for routing and explicit Escape diagnostics."""')
    assert matrix_inverse == base[matrix_path], "Original collection/build/verification/budget logic changed"
    compile(matrix, matrix_path, "exec")
    collector_start = matrix.index("                if requires_native_log_collection(selection):")
    collector_end = matrix.index("                viewport_reports =", collector_start)
    collector = matrix[collector_start:collector_end]
    assert 'device["status"] = "EXECUTED_PASS" if code == 0 else "FAIL"' in matrix[:collector_start]
    assert '"Documents/OtzariaLogs/otzaria-reader.log"' in collector
    assert '"COLLECTION_ERROR"' in collector and '"MISSING"' in collector
    assert 'sha256=hashlib.sha256(retained_log.read_bytes()).hexdigest()' in collector

    # Structural safeguards only. These are not a Swift parser or a UIKit runtime.
    recorder = field[field.index("@MainActor private final class GlobalSearchFontDiagnosticRecorder"):]
    for forbidden in (".text", ".attributedText", ".accessibilityLabel", ".accessibilityValue", ".accessibilityHint"):
        assert not re.search(re.escape(forbidden) + r"\b", recorder), forbidden
    for forbidden in ("layoutIfNeeded(", "setNeedsLayout(", "Task {", "DispatchQueue", "Timer("):
        assert forbidden not in recorder, forbidden
    for fragment in (
        'arguments[flag + 1] == "YES"',
        'OtzariaDataProfileRegistry.activeProfileID == "miniTest10"',
        'UUID(uuidString: raw)',
        'guard !observing, field.window === window',
        'nodeLimit = 768', 'labelLimit = 64', 'snapshotLimit = 32', 'byteLimit = 65_536',
        'if nativeFontDiagnosticLayoutPending {',
        'nativeFontDiagnosticLayoutPending = false',
        'OtzariaFileLogger.shared.log($0)',
    ):
        assert fragment in field, fragment
    marker = "private final class GlobalSearchTextField: UISearchTextField {"
    assert field.count(marker) == 1
    standalone = "import UIKit\n" + field[field.index(marker):]
    assert "OtzariaFileLogger" not in standalone and "OtzariaDataProfileRegistry" not in standalone
    driver = base["Scripts/CI/typecheck-faithful-ui-tests.py"]
    assert 'native_field[native_field.index(native_field_marker):]' in driver
    assert '"import UIKit\\n"' in driver
    assert 'otzaria-reader.log' in base["Source/Otzaria/Debug/OtzariaFileLogger.swift"]

    execution = json.loads((evidence / "raw/COLLECTION_RESULT.json").read_text())
    fixture_path = "Tests/HQ/global-search-font-diagnostics/test_collection_contract.py"
    assert digest((repo / fixture_path).read_bytes()) == execution["script_sha256"]
    assert digest(matrix.encode()) == execution["source_sha256"]
    stdout = (evidence / "raw/collection.stdout.log").read_bytes()
    stderr = (evidence / "raw/collection.stderr.log").read_bytes()
    assert digest(stdout) == execution["stdout_sha256"] and digest(stderr) == execution["stderr_sha256"]
    leaves = re.findall(rb"^(test\w+) \([^\n]+\) \.\.\. ok$", stderr, flags=re.M)
    assert execution["exit_code"] == 0 and len(leaves) == len(set(leaves)) == 12
    assert b"Ran 12 tests" in stderr and stderr.rstrip().endswith(b"OK")

    issue = (evidence / "raw/DFFFAB3F-BE6C-43E1-A8FD-5B023C86093B.txt").read_bytes()
    assert len(issue) == 131 and digest(issue) == "2387bf852f884c895eba4f7d55c4d772d72cc399c2adbb2ccc2c89dc3e44e790"
    assert b"element=unavailable" in issue

    return {
        "status": "PASS_SOURCE_PRESERVATION_AND_RETAINED_PYTHON_EVIDENCE_ONLY",
        "base_commit": base_info["source"], "base_git_blobs_verified": len(base),
        "product_release_inverse": "BYTE_IDENTICAL",
        "original_test_and_audit_inverse": "BYTE_IDENTICAL",
        "original_matrix_inverse": "BYTE_IDENTICAL",
        "test_declarations_unchanged": len(test_ids),
        "retained_python_cases": len(leaves),
        "standalone_uikit_component_sha256": digest(standalone.encode()),
        "collector_block_sha256": digest(collector.encode()),
        "swift_parse_typecheck": "NOT_RUN", "native_ui": "NOT_RUN",
        "dynamic_type_cause": "UNRESOLVED_ELEMENT_UNAVAILABLE",
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[3])
    parser.add_argument("--evidence", type=Path, default=Path(__file__).resolve().parent)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = verify(args.repo.resolve(), args.evidence.resolve())
    encoded = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.write_text(encoded)
    print(encoded, end="")

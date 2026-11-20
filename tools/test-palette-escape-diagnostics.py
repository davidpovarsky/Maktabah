#!/usr/bin/env python3
"""Source-bound log collector checks; no app, UIKit, Simulator or GitHub execution."""
import argparse
import ast
import hashlib
import json
from pathlib import Path
import shutil
import tempfile
from datetime import datetime, timezone
from types import SimpleNamespace


def main():
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=root / "Scripts/CI/run-faithful-ipad-matrix.py")
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    raw = args.source.read_bytes()
    tree = ast.parse(raw, filename=str(args.source))
    collectors = [
        node for node in ast.walk(tree)
        if isinstance(node, ast.If) and node.body
        and isinstance(node.body[0], ast.Assign)
        and any(isinstance(target, ast.Name) and target.id == "native_dir"
                for target in node.body[0].targets)
    ]
    if len(collectors) != 1:
        raise SystemExit("Expected the one original native log collection block")
    collector = collectors[0]
    helpers = [node for node in tree.body
               if isinstance(node, ast.FunctionDef) and node.name == "requires_native_log_collection"]
    if len(helpers) > 1:
        raise SystemExit("Ambiguous log collection helper")
    globals_ = {}
    exec(compile(ast.fix_missing_locations(ast.Module(body=helpers, type_ignores=[])),
                 str(args.source), "exec"), globals_)
    gate = compile(ast.Expression(body=collector.test), str(args.source), "eval")
    body = compile(ast.fix_missing_locations(ast.Module(body=[collector], type_ignores=[])),
                   str(args.source), "exec")
    results = []

    def check(name, operation):
        try:
            operation()
            results.append({"name": name, "status": "PASS"})
        except Exception as error:
            results.append({"name": name, "status": "FAIL", "error": str(error)})

    def expect_gate(selection, expected):
        actual = eval(gate, globals_, {"selection": selection})
        assert actual is expected, f"selection={selection!r}: {actual!r} != {expected!r}"

    escape = "FaithfulReaderUIAcceptanceTests/testPointerHoverClickAndHardwareKeyboardDismissal"
    selections = [
        ("empty_selection_is_not_collected", [], False),
        ("original_routing_suite_is_collected", ["NativeRoutingAcceptanceTests"], True),
        ("original_routing_method_is_collected", ["NativeRoutingAcceptanceTests/testReader"], True),
        ("original_phone_suite_is_collected", ["NativeRoutingPhoneAcceptanceTests"], True),
        ("original_phone_method_is_collected", ["NativeRoutingPhoneAcceptanceTests/testReader"], True),
        ("exact_escape_case_is_collected", [escape], True),
        ("whole_original_faithful_suite_is_collected", ["FaithfulReaderUIAcceptanceTests"], True),
        ("other_faithful_method_does_not_opt_in", ["FaithfulReaderUIAcceptanceTests/testOther"], False),
        ("other_suite_same_method_does_not_opt_in", ["AnotherSuite/" + escape.split("/")[1]], False),
        ("escape_method_typo_does_not_opt_in", [escape + "Typo"], False),
        ("unrelated_suite_is_not_collected", ["OtherTests/testMethod"], False),
        ("mixed_release_selection_retains_escape_log", ["OtherTests/testMethod", escape], True),
    ]
    for name, selection, expected in selections:
        check(name, lambda selection=selection, expected=expected: expect_gate(selection, expected))

    args.out.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="collector-fixture-", dir=args.out.parent) as temporary:
        scratch = Path(temporary)
        fixture_index = 0

        def exercise(selection, expected, *, log_exists=True, container_error=False):
            nonlocal fixture_index
            fixture_index += 1
            folder = scratch / str(fixture_index)
            actual_container = folder / "actual-relocated-container"
            old_container = folder / "old-container"
            artifacts = folder / "artifacts"
            artifacts.mkdir(parents=True)
            log = actual_container / "Documents/OtzariaLogs/otzaria-reader.log"
            log.parent.mkdir(parents=True)
            payload = (b"2026-11-20T00:00:00Z [NativePaletteEscape] pid=1 seq=1 stage=adapter.appeared\n"
                       b"2026-11-20T00:00:01Z [ExistingOriginal] preserved\n")
            if log_exists:
                log.write_bytes(payload)
            calls = []

            def simctl_boundary(command, **kwargs):
                calls.append(command)
                assert command == [
                    "xcrun", "simctl", "get_app_container", "FIXTURE-UDID",
                    "com.davidpovarsky.chavrusatext", "data"
                ], "Only the existing container lookup is doubled"
                assert kwargs == {"text": True, "timeout": 45}
                if container_error:
                    raise RuntimeError("fixture_container_lookup_failure")
                return str(actual_container) + "\n"

            device = {"status": "FAIL", "executedXCTestCount": 1}
            namespace = dict(globals_)
            namespace.update({
                "selection": selection, "artifacts": artifacts, "label": "11",
                "udid": "FIXTURE-UDID", "container": str(old_container), "device": device,
                "Path": Path, "subprocess": SimpleNamespace(check_output=simctl_boundary),
                "shutil": shutil, "hashlib": hashlib, "json": json,
                "datetime": datetime, "timezone": timezone, "code": 1,
            })
            exec(body, namespace)
            assert device["status"] == "FAIL", "Collection must not convert failed UI to success"
            retained_dir = artifacts / "native-routing-logs-11"
            if expected is None:
                assert not calls and not retained_dir.exists()
                return
            assert len(calls) == 1, "Exactly one original lookup; no retry"
            report_file = retained_dir / "collection.json"
            assert report_file.exists(), "Original collector did not retain a report for this case"
            report = json.loads(report_file.read_text())
            assert report["status"] == expected, report
            assert device["nativeRoutingLog"] == report
            assert report["udid"] == "FIXTURE-UDID"
            assert report["bundleID"] == "com.davidpovarsky.chavrusatext"
            retained_log = retained_dir / "otzaria-reader.log"
            if expected == "RETAINED":
                assert report["actualContainer"] == str(actual_container)
                assert retained_log.read_bytes() == payload
                assert report["bytes"] == len(payload)
                assert report["sha256"] == hashlib.sha256(payload).hexdigest()
                assert report["artifact"] == str(Path("native-routing-logs-11") / "otzaria-reader.log"), report["artifact"]
            else:
                assert not retained_log.exists(), "No fabricated log on missing/error"
                assert "sha256" not in report

        check("original_routing_retains_exact_bytes_and_sha_after_failure",
              lambda: exercise(["NativeRoutingAcceptanceTests/testReader"], "RETAINED"))
        check("escape_failure_retains_actual_relocated_container_log",
              lambda: exercise([escape], "RETAINED"))
        check("missing_escape_log_remains_missing",
              lambda: exercise([escape], "MISSING", log_exists=False))
        check("escape_container_lookup_error_is_retained_without_retry",
              lambda: exercise([escape], "COLLECTION_ERROR", container_error=True))
        check("unselected_case_has_no_log_collection_side_effect",
              lambda: exercise(["FaithfulReaderUIAcceptanceTests/testOther"], None))

    assert args.source.read_bytes() == raw, "Input source changed during execution"
    record = {
        "schemaVersion": 1,
        "scope": "ACTUAL_PYTHON_COLLECTOR_WITH_EXPLICIT_SIMCTL_BOUNDARY_DOUBLE",
        "source": str(args.source), "sourceSHA256": hashlib.sha256(raw).hexdigest(),
        "collectorBodySHA256": hashlib.sha256(ast.get_source_segment(raw.decode(), collector).encode()).hexdigest(),
        "fixtureSHA256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "executed": len(results), "passed": sum(row["status"] == "PASS" for row in results),
        "failed": sum(row["status"] == "FAIL" for row in results),
        "nativeTestsExecuted": 0, "appleTypechecksExecuted": 0, "cases": results,
    }
    args.out.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps(record, indent=2))
    raise SystemExit(1 if record["failed"] else 0)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Only changed runtime-closure/dependency admission controls; no Apple credit."""
import argparse
import gzip
import hashlib
import json
from pathlib import Path
import re
import runpy
import sys
import tempfile


def rejected(operation):
    try:
        operation()
    except (RuntimeError, ValueError, OSError):
        return
    raise AssertionError("An unqualified or missing proof was accepted")


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--source-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--review-dir", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    ci = args.source_root.resolve() / "Scripts/CI"
    sdk = runpy.run_path(str(ci / "hq-original-editor-distribution.py"))
    native = runpy.run_path(str(ci / "runtime27-original-editor-native.py"))
    rows = []
    report = {"scope": "CHANGED_SOURCE_ADMISSION_CONTROLS_ONLY", "apple_build": "NOT_RUN",
              "nm_or_otool_executed": False, "native_tests": 0, "controls": rows,
              "prior_22_controls_reexecuted": False}

    def control(name, operation):
        operation()
        rows.append({"name": name, "status": "PASS"})

    try:
        def identical():
            pins = {"floatingpanel": "a" * 40, "swift-syntax": "b" * 40}
            value = sdk["shared_package_policy"](pins, pins)
            assert value["identical_revisions"] == sorted(pins)
            assert value["swift_syntax_requires_actual_runtime_absence"] is False
        control("identical_shared_revisions_do_not_claim_an_exception", identical)

        for identity in ["floatingpanel", "torahinspectorkit", "zipfoundation"]:
            control("different_runtime_revision_rejects_" + identity,
                    lambda name=identity: rejected(lambda: sdk["shared_package_policy"](
                        {name: "a" * 40}, {name: "b" * 40})))

        def exact_pair():
            app, other = sdk["SYNTAX_APP"], sdk["SYNTAX_SDK"]
            value = sdk["shared_package_policy"]({"swift-syntax": app}, {"swift-syntax": other})
            assert value == {"identical_revisions": [], "swift_syntax_requires_actual_runtime_absence": True}
            for a, b in [(other, app), (app, "0" * 40), ("1" * 40, other)]:
                rejected(lambda: sdk["shared_package_policy"]({"swift-syntax": a}, {"swift-syntax": b}))
        control("only_the_exact_observed_build_tool_pair_is_conditional", exact_pair)
        control("case_aliased_package_identity_is_rejected", lambda: rejected(lambda:
            sdk["shared_package_policy"]({"Swift-Syntax": "a", "swift-syntax": "b"}, {"swift-syntax": "a"})))

        def manifest_derivation():
            names = set()
            for revision, expected in sdk["SYNTAX_MANIFESTS"].items():
                raw = (args.review_dir / ("swift-syntax-" + revision + "-Package.swift")).read_bytes()
                assert hashlib.sha256(raw).hexdigest() == expected["sha256"]
                assert hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest() == expected["git_blob"]
                names.update(re.findall(r'\.(?:library|target|testTarget|executableTarget)\s*\(\s*name:\s*"([^"]+)"', raw.decode()))
            assert names == set(sdk["SYNTAX_NAMES"]) and len(names) == len(sdk["SYNTAX_NAMES"])
            for name in names:
                rejected(lambda value=name: sdk["require_no_syntax_names"](["Modules/" + value + ".swiftmodule"]))
        control("all_actual_manifest_products_and_targets_are_covered", manifest_derivation)

        with tempfile.TemporaryDirectory(prefix="original-editor-closure-control-") as temporary:
            work = Path(temporary)
            output = work / "symbols.txt"
            def complete_symbol_input():
                output.write_bytes(b"actual-image:\n0000000000001000 T _ordinary_symbol\n                 U _objc_msgSend\n")
                assert sdk["scan_binary_output"](output, symbols=True)["symbol_lines"] == 2
                for raw in [b"", b"actual-image:\n", b"nm: no symbols\n"]:
                    output.write_bytes(raw)
                    rejected(lambda: sdk["scan_binary_output"](output, symbols=True))
            control("missing_or_header_only_symbol_evidence_cannot_pass", complete_symbol_input)

            def full_scan():
                output.write_bytes(b"000000001000 T _ordinary_symbol\n" * 10_000 + b"0000000001 T _$s16SwiftDiagnostics6Notice\n")
                rejected(lambda: sdk["scan_binary_output"](output, symbols=True))
            control("associated_symbol_after_large_prefix_is_not_truncated", full_scan)

            def lossless():
                # Exercise the real subprocess/output-retention code using a
                # Python text producer; this is not a fabricated Mach-O pass.
                script = "import sys;sys.stdout.write('000000001000 T _ordinary_symbol\\n'*10000)"
                receipt = sdk["binary_command"]([sys.executable, "-c", script], root=work,
                    evidence=work / "logs", label="full-source-control", symbols=True)
                expected = b"000000001000 T _ordinary_symbol\n" * 10_000
                retained = work / "logs" / receipt["output"]
                assert gzip.decompress(retained.read_bytes()) == expected
                assert receipt["uncompressed_bytes"] == len(expected) and receipt["symbol_lines"] == 10_000
                assert receipt["sha256"] == hashlib.sha256(retained.read_bytes()).hexdigest()
            control("actual_subprocess_full_output_is_retained_losslessly", lossless)

            def command_failure():
                for name, script in [("nonzero", "print('0001 T _ordinary');raise SystemExit(3)"),
                                     ("empty", "pass")]:
                    rejected(lambda label=name, source=script: sdk["binary_command"](
                        [sys.executable, "-c", source], root=work, evidence=work / "logs", label=label, symbols=True))
            control("failed_or_empty_actual_command_cannot_qualify", command_failure)

            def image_identity():
                images = work / "images"
                images.mkdir()
                (images / "binary").write_bytes(b"\xcf\xfa\xed\xfe" + b"classification fixture, not valid native code")
                (images / "archive.a").write_bytes(b"!<arch>\n" + b"classification fixture, not a native archive")
                (images / "resource").write_bytes(b"ordinary resource")
                before = sdk["code_images"](images)
                assert set(before) == {"binary", "archive.a"}
                (images / "binary").write_bytes((images / "binary").read_bytes() + b"changed")
                assert sdk["code_images"](images) != before
                (images / "alias").symlink_to(images / "binary")
                rejected(lambda: sdk["code_images"](images))
            control("complete_image_membership_hashes_and_alias_rejection", image_identity)

            def dependency_preflight():
                route = work / "route"
                source_dir = route / "Scripts/CI"
                source_dir.mkdir(parents=True)
                names = ["runtime27.py", "run-faithful-ipad-matrix.py", "prepare-faithful-ipad-fixtures.py",
                         "runtime27-fixture-oracle.py", "verify-faithful-xctest.py",
                         "hq-original-editor-distribution.py", "restore-original-editor-distribution.py"]
                for name in names:
                    (source_dir / name).write_text("import json\nimport local_dependency\nraise AssertionError('Do not execute fixture scripts')\n")
                (source_dir / "local_dependency.py").write_text("import sqlite3\n")
                function = native["runtime_dependency_preflight"]
                function.__globals__.update(ROOT=route, OUT=route / "build/evidence")
                function()
                receipt = json.loads((route / "build/evidence/python-runtime-preflight.json").read_text())
                assert receipt["status"] == "SELECTED_ROUTE_IMPORT_PREFLIGHT_PASS"
                assert set(receipt["source_inputs"]) == set(names + ["local_dependency.py"])
                assert receipt["native_process_or_fixture_executed"] is False
                (source_dir / "local_dependency.py").write_text("import missing_original_editor_dependency\n")
                rejected(function)
            control("early_import_preflight_never_executes_fixture_and_rejects_missing_dependency", dependency_preflight)

        report.update(status="CHANGED_SOURCE_CONTROLS_PASS", passed=len(rows), failed=0)
        return 0
    except BaseException as error:
        report.update(status="CHANGED_SOURCE_CONTROLS_FAILED", passed=len(rows), failed=1,
                      error=type(error).__name__ + ": " + str(error))
        return 1
    finally:
        report["source_inputs"] = {path.relative_to(args.source_root.resolve()).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in [ci / "hq-original-editor-distribution.py", ci / "runtime27-original-editor-native.py", Path(__file__)]}
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
        print(json.dumps({key: report.get(key) for key in ["status", "passed", "failed", "error"]}))


if __name__ == "__main__":
    raise SystemExit(main())

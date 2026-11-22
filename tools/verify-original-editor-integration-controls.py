#!/usr/bin/env python3
"""Bounded filesystem/admission controls; no Apple or native execution credit."""
import argparse
import ast
import copy
import hashlib
import io
import json
import os
from pathlib import Path
import runpy
import stat
import subprocess
import sys
import tempfile
import zipfile

BASE = "fb6a88f4e6ac3b0bfe0adb0a8992e2b0c3af4b5d"


def rejected(operation):
    try:
        operation()
    except (RuntimeError, ValueError, OSError):
        return
    raise AssertionError("The unsafe or changed input was accepted")


def verify_unfinalized_admission(config, restore, work):
    # Keep this negative control valid after the real input manifest is frozen.
    candidate = copy.deepcopy(config)
    candidate["source_sha"] = "UNFINALIZED"
    candidate["artifact_id"] = 0
    rejected(lambda: restore["stage"](candidate, work / "evidence"))
    assert not (work / "evidence").exists()


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--source-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--base-stage2", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    root = args.source_root.resolve()
    ci = root / "Scripts/CI"
    sdk = runpy.run_path(str(ci / "hq-original-editor-distribution.py"))
    restore = runpy.run_path(str(ci / "restore-original-editor-distribution.py"))
    native = runpy.run_path(str(ci / "runtime27-original-editor-native.py"))
    rows = []

    def control(name, operation):
        operation()
        rows.append({"name": name, "status": "PASS"})

    report = {"scope": "ACTUAL_SOURCE_FILESYSTEM_ADMISSION_CONTROLS_ONLY", "apple_build": "NOT_RUN",
              "native_tests": 0, "ruby_execution": "NOT_RUN", "controls": rows}
    try:
        def source_syntax():
            for path in ci.glob("*.py"):
                ast.parse(path.read_bytes(), filename=str(path))
        control("python_sources_parse", source_syntax)

        def preserve_default():
            path = "Scripts/CI/hq-stage2-focused-apple.py"
            base = args.base_stage2.read_bytes() if args.base_stage2 else subprocess.check_output(
                ["git", "show", BASE + ":" + path], cwd=root)
            assert hashlib.sha256(base).hexdigest() == "4adf3ba0502b433b478b00eae696300f36d222caca474bee6d42642c428805d0"
            before = ast.parse(base)
            after = ast.parse((root / path).read_bytes())
            class RemoveOptionalIntegration(ast.NodeTransformer):
                def visit_Import(self, node):
                    return None if [value.name for value in node.names] == ["runpy"] else node
                def visit_Assign(self, node):
                    return None if any(isinstance(target, ast.Name) and target.id == "original_editor" for target in node.targets) else node
                def visit_If(self, node):
                    if any(isinstance(value, ast.Name) and value.id == "original_editor" for value in ast.walk(node.test)):
                        return None
                    if any(isinstance(value, ast.Attribute) and value.attr == "original_editor_admission" for value in ast.walk(node.test)):
                        return None
                    return self.generic_visit(node)
                def visit_Expr(self, node):
                    if any(isinstance(value, ast.Constant) and value.value == "--original-editor-admission" for value in ast.walk(node)):
                        return None
                    if any(isinstance(value, ast.Attribute) and value.attr == "original_editor_admission" for value in ast.walk(node)):
                        return None
                    return node
            after = RemoveOptionalIntegration().visit(copy.deepcopy(after))
            assert ast.dump(before, include_attributes=False) == ast.dump(after, include_attributes=False)
        control("original_stage2_default_ast_unchanged_after_removing_optional_branch", preserve_default)

        for forbidden in [["--preflight-only"], ["--build-for-testing", "--prepare-inputs-only"], []]:
            def deny_mode(options=forbidden):
                result = subprocess.run([sys.executable, str(ci / "hq-stage2-focused-apple.py"),
                    "--original-editor-admission", "Scripts/CI/runtime27-original-editor.inputs.json", *options],
                    cwd=root, text=True, capture_output=True, timeout=10)
                assert result.returncode != 0 and "requires the real Debug Simulator test build" in result.stderr
            control("optional_sdk_rejects_" + ("_".join(x.removeprefix("--") for x in forbidden) or "unsigned_build"), deny_mode)

        with tempfile.TemporaryDirectory(prefix="original-editor-integration-control-") as temporary:
            work = Path(temporary)
            source, target = work / "source/Product.bundle", work / "app/Product.bundle"
            source.mkdir(parents=True)
            (source / "Resources").mkdir()
            (source / "Resources/input.dat").write_bytes(b"original immutable resource bytes")
            (source / "Info.plist").write_bytes(b"original product metadata")
            initial = sdk["inventory"](source, metadata=True)

            def missing_copy():
                assert sdk["compare_or_copy"](source, target) == "COPIED_MISSING"
                assert sdk["inventory"](source, metadata=True) == initial == sdk["inventory"](target, metadata=True)
            control("missing_product_copy_retains_exact_bytes_and_modes", missing_copy)

            def same_reuse():
                before = {p.relative_to(target).as_posix(): (p.stat().st_ino, p.stat().st_mtime_ns)
                          for p in target.rglob("*")}
                assert sdk["compare_or_copy"](source, target) == "REUSED_IDENTICAL"
                assert before == {p.relative_to(target).as_posix(): (p.stat().st_ino, p.stat().st_mtime_ns)
                                  for p in target.rglob("*")}
            control("identical_existing_product_is_reused_without_rewriting", same_reuse)

            def different_bytes():
                file = target / "Resources/input.dat"
                file.write_bytes(b"existing unrelated app resource")
                before = sdk["inventory"](target, metadata=True)
                rejected(lambda: sdk["compare_or_copy"](source, target))
                assert before == sdk["inventory"](target, metadata=True)
                file.write_bytes((source / "Resources/input.dat").read_bytes())
            control("different_shared_resource_rejects_without_overwriting", different_bytes)

            def added_member():
                extra = target / "existing-extra.dat"
                extra.write_bytes(b"preserve existing member")
                rejected(lambda: sdk["compare_or_copy"](source, target))
                assert extra.read_bytes() == b"preserve existing member"
                extra.unlink()
            control("extra_existing_member_cannot_evade_collision_check", added_member)

            def changed_mode():
                file = target / "Info.plist"
                original = stat.S_IMODE(file.stat().st_mode)
                file.chmod(0o600 if original != 0o600 else 0o644)
                rejected(lambda: sdk["compare_or_copy"](source, target))
                file.chmod(original)
            control("different_transported_file_mode_rejects", changed_mode)

            def linked_target():
                alias = work / "alias.bundle"
                alias.symlink_to(target, target_is_directory=True)
                rejected(lambda: sdk["compare_or_copy"](source, alias))
                assert sdk["inventory"](source, metadata=True) == initial
            control("linked_destination_is_never_followed", linked_target)

            def linked_parent():
                outside = work / "outside"
                outside.mkdir()
                parent = work / "app-link"
                parent.symlink_to(outside, target_is_directory=True)
                rejected(lambda: sdk["compare_or_copy"](source, parent / "Product.bundle"))
                assert not (outside / "Product.bundle").exists()
            control("linked_destination_parent_is_never_followed", linked_parent)

            def linked_source():
                alias = source / "linked.dat"
                alias.symlink_to(source / "Info.plist")
                rejected(lambda: sdk["compare_or_copy"](source, work / "new/Product.bundle"))
                assert not (work / "new").exists()
                alias.unlink()
            control("source_alias_is_rejected_before_copy", linked_source)

            def owned_read():
                file = work / "receipt.json"
                file.write_bytes(b'{"actual":"receipt"}')
                assert native["read_regular"](file, 128, work) == file.read_bytes()
                rejected(lambda: native["read_regular"](file, 4, work))
                alias = work / "receipt-alias.json"
                alias.symlink_to(file)
                rejected(lambda: native["read_regular"](alias, 128, work))
                isolated = work / "separate-owner"
                isolated.mkdir()
                rejected(lambda: native["read_regular"](file, 128, isolated))
            control("named_receipt_reader_enforces_size_alias_and_owner_boundary", owned_read)

            def unfinalized():
                config = json.loads((ci / "runtime27-original-editor.inputs.json").read_text())
                verify_unfinalized_admission(config, restore, work)
            control("unfinalized_artifact_pins_reject_before_network_or_write", unfinalized)

            for label, names in [
                    ("ordinary_members", ["Frameworks/A.framework/A", "Bundles/B.bundle/en.lproj/Text.strings"]),
                    ("parent_traversal", ["../outside"]),
                    ("absolute_member", ["/outside"]),
                    ("case_alias", ["Frameworks/A", "frameworks/a"]),
                    ("backslash", ["Frameworks\\A"]),
                    ("symlink", ["link"])]:
                def zip_check(kind=label, members=names):
                    data = io.BytesIO()
                    with zipfile.ZipFile(data, "w") as zipped:
                        for name in members:
                            entry = zipfile.ZipInfo(name)
                            entry.create_system = 3
                            entry.external_attr = ((stat.S_IFLNK if kind == "symlink" else stat.S_IFREG) | 0o644) << 16
                            zipped.writestr(entry, b"small source-control input")
                    with zipfile.ZipFile(io.BytesIO(data.getvalue())) as zipped:
                        if kind == "ordinary_members":
                            assert set(restore["zip_members"](zipped)) == set(members)
                        else:
                            rejected(lambda: restore["zip_members"](zipped))
                control("original_sdk_zip_" + label, zip_check)

            def exact_callback():
                callback = native["OriginalEditorEvidence"]()
                callback.validate_selection(False, None, [native["SELECTOR"]])
                rejected(lambda: callback.validate_selection(True, None, [native["SELECTOR"]]))
                rejected(lambda: callback.validate_selection(False, {}, [native["SELECTOR"]]))
                rejected(lambda: callback.validate_selection(False, None, [native["SELECTOR"], "Other/testCase"]))
                assert callback.udid is None and callback.capture_attempted is False
            control("callback_admits_only_the_exact_separate_case", exact_callback)

        report.update(status="SOURCE_CONTROLS_PASS", passed=len(rows), failed=0)
        return 0
    except BaseException as error:
        report.update(status="SOURCE_CONTROLS_FAILED", passed=len(rows), failed=1,
                      error=type(error).__name__ + ": " + str(error))
        return 1
    finally:
        report["source_inputs"] = {str(path.relative_to(root)): hashlib.sha256(path.read_bytes()).hexdigest()
                                  for path in sorted(ci.glob("*")) if path.is_file()}
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
        print(json.dumps({key: report.get(key) for key in ["status", "passed", "failed", "error"]}))


if __name__ == "__main__":
    raise SystemExit(main())

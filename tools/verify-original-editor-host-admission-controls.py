#!/usr/bin/env python3
"""Only new compiled-Host receipt admission controls; no Apple/Native credit."""
import argparse
import ast
import copy
import hashlib
import json
from pathlib import Path
import runpy


def rejected(operation):
    try:
        operation()
    except (RuntimeError, ValueError):
        return
    raise AssertionError("Unqualified original Host prerequisite was accepted")


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--source-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--spi-scope-only", action="store_true")
    args = parser.parse_args()
    ci = args.source_root.resolve() / "Scripts/CI"
    distribution = ci / "hq-original-editor-distribution.py"
    runner = ci / "runtime27-original-editor-native.py"
    sdk = runpy.run_path(str(distribution))
    admit = sdk["require_compiled_host_api"]
    source = {
        "public_host_api": "EXPOSED_COMPILED_NATIVE_EDITOR_NOT_RUN",
        "editable_mount": "API_COMPILED_NATIVE_UI_NOT_RUN", "native_editor_ui_tests": 0,
        "compiled_consumer_api_probe_sha256": "a" * 64,
        "actual_public_surface": {"status": "ACTUAL_TARGET_PUBLIC_SURFACE_INSPECTED",
            "target": "AnytypeOriginalEditor", "reviewed_host_and_spi_requirements_observed": 21,
            "editable_mount_api": "EXPOSED_COMPILED_NATIVE_EDITOR_NOT_RUN",
            "qualification_spi_scope_verified": True, "public_host_scope_verified": True,
            "public_original_editor_or_writer_declarations": [],
            "own_public_symbols": [{"path": ["synthetic-source-control-" + str(index)],
                                    "identifier": "synthetic-" + str(index),
                                    "location": "file:///source-control-not-Apple.swift",
                                    "spi": index >= 16} for index in range(21)]},
        "verified_runtime_observations": [{"language": language,
            "status": "ACTUAL_IMPORT_LINK_RESOURCE_RUNTIME_PASS", "editable_mount": "NOT_EXPOSED"}
            for language in ["en", "he"]],
    }
    rows = []
    report = {"scope": "SYNTHETIC_QUALIFICATION_RECEIPT_AND_EXACT_SOURCE_DELTA_CONTROLS",
              "apple_build": "NOT_RUN", "native_editor_ui_tests": 0,
              "prior_22_and_13_source_controls_reexecuted": False,
              "spi_scope_only": args.spi_scope_only, "controls": rows}

    def control(name, operation):
        if args.spi_scope_only and name not in {
                "compiled_host_proof_preserves_full_surface_and_resource_only_scope",
                "actual_qualification_spi_and_public_scope_proofs_are_required"}:
            return
        operation()
        rows.append({"name": name, "status": "PASS"})

    try:
        def compiled_only():
            before = copy.deepcopy(source)
            receipt = admit(source)
            assert source == before
            assert receipt["native_editor_ui_tests"] == 0
            assert receipt["actual_public_surface"] == source["actual_public_surface"]
            assert receipt["editable_mount"] == "API_COMPILED_NATIVE_UI_NOT_RUN"
            assert all(value["editable_mount"] == "NOT_EXPOSED" for value in source["verified_runtime_observations"])
        control("compiled_host_proof_preserves_full_surface_and_resource_only_scope", compiled_only)

        def spi_scope():
            for name in ["qualification_spi_scope_verified", "public_host_scope_verified"]:
                for value in [None, False, "true", 1]:
                    changed = copy.deepcopy(source)
                    changed["actual_public_surface"][name] = value
                    rejected(lambda item=changed: admit(item))
            for value in [None, "false", 0, 1]:
                changed = copy.deepcopy(source)
                changed["actual_public_surface"]["own_public_symbols"][0]["spi"] = value
                rejected(lambda item=changed: admit(item))
            changed = copy.deepcopy(source)
            del changed["actual_public_surface"]["own_public_symbols"][0]["spi"]
            rejected(lambda: admit(changed))
        control("actual_qualification_spi_and_public_scope_proofs_are_required", spi_scope)

        def legacy():
            old = copy.deepcopy(source)
            for name in ["public_host_api", "compiled_consumer_api_probe_sha256"]:
                old.pop(name)
            old["editable_mount"] = old["actual_public_surface"]["editable_mount_api"] = "NOT_EXPOSED"
            old["actual_public_surface"]["reviewed_host_and_spi_requirements_observed"] = 0
            rejected(lambda: admit(old))
        control("historical_inspection_only_producer_cannot_admit_editable_host", legacy)

        def outer_fields():
            for name, values in {
                    "public_host_api": [None, "NOT_EXPOSED", "PASS"],
                    "editable_mount": [None, "NOT_EXPOSED", "NATIVE_PASS"],
                    "native_editor_ui_tests": [None, False, "0", 1]}.items():
                for value in values:
                    changed = copy.deepcopy(source)
                    changed[name] = value
                    rejected(lambda item=changed: admit(item))
        control("missing_wrong_or_overclaimed_outer_execution_fields_are_rejected", outer_fields)

        def actual_surface():
            cases = {"status": [None, "PASS"], "target": [None, "OtherModule"],
                     "reviewed_host_and_spi_requirements_observed": [None, 20, "21", True],
                     "editable_mount_api": [None, "NOT_EXPOSED"],
                     "public_original_editor_or_writer_declarations": [None, [{"path": ["BaseDocument"]}]],
                     "own_public_symbols": [None, [], source["actual_public_surface"]["own_public_symbols"][:20]]}
            for name, values in cases.items():
                for value in values:
                    changed = copy.deepcopy(source)
                    changed["actual_public_surface"][name] = value
                    rejected(lambda item=changed: admit(item))
            for value in [None, []]:
                changed = copy.deepcopy(source)
                changed["actual_public_surface"] = value
                rejected(lambda item=changed: admit(item))
        control("incomplete_wrong_or_unsafe_public_spi_verifier_proof_is_rejected", actual_surface)

        def probe_hash():
            for value in [None, "UNFINALIZED", "a" * 63, "G" * 64]:
                changed = copy.deepcopy(source)
                changed["compiled_consumer_api_probe_sha256"] = value
                rejected(lambda item=changed: admit(item))
        control("missing_or_malformed_actual_consumer_api_probe_hash_is_rejected", probe_hash)

        def original_distribution_guards():
            tree = ast.parse(distribution.read_bytes())
            assert sum(isinstance(node, ast.Call) and isinstance(node.func, ast.Name)
                       and node.func.id == "require_compiled_host_api" for node in ast.walk(tree)) == 1
            class RemoveOnlyHostDelta(ast.NodeTransformer):
                def visit_FunctionDef(self, node):
                    return None if node.name == "require_compiled_host_api" else self.generic_visit(node)
                def visit_Assign(self, node):
                    if any(isinstance(target, ast.Name) and target.id == "compiled_host_api" for target in node.targets):
                        return None
                    return self.generic_visit(node)
                def visit_Dict(self, node):
                    indices = [index for index, key in enumerate(node.keys)
                               if isinstance(key, ast.Constant) and key.value == "compiled_host_api"]
                    for index in reversed(indices):
                        del node.keys[index]
                        del node.values[index]
                    return self.generic_visit(node)
            original = RemoveOnlyHostDelta().visit(tree)
            actual = hashlib.sha256(ast.dump(original, include_attributes=False).encode()).hexdigest()
            assert actual == "234766ec87dfad790e593e928e2375376cfac7daa9ec81370e0b52a3c18966de"
        control("every_original_artifact_source_signature_consumer_resource_and_collision_guard_is_preserved", original_distribution_guards)

        def exact_new_consumer_source():
            tree = ast.parse(runner.read_bytes())
            assignment = [node for node in tree.body if isinstance(node, ast.Assign)
                          and any(isinstance(target, ast.Name) and target.id == "SOURCE" for target in node.targets)]
            assert len(assignment) == 1 and assignment[0].value.value == "e5dadac39b88e0a2fd9de989dc8f58f8c7cd07c5"
            assignment[0].value.value = "3566e9d09939583e8ddc4d489d44add01238d8c0"
            actual = hashlib.sha256(ast.dump(tree, include_attributes=False).encode()).hexdigest()
            assert actual == "a987cad1573f5020335faf68fd4a556258bf4a2568e59a0c68394468af361771"
        control("runner_source_pin_only_changes_to_reviewed_e5dadac3_consumer", exact_new_consumer_source)
        report.update(status="CHANGED_HOST_ADMISSION_CONTROLS_PASS", passed=len(rows), failed=0)
        return 0
    except BaseException as error:
        report.update(status="CHANGED_HOST_ADMISSION_CONTROLS_FAIL", passed=len(rows), failed=1,
                      error=type(error).__name__ + ": " + str(error))
        return 1
    finally:
        report["source_inputs"] = {str(path.relative_to(args.source_root.resolve())):
            hashlib.sha256(path.read_bytes()).hexdigest() for path in [distribution, runner, Path(__file__).resolve()]}
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
        print(json.dumps({key: report.get(key) for key in ["status", "passed", "failed", "error"]}))


if __name__ == "__main__":
    raise SystemExit(main())

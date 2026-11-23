"""Affected portable source/API admission controls; no native acceptance credit."""
import ast
import copy
from pathlib import Path
import runpy
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
NATIVE_PATH = ROOT / "Scripts/CI/runtime27-original-editor-native.py"
DISTRIBUTION_PATH = ROOT / "Scripts/CI/hq-original-editor-distribution.py"
NATIVE = runpy.run_path(str(NATIVE_PATH))
DISTRIBUTION = runpy.run_path(str(DISTRIBUTION_PATH))


class QualifiedDependencySourceControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        def original_bytes(source):
            return subprocess.check_output(
                ["git", "show", source + ":" + NATIVE["HOST_LOCK"]], cwd=ROOT, timeout=45)
        cls.before = original_bytes(NATIVE["ORIGINAL_SOURCE"])
        cls.after = original_bytes(NATIVE["SOURCE"])

    def verify(self, **changes):
        values = {"paths": [NATIVE["HOST_LOCK"], "Vendor/HanlinSDK"],
                  "before_hanlin": NATIVE["ORIGINAL_HANLIN"],
                  "after_hanlin": NATIVE["QUALIFIED_HANLIN"],
                  "before_lock": self.before, "after_lock": self.after}
        values.update(changes)
        return NATIVE["verify_qualified_dependency_delta"](**values)

    def test_actual_git_leaf_keeps_original_ui_and_test_trees(self):
        result = NATIVE["qualified_dependency_source"]()
        self.assertEqual(result["qualified_dependency_source"], "6ba33d848bda808181e6b3174c05bac5b3fd2d94")
        self.assertEqual(result["original_application_source"], "1969b2065469b55e38e42cbb838a469ffa6a80f7")
        self.assertTrue(result["original_interface_and_tests_unchanged"])
        self.assertFalse(result["native_stageb_qualified"])
        self.assertEqual(result, self.verify())

    def test_additional_app_or_test_change_is_rejected(self):
        for extra in ["Source/Features/Reader.swift", "Maktabah-iOSUITests/OriginalEditorAnnotationAcceptanceTests.swift"]:
            with self.subTest(path=extra), self.assertRaisesRegex(RuntimeError, "original application or test source"):
                self.verify(paths=sorted([NATIVE["HOST_LOCK"], "Vendor/HanlinSDK", extra]))

    def test_missing_host_lock_adoption_is_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "original application or test source"):
            self.verify(paths=["Vendor/HanlinSDK"])

    def test_different_hanlin_parent_or_candidate_is_rejected(self):
        for key in ["before_hanlin", "after_hanlin"]:
            with self.subTest(key=key), self.assertRaisesRegex(RuntimeError, "Hanlin identities"):
                self.verify(**{key: "0" * 40})

    def test_earlier_unqualified_core_pin_is_rejected(self):
        after = self.after.replace(NATIVE["QUALIFIED_CORE"].encode(), b"29c966cd881a6394329a898f9a0ce00c29d2a50d")
        with self.assertRaisesRegex(RuntimeError, "single-revision change"):
            self.verify(after_lock=after)

    def test_extra_lock_edit_is_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "single-revision change"):
            self.verify(after_lock=self.after + b"\n")

    def test_changed_original_lock_preimage_is_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "single-revision change"):
            self.verify(before_lock=self.before + b"\n")

    def test_actual_source_context_calls_dependency_admission(self):
        tree = ast.parse(NATIVE_PATH.read_bytes())
        function = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == "source_context")
        calls = [n for n in ast.walk(function) if isinstance(n, ast.Call)
                 and isinstance(n.func, ast.Name) and n.func.id == "qualified_dependency_source"]
        self.assertEqual(len(calls), 1)


def qualification(count):
    api = "EXPOSED_COMPILED_NATIVE_EDITOR_NOT_RUN"
    return {"public_host_api": api, "editable_mount": "API_COMPILED_NATIVE_UI_NOT_RUN",
            "native_editor_ui_tests": 0, "compiled_consumer_api_probe_sha256": "e" * 64,
            "actual_public_surface": {"status": "ACTUAL_TARGET_PUBLIC_SURFACE_INSPECTED",
                "target": "AnytypeOriginalEditor", "reviewed_host_and_spi_requirements_observed": count,
                "editable_mount_api": api, "qualification_spi_scope_verified": True,
                "public_host_scope_verified": True, "public_original_editor_or_writer_declarations": [],
                "own_public_symbols": [{"spi": False, "fixture_only": True} for _ in range(count)]}}


class CompletePublicContractControls(unittest.TestCase):
    def admit(self, value, **kwargs):
        return DISTRIBUTION["require_compiled_host_api"](value, **kwargs)

    def test_legacy_default_and_explicit_schemas_remain_exactly_38(self):
        for options in [{}, {"admission_schema": 1}, {"admission_schema": 2}]:
            with self.subTest(options=options):
                result = self.admit(qualification(38), **options)
                self.assertEqual(result["native_editor_ui_tests"], 0)
                self.assertEqual(result["actual_public_surface"]["reviewed_host_and_spi_requirements_observed"], 38)

    def test_complete_schema_requires_86_without_native_ui_credit(self):
        result = self.admit(qualification(86), admission_schema=3)
        self.assertEqual(result["native_editor_ui_tests"], 0)
        self.assertEqual(result["actual_public_surface"]["reviewed_host_and_spi_requirements_observed"], 86)

    def test_old_38_requirement_proof_cannot_qualify_complete_schema(self):
        with self.assertRaisesRegex(RuntimeError, "verifier prerequisite is incomplete"):
            self.admit(qualification(38), admission_schema=3)

    def test_complete_proof_cannot_relabel_legacy_schema(self):
        for schema in [1, 2]:
            with self.subTest(schema=schema), self.assertRaisesRegex(RuntimeError, "verifier prerequisite is incomplete"):
                self.admit(qualification(86), admission_schema=schema)

    def test_arbitrary_or_boolean_requirement_count_is_rejected(self):
        for count in [85, 87, True, "86"]:
            value = qualification(86)
            value["actual_public_surface"]["reviewed_host_and_spi_requirements_observed"] = count
            with self.subTest(count=count), self.assertRaisesRegex(RuntimeError, "verifier prerequisite is incomplete"):
                self.admit(value, admission_schema=3)

    def test_unsupported_or_coerced_schema_is_rejected(self):
        for schema in [0, 4, True, "3"]:
            with self.subTest(schema=schema), self.assertRaisesRegex(RuntimeError, "contract schema"):
                self.admit(qualification(86), admission_schema=schema)

    def test_missing_public_symbols_or_scope_proof_is_rejected(self):
        incomplete = qualification(86)
        incomplete["actual_public_surface"]["own_public_symbols"].pop()
        values = [incomplete]
        for key in ["qualification_spi_scope_verified", "public_host_scope_verified"]:
            value = qualification(86)
            value["actual_public_surface"][key] = False
            values.append(value)
        for index, value in enumerate(values):
            with self.subTest(index=index), self.assertRaisesRegex(RuntimeError, "verifier prerequisite is incomplete"):
                self.admit(value, admission_schema=3)

    def test_native_ui_credit_cannot_be_added_to_compiler_proof(self):
        value = qualification(86)
        value["native_editor_ui_tests"] = 1
        with self.assertRaisesRegex(RuntimeError, "compiled Host/API prerequisite"):
            self.admit(value, admission_schema=3)

    def test_legacy_retained_proof_cannot_supply_complete_schema(self):
        with self.assertRaisesRegex(RuntimeError, "own actual compiled public proof"):
            self.admit(qualification(86), admission_schema=3, retained_original={})

    def test_actual_admission_passes_the_authenticated_schema(self):
        tree = ast.parse(DISTRIBUTION_PATH.read_bytes())
        function = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == "admit")
        calls = [n for n in ast.walk(function) if isinstance(n, ast.Call)
                 and isinstance(n.func, ast.Name) and n.func.id == "require_compiled_host_api"]
        self.assertEqual(len(calls), 1)
        values = [k.value for k in calls[0].keywords if k.arg == "admission_schema"]
        self.assertEqual(len(values), 1)
        self.assertEqual(ast.dump(values[0]), ast.dump(ast.parse('config["schema"]', mode="eval").body))


if __name__ == "__main__":
    unittest.main()

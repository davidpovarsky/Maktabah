"""Portable rejection controls for the exact expanded public contract, not native UI proof."""
import copy
from pathlib import Path
import runpy
import unittest

CI = Path(__file__).resolve().parent
API = runpy.run_path(str(CI / "hq-original-editor-distribution.py"))
LEGACY = runpy.run_path(str(CI / "test_original_editor_stageb_admission.py"))


class MiniAppsPublicContractControls(unittest.TestCase):
    def qualification(self, production=False):
        contract = API["miniapps_public_contract"]()
        value = LEGACY["qualification"](176 if production else 198)
        symbols = [{"path": list(p), "spi": False, "fixture_only": True}
                   for p in contract["public"]]
        if not production:
            symbols += [{"path": list(p), "spi": True, "fixture_only": True}
                        for p in contract["debug"]]
        value["actual_public_surface"]["own_public_symbols"] = symbols
        if production:
            value.update(configuration="Release-Anytype", platform="iphoneos")
            value["actual_public_surface"].update(
                debug_qualification_requirements_absent=22,
                debug_qualification_symbols_observed=[])
        return value

    def admit(self, value, production=False):
        return API["require_compiled_host_api"](
            value, admission_schema=3, production=production,
            public_contract_sha256=API["MINIAPPS_PUBLIC_CONTRACT_SHA256"])

    def test_exact_debug_and_release_graph_counts_preserve_native_not_run(self):
        for production in [False, True]:
            with self.subTest(production=production):
                value = self.qualification(production)
                result = self.admit(value, production)
                self.assertEqual(result["native_editor_ui_tests"], 0)
        self.assertTrue(set(API["LOCAL_ANNOTATION_REQUIREMENTS"])
                        <= set(API["miniapps_public_contract"]()["public"]))

    def test_legacy_lifecycle_or_revision_counts_cannot_admit_miniapps(self):
        for count in [86, 111, 175, 197]:
            with self.subTest(count=count), self.assertRaisesRegex(RuntimeError, "verifier prerequisite"):
                self.admit(LEGACY["qualification"](count))

    def test_missing_restore_or_revision_method_rejected_despite_full_count(self):
        for method in ["restoreMiniAppsContext(_:)",
                       "prepareAnnotationReplacement(snapshot:revisionToken:sourceLifetime:sourceIsCurrent:onDrained:)"]:
            value = self.qualification()
            for symbol in value["actual_public_surface"]["own_public_symbols"]:
                if symbol["path"][-1] == method:
                    symbol["path"] = ["UnrelatedFixtureSymbol"]
                    break
            else:
                self.fail("Reviewed contract lost " + method)
            with self.subTest(method=method), self.assertRaisesRegex(RuntimeError, "lacks the reviewed"):
                self.admit(value)

    def test_terminal_native_owner_constructor_cannot_become_public(self):
        value = self.qualification()
        value["actual_public_surface"]["own_public_symbols"].append({
            "path": ["AnytypeOriginalEditorMiniAppsLaunch", "init()"], "spi": False})
        with self.assertRaisesRegex(RuntimeError, "public constructors"):
            self.admit(value)

    def test_new_contract_missing_in_configuration_rejected(self):
        local = runpy.run_path(str(CI / "original_editor_local_admission.py"))
        source = {"public_host_contract_sha256": API["MINIAPPS_PUBLIC_CONTRACT_SHA256"]}
        with self.assertRaisesRegex(RuntimeError, "exact committed"):
            local["validate_public_contract"]({}, source, API)


if __name__ == "__main__":
    unittest.main()

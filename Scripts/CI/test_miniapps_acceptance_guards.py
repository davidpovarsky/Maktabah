#!/usr/bin/env python3
"""Canonical MiniApps gate refusals; source integrity only, no native credit."""
import copy
import json
import os
from pathlib import Path
import plistlib
import runpy
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
IMAGE_MODULE = Path(__file__).with_name("miniapps_runtime_image_origin.py")
RUNNER_MODULE = Path(__file__).with_name("otzaria-miniapps-native.py")
IMAGE_TESTS = Path(__file__).with_name("test_miniapps_runtime_image_origin.py")
IMAGE_API = runpy.run_path(str(IMAGE_MODULE))
RUNNER_API = runpy.run_path(str(RUNNER_MODULE))
DIAGNOSTIC_FLAGS = (
    "MINIAPPS_NATIVE_RICH_ONLY_ORIGINAL_DB",
    "MINIAPPS_NATIVE_CALLBACK_ACCEPTANCE_ONLY",
    "MINIAPPS_RICH_ORIGINAL_TEXTSTUDIO_SEED",
    "MINIAPPS_RICH_ORIGINAL_PASTE_SEED",
)
FLAG_NAMES = tuple(name for flag in DIAGNOSTIC_FLAGS for name in (flag, "TEST_RUNNER_" + flag))


class CanonicalAcceptanceGuardTests(unittest.TestCase):
    def setUp(self):
        environment = {key: value for key, value in os.environ.items()
                       if key not in (*FLAG_NAMES, "PYTHONOPTIMIZE")}
        guard = patch.dict(os.environ, environment, clear=True)
        guard.start()
        self.addCleanup(guard.stop)

    def child(self, code, *arguments, python_options=(), environment=None):
        return subprocess.run(
            [sys.executable, *python_options, "-B", "-c", code, *map(str, arguments)],
            env=os.environ.copy() if environment is None else environment,
            capture_output=True, text=True, timeout=20)

    def assert_optimized_rejected(self, completed):
        self.assertNotEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("optimized Python", completed.stderr)

    def test_normal_python_preserves_canonical_configuration(self):
        expected = json.loads(RUNNER_API["INPUTS"].read_text())
        self.assertEqual(RUNNER_API["configuration"](), expected)
        completed = self.child("import runpy,sys; runpy.run_path(sys.argv[1])", IMAGE_MODULE)
        self.assertEqual(completed.returncode, 0, completed.stderr)

    def test_actual_optimized_python_processes_cannot_import_acceptance(self):
        code = "import runpy,sys; runpy.run_path(sys.argv[1])"
        for options in (("-I", "-O"), ("-I", "-OO")):
            with self.subTest(options=options):
                self.assert_optimized_rejected(self.child(code, IMAGE_MODULE, python_options=options))
        environment = {**os.environ, "PYTHONOPTIMIZE": "1"}
        with self.subTest(environment="PYTHONOPTIMIZE=1"):
            self.assert_optimized_rejected(self.child(code, IMAGE_MODULE, environment=environment))

    def test_actual_optimized_canonical_configuration_is_rejected(self):
        code = "import runpy,sys; runpy.run_path(sys.argv[1])['configuration']()"
        self.assert_optimized_rejected(self.child(code, RUNNER_MODULE, python_options=("-I", "-O")))

    def test_optimized_process_cannot_accept_known_wrong_uuid_fixture(self):
        # Execute the existing independent mismatch fixture, not a replacement audit.
        code = """import runpy,sys
api = runpy.run_path(sys.argv[1])
case = api['ImageOriginIntegrityTests']('test_rejects_loaded_uuid_mismatch')
try:
    case.setUp()
    accepted = case.observe(uuid='FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF')
    print('SOURCE_INTEGRITY_FIXTURE_WRONG_UUID_ACCEPTED=' + str(accepted))
finally:
    case.doCleanups()
"""
        self.assert_optimized_rejected(self.child(code, IMAGE_TESTS, python_options=("-I", "-O")))

    def test_canonical_configuration_rejects_every_diagnostic_name_by_presence(self):
        for name in FLAG_NAMES:
            for value in ("", "0", "1"):
                with self.subTest(name=name, value=value), patch.dict(os.environ, {name: value}):
                    with self.assertRaisesRegex(RuntimeError, name):
                        RUNNER_API["configuration"]()

    def configuration_fixture(self):
        temporary = tempfile.TemporaryDirectory(prefix="miniapps-acceptance-guard-")
        self.addCleanup(temporary.cleanup)
        base = Path(temporary.name)
        derived = base / "derived"
        products = derived / "Build/Products"
        products.mkdir(parents=True)
        app = products / "Debug-iphonesimulator/Maktabah.app"
        evidence = base / "evidence"
        evidence.mkdir()
        original = {
            "Maktabah-iOSUITests": {
                "IsUITestBundle": True,
                "UITargetAppPath": "__TESTROOT__/Debug-iphonesimulator/Maktabah.app",
                "OnlyTestIdentifiers": RUNNER_API["SELECTORS"],
                "UITargetAppEnvironmentVariables": {"ORIGINAL_APP_SETTING": "keep"},
                "EnvironmentVariables": {"ORIGINAL_RUNNER_SETTING": "keep"},
            },
            "Maktabah-iOSNativeTests": {
                "EnvironmentVariables": {"NATIVE_INSTRUMENTATION": "keep"},
                "OnlyTestIdentifiers": ["OriginalUnit"],
            },
            "TestConfigurations": [{"TestTargets": [{"EnvironmentVariables": {"NESTED_SETTING": "keep"}}]}],
        }
        return derived, app, evidence, original

    def assert_configuration_rejected_without_output(self, name, original):
        derived, app, evidence, _ = self.configuration_fixture()
        path = derived / "Build/Products/Maktabah-iOS_fixture.xctestrun"
        raw = plistlib.dumps(original)
        path.write_bytes(raw)
        with self.assertRaisesRegex(RuntimeError, name):
            IMAGE_API["create_bundled_ui_configuration"](ROOT, evidence, app, derived)
        self.assertEqual(path.read_bytes(), raw)
        self.assertEqual(list(evidence.iterdir()), [])

    def test_final_configuration_rejects_inherited_diagnostic_names(self):
        _, _, _, original = self.configuration_fixture()
        for name in FLAG_NAMES:
            for value in ("", "0", "1"):
                with self.subTest(name=name, value=value), patch.dict(os.environ, {name: value}):
                    self.assert_configuration_rejected_without_output(name, original)

    def test_final_configuration_rejects_diagnostic_keys_in_every_environment(self):
        _, _, _, original = self.configuration_fixture()
        locations = (
            ("Maktabah-iOSUITests", "UITargetAppEnvironmentVariables"),
            ("Maktabah-iOSUITests", "EnvironmentVariables"),
            ("Maktabah-iOSNativeTests", "EnvironmentVariables"),
            ("TestConfigurations", 0, "TestTargets", 0, "EnvironmentVariables"),
        )
        for name in FLAG_NAMES:
            for location in locations:
                with self.subTest(name=name, location=location):
                    data = copy.deepcopy(original)
                    environment = data
                    for key in location:
                        environment = environment[key]
                    environment[name] = "1"
                    self.assert_configuration_rejected_without_output(name, data)

    def test_clean_configuration_preserves_original_targets_selectors_and_environment(self):
        derived, app, evidence, original = self.configuration_fixture()
        ui = original["Maktabah-iOSUITests"]
        # These are existing acceptance inputs, not diagnostic branch selection.
        ui["EnvironmentVariables"].update({
            "MINIAPPS_NATIVE_SHARED_GROUP": "/original/group",
            "TEST_RUNNER_MINIAPPS_PICKER_EXPECTED_DEVICE": "iphone",
            "ORIGINAL_TEXT_VALUE": DIAGNOSTIC_FLAGS[0],
        })
        path = derived / "Build/Products/Maktabah-iOS_fixture.xctestrun"
        raw = plistlib.dumps(original)
        path.write_bytes(raw)
        output = IMAGE_API["create_bundled_ui_configuration"](ROOT, evidence, app, derived)
        actual = plistlib.loads(output.read_bytes())
        self.assertEqual(actual["Maktabah-iOSNativeTests"], original["Maktabah-iOSNativeTests"])
        self.assertEqual(actual["TestConfigurations"], original["TestConfigurations"])
        self.assertEqual(actual["Maktabah-iOSUITests"]["OnlyTestIdentifiers"], RUNNER_API["SELECTORS"])
        self.assertEqual(actual["Maktabah-iOSUITests"]["EnvironmentVariables"], ui["EnvironmentVariables"])
        self.assertEqual(path.read_bytes(), raw)
        self.assertEqual((evidence / "original-built.xctestrun").read_bytes(), raw)


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""New lexical-link export controls only; these fixtures contain no native binaries."""
import importlib.util
import json
from pathlib import Path
import plistlib
import tarfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("existing_product_fixture",
    ROOT / "tools/test-miniapps-native-product-export.py")
fixtures = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixtures)


class NativeProductAliasClosureTests(unittest.TestCase):
    def setUp(self):
        self.fixture = fixtures.NativeProductArchiveClosureTests()
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)
        self.real = self.fixture.debug / "Referenced.bundle"
        self.real.mkdir()
        (self.real / "resource.fixture").write_bytes(b"original referenced resource")

    def configure_alias(self):
        self.fixture.configuration["TestConfigurations"][0]["TestTargets"][0]["DependentProductPaths"] = [
            "__TESTROOT__/Debug-iphonesimulator/FirstAlias.bundle"]
        self.fixture.plan.write_bytes(plistlib.dumps(self.fixture.configuration))

    def test_unchanged_xctestrun_alias_chain_is_relocatable(self):
        (self.fixture.debug / "FirstAlias.bundle").symlink_to("SecondAlias.bundle", target_is_directory=True)
        (self.fixture.debug / "SecondAlias.bundle").symlink_to("Referenced.bundle", target_is_directory=True)
        self.configure_alias()
        original_plan = self.fixture.plan.read_bytes()
        self.fixture.context["export_built_products"]()
        manifest = json.loads((self.fixture.output / "native-products-manifest.json").read_text())
        with tarfile.open(self.fixture.output / manifest["archive_name"], "r:gz") as archive:
            names = set(archive.getnames())
            first = "Debug-iphonesimulator/FirstAlias.bundle"
            second = "Debug-iphonesimulator/SecondAlias.bundle"
            self.assertTrue(archive.getmember(first).issym())
            self.assertEqual(archive.getmember(first).linkname, "SecondAlias.bundle")
            self.assertTrue(archive.getmember(second).issym())
            self.assertEqual(archive.getmember(second).linkname, "Referenced.bundle")
            self.assertIn("Debug-iphonesimulator/Referenced.bundle/resource.fixture", names)
            self.assertFalse(any(name.startswith(first + "/") or name.startswith(second + "/") for name in names))
            self.assertTrue(set(manifest["files"]) <= names)
            self.assertEqual(archive.extractfile("fixture.xctestrun").read(), original_plan)
            restored = self.fixture.root / "restored-products"
            archive.extractall(restored, filter="data")
        raw = plistlib.loads((restored / "fixture.xctestrun").read_bytes())["TestConfigurations"][0]["TestTargets"][0]["DependentProductPaths"][0]
        actual = Path(raw.replace("__TESTROOT__", str(restored))) / "resource.fixture"
        self.assertEqual(actual.read_bytes(), b"original referenced resource")
        self.assertIn(first, manifest["original_test_product_references"])
        self.assertEqual(manifest["native_ui_acceptance"], "NOT_RUN_AT_EXPORT")

    def test_alias_chain_cannot_depend_on_an_unexported_external_hop(self):
        external = self.fixture.products.parent / "ExternalAlias.bundle"
        external.symlink_to("Products/Debug-iphonesimulator/Referenced.bundle", target_is_directory=True)
        (self.fixture.debug / "FirstAlias.bundle").symlink_to("../../ExternalAlias.bundle", target_is_directory=True)
        self.configure_alias()
        with self.assertRaisesRegex(RuntimeError, "outside Products"):
            self.fixture.context["export_built_products"]()
        self.assertFalse((self.fixture.output / "native-products-manifest.json").exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)

#!/usr/bin/env python3
"""Check native product archive closure using temporary files, without Apple tests."""
import ast
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import tarfile
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Scripts/CI/otzaria-miniapps-native.py"


class NativeProductArchiveClosureTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="miniapps-product-archive-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.products = self.root / "build/DerivedData/Build/Products"
        self.debug = self.products / "Debug-iphonesimulator"
        self.app = self.debug / "Maktabah.app"
        self.runner = self.debug / "Maktabah-iOSUITests-Runner.app"
        self.test_bundle = self.runner / "PlugIns/Maktabah-iOSUITests.xctest"
        for path in [self.app, self.runner, self.test_bundle]:
            path.mkdir(parents=True, exist_ok=True)
            (path / "fixture.txt").write_text("Archive fixture only, not compiled native code.")
        self.output = self.root / "build/artifacts/miniapps-native"
        self.output.mkdir(parents=True)
        build = self.root / "build/hq-stage2/result.json"
        build.parent.mkdir(parents=True)
        build.write_text(json.dumps({
            "status": "SIMULATOR_BUILD_FOR_REAL_UI_PASS", "checkout_sha": "a" * 40,
            "application_source_sha": "b" * 40, "hanlin_gitlink": "c" * 40,
            "application_trees": {}, "xcode": "fixture", "swift": "fixture", "sdk_version": "fixture"}))
        self.plan = self.products / "fixture.xctestrun"
        self.configuration = {"TestConfigurations": [{"TestTargets": [{
            "TestHostPath": "__TESTROOT__/Debug-iphonesimulator/Maktabah-iOSUITests-Runner.app",
            "TestBundlePath": "__TESTHOST__/PlugIns/Maktabah-iOSUITests.xctest",
            "UITargetAppPath": "__TESTROOT__/Debug-iphonesimulator/Maktabah.app",
            "DependentProductPaths": []}]}]}
        def require(condition, message):
            if not condition:
                raise RuntimeError(message)
        def write(path, value):
            path.write_text(json.dumps(value))
        self.context = {"Path": Path, "plistlib": plistlib, "tarfile": tarfile, "re": re,
                        "os": os, "json": json, "ROOT": self.root, "OUT": self.output,
                        "require": require, "write": write,
                        "digest": lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest(),
                        "git": lambda *args: "unit-archive-fixture-only", "binaries": lambda: {}}
        tree = ast.parse(SOURCE.read_text())
        node = next(node for node in tree.body if isinstance(node, ast.FunctionDef)
                    and node.name == "export_built_products")
        exec(compile(ast.Module(body=[node], type_ignores=[]), str(SOURCE), "exec"), self.context)
        patcher = mock.patch.dict(os.environ, {"EXPECTED_CHECKOUT_SHA": "a" * 40})
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_archive_includes_sibling_symlink_and_xctestrun_product_closure(self):
        framework = self.debug / "Shared.framework"
        framework.mkdir()
        (framework / "native.fixture").write_bytes(b"fixture framework")
        (self.app / "native.fixture").symlink_to("../Shared.framework/native.fixture")
        resource = self.debug / "Referenced.bundle"
        resource.mkdir()
        (resource / "resource.fixture").write_text("fixture resource")
        self.configuration["TestConfigurations"][0]["TestTargets"][0]["DependentProductPaths"] = [
            "__TESTROOT__/Debug-iphonesimulator/Referenced.bundle"]
        self.plan.write_bytes(plistlib.dumps(self.configuration))
        self.context["export_built_products"]()
        manifest = json.loads((self.output / "native-products-manifest.json").read_text())
        archive = self.output / manifest["archive_name"]
        self.assertEqual(hashlib.sha256(archive.read_bytes()).hexdigest(), manifest["archive_sha256"])
        with tarfile.open(archive, "r:gz") as actual:
            names = set(actual.getnames())
            self.assertIn("Debug-iphonesimulator/Shared.framework/native.fixture", names)
            self.assertIn("Debug-iphonesimulator/Referenced.bundle/resource.fixture", names)
            self.assertEqual(actual.getmember("Debug-iphonesimulator/Maktabah.app/native.fixture").linkname,
                             "../Shared.framework/native.fixture")
            self.assertTrue(set(manifest["files"]) <= names)
        self.assertIn("Debug-iphonesimulator/Referenced.bundle",
                      manifest["original_test_product_references"])
        self.assertEqual(manifest["native_ui_acceptance"], "NOT_RUN_AT_EXPORT")

    def test_original_test_product_parent_traversal_rejected(self):
        external = self.products.parent / "outside.bundle"
        external.mkdir()
        self.configuration["TestConfigurations"][0]["TestTargets"][0]["DependentProductPaths"] = [
            "__TESTROOT__/../outside.bundle"]
        self.plan.write_bytes(plistlib.dumps(self.configuration))
        with self.assertRaisesRegex(RuntimeError, "outside Products"):
            self.context["export_built_products"]()
        self.assertFalse((self.output / "native-products-manifest.json").exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)

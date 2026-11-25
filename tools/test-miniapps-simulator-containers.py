#!/usr/bin/env python3
"""Focused filesystem admission checks, not Simulator or MiniApps acceptance."""
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest
from unittest import mock
import uuid

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("miniapps_native_containers",
    ROOT / "Scripts/CI/miniapps-simulator-containers.py")
resolver = importlib.util.module_from_spec(spec)
spec.loader.exec_module(resolver)


class NativeContainerAdmissionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="miniapps-container-admission-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.home = self.root / "home"
        self.udid = str(uuid.uuid4()).upper()
        self.data = self.home / "Library/Developer/CoreSimulator/Devices" / self.udid / "data"
        self.bundle = resolver.CONSUMER
        self.source = self.root / "build/DerivedData/Build/Products/Debug-iphonesimulator/Maktabah.app"
        self.source.mkdir(parents=True)
        self.info = {"CFBundleIdentifier": self.bundle, "CFBundleExecutable": "Maktabah"}
        (self.source / "Info.plist").write_bytes(plistlib.dumps(self.info))
        (self.source / "Maktabah").write_bytes(b"unit fixture executable identity")
        (self.source / "Maktabah.debug.dylib").write_bytes(b"unit fixture dylib identity")
        self.app_container = self.container("Containers/Bundle/Application", self.bundle)
        self.app = self.app_container / "Maktabah.app"
        self.app.mkdir()
        for source in self.source.iterdir():
            (self.app / source.name).write_bytes(source.read_bytes())
        self.private = self.container("Containers/Data/Application", self.bundle)
        self.group = self.container("Containers/Shared/AppGroup", "group.com.itorah.shared")
        for obj, attr, value in [(resolver, "ROOT", self.root),
                                 (resolver, "AUDIT", self.root / "audit.jsonl"),
                                 (resolver.Path, "home", mock.Mock(return_value=self.home))]:
            patcher = mock.patch.object(obj, attr, value)
            patcher.start()
            self.addCleanup(patcher.stop)
        patcher = mock.patch.dict(os.environ, {resolver.ENABLED: "1", resolver.OWNED: self.udid})
        patcher.start()
        self.addCleanup(patcher.stop)

    def container(self, relative, identifier):
        path = self.data / relative / str(uuid.uuid4()).upper()
        path.mkdir(parents=True)
        (path / resolver.METADATA).write_bytes(plistlib.dumps({"MCMMetadataIdentifier": identifier}))
        return path

    def native_timeout(self, args, **kwargs):
        if args[2:4] == ["list", "devices"]:
            return json.dumps({"devices": {"current": [{"udid": self.udid, "state": "Booted",
                                                       "dataPath": str(self.data)}]}})
        if args[2] == "get_app_container":
            raise subprocess.TimeoutExpired(args, kwargs["timeout"])
        self.fail("Unexpected native subprocess")

    def test_exact_installed_identity_and_metadata_resolve(self):
        app, images = resolver.installed_app(self.data, self.bundle, self.source)
        self.assertEqual(app, self.app)
        self.assertEqual(set(images), {"Info.plist", "Maktabah", "Maktabah.debug.dylib"})
        self.assertEqual(resolver.metadata_container(self.data, "Containers/Data/Application", self.bundle), self.private)

    def test_different_installed_executable_rejected(self):
        (self.app / "Maktabah").write_bytes(b"different native code image")
        with self.assertRaisesRegex(RuntimeError, "image differs"):
            resolver.installed_app(self.data, self.bundle, self.source)

    def test_different_installed_info_rejected(self):
        changed = dict(self.info, CFBundleVersion="different")
        (self.app / "Info.plist").write_bytes(plistlib.dumps(changed))
        with self.assertRaisesRegex(RuntimeError, "image differs"):
            resolver.installed_app(self.data, self.bundle, self.source)

    def test_duplicate_group_metadata_rejected(self):
        self.container("Containers/Shared/AppGroup", "group.com.itorah.shared")
        with self.assertRaisesRegex(RuntimeError, "Expected one"):
            resolver.metadata_container(self.data, "Containers/Shared/AppGroup", "group.com.itorah.shared")

    def test_redirected_native_parent_rejected(self):
        root = self.data / "Containers/Data/Application"
        moved = self.root / "foreign-data"
        root.rename(moved)
        root.symlink_to(moved, target_is_directory=True)
        with self.assertRaisesRegex(RuntimeError, "redirected"):
            resolver.metadata_container(self.data, "Containers/Data/Application", self.bundle)

    def test_other_simulator_identity_rejected_before_native_query(self):
        with mock.patch.object(resolver.subprocess, "check_output") as native:
            with self.assertRaisesRegex(RuntimeError, "exact disposable"):
                resolver.owned_data_path(str(uuid.uuid4()).upper())
            native.assert_not_called()

    def test_timeout_remains_recorded_without_reinstall_or_repeated_query(self):
        before = {str(path.relative_to(self.data)) for path in self.data.rglob("*")}
        with mock.patch.object(resolver.subprocess, "check_output", side_effect=self.native_timeout) as native:
            first = resolver.resolve_container(self.udid, self.bundle, "app", source_app=self.source)
            second = resolver.resolve_container(self.udid, self.bundle, "app", source_app=self.source)
        self.assertEqual(first, self.app)
        self.assertEqual(second, self.app)
        self.assertEqual(sum(call.args[0][2] == "get_app_container" for call in native.call_args_list), 1)
        self.assertEqual(before, {str(path.relative_to(self.data)) for path in self.data.rglob("*")})
        rows = [json.loads(line) for line in resolver.AUDIT.read_text().splitlines()]
        self.assertEqual(rows[0]["status"], "NATIVE_QUERY_TIMEOUT")
        self.assertEqual([row["status"] for row in rows[1:]], ["ACTUAL_MCM_IDENTITY_RESOLVED"] * 2)
        self.assertTrue(all(row["native_ui_acceptance"] == "STILL_REQUIRED" for row in rows[1:]))

    def test_existing_group_without_installed_entitlement_rejected(self):
        before = {str(path.relative_to(self.data)) for path in self.data.rglob("*")}
        with mock.patch.object(resolver.subprocess, "check_output", side_effect=self.native_timeout), \
                mock.patch.object(resolver, "entitled_groups", return_value=["group.another.app"]):
            with self.assertRaisesRegex(RuntimeError, "does not declare"):
                resolver.resolve_container(self.udid, self.bundle, "group.com.itorah.shared")
        self.assertEqual(before, {str(path.relative_to(self.data)) for path in self.data.rglob("*")})


if __name__ == "__main__":
    unittest.main(verbosity=2)

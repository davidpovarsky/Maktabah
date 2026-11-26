#!/usr/bin/env python3
"""Integrity refusals for the recovered observer; no simulator acceptance credit."""
import hashlib
import plistlib
from pathlib import Path
import runpy
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
API = runpy.run_path(str(Path(__file__).with_name("miniapps_runtime_image_origin.py")))
UUID = "01234567-89AB-CDEF-0123-456789ABCDEF"


class ImageOriginIntegrityTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="miniapps-image-origin-")
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.built = self.base / "built/Qualified.app"
        self.installed = self.base / "installed/Qualified.app"
        self.built.mkdir(parents=True)
        (self.built / "Info.plist").write_bytes(plistlib.dumps({
            "CFBundleIdentifier": "test.original.producer", "CFBundleExecutable": "Qualified",
            "CFBundleDisplayName": "Qualified",
        }))
        self.names = ["Qualified", "Qualified.debug.dylib", "Frameworks/NativeScript.framework/NativeScript"]
        for name in self.names:
            path = self.built / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(("SOURCE INTEGRITY FIXTURE " + name).encode())
        shutil.copytree(self.built, self.installed)
        self.audit = API["ImageAudit"](
            ROOT, self.base / "evidence", self.built, bundle_id="test.original.producer",
            runner_bundle_id="test.original.runner", required_images=[self.names[-1]])
        self.audit.artifact_uuids = lambda relative: {
            "uuids": [UUID], "architectures": ["arm64"],
            "evidence": "UNIT_METADATA_ONLY", "evidence_sha256": "0" * 64}

    def observe(self, paths=None, sample_paths=None, uuid=UUID, pid=123, report_pid=None):
        paths = paths or [self.installed / name for name in self.names]
        sample_paths = paths if sample_paths is None else sample_paths
        header = f"Process: Qualified [{report_pid or pid}]\nPath: {self.installed / 'Qualified'}\n"
        vmmap = header + "".join(f"__TEXT 1000-2000 [ 4K] r-x/r-x SM=COW {path}\n" for path in paths)
        sample = header + "Binary Images:\n" + "".join(
            f"0x1000 - 0x2000 +Qualified (1) <{uuid}> {path}\n" for path in sample_paths)
        (self.audit.out / "vmmap.txt").write_text(vmmap)
        (self.audit.out / "sample.txt").write_text(sample)
        return self.audit.observe(pid, self.installed, vmmap, "vmmap.txt",
                                  "ACTUAL_ORIGINAL_APP_UI", sample, "sample.txt")

    def test_accepts_actual_paths_matching_artifact_hash_and_uuid(self):
        self.assertTrue(self.observe())
        self.assertEqual(len(self.audit.rows[0]["private_images"]), 3)
        self.assertTrue(all(row["loaded_uuid"] == UUID for row in self.audit.rows[0]["private_images"]))

    def test_rejects_wrong_pid_report(self):
        with self.assertRaisesRegex(AssertionError, "Wrong actual process"):
            self.observe(report_pid=999)

    def test_rejects_changed_installed_private_bytes(self):
        (self.installed / "Qualified.debug.dylib").write_bytes(b"different installed image")
        with self.assertRaisesRegex(AssertionError, "Private image differs"):
            self.observe()

    def test_rejects_loaded_uuid_mismatch(self):
        with self.assertRaisesRegex(AssertionError, "UUID differs"):
            self.observe(uuid="FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")

    def test_rejects_vmmap_private_image_without_sampled_uuid(self):
        paths = [self.installed / name for name in self.names]
        with self.assertRaisesRegex(AssertionError, "no actual sampled UUID"):
            self.observe(paths=paths, sample_paths=paths[:-1])

    def test_rejects_debug_image_relocated_to_build_directory(self):
        paths = [self.installed / self.names[0], self.built / self.names[1], self.installed / self.names[2]]
        with self.assertRaisesRegex(AssertionError, "outside installed main bundle"):
            self.observe(paths=paths)

    def test_rejects_foreign_private_image(self):
        paths = [self.installed / name for name in self.names] + [self.base / "unqualified/Foreign.dylib"]
        with self.assertRaisesRegex(AssertionError, "Foreign loaded image"):
            self.observe(paths=paths)

    def test_requires_independent_xctest_pid_references(self):
        self.observe()
        result = self.audit.finish()
        self.assertEqual(result["status"], "IMAGE_ORIGIN_INCOMPLETE")

    def test_accepts_independent_xctest_pid_and_rejects_missing_pid(self):
        self.observe()
        log = self.base / "actual-ui.log"
        log.write_text("OTZARIA_MINIAPPS_IMAGE_PID bundle=test.original.producer pid=123 phase=native-ui\n")
        self.assertEqual(self.audit.finish(log_paths=[log])["status"], "PASS")
        log.write_text(log.read_text() +
                       "OTZARIA_MINIAPPS_IMAGE_PID bundle=test.original.producer pid=456 phase=cold-ui\n")
        result = self.audit.finish(log_paths=[log])
        self.assertEqual(result["status"], "IMAGE_ORIGIN_INCOMPLETE")
        self.assertEqual(result["missing_referenced_ui_pids"], [456])

    def test_rejects_changed_admitted_artifact_at_collection(self):
        self.observe()
        (self.built / "Qualified").write_bytes(b"changed artifact")
        with self.assertRaisesRegex(AssertionError, "Qualified built app changed"):
            self.audit.finish()

    def test_rejects_ambiguous_sample_uuid(self):
        text = ("Binary Images:\n"
                f"0x1000 - 0x2000 +Image <{UUID}> /tmp/image\n"
                "0x1000 - 0x2000 +Image <FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF> /tmp/image\n")
        with self.assertRaisesRegex(AssertionError, "Ambiguous"):
            API["sample_image_uuids"](text)

    def test_original_ui_loader_configuration_preserves_other_targets_and_selectors(self):
        derived = self.base / "derived"
        products = derived / "Build/Products"
        products.mkdir(parents=True)
        app = products / "Debug-iphonesimulator/Maktabah.app"
        ui = {
            "IsUITestBundle": True, "UITargetAppPath": "__TESTROOT__/Debug-iphonesimulator/Maktabah.app",
            "OnlyTestIdentifiers": ["MiniAppsAnnotationAcceptanceTests/testOriginalNativeFilesRoundTripAndReplayAfterColdReopen"],
            "UITargetAppEnvironmentVariables": {"DYLD_LIBRARY_PATH": "/unqualified",
                "__XPC_DYLD_LIBRARY_PATH": "/unqualified", "ORIGINAL_OTHER_VALUE": "keep"},
            "EnvironmentVariables": {"ORIGINAL_RUNNER_SETTING": "keep"},
        }
        native = {"EnvironmentVariables": {"NATIVE_INSTRUMENTATION": "keep"}, "OnlyTestIdentifiers": ["OriginalUnit"]}
        original = {"Maktabah-iOSUITests": ui, "Maktabah-iOSNativeTests": native}
        (products / "Maktabah-iOS_fixture.xctestrun").write_bytes(plistlib.dumps(original))
        path = API["create_bundled_ui_configuration"](ROOT, self.base / "evidence", app, derived)
        actual = plistlib.loads(path.read_bytes())
        self.assertEqual(actual["Maktabah-iOSNativeTests"], native)
        self.assertEqual(actual["Maktabah-iOSUITests"]["OnlyTestIdentifiers"], ui["OnlyTestIdentifiers"])
        self.assertEqual(actual["Maktabah-iOSUITests"]["EnvironmentVariables"], ui["EnvironmentVariables"])
        environment = actual["Maktabah-iOSUITests"]["UITargetAppEnvironmentVariables"]
        self.assertNotIn("DYLD_LIBRARY_PATH", environment)
        self.assertNotIn("__XPC_DYLD_LIBRARY_PATH", environment)
        self.assertEqual(environment["ORIGINAL_OTHER_VALUE"], "keep")
        self.assertEqual(environment["DYLD_FRAMEWORK_PATH"], str(app / "Frameworks"))


if __name__ == "__main__":
    unittest.main()

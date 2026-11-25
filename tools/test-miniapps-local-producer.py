#!/usr/bin/env python3
"""Integrity controls for local product admission. Fixtures are not native evidence."""
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import runpy
import subprocess
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
HELPER = runpy.run_path(str(ROOT / "Scripts/CI/miniapps-local-producer.py"))


class LocalProducerAdmissionIntegrityTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="miniapps-admission-control-")
        self.root = Path(self.temporary.name)
        self.sdk = self.root / "sdk"
        self.sdk.mkdir()
        self.run_git("init", "-q")
        (self.sdk / "engine.js").write_text("export const originalSource = true;\n")
        self.run_git("add", "engine.js")
        self.run_git("-c", "user.name=Admission Control", "-c", "user.email=control@example.invalid",
                     "commit", "-q", "-m", "Original control source")
        self.sha = self.run_git("rev-parse", "HEAD")
        self.export = self.root / "export"
        self.export.mkdir()
        self.receipt = self.export / "acceptance.json"
        self.receipt.write_text(json.dumps({"build": "EXECUTED_PASS", "status": "FIXTURE_ONLY"}))
        self.log = self.export / "build.log"
        self.log.write_text("ADMISSION CONTROL FIXTURE, NOT A REAL APP BUILD\n** BUILD SUCCEEDED **\n")
        self.archive = self.export / "HanlinMiniApps-simulator.zip"
        with zipfile.ZipFile(self.archive, "w") as output:
            output.writestr("HanlinMiniApps.app/control.txt", "control")
        self.manifest = {
            "schema_version": 1, "execution_origin": "local-mac", "run_id": None,
            "producer_sha": self.sha, "bundle_id": "com.itorah.hanlinminiapps",
            "build_status": "EXECUTED_PASS", "native_acceptance_status": "FIXTURE_ONLY",
            "app_relative_path": "HanlinMiniApps.app", "archive_name": self.archive.name,
            "archive_sha256": self.digest(self.archive),
            "build_receipt_name": self.receipt.name, "build_receipt_sha256": self.digest(self.receipt),
            "build_log_name": self.log.name, "build_log_sha256": self.digest(self.log),
            "source_identity": {"commit": self.sha, "tree": self.run_git("rev-parse", "HEAD^{tree}"),
                                "tracked_file_sha256": {"engine.js": self.digest(self.sdk / "engine.js")}},
            "app_files": {"control.txt": {"kind": "file", "bytes": 7, "mode": 0o644,
                                          "sha256": hashlib.sha256(b"control").hexdigest()}},
        }
        self.config = {"producer_source_sha": self.sha,
                       "local_producer_manifest": {"path": str(self.export / "producer-manifest.json")}}
        self.save_manifest()

    def tearDown(self):
        self.temporary.cleanup()

    def run_git(self, *arguments):
        return subprocess.check_output(["git", "-C", str(self.sdk), *arguments], text=True).strip()

    @staticmethod
    def digest(path):
        return hashlib.sha256(Path(path).read_bytes()).hexdigest()

    def save_manifest(self):
        path = Path(self.config["local_producer_manifest"]["path"])
        path.write_text(json.dumps(self.manifest, sort_keys=True))
        self.config["local_producer_manifest"]["sha256"] = self.digest(path)

    def validate(self):
        return HELPER["validate_export"](self.config, self.sdk, "com.itorah.hanlinminiapps")

    def test_matching_actual_git_objects_admit_control_manifest(self):
        path, manifest, archive = self.validate()
        self.assertEqual(manifest["source_identity"]["commit"], self.sha)
        self.assertEqual(archive, self.archive)
        self.assertEqual(path.name, "producer-manifest.json")

    def test_manifest_byte_change_is_rejected(self):
        Path(self.config["local_producer_manifest"]["path"]).write_text("{}")
        with self.assertRaisesRegex(RuntimeError, "manifest bytes differ"):
            self.validate()

    def test_build_receipt_change_is_rejected(self):
        self.receipt.write_text(json.dumps({"build": "FAILED", "status": "FIXTURE_ONLY"}))
        with self.assertRaisesRegex(RuntimeError, "build receipt changed"):
            self.validate()

    def test_archive_change_is_rejected(self):
        self.archive.write_bytes(b"changed")
        with self.assertRaisesRegex(RuntimeError, "archive changed"):
            self.validate()

    def test_original_source_blob_change_is_rejected(self):
        self.manifest["source_identity"]["tracked_file_sha256"]["engine.js"] = "0" * 64
        self.save_manifest()
        with self.assertRaisesRegex(RuntimeError, "source bytes differ"):
            self.validate()

    def test_local_product_cannot_claim_github_run(self):
        self.manifest["run_id"] = 12345
        self.save_manifest()
        with self.assertRaisesRegex(RuntimeError, "without a GitHub run"):
            self.validate()

    def test_receipt_outside_export_is_rejected(self):
        self.manifest["build_receipt_name"] = "../acceptance.json"
        self.save_manifest()
        with self.assertRaisesRegex(RuntimeError, "path leaves"):
            self.validate()

    def test_archive_path_escape_is_rejected_even_with_matching_digest(self):
        with zipfile.ZipFile(self.archive, "w") as output:
            output.writestr("HanlinMiniApps.app/../../outside", "control")
        self.manifest["archive_sha256"] = self.digest(self.archive)
        self.save_manifest()
        with self.assertRaisesRegex(RuntimeError, "archive leaves"):
            self.validate()

    def test_complete_product_inventory_detects_resource_change(self):
        app = self.root / "HanlinMiniApps.app"
        app.mkdir()
        resource = app / "resource.txt"
        resource.write_text("before")
        original = HELPER["app_inventory"](app)
        resource.write_text("after")
        self.assertNotEqual(HELPER["app_inventory"](app), original)

    def test_product_symlink_escape_is_rejected(self):
        app = self.root / "HanlinMiniApps.app"
        app.mkdir()
        outside = self.root / "outside"
        outside.write_text("control")
        (app / "link").symlink_to("../outside")
        with self.assertRaisesRegex(RuntimeError, "symlink leaves"):
            HELPER["app_inventory"](app)


if __name__ == "__main__":
    unittest.main(verbosity=2)

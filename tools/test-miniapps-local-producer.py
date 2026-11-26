#!/usr/bin/env python3
"""Integrity controls for local product admission. Fixtures are not native evidence."""
from copy import deepcopy
import hashlib
import os
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
        (self.sdk / "other.js").write_text("export const other = true;\n")
        declared = self.sdk / HELPER["PRODUCER_INVENTORY_SOURCE"]
        declared.parent.mkdir(parents=True)
        declared.write_text("def main():\n" + "\n".join(
            "    " + line for line in HELPER["PRODUCER_INVENTORY_DECLARATION"].splitlines()) + "\n")
        for name in ["AI_HLY.xcodeproj/project.pbxproj", "RuntimeDependencies.lock.json",
                     "AI_HLY.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"]:
            path = self.sdk / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("Original source-inventory integrity control only.\n")
        self.run_git("add", ".")
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
                                "tracked_file_sha256": {name: self.digest(self.sdk / name)
                                    for name in self.run_git("ls-files").splitlines()}},
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
        return HELPER["validate_export"](self.config, self.sdk, "com.itorah.hanlinminiapps",
                                         consumer_root=getattr(self, "consumer", None))

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

    def make_preparation(self, extra_path=False):
        original_tree = self.run_git("rev-parse", self.sha + "^{tree}")
        (self.sdk / "engine.js").write_text("export const originalSource = 'prepared control';\n")
        if extra_path:
            (self.sdk / "other.js").write_text("export const other = 'unreviewed preparation';\n")
        self.patch = self.export / "source-preparation.diff"
        self.patch.write_bytes(subprocess.check_output(["git", "-C", str(self.sdk), "diff", "--binary", self.sha]))
        with tempfile.TemporaryDirectory() as temporary:
            private = Path(temporary)
            (private / "objects").mkdir()
            env = dict(os.environ, GIT_INDEX_FILE=str(private / "index"),
                       GIT_OBJECT_DIRECTORY=str(private / "objects"),
                       GIT_ALTERNATE_OBJECT_DIRECTORIES=str(self.sdk / ".git/objects"))
            for arguments in (["read-tree", self.sha], ["apply", "--cached", "--binary", str(self.patch)]):
                subprocess.run(["git", "-C", str(self.sdk), *arguments], check=True, env=env, capture_output=True)
            prepared = subprocess.check_output(["git", "-C", str(self.sdk), "write-tree"], env=env, text=True).strip()
            def proof(tree):
                row = subprocess.check_output(["git", "-C", str(self.sdk), "ls-tree", tree, "--", "engine.js"],
                                              env=env, text=True).split("\t")[0].split()
                blob = subprocess.check_output(["git", "-C", str(self.sdk), "cat-file", "blob", row[2]], env=env)
                return {"mode": row[0], "blob": row[2], "bytes": len(blob), "sha256": hashlib.sha256(blob).hexdigest()}
            original_proof, prepared_proof = proof(original_tree), proof(prepared)
        self.review = {
            "schema": "miniapps.producer-preparation-review/1",
            "producer_sha": self.sha, "source_tree": original_tree, "prepared_tree": prepared,
            "git_status_porcelain": " M engine.js\n",
            "patch": {"name": self.patch.name, "bytes": self.patch.stat().st_size, "sha256": self.digest(self.patch)},
            "changes": [{"path": "engine.js", "status": "M", "before": original_proof,
                         "after": prepared_proof, "reason": "Synthetic prepared-source admission control only."}],
        }
        identity = self.manifest["source_identity"]
        identity.update({"git_status_porcelain": self.review["git_status_porcelain"],
                         "preparation_diff_name": self.patch.name, "preparation_diff_sha256": self.digest(self.patch),
                         "prepared_tree": prepared})
        identity["tracked_file_sha256"]["engine.js"] = self.digest(self.sdk / "engine.js")
        self.consumer = self.root / "consumer"
        self.consumer.mkdir()
        subprocess.run(["git", "-C", str(self.consumer), "init", "-q"], check=True)
        self.review_path = self.consumer / "Scripts/CI/preparation.json"
        self.review_path.parent.mkdir(parents=True)
        self.config["local_producer_preparation"] = {"path": "Scripts/CI/preparation.json"}
        self.save_review()
        self.save_manifest()

    def save_review(self, commit=True):
        self.review_path.write_text(json.dumps(self.review, sort_keys=True))
        self.config["local_producer_preparation"]["sha256"] = self.digest(self.review_path)
        if commit:
            subprocess.run(["git", "-C", str(self.consumer), "add", "Scripts/CI/preparation.json"], check=True)
            subprocess.run(["git", "-C", str(self.consumer), "-c", "user.name=Admission Control",
                            "-c", "user.email=control@example.invalid", "commit", "-q", "--allow-empty",
                            "-m", "Explicit synthetic preparation review"], check=True)

    def test_exact_reviewed_preparation_is_independently_reconstructed_without_index_mutation(self):
        self.make_preparation()
        index = self.digest(self.sdk / ".git/index")
        status = self.run_git("status", "--porcelain")
        _, manifest, _ = self.validate()
        self.assertEqual(manifest["source_identity"]["prepared_tree"], self.review["prepared_tree"])
        self.assertEqual(self.digest(self.sdk / ".git/index"), index)
        self.assertEqual(self.run_git("status", "--porcelain"), status)

    def test_preparation_never_writes_the_actual_producer_object_store(self):
        self.make_preparation()
        def inventory():
            return {str(path.relative_to(self.sdk / ".git/objects")): self.digest(path)
                    for path in (self.sdk / ".git/objects").rglob("*") if path.is_file()}
        generated = [self.review["prepared_tree"], self.review["changes"][0]["after"]["blob"]]
        before = inventory()
        for name in generated:
            self.assertNotEqual(subprocess.run(["git", "-C", str(self.sdk), "cat-file", "-e", name],
                capture_output=True).returncode, 0)
        self.validate()
        self.assertEqual(inventory(), before)
        for name in generated:
            self.assertNotEqual(subprocess.run(["git", "-C", str(self.sdk), "cat-file", "-e", name],
                capture_output=True).returncode, 0)

    def update_control_source(self):
        self.run_git("add", ".")
        self.run_git("-c", "user.name=Admission Control", "-c", "user.email=control@example.invalid",
                     "commit", "-q", "-m", "Changed source-inventory control")
        self.sha = self.run_git("rev-parse", "HEAD")
        self.config["producer_source_sha"] = self.sha
        self.manifest["producer_sha"] = self.sha
        self.manifest["source_identity"].update(commit=self.sha, tree=self.run_git("rev-parse", "HEAD^{tree}"),
            tracked_file_sha256={name: self.digest(self.sdk / name) for name in self.run_git("ls-files").splitlines()})
        self.save_manifest()

    def test_incomplete_recorded_source_inventory_is_rejected(self):
        del self.manifest["source_identity"]["tracked_file_sha256"]["other.js"]
        self.save_manifest()
        with self.assertRaisesRegex(RuntimeError, "inventory is incomplete"):
            self.validate()

    def test_undeclared_inventory_file_is_rejected_even_when_its_blob_is_real(self):
        (self.sdk / "README.md").write_text("Not part of the original producer source inventory.\n")
        self.update_control_source()
        with self.assertRaisesRegex(RuntimeError, "inventory is incomplete"):
            self.validate()

    def test_changed_original_inventory_predicate_is_rejected(self):
        path = self.sdk / HELPER["PRODUCER_INVENTORY_SOURCE"]
        path.write_text(path.read_text().replace("'.swift'", "'.txt'"))
        self.update_control_source()
        with self.assertRaisesRegex(RuntimeError, "source-inventory declaration changed"):
            self.validate()

    def test_selected_source_symlink_requires_an_explicit_new_review(self):
        (self.sdk / "linked.js").symlink_to("engine.js")
        self.update_control_source()
        with self.assertRaisesRegex(RuntimeError, "not a reviewed regular file"):
            self.validate()

    def test_dirty_preparation_without_committed_review_is_rejected(self):
        self.make_preparation()
        del self.config["local_producer_preparation"]
        with self.assertRaisesRegex(RuntimeError, "Dirty producer preparation requires"):
            self.validate()

    def test_claimed_clean_status_cannot_hide_prepared_patch(self):
        self.make_preparation()
        del self.config["local_producer_preparation"]
        self.manifest["source_identity"]["git_status_porcelain"] = ""
        self.save_manifest()
        with self.assertRaisesRegex(RuntimeError, "Prepared producer source requires"):
            self.validate()

    def test_uncommitted_review_cannot_admit_preparation(self):
        self.make_preparation()
        self.review["changes"][0]["reason"] = "Uncommitted change"
        self.save_review(commit=False)
        with self.assertRaisesRegex(RuntimeError, "not the exact committed file"):
            self.validate()

    def test_changed_preparation_patch_is_rejected(self):
        self.make_preparation()
        self.patch.write_bytes(self.patch.read_bytes() + b"\n")
        with self.assertRaisesRegex(RuntimeError, "patch bytes differ"):
            self.validate()

    def test_reviewed_but_wrong_prepared_tree_is_rejected(self):
        self.make_preparation()
        self.review["prepared_tree"] = self.review["source_tree"]
        self.manifest["source_identity"]["prepared_tree"] = self.review["source_tree"]
        self.save_review()
        self.save_manifest()
        with self.assertRaisesRegex(RuntimeError, "Reconstructed producer preparation tree differs"):
            self.validate()

    def test_extra_prepared_path_is_rejected_even_when_tree_and_patch_hashes_match(self):
        self.make_preparation(extra_path=True)
        with self.assertRaisesRegex(RuntimeError, "tree contains unreviewed changes"):
            self.validate()

    def test_preparation_index_status_cannot_be_relabelled_as_worktree_preparation(self):
        self.make_preparation()
        self.review["git_status_porcelain"] = "M  engine.js\n"
        self.manifest["source_identity"]["git_status_porcelain"] = "M  engine.js\n"
        self.save_review()
        self.save_manifest()
        with self.assertRaisesRegex(RuntimeError, "unreviewed index or working-tree"):
            self.validate()

    def test_preparation_before_blob_must_match_actual_git_source(self):
        self.make_preparation()
        self.review["changes"][0]["before"]["blob"] = "0" * 40
        self.save_review()
        with self.assertRaisesRegex(RuntimeError, "before object differs"):
            self.validate()

    def test_preparation_after_bytes_must_match_actual_reconstructed_blob(self):
        self.make_preparation()
        self.review["changes"][0]["after"]["sha256"] = "0" * 64
        self.save_review()
        with self.assertRaisesRegex(RuntimeError, "after object differs"):
            self.validate()

    def test_prepared_inventory_cannot_fall_back_to_unprepared_bytes(self):
        self.make_preparation()
        self.manifest["source_identity"]["tracked_file_sha256"]["engine.js"] = self.review["changes"][0]["before"]["sha256"]
        self.save_manifest()
        with self.assertRaisesRegex(RuntimeError, "source bytes differ"):
            self.validate()

    def test_preparation_review_cannot_be_a_symlink(self):
        self.make_preparation()
        saved = self.consumer / "unreviewed.json"
        saved.write_bytes(self.review_path.read_bytes())
        self.review_path.unlink()
        self.review_path.symlink_to(saved)
        with self.assertRaisesRegex(RuntimeError, "review bytes differ"):
            self.validate()

    def test_clean_generated_metadata_still_requires_empty_patch_and_original_tree(self):
        self.patch = self.export / "source-preparation.diff"
        self.patch.write_bytes(b"")
        self.manifest["source_identity"].update({
            "git_status_porcelain": "", "preparation_diff_name": self.patch.name,
            "preparation_diff_sha256": self.digest(self.patch),
            "prepared_tree": self.manifest["source_identity"]["tree"],
        })
        self.save_manifest()
        self.validate()


if __name__ == "__main__":
    unittest.main(verbosity=2)

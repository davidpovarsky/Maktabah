"""Source/metadata gates only; no Apple compiler, network, or binary execution.

Positive inputs are real Git trees and retained GitHub metadata. Negative inputs
are explicit copies with one changed fact. The complete app source freeze stays
separate from this bounded prebuilt qualification.
"""
from copy import deepcopy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("stage2_prebuilt", ROOT / "Scripts/CI/hq-stage2-focused-apple.py")
STAGE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(STAGE)
FIXTURES = Path(__file__).parent / "fixtures/d5-prebuilt-20261120"
OLD_PRODUCER = "41c278ac67f0c03e19270ed65b891b242a1a3f2e"
OLD_ARCHIVE_SHA = "ba24e27a2c26281e0af3d11cd7ea00fe88ff44a3634194dfd10ce89a526eccd5"


class PrebuiltSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.config = json.loads(STAGE.INPUTS.read_text(encoding="utf-8"))
        cls.manifest = json.loads(STAGE.TEST_ADDITIONS_MANIFEST.read_text(encoding="utf-8"))
        cls.producer = STAGE.git_tree_entries(cls.config["engine_producer_sha"], STAGE.OTZARIA_ROOT)
        cls.current = STAGE.git_tree_entries("HEAD", STAGE.OTZARIA_ROOT)

    def test_exact_actual_trees_preserve_all_prior_inputs_and_78_additions(self):
        result = STAGE.verify_otzaria_test_additions(self.config)
        self.assertEqual(result["reviewed_added_regular_files"], 78)
        self.assertEqual(result["preserved_producer_entries"], len(self.producer))
        self.assertEqual(result["binary_attribution"], "PRODUCER_TREE_ONLY_NOT_CURRENT_WHOLE_TREE")
        self.assertNotEqual(result["producer_whole_tree"], result["current_whole_tree"])

    def assert_changed_producer_rejected(self, path):
        self.assertIn(path, self.producer)
        current = deepcopy(self.current)
        current[path]["blob"] = "f" * 40
        with self.assertRaisesRegex(RuntimeError, "Changed or removed producer input"):
            STAGE.validate_test_additions(self.producer, current, self.manifest)

    def test_changed_compiled_rust_is_rejected(self):
        self.assert_changed_producer_rejected(STAGE.OTZARIA_ROOT + "/ios_bridge/src/lib.rs")

    def test_changed_export_header_is_rejected(self):
        self.assert_changed_producer_rejected(STAGE.OTZARIA_ROOT + "/include/otzaria_search_engine.h")

    def test_changed_build_script_is_rejected(self):
        self.assert_changed_producer_rejected(STAGE.OTZARIA_ROOT + "/build_xcframework.sh")

    def test_changed_cargo_build_input_is_rejected(self):
        self.assert_changed_producer_rejected(STAGE.OTZARIA_ROOT + "/ios_bridge/Cargo.toml")

    def test_changed_pinned_upstream_resource_is_rejected(self):
        self.assert_changed_producer_rejected(STAGE.OTZARIA_ROOT + "/Resources/dictionary.json")

    def test_changed_original_upstream_pin_is_rejected(self):
        self.assert_changed_producer_rejected(STAGE.OTZARIA_ROOT + "/Upstream/UPSTREAM_COMMIT")

    def test_removed_producer_input_is_rejected(self):
        current = deepcopy(self.current)
        del current[next(iter(self.producer))]
        with self.assertRaisesRegex(RuntimeError, "Changed or removed producer input"):
            STAGE.validate_test_additions(self.producer, current, self.manifest)

    def test_symlink_replacement_of_producer_input_is_rejected(self):
        current = deepcopy(self.current)
        current[next(iter(self.producer))]["mode"] = "120000"
        with self.assertRaisesRegex(RuntimeError, "Changed or removed producer input"):
            STAGE.validate_test_additions(self.producer, current, self.manifest)

    def test_undeclared_added_test_is_rejected(self):
        current = deepcopy(self.current)
        current[STAGE.OTZARIA_TEST_ROOT + "/extra.swift"] = {"mode": "100644", "type": "blob", "blob": "e" * 40}
        with self.assertRaisesRegex(RuntimeError, "Added paths differ"):
            STAGE.validate_test_additions(self.producer, current, self.manifest)

    def test_added_compiled_source_is_rejected(self):
        current = deepcopy(self.current)
        current[STAGE.OTZARIA_ROOT + "/ios_bridge/src/extra.rs"] = {"mode": "100644", "type": "blob", "blob": "e" * 40}
        with self.assertRaisesRegex(RuntimeError, "Added paths differ"):
            STAGE.validate_test_additions(self.producer, current, self.manifest)

    def test_modified_declared_test_is_rejected(self):
        current = deepcopy(self.current)
        current[self.manifest["entries"][0]["path"]]["blob"] = "e" * 40
        with self.assertRaisesRegex(RuntimeError, "Declared test identity drift"):
            STAGE.validate_test_additions(self.producer, current, self.manifest)

    def test_deleted_declared_test_is_rejected(self):
        current = deepcopy(self.current)
        del current[self.manifest["entries"][0]["path"]]
        with self.assertRaisesRegex(RuntimeError, "Added paths differ"):
            STAGE.validate_test_additions(self.producer, current, self.manifest)

    def test_declared_symlink_or_submodule_is_rejected(self):
        for mode, kind in (("120000", "blob"), ("160000", "commit"), ("100755", "blob")):
            with self.subTest(mode=mode):
                manifest = deepcopy(self.manifest)
                manifest["entries"][0].update(mode=mode, type=kind)
                with self.assertRaisesRegex(RuntimeError, "pinned regular file"):
                    STAGE.validate_test_additions(self.producer, self.current, manifest)

    def test_invalid_manifest_paths_are_rejected(self):
        for path in ("../escape", "/absolute", STAGE.OTZARIA_TEST_ROOT + "/../source.rs",
                     STAGE.OTZARIA_TEST_ROOT + "Extra/new.swift", STAGE.OTZARIA_TEST_ROOT + "//new.swift",
                     STAGE.OTZARIA_TEST_ROOT + "/dir\\new.swift", STAGE.OTZARIA_ROOT + "/ios_bridge/new.rs"):
            with self.subTest(path=path):
                manifest = deepcopy(self.manifest)
                manifest["entries"][0]["path"] = path
                with self.assertRaisesRegex(RuntimeError, "Invalid or duplicate"):
                    STAGE.validate_test_additions(self.producer, self.current, manifest)

    def test_duplicate_manifest_path_is_rejected(self):
        manifest = deepcopy(self.manifest)
        manifest["entries"].append(manifest["entries"][0])
        with self.assertRaisesRegex(RuntimeError, "Invalid or duplicate"):
            STAGE.validate_test_additions(self.producer, self.current, manifest)

    def test_old_265_producer_tree_cannot_pass_as_d5(self):
        old = STAGE.git_tree_entries(OLD_PRODUCER, STAGE.OTZARIA_ROOT)
        self.assertNotEqual(old, self.producer)
        with self.assertRaisesRegex(RuntimeError, "Changed or removed producer input"):
            STAGE.validate_test_additions(old, self.current, self.manifest)

    def test_wrong_producer_sha_is_rejected(self):
        config = deepcopy(self.config)
        config["engine_producer_sha"] = OLD_PRODUCER
        with self.assertRaisesRegex(RuntimeError, "Test manifest producer mismatch"):
            STAGE.verify_otzaria_test_additions(config)

    def test_wrong_manifest_digest_is_rejected(self):
        config = deepcopy(self.config)
        config["otzaria_test_additions_sha256"] = "0" * 64
        with self.assertRaisesRegex(RuntimeError, "manifest digest mismatch"):
            STAGE.verify_otzaria_test_additions(config)

    def test_wrong_whole_producer_tree_is_rejected(self):
        config = deepcopy(self.config)
        config["engine_trees"][STAGE.OTZARIA_ROOT] = "0" * 40
        with self.assertRaisesRegex(RuntimeError, "Whole producer Otzaria tree mismatch"):
            STAGE.verify_otzaria_test_additions(config)

    def test_current_whole_otzaria_tree_drift_is_rejected(self):
        capture = STAGE.capture
        def changed(*args):
            return "0" * 40 if args == ("git", "rev-parse", "HEAD:" + STAGE.OTZARIA_ROOT) else capture(*args)
        with mock.patch.object(STAGE, "capture", side_effect=changed):
            with self.assertRaisesRegex(RuntimeError, "Current Otzaria tree differs"):
                STAGE.verify_otzaria_test_additions(self.config)

    def test_manifest_git_crlf_checkout_preserves_exact_lf_digest(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "manifest.json"
            path.write_bytes(STAGE.TEST_ADDITIONS_MANIFEST.read_text(encoding="utf-8").replace("\n", "\r\n").encode("utf-8"))
            with mock.patch.object(STAGE, "TEST_ADDITIONS_MANIFEST", path):
                self.assertEqual(STAGE.verify_otzaria_test_additions(self.config)["manifest_sha256_lf"],
                                 self.config["otzaria_test_additions_sha256"])

    def test_current_whole_vendor_freeze_remains_strict(self):
        config = deepcopy(self.config)
        # Exercise the existing preflight Vendor gate without claiming the
        # independently pending complete Source/project freeze has passed.
        config["application_trees"] = {"Vendor": "0" * 40}
        with self.assertRaisesRegex(RuntimeError, "Application tree drift: Vendor"):
            STAGE.preflight(config)

    def test_project_membership_change_requires_new_exclusion_review(self):
        capture = STAGE.capture
        def changed(*args):
            if args == ("git", "rev-parse", "HEAD:Maktabah.xcodeproj/project.pbxproj"):
                return "0" * 40
            return capture(*args)
        with mock.patch.object(STAGE, "capture", side_effect=changed):
            with self.assertRaisesRegex(RuntimeError, "Reviewed build-exclusion input changed"):
                STAGE.verify_otzaria_test_additions(self.config)

    def test_actual_zayit_whole_tree_is_identical_and_rebuild_is_off(self):
        self.assertIs(self.config["rebuild_zayit_framework"], False)
        expected = self.config["engine_trees"]["Vendor/ZayitSearchPort"]
        for ref in (self.config["engine_producer_sha"], "HEAD"):
            self.assertEqual(STAGE.capture("git", "rev-parse", ref + ":Vendor/ZayitSearchPort"), expected)
        self.assertEqual(STAGE.zayit_build_plan(self.config)["mode"], "UNCHANGED_PRODUCTION_PREBUILT")


class PrebuiltMetadataTests(unittest.TestCase):
    def setUp(self):
        self.config = json.loads(STAGE.INPUTS.read_text(encoding="utf-8"))
        self.item = deepcopy(self.config["artifacts"][0])
        self.artifact = json.loads((FIXTURES / (str(self.item["id"]) + "-artifact.json")).read_text(encoding="utf-8"))
        self.run = json.loads((FIXTURES / "producer-run-attempt1.json").read_text(encoding="utf-8"))
        self.job = json.loads((FIXTURES / "producer-otzaria-job.json").read_text(encoding="utf-8"))

    def validate(self):
        return STAGE.validate_framework_metadata(self.config, self.item, self.artifact, self.run, self.job)

    def test_both_real_successful_jobs_are_accepted_without_whole_workflow_success(self):
        STAGE.validate_framework_bindings(self.config)
        for item, suffix in zip(self.config["artifacts"][:2], ("otzaria", "zayit")):
            with self.subTest(artifact=item["id"]):
                artifact = json.loads((FIXTURES / (str(item["id"]) + "-artifact.json")).read_text(encoding="utf-8"))
                job = json.loads((FIXTURES / ("producer-" + suffix + "-job.json")).read_text(encoding="utf-8"))
                result = STAGE.validate_framework_metadata(self.config, item, artifact, self.run, job)
                self.assertEqual(result["producer_run_conclusion"], "failure")
                self.assertEqual(result["producer_job_conclusion"], "success")
                self.assertEqual(result["producer_sha"], "99f7927e4da72f2463417f5c2de2c4d20c6aa168")

    def test_wrong_artifact_identity_digest_size_and_lifetime_are_rejected(self):
        for key, value in (("id", 12763376316), ("name", "wrong-framework"), ("size_in_bytes", 1),
                           ("digest", "sha256:" + OLD_ARCHIVE_SHA), ("digest", None), ("expired", True)):
            with self.subTest(key=key, value=value):
                artifact = deepcopy(self.artifact)
                artifact[key] = value
                with self.assertRaises(RuntimeError):
                    STAGE.validate_framework_metadata(self.config, self.item, artifact, self.run, self.job)

    def test_wrong_artifact_run_head_and_repository_are_rejected(self):
        for key, value in (("id", 40566258679), ("head_sha", OLD_PRODUCER), ("repository_id", 1),
                           ("head_repository_id", 1), ("head_branch", "other")):
            with self.subTest(key=key):
                artifact = deepcopy(self.artifact)
                artifact["workflow_run"][key] = value
                with self.assertRaises(RuntimeError):
                    STAGE.validate_framework_metadata(self.config, self.item, artifact, self.run, self.job)

    def test_wrong_run_identity_attempt_head_workflow_and_state_are_rejected(self):
        for key, value in (("id", 40566258679), ("run_attempt", 2), ("head_sha", OLD_PRODUCER),
                           ("head_commit", {"id": OLD_PRODUCER}), ("path", ".github/workflows/other.yml"),
                           ("status", "in_progress"), ("conclusion", "success"),
                           ("repository", {"full_name": "other/Maktabah", "id": 1}),
                           ("head_repository", {"full_name": "other/Maktabah", "id": 1})):
            with self.subTest(key=key):
                run = deepcopy(self.run)
                run[key] = value
                with self.assertRaises(RuntimeError):
                    STAGE.validate_framework_metadata(self.config, self.item, self.artifact, run, self.job)

    def test_wrong_job_identity_attempt_head_or_outcome_is_rejected(self):
        for key, value in (("id", 136041463406), ("name", "Resolve Swift packages"), ("run_id", 40566258679),
                           ("run_attempt", 2), ("head_sha", OLD_PRODUCER), ("status", "in_progress"),
                           ("conclusion", "failure"), ("conclusion", "skipped")):
            with self.subTest(key=key, value=value):
                job = deepcopy(self.job)
                job[key] = value
                with self.assertRaises(RuntimeError):
                    STAGE.validate_framework_metadata(self.config, self.item, self.artifact, self.run, job)

    def test_skipped_missing_duplicate_or_failed_build_steps_are_rejected(self):
        name = self.item["producer_required_steps"][0]
        for mutation in ("missing", "duplicate", "skipped", "failure", "in_progress"):
            with self.subTest(mutation=mutation):
                job = deepcopy(self.job)
                step = next(row for row in job["steps"] if row["name"] == name)
                if mutation == "missing":
                    job["steps"].remove(step)
                elif mutation == "duplicate":
                    job["steps"].append(deepcopy(step))
                elif mutation == "in_progress":
                    step["status"] = mutation
                else:
                    step["conclusion"] = mutation
                with self.assertRaises(RuntimeError):
                    STAGE.validate_framework_metadata(self.config, self.item, self.artifact, self.run, job)

    def test_artifact_from_outside_exact_upload_window_is_rejected(self):
        for value in ("2026-11-20T02:44:02Z", "2026-11-20T03:00:00Z"):
            with self.subTest(created=value):
                self.artifact["created_at"] = value
                with self.assertRaisesRegex(RuntimeError, "outside the verified producer upload"):
                    self.validate()

    def test_wrong_config_producer_is_rejected(self):
        self.item["producer_sha"] = OLD_PRODUCER
        with self.assertRaisesRegex(RuntimeError, "producer SHA mismatch"):
            self.validate()

    def test_framework_bindings_cannot_be_omitted_renamed_or_duplicated(self):
        for mode in ("omitted", "renamed", "duplicated", "wrong_destination", "missing_job"):
            with self.subTest(mode=mode):
                config = deepcopy(self.config)
                if mode == "omitted":
                    config["artifacts"].pop(0)
                elif mode == "renamed":
                    config["artifacts"][0]["name"] = "unqualified"
                elif mode == "duplicated":
                    config["artifacts"].append(deepcopy(config["artifacts"][0]))
                elif mode == "wrong_destination":
                    config["artifacts"][0]["destination"] = "Vendor/Other"
                else:
                    del config["artifacts"][0]["producer_job"]
                with self.assertRaises(RuntimeError):
                    STAGE.validate_framework_bindings(config)

    def test_restore_rejects_wrong_download_bytes_before_extraction(self):
        config = deepcopy(self.config)
        config["artifacts"] = [self.item]
        def wrong_download(command, **kwargs):
            # Explicit transport double: valid metadata must not bless any
            # bytes other than the pinned actual archive, including old265.
            kwargs["stdout"].write(b"different archive bytes")
        with tempfile.TemporaryDirectory() as directory:
            with mock.patch.object(STAGE, "OUT", Path(directory)), mock.patch.object(
                STAGE, "framework_metadata", return_value=self.validate()), mock.patch.object(
                    STAGE.subprocess, "run", side_effect=wrong_download), mock.patch.object(
                        STAGE.zipfile, "ZipFile", side_effect=AssertionError("must not extract rejected input")):
                with self.assertRaisesRegex(RuntimeError, "Artifact ZIP digest mismatch"):
                    STAGE.restore(config, {"zayit_framework": {"mode": "UNCHANGED_PRODUCTION_PREBUILT"}})

    def test_restore_rejects_bad_producer_before_downloading_archive(self):
        config = deepcopy(self.config)
        config["artifacts"] = [self.item]
        with tempfile.TemporaryDirectory() as directory:
            with mock.patch.object(STAGE, "OUT", Path(directory)), mock.patch.object(
                STAGE, "framework_metadata", side_effect=RuntimeError("Framework producer job did not succeed")), mock.patch.object(
                    STAGE.subprocess, "run", side_effect=AssertionError("must not download rejected producer")):
                with self.assertRaisesRegex(RuntimeError, "producer job did not succeed"):
                    STAGE.restore(config, {})


if __name__ == "__main__":
    unittest.main(verbosity=2)

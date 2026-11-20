#!/usr/bin/env python3
"""Portable fail-closed controls for the normal workflow adapter; no Apple/Pods/npm execution."""
import argparse
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("normal_ios_workspace", HERE / "prepare-normal-ios-workspace.py")
adapter = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(adapter)
ACTUAL_CONFIG = json.loads((HERE / "hq-stage2-focused-apple.inputs.json").read_text())
WORKFLOW = (HERE.parents[1] / ".github/workflows/ios-build.yml").read_text()


class OriginalPreparationBoundary:
    """Explicit command boundary double. Hashing/lock checks use actual temporary files."""
    def __init__(self, root, config):
        self.root, self.config = root, config
        self.checkout = "a" * 40
        self.current_tree = "b" * 40
        self.producer_tree = self.current_tree
        self.upstream = config["sefaria_gitlink"]
        self.changed = [adapter.OVERLAY]
        self.calls = []
        self.source_failure = False
        self.hanlin_failure = False

    @staticmethod
    def require(value, message):
        if not value:
            raise RuntimeError(message)

    @staticmethod
    def digest(path):
        return hashlib.sha256(path.read_bytes()).hexdigest()

    @staticmethod
    def pins(path):
        return {p["identity"]: p["state"]["revision"] for p in json.loads(path.read_text())["pins"]}

    def capture(self, *command):
        if command == ("git", "rev-parse", "HEAD"):
            return self.checkout
        if command == ("git", "rev-parse", "HEAD:" + adapter.UPSTREAM):
            return self.upstream
        if command == ("git", "rev-parse", "HEAD:Vendor/HanlinSDK"):
            return self.config["hanlin_gitlink"]
        if command == ("git", "rev-parse", "HEAD:" + adapter.RESOURCE_ROOT):
            return self.current_tree
        if command == ("git", "rev-parse", self.config["resource_producer_sha"] + ":" + adapter.RESOURCE_ROOT):
            return self.producer_tree
        if command == ("git", "rev-parse", self.config["resource_producer_sha"] + "^{commit}"):
            return self.config["resource_producer_sha"]
        if command == ("git", "rev-parse", "FETCH_HEAD"):
            return self.config["resource_producer_sha"]
        if command == ("git", "-C", str(self.root / adapter.UPSTREAM), "rev-parse", "HEAD"):
            return self.upstream
        if command == ("git", "diff", "--name-only", self.config["resource_producer_sha"], "HEAD", "--", adapter.RESOURCE_ROOT):
            return "\n".join(self.changed)
        raise AssertionError("Unexpected command boundary: " + repr(command))

    def logged(self, command, filename, report):
        self.calls.append(("command", command))

    def prepare_react_sources(self, config, report):
        self.calls.append(("react", config))
        report["native_context"] = self.native_context()
        for key in adapter.ENV_KEYS:
            os.environ[key] = "original-fixture-value"

    def restore(self, config, report):
        self.calls.append(("restore", config))
        report["resource_inputs"] = {"jsbundle_sha256": self.digest(self.root / "build/jsbundle/main.jsbundle")}

    def prepare_matching_embedded_bundle(self, config, report):
        self.calls.append(("bundle", config))

    def install_real_pods(self, report):
        self.calls.append(("pods", None))

    def verify_actual_sources(self, report):
        self.calls.append(("source", None))
        self.require(not self.source_failure, "original source validation failed")

    def prepare_original_hanlin(self, config, report, *, verify_only=False):
        self.calls.append(("hanlin", verify_only))
        self.require(verify_only and not self.hanlin_failure, "original Hanlin validation failed")

    def native_context(self):
        return {"gitlink": self.config["sefaria_gitlink"],
                "podfile_sha256": self.digest(self.root / "Podfile"),
                "pod_lock_sha256": self.digest(self.root / "Podfile.lock"),
                "npm_lock_sha256": self.digest(self.root / adapter.UPSTREAM / "package-lock.json"),
                "generated_project_sha256": self.digest(self.root / "Maktabah.xcodeproj/project.pbxproj"),
                "workspace_sha256": self.digest(self.root / "Maktabah.xcworkspace/contents.xcworkspacedata")}


class WorkspaceAdapterTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="normal-ios-workspace-control-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.out = self.root / "build/normal-ios-embedded"
        self.out.mkdir(parents=True)
        self.config = copy.deepcopy(ACTUAL_CONFIG)
        self.env_patch = mock.patch.dict(os.environ, {}, clear=True)
        self.env_patch.start()
        self.addCleanup(self.env_patch.stop)
        self.input_path = self.root / "Scripts/CI/hq-stage2-focused-apple.inputs.json"
        for key, value in [("ROOT", self.root), ("OUT", self.out), ("INPUTS", self.input_path)]:
            patch = mock.patch.object(adapter, key, value)
            patch.start()
            self.addCleanup(patch.stop)
        lock = json.dumps({"pins": [{"identity": "original-package", "state": {"revision": "1" * 40}}]})
        for path, value in {
            adapter.PROJECT_LOCK: lock, adapter.WORKSPACE_LOCK: lock,
            "Podfile": "original Podfile fixture", "Podfile.lock": "resolved original Pod lock fixture",
            adapter.UPSTREAM + "/package-lock.json": "original npm lock fixture",
            "Maktabah.xcodeproj/project.pbxproj": "actual generated project fixture",
            "Maktabah.xcworkspace/contents.xcworkspacedata": "actual generated workspace fixture",
            "Scripts/CI/hq-stage2-focused-apple.py": "original driver source fixture",
            "Scripts/CI/hq-stage2-focused-apple.inputs.json": json.dumps(self.config),
            "build/logs/hanlin-sdk-source.json": json.dumps({"sha": self.config["hanlin_gitlink"]}),
            "build/jsbundle/main.jsbundle": "current reviewed bundle fixture",
            "build/App.app/main.jsbundle": "current reviewed bundle fixture",
        }.items():
            target = self.root / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(value)
        self.driver = OriginalPreparationBoundary(self.root, self.config)
        self.report = {"status": "PREPARED_ORIGINAL_WORKSPACE_ONLY", "checkout_sha": self.driver.checkout,
                       "package_resolved_sha256": self.driver.digest(self.root / adapter.PROJECT_LOCK),
                       "package_pins": self.driver.pins(self.root / adapter.PROJECT_LOCK),
                       "native_context": self.driver.native_context(), "hanlin_sdk_source": {},
                       "inputs_sha256": self.driver.digest(self.input_path),
                       "original_driver_sha256": self.driver.digest(self.root / "Scripts/CI/hq-stage2-focused-apple.py"),
                       "resource_inputs": {"jsbundle_sha256": self.driver.digest(self.root / "build/jsbundle/main.jsbundle")}}

    def assert_refused(self, call, message):
        with self.assertRaisesRegex(RuntimeError, message):
            call()

    def test_resource_selection_preserves_exact_archive_and_excludes_same_run_engines_and_packages(self):
        original = copy.deepcopy(self.config)
        selected = adapter.resource_only_config(self.driver, self.config)
        self.assertEqual(selected["artifacts"], [a for a in original["artifacts"] if a["name"] == adapter.RESOURCE_NAME])
        self.assertEqual(self.config, original)
        self.assertEqual({k: v for k, v in selected.items() if k != "artifacts"}, {k: v for k, v in original.items() if k != "artifacts"})

    def test_ambiguous_resource_archive_is_rejected(self):
        item = next(a for a in self.config["artifacts"] if a["name"] == adapter.RESOURCE_NAME)
        self.config["artifacts"].append(copy.deepcopy(item))
        self.assert_refused(lambda: adapter.resource_only_config(self.driver, self.config), "exactly one")

    def test_missing_resource_archive_is_rejected(self):
        self.config["artifacts"] = [a for a in self.config["artifacts"] if a["name"] != adapter.RESOURCE_NAME]
        self.assert_refused(lambda: adapter.resource_only_config(self.driver, self.config), "exactly one")

    def test_tar_or_destination_cannot_enter_resource_only_restore(self):
        item = next(a for a in self.config["artifacts"] if a["name"] == adapter.RESOURCE_NAME)
        for key, value in [("tar", "SourcePackages.tar"), ("destination", "Vendor/OtzariaSearchEngine")]:
            with self.subTest(key=key):
                item[key] = value
                self.assert_refused(lambda: adapter.resource_only_config(self.driver, self.config), "cannot restore")
                del item[key]

    def test_resource_digest_and_identifier_are_required(self):
        item = next(a for a in self.config["artifacts"] if a["name"] == adapter.RESOURCE_NAME)
        for key, value in [("sha256", "unverified"), ("id", True), ("id", -1)]:
            with self.subTest(key=key, value=value):
                old = item[key]
                item[key] = value
                self.assert_refused(lambda: adapter.resource_only_config(self.driver, self.config), "cannot restore")
                item[key] = old

    def test_exact_reviewed_overlay_is_accepted(self):
        result = adapter.embedded_source_plan(self.driver, self.config)
        self.assertEqual(result, {"mode": "REBUILD_EXACT_REVIEWED_JS", "overlay_paths": [adapter.OVERLAY], "source_tree": self.driver.current_tree})

    def test_unreviewed_overlay_is_rejected(self):
        self.config["embedded_js_overlay_paths"] = [adapter.RESOURCE_ROOT + "/Integration/iOS/Unreviewed.m"]
        self.assert_refused(lambda: adapter.embedded_source_plan(self.driver, self.config), "Unreviewed")

    def test_unrelated_or_missing_source_delta_is_rejected(self):
        for changed in [[], [adapter.OVERLAY, adapter.UPSTREAM], [adapter.RESOURCE_ROOT + "/Integration/metro.config.embedded.js"]]:
            with self.subTest(changed=changed):
                self.driver.changed = changed
                self.assert_refused(lambda: adapter.embedded_source_plan(self.driver, self.config), "unrelated")

    def test_upstream_pin_drift_is_rejected(self):
        self.driver.upstream = "c" * 40
        self.assert_refused(lambda: adapter.embedded_source_plan(self.driver, self.config), "Sefaria pin drift")

    def test_unchanged_bundle_requires_full_resource_tree_equality(self):
        self.config["embedded_js_overlay_paths"] = []
        self.assertEqual(adapter.embedded_source_plan(self.driver, self.config)["mode"], "UNCHANGED_PINNED_BUNDLE")
        self.driver.producer_tree = "d" * 40
        self.assert_refused(lambda: adapter.embedded_source_plan(self.driver, self.config), "producer source differs")

    def test_shallow_fetch_is_exact_pinned_commit_only(self):
        with mock.patch.object(adapter.subprocess, "run", return_value=subprocess.CompletedProcess([], 1)) as run:
            adapter.ensure_resource_producer(self.driver, self.config, {})
        self.assertEqual(run.call_args.args[0], ["git", "cat-file", "-e", self.config["resource_producer_sha"] + "^{commit}"])
        self.assertEqual(self.driver.calls, [("command", ["git", "fetch", "--no-tags", "--depth", "1", "origin", self.config["resource_producer_sha"]])])

    def test_existing_producer_needs_no_fetch(self):
        with mock.patch.object(adapter.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)):
            adapter.ensure_resource_producer(self.driver, self.config, {})
        self.assertEqual(self.driver.calls, [])

    def test_non_sha_producer_cannot_trigger_fetch(self):
        self.config["resource_producer_sha"] = "main"
        with mock.patch.object(adapter.subprocess, "run") as run:
            self.assert_refused(lambda: adapter.ensure_resource_producer(self.driver, self.config, {}), "Invalid pinned")
        run.assert_not_called()

    def test_original_locks_and_workspace_are_accepted(self):
        adapter.verify_locks(self.driver, self.report)

    def test_each_lock_and_generated_project_or_workspace_drift_is_rejected(self):
        for path in [adapter.PROJECT_LOCK, "Podfile", "Podfile.lock", adapter.UPSTREAM + "/package-lock.json",
                     "Maktabah.xcodeproj/project.pbxproj", "Maktabah.xcworkspace/contents.xcworkspacedata"]:
            with self.subTest(path=path):
                target = self.root / path
                original = target.read_bytes()
                target.write_bytes(original + b"changed")
                self.assert_refused(lambda: adapter.verify_locks(self.driver, self.report), "Build input lock changed")
                target.write_bytes(original)

    def test_workspace_package_revision_drift_is_rejected(self):
        (self.root / adapter.WORKSPACE_LOCK).write_text('{"pins": []}')
        self.assert_refused(lambda: adapter.verify_locks(self.driver, self.report), "Workspace package revisions")

    def test_installed_upstream_head_drift_is_rejected(self):
        self.driver.upstream = "e" * 40
        self.assert_refused(lambda: adapter.verify_locks(self.driver, self.report), "React upstream changed")

    def test_environment_exports_only_original_build_keys(self):
        for key in adapter.ENV_KEYS:
            os.environ[key] = "value-for-" + key
        os.environ["GH_TOKEN"] = "must-not-be-exported"
        path = self.root / "github-env"
        adapter.export_environment(self.driver, path)
        self.assertEqual(path.read_text().splitlines(), [key + "=value-for-" + key for key in adapter.ENV_KEYS])

    def test_multiline_environment_is_rejected_before_any_write(self):
        for key in adapter.ENV_KEYS:
            os.environ[key] = "safe"
        os.environ["NODE_PATH"] = "safe\nUNTRUSTED=value"
        path = self.root / "github-env"
        self.assert_refused(lambda: adapter.export_environment(self.driver, path), "multiline")
        self.assertFalse(path.exists())

    def test_prepare_reuses_original_order_with_pinned_only_resolution_and_no_historical_binary_restore(self):
        report = {}
        with mock.patch.object(adapter.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, "-onlyUsePackageVersionsFromResolvedFile")):
            adapter.prepare(self.driver, self.config, report, self.root / "github-env")
        self.assertEqual([c[0] for c in self.driver.calls], ["react", "restore", "bundle", "pods", "command", "source", "hanlin"])
        restored = self.driver.calls[1][1]["artifacts"]
        self.assertEqual([a["name"] for a in restored], [adapter.RESOURCE_NAME])
        command = self.driver.calls[4][1]
        self.assertEqual(command, ["xcodebuild", "-resolvePackageDependencies", "-workspace", "Maktabah.xcworkspace", "-scheme", "Maktabah-iOS",
                                   "-clonedSourcePackagesDirPath", "build/SourcePackages", "-onlyUsePackageVersionsFromResolvedFile"])
        self.assertEqual(report["status"], "PREPARED_ORIGINAL_WORKSPACE_ONLY")
        self.assertFalse(report["app_build_executed"])
        self.assertEqual(report["runtime"], "NOT_RUN")

    def test_prepare_wrong_workflow_checkout_fails_before_mutation(self):
        os.environ["GITHUB_SHA"] = "f" * 40
        self.assert_refused(lambda: adapter.prepare(self.driver, self.config, {}, self.root / "github-env"), "Wrong workflow checkout")
        self.assertEqual(self.driver.calls, [])

    def test_preparation_failure_does_not_export_environment(self):
        self.driver.source_failure = True
        path = self.root / "github-env"
        with mock.patch.object(adapter.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, "-onlyUsePackageVersionsFromResolvedFile")):
            self.assert_refused(lambda: adapter.prepare(self.driver, self.config, {}, path), "original source validation failed")
        self.assertFalse(path.exists())

    def test_built_app_matching_bundle_checks_original_source_and_hanlin_without_runtime_claim(self):
        adapter.verify_app(self.driver, self.report, self.root / "build/App.app")
        self.assertEqual(self.report["status"], "BUILT_APP_ORIGINAL_INPUTS_VERIFIED")
        self.assertEqual(self.report["runtime"], "NOT_RUN")
        self.assertEqual(self.driver.calls, [("source", None), ("hanlin", True)])

    def test_missing_or_nonmatching_built_bundle_is_rejected(self):
        bundle = self.root / "build/App.app/main.jsbundle"
        bundle.unlink()
        self.assert_refused(lambda: adapter.verify_app(self.driver, self.report, bundle.parent), "no original Embedded bundle")
        bundle.write_text("different historical bundle")
        self.assert_refused(lambda: adapter.verify_app(self.driver, self.report, bundle.parent), "nonmatching Embedded bundle")

    def test_unprepared_or_stale_checkout_report_is_rejected(self):
        self.report["status"] = "FAIL"
        self.assert_refused(lambda: adapter.verify_app(self.driver, self.report, self.root / "build/App.app"), "Missing successful")
        self.report["status"] = "PREPARED_ORIGINAL_WORKSPACE_ONLY"
        self.driver.checkout = "f" * 40
        self.assert_refused(lambda: adapter.verify_app(self.driver, self.report, self.root / "build/App.app"), "Checkout changed")

    def test_modified_inputs_or_original_driver_are_rejected(self):
        for path in [self.input_path, self.root / "Scripts/CI/hq-stage2-focused-apple.py"]:
            with self.subTest(path=str(path)):
                original = path.read_bytes()
                path.write_bytes(original + b" ")
                self.assert_refused(lambda: adapter.verify_app(self.driver, self.report, self.root / "build/App.app"), "changed")
                path.write_bytes(original)

    def test_post_build_original_source_and_sdk_failure_propagate(self):
        for key, message in [("source_failure", "original source validation failed"), ("hanlin_failure", "original Hanlin validation failed")]:
            with self.subTest(key=key):
                setattr(self.driver, key, True)
                self.assert_refused(lambda: adapter.verify_app(self.driver, self.report, self.root / "build/App.app"), message)
                setattr(self.driver, key, False)

    def test_workflow_preserves_original_gates_with_workspace_and_destination_selected_sdks(self):
        for job, next_job, destination in [("simulator-build", "device-build", "generic/platform=iOS Simulator"),
                                           ("device-build", "native-bootstrap-heavy", "generic/platform=iOS")]:
            block = WORKFLOW.split("\n  " + job + ":", 1)[1].split("\n  " + next_job + ":", 1)[0]
            self.assertIn("-workspace Maktabah.xcworkspace", block)
            self.assertIn("-destination '" + destination + "'", block)
            self.assertNotIn("            -sdk ", block)
            self.assertIn("CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=\"\"", block)
            self.assertIn("prepare-ios-macro-authorization.py", block)
            self.assertIn("prepare-normal-ios-workspace.py --github-env", block)
            self.assertIn('prepare-normal-ios-workspace.py --verify-app "$APP"', block)
            self.assertIn("select-runtime27-toolchain.py --github-env", block)
            self.assertIn("node-version: 22", block)
            self.assertIn("ruby-version: '3.3'", block)
            self.assertNotIn("build/normal-ios-embedded/inputs", block)
        self.assertIn("Test Inspector backend mappings", WORKFLOW)
        self.assertIn('bash Scripts/run-ipad-simulator-acceptance.sh "$APP"', WORKFLOW)
        self.assertIn('echo "::error::Unsigned IPA contains runtime search data"', WORKFLOW)
        self.assertIn("name: Maktabah-iOS-unsigned-ipa-not-installable", WORKFLOW)
        self.assertIn("-disableAutomaticPackageResolution", WORKFLOW)
        self.assertNotIn("-skipMacroValidation", WORKFLOW)


class RecordingResult(unittest.TextTestResult):
    def startTest(self, test):
        super().startTest(test)
        self.executed.append(test.id().split(".")[-1])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(WorkspaceAdapterTests)
    declared = unittest.defaultTestLoader.getTestCaseNames(WorkspaceAdapterTests)
    RecordingResult.executed = []
    result = unittest.TextTestRunner(verbosity=2, resultclass=RecordingResult).run(suite)
    summary = {"scope": "PORTABLE_PYTHON_ADAPTER_WITH_EXPLICIT_APPLE_COMMAND_BOUNDARIES",
               "declared": declared, "executed": result.executed, "tests_run": result.testsRun,
               "failures": len(result.failures), "errors": len(result.errors), "skipped": len(result.skipped),
               "actual_apple_pods_npm_or_native_execution": False,
               "adapter_sha256": hashlib.sha256((HERE / "prepare-normal-ios-workspace.py").read_bytes()).hexdigest(),
               "workflow_sha256": hashlib.sha256((HERE.parents[1] / ".github/workflows/ios-build.yml").read_bytes()).hexdigest()}
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps(summary))
    return 0 if result.wasSuccessful() and result.testsRun == len(declared) and result.executed == declared else 1


if __name__ == "__main__":
    raise SystemExit(main())

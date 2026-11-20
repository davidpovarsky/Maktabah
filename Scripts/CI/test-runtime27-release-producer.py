#!/usr/bin/env python3
"""Synthetic producer/consumer integration fixtures; never Native acceptance."""
import copy
import hashlib
import json
from pathlib import Path
import runpy
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
producer = runpy.run_path(str(ROOT / "Scripts/CI/runtime27-release.py"))
gate = runpy.run_path(str(ROOT / "Scripts/CI/verify-runtime27-release-gate.py"))
dependency_fixture = runpy.run_path(str(ROOT / "Scripts/CI/test-runtime27-release-gate.py"))["dependency_fixture"]


class ReleaseProducerTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.root = Path(self.folder.name)
        self.sha = "a" * 40
        self.manifest = json.loads((ROOT / "Scripts/CI/runtime27-release-manifest.json").read_text(encoding="utf-8"))
        self.save("Scripts/CI/runtime27-release-manifest.json", self.manifest)
        self.manifest_sha = hashlib.sha256((self.root / "Scripts/CI/runtime27-release-manifest.json").read_bytes()).hexdigest()
        self.trees = {"Source": "source", "Vendor": "vendor", "Maktabah.xcodeproj": "project"}
        self.dependencies = dependency_fixture()
        self.report = {"checkout_sha": self.sha, "built_binary_sha256": self.binaries("Debug")}
        self.matrix = {"appSHA": self.sha, "baseline": False, "fullMatrixAcceptance": True, "diagnosticCases": [],
                       "releaseManifestSHA256": self.manifest_sha, "devices": [
                           {"size": size, "status": "EXECUTED_PASS", "ownedSimulatorCleanup": "PASS",
                            "udid": "owned-" + size, "runtime": {"version": "27.2", "buildversion": "fixture-27"},
                            "largeText": {"status": "EXECUTED_PASS", "actual": "accessibility-extra-extra-extra-large"}}
                           for size in ["11", "13", "phone"]]}
        self.production = {"appSHA": self.sha, "configuration": "Release", "dataProfile": "production",
                           "status": "EXECUTED_PASS", "udid": "owned-production",
                           "runtime": {"version": "27.2", "buildversion": "fixture-27"},
                           "built_binary_sha256": self.binaries("Release")}
        self.build = {"status": "SIMULATOR_BUILD_FOR_REAL_UI_PASS", "checkout_sha": self.sha,
                      "application_trees": self.trees, "package_pins": self.dependencies["package_pins"],
                      "package_resolved_sha256": self.dependencies["package_resolved_sha256"],
                      "actual_source_inputs_verified": 1,
                      "actual_package_checkouts": {key: {"head": value, "status": "CLEAN"} for key, value in self.dependencies["package_pins"].items()},
                      "hanlin_gitlink": self.dependencies["hanlin_sdk_source"]["sha"],
                      "hanlin_sdk_source": self.dependencies["hanlin_sdk_source"]}
        self.save("build/hq-stage2/result.json", self.build)
        for name in ["hanlin-sdk-inputs.json", "hanlin-sdk-inputs-after.json"]:
            self.save("build/hq-stage2/" + name, self.dependencies["hanlin_sdk_source"])
        for required in self.manifest["configurations"]:
            production = required["data_profile"] == "production"
            large = "content_size" in required
            label = "production-release" if production else "13-large-text" if large else required["device_size"]
            identities = required["required_ui_cases"] + required.get("required_oracle_cases", [])
            tree = {"devices": [{"deviceId": "owned-production" if production else "owned-" + required["device_size"],
                                 "osVersion": "27.2"}],
                    "testNodes": [{"nodeType": "UI test bundle", "name": "Maktabah-iOSUITests", "children": [
                        {"nodeType": "Test Suite", "name": identity.split("/")[0], "children": [
                            {"nodeType": "Test Case", "name": identity.split("/")[1] + "()",
                             "nodeIdentifier": identity + "()", "result": "Passed"}]} for identity in identities]}]}
            summary = {"result": "Passed", "totalTestCount": len(identities), "passedTests": len(identities),
                       "failedTests": 0, "skippedTests": 0, "expectedFailures": 0, "testFailures": []}
            prefix = "build/artifacts/runtime27/verified-" + label
            self.save(prefix + ".summary.json", summary)
            self.save(prefix + ".tests.json", tree)
            log = "\n".join("Test Case '-[" + value.replace("/", " ") + "]' passed (1 second)" for value in identities)
            observation = {"test": "fixture-" + label, "bundle_id": "com.davidpovarsky.chavrusatext", "locale": "he_IL",
                           "locale_source": "XCUIApplication.launchArguments/-AppleLocale",
                           "orientation": 1 if required["device_size"] == "phone" else 3,
                           "orientation_source": "XCUIDevice.shared.orientation", "foreground": True}
            log += "\nR27_RUNTIME_CONFIGURATION " + json.dumps(observation)
            log += f"\nExecuted {len(identities)} tests\n** TEST SUCCEEDED **\n"
            log_path = "build/artifacts/production-release-tests.log" if production else "build/artifacts/test-simulator-" + label + ".log"
            self.write(log_path, log)
            data = {"passed": True, "profileID": required["data_profile"], "shaMatched": True,
                    "expectedSHA256": "f" * 64, "actualSHA256": "f" * 64, "quickCheck": "ok",
                    "bookCount": 7876 if production else 10, "extractedBytes": 3821240320 if production else 100000}
            data_path = ("build/artifacts/production-native-fixture-install.json" if production
                         else "build/artifacts/miniTest10-native-fixture-install-" + required["device_size"] + ".json")
            self.save(data_path, data)
        self.persist_runners()

    def binaries(self, configuration):
        prefix = f"build/{'ReleaseDerivedData' if configuration == 'Release' else 'DerivedData'}/Build/Products/{configuration}-iphonesimulator/"
        return {prefix + "Maktabah.app": "a" * 64,
                prefix + "Maktabah-iOSUITests-Runner.app/PlugIns/Maktabah-iOSUITests.xctest": "b" * 64}

    def write(self, name, text):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def save(self, name, value):
        self.write(name, json.dumps(value, indent=2) + "\n")

    def persist_runners(self):
        self.save("build/artifacts/faithful-ipad-matrix.json", self.matrix)
        self.save("build/artifacts/production-release-acceptance.json", self.production)

    def candidate(self):
        self.persist_runners()
        return {**self.report, "status": "EXECUTED_PASS", "scope": "full-release-ui",
                "full_release_acceptance": True, "release_manifest_sha256": self.manifest_sha,
                "configurations": producer["collect_configurations"](self.root, self.report, self.manifest)}

    def check(self):
        return gate["verify_artifact_evidence"](
            self.root / "build", self.sha, self.manifest, self.manifest_sha, self.trees,
            required_inputs=self.dependencies, result=self.candidate())

    def test_complete_synthetic_producer_payload_reaches_unchanged_real_evidence_checks(self):
        result = self.check()
        self.assertEqual(result["required_ui_passed"], 96)
        self.assertEqual(result["separate_oracle_executed"], 2)
        self.assertEqual(len(result["configurations"]), 5)

    def test_partial_and_stale_matrix_rejected_before_acceptance(self):
        for field, value in [("fullMatrixAcceptance", False), ("appSHA", "f" * 40),
                             ("diagnosticCases", ["Suite/testSubset"]), ("releaseManifestSHA256", "stale")]:
            previous = self.matrix[field]
            self.matrix[field] = value
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, "partial, stale"):
                self.candidate()
            self.matrix[field] = previous

    def test_missing_or_duplicate_native_device_rejected(self):
        original = copy.deepcopy(self.matrix["devices"])
        for devices in [original[:2], [original[0], original[0], original[2]]]:
            self.matrix["devices"] = devices
            with self.assertRaisesRegex(ValueError, "Missing or duplicate"):
                self.candidate()

    def test_production_flags_cannot_replace_real_release(self):
        for field, value in [("status", "NOT_RUN"), ("configuration", "Debug"),
                             ("dataProfile", "miniTest10"), ("appSHA", "f" * 40)]:
            previous = self.production[field]
            self.production[field] = value
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, "full-corpus"):
                self.candidate()
            self.production[field] = previous

    def test_missing_and_background_only_observations_cannot_be_invented(self):
        path = self.root / "build/artifacts/test-simulator-11.log"
        original = path.read_text(encoding="utf-8")
        for content in ["\n".join(line for line in original.splitlines() if "R27_RUNTIME_CONFIGURATION" not in line),
                        original.replace('"foreground": true', '"foreground": false')]:
            path.write_text(content, encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "No foreground"):
                self.candidate()

    def test_wrong_actual_text_size_rejected(self):
        self.matrix["devices"][1]["largeText"]["actual"] = "large"
        with self.assertRaisesRegex(ValueError, "actual system accessibility"):
            self.candidate()

    def test_pass_flags_without_raw_results_are_not_acceptance(self):
        (self.root / "build/artifacts/runtime27/verified-13-large-text.tests.json").unlink()
        with self.assertRaisesRegex(ValueError, "Required evidence missing"):
            self.check()

    def test_missing_original_oracle_is_rejected_independently_of_native_count(self):
        path = self.root / "build/artifacts/runtime27/verified-11.tests.json"
        tree = json.loads(path.read_text(encoding="utf-8"))
        tree["testNodes"][0]["children"].pop()
        self.save(str(path.relative_to(self.root)), tree)
        with self.assertRaises(ValueError):
            self.check()

    def test_skip_cannot_be_promoted_to_a_pass(self):
        path = "build/artifacts/runtime27/verified-phone.summary.json"
        summary = json.loads((self.root / path).read_text(encoding="utf-8"))
        summary["skippedTests"] = 1
        self.save(path, summary)
        with self.assertRaises(ValueError):
            self.check()

    def test_wrong_actual_device_and_os_cannot_be_relabelled(self):
        path = "build/artifacts/runtime27/verified-phone.tests.json"
        tree = json.loads((self.root / path).read_text(encoding="utf-8"))
        tree["devices"][0]["osVersion"] = "26.2"
        self.save(path, tree)
        with self.assertRaisesRegex(ValueError, "actual device/OS"):
            self.check()

    def test_miniature_data_cannot_satisfy_production(self):
        path = "build/artifacts/production-native-fixture-install.json"
        data = json.loads((self.root / path).read_text(encoding="utf-8"))
        data["bookCount"] = 10
        self.save(path, data)
        with self.assertRaisesRegex(ValueError, "full real corpus"):
            self.check()

    def test_dependency_drift_remains_blocking_after_producer_aggregation(self):
        self.build["actual_package_checkouts"]["fixture-1"]["head"] = "f" * 40
        self.save("build/hq-stage2/result.json", self.build)
        with self.assertRaisesRegex(ValueError, "pinned package source mismatch"):
            self.check()

    def test_current_manifest_names_real_compilable_target_declarations(self):
        manifest = producer["load_manifest"](ROOT)
        self.assertEqual(sum(len(row["required_ui_cases"]) for row in manifest["configurations"]), 96)
        self.assertEqual({row["id"]: len(row["required_ui_cases"]) for row in manifest["configurations"]},
                         {"ipad11-native": 54, "ipad13-native": 34, "ipad13-largest-text": 1,
                          "iphone-native": 6, "ipad13-production-release": 1})
        self.assertEqual(sum(len(row.get("required_oracle_cases", [])) for row in manifest["configurations"]), 2)
        self.assertEqual(manifest["prepared_source_requirements"][0]["path"],
                         "Maktabah-iOSUITests/Sidebar11201AcceptanceTests.swift")


if __name__ == "__main__":
    unittest.main(verbosity=2)

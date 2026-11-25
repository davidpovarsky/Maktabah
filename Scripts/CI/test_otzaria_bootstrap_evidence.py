"""Controlled report vectors against retained real v32/v40 release metadata."""
import contextlib
import copy
import io
import os
import hashlib
import json
from pathlib import Path
import runpy
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
F = ROOT / "Tests/HQ/latest-multipart"
V = runpy.run_path(str(ROOT / "Scripts/CI/otzaria_bootstrap_evidence.py"))
V40 = json.loads((F / "official-v40-release.json").read_bytes())
V32 = json.loads((F / "official-v32-release.json").read_bytes())
MANIFEST = (F / "official-v40-manifest.json").read_bytes()
M = json.loads(MANIFEST)


def report(release, multipart):
    suffix = ".manifest.json" if multipart else ".db.zst"
    asset = next(a for a in release["assets"] if a["name"].endswith(suffix)
                 and (multipart or V["ARCHIVE_NAME"].fullmatch(a["name"])))
    return {"passed": True, "phase": "install", "profileID": "production", "profileVersion": 1,
            "releaseID": release["id"], "releaseTag": release["tag_name"],
            "assetID": asset["id"], "assetName": asset["name"],
            "assetBytes": asset["size"], "assetDigest": asset["digest"],
            "archiveName": M["archive"] if multipart else asset["name"],
            "expectedCompressedBytes": M["size"] if multipart else asset["size"],
            "expectedSHA256": M["sha256"] if multipart else asset["digest"][7:],
            "actualSHA256": M["sha256"] if multipart else asset["digest"][7:],
            "shaMatched": True}


def phases():
    install = report(V40, True)
    install.update(quickCheck="ok", requiredTables=["book", "line", "category"],
                   bookCount=7001, lineCount=100000, source="managedInternal",
                   finalPath="/controlled-original-app-group/Otzaria/seforim.db",
                   resumeFromBytes=67_108_864, errors=[])
    for key in ("partCleanedAfterSuccess", "sidecarCleanedAfterSuccess", "finalExists",
                "stagingAbsentAfterSuccess", "previousAbsentAfterSuccess",
                "installationManifestExists", "backupExcluded",
                "managedWithoutSecurityScope", "dictionaryConfigured"):
        install[key] = True
    cancel = copy.deepcopy(install)
    cancel.update(phase="cancel", finalExists=False, downloadedBytes=67_108_864)
    restore = copy.deepcopy(install)
    restore.update(phase="restore", restoreAfterRelaunch=True)
    return cancel, install, restore


class BootstrapEvidenceControls(unittest.TestCase):
    def test_authentic_v40_remote_manifest_is_distinct_from_full_archive(self):
        result = V["validate_release_report"](report(V40, True), V40, MANIFEST)
        self.assertEqual(result["remote_asset"]["bytes"], 589)
        self.assertEqual(result["archive"]["bytes"], 2_129_902_636)
        self.assertEqual(len(result["parts"]), 2)

    def test_authentic_v32_direct_asset_keeps_equal_archive_identity(self):
        result = V["validate_release_report"](report(V32, False), V32)
        self.assertEqual(result["remote_asset"]["bytes"], result["archive"]["bytes"])
        self.assertEqual(result["parts"], [])

    def test_archive_bytes_cannot_replace_manifest_asset_bytes(self):
        value = report(V40, True)
        value["assetBytes"] = value["expectedCompressedBytes"]
        with self.assertRaisesRegex(ValueError, "remote asset bytes"):
            V["validate_release_report"](value, V40, MANIFEST)

    def test_manifest_hash_cannot_replace_archive_hash(self):
        value = report(V40, True)
        value["expectedSHA256"] = value["assetDigest"][7:]
        with self.assertRaisesRegex(ValueError, "archive facts"):
            V["validate_release_report"](value, V40, MANIFEST)

    def test_changed_manifest_bytes_are_rejected_before_decoding(self):
        changed = bytearray(MANIFEST)
        changed[10] ^= 1
        with self.assertRaisesRegex(ValueError, "manifest bytes/hash"):
            V["validate_release_report"](report(V40, True), V40, bytes(changed))

    def test_part_digest_must_match_actual_official_asset(self):
        release = copy.deepcopy(V40)
        part = next(a for a in release["assets"] if a["name"].endswith("part-001"))
        part["digest"] = "sha256:" + "0" * 64
        with self.assertRaisesRegex(ValueError, "part bytes/hash"):
            V["validate_release_report"](report(V40, True), release, MANIFEST)

    def test_different_official_release_is_rejected(self):
        value = report(V40, True)
        value["releaseID"] += 1
        with self.assertRaisesRegex(ValueError, "different official release"):
            V["validate_release_report"](value, V40, MANIFEST)

    def test_three_original_phases_require_actual_nonzero_resume(self):
        cancel, install, restore = phases()
        actual = V["validate_phases"](cancel, install, restore, V40, MANIFEST, True)
        self.assertEqual(actual["resumed_bytes"], 67_108_864)
        install["resumeFromBytes"] = 0
        with self.assertRaisesRegex(ValueError, "actually resume"):
            V["validate_phases"](cancel, install, restore, V40, MANIFEST, True)

    def test_restore_count_change_is_rejected(self):
        cancel, install, restore = phases()
        restore["lineCount"] += 1
        with self.assertRaisesRegex(ValueError, "restoration changed"):
            V["validate_phases"](cancel, install, restore, V40, MANIFEST, True)

    def test_native_sqlite_failure_cannot_be_relabelled_by_pass_boolean(self):
        cancel, install, restore = phases()
        install["quickCheck"] = "corrupt"
        with self.assertRaisesRegex(ValueError, "SQLite/count"):
            V["validate_phases"](cancel, install, restore, V40, MANIFEST, True)

    def test_install_final_path_must_be_absolute_and_present(self):
        for value in (None, "", "relative.db", "/managed/db\n", "/managed/db\r", 7):
            with self.subTest(path=value):
                cancel, install, restore = phases()
                install["finalPath"] = value
                with self.assertRaisesRegex(ValueError, "managed database path"):
                    V["validate_phases"](cancel, install, restore, V40, MANIFEST, True)

    def test_restore_final_path_must_be_absolute_and_present(self):
        for value in (None, "", "relative.db", "/managed/db\n", "/managed/db\r", 7):
            with self.subTest(path=value):
                cancel, install, restore = phases()
                restore["finalPath"] = value
                with self.assertRaisesRegex(ValueError, "managed database path"):
                    V["validate_phases"](cancel, install, restore, V40, MANIFEST, True)

    def test_cancel_errors_are_rejected_despite_pass_boolean(self):
        cancel, install, restore = phases()
        cancel["errors"] = ["Original cancellation reported an error"]
        with self.assertRaisesRegex(ValueError, "cancellation contains errors"):
            V["validate_phases"](cancel, install, restore, V40, MANIFEST, True)


class NativeBootstrapSimulatorSelectionControls(unittest.TestCase):
    """Execute the actual embedded selector with read-only command fixtures."""

    owned = "A70351BD-421A-4D71-9BF7-22111F992113"
    phone = "BC343199-34F4-4E9F-A148-644990D9A1B2"
    runtime = "com.apple.CoreSimulator.SimRuntime.iOS-27-2"

    def setUp(self):
        script = (ROOT / "Scripts/run-otzaria-native-bootstrap-acceptance.sh").read_text()
        prefix = "UDID=\"$(python3 <<'PY'\n"
        suffix = "\nPY\n)"
        self.assertEqual(script.count(prefix), 1)
        body = script.split(prefix, 1)[1]
        self.assertIn(suffix, body)
        self.selector = compile(body.split(suffix, 1)[0],
                                "actual-native-bootstrap-embedded-selector", "exec")
        self.calls = []
        self.output = io.StringIO()

    def command(self, argv, **kwargs):
        self.calls.append((argv, kwargs))
        if argv == ["xcrun", "simctl", "list", "runtimes", "available", "-j"]:
            self.assertEqual(kwargs, {})
            return json.dumps({"runtimes": [{"identifier": self.runtime, "version": "27.2",
                                             "isAvailable": True}]}).encode()
        if argv == ["xcrun", "simctl", "list", "devices", "available", "-j"]:
            self.assertEqual(kwargs, {})
            return json.dumps({"devices": {self.runtime: [
                {"udid": self.owned, "isAvailable": True, "name": "Owned iPad",
                 "deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5"},
                {"udid": self.phone, "isAvailable": True, "name": "iPhone fixture",
                 "deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-17"}
            ]}}).encode()
        if argv == ["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"]:
            self.assertEqual(kwargs, {"text": True})
            return "27.2\n"
        raise AssertionError("Undeclared selector command: " + repr(argv))

    def execute_selector(self, environment):
        with mock.patch.dict(os.environ, environment, clear=True), \
                mock.patch("subprocess.check_output", side_effect=self.command), \
                contextlib.redirect_stdout(self.output):
            exec(self.selector, {"__name__": "controlled_original_selector"})

    def test_empty_explicit_owned_id_never_falls_back(self):
        with self.assertRaises(ValueError):
            self.execute_selector({"OTZARIA_NATIVE_BOOTSTRAP_OWNED_UDID": ""})
        self.assertEqual(self.output.getvalue(), "")
        self.assertEqual(len(self.calls), 2)

    def test_valid_owned_sdk_matched_ipad_is_selected(self):
        with self.assertRaises(SystemExit) as stopped:
            self.execute_selector({"OTZARIA_NATIVE_BOOTSTRAP_OWNED_UDID": self.owned})
        self.assertEqual(stopped.exception.code, 0)
        self.assertEqual(self.output.getvalue(), self.owned + "\n")
        self.assertEqual(len(self.calls), 3)

    def test_absent_owned_id_preserves_original_selection(self):
        self.execute_selector({})
        self.assertEqual(self.output.getvalue(), self.phone + "\n")
        self.assertEqual(len(self.calls), 2)


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Source-integrity refusal tests; these do not award app/runtime acceptance."""
import copy
import hashlib
import json
from pathlib import Path
import runpy
import subprocess
import tempfile
import unittest

API = runpy.run_path(str(Path(__file__).with_name("original_editor_hanlin_equivalence.py")))
PACKAGE = API["BRIDGE_ROOT"]
PICKER = API["PICKER_PATH"]
ORIGINAL_PICKER = """private struct NativePicker {
    func row() {
        originalLabel
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    private func update() {}
}
"""
REVIEWED_PICKER = ORIGINAL_PICKER.replace(
    "        .frame(maxWidth: .infinity, alignment: .leading)\n",
    "        .frame(maxWidth: .infinity, alignment: .leading)\n        .contentShape(Rectangle())\n")


class MiniAppsSourceIntegrityTests(unittest.TestCase):
    def git(self, root, *args):
        return subprocess.check_output(
            ["git", "-c", "user.name=Source integrity test",
             "-c", "user.email=source-integrity@example.invalid", "-C", str(root), *args],
            stderr=subprocess.PIPE).decode().strip()

    def commit_sdk(self):
        self.git(self.sdk, "add", PACKAGE)
        self.git(self.sdk, "commit", "-qm", "Source integrity fixture")
        return self.git(self.sdk, "rev-parse", "HEAD")

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="miniapps-source-integrity-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.sdk = self.root / "Vendor/HanlinSDK"
        self.sdk.mkdir(parents=True)
        self.git(self.root, "init", "-q")
        self.git(self.sdk, "init", "-q")
        fixtures = {
            PACKAGE + "/Package.swift": "// Original fixture package membership\n",
            PACKAGE + "/Sources/HanlinMiniAppsBridge/MiniAppContracts.swift": "// Original transport fixture\n",
            PICKER: ORIGINAL_PICKER,
            PACKAGE + "/Sources/HanlinMiniAppsPicker/Resources/he.lproj/Localizable.strings": '"More" = "עוד";\n',
        }
        for name, value in fixtures.items():
            path = self.sdk / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(value)
        self.producer = self.commit_sdk()
        (self.sdk / PICKER).write_text(REVIEWED_PICKER)
        self.consumer = self.commit_sdk()
        self.review = API["build_miniapps_review"](self.sdk, self.producer, self.consumer)
        self.pin = self.commit_review(self.review)

    def commit_review(self, review):
        path = self.root / "Scripts/CI/miniapps-review.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(review, sort_keys=True, indent=2) + "\n")
        self.git(self.root, "add", "Scripts/CI/miniapps-review.json")
        self.git(self.root, "update-index", "--add", "--cacheinfo",
                 "160000", self.consumer, "Vendor/HanlinSDK")
        self.git(self.root, "commit", "-qm", "Pinned source integrity review")
        return {"path": "Scripts/CI/miniapps-review.json",
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}

    def admitted(self, pin=None):
        return API["read_miniapps_review"](
            self.root, pin or self.pin, self.producer, self.consumer)

    def verify(self, pinned=None):
        return API["verify_miniapps_sources"](
            self.root, self.producer, self.consumer, self.admitted() if pinned is None else pinned)

    def test_accepts_only_reviewed_picker_insertion_with_every_file(self):
        proof = self.verify()
        self.assertEqual(proof["verified_files"], 4)
        self.assertFalse(proof["new_native_acceptance"])
        self.assertEqual(proof["source_review"]["producer"]["revision"], self.producer)
        self.assertEqual(proof["source_review"]["consumer"]["revision"], self.consumer)

    def test_same_revision_requires_no_compatibility_exception(self):
        proof = API["verify_miniapps_sources"](self.root, self.consumer, self.consumer)
        self.assertIsNone(proof["source_review"]["reviewed_picker_change"])

    def test_rejects_distinct_revisions_without_review(self):
        with self.assertRaisesRegex(RuntimeError, "need an exact committed review"):
            API["verify_miniapps_sources"](self.root, self.producer, self.consumer)

    def test_rejects_omitted_review_file(self):
        review = copy.deepcopy(self.review)
        del review["consumer_files"][PACKAGE + "/Package.swift"]
        pin = self.commit_review(review)
        with self.assertRaisesRegex(RuntimeError, "differs from complete original Git source"):
            self.verify(self.admitted(pin))

    def test_rejects_uncommitted_review_even_with_matching_digest(self):
        path = self.root / self.pin["path"]
        path.write_text(path.read_text() + "\n")
        pin = {**self.pin, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
        with self.assertRaisesRegex(RuntimeError, "not the committed file"):
            self.admitted(pin)

    def test_rejects_changed_working_source(self):
        (self.sdk / PICKER).write_text(REVIEWED_PICKER + "// uncommitted\n")
        with self.assertRaisesRegex(RuntimeError, "package bytes differ"):
            self.verify()

    def test_rejects_extra_working_source(self):
        (self.sdk / PACKAGE / "untracked.swift").write_text("// extra membership\n")
        with self.assertRaisesRegex(RuntimeError, "missing or additional files"):
            self.verify()

    def test_rejects_original_transport_change(self):
        path = self.sdk / PACKAGE / "Sources/HanlinMiniAppsBridge/MiniAppContracts.swift"
        path.write_text("// changed transport contract\n")
        changed = self.commit_sdk()
        with self.assertRaisesRegex(RuntimeError, "transport and contract source trees differ"):
            API["build_miniapps_review"](self.sdk, self.producer, changed)

    def test_rejects_another_picker_behavior_change(self):
        (self.sdk / PICKER).write_text(REVIEWED_PICKER.replace("originalLabel", "differentBehavior"))
        changed = self.commit_sdk()
        with self.assertRaisesRegex(RuntimeError, "beyond the single original row"):
            API["build_miniapps_review"](self.sdk, self.producer, changed)

    def test_rejects_changed_source_mode(self):
        (self.sdk / PACKAGE / "Package.swift").chmod(0o755)
        changed = self.commit_sdk()
        with self.assertRaisesRegex(RuntimeError, "mode changes or renames"):
            API["build_miniapps_review"](self.sdk, self.producer, changed)

    def test_rejects_different_checkout(self):
        self.git(self.sdk, "checkout", "-q", self.producer)
        with self.assertRaisesRegex(RuntimeError, "gitlink or checkout differs"):
            self.verify()

    def test_rejects_swapped_producer_consumer_target(self):
        review = copy.deepcopy(self.review)
        review["consumer"]["target"] = "HanlinMiniApps"
        pin = self.commit_review(review)
        with self.assertRaisesRegex(RuntimeError, "different producer or consumer targets"):
            self.admitted(pin)

    def test_legacy_binary_sdk_identity_guard_is_preserved(self):
        review = {
            "schema": "otzaria.shared-hanlin-source-equivalence/1", "scope": API["SCOPE"],
            "sdk_producer_revision": self.producer, "consumer_revision": self.consumer,
            "miniapps_producer_revision": self.consumer,
            "shared_trees": {path: "1" * 40 for path in API["SHARED_ROOTS"]},
            "miniapps_shared_trees": self.review["consumer_trees"],
        }
        pin = self.commit_review(review)
        self.assertEqual(API["read_review"](self.root, pin, self.producer)["review"], review)
        review["miniapps_producer_revision"] = self.producer
        pin = self.commit_review(review)
        with self.assertRaisesRegex(RuntimeError, "different producer or consumer identity"):
            API["read_review"](self.root, pin, self.producer)


if __name__ == "__main__":
    unittest.main()

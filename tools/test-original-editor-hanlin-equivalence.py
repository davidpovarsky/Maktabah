#!/usr/bin/env python3
"""Real Git/source admission controls only; zero Apple or native UI credit."""
import argparse
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("equivalence", ROOT / "Scripts/CI/original_editor_hanlin_equivalence.py")
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


def git(path, *args):
    return subprocess.check_output(["git", "-C", str(path), *args], stderr=subprocess.DEVNULL).decode().strip()


class SourceEquivalence(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "host"
        self.root.mkdir()
        git(self.root, "init", "-q")
        git(self.root, "config", "user.name", "Source admission control")
        git(self.root, "config", "user.email", "source-control@example.invalid")
        self.sdk = self.root / "Vendor/HanlinSDK"
        self.sdk.mkdir(parents=True)
        git(self.sdk, "init", "-q")
        git(self.sdk, "config", "user.name", "Source admission control")
        git(self.sdk, "config", "user.email", "source-control@example.invalid")
        for path in (*m.SHARED_ROOTS, m.BRIDGE_ROOT):
            p = self.sdk / path / "Package.swift"
            p.parent.mkdir(parents=True)
            p.write_text("// admission control, never compiled\n")
        for name in ("HanlinMiniAppsBridge", "HanlinMiniAppsPicker"):
            p = self.sdk / m.BRIDGE_ROOT / "Sources" / name / "Control.swift"
            p.parent.mkdir(parents=True)
            p.write_text("// " + name + " source admission only\n")
        git(self.sdk, "add", ".")
        git(self.sdk, "commit", "-qm", "Original shared source fixture")
        self.producer = git(self.sdk, "rev-parse", "HEAD")
        (self.sdk / "outside.txt").write_text("Monorepo-only change outside complete packages\n")
        git(self.sdk, "add", "outside.txt")
        git(self.sdk, "commit", "-qm", "Unconsumed monorepo change")
        self.consumer = git(self.sdk, "rev-parse", "HEAD")
        git(self.root, "update-index", "--add", "--cacheinfo", "160000", self.consumer, "Vendor/HanlinSDK")
        self.review_path = self.root / "Scripts/CI/review.json"
        self.review_path.parent.mkdir(parents=True)
        self.review = {
            "schema": "otzaria.shared-hanlin-source-equivalence/1",
            "scope": m.SCOPE,
            "sdk_producer_revision": self.producer,
            "consumer_revision": self.consumer,
            "miniapps_producer_revision": self.consumer,
            "shared_trees": {p: m.tree(self.sdk, self.consumer, p) for p in m.SHARED_ROOTS},
            "miniapps_shared_trees": {p: m.tree(self.sdk, self.consumer, p) for p in m.MINIAPPS_TREES},
        }
        self.commit_review()
        files = m.leaves(self.sdk, self.consumer, [*m.SHARED_ROOTS, m.BRIDGE_ROOT])
        self.source = {"sha": self.consumer, "layout": [*m.SHARED_ROOTS, m.BRIDGE_ROOT],
                       "verified_files": len(files), "git_blobs": files}
        self.shared = {"hanlin_revision": self.producer,
                       "ownership": {"hanlin_package_files": {
                           p: m.digest(self.sdk / p) for p in files
                           if p.startswith(tuple(x + "/" for x in m.SHARED_ROOTS))}},
                       "host_source_equivalence": m.read_review(self.root, self.pin, self.producer)}

    def commit_review(self):
        self.review_path.write_text(json.dumps(self.review, sort_keys=True, indent=2) + "\n")
        git(self.root, "add", "Scripts/CI/review.json")
        git(self.root, "commit", "-qm", "Pin exact reviewed package equivalence")
        self.pin = {"path": "Scripts/CI/review.json", "sha256": m.digest(self.review_path)}

    def call(self):
        before = (self.root / ".git/index").read_bytes()
        try:
            return m.verify_hanlin_sources(self.root, self.shared, self.source)
        finally:
            self.assertEqual(before, (self.root / ".git/index").read_bytes())

    def deny(self):
        with self.assertRaises((RuntimeError, ValueError)):
            self.call()

    def test_exact_complete_review_preserves_distinct_identities(self):
        before = copy.deepcopy(self.shared)
        files, proof = self.call()
        self.assertEqual(files, self.source["git_blobs"])
        self.assertEqual(proof["producer_hanlin_revision"], self.producer)
        self.assertEqual(proof["host_hanlin_revision"], self.consumer)
        self.assertEqual(proof["additional_miniapps_files"], 3)
        self.assertEqual(before, self.shared)

    def test_original_three_package_same_revision_route_retained(self):
        self.source["sha"] = self.producer
        self.source["git_blobs"] = {p: h for p, h in self.source["git_blobs"].items()
                                   if not p.startswith(m.BRIDGE_ROOT + "/")}
        del self.shared["host_source_equivalence"]
        _, proof = self.call()
        self.assertIsNone(proof["source_equivalence"])
        self.assertEqual(proof["additional_miniapps_files"], 0)

    def test_revision_change_without_review_is_rejected(self):
        del self.shared["host_source_equivalence"]
        self.deny()

    def test_fourth_package_without_review_is_rejected(self):
        del self.shared["host_source_equivalence"]
        self.source["sha"] = self.producer
        self.deny()

    def test_missing_report_member_is_rejected(self):
        self.source["git_blobs"].pop(next(iter(self.source["git_blobs"])))
        self.source["verified_files"] = len(self.source["git_blobs"])
        self.deny()

    def test_added_report_member_is_rejected(self):
        self.source["git_blobs"][m.BRIDGE_ROOT + "/Sources/Unexpected.swift"] = "0" * 40
        self.source["verified_files"] = len(self.source["git_blobs"])
        self.deny()

    def test_incomplete_package_layout_is_rejected(self):
        self.source["layout"].pop()
        self.deny()

    def test_wrong_report_revision_is_rejected(self):
        self.source["sha"] = self.producer
        self.deny()

    def test_wrong_checkout_revision_is_rejected(self):
        git(self.sdk, "checkout", "-q", self.producer)
        self.deny()

    def test_wrong_host_gitlink_is_rejected(self):
        git(self.root, "update-index", "--cacheinfo", "160000", self.producer, "Vendor/HanlinSDK")
        git(self.root, "commit", "-qm", "Wrong host source pin control")
        self.deny()

    def test_changed_core_bytes_are_rejected(self):
        (self.sdk / m.SHARED_ROOTS[0] / "Package.swift").write_text("changed\n")
        self.deny()

    def test_changed_picker_bytes_are_rejected(self):
        (self.sdk / m.BRIDGE_ROOT / "Sources/HanlinMiniAppsPicker/Control.swift").write_text("changed\n")
        self.deny()

    def test_extra_working_swift_source_is_rejected(self):
        (self.sdk / m.BRIDGE_ROOT / "Sources/HanlinMiniAppsPicker/Unexpected.swift").write_text("unexpected\n")
        self.deny()

    def test_incomplete_qualified_sdk_membership_is_rejected(self):
        self.shared["ownership"]["hanlin_package_files"].pop(next(iter(self.shared["ownership"]["hanlin_package_files"])))
        self.deny()

    def test_changed_review_even_with_matching_working_hash_is_rejected(self):
        self.review["scope"] = "Changed"
        self.review_path.write_text(json.dumps(self.review))
        self.shared["host_source_equivalence"]["pin"]["sha256"] = m.digest(self.review_path)
        self.deny()

    def test_committed_wrong_package_tree_is_rejected(self):
        self.review["shared_trees"][m.SHARED_ROOTS[0]] = "0" * 40
        self.commit_review()
        self.shared["host_source_equivalence"] = m.read_review(self.root, self.pin, self.producer)
        self.deny()

    def test_committed_wrong_picker_tree_is_rejected(self):
        self.review["miniapps_shared_trees"][m.MINIAPPS_TREES[-1]] = "0" * 40
        self.commit_review()
        self.shared["host_source_equivalence"] = m.read_review(self.root, self.pin, self.producer)
        self.deny()

    def test_mismatched_miniapps_producer_is_rejected(self):
        self.review["miniapps_producer_revision"] = self.producer
        self.commit_review()
        with self.assertRaises(RuntimeError):
            m.read_review(self.root, self.pin, self.producer)

    def test_symlinked_bridge_source_is_rejected(self):
        p = self.sdk / m.BRIDGE_ROOT / "Sources/HanlinMiniAppsPicker/Control.swift"
        original = p.read_bytes()
        p.unlink()
        target = self.root / "copied.swift"
        target.write_bytes(original)
        p.symlink_to(target)
        self.deny()

    def test_review_path_escape_is_rejected(self):
        for path in ("../Scripts/CI/review.json", "/Scripts/CI/review.json", "Scripts/CI/../CI/review.json"):
            with self.subTest(path=path), self.assertRaises(RuntimeError):
                m.read_review(self.root, {"path": path, "sha256": self.pin["sha256"]}, self.producer)


if __name__ == "__main__":
    unittest.main(verbosity=2)

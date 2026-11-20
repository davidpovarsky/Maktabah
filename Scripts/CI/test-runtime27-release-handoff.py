#!/usr/bin/env python3
"""Synthetic archive/provenance controls. These never execute or certify iOS UI."""
import copy
import hashlib
import io
import json
import os
from pathlib import Path
import plistlib
import stat
import subprocess
import tarfile
import tempfile
import unittest
from unittest.mock import patch

import runtime27_release_handoff as handoff


def fixture_context():
    return {"repository": handoff.REPOSITORY, "workflow": handoff.WORKFLOW,
            "checkout_sha": "a" * 40, "run_id": 101, "run_attempt": 2,
            "trees": {"Source": "b" * 40, "Vendor": "c" * 40,
                      "Maktabah.xcodeproj": "d" * 40, "Maktabah-iOSUITests": "e" * 40},
            "release_manifest_sha256": "1" * 64, "inputs_sha256": "2" * 64,
            "workflow_sha256": "3" * 64, "reviewed_driver_inputs": {"files": 123, "sha256": "4" * 64},
            "xcode": "SYNTHETIC Xcode 27.2 build fixture", "swift_compiler": "SYNTHETIC Swift 6.4.2",
            "sdk": "27.2", "runtime": {"identifier": "fixture.iOS-27-2", "version": "27.2", "build": "fixture"}}


def write(path, value=b"synthetic fixture bytes", mode=0o644):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(value)
    path.chmod(mode)
    return path


def products(root):
    base = root / handoff.PRODUCT_ROOTS[0]
    app = write(base / "Debug-iphonesimulator/Maktabah.app/Maktabah", mode=0o755)
    write(app.parent / "main.jsbundle", b"synthetic original embedded resource")
    runner = write(base / "Debug-iphonesimulator/Maktabah-iOSUITests-Runner.app/Runner", mode=0o755)
    write(runner.parent / "PlugIns/Maktabah-iOSUITests.xctest/Tests", mode=0o755)
    target = {"TestHostPath": "__TESTROOT__/Debug-iphonesimulator/Maktabah-iOSUITests-Runner.app",
              "TestBundlePath": "__TESTHOST__/PlugIns/Maktabah-iOSUITests.xctest",
              "UITargetAppPath": "__TESTROOT__/Debug-iphonesimulator/Maktabah.app",
              "IsUITestBundle": True, "IsXCTRunnerHostedTestBundle": True,
              "TestTimeoutsEnabled": False, "EnvironmentVariables": {"fixture": "UNCHANGED"}}
    document = {"Maktabah-iOSUITests": target, "__xctestrun_metadata__": {"FormatVersion": 1}}
    test_run = write(base / "Maktabah-iOS_iphonesimulator27.2-arm64.xctestrun", plistlib.dumps(document))
    write(root / handoff.PRODUCT_ROOTS[1] / "SafariPrototypeReference", mode=0o755)
    return app, test_run


class ArchiveFixture(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.folder = Path(self.temporary.name)
        self.root = self.folder / "producer"
        self.root.mkdir()
        self.app, self.test_run = products(self.root)
        self.context = fixture_context()
        self.destination = self.folder / "handoff"

    def pack(self):
        self.receipt = handoff.pack(self.root, self.destination, "build",
            [self.root / name for name in handoff.PRODUCT_ROOTS], self.context,
            "RELEASE_BUILD_ONLY_PASS", products=handoff.product_inventory(self.root))
        self.archive = self.destination / "build.tar.gz"
        return self.receipt

    def extract(self, receipt=None, target=None):
        target = target or self.folder / "consumer"
        target.mkdir(exist_ok=True)
        value = receipt or self.receipt
        handoff.extract(target, self.archive, value, self.context, "build", value["archive"]["sha256"])
        return target

    def rewrite_archive(self, edit):
        # Test-only attacker envelope with a correspondingly changed outer hash:
        # inner inventory checks must independently reject the altered tar.
        temporary = self.folder / "changed.tar.gz"
        with tarfile.open(self.archive, "r:gz") as original, tarfile.open(temporary, "w:gz") as output:
            entries = [(member, original.extractfile(member).read() if member.isfile() else None)
                       for member in original.getmembers()]
            for member, data in edit(entries):
                output.addfile(member, io.BytesIO(data) if data is not None else None)
        temporary.replace(self.archive)
        self.receipt["archive"].update(sha256=handoff.digest(self.archive), bytes=self.archive.stat().st_size)


class ArchiveTests(ArchiveFixture):
    def test_roundtrip_retains_every_byte_mode_and_original_plist(self):
        before = self.test_run.read_bytes()
        self.pack()
        target = self.extract()
        self.assertEqual(handoff.product_inventory(target), self.receipt["products"])
        self.assertEqual(handoff.original_xctestrun(target, self.receipt).read_bytes(), before)
        self.assertEqual(stat.S_IMODE((target / self.app.relative_to(self.root)).stat().st_mode), 0o755)
        self.assertEqual(handoff.verify_products(target, self.receipt)["status"], "EXACT_ORIGINAL_PRODUCTS")

    def test_internal_versioned_framework_aliases_roundtrip(self):
        framework = self.app.parent / "Frameworks/Example.framework"
        write(framework / "Versions/A/Example", b"actual synthetic link target", 0o755)
        (framework / "Versions/Current").symlink_to("A", target_is_directory=True)
        (framework / "Example").symlink_to("Versions/Current/Example")
        self.pack()
        target = self.extract()
        alias = target / (framework / "Example").relative_to(self.root)
        self.assertEqual(alias.read_bytes(), b"actual synthetic link target")
        handoff.verify_products(target, self.receipt)

    def test_corrupt_archive_is_rejected_before_extraction(self):
        self.pack()
        self.archive.write_bytes(self.archive.read_bytes() + b"tamper")
        with self.assertRaisesRegex(ValueError, "archive bytes"):
            self.extract()
        self.assertFalse((self.folder / "consumer/build").exists())

    def test_different_needs_output_is_rejected(self):
        self.pack()
        with self.assertRaisesRegex(ValueError, "producer archive output"):
            handoff.validate_receipt(self.receipt, self.context, "build", "0" * 64)

    def test_changed_inner_file_cannot_use_self_consistent_archive_hash(self):
        self.pack()
        def edit(rows):
            for member, data in rows:
                if member.name.endswith("/Maktabah"):
                    data = b"x" * len(data)
                yield member, data
        self.rewrite_archive(edit)
        with self.assertRaisesRegex(ValueError, "member digest"):
            self.extract()
        self.assertFalse((self.folder / "consumer/build").exists())

    def test_missing_extra_duplicate_members_are_rejected(self):
        self.pack()
        pristine = self.archive.read_bytes()
        for operation in [lambda rows: rows[:-1], lambda rows: rows + [rows[-1]],
                          lambda rows: rows + [(tarfile.TarInfo("build/artifacts/unexpected"), b"")]]:
            with self.subTest(operation=operation):
                self.archive.write_bytes(pristine)
                self.rewrite_archive(operation)
                with self.assertRaisesRegex(ValueError, "missing/extra/duplicate"):
                    self.extract()

    def test_changed_member_permissions_are_rejected(self):
        self.pack()
        def edit(rows):
            rows[-1][0].mode = 0o777
            return rows
        self.rewrite_archive(edit)
        with self.assertRaisesRegex(ValueError, "permissions"):
            self.extract()

    def test_changed_member_type_is_rejected(self):
        self.pack()
        def edit(rows):
            for member, data in rows:
                if member.isfile():
                    member.type, member.size, member.linkname = tarfile.SYMTYPE, 0, "/tmp/outside"
                    data = None
                yield member, data
        self.rewrite_archive(edit)
        with self.assertRaisesRegex(ValueError, "type changed"):
            self.extract()

    def test_existing_different_product_is_never_overwritten(self):
        self.pack()
        target = self.folder / "consumer"
        occupied = write(target / self.app.relative_to(self.root), b"existing retained bytes", 0o755)
        with self.assertRaisesRegex(ValueError, "replace different"):
            self.extract(target=target)
        self.assertEqual(occupied.read_bytes(), b"existing retained bytes")

    def test_existing_identical_inventory_is_idempotent(self):
        self.pack()
        target = self.extract()
        self.extract(target=target)
        handoff.verify_products(target, self.receipt)

    def test_existing_external_parent_link_is_rejected(self):
        self.pack()
        target = self.folder / "consumer"
        target.mkdir()
        outside = self.folder / "outside"
        outside.mkdir()
        (target / "build").symlink_to(outside, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, "escaped checkout"):
            self.extract(target=target)
        self.assertFalse(list(outside.iterdir()))

    def test_changed_extra_or_permission_modified_products_are_rejected(self):
        self.pack()
        target = self.extract()
        app = target / self.app.relative_to(self.root)
        before = app.read_bytes()
        for mutation, undo in [(lambda: app.write_bytes(b"changed"), lambda: app.write_bytes(before)),
                               (lambda: app.chmod(0o644), lambda: app.chmod(0o755))]:
            with self.subTest(mutation=mutation):
                mutation()
                with self.assertRaisesRegex(ValueError, "products changed"):
                    handoff.verify_products(target, self.receipt)
                undo()
        extra = write(app.parent / "unreviewed")
        with self.assertRaisesRegex(ValueError, "products changed"):
            handoff.verify_products(target, self.receipt)
        extra.unlink()

    def test_xctestrun_is_never_rewritten_or_replaced(self):
        self.pack()
        target = self.extract()
        path = handoff.original_xctestrun(target, self.receipt)
        path.write_bytes(path.read_bytes() + b"\n")
        with self.assertRaisesRegex(ValueError, "bytes changed"):
            handoff.original_xctestrun(target, self.receipt)

    def test_unknown_or_filtered_xctestrun_is_rejected(self):
        for change in [lambda p: p["__xctestrun_metadata__"].update(FormatVersion=2),
                       lambda p: p["Maktabah-iOSUITests"].update(OnlyTestIdentifiers=["fixture/testOne"]),
                       lambda p: p["Maktabah-iOSUITests"].update(SkipTestIdentifiers=["fixture/testOne"]),
                       lambda p: p["Maktabah-iOSUITests"].update(TestHostPath="/producer/absolute/Runner.app")]:
            with self.subTest(change=change):
                document = plistlib.loads(self.test_run.read_bytes())
                original = self.test_run.read_bytes()
                change(document)
                self.test_run.write_bytes(plistlib.dumps(document))
                with self.assertRaises(ValueError):
                    handoff.original_xctestrun(self.root, {"products": handoff.product_inventory(self.root)})
                self.test_run.write_bytes(original)

    def test_ambiguous_original_test_run_is_rejected(self):
        self.pack()
        write(self.test_run.with_name("Maktabah-iOS_iphonesimulator27.1-arm64.xctestrun"), self.test_run.read_bytes())
        with self.assertRaisesRegex(ValueError, "ambiguous"):
            handoff.original_xctestrun(self.root, self.receipt)


class ReceiptTests(ArchiveFixture):
    def test_all_immutable_context_fields_are_required(self):
        self.pack()
        for key in self.context:
            with self.subTest(field=key):
                changed = copy.deepcopy(self.context)
                changed.pop(key)
                with self.assertRaisesRegex(ValueError, "drift"):
                    handoff.validate_receipt(self.receipt, changed, "build")

    def test_full_acceptance_and_wrong_partial_status_are_rejected(self):
        self.pack()
        for field, value in [("full_release_acceptance", True), ("stage_status", "EXECUTED_PASS"),
                             ("stage_status", "FAIL"), ("stage_status", "RELEASE_NATIVE_MATRIX_ONLY_PASS")]:
            changed = copy.deepcopy(self.receipt)
            changed[field] = value
            with self.subTest(field=field, value=value), self.assertRaisesRegex(ValueError, "Partial handoff"):
                handoff.validate_receipt(changed, self.context, "build")

    def test_bad_paths_are_rejected(self):
        for path in ["/build/artifacts/a", "build/artifacts/../a", "build/artifacts/./a", "build/artifacts//a",
                     "build/artifacts/a/", "C:/build/artifacts/a", "build\\artifacts\\a", "Source/a", "build/other/a"]:
            with self.subTest(path=path), self.assertRaises(ValueError):
                handoff.safe_relative(path)

    def test_archive_byte_counts_are_strict_and_bounded(self):
        self.pack()
        for count in [0, -1, True, "10", handoff.MAX_TRANSFER_BYTES + 1]:
            changed = copy.deepcopy(self.receipt)
            changed["archive"]["bytes"] = count
            with self.subTest(count=count), self.assertRaises(ValueError):
                handoff.validate_receipt(changed, self.context, "build")

    def test_missing_duplicate_privileged_special_inventory_is_rejected(self):
        self.pack()
        for change in [lambda r: r.update(members=[]), lambda r: r["members"].append(r["members"][0]),
                       lambda r: r["members"][0].update(mode=0o4755), lambda r: r["members"][0].update(kind="device"),
                       lambda r: r.update(products=[]), lambda r: r["products"].pop()]:
            changed = copy.deepcopy(self.receipt)
            change(changed)
            with self.subTest(change=change), self.assertRaises(ValueError):
                handoff.validate_receipt(changed, self.context, "build")

    def test_link_escape_cycle_missing_and_depth_are_rejected(self):
        for rows, path in [
            ({"build/artifacts/a": {"kind": "symlink", "target": "/tmp/outside"}}, "build/artifacts/a"),
            ({"build/artifacts/a": {"kind": "symlink", "target": "../../Source/private"}}, "build/artifacts/a"),
            ({"build/artifacts/a": {"kind": "symlink", "target": "missing"}}, "build/artifacts/a"),
            ({"build/artifacts/a": {"kind": "symlink", "target": "b"},
              "build/artifacts/b": {"kind": "symlink", "target": "a"}}, "build/artifacts/a"),
            ({"build/artifacts/a" + str(i): {"kind": "symlink", "target": "a" + str(i + 1)} for i in range(45)},
             "build/artifacts/a0")]:
            with self.subTest(rows=rows), self.assertRaises(ValueError):
                handoff.resolve_carried_link(path, rows)

    def test_product_link_cannot_borrow_mutable_evidence_outside_product_inventory(self):
        self.pack()
        target = {"path": "build/artifacts/borrowed", "kind": "file", "mode": 0o644,
                  "bytes": 0, "sha256": hashlib.sha256(b"").hexdigest()}
        link = {"path": handoff.PRODUCT_ROOTS[0] + "/borrowed", "kind": "symlink", "mode": 0o777,
                "target": "../../../artifacts/borrowed"}
        self.receipt["members"].extend([link, target])
        self.receipt["products"].append(link)
        with self.assertRaisesRegex(ValueError, "crosses its immutable product root"):
            handoff.validate_receipt(self.receipt, self.context, "build")


class ProvenanceTests(unittest.TestCase):
    def setUp(self):
        self.context = fixture_context()
        self.run = {"id": 101, "run_attempt": 2, "head_sha": "a" * 40, "event": "workflow_dispatch",
                    "path": handoff.WORKFLOW, "status": "in_progress", "conclusion": None}
        self.metadata = {"id": 301, "name": "runtime27-release-build-handoff", "expired": False,
            "size_in_bytes": 500, "digest": "sha256:" + "6" * 64, "created_at": "2026-11-20T07:01:00Z",
            "workflow_run": {"id": 101, "head_sha": "a" * 40,
                             "repository_id": handoff.REPOSITORY_ID, "head_repository_id": handoff.REPOSITORY_ID}}
        self.jobs = [{"name": "Release build and prototype", "run_id": 101, "run_attempt": 2,
                      "head_sha": "a" * 40, "status": "completed", "conclusion": "success",
                      "started_at": "2026-11-20T07:00:00Z", "completed_at": "2026-11-20T07:02:00Z"}]

    def check(self):
        return handoff.validate_artifact_metadata(self.metadata, self.run, self.jobs, self.context, "build", 301)

    def test_actual_successful_predecessor_allowed_while_workflow_remains_active(self):
        self.assertEqual(self.check(), self.jobs[0])
        self.assertEqual(self.run["status"], "in_progress")

    def test_foreign_source_attempt_run_or_trigger_is_rejected(self):
        for key, value in [("id", 102), ("run_attempt", 1), ("head_sha", "b" * 40),
                           ("event", "push"), ("path", "other.yml")]:
            with self.subTest(field=key):
                original = self.run[key]
                self.run[key] = value
                with self.assertRaisesRegex(ValueError, "source/attempt"):
                    self.check()
                self.run[key] = original

    def test_artifact_name_id_expiry_origin_and_digest_are_bound(self):
        for key, value in [("id", 302), ("name", "runtime27-evidence"), ("expired", True),
                           ("size_in_bytes", True), ("size_in_bytes", 0), ("digest", "unknown")]:
            with self.subTest(field=key):
                original = self.metadata[key]
                self.metadata[key] = value
                with self.assertRaises(ValueError):
                    self.check()
                self.metadata[key] = original
        for key, value in [("id", 102), ("head_sha", "b" * 40), ("repository_id", 1), ("head_repository_id", 2)]:
            with self.subTest(origin_field=key):
                original = self.metadata["workflow_run"][key]
                self.metadata["workflow_run"][key] = value
                with self.assertRaises(ValueError):
                    self.check()
                self.metadata["workflow_run"][key] = original

    def test_failed_incomplete_stale_or_duplicate_producer_is_rejected(self):
        for key, value in [("status", "in_progress"), ("conclusion", "failure"), ("conclusion", "cancelled"),
                           ("run_id", 102), ("run_attempt", 1), ("head_sha", "b" * 40), ("name", "other job")]:
            with self.subTest(field=key):
                original = self.jobs[0][key]
                self.jobs[0][key] = value
                with self.assertRaises(ValueError):
                    self.check()
                self.jobs[0][key] = original
        self.jobs.append(copy.deepcopy(self.jobs[0]))
        with self.assertRaises(ValueError):
            self.check()

    def test_upload_must_belong_to_successful_producer_time_interval(self):
        for timestamp in ["2026-11-20T06:59:59Z", "2026-11-20T07:02:01Z"]:
            with self.subTest(timestamp=timestamp):
                self.metadata["created_at"] = timestamp
                with self.assertRaisesRegex(ValueError, "outside"):
                    self.check()

    def test_actual_changed_driver_bytes_are_rejected_independently_of_head(self):
        records = b"100644 blob " + b"a" * 40 + b"\tScripts/CI/fixture.py\0"
        with patch.object(subprocess, "check_output", side_effect=[records, b"b" * 40 + b"\n"]):
            with self.assertRaisesRegex(ValueError, "Actual workflow/helper/test bytes"):
                handoff.reviewed_driver_inputs(Path("unused-synthetic-root"))

    def test_matching_actual_driver_bytes_have_a_stable_proof(self):
        records = b"100644 blob " + b"a" * 40 + b"\tScripts/CI/fixture.py\0"
        with patch.object(subprocess, "check_output", side_effect=[records, b"a" * 40 + b"\n"]):
            proof = handoff.reviewed_driver_inputs(Path("unused-synthetic-root"))
        self.assertEqual(proof["files"], 1)
        self.assertRegex(proof["sha256"], "^[a-f0-9]{64}$")


if __name__ == "__main__":
    unittest.main(verbosity=2)

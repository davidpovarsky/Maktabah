#!/usr/bin/env python3
"""Deterministic patch and signed legacy compatibility tests in disposable repos.

All Ed25519 keys are in-memory NON-PRODUCTION fixtures. Neither the source
checkout nor any real exception register, approval status, or owner key is used.
"""
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest
from unittest.mock import patch as patch_environment

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from generate_owner_patch_manifest import generate_manifest
import sign_owner_approvals as signer


ROOT = Path(__file__).resolve().parent.parent
GUARDS = []
for name, relative in (("tools", "tools/verify_upstream_boundary.py"),
                       ("ci", "Scripts/CI/verify-upstream-boundary.py")):
    spec = importlib.util.spec_from_file_location("fixture_guard_" + name, ROOT / relative)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    GUARDS.append((name, module))


class Fixture:
    path = "Source/Core/Fixture.swift"
    approval_id = "NON_PRODUCTION_FIXTURE_01"
    original = b"// synthetic upstream\n\nlet value = 1\n// keep this context\n"
    reviewed = b"// synthetic upstream\n\nlet value = 2\n// keep this context\n"

    def __init__(self):
        self.temp = tempfile.TemporaryDirectory(prefix="boundary-digest-fixture-")
        self.repo = Path(self.temp.name)
        self.key = Ed25519PrivateKey.generate()
        self.public = self.key.public_key().public_bytes_raw().hex()
        self.git("init", "-b", "main")
        self.git("config", "user.name", "Non-production fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        self.git("config", "core.autocrlf", "false")
        self.git("config", "core.filemode", "true")
        self.write(self.path, self.original)
        self.git("add", ".")
        self.git("commit", "-m", "Synthetic upstream")
        self.upstream = self.git("rev-parse", "HEAD")
        self.write(self.path, self.reviewed)
        self.git("add", ".")
        self.git("commit", "-m", "Synthetic reviewed hunk")
        self.head = self.git("rev-parse", "HEAD")
        self.base = self.upstream
        self.blob = self.git("rev-parse", self.head + ":" + self.path)

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.temp.cleanup()

    def git_bytes(self, *args, input=None):
        return subprocess.run(["git", *args], cwd=self.repo, input=input,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              check=True).stdout

    def git(self, *args, input=None):
        return self.git_bytes(*args, input=input).decode("utf-8").strip()

    def write(self, relative, data):
        path = self.repo / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)

    def legacy(self, width=7):
        return self.git_bytes("-c", "core.abbrev=" + str(width), "diff", self.upstream,
                              self.head, "--", self.path).replace(b"\r\n", b"\n")

    def record(self, guard, patch, archive=False):
        digest = hashlib.sha256(patch.replace(b"\r\n", b"\n")).hexdigest()
        attestation = {
            "repo": "davidpovarsky/Maktabah", "approval_id": self.approval_id,
            "base_sha": self.upstream, "expected_head_blob_sha": self.blob,
            "patch_digest_sha256": digest, "expires_at": "2099-01-01T00:00:00Z",
            "signer_public_key": self.public,
        }
        payload = guard.construct_canonical_attestation_payload(
            attestation["repo"], self.path, self.upstream, self.blob, digest,
            self.approval_id, attestation["expires_at"])
        attestation["signature"] = self.key.sign(payload).hex()
        record = {"path": self.path, "status": "APPROVED", "patch_id": self.approval_id,
                  "approval_ref": self.approval_id, "expected_head_blob_sha": self.blob,
                  "patch_digest_sha256": digest, "owner_attestation": attestation}
        if archive:
            record["expected_patch_file"] = "fixture.patch"
        return record

    def publish(self, record, archive=None):
        # The CI guard's existing admission path: signed register-only trusted
        # base, followed by the exact reviewed source. No unsafe-register flag.
        self.git("checkout", "--detach", self.upstream)
        register = {"baseline_commit": self.upstream, "exceptions": [record]}
        self.write("docs/architecture/UPSTREAM_EXCEPTION_REGISTER.json",
                   json.dumps(register).encode("utf-8"))
        if archive is not None:
            self.write("docs/architecture/build-8401-patches/fixture.patch", archive)
        self.git("add", ".")
        self.git("commit", "-m", "Synthetic owner record in trusted base")
        self.base = self.git("rev-parse", "HEAD")
        self.write(self.path, self.reviewed)
        self.git("add", ".")
        self.git("commit", "-m", "Synthetic reviewed source after admission")
        self.head = self.git("rev-parse", "HEAD")

    def verify(self, guard):
        return guard.verify_boundaries(self.base, self.head, self.upstream,
                                       str(self.repo), owner_public_key=self.public)


class PatchDigestTests(unittest.TestCase):
    def assert_rejected(self, result, code):
        status, report = result
        self.assertNotEqual(status, 0)
        self.assertIn(code, [v["type"] for v in report["violations"]], report)

    def assert_passed(self, result, patch_format):
        status, report = result
        self.assertEqual(status, 0, report)
        self.assertEqual([w["patch_format"] for w in report["warnings"]], [patch_format])

    def test_self_contained_helpers_are_identical(self):
        blocks = []
        for _, guard in GUARDS:
            source = Path(guard.__file__).read_text()
            blocks.append(source.split("# BEGIN SELF-CONTAINED PATCH VERIFICATION", 1)[1]
                          .split("# END SELF-CONTAINED PATCH VERIFICATION", 1)[0])
        self.assertEqual(blocks[0], blocks[1])

    def test_seven_field_payload_is_unchanged(self):
        expected = (b'{"approval_id":"ID","base_sha":"BASE","canonical_patch_sha256":"DIGEST",'
                    b'"expires_at":"EXPIRY","head_blob_sha":"BLOB","path":"a/b","repo":"REPO"}')
        for name, guard in GUARDS:
            with self.subTest(guard=name):
                self.assertEqual(guard.construct_canonical_attestation_payload(
                    "REPO", "a\\b", "BASE", "BLOB", "DIGEST", "ID", "EXPIRY"), expected)

    def test_full_index_is_stable_across_core_abbrev_and_legacy_widths(self):
        for name, guard in GUARDS:
            with self.subTest(guard=name), Fixture() as f:
                patches = []
                for width in (7, 8, 12, 40):
                    f.git("config", "core.abbrev", str(width))
                    patches.append(guard.canonical_patch_bytes(f.upstream, f.head, f.path, str(f.repo)))
                self.assertTrue(all(p == patches[0] for p in patches))
                self.assertNotEqual(f.legacy(7), f.legacy(8))
                f.publish(f.record(guard, patches[0]))
                self.assert_passed(f.verify(guard), "full-index-v1")

    def test_object_store_collision_does_not_invalidate_authentic_legacy_archive(self):
        for name, guard in GUARDS:
            with self.subTest(guard=name), Fixture() as f:
                archive = f.legacy(4)
                canonical = guard.canonical_patch_bytes(f.upstream, f.head, f.path, str(f.repo))
                # Find a four-digit object prefix collision in memory, then add
                # just that harmless blob to this disposable object database.
                for nonce in range(2_000_000):
                    candidate = ("NON_PRODUCTION_COLLISION_" + str(nonce)).encode()
                    oid = hashlib.sha1(b"blob " + str(len(candidate)).encode() + b"\0" + candidate).hexdigest()
                    if oid[:4] == f.blob[:4] and oid != f.blob:
                        break
                else:
                    self.fail("Could not construct bounded synthetic prefix collision")
                f.git("hash-object", "-w", "--stdin", input=candidate)
                self.assertNotEqual(f.legacy(4), archive)
                self.assertEqual(guard.canonical_patch_bytes(f.upstream, f.head, f.path, str(f.repo)), canonical)
                f.publish(f.record(guard, archive, archive=True), archive)
                self.assert_passed(f.verify(guard), "authenticated-legacy-index-width")

    def test_legacy_requires_exact_authenticated_archive(self):
        for name, guard in GUARDS:
            with self.subTest(guard=name), Fixture() as f:
                archive = f.legacy()
                f.publish(f.record(guard, archive))
                self.assert_rejected(f.verify(guard), "PATCH_DIGEST_MISMATCH")

    def test_local_blank_context_configuration_does_not_change_canonical_patch(self):
        for name, guard in GUARDS:
            with self.subTest(guard=name), Fixture() as f:
                canonical = guard.canonical_patch_bytes(f.upstream, f.head, f.path, str(f.repo))
                default_patch = f.legacy()
                f.git("config", "diff.suppressBlankEmpty", "true")
                self.assertNotEqual(f.legacy(), default_patch)
                self.assertEqual(guard.canonical_patch_bytes(f.upstream, f.head, f.path, str(f.repo)), canonical)
                f.publish(f.record(guard, canonical))
                self.assert_passed(f.verify(guard), "full-index-v1")

    def test_archive_root_cannot_escape_repository_through_symlink(self):
        for name, guard in GUARDS:
            with self.subTest(guard=name), Fixture() as f, tempfile.TemporaryDirectory(prefix="external-archive-fixture-") as outside:
                archive = f.legacy()
                f.publish(f.record(guard, archive, archive=True), archive)
                external = Path(outside)
                (external / "build-8401-patches").mkdir()
                (external / "build-8401-patches/fixture.patch").write_bytes(archive)
                root = f.repo / "docs/architecture"
                root.rename(f.repo / "docs/original-architecture")
                try:
                    root.symlink_to(external, target_is_directory=True)
                except OSError:
                    if os.name != "nt":
                        raise
                    # NTFS junctions provide the same realpath escape when the
                    # test account lacks Windows symbolic-link privileges.
                    subprocess.run(["cmd", "/c", "mklink", "/J", str(root), str(external)],
                                   check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                try:
                    self.assert_rejected(f.verify(guard), "PATCH_FILE_OUTSIDE_REPOSITORY")
                finally:
                    if os.name == "nt" and not root.is_symlink():
                        os.rmdir(root)
                    else:
                        root.unlink()

    def test_archive_tampering_is_rejected(self):
        for name, guard in GUARDS:
            with self.subTest(guard=name), Fixture() as f:
                archive = f.legacy()
                f.publish(f.record(guard, archive, archive=True), archive)
                f.write("docs/architecture/build-8401-patches/fixture.patch", archive + b"tampered\n")
                self.assert_rejected(f.verify(guard), "PATCH_FILE_DIGEST_MISMATCH")

    def test_signed_archive_cannot_substitute_hunk_path_mode_or_index(self):
        mutators = {
            "hunk": lambda p: p.replace(b"+let value = 2", b"+let value = 9"),
            "path": lambda p: p.replace(b"Source/Core/Fixture.swift", b"Source/Core/Other.swift"),
            "mode": lambda p: p.replace(b" 100644\n", b" 100755\n"),
            "object": lambda p: re.sub(rb"(?m)^index [0-9a-f]+", b"index deadbeef", p),
            "multiple_files": lambda p: p + p,
        }
        for name, guard in GUARDS:
            for variation, mutate in mutators.items():
                with self.subTest(guard=name, variation=variation), Fixture() as f:
                    archive = mutate(f.legacy())
                    # Authentic fixture signature alone cannot make an archive
                    # whose body differs from the actual source valid.
                    f.publish(f.record(guard, archive, archive=True), archive)
                    self.assert_rejected(f.verify(guard), "PATCH_DIGEST_MISMATCH")

    def test_actual_changed_hunk_is_rejected(self):
        for name, guard in GUARDS:
            with self.subTest(guard=name), Fixture() as f:
                archive = f.legacy()
                f.publish(f.record(guard, archive, archive=True), archive)
                f.write(f.path, f.reviewed + b"// unapproved hunk\n")
                f.git("add", f.path)
                f.git("commit", "-m", "Unapproved fixture mutation")
                f.head = f.git("rev-parse", "HEAD")
                self.assert_rejected(f.verify(guard), "UNAPPROVED_HUNK_DIFFERS_FROM_EXCEPTION")

    def test_actual_mode_change_is_rejected_with_identical_blob(self):
        for name, guard in GUARDS:
            with self.subTest(guard=name), Fixture() as f:
                archive = f.legacy()
                f.publish(f.record(guard, archive, archive=True), archive)
                f.git("update-index", "--chmod=+x", f.path)
                f.git("commit", "-m", "Unapproved fixture mode")
                f.head = f.git("rev-parse", "HEAD")
                self.assertEqual(f.git("rev-parse", f.head + ":" + f.path), f.blob)
                self.assert_rejected(f.verify(guard), "PATCH_DIGEST_MISMATCH")

    def test_invalid_signature_cannot_activate_archive_compatibility(self):
        for name, guard in GUARDS:
            with self.subTest(guard=name), Fixture() as f:
                archive = f.legacy()
                record = f.record(guard, archive, archive=True)
                signature = bytearray.fromhex(record["owner_attestation"]["signature"])
                signature[0] ^= 1
                record["owner_attestation"]["signature"] = signature.hex()
                f.publish(record, archive)
                self.assert_rejected(f.verify(guard), "INVALID_CRYPTOGRAPHIC_SIGNATURE")

    def test_conflicting_unsigned_identity_fields_are_rejected(self):
        for name, guard in GUARDS:
            for field in ("approval_ref", "patch_id"):
                with self.subTest(guard=name, field=field), Fixture() as f:
                    patch = guard.canonical_patch_bytes(f.upstream, f.head, f.path, str(f.repo))
                    record = f.record(guard, patch)
                    record[field] = "CONFLICTING_UNSIGNED_ID"
                    f.publish(record)
                    self.assert_rejected(f.verify(guard), "ATTESTATION_IDENTITY_CONFLICT")

    def test_legacy_approval_ref_is_verified_as_the_exact_signed_id(self):
        for name, guard in GUARDS:
            with self.subTest(guard=name), Fixture() as f:
                archive = f.legacy()
                record = f.record(guard, archive, archive=True)
                del record["owner_attestation"]["approval_id"]
                f.publish(record, archive)
                self.assert_passed(f.verify(guard), "authenticated-legacy-index-width")

    def test_conflicting_digest_and_blob_aliases_are_rejected(self):
        for name, guard in GUARDS:
            for field, code in (("canonical_patch_sha256", "ATTESTATION_DIGEST_CONFLICT"),
                                ("expected_head_blob_sha", "ATTESTATION_BLOB_CONFLICT")):
                with self.subTest(guard=name, field=field), Fixture() as f:
                    patch = guard.canonical_patch_bytes(f.upstream, f.head, f.path, str(f.repo))
                    record = f.record(guard, patch)
                    record["owner_attestation"][field] = "0" * (64 if "sha256" in field else 40)
                    f.publish(record)
                    self.assert_rejected(f.verify(guard), code)

    def test_worktree_renderer_includes_uncommitted_bytes(self):
        for name, guard in GUARDS:
            with self.subTest(guard=name), Fixture() as f:
                committed = guard.canonical_patch_bytes(f.upstream, f.head, f.path, str(f.repo))
                f.write(f.path, f.reviewed + b"// uncommitted fixture\n")
                working = guard.canonical_patch_bytes(f.upstream, "WORKTREE", f.path, str(f.repo))
                self.assertNotEqual(committed, working)
                self.assertIn(b"+// uncommitted fixture", working)

    def test_unsigned_generator_and_signer_preflight_share_exact_bytes(self):
        with Fixture() as f, tempfile.TemporaryDirectory(prefix="unsigned-patch-fixture-") as output:
            before = f.git("status", "--porcelain")
            manifest, patches = generate_manifest(f.repo, f.upstream, f.head, f.upstream)
            f.git("config", "core.abbrev", "8")
            second_manifest, second_patches = generate_manifest(f.repo, f.upstream, f.head, f.upstream)
            self.assertEqual(manifest, second_manifest)
            self.assertEqual(patches, second_patches)
            self.assertEqual(manifest["total_patches"], 1)
            self.assertNotIn("owner_attestation", json.dumps(manifest))
            for filename, content in patches.items():
                (Path(output) / filename).write_bytes(content)
            signer.validate_manifest_preconditions(manifest, output, str(f.repo))
            payloads = signer.get_canonical_payloads(manifest, f.upstream, "davidpovarsky/Maktabah", "2099-01-01T00:00:00Z")
            self.assertEqual(json.loads(payloads[0]["canonical_json"])["canonical_patch_sha256"],
                             manifest["patches"][0]["patch_digest_sha256"])
            self.assertEqual(f.git("status", "--porcelain"), before)
            tampered = copy.deepcopy(manifest)
            tampered["patches"][0]["head_blob_sha"] = "0" * 40
            with self.assertRaisesRegex(ValueError, "immutable source"):
                signer.validate_manifest_preconditions(tampered, output, str(f.repo))

    def test_global_autocrlf_worktree_matches_committed_patch_and_blob(self):
        for name, guard in GUARDS:
            with self.subTest(guard=name), Fixture() as f, tempfile.TemporaryDirectory(prefix="git-config-fixture-") as config_dir:
                config = Path(config_dir) / "global-config"
                config.write_text("[core]\n\tautocrlf = true\n", encoding="utf-8")
                with patch_environment.dict(os.environ, {"GIT_CONFIG_GLOBAL": str(config)}):
                    f.git("config", "--unset", "core.autocrlf")
                    f.git("checkout", "--detach", "--force", f.upstream)
                    f.git("checkout", "--detach", "--force", f.head)
                    self.assertIn(b"\r\n", (f.repo / f.path).read_bytes())
                    self.assertEqual(f.git("hash-object", f.path), f.blob)
                    committed = guard.canonical_patch_bytes(f.upstream, f.head, f.path, str(f.repo))
                    working = guard.canonical_patch_bytes(f.upstream, "WORKTREE", f.path, str(f.repo))
                    self.assertEqual(working, committed)

    def test_signer_rejects_identity_conflict_without_touching_proposals(self):
        with Fixture() as f:
            manifest, _ = generate_manifest(f.repo, f.upstream, f.head, f.upstream)
            payloads = signer.get_canonical_payloads(manifest, f.upstream, "davidpovarsky/Maktabah", "2099-01-01T00:00:00Z")
            proposal = {"exceptions": [{"patch_id": payloads[0]["patch_id"], "path": f.path,
                                         "status": "OWNER_APPROVAL_REQUIRED", "owner_attestation": None,
                                         "approval_ref": "UNSIGNED_CONFLICTING_ID"}]}
            original = copy.deepcopy(proposal)
            with self.assertRaisesRegex(ValueError, "conflicts"):
                signer.validate_register_identities(proposal, payloads)
            self.assertEqual(proposal, original)


if __name__ == "__main__":
    unittest.main(verbosity=2)

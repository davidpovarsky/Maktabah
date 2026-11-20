#!/usr/bin/env python3
"""Synthetic downloader/archive refusal controls; these are not Native tests."""
import copy
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import stat
import subprocess
import tempfile
import time
import unittest
from unittest import mock
import urllib.error
import zipfile

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("evidence", HERE / "native98-commentary-evidence.py")
M = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(M)
CONTRACT = json.loads((HERE / "native98-commentary-evidence.json").read_bytes())


def metadata():
    run = copy.deepcopy(CONTRACT["sourceRun"])
    run.update(repository={"id": 1280062128, "full_name": "davidpovarsky/Maktabah"},
               head_repository={"id": 1280062128, "full_name": "davidpovarsky/Maktabah"})
    artifact = copy.deepcopy(CONTRACT["sourceArtifact"])
    artifact["workflow_run"] = {"id": 44723902453, "repository_id": 1280062128,
        "head_repository_id": 1280062128, "head_sha": "60a57972acb28739ec738565083bf17fb7503028",
        "head_branch": "codex/otzaria-native98-signature-reviewed-20261120"}
    job = copy.deepcopy(CONTRACT["sourceJob"])
    job["steps"] = [copy.deepcopy(CONTRACT["uploadStep"])]
    return run, artifact, job


class MetadataControls(unittest.TestCase):
    def reject(self, position, key, value):
        values = list(metadata())
        values[position][key] = value
        with self.assertRaises(M.Refusal): M.validate_metadata(*values, CONTRACT)

    def test_original_cancelled_run_with_successful_upload_is_accepted_as_evidence_only(self):
        M.validate_metadata(*metadata(), CONTRACT)
        self.assertEqual(CONTRACT["sourceRun"]["conclusion"], "cancelled")
        self.assertEqual(CONTRACT["sourceArtifact"]["size_in_bytes"], 775094118)

    def test_wrong_run(self): self.reject(0, "id", 44723902454)
    def test_wrong_head(self): self.reject(0, "head_sha", "0" * 40)
    def test_wrong_attempt(self): self.reject(0, "run_attempt", 2)
    def test_boolean_attempt_is_not_integer(self): self.reject(0, "run_attempt", True)
    def test_success_is_not_substituted_for_cancelled(self): self.reject(0, "conclusion", "success")
    def test_wrong_repository(self): self.reject(0, "repository", {"id": 1, "full_name": M.REPOSITORY})
    def test_wrong_artifact(self): self.reject(1, "id", 14632383919)
    def test_wrong_artifact_size(self): self.reject(1, "size_in_bytes", 775094117)
    def test_wrong_artifact_digest(self): self.reject(1, "digest", "sha256:" + "0" * 64)
    def test_expired_artifact(self): self.reject(1, "expired", True)
    def test_wrong_artifact_run(self): self.reject(1, "workflow_run", {"id": 1})
    def test_wrong_job(self): self.reject(2, "id", 136246398293)
    def test_wrong_job_attempt(self): self.reject(2, "run_attempt", 2)
    def test_wrong_job_head(self): self.reject(2, "head_sha", "0" * 40)

    def test_failed_or_duplicate_upload(self):
        for mode in ("failure", "duplicate"):
            with self.subTest(mode=mode):
                values = list(metadata())
                if mode == "failure": values[2]["steps"][0]["conclusion"] = "failure"
                else: values[2]["steps"] *= 2
                with self.assertRaises(M.Refusal): M.validate_metadata(*values, CONTRACT)

    def test_upload_window_is_checked_independently(self):
        values = list(metadata()); contract = copy.deepcopy(CONTRACT)
        values[1]["created_at"] = contract["sourceArtifact"]["created_at"] = "2026-11-20T13:41:07Z"
        with self.assertRaisesRegex(M.Refusal, "artifact_upload_window"):
            M.validate_metadata(*values, contract)


class ArchiveControls(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.payloads = {s["path"]: (b"original\r\n\x00bytes-" + str(i).encode())
                         for i, s in enumerate(CONTRACT["selectedMembers"])}
        self.payloads["other-result/retained.bin"] = b"nonselected-content"

    def make(self, extras=(), omit=None, corrupt=None):
        path = self.root / "input.zip"
        with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_STORED) as archive:
            for name, data in self.payloads.items():
                if name != omit: archive.writestr(name, data)
            for name, data in extras: archive.writestr(name, data)
        if corrupt:
            raw = path.read_bytes(); needle = self.payloads[corrupt]
            self.assertEqual(raw.count(needle), 1)
            raw = raw.replace(needle, bytes([needle[0] ^ 1]) + needle[1:])
            path.write_bytes(raw)
        contract = copy.deepcopy(CONTRACT)
        contract["sourceArtifact"].update(size_in_bytes=path.stat().st_size,
                                         digest="sha256:" + M.sha256(path.read_bytes()))
        return path, contract

    def verify(self, path, contract):
        return M.verify_archive(path, contract, self.root / "result", time.monotonic() + 20)

    def test_all_crc_and_selected_original_bytes(self):
        path, contract = self.make()
        proof = self.verify(path, contract)
        self.assertEqual(proof["archiveMemberCount"], 4)
        self.assertTrue(proof["allMembersCRCVerified"])
        for spec in CONTRACT["selectedMembers"]:
            self.assertEqual((self.root / "result/entries" / spec["path"]).read_bytes(), self.payloads[spec["path"]])
        self.assertFalse((self.root / "result/entries/other-result").exists())

    def test_nonselected_crc_failure_blocks_all_selected_publication(self):
        path, contract = self.make(corrupt="other-result/retained.bin")
        with self.assertRaisesRegex(M.Refusal, "archive_crc_or_structure"): self.verify(path, contract)
        self.assertFalse((self.root / "result/entries").exists())

    def test_selected_crc_failure(self):
        path, contract = self.make(corrupt=CONTRACT["selectedMembers"][0]["path"])
        with self.assertRaisesRegex(M.Refusal, "archive_crc_or_structure"): self.verify(path, contract)

    def test_size_failure(self):
        path, contract = self.make(); contract["sourceArtifact"]["size_in_bytes"] += 1
        with self.assertRaisesRegex(M.Refusal, "archive_size"): self.verify(path, contract)

    def test_hash_failure(self):
        path, contract = self.make(); contract["sourceArtifact"]["digest"] = "sha256:" + "0" * 64
        with self.assertRaisesRegex(M.Refusal, "archive_sha256"): self.verify(path, contract)

    def test_no_basename_fallback(self):
        old = CONTRACT["selectedMembers"][0]["path"]
        path, contract = self.make(omit=old, extras=[("other/" + Path(old).name, b"wrong")])
        with self.assertRaisesRegex(M.Refusal, "selected_member_missing"): self.verify(path, contract)

    def test_duplicate_member(self):
        with self.assertWarns(UserWarning): path, contract = self.make(extras=[(next(iter(self.payloads)), b"duplicate")])
        with self.assertRaisesRegex(M.Refusal, "archive_duplicate_member"): self.verify(path, contract)

    def test_traversal_member(self):
        path, contract = self.make(extras=[("../escape", b"bad")])
        with self.assertRaisesRegex(M.Refusal, "archive_member_path"): self.verify(path, contract)

    def test_symlink_member(self):
        entry = zipfile.ZipInfo("link"); entry.create_system = 3
        entry.external_attr = (stat.S_IFLNK | 0o777) << 16
        path, contract = self.make(extras=[(entry, b"outside")])
        with self.assertRaisesRegex(M.Refusal, "archive_member_type"): self.verify(path, contract)

    def test_noncanonical_and_encrypted_members(self):
        for name in ("/absolute", "a//b", "a/./b", "a\\b", "C:/path"):
            with self.subTest(name=name), self.assertRaises(M.Refusal): M.canonical_entry(zipfile.ZipInfo(name))
        info = zipfile.ZipInfo("ok"); info.flag_bits = 1
        with self.assertRaises(M.Refusal): M.canonical_entry(info)

    def test_deadline_is_not_success(self):
        path, contract = self.make()
        with self.assertRaisesRegex(M.Refusal, "processing_deadline"):
            M.verify_archive(path, contract, self.root / "result", time.monotonic() - 1)


class Response(io.BytesIO):
    def __init__(self, data, status=200, headers=None):
        super().__init__(data); self.status = status; self.headers = headers or {}


class Opener:
    def __init__(self, value): self.value, self.requests = value, []
    def open(self, request, timeout):
        self.requests.append(request)
        if isinstance(self.value, Exception): raise self.value
        return self.value


class TransportControls(unittest.TestCase):
    def perform(self, data=b"exact zip", url="https://productionresultssa1.blob.core.windows.net/path?sig=secret",
                expected_size=None, expected_sha=None, storage_status=200):
        api = Opener(urllib.error.HTTPError("https://api.github.com/route", 302, "redirect", {"Location": url}, io.BytesIO()))
        storage = Opener(Response(data, storage_status))
        reader = M.GitHubReader("test-token-not-real", time.monotonic() + 20, api, storage)
        with tempfile.TemporaryDirectory() as tmp:
            value = reader.download(14632274701, Path(tmp) / "source.zip",
                                    len(data) if expected_size is None else expected_size,
                                    hashlib.sha256(data).hexdigest() if expected_sha is None else expected_sha)
        return value, api, storage

    def test_authenticated_github_then_anonymous_storage(self):
        receipt, api, storage = self.perform()
        self.assertEqual(api.requests[0].get_header("Authorization"), "Bearer test-token-not-real")
        self.assertIsNone(storage.requests[0].get_header("Authorization"))
        self.assertFalse(receipt["authorizationForwardedToStorage"])
        self.assertNotIn("sig=", json.dumps(receipt)); self.assertNotIn("test-token", json.dumps(receipt))

    def test_unsafe_redirects_are_refused(self):
        for url in ("http://productionresultssa1.blob.core.windows.net/p", "https://evil.example/p",
                    "https://u:p@a.blob.core.windows.net/p", "https://a.blob.core.windows.net:444/p",
                    "https://a.blob.core.windows.net/p#fragment"):
            with self.subTest(url=url), self.assertRaisesRegex(M.Refusal, "archive_redirect_host"): self.perform(url=url)

    def test_storage_redirect_not_followed(self):
        with self.assertRaisesRegex(M.Refusal, "archive_http_status"): self.perform(storage_status=302)

    def test_incomplete_download(self):
        with self.assertRaisesRegex(M.Refusal, "archive_incomplete"): self.perform(expected_size=50)

    def test_oversized_download(self):
        with self.assertRaisesRegex(M.Refusal, "archive_too_large"): self.perform(expected_size=2)

    def test_wrong_download_digest(self):
        with self.assertRaisesRegex(M.Refusal, "archive_sha256"): self.perform(expected_sha="0" * 64)

    def test_api_route_cannot_receive_a_foreign_host(self):
        reader = M.GitHubReader("not-real", time.monotonic() + 20)
        with self.assertRaisesRegex(M.Refusal, "api_route"): reader.api_request("https://evil.example")
        self.assertIsNone(M.NoRedirect().redirect_request(None, None, 302, None, None, "https://evil.example"))


class SourceControls(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.git("init", "-q"); self.git("config", "user.name", "Synthetic control")
        self.git("config", "user.email", "control@example.invalid")
        self.git("commit", "-q", "--allow-empty", "-m", "baseline")
        self.base = self.git("rev-parse", "HEAD").strip()
        for name in M.SOURCE_PATHS:
            p = self.root / name; p.parent.mkdir(parents=True, exist_ok=True); p.write_text("synthetic " + name)
        self.git("add", "."); self.git("commit", "-q", "-m", "candidate")
        self.env = {"GITHUB_REPOSITORY": M.REPOSITORY, "GITHUB_REPOSITORY_ID": str(M.REPOSITORY_ID),
                    "GITHUB_EVENT_NAME": "push", "GITHUB_REF": "refs/heads/" + M.BRANCH,
                    "GITHUB_RUN_ATTEMPT": "1", "GITHUB_SHA": self.git("rev-parse", "HEAD").strip(),
                    "GITHUB_RUN_ID": "1", "GITHUB_WORKFLOW_REF": f"{M.REPOSITORY}/{M.WORKFLOW}@refs/heads/{M.BRANCH}"}
        self.env["GITHUB_WORKFLOW_SHA"] = self.env["GITHUB_SHA"]

    def git(self, *args): return subprocess.check_output(["git", "-C", str(self.root), *args], text=True, stderr=subprocess.DEVNULL)

    def verify(self):
        with mock.patch.object(M, "BASE", self.base):
            return M.verify_source(self.root, self.env, M.sha256((self.root / M.MANIFEST).read_bytes()))

    def test_exact_git_bytes_and_parent(self): self.assertEqual(len(self.verify()["inputs"]), 4)
    def test_wrong_trigger_branch(self):
        self.env["GITHUB_REF"] += "-other"
        with self.assertRaisesRegex(M.Refusal, "processor_identity"): self.verify()
    def test_changed_driver_bytes(self):
        (self.root / M.DRIVER).write_text("changed")
        with self.assertRaisesRegex(M.Refusal, "processor_source_changed"): self.verify()
    def test_other_product_change_is_refused(self):
        p = self.root / "Source/Unexpected.swift"; p.parent.mkdir(); p.write_text("changed")
        self.git("add", "."); self.git("commit", "-q", "--amend", "--no-edit")
        self.env["GITHUB_SHA"] = self.env["GITHUB_WORKFLOW_SHA"] = self.git("rev-parse", "HEAD").strip()
        with self.assertRaisesRegex(M.Refusal, "unexpected_source_change"): self.verify()

    def test_existing_receipt_is_not_overwritten_on_reuse(self):
        output = self.root / "previous-output"; output.mkdir()
        prior = b'{"qualified":true,"retained":"previous original bytes"}\r\n'
        (output / "RESULT.json").write_bytes(prior)
        with mock.patch("sys.argv", ["processor", "--output", str(output), "--cache", str(self.root / "cache"),
                                     "--manifest-sha256", "0" * 64]), mock.patch("sys.stdout", new_callable=io.StringIO):
            self.assertEqual(M.main(), 1)
        self.assertEqual((output / "RESULT.json").read_bytes(), prior)


if __name__ == "__main__":
    unittest.main(verbosity=2)

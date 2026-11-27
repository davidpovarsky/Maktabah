"""Actual finite URL transport policy; subprocess/system delivery is a double."""
import json
import os
from pathlib import Path
import runpy
import subprocess
import tempfile
import time
import unittest
import uuid

dispatch = runpy.run_path(str(Path(__file__).with_name("runtime27-url-delivery.py")))["dispatch_request"]


class PublicSearchURLTransportTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.token = "explicit-test-owned-token"
        self.udid, self.nonce = str(uuid.uuid4()).upper(), str(uuid.uuid4()).upper()
        self.path = Path(self.directory.name) / f"r27-url-{self.token}-{self.nonce}.request.json"
        self.seen, self.calls = set(), []

    def url(self, kind="result", https=False):
        prefix = "https://davidpovarsky.github.io/chavrusatext/action" if https else "maktabah-debug://action"
        return prefix + "/v2/native.search." + kind + "?route=AbC123_-"

    def execute(self, url, changes=None, stale=False):
        value = dict(token=self.token, nonce=self.nonce, udid=self.udid, url=url)
        value.update(changes or {})
        self.path.write_text(json.dumps(value))
        if stale:
            os.utime(self.path, (time.time() - 31, time.time() - 31))
        def run(argv, **kwargs):
            self.calls.append((argv, kwargs))
            return subprocess.CompletedProcess(argv, 0)
        return dispatch(self.path, self.token, self.udid, self.seen, run=run)

    def fresh(self):
        self.calls.clear()
        self.seen.clear()

    def require_allowed(self, url):
        self.fresh()
        result = self.execute(url)
        self.assertTrue(result["delivered"])
        self.assertEqual(self.calls, [(["xcrun", "simctl", "openurl", self.udid, url],
                                      dict(capture_output=True, timeout=12, check=False))])
        self.assertEqual(set(result), {"udid", "transport", "delivered", "nonce", "time"})
        self.assertEqual(self.seen, {self.nonce})
        self.assertNotIn(self.token, json.dumps(result))
        self.assertNotIn(url, json.dumps(result))

    def require_rejected(self, url, changes=None, stale=False):
        self.fresh()
        result = self.execute(url, changes=changes, stale=stale)
        self.assertFalse(result["delivered"])
        self.assertEqual(self.calls, [])
        self.assertEqual(self.seen, set())
        self.assertEqual(result["error"], "System URL request rejected")
        self.assertNotIn(self.token, json.dumps(result))
        self.assertNotIn(url, json.dumps(result))

    def test_both_exact_custom_v2_search_paths_use_same_owned_argv(self):
        for kind in ["result", "nextPage"]:
            with self.subTest(kind=kind):
                self.require_allowed(self.url(kind))

    def test_both_exact_verified_https_paths_use_same_owned_argv(self):
        for kind in ["result", "nextPage"]:
            with self.subTest(kind=kind):
                self.require_allowed(self.url(kind, https=True))

    def test_versions_case_children_suffixes_and_other_search_actions_refuse(self):
        for https in [False, True]:
            for kind in ["result", "nextPage"]:
                original = self.url(kind, https)
                values = [original.replace("/v2/", "/v1/"), original.replace("/v2/", "/v3/"),
                    original.replace("native.search.", "native.Search."), original.replace(kind, kind.lower() if kind != kind.lower() else kind.upper()),
                    original.replace(kind + "?", kind + ".delete?"), original.replace(kind + "?", kind + "/extra?"),
                    original.replace("native.search." + kind, "native.search.selectedHit"),
                    original.replace("native.search." + kind, "native.search.execute"),
                    original.replace("native.search." + kind, "native.search.nextPageAll")]
                for url in values:
                    with self.subTest(url=url):
                        self.require_rejected(url)

    def test_foreign_origins_credentials_encoded_paths_and_extra_payload_refuse(self):
        for kind in ["result", "nextPage"]:
            original = self.url(kind, https=True)
            values = [original.replace("https://", "http://"), original.replace("davidpovarsky.github.io", "example.com"),
                original.replace("davidpovarsky.github.io", "davidpovarsky.github.io.example.com"),
                original.replace("https://", "https://user@"), original.replace(".io/", ".io:443/"),
                original.replace("/chavrusatext/", "/other-app/"), original.replace("/action/", "/%61ction/"),
                original.replace("native.search", "native%2esearch"), original + "&route=Other", original + "&save=true",
                original + "#fragment", original + ";echo unsafe", original.replace("AbC123_-", "%41bC123_-"),
                original.replace("?route=", "?query=private&route=")]
            for url in values:
                with self.subTest(url=url):
                    self.require_rejected(url)
            self.require_rejected(self.url(kind).replace("maktabah-debug://", "maktabah://"))
            self.require_rejected(self.url(kind).replace("://action/", "://foreign/"))

    def test_same_transport_nonce_never_delivers_again(self):
        url = self.url()
        self.require_allowed(url)
        self.calls.clear()
        result = self.execute(url)
        self.assertFalse(result["delivered"])
        self.assertEqual(self.calls, [])
        self.assertEqual(self.seen, {self.nonce})

    def test_same_original_job_target_filename_and_age_guards_remain_required(self):
        for https in [False, True]:
            url = self.url(https=https)
            for changes in [dict(token="foreign"), dict(udid=str(uuid.uuid4()).upper()),
                            dict(nonce=str(uuid.uuid4()).upper()), dict(command="launch")]:
                with self.subTest(changes=changes):
                    self.require_rejected(url, changes=changes)
            self.require_rejected(url, stale=True)

    def test_original_request_and_url_budgets_remain_enforced(self):
        self.require_rejected(self.url() + "A" * 6144)
        self.require_rejected(self.url(), changes={"extra": "X" * 8192})
        self.seen.update(str(uuid.uuid4()).upper() for _ in range(256))
        result = self.execute(self.url())
        self.assertFalse(result["delivered"])
        self.assertEqual(self.calls, [])

    def test_payload_is_not_decoded_or_promoted_to_authority_by_transport(self):
        # Deliberately not valid app JSON. The original app parser and source
        # binding must still decide; transport must only deliver exact bytes.
        self.require_allowed(self.url("nextPage", https=True).replace("AbC123_-", "NotApplicationJSON"))


if __name__ == "__main__":
    unittest.main()

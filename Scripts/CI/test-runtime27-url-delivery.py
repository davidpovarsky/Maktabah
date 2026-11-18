"""Portable security/transport contract checks; no Native acceptance claim."""
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


class OwnedURLTransportTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.token, self.udid, self.nonce = "private-job-token", str(uuid.uuid4()).upper(), str(uuid.uuid4()).upper()
        self.url = "maktabah-debug://action/v1/native.history?route=AbC123_-"
        self.request = Path(self.directory.name) / f"r27-url-{self.token}-{self.nonce}.request.json"
        self.payload = dict(token=self.token, nonce=self.nonce, udid=self.udid, url=self.url)
        self.calls, self.seen = [], set()

    def execute(self, code=0, error=None):
        self.request.write_text(json.dumps(self.payload))
        def run(argv, **kwargs):
            self.calls.append((argv, kwargs))
            if error:
                raise error
            return subprocess.CompletedProcess(argv, code)
        return dispatch(self.request, self.token, self.udid, self.seen, run=run)

    def assert_rejected(self):
        result = self.execute()
        self.assertFalse(result["delivered"])
        self.assertEqual(self.calls, [])
        self.assertNotIn(self.token, json.dumps(result))
        self.assertNotIn(self.url, json.dumps(result))

    def test_exact_owned_argv_and_public_transport_only_ack(self):
        result = self.execute()
        self.assertTrue(result["delivered"])
        self.assertEqual(set(result), {"udid", "transport", "delivered", "nonce", "time"})
        self.assertEqual(self.calls, [(["xcrun", "simctl", "openurl", self.udid, self.url],
                                      dict(capture_output=True, timeout=12, check=False))])

    def test_wrong_target_rejected(self):
        self.payload["udid"] = str(uuid.uuid4()).upper()
        self.assert_rejected()

    def test_wrong_credential_rejected(self):
        self.payload["token"] = "another-job"
        self.assert_rejected()

    def test_nonce_filename_mismatch_rejected(self):
        self.payload["nonce"] = str(uuid.uuid4()).upper()
        self.assert_rejected()

    def test_arbitrary_urls_shell_text_extra_query_and_paths_rejected(self):
        for value in ["https://example.com", self.url + "&cmd=delete", self.url + ";echo unsafe",
                      self.url.replace("v1", "v3"), self.url.replace("native.history", "native.settings")]:
            with self.subTest(url=value):
                self.payload["url"] = value
                self.assert_rejected()

    def test_intentional_v2_refusal_reaches_actual_app_parser(self):
        self.payload["url"] = self.url.replace("/v1/", "/v2/")
        self.assertTrue(self.execute()["delivered"])

    def test_only_explicit_reader_v2_envelope_is_delivered(self):
        self.payload["url"] = self.url.replace("/v1/native.history", "/v2/native.reader")
        self.assertTrue(self.execute()["delivered"])
        self.assertEqual(self.calls[0][0], ["xcrun", "simctl", "openurl", self.udid, self.payload["url"]])

    def test_uninstalled_reader_envelopes_are_rejected(self):
        for version in ["v1", "v3"]:
            with self.subTest(version=version):
                self.payload["url"] = self.url.replace("/v1/native.history", "/" + version + "/native.reader")
                self.assert_rejected()

    def test_explicit_search_and_annotations_envelopes_only(self):
        for root in ["native.search", "native.annotations", "native.library", "native.reader.toc"]:
            for version in ["v1", "v2"]:
                with self.subTest(root=root, version=version):
                    self.seen.clear(); self.calls.clear()
                    self.payload["url"] = self.url.replace("/v1/native.history", "/" + version + "/" + root)
                    self.assertTrue(self.execute()["delivered"])
                    self.assertEqual(self.calls[0][0], ["xcrun", "simctl", "openurl", self.udid, self.payload["url"]])

    def test_uninstalled_root_versions_components_and_mutations_rejected(self):
        for path in ["v3/native.search", "v1/native.search.execute", "v2/native.annotations.delete",
                     "v1/native.annotations-export", "v1/native.search/extra", "v2/native.reader.toc.select",
                     "v2/native.library.delete", "v2/native.reader.toc/extra"]:
            with self.subTest(path=path):
                self.payload["url"] = self.url.replace("/v1/native.history", "/" + path)
                self.assert_rejected()

    def test_stale_file_rejected(self):
        self.request.write_text(json.dumps(self.payload))
        os.utime(self.request, (time.time() - 31, time.time() - 31))
        result = dispatch(self.request, self.token, self.udid, self.seen, run=lambda *a, **k: self.fail())
        self.assertFalse(result["delivered"])

    def test_repeated_transport_nonce_is_not_reexecuted(self):
        self.assertTrue(self.execute()["delivered"])
        self.calls.clear()
        self.assert_rejected()

    def test_subprocess_failure_does_not_export_sensitive_stderr(self):
        for error in [None, subprocess.TimeoutExpired([self.token, self.url], 12), RuntimeError(self.token)]:
            self.seen.clear()
            result = self.execute(code=1, error=error)
            self.assertFalse(result["delivered"])
            self.assertNotIn(self.token, json.dumps(result))
            self.assertNotIn(self.url, json.dumps(result))

    def test_unknown_fields_and_bounded_request_count(self):
        self.payload["command"] = "launch"
        self.assert_rejected()
        del self.payload["command"]
        self.seen.update(str(uuid.uuid4()).upper() for _ in range(256))
        self.assert_rejected()


if __name__ == "__main__":
    unittest.main()

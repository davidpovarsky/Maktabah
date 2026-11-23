"""Offline boundary controls; no provider or GitHub calls."""
import importlib.util
import pathlib
import tempfile
import unittest

path = pathlib.Path(__file__).with_name("live11-controller.py")
spec = importlib.util.spec_from_file_location("live11_controller", path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class Boundaries(unittest.TestCase):
    def test_exact_owner_metadata(self):
        prior = {"name": module.SECRET, "created_at": "a", "updated_at": "a"}
        self.assertTrue(module.owned_metadata(dict(prior), prior))
        self.assertFalse(module.owned_metadata(dict(prior, updated_at="b"), prior))
        self.assertFalse(module.owned_metadata({"name": "different"}, prior))
        self.assertFalse(module.owned_metadata(None, prior))

    def test_original_run_identity(self):
        b = {"checkout_sha": "a" * 40, "branch": "owned"}
        r = {"head_sha": b["checkout_sha"], "head_branch": b["branch"],
             "run_attempt": 1, "event": "workflow_dispatch"}
        self.assertTrue(module.exact_run(r, b))
        for key, value in (("head_sha", "b" * 40), ("head_branch", "other"),
                           ("run_attempt", 2), ("event", "push")):
            self.assertFalse(module.exact_run(dict(r, **{key: value}), b))

    def test_metadata_http_status_is_explicit(self):
        self.assertEqual(module.http_response(b'HTTP/2.0 404 Not Found\n\n{}'), (404, None))
        self.assertEqual(module.http_response(b'HTTP/2.0 204 No Content\n'), (204, None))
        self.assertEqual(module.http_response(b'HTTP/2.0 200 OK\n\n{"name":"x"}'),
                         (200, {"name": "x"}))
        with self.assertRaises(AssertionError):
            module.http_response(b'{"message":"not an HTTP receipt"}')

    def test_cleanup_never_deletes_changed_secret(self):
        with tempfile.TemporaryDirectory() as temporary:
            life = module.Lifecycle({"checkout_sha": "a" * 40}, pathlib.Path(temporary))
            prior = {"name": module.SECRET, "created_at": "a", "updated_at": "a"}
            life.record = {"metadata": prior, "secret_cleanup_required": True}
            calls = []
            def metadata(method="GET"):
                calls.append(method)
                return 200, dict(prior, updated_at="b")
            life.secret_http = metadata
            with self.assertRaises(AssertionError):
                life.cleanup()
            self.assertEqual(calls, ["GET"])
            self.assertTrue(life.record["secret_cleanup_required"])

    def test_cleanup_requires_delete_and_absence_receipts(self):
        with tempfile.TemporaryDirectory() as temporary:
            life = module.Lifecycle({"checkout_sha": "a" * 40}, pathlib.Path(temporary))
            prior = {"name": module.SECRET, "created_at": "a", "updated_at": "a"}
            life.record = {"metadata": prior, "secret_cleanup_required": True, "run_id": 12}
            calls = []
            replies = iter([(200, prior), (204, None), (404, None)])
            def metadata(method="GET"):
                calls.append(method)
                return next(replies)
            life.secret_http = metadata
            life.cleanup()
            self.assertEqual(calls, ["GET", "DELETE", "GET"])
            self.assertFalse(life.record["secret_cleanup_required"])
            self.assertEqual(life.record["state"], "DELETED_AND_ABSENCE_VERIFIED")

    def test_exclusive_observer_lock(self):
        with tempfile.TemporaryDirectory() as temporary:
            first = module.Lifecycle({}, pathlib.Path(temporary))
            second = module.Lifecycle({}, pathlib.Path(temporary))
            first.acquire()
            try:
                with self.assertRaises(OSError):
                    second.acquire()
            finally:
                first.lock.close()
                if second.lock:
                    second.lock.close()

if __name__ == "__main__":
    unittest.main(verbosity=2)

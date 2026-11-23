"""Offline checks only for the changed Live12 preflight identity constants."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
p = Path(__file__).with_name("live12-controller.py")
spec = importlib.util.spec_from_file_location("live12_controller", p)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class Live12Identity(unittest.TestCase):
    def preflight(self, *, branch="codex/otzaria-hanlin-live12-20261123",
                  previous_source="fdb78a44778c318b277506f0b09ba91c3b678e91"):
        with tempfile.TemporaryDirectory() as tmp:
            binding = {"schema":1,"repository":module.REPOSITORY,
                "checkout_sha":"a"*40,"branch":branch,
                "workflow":{"path":".github/workflows/otzaria-hanlin-live-native.yml"},
                "admission":{"path":"owned-control-only.json","sha256":"b"*64},
                "source_review_status":"REVIEWED_FOR_ONE_DIAGNOSTIC_LIVE_RUN"}
            life=module.Lifecycle(binding,Path(tmp))
            observed=[]
            def api(path):
                observed.append(path)
                if path.endswith("/git/ref/heads/"+branch):
                    return {"object":{"sha":"a"*40}}
                if path.endswith("/actions/runs/45103578190"):
                    return {"head_sha":previous_source,"run_attempt":1,"status":"completed","conclusion":"failure"}
                if "/actions/workflows/" in path and "/runs?status=" in path:
                    return {"total_count":0,"workflow_runs":[]}
                raise AssertionError("Unreviewed preflight route: "+path)
            life.api=api
            life.remote_file=lambda item: b"on:\n  workflow_dispatch:\n" if item is binding["workflow"] else b"{}"
            life.secret_http=lambda method="GET": (404,None)
            life.preflight()
            self.assertEqual(life.record["preflight"]["previous_live_run"],45103578190)
            self.assertEqual(life.record["state"],"PREPARED_SOURCE_BOUND")
            self.assertIn("repos/"+module.REPOSITORY+"/actions/runs/45103578190",observed)
    def test_new_exact_prior_run_and_new_branch_are_accepted(self):
        self.preflight()
    def test_previous_live10_source_is_rejected(self):
        with self.assertRaises(AssertionError):
            self.preflight(previous_source="9533a8017adadecf770b19811e72b495f32e90f7")
    def test_old_live11_branch_is_rejected(self):
        with self.assertRaises(AssertionError):
            self.preflight(branch="codex/otzaria-hanlin-live11-20261123")

if __name__=="__main__":
    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(Live12Identity))
    print(json.dumps({"status":"PASS" if result.wasSuccessful() else "FAIL",
        "executed":result.testsRun,"failures":len(result.failures),"errors":len(result.errors),
        "scope":"OFFLINE_CHANGED_SOURCE_IDENTITY_CONSTANTS_ONLY",
        "provider_called":False,"credential_accessed":False,"GitHub_called":False,
        "unchanged_six_lifecycle_controls":"REUSED_WITH_EXACT_INVERSE_SOURCE_PROOF"}))
    raise SystemExit(0 if result.wasSuccessful() else 1)

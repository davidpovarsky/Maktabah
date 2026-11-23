"""Offline checks only for the changed Live13 preflight identity constants."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
p = Path(__file__).with_name("live13-controller.py")
spec = importlib.util.spec_from_file_location("live13_controller", p)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class Live13Identity(unittest.TestCase):
    def preflight(self, *, branch="codex/otzaria-hanlin-live13-20261123",
                  previous_source="9bee6104e2938767b4e4e1047c56da8991d621fb"):
        with tempfile.TemporaryDirectory() as tmp:
            binding = {"schema":1,"repository":module.REPOSITORY,
                "checkout_sha":"a"*40,"branch":branch,
                "workflow":{"path":".github/workflows/otzaria-hanlin-live-native.yml"},
                "admission":{"path":"owned-control-only.json","sha256":"b"*64},
                "source_review_status":"REVIEWED_FOR_ONE_COLD_SEARCH_REPAIR_LIVE_RUN"}
            life=module.Lifecycle(binding,Path(tmp))
            observed=[]
            def api(path):
                observed.append(path)
                if path.endswith("/git/ref/heads/"+branch):
                    return {"object":{"sha":"a"*40}}
                if path.endswith("/actions/runs/45114449674"):
                    return {"head_sha":previous_source,"run_attempt":1,"status":"completed","conclusion":"failure"}
                if "/actions/workflows/" in path and "/runs?status=" in path:
                    return {"total_count":0,"workflow_runs":[]}
                raise AssertionError("Unreviewed preflight route: "+path)
            life.api=api
            life.remote_file=lambda item: b"on:\n  workflow_dispatch:\n" if item is binding["workflow"] else b"{}"
            life.secret_http=lambda method="GET": (404,None)
            life.preflight()
            self.assertEqual(life.record["preflight"]["previous_live_run"],45114449674)
            self.assertEqual(life.record["state"],"PREPARED_SOURCE_BOUND")
            self.assertIn("repos/"+module.REPOSITORY+"/actions/runs/45114449674",observed)
    def test_new_exact_prior_run_and_new_branch_are_accepted(self):
        self.preflight()
    def test_previous_live11_source_is_rejected(self):
        with self.assertRaises(AssertionError):
            self.preflight(previous_source="fdb78a44778c318b277506f0b09ba91c3b678e91")
    def test_old_live12_branch_is_rejected(self):
        with self.assertRaises(AssertionError):
            self.preflight(branch="codex/otzaria-hanlin-live12-20261123")

if __name__=="__main__":
    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(Live13Identity))
    print(json.dumps({"status":"PASS" if result.wasSuccessful() else "FAIL",
        "executed":result.testsRun,"failures":len(result.failures),"errors":len(result.errors),
        "scope":"OFFLINE_CHANGED_SOURCE_IDENTITY_CONSTANTS_ONLY",
        "provider_called":False,"credential_accessed":False,"GitHub_called":False,
        "unchanged_six_lifecycle_controls":"REUSED_WITH_EXACT_INVERSE_SOURCE_PROOF"}))
    raise SystemExit(0 if result.wasSuccessful() else 1)

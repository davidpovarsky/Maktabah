#!/usr/bin/env python3
"""Focused candidate preflight controls; explicit metadata/file/secret-HTTP doubles only."""
import copy
import hashlib
import json
from pathlib import Path
import runpy
import subprocess
import time

ROOT = Path("/mnt/development/projects/diagnostics/otzaria-hanlin-live-consent-20261123/controller-review")
SOURCE = ROOT / "controller120.py"
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == "0b377e7f03c94d41fefc252b8a0b405d4dd192cbcc7c0817d50f4d3c93643733"
module = runpy.run_path(str(SOURCE), run_name="controlled_source_load")
binding = json.loads((ROOT / "binding.json").read_bytes())
worktree = "/mnt/development/projects/worktrees/Maktabah-hanlin-live-consent-20261123"
revision = "39b021a944245b2ab6b235dd5ef4bc6982db93ea"
files = {}
for key in ("workflow", "admission", "source_guard", "previous_intake", "previous_cleanup"):
    item = binding[key]
    raw = subprocess.check_output(["runuser", "-u", "ubuntu", "--", "git", "-C", worktree,
                                   "show", revision + ":" + item["path"]], timeout=30)
    assert hashlib.sha256(raw).hexdigest() == item["sha256"]
    files[item["path"]] = raw
prior_run = json.loads(Path("/mnt/development/projects/diagnostics/otzaria-hanlin-live13-infrastructure-retry1-20261123/45145388957/run.json").read_bytes())

class MetadataDouble:
    def __init__(self):
        self.binding = copy.deepcopy(binding)
        self.record = {}
        self.remote = dict(files)
        self.prior_run = copy.deepcopy(prior_run)
        self.existing = []
        self.api_calls = []
        self.secret_metadata_reads = 0
        self.saves = 0

    def api(self, path):
        self.api_calls.append(path)
        if "/git/ref/heads/" in path:
            return {"object": {"sha": binding["checkout_sha"]}}
        if path.endswith("/actions/runs/45145388957"):
            return self.prior_run
        if "/runs?head_sha=" in path:
            return {"total_count": len(self.existing), "workflow_runs": self.existing}
        if "/runs?status=" in path:
            return {"total_count": 0, "workflow_runs": []}
        raise AssertionError("Unexpected metadata route: " + path)

    def remote_file(self, item):
        return self.remote[item["path"]]

    def secret_http(self):
        self.secret_metadata_reads += 1
        return 404, None

    def save(self):
        self.saves += 1

def alter_json(fake, key, mutate):
    path = fake.binding[key]["path"]
    value = json.loads(fake.remote[path])
    mutate(value)
    fake.remote[path] = json.dumps(value).encode()

cases = [
    ("actual_prior_executed_consent_failure_admits_new_source", None, True),
    ("prior_install_not_run_does_not_qualify_new_followup",
     lambda f: alter_json(f, "previous_intake", lambda v: v["outcome"].update(executed=0, failed=0, not_run=1)), False),
    ("prior_pass_cannot_be_relabelled_consent_failure",
     lambda f: alter_json(f, "previous_intake", lambda v: v["outcome"].update(passed=1, failed=0)), False),
    ("prior_provider_completed_claim_refused",
     lambda f: alter_json(f, "previous_intake", lambda v: v["outcome"].update(provider_completed_conversations_verified=1)), False),
    ("prior_cleanup_absence_must_be_confirmed",
     lambda f: alter_json(f, "previous_cleanup", lambda v: v["receipts"][0]["receipt"].update(after_http_status=200)), False),
    ("prior_runtime_source_identity_mismatch_refused",
     lambda f: f.prior_run.update(head_sha="0" * 40), False),
    ("an_existing_new_source_run_prevents_second_dispatch",
     lambda f: f.existing.append({"id": 99001, "head_sha": binding["checkout_sha"],
         "head_branch": binding["branch"], "run_attempt": 1, "event": "workflow_dispatch"}), False),
    ("source_guard_binding_disagreement_refused",
     lambda f: alter_json(f, "admission", lambda v: v.update(source_guard_sha256="0" * 64)), False),
]
results = []
for name, mutate, should_admit in cases:
    fake = MetadataDouble()
    if mutate:
        mutate(fake)
    started = time.monotonic()
    admitted = False
    caught = None
    try:
        module["Lifecycle"].preflight(fake)
        admitted = True
    except AssertionError as error:
        caught = type(error).__name__
    assert admitted == should_admit, name
    if should_admit:
        assert fake.record["state"] == "PREPARED_SOURCE_BOUND"
        assert fake.record["preexisting_exact_run_ids"] == []
        assert fake.record["preflight"]["previous_counts"] == {"PASS": 0, "FAIL": 1, "SKIP": 0, "NOT_RUN": 0}
        assert fake.secret_metadata_reads == 1 and fake.saves == 1
    else:
        assert fake.secret_metadata_reads == 0 and fake.saves == 0
    results.append({"case": name, "status": "PASS", "admitted": admitted,
        "expected_admission": should_admit, "caught": caught,
        "secret_metadata_double_reads": fake.secret_metadata_reads,
        "elapsed_seconds": time.monotonic() - started})
result = {"scope": "EIGHT_NEW_PREFLIGHT_DECISIONS_ON_ACTUAL_CANDIDATE_SOURCE_WITH_EXPLICIT_METADATA_DOUBLES",
    "controller_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
    "binding_sha256": hashlib.sha256((ROOT / "binding.json").read_bytes()).hexdigest(),
    "cases": results, "PASS": len(results), "FAIL": 0,
    "old_nine_controls_replayed": False, "live_network_or_secret_access": False,
    "dispatches": 0, "provider_calls": 0, "credential_reads_or_values_or_hashes": False,
    "actual_genuine_prior_run_used": 45145388957,
    "file_contents_from_exact_reviewed_ci_tree": revision,
    "original_configure_watch_cleanup_not_invoked": True}
(ROOT / "CONTROL_RESULT.json").write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps(result))

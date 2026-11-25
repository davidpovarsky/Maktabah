import ast, copy, hashlib, json, runpy, subprocess, time
from pathlib import Path
root = Path("/mnt/development/projects/diagnostics/otzaria-hanlin-live-consent-20261123/controller-review")
control = root / "check_preflight_followup.py"
assert hashlib.sha256(control.read_bytes()).hexdigest() == "6da674468020bc453a1a0570de85c961ebd4222cd257a5daf9327670bcd6c657"
binding = json.loads((root / "binding.json").read_bytes())
files = {}
for key in ("workflow", "admission", "source_guard", "previous_intake", "previous_cleanup"):
    item = binding[key]
    raw = subprocess.check_output(["runuser", "-u", "ubuntu", "--", "git", "-C",
        "/mnt/development/projects/worktrees/Maktabah-hanlin-live-consent-20261123", "show",
        "39b021a944245b2ab6b235dd5ef4bc6982db93ea:" + item["path"]], timeout=30)
    assert hashlib.sha256(raw).hexdigest() == item["sha256"]
    files[item["path"]] = raw
prior_run = json.loads(Path("/mnt/development/projects/diagnostics/otzaria-hanlin-live13-infrastructure-retry1-20261123/45145388957/run.json").read_bytes())
parsed = ast.parse(control.read_bytes())
classes = [node for node in parsed.body if isinstance(node, ast.ClassDef) and node.name == "MetadataDouble"]
assert len(classes) == 1
exec(compile(ast.Module(body=classes, type_ignores=[]), str(control), "exec"), globals())
observations = []
for label, relative, sha, should_admit in [
    ("retained_buggy_source", "superseded-0b377e7f/controller120.py", "0b377e7f03c94d41fefc252b8a0b405d4dd192cbcc7c0817d50f4d3c93643733", True),
    ("corrected_source", "controller120.py", "ef6f1c42598f719c256e8cd45138fb6ee89aea44fab45f666f51c57a815e5c74", False)]:
    path = root / relative
    assert hashlib.sha256(path.read_bytes()).hexdigest() == sha
    module = runpy.run_path(str(path), run_name="controlled_source_load")
    fake = MetadataDouble()
    fake.existing = [{"id": 99002, "head_sha": binding["checkout_sha"],
        "head_branch": binding["branch"], "run_attempt": 2, "event": "workflow_dispatch"}]
    admitted = False
    message = None
    try:
        module["Lifecycle"].preflight(fake)
        admitted = True
    except AssertionError as error:
        message = str(error)
    assert admitted == should_admit
    if should_admit:
        assert fake.saves == 1 and fake.secret_metadata_reads == 1
    else:
        assert fake.saves == 0 and fake.secret_metadata_reads == 0
        assert message == "This new reviewed source already has an exact manual run; do not redispatch"
    observations.append({"source": label, "sha256": sha, "admitted": admitted,
        "secret_metadata_double_reads": fake.secret_metadata_reads, "save_double_calls": fake.saves,
        "failure": message})
result = {"scope": "ONE_NEW_ATTEMPT2_HISTORY_CONTROL_WITH_EXPLICIT_METADATA_DOUBLES",
    "case": "Existing rerun attempt 2 on same source/branch/manual event refuses new dispatch",
    "status": "PASS", "observations": observations,
    "earlier_eight_controls_replayed": False, "old_nine_controls_replayed": False,
    "actual_network_or_credentials_or_dispatch": False,
    "full_actual_candidate_preflight_executed": True,
    "original_credential_watch_cleanup_not_invoked": True}
(root / "ATTEMPT2_CONTROL_RESULT.json").write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps(result))

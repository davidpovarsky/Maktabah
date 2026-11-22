import datetime, json, subprocess, time
from pathlib import Path
RUN = 45041601629
HEAD = "6591bba49d2b5a28d02b763c4360406843fce4cf"
ROOT = Path(r"C:\Users\DAVID\AppData\Local\Temp\otzaria-continuation-root-20261122\native450416-watch")
ROOT.mkdir(exist_ok=False)
(ROOT / "OWNED_OBSERVER.lock").write_text("root sole finite observer; immutable head; no dispatch\n", encoding="utf-8")
def now(): return datetime.datetime.now(datetime.timezone.utc).isoformat()
receipt = {"run_id": RUN, "expected_head": HEAD, "run_attempt": 1, "owner": "/root", "started_at": now(), "observer_invocations": 1, "status_polls": 0, "transport_errors": 0, "max_seconds": 2700, "status": "OBSERVING_EXISTING_RUN", "new_dispatches": 0, "artifact_downloads": 0}
def save(): (ROOT / "WATCH.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
save()
deadline = time.monotonic() + 2700
try:
    while time.monotonic() < deadline:
        receipt["status_polls"] += 1
        try:
            r = subprocess.run(["gh", "api", f"repos/davidpovarsky/Maktabah/actions/runs/{RUN}"], capture_output=True, timeout=45)
            if r.returncode: raise RuntimeError(r.stderr.decode("utf-8", errors="replace")[:1500])
            run = json.loads(r.stdout)
            assert run["id"] == RUN and run["head_sha"] == HEAD and run["run_attempt"] == 1
            assert run["head_branch"] == "codex/otzaria-native-package-cache-20261122"
            (ROOT / "RUN_LAST.json").write_bytes(r.stdout)
            receipt["last"] = {k: run.get(k) for k in ["id", "head_sha", "head_branch", "run_attempt", "status", "conclusion", "updated_at", "html_url"]}
            receipt["last_observed_at"] = now()
            save()
            if run["status"] == "completed":
                receipt["status"] = "TERMINAL"
                receipt["conclusion"] = run["conclusion"]
                break
        except (subprocess.SubprocessError, OSError, RuntimeError, json.JSONDecodeError) as e:
            receipt["transport_errors"] += 1
            receipt.setdefault("transport_error_details", []).append({"at": now(), "error": str(e)})
            save()
            if receipt["transport_errors"] >= 3:
                receipt["status"] = "TRANSPORT_BUDGET_ENDED_CI_UNCHANGED"
                break
        remaining = deadline - time.monotonic()
        if remaining > 0: time.sleep(min(45, remaining))
    else:
        receipt["status"] = "FINITE_WINDOW_ENDED_CI_UNCHANGED"
finally:
    receipt["finished_at"] = now()
    save()
    print(json.dumps(receipt))

"""Owned temporary-credential lifecycle for one reviewed Hanlin Live12 dispatch.
This is orchestration only; the original source-bound Apple runner owns acceptance.
No provider request is made here and no credential value/hash is retained.
"""
import argparse
import base64
import hashlib
import json
import os
import re
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import quote

REPOSITORY = "davidpovarsky/Maktabah"
SECRET = "OTZARIA_LIVE_GEMINI_API_KEY"
KEY_NAMES = {"GEMINI_API_KEY", SECRET, "OTZARIA_HANLIN_LIVE_API_KEY"}
ENDPOINT = "repos/" + REPOSITORY + "/actions/secrets/" + SECRET

def utc():
    return datetime.now(timezone.utc).isoformat()

def digest(raw):
    return hashlib.sha256(raw).hexdigest()

def owned_metadata(current, recorded):
    return isinstance(current, dict) and current == recorded and current.get("name") == SECRET

def exact_run(run, binding):
    return (run.get("head_sha") == binding["checkout_sha"]
            and run.get("head_branch") == binding["branch"]
            and run.get("run_attempt") == 1
            and run.get("event") == "workflow_dispatch")

def http_response(raw):
    text = raw.decode("utf-8", errors="strict")
    codes = re.findall(r"^HTTP/\S+\s+(\d+)", text, re.M)
    assert codes, "Missing explicit metadata HTTP status"
    code = int(codes[-1])
    body = json.loads(text[text.index("{"):]) if code == 200 else None
    return code, body

class Lifecycle:
    def __init__(self, binding, out):
        self.binding = binding
        self.out = out
        self.env = {k: v for k, v in os.environ.items() if k not in KEY_NAMES}
        self.record = {}
        self.lock = None

    def acquire(self):
        self.out.mkdir(parents=True, exist_ok=True)
        self.lock = (self.out / "observer.lock").open("a+b")
        if self.lock.tell() == 0:
            self.lock.write(b"0")
            self.lock.flush()
        self.lock.seek(0)
        if os.name == "nt":
            import msvcrt
            msvcrt.locking(self.lock.fileno(), msvcrt.LK_NBLCK, 1)
        else:
            import fcntl
            fcntl.flock(self.lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)

    def save(self):
        target = self.out / "lifecycle.json"
        temporary = self.out / "lifecycle.next.json"
        temporary.write_bytes((json.dumps(self.record, indent=2) + "\n").encode())
        temporary.replace(target)

    def command(self, args, *, timeout=60, input_bytes=None):
        return subprocess.run(args, cwd=self.out, env=self.env, input=input_bytes,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout)

    def api(self, path):
        result = self.command(["gh", "api", path])
        assert result.returncode == 0, "GitHub metadata read failed"
        return json.loads(result.stdout)

    def secret_http(self, method="GET"):
        result = self.command(["gh", "api", "--include", "--method", method, ENDPOINT])
        return http_response(result.stdout)

    def remote_file(self, item):
        path = quote(item["path"], safe="/")
        result = self.api("repos/" + REPOSITORY + "/contents/" + path +
                          "?ref=" + self.binding["checkout_sha"])
        assert result["encoding"] == "base64" and result["size"] <= 1024 * 1024
        assert result["sha"] == item["git_blob"]
        raw = base64.b64decode(result["content"])
        assert len(raw) == result["size"] and digest(raw) == item["sha256"]
        return raw

    def preflight(self):
        b = self.binding
        assert b["schema"] == 1 and b["repository"] == REPOSITORY
        assert re.fullmatch(r"[0-9a-f]{40}", b["checkout_sha"])
        assert b["branch"] == "codex/otzaria-hanlin-live12-20261123"
        assert b["workflow"]["path"] == ".github/workflows/otzaria-hanlin-live-native.yml"
        assert b["source_review_status"] == "REVIEWED_FOR_ONE_DIAGNOSTIC_LIVE_RUN"
        ref = self.api("repos/" + REPOSITORY + "/git/ref/heads/" + b["branch"])
        assert ref["object"]["sha"] == b["checkout_sha"], "Reviewed branch changed"
        workflow = self.remote_file(b["workflow"]).decode()
        assert re.search(r"(?m)^  workflow_dispatch:", workflow)
        assert not re.search(r"(?m)^  (push|pull_request|schedule):", workflow)
        self.remote_file(b["admission"])
        previous = self.api("repos/" + REPOSITORY + "/actions/runs/45103578190")
        assert previous["head_sha"] == "fdb78a44778c318b277506f0b09ba91c3b678e91"
        assert previous["run_attempt"] == 1 and previous["status"] == "completed"
        assert previous["conclusion"] == "failure"
        workflow_name = Path(b["workflow"]["path"]).name
        for status in ("queued", "in_progress", "waiting", "pending", "requested"):
            runs = self.api("repos/" + REPOSITORY + "/actions/workflows/" +
                            workflow_name + "/runs?status=" + status + "&per_page=100")
            assert runs["total_count"] == 0, "Another live workflow owns execution"
        status, _ = self.secret_http()
        assert status == 404, "Preserve a pre-existing live secret"
        self.record["preflight"] = {
            "remote_exact_source": True, "manual_only_workflow": True,
            "admission_sha256": b["admission"]["sha256"],
            "previous_live_run": 45103578190, "previous_conclusion": "failure",
            "active_live_runs": 0, "secret_prior_http": status,
            "new_provider_requests": 0}
        self.record["state"] = "PREPARED_SOURCE_BOUND"
        self.save()

    def configure_and_dispatch(self):
        b = self.binding
        key = os.environ.get("GEMINI_API_KEY")
        assert isinstance(key, str) and 20 <= len(key) <= 4096
        assert all(32 < ord(c) < 127 for c in key), "Configured key unavailable"
        self.record.update(state="SECRET_SET_REQUESTED", secret_cleanup_required=True,
                           secret_set_started_utc=utc())
        self.save()
        try:
            result = self.command(["gh", "secret", "set", SECRET, "--repo", REPOSITORY],
                                  input_bytes=key.encode())
        finally:
            key = None
        assert result.returncode == 0, "Temporary secret configuration failed"
        status, metadata = self.secret_http()
        assert status == 200 and metadata["name"] == SECRET
        self.record.update(metadata=metadata, state="SECRET_OWNED")
        self.save()
        # A second branch check closes the gap between source review and dispatch.
        ref = self.api("repos/" + REPOSITORY + "/git/ref/heads/" + b["branch"])
        assert ref["object"]["sha"] == b["checkout_sha"], "Reviewed branch changed"
        self.record.update(state="DISPATCH_REQUESTED", dispatch_started_utc=utc())
        self.save()
        result = self.command(["gh", "workflow", "run", Path(b["workflow"]["path"]).name,
                               "--repo", REPOSITORY, "--ref", b["branch"]])
        self.record["dispatch_exit_code"] = result.returncode
        self.save()
        assert result.returncode == 0, "Single dispatch requires review; do not retry"
        found = []
        for attempt in range(12):
            rows = self.api("repos/" + REPOSITORY + "/actions/workflows/" +
                            Path(b["workflow"]["path"]).name +
                            "/runs?head_sha=" + b["checkout_sha"] + "&per_page=20")["workflow_runs"]
            found = [row for row in rows if exact_run(row, b)]
            if found:
                break
            time.sleep(3)
        assert len(found) == 1, "Exact single live run not identified; do not redispatch"
        run = found[0]
        self.record.update(state="RUNNING", run_id=run["id"], run_attempt=1,
                           run_url=run["html_url"])
        self.save()
        print(json.dumps({"state": "RUNNING", "run_id": run["id"],
                          "run_url": run["html_url"], "checkout_sha": b["checkout_sha"],
                          "sole_observer": True}), flush=True)

    def cleanup(self):
        status, metadata = self.secret_http()
        assert status == 200 and owned_metadata(metadata, self.record.get("metadata")), (
            "Secret metadata changed; preserve another owner's value")
        deleted, _ = self.secret_http("DELETE")
        assert deleted == 204, "Secret deletion not acknowledged"
        absent, _ = self.secret_http()
        assert absent == 404, "Secret absence not verified"
        receipt = {"state": "DELETED_AND_ABSENCE_VERIFIED",
                   "before_metadata": metadata, "delete_http_status": deleted,
                   "after_http_status": absent, "checkout_sha": self.binding["checkout_sha"],
                   "run_id": self.record.get("run_id"), "finished_at": utc()}
        (self.out / "cleanup.json").write_bytes((json.dumps(receipt, indent=2) + "\n").encode())
        self.record.update(state=receipt["state"], secret_cleanup_required=False,
                           cleanup_receipt=str(self.out / "cleanup.json"))
        self.save()

    def watch(self, seconds):
        window = self.record.get("observer_windows", 0) + 1
        self.record.update(observer_windows=window, observer_started_utc=utc(),
                           watch_timed_out=False)
        self.save()
        run_id = self.record["run_id"]
        with (self.out / ("watch-" + str(window) + ".log")).open("xb") as log:
            try:
                result = subprocess.run(["gh", "run", "watch", str(run_id), "--repo",
                                         REPOSITORY, "--interval", "30", "--exit-status",
                                         "--compact"], cwd=self.out, env=self.env,
                                        stdout=log, stderr=subprocess.STDOUT, timeout=seconds)
                self.record["watch_exit_code"] = result.returncode
            except subprocess.TimeoutExpired:
                self.record["watch_timed_out"] = True
        run = self.api("repos/" + REPOSITORY + "/actions/runs/" + str(run_id))
        assert exact_run(run, self.binding), "Run source or attempt changed"
        self.record["observed_run"] = {k: run[k] for k in (
            "id", "head_sha", "run_attempt", "status", "conclusion", "updated_at", "html_url")}
        if run["status"] == "completed":
            self.cleanup()
        else:
            self.record["state"] = "OBSERVER_WINDOW_ENDED_CI_STILL_ACTIVE"
            self.save()

    def execute(self, mode, seconds, binding_sha256):
        self.acquire()
        controller_sha256 = digest(Path(__file__).read_bytes())
        if mode == "start":
            assert not (self.out / "lifecycle.json").exists(), "Preserve existing lifecycle"
            self.record = {"repository": REPOSITORY, "secret_name": SECRET,
                           "source_environment_name": "GEMINI_API_KEY",
                           "checkout_sha": self.binding["checkout_sha"],
                           "branch": self.binding["branch"], "started_utc": utc(),
                           "controller_sha256": controller_sha256,
                           "binding_sha256": binding_sha256,
                           "credential_in_argv": False,
                           "credential_value_or_hash_recorded": False,
                           "secret_cleanup_required": False,
                           "new_provider_probe_requests": 0}
            self.save()
        else:
            self.record = json.loads((self.out / "lifecycle.json").read_bytes())
            assert self.record["controller_sha256"] == controller_sha256
            assert self.record["binding_sha256"] == binding_sha256
            assert self.record["checkout_sha"] == self.binding["checkout_sha"]
            assert self.record.get("secret_cleanup_required") and self.record.get("run_id")
        try:
            if mode == "start":
                self.preflight()
                self.configure_and_dispatch()
            self.watch(seconds)
        except BaseException as error:
            self.record.update(state="LIFECYCLE_REQUIRES_REVIEW",
                               error_kind=type(error).__name__)
            # A possible dispatch may already own the secret. Never infer absence.
            if (self.record.get("secret_cleanup_required") and self.record.get("metadata")
                    and "dispatch_started_utc" not in self.record):
                try:
                    self.cleanup()
                except Exception as cleanup_error:
                    self.record["cleanup_error_kind"] = type(cleanup_error).__name__
            self.save()
            print(json.dumps(self.record), flush=True)
            raise SystemExit(1)
        print(json.dumps(self.record), flush=True)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--binding", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--mode", choices=("start", "continue"), default="start")
    parser.add_argument("--watch-seconds", type=int, default=3300)
    args = parser.parse_args()
    assert 1 <= args.watch_seconds <= 3300
    raw = args.binding.read_bytes()
    assert len(raw) <= 65536
    Lifecycle(json.loads(raw), args.output).execute(args.mode, args.watch_seconds, digest(raw))

if __name__ == "__main__":
    main()

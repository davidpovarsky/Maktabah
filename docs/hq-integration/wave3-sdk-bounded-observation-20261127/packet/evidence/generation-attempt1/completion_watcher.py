"""Durable parent for exactly one reviewed SDK supervisor. No process signaling."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time
from sdk_process_observation import identity, free_bytes, require_launch_capacity

SUPERVISOR_SHA = "a4b4e94edd9ce1b5fb566960d6ecf0d9b950955468ba945eda1e27666f862f3f"
PYTHON = "/opt/homebrew/opt/python@3.12/libexec/bin/python3"
BASE = Path("/Users/m1/builds/otzaria-root-actions-acceptance-20261126.wjQnLNJl")
PREFIX = "wave3-sdk-pasteboard-options-20261127."


def utc():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        while chunk := f.read(1024 * 1024):
            h.update(chunk)
    return {"path": str(path), "bytes": path.stat().st_size, "sha256": h.hexdigest()}


def free():
    return free_bytes()


def write(path, value, *, exclusive=True):
    data = (json.dumps(value, indent=2) + "\n").encode()
    target = path if exclusive else path.with_name(path.name + ".next")
    with target.open("xb" if exclusive else "wb") as f:
        f.write(data)
        f.flush()
        os.fsync(f.fileno())
    if not exclusive:
        os.replace(target, path)
    fd = os.open(path.parent, os.O_RDONLY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--execute-owned-supervisor", action="store_true", required=True)
    ap.add_argument("--manifest-sha256", required=True)
    args = ap.parse_args()
    require_launch_capacity()
    control = Path(__file__).resolve().parent
    manifest_path = control / "LAUNCH_INPUTS.json"
    assert digest(manifest_path)["sha256"] == args.manifest_sha256
    manifest = json.loads(manifest_path.read_bytes())
    for row in manifest["files"]:
        path = control / row["path"]
        assert path.parent == control and not path.is_symlink()
        got = digest(path)
        assert got["bytes"] == row["bytes"] and got["sha256"] == row["sha256"]
    supervisor = control / "supervisor.py"
    assert digest(supervisor)["sha256"] == SUPERVISOR_SHA
    claim = json.loads((control / "LAUNCH_CLAIM.json").read_bytes())
    assert claim["manifestSHA256"] == args.manifest_sha256
    assert claim["approvedSupervisorSHA256"] == SUPERVISOR_SHA
    me = identity(os.getpid())
    assert me["available"] and me["pgid"] == os.getpid()
    started = {"schema": 1, "status": "OWNED_WATCHER_STARTED", "started_at": utc(),
               "identity": me, "manifestSHA256": args.manifest_sha256,
               "supervisorSHA256": SUPERVISOR_SHA, "freeBefore": free(),
               "sdkSupervisorSignalsIssuedByWatcher": 0,
               "observerScope": "Pinned BSD reader may clean up only its own bounded helper; watcher never signals SDK supervisor"}
    write(control / "WATCHER_STARTED.json", started)
    assert started["freeBefore"] >= 15032385536, "Root fourteen-GiB launch admission unavailable before supervisor"
    child = None
    child_identity = None
    actual_out = None
    monitor_error = None
    stdout_path = control / "supervisor.stdout.log"
    stderr_path = control / "supervisor.stderr.log"

    def observe():
        nonlocal actual_out
        if actual_out is None and stdout_path.exists():
            with stdout_path.open("rb") as f:
                line = f.readline(65536)
            if line.endswith(b"\n"):
                value = json.loads(line)
                candidate = Path(value["started"])
                assert candidate.parent == BASE and candidate.name.startswith(PREFIX)
                assert candidate.is_dir() and not candidate.is_symlink()
                actual_out = candidate
        current = {"schema": 1, "status": "SUPERVISOR_RUNNING", "observed_at": utc(),
                   "watcherIdentity": me, "supervisorIdentity": child_identity,
                   "freeNow": free(), "originalSupervisorOut": str(actual_out) if actual_out else None,
                   "sdkSupervisorSignalsIssuedByWatcher": 0}
        if actual_out and (actual_out / "STATUS.json").is_file():
            # The original supervisor owns this mutable status; tolerate its short write interval.
            try:
                value = json.loads((actual_out / "STATUS.json").read_bytes())
                current.update(originalPhase=value.get("phase"), originalStatus=value.get("status"),
                               actualExecutionID=value.get("actualExecutionID"))
            except json.JSONDecodeError:
                current["originalStatusBeingWritten"] = True
        write(control / "WATCH_STATUS.json", current, exclusive=False)

    try:
        with stdout_path.open("xb") as so, stderr_path.open("xb") as se:
            child = subprocess.Popen([PYTHON, "-B", str(supervisor), "--execute-reviewed-proposal"],
                                     stdin=subprocess.DEVNULL, stdout=so, stderr=se,
                                     cwd=control, start_new_session=True, close_fds=True)
            child_identity = identity(child.pid)
            # A very early failure may exit before ps observes it; retain the real Popen wait result.
            if child_identity["available"]:
                assert child_identity["pid"] == child.pid and child_identity["pgid"] == child.pid
            write(control / "SUPERVISOR_PROCESS.json", {
                "schema": 1, "started_at": utc(), "identity": child_identity,
                "popenPID": child.pid, "directChildOfWatcher": os.getpid(),
                "command": [PYTHON, "-B", str(supervisor), "--execute-reviewed-proposal"],
                "supervisorSHA256": SUPERVISOR_SHA,
            })
            while child.poll() is None:
                observe()
                time.sleep(10)
            rc = child.wait()
            observe()
    except BaseException as error:
        monitor_error = type(error).__name__ + ": " + str(error)
        # Keep the direct parent alive until the original supervisor completes its own finally.
        # Never infer a process group or send a signal from this monitoring layer.
        rc = child.wait() if child is not None else None
    result = {"schema": 1, "status": "SUPERVISOR_EXITED_RECEIPT_REVIEW_REQUIRED" if rc == 0 and monitor_error is None else "SUPERVISOR_NOT_ACCEPTED",
              "finished_at": utc(), "watcherIdentity": me, "supervisorIdentity": child_identity,
              "actualSupervisorExit": rc, "monitorError": monitor_error,
              "originalSupervisorOut": str(actual_out) if actual_out else None,
              "freeAfter": free(), "supervisorSourceAfter": digest(supervisor),
              "logs": [digest(p) for p in [stdout_path, stderr_path] if p.is_file()],
              "sdkSupervisorSignalsIssuedByWatcher": 0, "newMaktabahAppBuilds": 0,
              "newMaktabahNativeAcceptanceRuns": 0}
    if actual_out and (actual_out / "RESULT.json").is_file():
        p = actual_out / "RESULT.json"
        result["originalResult"] = digest(p)
        value = json.loads(p.read_bytes())
        result["actualExecutionID"] = value.get("actualExecutionID")
        result["originalStatus"] = value.get("status")
        result["primaryError"] = value.get("primaryError")
        result["restoreError"] = value.get("restoreError")
    write(control / "WATCHER_RESULT.json", result)
    write(control / "WATCH_STATUS.json", result, exclusive=False)
    print(json.dumps(result), flush=True)
    return 0 if result["status"] == "SUPERVISOR_EXITED_RECEIPT_REVIEW_REQUIRED" else 1


if __name__ == "__main__":
    raise SystemExit(main())

"""Launch one reviewed, durable SDK watcher; a repeated invocation cannot relaunch."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
from sdk_process_observation import identity, require_launch_capacity, require_original_sdk_slot, require_compiler_slot

EXPECTED_MANIFEST = "5419732b5b6d3cceec15cfea43a81418b59b337e98cdf6bbe4af2a0bba9f45b2"
PYTHON = "/opt/homebrew/opt/python@3.12/libexec/bin/python3"
SDK = Path("/Users/m1/builds/otzaria-wave1-sdk-20261127/source")
SOURCE = "d6090c03b9ac4e5760941e34f4c04478db4ae59f"


def utc():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def save(path, data):
    with path.open("xb") as f:
        f.write((json.dumps(data, indent=2) + "\n").encode())
        f.flush()
        os.fsync(f.fileno())
    fd = os.open(path.parent, os.O_RDONLY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def git(*args):
    return subprocess.run(["/usr/bin/git", "-c", "gc.auto=0", "-c", "maintenance.auto=false", "-C", str(SDK), *args],
                          capture_output=True, check=True, timeout=30).stdout


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--execute-root-authorized-attempt", action="store_true", required=True)
    ap.parse_args()
    require_launch_capacity()
    control = Path(__file__).resolve().parent
    manifest_bytes = (control / "LAUNCH_INPUTS.json").read_bytes()
    assert hashlib.sha256(manifest_bytes).hexdigest() == EXPECTED_MANIFEST
    manifest = json.loads(manifest_bytes)
    for row in manifest["files"]:
        path = control / row["path"]
        assert path.parent == control and not path.is_symlink()
        b = path.read_bytes()
        assert len(b) == row["bytes"] and hashlib.sha256(b).hexdigest() == row["sha256"]
    assert git("rev-parse", "HEAD").decode().strip() == SOURCE
    assert not git("status", "--porcelain", "--untracked-files=no").strip()
    original = json.loads((control / "HISTORICAL_OBSERVED_CONTRACT.json").read_bytes())
    for row in original["original_files"] + [manifest["preflightGuard"]]:
        b = (SDK / row["path"]).read_bytes()
        assert len(b) == row["bytes"] and hashlib.sha256(b).hexdigest() == row["sha256"]
        assert git("show", "HEAD:" + row["path"]) == b
    recipe = json.loads((control / "FRESH_RUN_COMMANDS.json").read_bytes())
    for value in recipe["fresh_paths"].values():
        p = Path(value)
        assert p.is_relative_to(SDK / "build") and not p.exists() and not p.is_symlink()
    sdk_slot_observation = require_original_sdk_slot(SDK)
    active_compilers = require_compiler_slot()
    available = require_launch_capacity()
    claim = {"schema": 1, "status": "ROOT_AUTHORIZED_SINGLE_ATTEMPT_CLAIMED", "created_at": utc(),
             "manifestSHA256": EXPECTED_MANIFEST, "approvedSupervisorSHA256": manifest["approvedSupervisorSHA256"],
             "launcherIdentity": identity(os.getpid()), "sourceSHA": SOURCE,
             "originalGuardFilesVerified": 17, "freshPathsAbsent": recipe["fresh_paths"],
             "minimumLaunchFreeBytes": 15032385536, "activeCompilers": active_compilers,
             "freeBefore": available, "capacityObservation": "os.statvfs f_bavail times f_frsize",
             "sdkSlotObservation": sdk_slot_observation, "retryAuthorized": False}
    save(control / "LAUNCH_CLAIM.json", claim)
    command = [PYTHON, "-B", str(control / "completion_watcher.py"),
               "--execute-owned-supervisor", "--manifest-sha256", EXPECTED_MANIFEST]
    with (control / "watcher.stdout.log").open("xb") as so, (control / "watcher.stderr.log").open("xb") as se:
        child = subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=so, stderr=se,
                                 cwd=control, start_new_session=True, close_fds=True)
        observed = identity(child.pid)
        if observed["available"]:
            assert observed["pid"] == child.pid and observed["pgid"] == child.pid
    result = {"schema": 1, "status": "OWNED_WATCHER_LAUNCHED_NOT_ACCEPTANCE", "created_at": utc(),
              "watcherIdentity": observed, "watcherPID": child.pid, "command": command,
              "manifestSHA256": EXPECTED_MANIFEST, "control": str(control), "freeBefore": available,
              "launcherSourceSHA256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
    save(control / "LAUNCH_RESULT.json", result)
    print(json.dumps(result), flush=True)


if __name__ == "__main__":
    main()

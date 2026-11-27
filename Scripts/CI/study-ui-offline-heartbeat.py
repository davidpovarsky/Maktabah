#!/usr/bin/env python3
"""Oracle-side fresh pinned-SSH heartbeat for one coordinated Mac window.

No agent network policy is changed. Never run this as a Mac timer: the sealed
watchdog independently verifies a new SSH ancestry/socket from the admitted
Oracle peer for EVERY message. This relay does not activate PF or run native UI.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--window", required=True)
    parser.add_argument("--deadline-unix", required=True, type=float)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    if sys.platform != "linux" or os.geteuid() == 0:
        raise ValueError("Run only as the existing Oracle SSH owner, not Mac/root")
    if not re.fullmatch(r"[a-f0-9]{32}", args.window) or not 0 < args.deadline_unix - time.time() <= 900:
        raise ValueError("Invalid bounded existing window")
    output = Path(args.output)
    if not output.is_absolute() or output.exists() or output.parent.resolve() != output.parent:
        raise ValueError("Use a fresh canonical private heartbeat receipt")
    command = ["/usr/bin/sudo", "-n", "/usr/bin/python3", "-I", "-B",
               "/Library/Application Support/OtzariaOffline/" + args.window + "/watchdog.py", "heartbeat", args.window]
    deadline = time.monotonic() + args.deadline_unix - time.time()
    source_sha = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    descriptor = os.open(output, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    with os.fdopen(descriptor, "w") as handle:
        sequence = 0
        while time.monotonic() < deadline and time.time() < args.deadline_unix:
            started = time.time()
            # Explicitly disable connection multiplexing: a new remote channel
            # on an old SSH transport does not prove fresh control connectivity.
            call = ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=5", "-o", "StrictHostKeyChecking=yes",
                    "-o", "ControlMaster=no", "-o", "ControlPath=none", "scaleway-mac", shlex.join(command)]
            result = subprocess.run(call, capture_output=True, timeout=12)
            if len(result.stdout) + len(result.stderr) > 64 * 1024:
                raise ValueError("Heartbeat response exceeded bound")
            row = {"windowID": args.window, "sequence": sequence, "startedUnix": started,
                   "finishedUnix": time.time(), "exit": result.returncode,
                   "relayProcessID": os.getpid(), "relaySourceSHA256": source_sha,
                   "stdoutSHA256": hashlib.sha256(result.stdout).hexdigest(),
                   "stderrSHA256": hashlib.sha256(result.stderr).hexdigest()}
            if result.returncode == 0 and not result.stderr:
                value = json.loads(result.stdout)
                if value.get("windowID") == args.window and value.get("status") == "WINDOW_ALREADY_CLEANED" \
                        and re.fullmatch(r"[a-f0-9]{64}", value.get("cleanupSHA256", "")):
                    row["remote"] = value
                    handle.write(json.dumps(row) + "\n"); handle.flush(); os.fsync(handle.fileno())
                    return
                if value.get("windowID") != args.window or not re.fullmatch(r"[a-f0-9]{32}", value.get("nonce", "")):
                    raise ValueError("Wrong actual remote heartbeat receipt")
                row["remote"] = value
            handle.write(json.dumps(row) + "\n"); handle.flush(); os.fsync(handle.fileno())
            if result.returncode != 0 or result.stderr:
                raise RuntimeError("Fresh SSH heartbeat failed; independent watchdog must roll back")
            sequence += 1
            time.sleep(min(8, max(0, deadline - time.monotonic())))


if __name__ == "__main__":
    main()

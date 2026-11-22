#!/usr/bin/env python3
"""Idempotently idle the exact Simulator used by this CI validation step."""
from datetime import datetime, timezone
import json
import subprocess
import sys
import time
import uuid

udid = str(uuid.UUID(sys.argv[1])).upper()
started = time.monotonic()


def phase(name, **details):
    # Flush before each bounded command: a parent timeout must not hide which
    # exact owned-device operation was in flight. Never include environment.
    print(json.dumps({"event": "owned_simulator_shutdown", "udid": udid,
                      "phase": name, "at": datetime.now(timezone.utc).isoformat(),
                      "elapsed_seconds": round(time.monotonic() - started, 6),
                      **details}), flush=True)


def state(label):
    phase(label + "_REQUESTED", timeout_seconds=45)
    try:
        inventory = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "-j"], text=True, timeout=45))
    except BaseException as error:
        phase(label + "_FAILED", error_kind=type(error).__name__)
        raise
    value = next((device["state"] for devices in inventory["devices"].values() for device in devices
                  if device["udid"].upper() == udid), None)
    phase(label + "_OBSERVED", state=value)
    return value


try:
    initial_state = state("INITIAL_STATE")
except subprocess.TimeoutExpired:
    #43863125434 timed out in this read-only inventory after the window UI
    # had passed. Still request shutdown of ONLY our exact owned simulator,
    # then require an actual final state; never kill CoreSimulator globally.
    print("Initial Simulator inventory timed out; requesting exact owned shutdown", flush=True)
    initial_state = None
if initial_state == "Shutdown":
    phase("ALREADY_SHUTDOWN")
    print("Validation Simulator is already shut down", flush=True)
else:
    phase("SHUTDOWN_REQUESTED", timeout_seconds=180)
    try:
        result = subprocess.run(["xcrun", "simctl", "shutdown", udid], capture_output=True, text=True, timeout=180)
    except BaseException as error:
        phase("SHUTDOWN_FAILED", error_kind=type(error).__name__)
        raise
    phase("SHUTDOWN_RETURNED", returncode=result.returncode)
    # One authoritative postcondition read also covers the existing Xcode race.
    # The bounded path is45+180+45=270s; normal parents reserve300s.
    final_state = state("FINAL_STATE")
    if result.returncode and final_state != "Shutdown":
        phase("FINAL_STATE_REJECTED", returncode=result.returncode)
        print(result.stderr, file=sys.stderr)
        raise SystemExit(result.returncode)
    if final_state != "Shutdown":
        phase("FINAL_STATE_REJECTED", returncode=result.returncode)
        raise SystemExit("The validation Simulator did not shut down")
    phase("SHUTDOWN_VERIFIED")

#!/usr/bin/env python3
"""Idempotently idle the exact Simulator used by this CI validation step."""
import json
import subprocess
import sys
import uuid

udid = str(uuid.UUID(sys.argv[1])).upper()
def state():
    inventory = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "-j"], text=True))
    return next((device["state"] for devices in inventory["devices"].values() for device in devices
                 if device["udid"].upper() == udid), None)
if state() == "Shutdown":
    print("Validation Simulator is already shut down")
else:
    result = subprocess.run(["xcrun", "simctl", "shutdown", udid], capture_output=True, text=True, timeout=180)
    # Xcode may finish its own shutdown between the query and the command.
    if result.returncode and state() != "Shutdown":
        print(result.stderr, file=sys.stderr)
        raise SystemExit(result.returncode)
    if state() != "Shutdown":
        raise SystemExit("The validation Simulator did not shut down")

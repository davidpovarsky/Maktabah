#!/usr/bin/env python3
"""Capture diagnostics from the exact disposable validation Simulator."""
import json
import os
import re
from pathlib import Path
import subprocess
import sys
import uuid

udid = str(uuid.UUID(sys.argv[1])).upper()
label = sys.argv[2]
if label not in ["11", "13", "phone", "production"]:
    raise SystemExit("Unknown validation scenario")
destination = Path("build/artifacts")
destination.mkdir(parents=True, exist_ok=True)
def save(command, suffix):
    try:
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=45)
        output = result.stdout
    except subprocess.TimeoutExpired as error:
        output = error.stdout or ""
        if isinstance(output, bytes):
            output = output.decode("utf-8", errors="replace")
        output += "\nDiagnostic command timed out; this is not acceptance evidence.\n"
    token = os.environ.get("GH_TOKEN")
    if token:
        output = output.replace(token, "<redacted>")
    output = re.sub(r"(https?://[^\s?]+)\?[^\s]+", r"\1?<redacted>", output)
    output = re.sub(r"(?i)(authorization:\s*(?:bearer|token)\s+)\S+", r"\1<redacted>", output)
    (destination / f"simulator-failure-{label}-{suffix}.log").write_text(output[-1_000_000:], encoding="utf-8")

save(["xcrun", "simctl", "list", "devices", "-j"], "devices")
save(["xcrun", "simctl", "spawn", udid, "log", "show", "--style", "compact", "--last", "3m", "--predicate",
      "process == 'Maktabah' OR process == 'SpringBoard' OR process == 'installd'"], "services")
save(["xcrun", "simctl", "io", udid, "screenshot", str(destination / f"simulator-failure-{label}.png")], "screenshot")

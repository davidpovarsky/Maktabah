#!/usr/bin/env python3
"""Bounded input diagnostics from one owned simulator; never UI acceptance."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import uuid


def main():
    udid = str(uuid.UUID(sys.argv[1])).upper()
    label = sys.argv[2]
    if label != "11-window":
        raise ValueError("Only the owned R27 window diagnostic is supported")
    out = Path("build/artifacts/runtime27")
    out.mkdir(parents=True, exist_ok=True)
    predicate = 'subsystem == "com.davidpovarsky.chavrusatext" AND category == "R27PaletteInput"'
    command = ["xcrun", "simctl", "spawn", udid, "log", "show", "--style", "json",
               "--last", "15m", "--info", "--debug", "--predicate", predicate]
    report = {"status": "FAILED", "device_udid": udid, "command": command,
              "acceptance_effect": "NONE; diagnostic capture is not a UI pass"}
    try:
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=45)
        raw = result.stdout.decode("utf-8", errors="replace")
        report.update(exit_code=result.returncode, status="CAPTURED" if result.returncode == 0 else "FAILED")
    except subprocess.TimeoutExpired as error:
        raw = (error.stdout or b"").decode("utf-8", errors="replace")
        report["error"] = "Bounded simulator log command timed out"
    token = os.environ.get("GH_TOKEN")
    if token:
        raw = raw.replace(token, "<redacted>")
    report["truncated"] = len(raw.encode("utf-8")) > 1_000_000
    data = raw.encode("utf-8")[-1_000_000:]
    path = out / f"palette-input-{label}.log"
    path.write_bytes(data)
    report.update(path=path.name, bytes=len(data), sha256=hashlib.sha256(data).hexdigest())
    try:
        entries = json.loads(data)
        report["matching_events"] = sum(row.get("category") == "R27PaletteInput" and
            row.get("subsystem") == "com.davidpovarsky.chavrusatext" for row in entries)
    except (ValueError, TypeError, AttributeError):
        report["matching_events"] = "UNPARSED; inspect retained raw diagnostics"
    (out / f"palette-input-{label}.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report))
    return 0 if report["status"] == "CAPTURED" else 1


if __name__ == "__main__":
    raise SystemExit(main())

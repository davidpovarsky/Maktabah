#!/usr/bin/env python3
"""
select-ipad-simulator.py
Discovers an available iPad Simulator on the current macOS runner and writes
its UDID to an output file for automated simulator testing.
"""

import argparse
import json
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description="Discover available iPad simulator UDID")
    parser.add_argument("--out", default="sim_udid.txt", help="Output file to write UDID into")
    args = parser.parse_args()

    try:
        raw_json = subprocess.check_output(
            ["xcrun", "simctl", "list", "devices", "available", "-j"],
            text=True
        )
        data = json.loads(raw_json)
    except Exception as e:
        print(f"Error querying simctl: {e}", file=sys.stderr)
        sys.exit(1)

    devices_by_runtime = data.get("devices", {})
    selected_udid = None
    selected_name = None
    selected_runtime = None

    # First pass: Look for an available iPad device
    for runtime, devices in devices_by_runtime.items():
        for d in devices:
            if d.get("isAvailable") and "iPad" in d.get("name", ""):
                selected_udid = d.get("udid")
                selected_name = d.get("name")
                selected_runtime = runtime
                break
        if selected_udid:
            break

    # Fallback pass: Look for any available device
    if not selected_udid:
        for runtime, devices in devices_by_runtime.items():
            for d in devices:
                if d.get("isAvailable"):
                    selected_udid = d.get("udid")
                    selected_name = d.get("name")
                    selected_runtime = runtime
                    break
            if selected_udid:
                break

    if not selected_udid:
        print("ERROR: No available simulator device found in simctl!", file=sys.stderr)
        sys.exit(1)

    print(f"Found available simulator: {selected_name} ({selected_udid}) on {selected_runtime}")
    with open(args.out, "w", encoding="utf-8") as f:
        f.write(selected_udid.strip())
    print(f"Wrote simulator UDID to {args.out}")


if __name__ == "__main__":
    main()

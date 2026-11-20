#!/usr/bin/env python3
"""Authorize the existing exact Equatable macro after checking its real checkout."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
LOCK = "Maktabah.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
PACKAGE = "equatable"
LOCATION = "https://github.com/ordo-one/equatable"
REVISION = "597c2bb34af0c51331eb3b5e705f942d8ee20daa"


def capture(*command):
    return subprocess.check_output(command, cwd=ROOT, text=True, encoding="utf-8").strip()


def exact_pin(document):
    rows = [row for row in document["pins"] if row["identity"] == PACKAGE]
    if (len(rows) != 1 or rows[0]["location"] != LOCATION or
            rows[0]["kind"] != "remoteSourceControl" or
            rows[0]["state"]["revision"] != REVISION):
        raise RuntimeError("Committed/resolved Equatable macro pin differs from the original reviewed revision")
    return rows[0]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    report = {"status": "FAILED", "global_validation_disabled": False}
    try:
        source = ROOT / "Scripts/CI/hq-stage2-focused-apple.py"
        committed = subprocess.check_output(["git", "show", "HEAD:" + LOCK], cwd=ROOT)
        resolved = (ROOT / LOCK).read_bytes()
        if exact_pin(json.loads(committed)) != exact_pin(json.loads(resolved)):
            raise RuntimeError("Xcode changed the original Equatable package pin")
        checkout = ROOT / "build/SourcePackages/checkouts/equatable"
        if Path(capture("git", "-C", str(checkout), "rev-parse", "--show-toplevel")).resolve() != checkout.resolve():
            raise RuntimeError("Expected actual standalone Equatable checkout")
        head = capture("git", "-C", str(checkout), "rev-parse", "HEAD")
        dirty = capture("git", "-C", str(checkout), "status", "--porcelain", "--untracked-files=all")
        if head != REVISION or dirty:
            raise RuntimeError("Actual Equatable macro checkout must be the exact pristine original source")
        report.update({
            "checkout_sha": capture("git", "rev-parse", "HEAD"),
            "package_pins": {PACKAGE: REVISION},
            "actual_package_checkouts": {PACKAGE: {"head": head, "status": "CLEAN"}},
            "package_location": LOCATION,
            "committed_lock_sha256": hashlib.sha256(committed).hexdigest(),
            "resolved_lock_sha256": hashlib.sha256(resolved).hexdigest(),
            "existing_authorizer_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        })
        spec = importlib.util.spec_from_file_location("focused_apple", source)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        module.authorize_pinned_equatable_macro(report)
        report["status"] = "EXACT_EXISTING_MACRO_AUTHORIZED"
        return 0
    except Exception as error:
        report["error"] = str(error)
        return 1
    finally:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(report, indent=2))


if __name__ == "__main__":
    raise SystemExit(main())

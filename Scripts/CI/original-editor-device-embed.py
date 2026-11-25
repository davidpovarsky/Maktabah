#!/usr/bin/env python3
"""Embed or verify only the explicitly admitted original Release device SDK."""
import argparse
from pathlib import Path
import runpy


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["embed", "verify"])
    parser.add_argument("--receipt", required=True)
    parser.add_argument("--receipt-sha256", required=True)
    parser.add_argument("--app", required=True)
    parser.add_argument("--evidence", required=True)
    parser.add_argument("--after-archive", action="store_true")
    args = parser.parse_args()
    if args.after_archive and args.command != "verify":
        parser.error("--after-archive is only a verification phase")
    root = Path(__file__).resolve().parents[2]
    module = runpy.run_path(str(root / "Scripts/CI/original_editor_device_signature.py"))
    extra = {"after_archive": args.after_archive} if args.command == "verify" else {}
    result = module[args.command](root, args.receipt, args.receipt_sha256, Path(args.app), args.evidence, **extra)
    print(result["status"])


if __name__ == "__main__":
    main()

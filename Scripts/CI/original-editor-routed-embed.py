#!/usr/bin/env python3
"""Xcode app-target entrypoint for the exact admitted SDK configuration/platform."""
import argparse
from pathlib import Path
from original_editor_sdk_routes import embed

if __name__ == '__main__':
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('command', choices=['embed'])
    parser.add_argument('--routes', required=True)
    parser.add_argument('--routes-sha256', required=True)
    parser.add_argument('--app', required=True)
    args = parser.parse_args()
    embed(Path(__file__).resolve().parents[2], args.routes, args.routes_sha256, Path(args.app))

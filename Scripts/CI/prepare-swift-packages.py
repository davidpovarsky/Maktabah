#!/usr/bin/env python3
"""
Scripts/CI/prepare-swift-packages.py
Prepares pre-resolved Swift packages and fixes workspace-state schema compatibility
for Xcode 16.x runners.
"""

import json
import os
import sys

RESOLVED_PACKAGES_V2 = {
    "pins": [
        {
            "identity": "anchoredpopup",
            "kind": "remoteSourceControl",
            "location": "https://github.com/exyte/AnchoredPopup.git",
            "state": {
                "revision": "f93c51e75ff4e5242328ac24c8fb12f1f1e84eda",
                "version": "1.3.1"
            }
        },
        {
            "identity": "floatingpanel",
            "kind": "remoteSourceControl",
            "location": "https://github.com/scenee/FloatingPanel.git",
            "state": {
                "revision": "3db567a19ff81d2d3ce00399021ee87a4fccf7e0",
                "version": "3.2.4"
            }
        },
        {
            "identity": "sparkle",
            "kind": "remoteSourceControl",
            "location": "https://github.com/sparkle-project/Sparkle",
            "state": {
                "revision": "066e75a8b3e99962685d6a90cdd5293ebffd9261",
                "version": "2.9.1"
            }
        },
        {
            "identity": "torahinspectorkit",
            "kind": "remoteSourceControl",
            "location": "https://github.com/davidpovarsky/TorahInspectorKit.git",
            "state": {
                "revision": "b1fbfbec8f44c2f70d09ec80b36a3436872c6e57"
            }
        },
        {
            "identity": "zipfoundation",
            "kind": "remoteSourceControl",
            "location": "https://github.com/weichsel/ZIPFoundation.git",
            "state": {
                "revision": "22787ffb59de99e5dc1fbfe80b19c97a904ad48d",
                "version": "0.9.20"
            }
        },
        {
            "identity": "zstd",
            "kind": "remoteSourceControl",
            "location": "https://github.com/facebook/zstd.git",
            "state": {
                "revision": "f8745da6ff1ad1e7bab384bd1f9d742439278e99",
                "version": "1.5.7"
            }
        }
    ],
    "version": 2
}

def fix_workspace_state(ws_file):
    if not os.path.isfile(ws_file):
        print(f"Note: {ws_file} not found; skipping workspace-state patch.")
        return
    with open(ws_file, "r", encoding="utf-8") as f:
        data = json.load(f)

    changed = False
    for art in data.get("object", {}).get("artifacts", []):
        if isinstance(art.get("kind"), dict):
            art["kind"] = "xcframework"
            changed = True

    if changed:
        with open(ws_file, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
        print(f"Patched {ws_file} for Xcode 16 schema compatibility.")
    else:
        print(f"{ws_file} already has compatible schema.")

def main():
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

    # 1. Patch workspace-state.json if extracted in build/SourcePackages
    ws_file = os.path.join(root, "build", "SourcePackages", "workspace-state.json")
    fix_workspace_state(ws_file)

    # 2. Write Package.resolved to both workspace and project locations
    resolved_paths = [
        os.path.join(root, "Maktabah.xcworkspace", "xcshareddata", "swiftpm", "Package.resolved"),
        os.path.join(root, "Maktabah.xcodeproj", "project.xcworkspace", "xcshareddata", "swiftpm", "Package.resolved"),
        os.path.join(root, "build", "SourcePackages", "Package.resolved"),
    ]

    for p in resolved_paths:
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "w", encoding="utf-8") as f:
            json.dump(RESOLVED_PACKAGES_V2, f, indent=2)
        print(f"Wrote complete Package.resolved to: {p}")

if __name__ == "__main__":
    main()

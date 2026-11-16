#!/usr/bin/env python3
"""Small local checks only; never build an app or dispatch Apple/project CI."""
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
subprocess.run([sys.executable, str(root / "Scripts/CI/test-native-sidebar-policy.py")],
               cwd=root, check=True)

files = [
    "Source/ChavrusaText/ReaderHost/ReaderSidebarPageCoordinator.swift",
    "Source/UI/iOS/Views/iPadLayout.swift",
    "Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift",
    "Maktabah-iOSUITests/Sidebar11201AcceptanceTests.swift",
]
subprocess.run(["swiftc", "-frontend", "-parse", *files], cwd=root, check=True)
with tempfile.TemporaryDirectory(prefix="hq-sidebar-parse-") as directory:
    # Parse the normally inactive Apple branch too. This is syntax validation,
    # explicitly NOT SwiftUI/UIKit typechecking on Windows.
    source = (root / "Source/ChavrusaText/ReaderHost/ReaderSidebarPager.swift").read_text(encoding="utf-8")
    guard = "#if canImport(SwiftUI) && canImport(UIKit)"
    if source.count(guard) != 1:
        raise RuntimeError("Pager platform guard changed; review parse coverage")
    active = Path(directory) / "ReaderSidebarPager.swift"
    active.write_text(source.replace(guard, "#if true"), encoding="utf-8")
    subprocess.run(["swiftc", "-frontend", "-parse", str(active)], cwd=root, check=True)
subprocess.run(["git", "diff", "--check"], cwd=root, check=True)
print("PASS: five changed/prepared Swift files parsed, including the pager Apple branch; diff whitespace clean", flush=True)
print("NOT_RUN: Apple typecheck, app build, simulator/device, gesture arbitration and visual acceptance", flush=True)

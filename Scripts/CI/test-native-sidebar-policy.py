#!/usr/bin/env python3
"""Compile the actual pager's portable policy; never launch an Apple runtime."""
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix="native-sidebar-policy-") as directory:
    executable = Path(directory) / ("sidebar.exe" if os.name == "nt" else "sidebar")
    subprocess.run(["swiftc", "-parse-as-library",
                    str(root / "Source/ChavrusaText/ReaderHost/ReaderSidebarPager.swift"),
                    str(root / "tools/test_native_sidebar_policy.swift"), "-o", str(executable)],
                   cwd=root, check=True)
    subprocess.run([str(executable)], cwd=root, check=True)

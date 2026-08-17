#!/usr/bin/env python3
from hashlib import sha256
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[2]

if sys.argv[1:] != ["swiftpm"]:
    raise SystemExit("usage: cache-key-inputs.py swiftpm")

project = (root / "Maktabah.xcodeproj" / "project.pbxproj").read_text(encoding="utf-8")
sections = []
for name in ["XCRemoteSwiftPackageReference", "XCSwiftPackageProductDependency"]:
    match = re.search(
        rf"/\* Begin {name} section \*/(.*?)/\* End {name} section \*/",
        project,
        re.S,
    )
    sections.append(match.group(1) if match else "")

resolved = root / "Maktabah.xcodeproj" / "project.xcworkspace" / "xcshareddata" / "swiftpm" / "Package.resolved"
payload = "\n".join(sections).encode("utf-8")
if resolved.exists():
    payload += b"\n" + resolved.read_bytes()
print(sha256(payload).hexdigest())

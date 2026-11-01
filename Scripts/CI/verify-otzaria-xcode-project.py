#!/usr/bin/env python3
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[2]
project_path = root / "Maktabah.xcodeproj" / "project.pbxproj"
text = project_path.read_text(encoding="utf-8")

target_match = re.search(
    r"[A-F0-9]+ /\* Maktabah-iOS \*/ = \{.*?buildPhases = \((.*?)\);",
    text,
    re.S,
)
if not target_match:
    raise SystemExit("Maktabah-iOS target build phases were not found")

build_phases_text = target_match.group(1)

def phase_id(label: str) -> str:
    match = re.search(rf"([A-F0-9]+) /\* {label} \*/", build_phases_text)
    if not match:
        raise SystemExit(f"Maktabah-iOS build phase '{label}' was not found in target")
    return match.group(1)

def phase_body(identifier: str, label: str) -> str:
    match = re.search(
        rf"{identifier} /\* {label} \*/ = \{{.*?files = \((.*?)\);",
        text,
        re.S,
    )
    if not match:
        raise SystemExit(f"{label} phase {identifier} was not found")
    return match.group(1)

sources = phase_body(phase_id("Sources"), "Sources")
frameworks = phase_body(phase_id("Frameworks"), "Frameworks")
resources = phase_body(phase_id("Resources"), "Resources")

missing = []
for source in sorted((root / "Source" / "Otzaria").rglob("*.swift")):
    if "Experimental" in source.parts:
        continue
    token = f"/* {source.name} in Sources */"
    if token not in sources:
        missing.append(source.relative_to(root).as_posix())

for expected in [
    "OtzariaSearchEngine.xcframework in Frameworks",
    "MaktabahZayitSearch.xcframework in Frameworks",
]:
    if expected not in frameworks:
        missing.append(expected)

for expected in [
    "dictionary.json in Resources",
    "Acronyms.json in Resources",
    "miniTest10.profile.json in Resources",
]:
    if expected not in resources:
        missing.append(expected)

if missing:
    print("Missing Maktabah-iOS project membership:", file=sys.stderr)
    for item in missing:
        print(f"  {item}", file=sys.stderr)
    raise SystemExit(1)

print(
    "Verified Maktabah-iOS project membership for "
    f"{len(list((root / 'Source' / 'Otzaria').rglob('*.swift')))} Otzaria Swift files, "
    "both search frameworks, and required dictionaries"
)

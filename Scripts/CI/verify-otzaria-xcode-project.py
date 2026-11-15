#!/usr/bin/env python3
from pathlib import Path
import argparse
import re
import runpy
import sys

root = Path(__file__).resolve().parents[2]
arguments = argparse.ArgumentParser()
arguments.add_argument('--project-path', type=Path, default=root / 'Maktabah.xcodeproj/project.pbxproj')
project_path = arguments.parse_args().project_path
text = project_path.read_text(encoding="utf-8")

native_section_match = re.search(
    r"/\* Begin PBXNativeTarget section \*/(.*?)/\* End PBXNativeTarget section \*/",
    text,
    re.S,
)
if not native_section_match:
    raise SystemExit("PBXNativeTarget section not found in project.pbxproj")

native_section = native_section_match.group(1)

target_match = re.search(
    r"[A-F0-9]+\s*(?:/\* [^*]* \*/)?\s*=\s*\{(?P<body>[^{}]*?name\s*=\s*\"?Maktabah-iOS\"?;[^{}]*?)\};",
    native_section,
    re.S,
)
if not target_match:
    target_match = re.search(
        r"F30576DD2FA46222005732C6\s*(?:/\* [^*]* \*/)?\s*=\s*\{(?P<body>[^{}]*?)\};",
        native_section,
        re.S,
    )

if not target_match:
    raise SystemExit("Maktabah-iOS target build phases were not found")

target_body = target_match.group("body")
build_phases_match = re.search(r"buildPhases\s*=\s*\((.*?)\);", target_body, re.S)
if not build_phases_match:
    raise SystemExit("Maktabah-iOS target build phases were not found")

build_phases_text = build_phases_match.group(1)

def phase_id(label: str) -> str:
    match = re.search(rf"([A-F0-9]+)\s*/\*\s*{re.escape(label)}\s*\*/", build_phases_text)
    if not match:
        raise SystemExit(f"Maktabah-iOS build phase '{label}' was not found in target")
    return match.group(1)

def phase_body(identifier: str, label: str) -> str:
    match = re.search(
        rf"{identifier}\s*(?:/\*\s*{re.escape(label)}\s*\*/)?\s*=\s*\{{.*?files\s*=\s*\((.*?)\);",
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
parse = runpy.run_path(str(root / 'docs/hq-integration/verify_source_registration.py'))['parse']
project, _ = parse(text)
objects = project['objects']
target = objects['F30576DD2FA46222005732C6']
framework_phase = next(objects[item] for item in target['buildPhases'] if objects[item]['isa'] == 'PBXFrameworksBuildPhase')
package_roots = {'Actions': 'OtzariaActionCore', 'UIRouting': 'OtzariaUIRouting'}
for folder, name in package_roots.items():
    package_path = root / 'Source/Otzaria' / folder
    if not (package_path / 'Package.swift').is_file():
        continue
    products = [item for item in target.get('packageProductDependencies', [])
                if objects[item].get('productName') == name]
    if len(products) != 1:
        missing.append(f'{name}: exactly one iOS package product dependency required')
        continue
    product = products[0]
    package = objects.get(objects[product].get('package'), {})
    if package.get('isa') != 'XCLocalSwiftPackageReference' or package.get('relativePath') != f'Source/Otzaria/{folder}':
        missing.append(f'{name}: wrong local package reference')
    elif objects[product]['package'] not in objects[project['rootObject']].get('packageReferences', []):
        missing.append(f'{name}: package missing from project references')
    if sum(objects[item].get('productRef') == product for item in framework_phase['files']) != 1:
        missing.append(f'{name}: exactly one linked package product required')
# The real app uses explicit ChavrusaText membership even though MaktabahTests
# is synchronized. A standalone SDK compile cannot establish target membership.
overview_bridge = root / "Source/ChavrusaText/ReaderHost/ReaderOverviewPresentation.swift"
if overview_bridge.is_file() and "/* ReaderOverviewPresentation.swift in Sources */" not in sources:
    missing.append(overview_bridge.relative_to(root).as_posix())
for source in sorted((root / "Source" / "Otzaria").rglob("*.swift")):
    if "Experimental" in source.parts:
        continue
    relative = source.relative_to(root / 'Source/Otzaria').parts
    if relative[0] in package_roots:
        # SPM compiles its Sources and owns its manifest/tests. Only explicit
        # Integration sources outside that target belong in app source phases.
        if (len(relative) > 1 and relative[1] in {'Sources', 'Tests'}) or relative[1:] == ('Package.swift',):
            if f'/* {source.name} in Sources */' in sources:
                missing.append(f'SPM-owned file compiled into app: {source.relative_to(root).as_posix()}')
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
    "Verified Maktabah-iOS app/package source ownership for "
    f"{len(list((root / 'Source' / 'Otzaria').rglob('*.swift')))} Otzaria Swift files, "
    "both search frameworks, and required dictionaries"
)

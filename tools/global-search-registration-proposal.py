"""Write reviewable registration artifacts only; NEVER modify the shared project."""
from pathlib import Path
import difflib
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/features/search/selftest-20261115"
OUT.mkdir(parents=True, exist_ok=True)
project = ROOT / "Maktabah.xcodeproj/project.pbxproj"
original = project.read_text(encoding="utf-8")
proposed = original
files = sorted((ROOT / "Source/ChavrusaText/Search/UI").glob("*.swift"))
def identifier(kind, path):
    return hashlib.sha1(("global-search-20261115:" + kind + ":" + path).encode()).hexdigest()[:24].upper()

builds, references, children, sources = [], [], [], []
inventory = []
for file in files:
    relative = file.relative_to(ROOT).as_posix()
    ref, build = identifier("ref", relative), identifier("build", relative)
    assert ref not in original and build not in original
    builds.append(f'\t\t{build} /* {file.name} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {file.name} */; }};\n')
    references.append(f'\t\t{ref} /* {file.name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = {file.name}; path = {relative}; sourceTree = SOURCE_ROOT; }};\n')
    children.append(f'\t\t\t\t{ref} /* {file.name} */,\n')
    sources.append(f'\t\t\t\t{build} /* {file.name} in Sources */,\n')
    inventory.append({"path": relative, "sha256": hashlib.sha256(file.read_bytes()).hexdigest(),
                      "target": "Maktabah-iOS (same Sources phase as UnifiedSearchSessionController.swift)"})

proposed = proposed.replace("/* End PBXBuildFile section */", "".join(builds) + "/* End PBXBuildFile section */", 1)
proposed = proposed.replace("/* End PBXFileReference section */", "".join(references) + "/* End PBXFileReference section */", 1)
group = identifier("group", "Global Search UI")
group_block = f'\t\t{group} /* Global Search UI */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n' + "".join(children) + '\t\t\t);\n\t\t\tname = "Global Search UI";\n\t\t\tsourceTree = "<group>";\n\t\t};\n'
proposed = proposed.replace("/* End PBXGroup section */", group_block + "/* End PBXGroup section */", 1)
anchor = '\t\tCFEE00000000000000000001 /* ChavrusaText */ = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n'
assert proposed.count(anchor) == 1
proposed = proposed.replace(anchor, anchor + f'\t\t\t\t{group} /* Global Search UI */,\n', 1)
source_anchor = '\t\t\t\tFA1000000000000000000005 /* UnifiedSearchSessionController.swift in Sources */,\n'
assert proposed.count(source_anchor) == 1
proposed = proposed.replace(source_anchor, source_anchor + "".join(sources), 1)
patch = "".join(difflib.unified_diff(original.splitlines(keepends=True), proposed.splitlines(keepends=True),
                                 fromfile="a/Maktabah.xcodeproj/project.pbxproj", tofile="b/Maktabah.xcodeproj/project.pbxproj"))
(OUT / "MANAGER_REGISTRATION_PROPOSAL.patch").write_text(patch, encoding="utf-8", newline="\n")
(OUT / "ADDITIVE_SOURCE_INVENTORY.json").write_text(json.dumps({"base": "13e40d1daa4a53799c94cd8ed5170f1343b9b1e8",
    "projectEdited": False, "files": inventory, "testMembership": "Portable S fixtures only; independent I owns native acceptance suite registration."}, indent=2) + "\n", encoding="utf-8")
assert project.read_text(encoding="utf-8") == original
protected = ["Source/Features/Search/iOS/SearchModeView.swift", "Source/Features/Search/iOS/SearchResultsListView.swift",
             "Source/Features/Search/iOS/iOSSearchFilterViewController.swift", "Source/Features/Search/ViewModel/SearchViewModel.swift",
             "Source/Features/Search/ViewModel/Extensions/Search+Execution.swift", "Source/UI/iOS/Views/iPadLayout.swift",
             "Source/UI/iOS/Views/iPhoneLayout.swift"]
protected_diff = subprocess.check_output(["git", "diff", "--no-ext-diff", "13e40d1daa4a53799c94cd8ed5170f1343b9b1e8", "--", *protected], cwd=ROOT)
(OUT / "PROTECTED_HUNKS.patch").write_bytes(protected_diff)
code = files + [ROOT / p for p in protected] + [ROOT / "Source/ZayitSearch/UnifiedSearchSessionController.swift"]
(OUT / "CODE_SNAPSHOT.json").write_text(json.dumps({
    "base": "13e40d1daa4a53799c94cd8ed5170f1343b9b1e8",
    "upstream": "d46af139b3a265399c16d87f5923acd8e3444024",
    "protectedDiffSHA256": hashlib.sha256(protected_diff).hexdigest(),
    "sourceHashes": {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in code},
    "portableResults": {"presentation": 42, "actualPaging": 18, "existingModels": 191, "cachedReadiness": 14},
    "nativeBuild": "NOT_RUN", "physicalDevice": "NOT_RUN"
}, indent=2) + "\n", encoding="utf-8")
print(f"Prepared manager-only proposal for {len(files)} iOS app sources; shared project untouched.")

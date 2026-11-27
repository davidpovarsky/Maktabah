"""Read-only OpenStep/project graph validation for the leased registration patch.

Uses stdlib only. This verifies project structure and exact target membership;
it does not replace Xcode parsing, compilation, linkage or runtime acceptance.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess


def parse(text):
    token = re.compile(r'\s+|//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\])*"|[{}()=;,]|[^\s{}()=;,"]+', re.S)
    tokens = [m.group() for m in token.finditer(text)
              if not m.group().isspace() and not m.group().startswith(("//", "/*"))]
    index = 0
    duplicates = []

    def take(expected=None):
        nonlocal index
        value = tokens[index]
        index += 1
        if expected is not None:
            assert value == expected, (expected, value, index)
        return value

    def value():
        item = take()
        if item == "{":
            result = {}
            while tokens[index] != "}":
                key = take().strip('"')
                take("=")
                item_value = value()
                if key in result:
                    duplicates.append({"key": key, "identical": result[key] == item_value})
                result[key] = item_value
                take(";")
            take("}")
            return result
        if item == "(":
            result = []
            while tokens[index] != ")":
                result.append(value())
                if tokens[index] != ")":
                    take(",")
            take(")")
            return result
        assert item not in "}=;,)", (item, index)
        return item[1:-1] if item.startswith('"') else item

    result = value()
    assert index == len(tokens), "trailing project tokens"
    return result, duplicates


def target_sources(project):
    objects = project["objects"]
    result = {}
    for target in objects.values():
        if target.get("isa") != "PBXNativeTarget":
            continue
        sources = [phase for phase in target["buildPhases"]
                   if objects[phase]["isa"] == "PBXSourcesBuildPhase"]
        assert len(sources) == 1, target["name"]
        result[target["name"]] = (sources[0], objects[sources[0]]["files"])
    return result


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    ap.add_argument("--baseline", default="df2a21941afa46da716387fce9de620865d2a151")
    ap.add_argument("--source", action="append", default=[], help="Repository-relative new source path")
    ap.add_argument("--source-root", type=Path, help="Delivered source tree; reads only, no files copied")
    ap.add_argument("--targets", nargs="+", default=["Maktabah", "Maktabah-Direct", "Maktabah-iOS"])
    args = ap.parse_args()
    project_path = "Maktabah.xcodeproj/project.pbxproj"
    base_text = subprocess.check_output(["git", "-C", str(args.root), "show", f"{args.baseline}:{project_path}"], text=True, encoding="utf-8")
    base, old_duplicates = parse(base_text)
    current, duplicates = parse((args.root / project_path).read_text(encoding="utf-8"))
    assert duplicates == old_duplicates, "introduced/changed duplicate dictionary keys"
    old_objects, objects = base["objects"], current["objects"]
    assert {k: v for k, v in base.items() if k != "objects"} == {k: v for k, v in current.items() if k != "objects"}
    assert old_objects.keys() <= objects.keys(), "removed existing project objects"
    phases = target_sources(current)
    changed = {key for key in old_objects if old_objects[key] != objects[key]}
    allowed = {"CFEE00000000000000000001"} | {phases[name][0] for name in args.targets}
    assert changed <= allowed, f"unleased project changes: {changed - allowed}"
    added = objects.keys() - old_objects.keys()
    assert len(added) == len(args.source) * (1 + len(args.targets)), (len(added), args.source)
    assert all(objects[key]["isa"] in {"PBXFileReference", "PBXBuildFile"} for key in added)
    for key in changed:
        field = "children" if objects[key]["isa"] == "PBXGroup" else "files"
        before, after = old_objects[key], objects[key]
        assert {k: v for k, v in before.items() if k != field} == {k: v for k, v in after.items() if k != field}
        assert [item for item in after[field] if item in before[field]] == before[field], f"reordered/removed existing entries: {key}"
        assert all(after[field].count(item) == 1 for item in after[field] if item not in before[field]), f"new duplicate entries: {key}"
    report = []
    for path in args.source:
        relative = str(Path(path).relative_to("Source/ChavrusaText")).replace("\\", "/")
        refs = [key for key in added if objects[key]["isa"] == "PBXFileReference" and objects[key]["path"] == relative]
        assert len(refs) == 1, (path, refs)
        ref = refs[0]
        assert objects[ref]["sourceTree"] == "<group>"
        assert objects["CFEE00000000000000000001"]["children"].count(ref) == 1
        build_ids = {key for key in added if objects[key].get("fileRef") == ref}
        actual = []
        for name, (_, files) in phases.items():
            matches = [key for key in files if key in build_ids]
            if matches:
                assert len(matches) == 1, (path, name, matches)
                actual.append(name)
        assert set(actual) == set(args.targets), (path, actual)
        delivered = (args.source_root or args.root) / path
        assert delivered.is_file(), f"delivered source missing: {delivered}"
        report.append({"path": path, "targets": sorted(actual), "delivered_source": str(delivered), "present_in_integration_tree": (args.root / path).is_file()})
    print(json.dumps({"status": "PASS", "scope": "OpenStep token structure and additive target membership only; inherited duplicate keys preserved, not repaired", "baseline": args.baseline, "inherited_duplicate_keys": duplicates, "new_objects": len(added), "modified_existing_objects": sorted(changed), "sources": report}, indent=2))


if __name__ == "__main__":
    main()

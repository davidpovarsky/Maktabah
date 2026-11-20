#!/usr/bin/env python3
"""Verify immutable source/evidence only. Does not execute Native or SQL."""
from __future__ import annotations
import gzip, hashlib, json, pathlib, re, subprocess

here = pathlib.Path(__file__).resolve().parent
repo = here.parents[2]
sha = lambda b: hashlib.sha256(b).hexdigest()
read = lambda p: json.loads((here / p).read_bytes())
manifest = read("SHA256SUMS.json")
assert len({x["path"] for x in manifest["files"]}) == len(manifest["files"])
for item in manifest["files"]:
    relative = pathlib.PurePosixPath(item["path"])
    assert not relative.is_absolute() and ".." not in relative.parts
    raw = (here / item["path"]).read_bytes()
    assert len(raw) == item["bytes"] and sha(raw) == item["sha256"], item["path"]
    if "uncompressedSHA256" in item:
        assert sha(gzip.decompress(raw)) == item["uncompressedSHA256"], item["path"]
for item in read("NEWLINE_PROVENANCE.json")["records"]:
    raw = gzip.decompress((here / item["rawGzip"]).read_bytes())
    view = (here / item["view"]).read_bytes()
    assert sha(raw) == item["originalSHA256"]
    assert sha(view) == item["gitLFSHA256"]
    assert raw.replace(b"\r\n", b"\n") == view

evidence = read("EVIDENCE.json")
proof = read("FINAL_SOURCE_INVERSE.json")
source, base = evidence["sourceCommit"], proof["base"]
git = lambda *a: subprocess.check_output(["git", *a], cwd=repo)
files = {x["path"]: x for x in proof["files"]}
assert len(files) == 3
assert set(git("diff", "--name-only", base, source).decode().splitlines()) == set(files)
original, current = {}, {}
for path, item in files.items():
    original[path] = git("show", base + ":" + path)
    current[path] = git("show", source + ":" + path)
    assert sha(original[path]) == item["baseGitBlobSHA256"], path
    assert sha(current[path]) == item["candidateSHA256"], path
    snap = here / "source-snapshot" / (path.replace("/", "__") + ".gz")
    assert gzip.decompress(snap.read_bytes()) == current[path], path
comp = "Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeRoutingComposition.swift"
scene = "Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSceneSession.swift"
test = "Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift"
material = read("ADDITIVE_MATERIAL.json")
old_guard = 'guard ["notes", "search", "commentary", "count"].contains(kind) else { return nil }'
new_guard = 'guard ["notes", "search", "commentary", "count", "journey-count-results",\n               "journey-commentary-draft", "journey-catalog-stop"].contains(kind) else { return nil }'
text = current[comp].decode()
for key in ("compositionFunctions", "dispatch"):
    assert text.count(material[key]) == 1
    text = text.replace(material[key], "", 1)
assert text.count(new_guard) == 1
assert text.replace(new_guard, old_guard, 1).encode() == original[comp]
text = current[scene].decode()
assert text.count(material["scene"]) == 1
assert text.replace(material["scene"], "", 1).encode() == original[scene]
text = current[test].decode()
assert text.endswith(material["append"])
old = 'XCTAssertTrue(["notes", "search", "commentary", "count"].contains(kind))'
new = 'XCTAssertTrue(["notes", "search", "commentary", "count", "journey-count-results",\n                       "journey-commentary-draft", "journey-catalog-stop"].contains(kind))'
text = text[:-len(material["append"])]
assert text.count(new) == 1 and text.replace(new, old, 1).encode() == original[test]
names = lambda data: re.findall(r"\bfunc\s+(test[A-Za-z0-9_]+)\s*\(", data.decode())
before, after = names(original[test]), names(current[test])
assert len(before) == 50 and len(after) == 56 and len(set(after)) == 56
assert all(after.count(x) == before.count(x) for x in before)
assert [x.split("/")[-1] for x in proof["newCases"]] == [x for x in after if x not in before]
for folder, debug in (("syntax-attempt1", False), ("syntax-attempt2-debug", True)):
    result = read(folder + "/RESULT.json")
    assert result["passed"] and len(result["files"]) == 3
    for item in result["files"]:
        assert item["exitCode"] == 0 and item["sourceUnchanged"]
        assert item["sha256"] == files[item["path"]]["candidateSHA256"]
        command = item["command"]
        assert "-parse" in command and "-typecheck" not in command
        assert ("DEBUG" in command) == debug
        assert item["warnings"] == 2
sql = read("FINAL_SQL_SOURCE_IDENTITY.json")
assert sql["readOnlyURI"] and sql["queryOnly"] and sql["bytes"] == 15470592
assert sql["sha256Before"] == sql["sha256After"] == "d3d9bfcc2320a987a0391ad23fa72abcf6fd1fa0f3cba95adc05096e05a9edef"
q = sql["queries"]
assert q["exactTOCHeading"]["rows"] == [[600, 28, 599, "פרק א", 15827, 1]]
assert q["exactVerseAndCommentaryLink"]["rows"] == [[6529212, 28, 6188105, 2, 3276, 6609893, 4, "COMMENTARY"]]
for key in ("headingOutgoing", "headingIncoming", "headingCoverage"):
    assert q[key]["rows"] == []
references = read("REFERENCE_INPUTS.json")
for item in references["gitFiles"]:
    raw = git("show", source + ":" + item["path"])
    assert sha(raw) == item["gitSHA256"], item["path"]
oracle = json.loads(git("show", source + ":" + references["independentOraclePath"]))
assert oracle["databaseSHA256"] == sql["sha256Before"]
assert oracle["rowsScanned"] == 18879
assert oracle["queries"]["אברהם"]["books"]["1"] == {"occurrences": 109, "matchingLiveDocuments": 98}
assert evidence["nativeExecuted"] == 0 and evidence["appleTypecheck"] == "NOT_RUN"
print(json.dumps({"status": "PASS_SOURCE_AND_RECORDED_EVIDENCE_ONLY", "sealedFiles": len(manifest["files"]), "sourceCommit": source, "originalDeclarations": len(before), "candidateDeclarations": len(after), "newNativeDeclarations": 6, "nativeExecuted": 0, "appleTypecheck": "NOT_RUN"}, indent=2))

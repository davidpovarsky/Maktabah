"""Verify exact recorded source/evidence. Does not run Swift, Native or benchmarks."""
from pathlib import Path
import gzip, hashlib, json, re, subprocess
HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sha = lambda data: hashlib.sha256(data).hexdigest()
read = lambda name: json.loads((HERE / name).read_bytes())
evidence = read("EVIDENCE.json")
manifest = read("ARTIFACTS.json")
assert len({x["path"] for x in manifest["files"]}) == len(manifest["files"])
for item in manifest["files"]:
    path = Path(item["path"])
    assert not path.is_absolute() and ".." not in path.parts
    data = (HERE / path).read_bytes()
    assert len(data) == item["bytes"] and sha(data) == item["sha256"], item["path"]
    if "rawSHA256" in item:
        raw = gzip.decompress(data)
        assert len(raw) == item["rawBytes"] and sha(raw) == item["rawSHA256"], item["path"]
git = lambda ref, path: subprocess.check_output(["git", "show", ref + ":" + path], cwd=REPO)
source = evidence["sourceCommit"]
base = evidence["base"]
inputs = read("SOURCE_INPUTS.json")
for path, expected in inputs.items():
    assert sha(git(source, path)) == expected, path
material = read("INVERSE_MATERIAL.json")
adapter = "Source/ChavrusaText/StudyWorkspace/StudyWorkspaceNavigationAdapter.swift"
ui = "Maktabah-iOSUITests/FaithfulReaderUIAcceptanceTests.swift"
project = "Maktabah.xcodeproj/project.pbxproj"
text = git(source, adapter).decode()
for key in ["adapter_hook", "adapter_endhook"]:
    assert text.count(material[key]) == 1
    text = text.replace(material[key], "", 1)
assert text.encode() == git(base, adapter)
text = git(source, ui).decode()
for key in ["metric_types", "property", "declaration", "expectation", "capture"]:
    assert text.count(material[key]) == 1
    text = text.replace(material[key], "", 1)
block = material["capture_method"] + "\n"
assert text.count(block) == 1
text = text.replace(block, "", 1)
text = text.replace('        launchReader(backend: "otzaria", tier: .realUI)',
                    '        launchReader(backend: "otzaria")')
text = text.replace('        launchReader(scenario: "catalog", backend: "otzaria", tier: .realUI)',
                    '        launchReader(scenario: "catalog", backend: "otzaria")')
assert text.encode() == git(base, ui)
old_names = re.findall(rb"\bfunc\s+(test[A-Za-z0-9_]+)\s*\(", git(base, ui))
new_names = re.findall(rb"\bfunc\s+(test[A-Za-z0-9_]+)\s*\(", git(source, ui))
assert old_names == new_names
text = git(source, project).decode()
for addition in material["project_additions"]:
    assert text.count(addition) == 1
    text = text.replace(addition, "", 1)
assert text.encode() == git(base, project)
result = json.loads(gzip.decompress((HERE / "raw/attempt1/RESULT.json.gz").read_bytes()))
assert result["status"] == "PASS_PORTABLE_ONLY"
assert result["compile"]["returncode"] == result["controls"]["returncode"] == 0
controls = result["results"]
assert controls["executed"] == controls["passed"] == 37 and controls["failed"] == 0
assert len(controls["checks"]) == 37 and all(x["passed"] for x in controls["checks"])
assert len({x["name"] for x in controls["checks"]}) == 37
assert result["source_sha256"] == inputs
syntax = json.loads(gzip.decompress((HERE / "raw/syntax-debug/RESULT.json.gz").read_bytes()))
assert syntax["passed"] and len(syntax["files"]) == 3
for item in syntax["files"]:
    assert item["returncode"] == 0 and item["unchanged"] and item["warnings"] == 2
    assert "DEBUG" in item["command"] and "-parse" in item["command"] and "-typecheck" not in item["command"]
    assert sha(git(source, item["path"])) == item["sha256"]
assert evidence["nativeExecuted"] == 0 and evidence["actualApplicationMetrics"] == "NOT_RUN"
print(json.dumps({"status": "PASS_SOURCE_AND_RECORDED_EVIDENCE_ONLY",
                  "sourceCommit": source, "sealedFiles": len(manifest["files"]),
                  "sourceInputs": len(inputs), "controls": 37,
                  "originalNativeDeclarationsPreserved": len(old_names),
                  "nativeExecuted": 0, "actualApplicationMetrics": "NOT_RUN"}, indent=2))

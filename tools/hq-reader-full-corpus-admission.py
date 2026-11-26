#!/usr/bin/env python3
"""Controls for corpus/source admission only; never executes or accepts native UI."""
import argparse
import ast
import copy
import hashlib
import json
from pathlib import Path
import runpy
import subprocess

BASE = "29a731e273f9a757c743c49e182fece0e8047d46"
FAITHFUL = "Maktabah-iOSUITests/FaithfulReaderUIAcceptanceTests.swift"
DRIVER = "Scripts/CI/reader-full-v32-ui-observation.py"
CATALOG = "docs/hq-integration/reader-full-v32-ui-observation-20261123/FullV32ObservationCatalog.swift"

def extract(text, beginning, ending):
    return text[text.index(beginning):text.index(ending, text.index(beginning))]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--baseline-root", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    root = args.root.resolve()
    def baseline(path):
        if args.baseline_root:
            return (args.baseline_root / path).read_text()
        return subprocess.check_output(["git", "-C", str(root), "show", BASE + ":" + path], text=True)
    results = []
    def check(name, function):
        try:
            function()
            results.append({"name": name, "passed": True})
        except Exception as error:
            results.append({"name": name, "passed": False, "error": type(error).__name__ + ": " + str(error)})
    def require(value):
        assert value
    def rejects(function):
        try:
            function()
        except ValueError:
            return
        raise AssertionError("Invalid source/corpus admission was accepted")
    old, new = baseline(FAITHFUL), (root / FAITHFUL).read_text()
    preserved = {}
    def reader_body():
        start = "    @MainActor\n    func testTwentyOriginalFullV32ReaderOpensAndForcedRelaunch() throws {"
        finish = "\n    @MainActor private func fullV32Rect"
        previous = extract(old, start, finish)
        current = extract(new, "    @MainActor\n    private func observeTwentyOriginalFullCorpusReaderOpensAndForcedRelaunch(_ corpus: FullReaderObservationCorpus) throws {", finish)
        current = current.replace("private func observeTwentyOriginalFullCorpusReaderOpensAndForcedRelaunch(_ corpus: FullReaderObservationCorpus)", "func testTwentyOriginalFullV32ReaderOpensAndForcedRelaunch()")
        current = current.replace("fullV32Catalog(corpus)", "fullV32Catalog()")
        current = current.replace('fullCorpusArtifactName("full-v32-original-reader-final")', '"full-v32-original-reader-final"')
        require(previous == current)
        preserved["reader_runtime_body"] = {"sha256": hashlib.sha256(previous.encode()).hexdigest(), "bytes": len(previous.encode())}
    check("v32 Reader entire runtime body unchanged after explicit profile/artifact substitution", reader_body)
    def inspector_body():
        start = "    @MainActor\n    func testOriginalFullV32InspectorRelationshipScalesAndReturn() throws {"
        finish = "\n\n}\n// END ADDITIVE FULL-V32 ORIGINAL READER OBSERVATIONS"
        previous = extract(old, start, finish)
        current = extract(new, "    @MainActor\n    private func observeOriginalFullCorpusInspectorRelationshipScalesAndReturn(_ corpus: FullReaderObservationCorpus) throws {", finish)
        current = current.replace("private func observeOriginalFullCorpusInspectorRelationshipScalesAndReturn(_ corpus: FullReaderObservationCorpus)", "func testOriginalFullV32InspectorRelationshipScalesAndReturn()")
        current = current.replace("fullV32Catalog(corpus)", "fullV32Catalog()")
        before = '''        // v32 retains the exact original identity set. v40 is admitted against
        // its separately frozen SQL catalog; no v32 identifiers are substituted.
        let inspectorBookIDs: [Int]
        if corpus == .v32 { inspectorBookIDs = [103, 28, 3152] }
        else { inspectorBookIDs = try XCTUnwrap(catalog.inspectorBookIDs) }
        let inspectorTargets = catalog.targets.filter { inspectorBookIDs.contains($0.bookID) }'''
        current = current.replace(before, '        let inspectorTargets = catalog.targets.filter { [103, 28, 3152].contains($0.bookID) }')
        current = current.replace('fullCorpusArtifactName("full-v32-original-expanded-source-" + key + "-" + String(required))', '"full-v32-original-expanded-source-" + key + "-" + String(required)')
        require(previous == current)
        preserved["inspector_runtime_body"] = {"sha256": hashlib.sha256(previous.encode()).hexdigest(), "bytes": len(previous.encode())}
    check("v32 Inspector entire runtime body unchanged after exact default identity/artifact substitution", inspector_body)
    previous_driver, current_driver = ast.parse(baseline(DRIVER)), ast.parse((root / DRIVER).read_text())
    def function(tree, name):
        return next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == name)
    def shape(node):
        return ast.dump(node, include_attributes=False)
    check("v32 immutable installer admission function unchanged", lambda: require(shape(function(previous_driver, "admit_installation")) == shape(function(current_driver, "admit_installation"))))
    check("v32 exact catalog source unchanged", lambda: require(baseline(CATALOG) == (root / CATALOG).read_text()))
    previous_execute, current_execute = function(previous_driver, "execute"), function(current_driver, "execute")
    old_try = next(node for node in previous_execute.body if isinstance(node, ast.Try))
    new_try = next(node for node in current_execute.body if isinstance(node, ast.Try))
    def is_default(node):
        return isinstance(node, ast.If) and shape(node.test) == "Compare(left=Name(id='REUSED_INSTALLATION', ctx=Load()), ops=[Is()], comparators=[Constant(value=None)])"
    check("v32 fresh native install commands and exact admission unchanged", lambda: require(
        [shape(node) for node in old_try.body[3:7]] == [shape(node) for node in next(node for node in new_try.body if is_default(node)).body]))
    old_cleanup = next(node for node in old_try.finalbody if isinstance(node, ast.For))
    new_cleanup = next(node for node in new_try.finalbody if is_default(node)).body[0]
    check("v32 original owned simulator shutdown/delete unchanged", lambda: require(shape(old_cleanup) == shape(new_cleanup)))
    wrapper = runpy.run_path(str(root / "Scripts/CI/reader-full-v40-ui-observation.py"))
    profile = json.loads((root / "Scripts/CI/reader-full-v40-ui-observation.inputs.json").read_text())
    validate = wrapper["validate_profile"]
    check("separate finalized v40 corpus target admission", lambda: validate(profile, require_frozen=True))
    def mutated_profile(path, value):
        changed = copy.deepcopy(profile)
        target = changed
        for part in path[:-1]: target = target[part]
        target[path[-1]] = value
        rejects(lambda: validate(changed, require_frozen=True))
    for name, path, value in [
        ("v32 schema", ["schema"], "otzaria.full-v32.original-ui-observation/1"),
        ("v32 database hash", ["source_database", "databaseSHA256"], "2f4dcd72e8bdb1fc5c0516ae9705e57759c017ec2981b49c35115625c3d3f765"),
        ("v32 counts", ["source_database", "counts", "line"], 7080797),
        ("wrong release", ["source_database", "releaseID"], 409213893),
        ("wrong selected case", ["selected_case_ids", 0], "FaithfulProductionReleaseTests/testTwentyOriginalFullV32ReaderOpensAndForcedRelaunch"),
        ("unowned installation policy", ["installation_policy"], "LATEST"),
        ("unknown book id", ["catalog_targets", "books", 0, "bookID"], 999999),
        ("wrong complete book count", ["catalog_targets", "books", 0, "lineCount"], 10),
        ("unfinalized title", ["catalog_targets", "books", 0, "title"], "UNFINALIZED"),
        ("v32 stress book", ["catalog_targets", "retainedChapter", "bookID"], 5869),
        ("wrong stress row count", ["catalog_targets", "retainedChapter", "unitRowCount"], 110196),
        ("wrong source length", ["catalog_targets", "retainedChapter", "sourceUTF16Length"], 1),
        ("unfinalized unit", ["catalog_targets", "retainedChapter", "unitID"], "UNFINALIZED"),
        ("negative focus", ["catalog_targets", "retainedChapter", "focusLineIndex"], -1),
    ]:
        check("reject " + name, lambda path=path, value=value: mutated_profile(path, value))
    source = wrapper["SOURCE"]
    fixture = {key: source[key] for key in ("releaseID", "releaseTag", "assetID", "assetName")}
    fixture.update(passed=True, phase="install", profileID="production", quickCheck="ok",
        actualSHA256=source["assetSHA256"], expectedSHA256=source["assetSHA256"],
        expectedCompressedBytes=source["assetBytes"], extractedBytes=source["databaseBytes"],
        bookCount=source["counts"]["book"], lineCount=source["counts"]["line"])
    native = wrapper["validate_native_installation"]
    check("synthetic native-report control with exact independent v40 pins", lambda: native(fixture))
    for key, value in [("passed", False), ("phase", "restore"), ("assetName", "seforim-schema7.db.zst"),
        ("actualSHA256", "0" * 64), ("expectedSHA256", "1" * 64), ("extractedBytes", 1), ("bookCount", 10), ("lineCount", 7080797)]:
        check("reject synthetic native report " + key, lambda key=key, value=value: rejects(lambda: native({**fixture, key: value})))
    udid, container_id = "12345678-1234-1234-1234-123456789ABC", "87654321-4321-4321-4321-CBA987654321"
    path = "/Users/control/Library/Developer/CoreSimulator/Devices/" + udid + "/data/Containers/Data/Application/" + container_id + "/Library/Application Support/Otzaria/seforim.db"
    relocation = wrapper["relocated_database"]
    check("same-device container relocation retains exact relative corpus path", lambda: require(relocation(path, udid, Path("/control/current-container"))[0] == Path("/control/current-container/Library/Application Support/Otzaria/seforim.db")))
    check("reject another simulator's prior database", lambda: rejects(lambda: relocation(path, "AAAAAAAA-1234-1234-1234-123456789ABC", Path("/control/current-container"))))
    check("reject escaping prior database path", lambda: rejects(lambda: relocation(path.replace("/Library/", "/../Library/", 1), udid, Path("/control/current-container"))))
    result = {"status": "SOURCE_ADMISSION_CONTROLS_ONLY", "baseline_source": BASE,
        "passed": sum(row["passed"] for row in results), "failed": sum(not row["passed"] for row in results),
        "controls": results, "preserved_v32_runtime_bodies": preserved,
        "native_ui_executed": 0, "current_corpus_installed": False, "performance_acceptance": False,
        "native_report_fixtures_are_synthetic_controls_only": True}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2) + "\n")
    print(json.dumps({key: result[key] for key in ("status", "passed", "failed", "native_ui_executed")}))
    return 1 if result["failed"] else 0

if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Read-only packet/source verification; does not run Swift, app, or CI."""
from pathlib import Path
import ast
import gzip
import hashlib
import io
import json
import zipfile

DOCS = Path(__file__).resolve().parent
ROOT = DOCS.parents[2]


def require(value, message):
    if not value: raise ValueError(message)


def pin(data):
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(),
            "git_blob": hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()}


def read(path):
    return json.loads(path.read_bytes())


def functions(data):
    text = data.decode(); lines = text.splitlines(keepends=True)
    return {node.name: "".join(lines[node.lineno - 1:node.end_lineno]).encode()
            for node in ast.parse(text).body if isinstance(node, ast.FunctionDef)}


def main():
    authority = read(DOCS / "SOURCE_AUTHORITY.json")
    artifacts = read(DOCS / "ARTIFACTS.json")
    files = artifacts["files"]
    require(len(files) == len({row["path"] for row in files}), "Duplicate sealed path")
    for row in files:
        path = ROOT / row["path"]
        require(path.is_file() and not path.is_symlink(), "Missing/linked sealed file")
        require(pin(path.read_bytes()) == {key: row[key] for key in ("bytes", "sha256", "git_blob")}, "Sealed bytes differ: " + row["path"])
    tree = json.loads(gzip.decompress((DOCS / "raw/BASE_GIT_TREE.json.gz").read_bytes()))
    require(tree["sha"] == authority["tree"] and tree["truncated"] is False, "Wrong base Git tree")
    entries = {row["path"]: row for row in tree["tree"]}
    require(len(entries) == len(tree["tree"]), "Duplicate Git tree path")
    directories = {"": tree["sha"], **{p: r["sha"] for p, r in entries.items() if r["type"] == "tree"}}
    for parent, expected in directories.items():
        children = []
        for path, row in entries.items():
            if path.rpartition("/")[0] == parent:
                name = path.rsplit("/", 1)[-1]
                order = name.encode() + (b"/" if row["type"] == "tree" else b"")
                mode = "40000" if row["mode"] == "040000" else row["mode"]
                children.append((order, mode.encode() + b" " + name.encode() + b"\0" + bytes.fromhex(row["sha"])))
        payload = b"".join(row for _, row in sorted(children))
        actual = hashlib.sha1(b"tree " + str(len(payload)).encode() + b"\0" + payload).hexdigest()
        require(actual == expected, "Git tree Merkle identity differs: " + parent)
    raw = (DOCS / "raw/M_SOURCE_INPUTS.zip").read_bytes()
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        require(archive.testzip() is None and set(archive.namelist()) == set(authority["base_inputs"]), "Base input ZIP differs")
        for path, expected in authority["base_inputs"].items():
            data = archive.read(path)
            require(pin(data) == {key: expected[key] for key in ("bytes", "sha256", "git_blob")}
                    and expected["git_blob"] == entries[path]["sha"] and expected["mode"] == entries[path]["mode"], "Base source changed")
    wrapper = "Scripts/CI/annotation-combined-core194-apple.py"
    original = "Scripts/CI/annotation-disconnect-apple.py"
    actual_functions, original_functions = functions((ROOT / wrapper).read_bytes()), functions((ROOT / original).read_bytes())
    proof = read(DOCS / "ORIGINAL_VALIDATOR_BODY_PROOF.json")
    for name, expected in proof["functions"].items():
        require(actual_functions[name] == original_functions[name]
                and hashlib.sha256(actual_functions[name]).hexdigest() == expected["sha256"], "Original validator body differs")
    binding = read(ROOT / "Scripts/CI/annotation-combined-core194-apple.inputs.json")
    require(binding["application_source"] == authority["commit"] and binding["application_tree"] == authority["tree"]
            and binding["source_sealed"] is True, "Unfinalized source")
    for path, expected in binding["source_pins"].items():
        if (ROOT / path).is_file():
            data = (ROOT / path).read_bytes()
        else:
            with zipfile.ZipFile(io.BytesIO(raw)) as archive: data = archive.read(path)
        require(pin(data) == expected, "Execution source pin differs: " + path)
    observed = read(DOCS / "PREPARATION_RESULTS.json")
    require(observed["new_controls"]["final"] == {"executed": 40, "passed": 40, "failures": 0, "errors": 0, "skips": 0}
            and observed["Swift_executed"] == 0 and observed["Native_executed"] == 0, "Preparation scope changed")
    require(authority["protected_application_trees"] == binding["application_trees"], "Protected source trees differ")
    print(json.dumps({"status": "PASS_READONLY_SEALED_SOURCE_AND_RECEIPTS", "sealed_files": len(files),
                      "base_inputs": len(authority["base_inputs"]), "Git_tree_nodes": len(entries),
                      "original_validator_functions": len(proof["functions"]), "source_pins": len(binding["source_pins"]),
                      "Swift_executed": 0, "Native_executed": 0}, sort_keys=True))


if __name__ == "__main__": main()

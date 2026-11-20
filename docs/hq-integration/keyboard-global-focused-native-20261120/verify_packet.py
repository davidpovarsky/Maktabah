#!/usr/bin/env python3
"""Read-only packet/whole-source inverse, without Swift or Simulator execution."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import zipfile


def sha(data):
    return hashlib.sha256(data).hexdigest()


def blob(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--run-python-controls", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()
    docs = root / "docs/hq-integration/keyboard-global-focused-native-20261120"
    manifest = json.loads((docs / "ARTIFACTS.json").read_bytes())
    for row in manifest["files"]:
        data = (root / row["path"]).read_bytes()
        assert len(data) == row["bytes"] and sha(data) == row["sha256"] and blob(data) == row["git_blob"], row["path"]
    inputs = json.loads((docs / "CANONICAL_BASE_INPUTS.json").read_bytes())
    records = {row["path"]: row for row in inputs["files"]}
    binding = json.loads((docs / "SOURCE_BINDING.json").read_bytes())
    assert binding["source_sealed"] is True and binding["source_commit"] == inputs["source"]
    assert binding["source_tree"] == inputs["tree"]
    with tempfile.TemporaryDirectory(prefix="keyboard-global-source-") as temporary:
        base = Path(temporary)
        with zipfile.ZipFile(docs / "BASE_INPUTS.zip") as archive:
            names = archive.namelist()
            assert set(names) == set(records) and len(names) == len(set(names)) == 14
            assert archive.testzip() is None
            for name in names:
                path = Path(name)
                assert not path.is_absolute() and ".." not in path.parts
                data = archive.read(name)
                row = records[name]
                assert len(data) == row["bytes"] and sha(data) == row["sha256"] and blob(data) == row["git_blob"]
                destination = base / name
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(data)
        runtime = root / "Scripts/CI/runtime27.py"
        edit = json.loads((docs / "RUNTIME_EXACT_EDIT.json").read_bytes())
        inverse = runtime.read_text()
        for row in reversed(edit["replacements"]):
            assert inverse.count(row["after"]) == 1
            inverse = inverse.replace(row["after"], row["before"], 1)
        assert inverse.count(edit["new_r27_pin"]) == 1
        inverse = inverse.replace(edit["new_r27_pin"], edit["old_r27_pin"], 1)
        assert inverse.encode() == (base / "Scripts/CI/runtime27.py").read_bytes()
        old_manifest = json.loads((base / "docs/hq-integration/runtime27/R27_CASES.json").read_bytes())
        rows = old_manifest["cases"] + old_manifest["supplemental_cases"]
        assert len(rows) == 116
        selected = {}
        for name, count in (("ipad11", 4), ("ipad13", 2)):
            current = json.loads((root / f"docs/hq-integration/runtime27/keyboard-global-{name}.json").read_bytes())
            all_rows = current["cases"] + current["supplemental_cases"]
            assert all_rows[:116] == rows and len(all_rows) == 120
            selected[name] = current["execution_case_ids"]
            assert len(selected[name]) == len(set(selected[name])) == count
        assert selected["ipad13"] == selected["ipad11"][2:]
        python_result = "NOT_RERUN_BY_PACKET_VERIFIER"
        if args.run_python_controls:
            command = ["python3", str(root / "Scripts/CI/test-keyboard-global-focused-native.py"), "--base-dir", str(base)]
            result = subprocess.run(command, text=True, capture_output=True, timeout=60)
            print(result.stdout + result.stderr)
            assert result.returncode == 0 and "Ran 36 tests" in result.stderr and result.stderr.rstrip().endswith("OK")
            python_result = "36_PASS_PYTHON_ONLY"
    print(json.dumps({"status": "PASS_PACKET_SOURCE_INVERSE_ONLY", "manifested_files": len(manifest["files"]),
                      "canonical_base_inputs": 14, "original_native_rows_preserved": 116,
                      "independent_configurations": {"ipad11": 4, "ipad13": 2}, "runtime_body_inverse_exact": True,
                      "python_controls": python_result, "swift_compilation": "NOT_RUN", "native_executions": 0}, indent=2))


if __name__ == "__main__":
    main()

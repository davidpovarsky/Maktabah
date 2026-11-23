#!/usr/bin/env python3
"""Synthetic filesystem-boundary controls only; no Simulator or native results."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(sys.argv[1]).resolve()
helper = root / "Scripts/CI/native-cohort-artifacts.py"
spec = importlib.util.spec_from_file_location("cohort_output", helper)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
actual_head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
rows = []
def context(path):
    return {"schema": module.SCHEMA, "checkout_sha": actual_head, "run_id": "1",
            "run_attempt": "1", "repository_root": str(path)}
def rejected(operation):
    try:
        operation()
    except (ValueError, OSError):
        return
    raise AssertionError("Unsafe selection was accepted")
def case(name, operation):
    with tempfile.TemporaryDirectory(prefix="owned-cohort-control-") as temporary:
        path = Path(temporary).resolve()
        operation(path, context(path))
    rows.append({"case": name, "result": "PASS"})

def isolation(path, identity):
    first = module.select(path, identity, "groups100")
    group = Path(first["artifact_directory"]) / "preserved-control.txt"
    group.write_bytes(b"original synthetic Group control bytes\n")
    second = module.select(path, identity, "library7")
    library = Path(second["artifact_directory"]) / "preserved-control.txt"
    library.write_bytes(b"independent synthetic Library control bytes\n")
    module.select(path, identity, "full-v32")
    module.select(path, identity, "shared-build")
    module.select(path, identity, "groups100")
    assert (path / "build/artifacts/preserved-control.txt").read_bytes() == group.read_bytes()
    assert group.read_bytes() != library.read_bytes()
    assert library.read_bytes() == b"independent synthetic Library control bytes\n"
    assert len(list((path / "build/native-cohorts/selections").glob("*.json"))) == 5
case("all_four_cohorts_switch_without_overwriting_prior_bytes", isolation)

def foreign_owner(path, identity):
    first = module.select(path, identity, "groups100")
    rejected(lambda: module.select(path, identity | {"run_attempt": "2"}, "library7"))
    assert (path / "build/artifacts").resolve() == Path(first["artifact_directory"])
case("different_attempt_owner_rejected", foreign_owner)

def unowned(path, identity):
    artifacts = path / "build/artifacts";artifacts.mkdir(parents=True)
    witness = artifacts / "unowned.txt";witness.write_bytes(b"must remain\n")
    rejected(lambda: module.select(path, identity, "groups100"))
    assert witness.read_bytes() == b"must remain\n" and not artifacts.is_symlink()
case("preexisting_unowned_artifacts_preserved_and_rejected", unowned)

def escaped_alias(path, identity):
    module.select(path, identity, "groups100")
    outside = path / "foreign";outside.mkdir()
    (path / "build/artifacts").unlink()
    (path / "build/artifacts").symlink_to(outside, target_is_directory=True)
    rejected(lambda: module.select(path, identity, "library7"))
    assert (path / "build/artifacts").resolve() == outside
case("alias_outside_owned_cohorts_rejected", escaped_alias)

def escaped_target(path, identity):
    module.select(path, identity, "groups100")
    outside = path / "foreign";outside.mkdir()
    (path / "build/native-cohorts/library7").symlink_to(outside, target_is_directory=True)
    rejected(lambda: module.select(path, identity, "library7"))
    assert list(outside.iterdir()) == []
case("symlinked_cohort_directory_rejected", escaped_target)

def escaped_build(path, identity):
    outside = path / "foreign";outside.mkdir()
    (path / "build").symlink_to(outside, target_is_directory=True)
    rejected(lambda: module.select(path, identity, "groups100"))
    assert list(outside.iterdir()) == []
case("symlinked_build_directory_rejected", escaped_build)

previous = os.environ.get("EXPECTED_CHECKOUT_SHA")
os.environ["EXPECTED_CHECKOUT_SHA"] = "0" * 40
try:
    rejected(module.current_identity)
finally:
    if previous is None:
        del os.environ["EXPECTED_CHECKOUT_SHA"]
    else:
        os.environ["EXPECTED_CHECKOUT_SHA"] = previous
rows.append({"case": "wrong_actual_git_checkout_rejected_before_actions_identity", "result": "PASS"})
print(json.dumps({"scope": "Seven synthetic output-ownership controls only; no Actions/native acceptance",
                  "helper_sha256": hashlib.sha256(helper.read_bytes()).hexdigest(),
                  "control_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                  "actual_source_head_at_execution": actual_head, "cases": rows}, indent=2))

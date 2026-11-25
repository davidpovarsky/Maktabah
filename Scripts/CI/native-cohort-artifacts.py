#!/usr/bin/env python3
"""Select owned ignored artifact directories without changing native drivers."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[2]
COHORTS = ("shared-build", "groups100", "library7", "full-v32")
SCHEMA = "otzaria.native-cohort-artifacts/1"

def require(value, message):
    if not value:
        raise ValueError(message)

def directory(path, create=False):
    if os.path.lexists(path):
        require(stat.S_ISDIR(path.lstat().st_mode), "Not a real owned directory: " + str(path))
    elif create:
        path.mkdir()
    else:
        raise ValueError("Missing owned directory: " + str(path))
    require(path.resolve(strict=True) == path, "Directory escapes its lexical owner: " + str(path))

def read_marker(path):
    require(stat.S_ISREG(path.lstat().st_mode), "Ownership marker is not regular")
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    with os.fdopen(descriptor, "rb") as stream:
        data = stream.read(8193)
    require(len(data) <= 8192, "Ownership marker exceeds its bound")
    return json.loads(data)

def new_json(path, value):
    data = (json.dumps(value, sort_keys=True, indent=2) + "\n").encode()
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(descriptor, "wb") as stream:
        stream.write(data)

def current_identity():
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, timeout=90).decode().strip()
    require(head == os.environ["EXPECTED_CHECKOUT_SHA"], "Wrong immutable checkout")
    run_id, attempt = os.environ["GITHUB_RUN_ID"], os.environ["GITHUB_RUN_ATTEMPT"]
    require(run_id.isdecimal() and int(run_id) > 0, "Missing actual Actions run ID")
    require(attempt.isdecimal() and int(attempt) > 0, "Missing actual Actions attempt")
    return {"schema": SCHEMA, "checkout_sha": head, "run_id": run_id,
            "run_attempt": attempt, "repository_root": str(ROOT)}

def select(root, identity, cohort):
    require(cohort in COHORTS, "Unknown cohort")
    root = Path(root).resolve(strict=True)
    require(identity["schema"] == SCHEMA and identity["repository_root"] == str(root),
            "Ownership identity does not bind this repository")
    build = root / "build"
    directory(build, create=True)
    alias = build / "artifacts"
    # An existing ordinary artifacts directory may belong to another operation.
    # Never move, merge, delete or replace it to make this switch succeed.
    if os.path.lexists(alias):
        require(stat.S_ISLNK(alias.lstat().st_mode), "Existing unowned artifacts directory")
    owner = build / "native-cohorts"
    if not os.path.lexists(owner):
        directory(owner, create=True)
        new_json(owner / "owner.json", identity)
    else:
        directory(owner)
        require(read_marker(owner / "owner.json") == identity, "Cohort ownership mismatch")
    allowed = {owner / name / "artifacts" for name in COHORTS}
    previous = None
    if os.path.lexists(alias):
        previous = alias.resolve(strict=True)
        require(previous in allowed, "Artifacts link escapes owned cohorts")
        directory(previous.parent)
        directory(previous)
    cohort_dir = owner / cohort
    directory(cohort_dir, create=True)
    target = cohort_dir / "artifacts"
    directory(target, create=True)
    ledger = owner / "selections"
    directory(ledger, create=True)
    temporary = build / (".artifacts-switch-" + uuid.uuid4().hex)
    try:
        os.symlink(os.path.relpath(target, build), temporary)
        # Refuse a changed or newly occupied alias; no prior cohort data is moved.
        if previous is None:
            require(not os.path.lexists(alias), "Artifacts alias appeared during selection")
        else:
            require(alias.is_symlink() and alias.resolve(strict=True) == previous,
                    "Artifacts alias changed during selection")
        os.replace(temporary, alias)
    finally:
        if os.path.lexists(temporary):
            temporary.unlink()
    require(alias.resolve(strict=True) == target, "Selected artifact directory mismatch")
    receipt = {"ownership": identity, "cohort": cohort, "artifact_directory": str(target),
               "canonical_alias": str(alias), "previous_artifact_directory": str(previous) if previous else None,
               "selected_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
               "helper_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
               "data_moved_or_deleted": False}
    new_json(ledger / (uuid.uuid4().hex + ".json"), receipt)
    return receipt

if __name__ == "__main__":
    require(len(sys.argv) == 2, "Expected exactly one cohort name")
    print(json.dumps(select(ROOT, current_identity(), sys.argv[1]), indent=2))

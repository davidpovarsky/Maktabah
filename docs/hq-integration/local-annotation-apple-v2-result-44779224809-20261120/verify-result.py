#!/usr/bin/env python3
"""Offline authentication and optional ORIGINAL result replay; never invokes Swift.

The replay reconstructs only an absent original runner checkout path because the
frozen validators intentionally require literal owned-fixture paths. It never
rewrites a receipt or patches the validator. The copied checkout is removed only
when its exclusive ownership marker still matches this invocation.
"""
import argparse
import datetime
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import sys
import tarfile
import traceback
import uuid
import zipfile

RUN = 44779224809
HEAD = "421944748f0638b651f771333ab97b620546773b"
TREE = "491ad8335df97a81066762e4581719b733fa11c2"
CORE = "5d0ee482c8f10726fe3863792dac94c18e94d792"
ARTIFACT = 14650449336
ZIP_SHA = "45b61198f542499ca2eb41db374e66089d235d9ba0c10b9befccda5933d53e96"
BRANCH = "codex/otzaria-local-annotation-editor-apple-reviewed-v2-20261120"
ROOT = Path("/Users/runner/work/Maktabah/Maktabah")
ROUTE = "local-annotation-editor-route"
OUTPUTS = {ROUTE, "local-annotation-editor-acceptance", "local-annotation-editor-exchange-regression"}


def require(value, message):
    if not value:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def blob(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes((json.dumps(value, indent=2, ensure_ascii=False, sort_keys=True) + "\n").encode())


def relative(name):
    require(isinstance(name, str) and name == str(PurePosixPath(name))
            and not name.startswith("/") and "\\" not in name
            and all(x not in ("", ".", "..") for x in name.split("/")), "Unsafe archive path")
    return name


def archive_files(data):
    result = {}
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as archive:
        for row in archive.getmembers():
            name = relative(row.name)
            require(row.isfile() and name not in result, "Nonregular/duplicate source member")
            result[name] = archive.extractfile(row).read()
    return result


def inventory(root):
    return {p.relative_to(root).as_posix(): {"bytes": p.stat().st_size, "sha256": sha(p.read_bytes())}
            for p in sorted(root.rglob("*")) if p.is_file()}


def verify(input_root):
    zbytes = (input_root / "artifact.zip").read_bytes()
    require(len(zbytes) == 1031439 and sha(zbytes) == ZIP_SHA, "Authentic full ZIP digest/size mismatch")
    artifact = load(input_root / "ARTIFACT.json")
    run = load(input_root / "RUN.json")
    jobs = load(input_root / "JOBS.json")
    api = input_root / "independent-api"
    fresh_run, commit = load(api / "run.json"), load(api / "commit.json")
    fresh_artifacts, fresh_jobs = load(api / "artifacts.json")["artifacts"], load(api / "jobs.json")["jobs"]
    require(len(fresh_artifacts) == len(fresh_jobs) == 1, "Ambiguous artifact/job API result")
    # The purpose-built connector omits only REST's GraphQL node_id field.
    require(fresh_artifacts[0] == {k: v for k, v in artifact.items() if k != "node_id"},
            "Fresh artifact metadata differs beyond the connector's node_id projection")
    for observed in (run, fresh_run):
        require(observed["id"] == RUN and observed["run_attempt"] == 1
                and observed["head_sha"] == HEAD and observed["head_branch"] == BRANCH
                and observed["event"] == "push" and observed["status"] == "completed"
                and observed["conclusion"] == "success"
                and observed["repository"]["id"] == observed["head_repository"]["id"] == 1280062128
                and observed["repository"]["full_name"] == observed["head_repository"]["full_name"] == "davidpovarsky/Maktabah",
                "Wrong actual source/run/repository result")
    require(commit["sha"] == HEAD and commit["tree"]["sha"] == TREE, "Frozen commit/tree mismatch")
    require(artifact["id"] == ARTIFACT and artifact["size_in_bytes"] == len(zbytes)
            and artifact["digest"] == "sha256:" + ZIP_SHA and artifact["expired"] is False
            and artifact["workflow_run"] == {"id": RUN, "repository_id": 1280062128,
                "head_repository_id": 1280062128, "head_branch": BRANCH, "head_sha": HEAD}, "Wrong artifact producer")
    require(jobs["total_count"] == len(jobs["jobs"]) == 1, "Wrong actual job count")
    job = jobs["jobs"][0]
    require(job["id"] == fresh_jobs[0]["id"] == 136437128170
            and job["status"] == fresh_jobs[0]["status"] == "completed"
            and job["conclusion"] == fresh_jobs[0]["conclusion"] == "success", "Job not successful")
    for step in job["steps"]:
        require(step["status"] == "completed" and step["conclusion"] == "success", "Incomplete workflow step")
    require(job["started_at"] <= artifact["created_at"] <= job["completed_at"], "Upload outside successful job interval")
    ancestry = load(api / "ancestry.json")
    require(ancestry["status"] == "ahead" and ancestry["behind_by"] == 0
            and ancestry["base_commit"]["sha"] == "1bde04bfbabbf1b1df714668785b580c9141a3b8"
            and [x["sha"] for x in ancestry["commits"]] == [
                "5b0f8ef7875a373918d1e2e32f45651e1a15a11f", "19db1fa70516a3918509a94c75bfc31d379687a1", HEAD],
            "First failure/correction ancestry changed")
    payloads = {}
    with zipfile.ZipFile(io.BytesIO(zbytes)) as archive:
        require(len(archive.infolist()) == 228 and archive.testzip() is None, "ZIP CRC/inventory failure")
        for row in archive.infolist():
            name = relative(row.filename)
            require(not row.is_dir() and name not in payloads
                    and not stat.S_ISLNK(row.external_attr >> 16)
                    and name.split("/")[0] in OUTPUTS, "Unsafe/duplicate ZIP member")
            payloads[name] = archive.read(row)
    raw = input_root / "raw"
    if raw.exists():
        require(inventory(raw) == {name: {"bytes": len(data), "sha256": sha(data)} for name, data in payloads.items()},
                "Retained extracted files differ from authentic ZIP")
    before = json.loads(payloads[ROUTE + "/before.json"])
    after = json.loads(payloads[ROUTE + "/after.json"])
    require(before["source"] == after["source"], "Source before/after changed")
    observed = before["source"]
    require(observed["identity"]["head_sha"] == HEAD and observed["identity"]["run_id"] == RUN
            and observed["identity"]["run_attempt"] == 1 and observed["core_tree_sha"] == CORE,
            "Original driver source/whole Core provenance differs")
    require(after["status"] == "PASS_APPLE_FOUNDATION_LOCAL43_COLD2_EXCHANGE28_CRASH2"
            and after["workflow_step_outcomes"] == {"toolchain": "success", "local": "success", "exchange": "success"},
            "Original strict after gate did not pass")
    for key in ("anytype_runtime_executed", "app_relaunch_executed", "cloudkit_transport_executed", "native_ui_executed", "physical_device_executed"):
        require(type(after[key]) is int and after[key] == 0, "Scope widened")
    require(after["live_exchange_enabled"] is False, "Live exchange unexpectedly enabled")
    snapshots = []
    for receipt in (before, after):
        seal = receipt["raw_source_archive"]
        data = payloads[ROUTE + "/" + seal["file"]]
        require(len(data) == seal["bytes"] and sha(data) == seal["sha256"] and seal["members"] == 85,
                "Raw source archive seal mismatch")
        snapshots.append(archive_files(data))
    require(snapshots[0] == snapshots[1] and len(snapshots[0]) == 85, "Raw original source changed")
    sources = snapshots[0]
    proof = load(input_root / "SOURCE_GIT_PROOF.json")
    require(proof["commit"] == HEAD and proof["tree"] == TREE and len(proof["files"]) == 85, "Wrong canonical Git proof")
    rows = {x["path"]: x for x in proof["files"]}
    require(set(rows) == set(sources) == set(observed["files"]), "Canonical Git/source closure differs")
    for name, data in sources.items():
        require(rows[name]["type"] == "blob" and rows[name]["size"] == len(data)
                and rows[name]["sha"] == blob(data)
                and observed["files"][name] == {"bytes": len(data), "sha256": sha(data), "git_blob": blob(data)},
                "Canonical source byte mismatch: " + name)
    core_tree = load(api / "core_tree.json")
    require(core_tree["sha"] == CORE and core_tree["truncated"] is False, "Incomplete Core tree")
    core_rows = {"Source/Otzaria/Actions/" + x["path"]: x for x in core_tree["tree"] if x["type"] == "blob"}
    require(len(core_rows) == 53 and set(core_rows) == {n for n in sources if n.startswith("Source/Otzaria/Actions/")},
            "Whole original Core closure differs")
    require(all(blob(sources[n]) == row["sha"] and len(sources[n]) == row["size"] for n, row in core_rows.items()),
            "Whole Core original bytes differ")
    controls = json.loads(payloads[ROUTE + "/python-controls/RESULT.json"])
    require(controls["tests"] == 32 and controls["status"] == "PASS"
            and controls["failures"] == controls["errors"] == controls["skipped"] == 0
            and controls["source_before"] == controls["source_after"], "Actual Mac Python controls incomplete")
    warnings = {}
    for label in ("local-annotation-editor-acceptance", "local-annotation-editor-exchange-regression"):
        log = payloads[label + "/compile.log"].decode()
        log = re.sub(r"\x1b\]8;[^\x1b]*\x1b\\", "", log)
        log = re.sub(r"\x1b\[[0-9;]*m", "", log)
        require(not re.search(r"\berror:", log), "Actual compiler emitted error")
        warnings[label] = list(dict.fromkeys(line for line in log.splitlines() if re.match(r"/.*:\d+:\d+: warning:", line)))
    return sources, payloads, before, after, {"run": RUN, "head": HEAD, "tree": TREE,
        "artifact_id": ARTIFACT, "artifact_sha256": ZIP_SHA, "zip_crc_members": 228,
        "source_before_after_files": 85, "whole_original_core_files": 53, "whole_original_core_tree": CORE,
        "mac_python_controls": 32, "compiler_warnings": warnings,
        "first_failure_preserved_ancestor": ancestry["base_commit"]["sha"],
        "scope": "Actual Apple Foundation component/cold SQLite processes; no Native UI/Anytype mount/live CloudKit/physical execution"}


def replay(input_root, sources, payloads, before, after):
    require(not ROOT.exists() and not ROOT.is_symlink(), "Replay root already exists; no overwrite allowed")
    for parent in ROOT.parents:
        require(not parent.is_symlink(), "Linked replay ancestor")
    original_raw_inventory = inventory(input_root / "raw") if (input_root / "raw").exists() else None
    token = str(uuid.uuid4())
    ROOT.parent.mkdir(parents=True, exist_ok=True)
    ROOT.mkdir(exist_ok=False)
    marker = ROOT / "REPLAY_OWNERSHIP.json"
    write(marker, {"token": token, "run": RUN, "purpose": "Original Python validator only; no Swift/compiler"})
    old_developer_dir = os.environ.get("DEVELOPER_DIR")
    old_bytecode = sys.dont_write_bytecode
    try:
        for name, data in {**sources, **{"build/" + n: b for n, b in payloads.items()}}.items():
            dest = ROOT / relative(name)
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(data)
        copied_before = inventory(ROOT)
        selection = json.loads(payloads[ROUTE + "/toolchain.json"])["selected"]["developer_dir"]
        os.environ["DEVELOPER_DIR"] = selection  # literal receipt comparison, never executed
        sys.dont_write_bytecode = True
        spec = importlib.util.spec_from_file_location("frozen_local43_result_validator", ROOT / "Scripts/CI/local-annotation-editor-apple.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        verified = module.verify_results(ROOT, before["source"], after["workflow_step_outcomes"])
        require(verified == after["verified"], "Original verifier replay differs from actual Apple gate")
        copied_after = inventory(ROOT)
        changed = [n for n in sorted(set(copied_before) | set(copied_after)) if copied_before.get(n) != copied_after.get(n)]
        require(all(not n.startswith(("Source/", "Scripts/", "Tests/", "tools/", "Maktabah.xcodeproj/", ".github/")) for n in changed),
                "Replay modified original source")
        if original_raw_inventory is not None:
            require(original_raw_inventory == inventory(input_root / "raw"), "Replay changed retained authentic raw evidence")
        return {"status": "PASS_ORIGINAL_FROZEN_VERIFIER_REPLAY", "verified": verified,
                "verified_equals_actual_after_output": True, "literal_fixture_paths_unchanged": True,
                "replay_root_was_absent": True, "replay_owned_copy_changes": changed,
                "authentic_raw_evidence_unchanged": True, "original_source_unchanged": True,
                "developer_dir_is_receipt_comparison_only": selection,
                "swift_compiler_processes_started": 0, "native_processes_started": 0,
                "original_sqlite_validator_used_mode_ro": True}
    finally:
        sys.dont_write_bytecode = old_bytecode
        if old_developer_dir is None:
            os.environ.pop("DEVELOPER_DIR", None)
        else:
            os.environ["DEVELOPER_DIR"] = old_developer_dir
        require(marker.is_file() and load(marker).get("token") == token, "Replay ownership lost; refusing cleanup")
        shutil.rmtree(ROOT)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--replay", action="store_true")
    args = parser.parse_args()
    require(not args.output.exists(), "Refusing to overwrite a prior verifier receipt")
    result = {"observed_at": datetime.datetime.now(datetime.timezone.utc).isoformat(), "status": "FAILED", "swift_rerun": False}
    try:
        sources, payloads, before, after, authenticated = verify(args.input_root)
        result["authentication"] = authenticated
        if args.replay:
            result["original_validator_replay"] = replay(args.input_root, sources, payloads, before, after)
            result["owned_replay_root_removed"] = not ROOT.exists()
        result["status"] = "PASS_AUTHENTIC_APPLE_RESULT" + ("_AND_ORIGINAL_REPLAY" if args.replay else "")
    except Exception as error:
        result["error"] = str(error)
        result["traceback"] = traceback.format_exc()
        write(args.output, result)
        raise
    write(args.output, result)
    print(json.dumps({"status": result["status"], "source_files": 85, "local": 43, "exchange": 28,
                      "cold_reopens": 2, "crash_reopens": 2, "swift_rerun": False}))


if __name__ == "__main__":
    main()

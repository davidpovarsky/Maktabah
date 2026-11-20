#!/usr/bin/env python3
"""Read-only verification of the retained Apple v4 packet and narrow proposal.

This never launches Swift, a retained executable, a workflow, or a product.
It does not replace the unchanged original validators whose scoped replay is
retained separately. In particular it does not invent missing directories or
the two Apple binaries omitted by upload-artifact.
"""
from __future__ import annotations

import argparse
import gzip
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import stat
import tarfile
import zipfile

RUN = 44808496839
JOB = 136538641362
ARTIFACT = 14664188280
F = "5bf1ddfc4a4b04dede8e8bdcaecabf3a7a5dddcd"
M = "c1e0d33117154d578206195ef021d41fc2fa2b12"
BASE = "1146a249fdd94c345371c67a8d763f16223017ee"
ZIP_SHA = "cd309d6806f1b0591b017564cbb807531114bf0564c7db63991a006f6a0f68fb"


def require(value, message):
    if not value:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def blob(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def canonical(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n").encode()


def safe(name):
    path = PurePosixPath(name)
    require(name == str(path) and bool(path.parts) and not path.is_absolute()
            and ".." not in path.parts and "\\" not in name, "noncanonical path")
    return path


def load(path):
    data = path.read_bytes()
    return json.loads(gzip.decompress(data) if path.suffix == ".gz" else data)


def api(path):
    value = load(path)
    return json.loads(value["structuredContent"]["content"])


def merkle(entries):
    trie = {}
    for path, item in entries.items():
        target = trie
        parts = safe(path).parts
        for part in parts[:-1]:
            target = target.setdefault(part, {})
        require(parts[-1] not in target, "duplicate leaf")
        target[parts[-1]] = (item["mode"], item["sha"])
    subtrees = {}

    def node(value, prefix=""):
        rows = []
        for name, child in value.items():
            if isinstance(child, dict):
                digest = node(child, prefix + name + "/")
                subtrees[prefix + name] = digest
                rows.append((name, "40000", digest, True))
            else:
                rows.append((name, child[0].lstrip("0"), child[1], False))
        rows.sort(key=lambda row: (row[0] + ("/" if row[3] else "")).encode())
        data = b"".join(mode.encode() + b" " + name.encode() + b"\0" + bytes.fromhex(digest)
                        for name, mode, digest, _ in rows)
        return hashlib.sha1(b"tree " + str(len(data)).encode() + b"\0" + data).hexdigest()

    return node(trie), subtrees


def tree_from(path, expected):
    value = api(path)
    require(value["sha"] == expected and value["truncated"] is False, "wrong/incomplete Git tree")
    require(len({row["path"] for row in value["tree"]}) == len(value["tree"]), "duplicate Git path")
    leaves = {row["path"]: row for row in value["tree"] if row["type"] != "tree"}
    digest, subtrees = merkle(leaves)
    require(digest == expected, "Git Merkle root mismatch")
    return leaves, subtrees


def verify(here, source_root):
    manifest_path = here / "ARTIFACTS.json"
    manifest = load(manifest_path)
    require(manifest_path.read_bytes() == canonical(manifest), "noncanonical manifest")
    rows = manifest["files"]
    require(len({row["path"] for row in rows}) == len(rows), "duplicate manifest member")
    expected = {row["path"] for row in rows}
    actual = {str(path.relative_to(here)) for path in here.rglob("*") if path.is_file()}
    require(actual == expected | {"ARTIFACTS.json"}, "unindexed/missing packet file")
    for row in rows:
        path = here / safe(row["path"])
        require(stat.S_ISREG(path.lstat().st_mode) and not path.is_symlink(), "nonregular packet member")
        data = path.read_bytes()
        require(len(data) == row["bytes"] and sha(data) == row["sha256"]
                and blob(data) == row["git_blob"], "packet member hash mismatch: " + row["path"])

    run = api(here / "raw/RUN.json.gz")
    jobs = api(here / "raw/JOBS.json.gz")["jobs"]
    artifacts = api(here / "raw/ARTIFACT_METADATA.json.gz")["artifacts"]
    require(run["id"] == RUN and run["run_attempt"] == 1 and run["head_sha"] == F
            and run["status"] == "completed" and run["conclusion"] == "success"
            and run["event"] == "push", "wrong actual run")
    require(len(jobs) == len(artifacts) == 1, "unexpected producer count")
    job, artifact = jobs[0], artifacts[0]
    require(job["id"] == JOB and job["run_id"] == RUN and job["head_sha"] == F
            and job["run_attempt"] == 1 and job["conclusion"] == "success", "wrong producer job")
    require(artifact["id"] == ARTIFACT and artifact["size_in_bytes"] == 1742796
            and artifact["expired"] is False and artifact["digest"] == "sha256:" + ZIP_SHA
            and artifact["workflow_run"]["id"] == RUN
            and artifact["workflow_run"]["head_sha"] == F
            and artifact["workflow_run"]["repository_id"] == 1280062128, "wrong artifact")
    upload = [step for step in job["steps"] if step["name"] == "Preserve actual source, failures, markers and original owned databases"]
    require(len(upload) == 1 and upload[0]["conclusion"] == "success"
            and upload[0]["started_at"] <= artifact["created_at"] <= upload[0]["completed_at"],
            "artifact time outside successful upload step")

    commit = api(here / "raw/F_COMMIT.json.gz")
    source_commit = api(here / "raw/M_COMMIT.json.gz")
    base_commit = api(here / "raw/BASE_COMMIT.json.gz")
    require(commit["sha"] == F and [p["sha"] for p in commit["parents"]] == [M], "wrong F/M parent")
    require(source_commit["sha"] == M and base_commit["sha"] == BASE, "wrong source/base commit")
    frozen, _ = tree_from(here / "raw/F_TREE.json.gz", commit["tree"]["sha"])
    tested, _ = tree_from(here / "raw/M_TREE.json.gz", source_commit["tree"]["sha"])
    current, current_subtrees = tree_from(here / "raw/BASE_TREE.json.gz", base_commit["tree"]["sha"])

    zip_data = (here / "raw/evidence.zip").read_bytes()
    require(len(zip_data) == 1742796 and sha(zip_data) == ZIP_SHA, "archive bytes mismatch")
    with zipfile.ZipFile(io.BytesIO(zip_data)) as archive:
        infos = archive.infolist()
        require(len(infos) == len({i.filename for i in infos}) == 569 and archive.testzip() is None,
                "ZIP member/CRC failure")
        zip_rows = []
        for info in infos:
            safe(info.filename)
            require(not info.is_dir() and not (info.flag_bits & 1)
                    and stat.S_IFMT(info.external_attr >> 16) in (0, stat.S_IFREG), "nonregular ZIP member")
            data = archive.read(info)
            zip_rows.append({"path": info.filename, "bytes": len(data), "sha256": sha(data), "crc32": f"{info.CRC:08x}"})
        require(zip_rows == load(here / "ZIP_FILES.json"), "ZIP manifest mismatch")
        before = json.loads(archive.read("annotation-disconnect-route/before.json"))
        after = json.loads(archive.read("annotation-disconnect-route/after.json"))
        require(before["source"] == after["source"] and len(after["source"]["files"]) == 102,
                "before/after source changed")
        observed = after["source"]
        require(observed["identity"]["head_sha"] == F and observed["identity"]["run_id"] == RUN
                and observed["identity"]["run_attempt"] == 1 and observed["application_source"] == M,
                "source report identity mismatch")
        baseline_api = load(here / "raw/BASELINE_REPOSITORY_API.json.gz")
        baseline = baseline_api["content"].encode()
        if blob(baseline) != baseline_api["sha"]:
            require(baseline.endswith(b"\n") and blob(baseline[:-1]) == baseline_api["sha"], "baseline bytes mismatch")
            baseline = baseline[:-1]
        require(blob(baseline) == observed["original_repository"]["git_blob"]
                and sha(baseline) == observed["original_repository"]["sha256"], "original baseline mismatch")
        source_copies = []
        for phase, report in (("before", before), ("after", after)):
            data = archive.read(f"annotation-disconnect-route/source-{phase}.tar.gz")
            pin = report["source_archive"]
            require(len(data) == pin["bytes"] and sha(data) == pin["sha256"] and pin["members"] == 103,
                    "source tar digest mismatch")
            with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as source_tar:
                members = source_tar.getmembers()
                require(len(members) == len({i.name for i in members}) == 103, "source tar member count")
                values = {}
                for member in members:
                    safe(member.name)
                    require(member.isfile() and not member.issym() and not member.islnk()
                            and member.mode == 0o644, "nonregular source tar member")
                    value = source_tar.extractfile(member).read()
                    if member.name == "original-baseline/AnnotationRepository.swift":
                        require(value == baseline, "original repository tar mismatch")
                    else:
                        row, git_row = observed["files"][member.name], frozen[member.name]
                        require(len(value) == row["bytes"] and sha(value) == row["sha256"]
                                and blob(value) == row["git_blob"] == git_row["sha"]
                                and git_row["mode"] == "100644" and git_row["type"] == "blob", "source/Git mismatch")
                    values[member.name] = value
                require(set(values) == set(observed["files"]) | {"original-baseline/AnnotationRepository.swift"}, "source membership mismatch")
                source_copies.append(values)
        require(source_copies[0] == source_copies[1], "source archive change")
        require(after["status"] == "PASS_APPLE_REPOSITORY_RED10_LOCAL43_COLD2_CLOUD48_EXCHANGE28_CRASH2"
                and all(outcome == "success" for outcome in after["outcomes"].values()), "actual CI gate incomplete")
        require(after["race_gates"] == {"candidate_green": 10, "cold_reads": 11, "original_red": 1,
                    "original_red_counts_as_pass": False, "status": "PASS_ACTUAL_REPOSITORY_RED_AND10_GREEN"}, "race gate mismatch")
        original = after["original_gates"]
        require((original["local_cases"], original["local_cold_reopen_gates"], original["cloud_cases"],
                 original["exchange_cases"], original["exchange_abrupt_process_reopen_gates"]) == (43, 2, 48, 28, 2), "original gate counts")
        require(after["native_ui_executed"] == after["physical_device_executed"] == after["anytype_runtime_executed"]
                == after["cloudkit_transport_executed"] == 0 and after["current_core194_executed"] is False, "scope inflation")

    replay = load(here / "SCOPED_REPLAY_RESULT.json")
    require(replay["status"] == "PASS_SCOPED_UNCHANGED_READ_ONLY_VALIDATORS" and not replay["errors"]
            and replay["source_before_after_identical"] is True and replay["offline_swift_executed"]
            == replay["offline_native_executed"] == 0, "scoped replay incomplete")
    require(replay["steps"]["unchanged_complete_original_cloud_local_exchange_gate"]["result"] == original,
            "retained complete original-gate replay mismatch")
    candidates = replay["steps"]["candidate_results_with_explicit_empty_directory_retention_boundary"]["result"]
    require((candidates["unchanged_function_complete_replays"], candidates["raw_result_and_CI_gate_only"]) == (3, 7),
            "empty-directory retention boundary lost")
    process = replay["steps"]["bounded_raw_process_receipts_and_actual_CI_binary_gate_scope"]["result"]
    require(process["executables_retained_in_artifact"] is False and len(set(process["distinct_execution_PIDs"])) == 11,
            "binary/PID scope mismatch")

    proposal = load(here / "INTEGRATION_PROPOSAL.json")
    require(proposal["base_commit"] == BASE and proposal["base_tree"] == base_commit["tree"]["sha"]
            and proposal["tested_source_commit"] == M and len(proposal["source_files"]) == 15,
            "wrong integration proposal")
    changed = dict(current)
    for row in proposal["source_files"]:
        path = safe(row["path"])
        data = (source_root / path).read_bytes()
        require(not (source_root / path).is_symlink() and len(data) == row["bytes"]
                and sha(data) == row["sha256"] and blob(data) == row["git_blob"] == tested[str(path)]["sha"],
                "candidate differs from actually tested bytes: " + str(path))
        require((current[str(path)]["sha"] if str(path) in current else None) == row["base_git_blob"], "base input mismatch")
        changed[str(path)] = {"path": str(path), "mode": row["mode"], "type": row["type"], "sha": row["git_blob"]}
    proposed_tree, proposed_subtrees = merkle(changed)
    require(proposed_tree == proposal["proposed_product_only_tree"], "unexpected proposed Merkle tree")
    for path, digest in proposal["unchanged_protected_subtrees"].items():
        require(current_subtrees[path] == digest == proposed_subtrees[path], "protected tree changed")
    require(b'CORE_TREE = "5d0ee482c8f10726fe3863792dac94c18e94d792"' in
            (source_root / "tools/hq-annotation-disconnect-acceptance.py").read_bytes(), "historical helper relabelled")
    return {"status": "PASS_READ_ONLY_PACKET_AND_EXACT_SOURCE_PROPOSAL", "run": RUN, "job": JOB,
            "artifact": ARTIFACT, "ZIP_files_CRC_verified": 569, "source_inputs_Git_verified": 102,
            "source_tar_members_each": 103, "source_before_after_identical": True,
            "proposed_paths": 15, "proposed_product_only_tree": proposed_tree,
            "actual_CI_scope": "local43+cold2+cloud48+exchange28+reopen2+expected-original-RED+candidate10",
            "unchanged_local_replay": "complete original Cloud/Local/Exchange; Repository scoped3+7 with disclosed retention boundary",
            "full_verify_race_offline": "NOT_REPLAYED: required Apple binaries are absent",
            "offline_Swift": 0, "offline_Native": 0, "new_combined_source_qualification": "NOT_RUN"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path)
    args = parser.parse_args()
    here = Path(__file__).resolve().parent
    result = verify(here, args.source_root or here.parents[2])
    print(json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2))


if __name__ == "__main__":
    main()

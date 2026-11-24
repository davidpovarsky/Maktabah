#!/usr/bin/env python3
"""Restore two exact original SDK artifacts into new, owned build paths only."""
import argparse
from datetime import datetime
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import runpy
import shutil
import stat
import re
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[2]
SDK = runpy.run_path(str(ROOT / "Scripts/CI/hq-original-editor-distribution.py"))
require, digest, write, owned_path = (SDK[key] for key in ["require", "digest", "write", "owned_path"])
REPOSITORY = "davidpovarsky/anytype-swift"


def current_metadata(config, item, evidence):
    def fetch(endpoint, suffix):
        raw = subprocess.check_output(["gh", "api", "repos/" + REPOSITORY + "/actions/" + endpoint],
                                      cwd=ROOT, timeout=90)
        result = json.loads(raw)
        write(evidence / (str(item["id"]) + "-" + suffix + ".json"), result)
        return result
    artifact = fetch("artifacts/" + str(item["id"]), "artifact")
    run = fetch(f"runs/{config['run_id']}/attempts/{config['run_attempt']}", "run")
    job = fetch("jobs/" + str(config["job_id"]), "job")
    for field in ["id", "name", "size_in_bytes"]:
        require(artifact.get(field) == item[field], "Original SDK artifact metadata differs: " + field)
    require(artifact.get("expired") is False and artifact.get("digest") == "sha256:" + item["sha256"],
            "Original SDK artifact digest/lifetime differs")
    producer = artifact.get("workflow_run", {})
    require(producer.get("id") == config["run_id"] and producer.get("head_sha") == config["source_sha"]
            and producer.get("repository_id") == producer.get("head_repository_id") == config["repository_id"],
            "Original SDK artifact producer differs")
    require(run.get("id") == config["run_id"] and run.get("run_attempt") == config["run_attempt"]
            and run.get("head_sha") == run.get("head_commit", {}).get("id") == config["source_sha"]
            and run.get("status") == "completed" and run.get("conclusion") == "success"
            and run.get("path") == config["workflow_path"], "Original SDK run is not the reviewed successful producer")
    require(all(run.get(key, {}).get("full_name") == REPOSITORY
                and run[key].get("id") == config["repository_id"] for key in ["repository", "head_repository"]),
            "Original SDK run repository differs")
    require(job.get("id") == config["job_id"] and job.get("name") == config["job_name"]
            and job.get("run_id") == config["run_id"] and job.get("run_attempt") == config["run_attempt"]
            and job.get("head_sha") == config["source_sha"] and job.get("status") == "completed"
            and job.get("conclusion") == "success"
            and job.get("head_branch") == run.get("head_branch") == producer.get("head_branch"),
            "Original SDK framework job differs")
    for name in [*config["required_steps"], item["upload_step"]]:
        steps = [step for step in job.get("steps", []) if step.get("name") == name]
        require(len(steps) == 1 and steps[0].get("status") == "completed"
                and steps[0].get("conclusion") == "success", "Original SDK producer step did not succeed: " + name)
    upload = next(step for step in job["steps"] if step["name"] == item["upload_step"])
    timestamp = lambda text: datetime.fromisoformat(text.replace("Z", "+00:00"))
    created = timestamp(artifact["created_at"])
    require(timestamp(upload["started_at"]) <= created <= timestamp(upload["completed_at"])
            and timestamp(job["started_at"]) <= created <= timestamp(job["completed_at"]),
            "SDK artifact creation is outside its exact successful upload")
    return {"artifact_id": item["id"], "run_id": config["run_id"], "run_attempt": config["run_attempt"],
            "job_id": config["job_id"], "source_sha": config["source_sha"], "sha256": item["sha256"]}


def download(item):
    target = owned_path(ROOT, item["path"], build=True)
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        require(target.is_file() and target.stat().st_size == item["size_in_bytes"]
                and digest(target) == item["sha256"], "Refusing to overwrite a different SDK input artifact")
        return target
    partial = target.with_suffix(target.suffix + ".partial")
    with partial.open("xb") as output:
        subprocess.run(["gh", "api", f"repos/{REPOSITORY}/actions/artifacts/{item['id']}/zip"],
                       cwd=ROOT, stdout=output, check=True, timeout=900)
    require(partial.stat().st_size == item["size_in_bytes"] and digest(partial) == item["sha256"],
            "Downloaded SDK artifact bytes differ; partial input retained")
    require(not target.exists(), "SDK artifact destination appeared during download")
    partial.rename(target)
    return target


def zip_members(zipped):
    result = {}
    aliases = set()
    for entry in zipped.infolist():
        path = PurePosixPath(entry.filename.rstrip("/"))
        require(entry.filename and path.parts and path.as_posix() != "." and not path.is_absolute() and ".." not in path.parts
                and path.as_posix() == entry.filename.rstrip("/") and "\\" not in entry.filename
                and not (entry.flag_bits & 1), "Unsafe original SDK ZIP member")
        folded = path.as_posix().casefold()
        require(folded not in aliases, "Aliased or duplicate original SDK ZIP member")
        aliases.add(folded)
        mode = (entry.external_attr >> 16) & 0xFFFF
        require(stat.S_IFMT(mode) in {0, stat.S_IFDIR if entry.is_dir() else stat.S_IFREG},
                "Nonregular original SDK ZIP member")
        if not entry.is_dir():
            result[path.as_posix()] = entry
    return result


def stage(config, evidence):
    if config.get("producer_kind") == "local-mac":
        helper = ("original_editor_production_admission.py"
                  if config.get("schema") == "otzaria.original-editor.production-input/1"
                  else "original_editor_local_admission.py")
        local = runpy.run_path(str(owned_path(ROOT, "Scripts/CI/" + helper)))
        return local["restore"](ROOT, config, evidence, SDK, zip_members)
    if config.get("schema") == 2:
        continuation = runpy.run_path(str(owned_path(ROOT, "Scripts/CI/original_editor_continuation_admission.py")))
        return continuation["stage"](ROOT, config, evidence, SDK, download)
    framework = config["framework_artifact"]
    original_evidence = config["evidence_artifact"]
    require(re.fullmatch(r"[a-f0-9]{40}", config.get("source_sha", ""))
            and all(type(config.get(key)) is int and config[key] > 0 for key in
                    ["repository_id", "run_id", "run_attempt", "job_id", "artifact_id", "archive_bytes"]),
            "Original SDK producer pins are not finalized")
    require(config.get("workflow_path") == ".github/workflows/pinkha-original-editor-framework.yml"
            and isinstance(config.get("required_steps"), list) and config["required_steps"]
            and isinstance(config.get("job_name"), str) and config["job_name"], "Unreviewed SDK producer contract")
    for key in ["archive_sha256", "distribution_manifest_sha256", "qualification_sha256", "original_source_sha256", "hanlin_source_sha256"]:
        require(re.fullmatch(r"[a-f0-9]{64}", config.get(key, "")), "Unfinalized SDK input digest: " + key)
    for item in [framework, original_evidence]:
        require(all(type(item.get(key)) is int and item[key] > 0 for key in ["id", "size_in_bytes"])
                and re.fullmatch(r"[a-f0-9]{64}", item.get("sha256", ""))
                and all(isinstance(item.get(key), str) and item[key] for key in ["name", "upload_step"]),
                "Unfinalized original SDK artifact")
        owned_path(ROOT, item["path"], build=True)
    require(framework["id"] == config["artifact_id"] and framework["path"] == config["archive_path"]
            and framework["sha256"] == config["archive_sha256"]
            and framework["size_in_bytes"] == config["archive_bytes"], "SDK archive aliases disagree")
    producers = [current_metadata(config, item, evidence) for item in [framework, original_evidence]]
    archive, evidence_archive = download(framework), download(original_evidence)
    with zipfile.ZipFile(evidence_archive) as outer:
        members = zip_members(outer)
        require(set(members) == {"Pinkha-Native-Derived-Evidence.zip"}, "Unexpected original evidence wrapper")
        payload = members["Pinkha-Native-Derived-Evidence.zip"]
        require(payload.file_size <= 256 * 1024 * 1024, "Oversized original evidence payload")
        with zipfile.ZipFile(io.BytesIO(outer.read(payload))) as inner:
            members = zip_members(inner)
            for member, path_key, sha_key in [
                    ("framework-distribution.json", "distribution_manifest_path", "distribution_manifest_sha256"),
                    ("original-hanlin-snapshot.json", "hanlin_source_path", "hanlin_source_sha256")]:
                selected = members.get(member)
                require(selected is not None and 0 < selected.file_size <= 16 * 1024 * 1024,
                        "Missing bounded original producer input: " + member)
                raw = inner.read(selected)
                require(hashlib.sha256(raw).hexdigest() == config[sha_key], "Original producer input differs: " + member)
                destination = owned_path(ROOT, config[path_key], build=True)
                destination.parent.mkdir(parents=True, exist_ok=True)
                if destination.exists():
                    require(destination.read_bytes() == raw, "Refusing to overwrite original producer input")
                else:
                    with destination.open("xb") as output:
                        output.write(raw)
    exported = SDK["read_json"](owned_path(ROOT, config["distribution_manifest_path"], build=True))
    expected = dict(exported["files"])
    require("QUALIFICATION.json" not in expected and expected, "Unexpected original export closure")
    destination = owned_path(ROOT, config["distribution_root"], build=True)
    with zipfile.ZipFile(archive) as zipped:
        members = zip_members(zipped)
        require(set(members) == set(expected) | {"QUALIFICATION.json"}, "SDK archive does not contain the exact export closure")
        qualification = members["QUALIFICATION.json"]
        require(0 < qualification.file_size <= 16 * 1024 * 1024, "Oversized SDK qualification receipt")
        expected["QUALIFICATION.json"] = {"bytes": qualification.file_size, "sha256": config["qualification_sha256"]}
        if destination.exists():
            require(SDK["inventory"](destination) == expected, "Refusing to overwrite a different SDK distribution")
        else:
            destination.mkdir(parents=True)
            for name, entry in members.items():
                require(entry.file_size == expected[name]["bytes"], "SDK member size differs: " + name)
                target = destination / name
                target.parent.mkdir(parents=True, exist_ok=True)
                with zipped.open(entry) as source, target.open("xb") as output:
                    shutil.copyfileobj(source, output)
                require(digest(target) == expected[name]["sha256"], "SDK member digest differs: " + name)
                # Retain the mode actually transported by the artifact. The
                # signed bytes are never transformed or re-signed here.
                mode = stat.S_IMODE((entry.external_attr >> 16) & 0xFFFF) or 0o644
                require(mode & ~0o777 == 0, "Special SDK permission bits")
                target.chmod(mode)
            require(SDK["inventory"](destination) == expected, "Materialized SDK distribution differs")
    write(evidence / "restoration.json", {"status": "EXACT_ORIGINAL_SDK_ARTIFACTS_RESTORED",
          "producers": producers, "files": len(expected), "source_sha": config["source_sha"],
          "native_editor_ui_tests": 0, "overwritten_inputs": 0})


if __name__ == "__main__":
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--admission", required=True)
    args = parser.parse_args()
    path = owned_path(ROOT, args.admission)
    require(args.admission.startswith("Scripts/CI/") and args.admission.endswith(".json"), "Unreviewed SDK input location")
    committed = subprocess.check_output(["git", "show", "HEAD:" + args.admission], cwd=ROOT, timeout=60)
    require(path.read_bytes() == committed, "SDK input manifest differs from reviewed source")
    config = SDK["read_json"](path)
    require(config.get("schema") in {1, 2, 3, "otzaria.original-editor.production-input/1"}
            and config.get("repository") == REPOSITORY, "Wrong SDK input contract")
    evidence = ROOT / "build/original-editor-sdk-metadata"
    evidence.mkdir(parents=True, exist_ok=True)
    stage(config, evidence)

"""Strict optional admission for one retained framework and a later runtime.

Schema 1 is handled by the unchanged original route. The old product bytes and
its failed producer receipt stay immutable; a separately authenticated successful
continuation is required. No framework or prior source-control replay occurs here.
"""
from datetime import datetime
import hashlib
import io
import json
from pathlib import Path
import re
import shutil
import stat
import subprocess
import zipfile
from pathlib import PurePosixPath

REPOSITORY = "davidpovarsky/anytype-swift"
QUALIFIED = "ACTUAL_ORIGINAL_FRAMEWORK_EXTERNAL_IMPORT_LINK_RESOURCES_PASS"
WORKFLOW = ".github/workflows/pinkha-original-editor-runtime-continuation.yml"
BRANCH = "codex/otzaria-original-editor-runtime-v13-20261122"
JOB_NAME = "original-editor-runtime-continuation"
PRODUCER_CANONICAL_SHA256 = "4751f2745b5ff5c23574291c78107de5aeacc42c679bb41d58be8e5b1e2f839c"
RUNTIME_REQUIRED_STEPS = ["Verify continuation controls", "Qualify retained original framework runtime", "Preserve runtime continuation evidence", "Upload runtime continuation evidence"]
RUNTIME_UPLOAD_STEP = "Upload runtime continuation evidence"
RUNTIME_WRAPPER = "runtime-continuation-evidence.zip"
RUNTIME_IDENTITY_KEYS = ("repository", "repository_id", "control_sha", "run_id", "run_attempt", "workflow_path", "head_branch", "job_name")

def digest(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()

def require(condition, message):
    if not condition:
        raise RuntimeError(message)

def read_json(path, maximum=16 * 1024 * 1024):
    require(path.is_file() and not path.is_symlink() and 0 < path.stat().st_size <= maximum,
            'Missing, aliased or oversized evidence: ' + str(path))
    return json.loads(path.read_bytes())

def zip_members(zipped):
    result, aliases = {}, set()
    for entry in zipped.infolist():
        path = PurePosixPath(entry.filename.rstrip('/'))
        require(path.parts and path.as_posix() != '.' and not path.is_absolute() and '..' not in path.parts
                and path.as_posix() == entry.filename.rstrip('/') and '\\' not in entry.filename
                and ':' not in entry.filename and not (entry.flag_bits & 1), 'Unsafe retained ZIP member')
        folded = path.as_posix().casefold()
        require(folded not in aliases, 'Aliased or repeated retained ZIP member')
        aliases.add(folded)
        mode = (entry.external_attr >> 16) & 0xFFFF
        require(stat.S_IFMT(mode) in {0, stat.S_IFDIR if entry.is_dir() else stat.S_IFREG}
                and not stat.S_IMODE(mode) & ~0o777, 'Nonregular retained ZIP member')
        if not entry.is_dir():
            result[path.as_posix()] = entry
    return result

def verify_retained_phase(producer, evidence):
    for name, expected in producer['retained_input_sha256'].items():
        require(digest(evidence / name) == expected, 'Original evidence digest differs: ' + name)
    execution = read_json(evidence / 'execution.json')
    require(execution['source_sha'] == producer['source_sha']
            and str(execution['run_id']) == str(producer['run_id'])
            and str(execution['run_attempt']) == str(producer['run_attempt'])
            and execution['status'] == 'FAIL' and execution['phase'] == 'ACTUAL_EXTERNAL_RESOURCE_RUNTIME'
            and execution['error_type'] == 'TimeoutExpired'
            and execution['original_framework_build'] == execution['external_consumer_build'] == 'PASS'
            and execution['verified_runtime_observations'] == [], 'Original failure is not the admitted install boundary')
    install = read_json(evidence / 'install-external-consumer.command.json')
    require(install['command'][:3] == ['xcrun', 'simctl', 'install']
            and install['timed_out'] is True and install['timeout_seconds'] == 60 and install['returncode'] == -15,
            'Original install did not fail at the reviewed finite timeout')
    for name in ['framework-build', 'external-consumer-build', 'external-consumer-signature']:
        command = read_json(evidence / (name + '.command.json'))
        require(command['returncode'] == 0 and command['timed_out'] is False, 'Original completed command differs: ' + name)
    controls = read_json(evidence / 'source-controls-result.json')
    expected = controls['expected_ids']
    require(controls['status'] == 'PASS_SOURCE_CONTROLS_245' and controls['tests_run'] == 245,
            'Original required source suite did not pass')
    for key in ['expected_ids', 'discovered_ids', 'started_ids', 'passed_ids']:
        require(len(controls[key]) == len(set(controls[key])) == 245 and sorted(controls[key]) == sorted(expected),
                'Original source control identity set differs')
    require(all(controls[k] == [] for k in ['errors', 'failures', 'skipped', 'expected_failures', 'unexpected_successes']),
            'Original source controls were incomplete')
    require((evidence / 'source-before.json').read_bytes() == (evidence / 'source-after.json').read_bytes(),
            'Original product source changed')
    surface = read_json(evidence / 'actual-public-surface.json')
    require(surface['reviewed_host_and_spi_requirements_observed'] == 38
            and surface['public_host_scope_verified'] and surface['qualification_spi_scope_verified']
            and surface['public_original_editor_or_writer_declarations'] == []
            and surface == execution['actual_public_surface'], 'Original public/SPI closure differs')
    require(execution['compiled_consumer_api_probe_sha256'] == producer['consumer_source_sha256'],
            'Original compiled consumer probe differs')
    return execution

def extract_original_evidence(outer_path, work, producer):
    with zipfile.ZipFile(outer_path) as outer:
        members = zip_members(outer)
        require(set(members) == {'Pinkha-Native-Derived-Evidence.zip'}, 'Unexpected original evidence wrapper')
        payload = outer.read(members['Pinkha-Native-Derived-Evidence.zip'])
    require(len(payload) == producer['evidence_inner_bytes']
            and hashlib.sha256(payload).hexdigest() == producer['evidence_inner_sha256'], 'Original evidence payload differs')
    inner_path = work / 'original-evidence.zip'
    inner_path.write_bytes(payload)
    destination = work / 'original-evidence'
    destination.mkdir()
    with zipfile.ZipFile(io.BytesIO(payload)) as inner:
        members = zip_members(inner)
        for name in producer['retained_input_sha256']:
            require(name in members and members[name].file_size <= 16 * 1024 * 1024, 'Missing bounded original evidence member')
            target = destination / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(inner.read(members[name]))
    verify_retained_phase(producer, destination)
    return destination


def validate_configuration(config):
    require(type(config.get("schema")) is int and config["schema"] == 2 and config.get("repository") == REPOSITORY, "Wrong continuation admission schema")
    framework = config.get("framework_producer", {})
    require(hashlib.sha256(json.dumps(framework, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
            == PRODUCER_CANONICAL_SHA256, "Framework producer is not the exact reviewed retained producer")
    for field in ["repository_id", "source_sha", "run_id", "run_attempt", "job_id", "job_name", "workflow_path", "required_steps"]:
        require(config.get(field) == framework[field], "Framework role alias differs: " + field)
    for field in ["framework_artifact", "evidence_artifact"]:
        item = config.get(field, {})
        require({k: v for k, v in item.items() if k != "path"} == framework[field], "Original artifact alias differs: " + field)
    artifact = framework["framework_artifact"]
    require(config.get("artifact_id") == artifact["id"] and config.get("archive_bytes") == artifact["size_in_bytes"]
            and config.get("archive_sha256") == artifact["sha256"]
            and config.get("archive_path") == config["framework_artifact"].get("path"), "Original archive aliases differ")
    require(config.get("distribution_manifest_sha256") == framework["retained_input_sha256"]["framework-distribution.json"]
            and config.get("hanlin_source_sha256") == framework["retained_input_sha256"]["original-hanlin-snapshot.json"],
            "Original evidence aliases differ")
    runtime = config.get("runtime_qualification_producer", {})
    require(runtime.get("repository") == REPOSITORY and runtime.get("repository_id") == framework["repository_id"]
            and runtime.get("workflow_path") == WORKFLOW and runtime.get("head_branch") == BRANCH
            and runtime.get("job_name") == JOB_NAME and type(runtime.get("run_attempt")) is int and runtime["run_attempt"] == 1,
            "Unreviewed continuation producer route")
    require(isinstance(runtime.get("control_sha"), str) and re.fullmatch(r"[a-f0-9]{40}", runtime["control_sha"])
            and runtime["control_sha"] != framework["source_sha"]
            and all(type(runtime.get(k)) is int and runtime[k] > 0 for k in ["run_id", "job_id"])
            and runtime["run_id"] != framework["run_id"], "Unfinalized distinct continuation identity")
    require(runtime.get("required_steps") == RUNTIME_REQUIRED_STEPS
            and runtime.get("evidence_artifact", {}).get("upload_step") == RUNTIME_UPLOAD_STEP,
            "Continuation successful step contract differs")
    for item in [config["framework_artifact"], config["evidence_artifact"], runtime.get("evidence_artifact", {})]:
        require(all(type(item.get(k)) is int and item[k] > 0 for k in ["id", "size_in_bytes"])
                and isinstance(item.get("sha256"), str) and re.fullmatch(r"[a-f0-9]{64}", item["sha256"])
                and all(isinstance(item.get(k), str) and item[k] for k in ["name", "upload_step", "path"]),
                "Unfinalized role-specific artifact")
    require(runtime["evidence_artifact"]["id"] not in {framework["framework_artifact"]["id"], framework["evidence_artifact"]["id"]},
            "Continuation evidence aliases an old artifact")
    require(runtime["evidence_artifact"]["name"] == "Otzaria-Original-Editor-Runtime-Continuation-"
            + runtime["control_sha"] + "-" + str(runtime["run_id"]) + "-1", "Continuation artifact name differs from its producer")
    for key in ["qualification_sha256", "original_source_sha256"]:
        require(isinstance(config.get(key), str) and re.fullmatch(r"[a-f0-9]{64}", config[key]), "Unfinalized continuation digest: " + key)
    require(config.get("qualification_member") == "runtime-qualification.json"
            and config.get("qualification_wrapper") == RUNTIME_WRAPPER, "Unexpected continuation sidecar member/wrapper")
    require(config["original_source_sha256"] == framework["original_source_sha256"], "Original source digest alias differs")
    return framework, runtime


def verify_role_metadata(role, run, job, artifact, expected_artifact, *, framework):
    head = role["source_sha"] if framework else role["control_sha"]
    conclusion = "failure" if framework else "success"
    require(run.get("id") == role["run_id"] and run.get("run_attempt") == role["run_attempt"]
            and run.get("head_sha") == run.get("head_commit", {}).get("id") == head
            and run.get("status") == "completed" and run.get("conclusion") == conclusion and run.get("event") == "push"
            and run.get("path") == role["workflow_path"] and run.get("head_branch") == role["head_branch"],
            "Role-specific producer run differs")
    for key in ["repository", "head_repository"]:
        require(run.get(key, {}).get("id") == role["repository_id"] and run[key].get("full_name") == REPOSITORY,
                "Role-specific repository differs")
    require(job.get("id") == role["job_id"] and job.get("name") == role["job_name"]
            and job.get("run_id") == role["run_id"] and job.get("run_attempt") == role["run_attempt"]
            and job.get("head_sha") == head and job.get("head_branch") == role["head_branch"]
            and job.get("status") == "completed" and job.get("conclusion") == conclusion, "Role-specific job differs")
    def step(name, expected):
        matches = [s for s in job.get("steps", []) if s.get("name") == name]
        require(len(matches) == 1 and matches[0].get("status") == "completed" and matches[0].get("conclusion") == expected,
                "Role-specific step differs: " + name)
        return matches[0]
    for name in role["required_steps"]:
        step(name, "success")
    if framework:
        step(role["failed_step"], "failure")
    upload = step(expected_artifact["upload_step"], "success")
    require(all(artifact.get(k) == expected_artifact[k] for k in ["id", "name", "size_in_bytes"])
            and artifact.get("expired") is False and artifact.get("digest") == "sha256:" + expected_artifact["sha256"],
            "Role-specific artifact identity/digest differs")
    origin = artifact.get("workflow_run", {})
    require(origin.get("id") == role["run_id"] and origin.get("head_sha") == head
            and origin.get("repository_id") == origin.get("head_repository_id") == role["repository_id"]
            and origin.get("head_branch") == role["head_branch"], "Artifact has the wrong producer role")
    instant = lambda value: datetime.fromisoformat(value.replace("Z", "+00:00"))
    created = instant(artifact["created_at"])
    require(instant(upload["started_at"]) <= created <= instant(upload["completed_at"])
            and instant(job["started_at"]) <= created <= instant(job["completed_at"]), "Artifact was not created by its declared upload")


def validate_qualification(config, qualification, *, surface=None):
    framework, runtime = validate_configuration(config)
    require(type(qualification.get("schema")) is int and qualification["schema"] == 2 and qualification.get("kind") == "ORIGINAL_FRAMEWORK_RUNTIME_CONTINUATION"
            and qualification.get("status") == QUALIFIED and qualification.get("phase") == "COMPLETE",
            "Continuation qualification did not complete")
    require(qualification.get("framework_source_sha") == framework["source_sha"]
            and qualification.get("framework_producer") == framework
            and qualification.get("runtime_qualification_producer") == {k: runtime[k] for k in RUNTIME_IDENTITY_KEYS},
            "Continuation qualification confused framework and control provenance")
    require(qualification.get("original_framework_build") == "REUSED_SUCCESSFUL_ORIGINAL_PRODUCER"
            and qualification.get("source_controls_replayed") == 0 and qualification.get("retained_source_controls_passed") == 245
            and qualification.get("external_consumer_build") == "PASS" and qualification.get("same_toolchain_only") is True
            and qualification.get("simulator_attempts") == qualification.get("install_attempts") == 1
            and qualification.get("automatic_retry") is False, "Continuation scope differs")
    require(qualification.get("swift") == framework["toolchain"]["swift"]
            and qualification.get("sdk") == framework["toolchain"]["sdk_version"]
            and qualification.get("preflight", {}).get("xcode") == framework["toolchain"]["xcode"],
            "Continuation did not use the original exact toolchain")
    require(qualification.get("compiled_consumer_api_probe_sha256") == framework["consumer_source_sha256"],
            "Recompiled consumer source differs from the original probe")
    require(all(type(qualification.get(k)) is int for k in ["source_controls_replayed", "retained_source_controls_passed", "simulator_attempts", "install_attempts"])
            and qualification.get("owned_simulator_cleanup_completed") is True
            and qualification.get("distribution_unchanged") is True
            and qualification.get("distribution_manifest_sha256") == config["distribution_manifest_sha256"]
            and qualification.get("original_source_sha256") == config["original_source_sha256"]
            and qualification.get("hanlin_source_sha256") == config["hanlin_source_sha256"],
            "Runtime completion or exact original distribution commitment is incomplete")
    require(qualification.get("public_surface_producer") == {k: framework[k] for k in ["source_sha", "run_id", "run_attempt"]}
            and qualification.get("original_clang_declarations", {}).get("manifest_sha256") == framework["clang_manifest_sha256"],
            "Retained compiler/Clang evidence lost original provenance")
    observations = qualification.get("verified_runtime_observations", [])
    require(len(observations) == 2 and {row.get("language") for row in observations} == {"en", "he"}
            and all(row.get("status") == "ACTUAL_IMPORT_LINK_RESOURCE_RUNTIME_PASS" for row in observations),
            "Actual continuation English/Hebrew observations are incomplete")
    if surface is not None:
        require(qualification.get("actual_public_surface") == surface, "Retained public surface provenance changed")
    return {"framework_producer": framework, "runtime_qualification_producer": runtime,
            "qualification_path": config["qualification_path"], "qualification_sha256": config["qualification_sha256"]}


def validate_paths(root, config, sdk):
    distribution = sdk["owned_path"](root, config["distribution_root"], build=True)
    paths = [config[k] for k in ["distribution_manifest_path", "hanlin_source_path", "qualification_path"]]
    paths += [config[k]["path"] for k in ["framework_artifact", "evidence_artifact"]]
    paths += [config["runtime_qualification_producer"]["evidence_artifact"]["path"]]
    require(len(paths) == len(set(paths)), "Role-specific input paths alias")
    for relative in paths:
        path = sdk["owned_path"](root, relative, build=True)
        require(path != distribution and not path.is_relative_to(distribution) and not distribution.is_relative_to(path),
                "Sidecar or archive would change the original product inventory")
    return distribution


def write_exact(path, raw):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        require(path.is_file() and not path.is_symlink() and path.read_bytes() == raw, "Refusing to replace a retained original input")
    else:
        with path.open("xb") as stream:
            stream.write(raw)


def runtime_payload(archive, config):
    framework, _ = validate_configuration(config)
    with zipfile.ZipFile(archive) as outer:
        members = zip_members(outer)
        require(set(members) == {RUNTIME_WRAPPER}, "Unexpected runtime evidence wrapper")
        entry = members[RUNTIME_WRAPPER]
        require(0 < entry.file_size <= 256 * 1024 * 1024, "Oversized runtime evidence payload")
        payload = outer.read(entry)
    supplements = {}
    with zipfile.ZipFile(io.BytesIO(payload)) as inner:
        members = zip_members(inner)
        for item in framework["archive_omissions"]:
            entry = members.get(item["evidence_path"])
            require(entry is not None and entry.file_size == item["bytes"], "Missing exact original dotfile supplement")
            raw = inner.read(entry)
            require(hashlib.sha256(raw).hexdigest() == item["sha256"]
                    and hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest() == item["git_blob"],
                    "Original dotfile supplement bytes differ")
            supplements[item["distribution_path"]] = raw
        def member(name):
            entry = members.get(name)
            require(entry is not None and 0 < entry.file_size <= 16 * 1024 * 1024, "Missing bounded runtime evidence: " + name)
            return inner.read(entry)
        raw = member("runtime-qualification.json")
        restoration_raw = member("RESTORATION.json")
    require(hashlib.sha256(raw).hexdigest() == config["qualification_sha256"], "Runtime sidecar hash differs")
    qualification, restoration = json.loads(raw), json.loads(restoration_raw)
    validate_qualification(config, qualification)
    require(qualification.get("restoration") == restoration
            and restoration.get("status") == "EXACT_ORIGINAL_FULL_DISTRIBUTION_RESTORED_WITH_TWO_SOURCE_BOUND_DOTFILES"
            and restoration.get("historical_archive_sha256") == framework["framework_artifact"]["sha256"]
            and restoration.get("historical_archive_unchanged") is True
            and restoration.get("archive_product_members") == 2526 and restoration.get("restored_product_members") == 2528
            and restoration.get("omissions") == framework["archive_omissions"]
            and restoration.get("original_qualification_synthesized") is False,
            "Runtime restoration provenance differs")
    return raw, restoration_raw, supplements


def stage(root, config, evidence, sdk, download):
    framework, runtime = validate_configuration(config)
    destination = validate_paths(root, config, sdk)
    def api(endpoint, label):
        raw = subprocess.check_output(["gh", "api", "repos/" + REPOSITORY + "/actions/" + endpoint], cwd=root, timeout=90)
        value = json.loads(raw)
        sdk["write"](evidence / (label + ".json"), value)
        return value
    for role_name, role, items in [("framework", framework, [config["framework_artifact"], config["evidence_artifact"]]),
                                    ("runtime", runtime, [runtime["evidence_artifact"]])]:
        run = api(f"runs/{role['run_id']}/attempts/{role['run_attempt']}", role_name + "-run")
        job = api("jobs/" + str(role["job_id"]), role_name + "-job")
        for item in items:
            artifact = api("artifacts/" + str(item["id"]), role_name + "-artifact-" + str(item["id"]))
            verify_role_metadata(role, run, job, artifact, item, framework=role_name == "framework")
    # Each role is authenticated before fetching any bytes; downloads are exact,
    # retained, and never replace a previous differing input.
    archive, old_evidence = download(config["framework_artifact"]), download(config["evidence_artifact"])
    continuation_archive = download(runtime["evidence_artifact"])
    qualification_raw, restoration_raw, supplements = runtime_payload(continuation_archive, config)
    original = extract_original_evidence(old_evidence, evidence, framework)
    exported = read_json(original / "framework-distribution.json")
    for member, path_key in [("framework-distribution.json", "distribution_manifest_path"),
                              ("original-hanlin-snapshot.json", "hanlin_source_path")]:
        write_exact(sdk["owned_path"](root, config[path_key], build=True), (original / member).read_bytes())
    expected = exported["files"]
    require("QUALIFICATION.json" not in expected and expected and len(expected) == 2528
            and sum(row["bytes"] for row in expected.values()) == exported["bytes"] <= 4 * 1024**3,
            "Original export closure differs")
    omissions = {item["distribution_path"]: item for item in framework["archive_omissions"]}
    require(len(omissions) == 2 and set(omissions) == set(supplements)
            and all(expected.get(name) == {"bytes": item["bytes"], "sha256": item["sha256"]} for name, item in omissions.items()),
            "Dotfile supplements do not match the original full product inventory")
    require(json.loads(restoration_raw)["restored_product_bytes"] == exported["bytes"], "Runtime restored product byte count differs")
    with zipfile.ZipFile(archive) as zipped:
        members = zip_members(zipped)
        require(set(members) == {"distribution/" + name for name in expected if name not in omissions} | {"UNQUALIFIED_PRODUCER.json"},
                "Retained producer ZIP differs beyond the exact two observed dotfiles")
        entry = members["UNQUALIFIED_PRODUCER.json"]
        require(0 < entry.file_size <= 16 * 1024 * 1024, "Oversized historical producer receipt")
        historical = zipped.read(entry)
        require(hashlib.sha256(historical).hexdigest() == framework["retention_receipt_sha256"], "Historical producer receipt differs")
        record = json.loads(historical)
        require(record["source_sha"] == framework["source_sha"] and str(record["run_id"]) == str(framework["run_id"])
                and str(record["run_attempt"]) == str(framework["run_attempt"])
                and record["qualified_distribution"] is False and record["restore_as_sdk_allowed"] is False
                and record["consumer_continuation_admission"] == "NOT_IMPLEMENTED_OR_GRANTED"
                and record["distribution_files"] == expected and record["distribution_bytes"] == exported["bytes"],
                "Historical producer record was relabeled")
        write_exact(evidence / "UNQUALIFIED_PRODUCER.json", historical)
        if destination.exists():
            require(sdk["inventory"](destination) == expected, "Existing SDK product differs")
        else:
            destination.mkdir(parents=True)
            for name, commitment in expected.items():
                target = sdk["owned_path"](destination, name)
                target.parent.mkdir(parents=True, exist_ok=True)
                if name in omissions:
                    with target.open("xb") as output:
                        output.write(supplements[name])
                    target.chmod(0o644)
                else:
                    entry = members["distribution/" + name]
                    require(entry.file_size == commitment["bytes"], "Original product member size differs")
                    with zipped.open(entry) as source, target.open("xb") as output:
                        shutil.copyfileobj(source, output)
                    target.chmod(stat.S_IMODE((entry.external_attr >> 16) & 0xFFFF) or 0o644)
                require(target.stat().st_size == commitment["bytes"] and digest(target) == commitment["sha256"],
                        "Original product member hash/size differs")
    require(sdk["inventory"](destination) == expected, "Materialized original distribution differs")
    provenance = read_json(destination / "SourceProvenance/OriginalSource.json")
    require(provenance["application_source"] == framework["source_sha"] and provenance["original_trees"] == framework["source_trees"]
            and digest(destination / "SourceProvenance/OriginalSource.json") == config["original_source_sha256"],
            "Original framework source provenance differs")
    qualification = json.loads(qualification_raw)
    validate_qualification(config, qualification, surface=read_json(original / "actual-public-surface.json"))
    sdk["require_compiled_host_api"](qualification)
    write_exact(sdk["owned_path"](root, config["qualification_path"], build=True), qualification_raw)
    write_exact(evidence / "runtime-RESTORATION.json", restoration_raw)
    for item in framework["archive_omissions"]:
        write_exact(sdk["owned_path"](evidence, item["evidence_path"]), supplements[item["distribution_path"]])
    sdk["write"](evidence / "restoration.json", {"schema": 2, "status": "EXACT_ORIGINAL_PRODUCTS_AND_SEPARATE_RUNTIME_QUALIFICATION_RESTORED",
            "framework_producer": framework, "runtime_qualification_producer": runtime,
            "files": len(expected), "source_sha": framework["source_sha"], "qualification_sha256": config["qualification_sha256"],
            "native_editor_ui_tests": 0, "overwritten_inputs": 0, "framework_builds_performed": 0})

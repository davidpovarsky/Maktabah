"""Admission for the original signed app and its separate EN/HE runtime.

The successful original framework/consumer commands stay with their failed
producer. This route never relabels that receipt or claims another build.
"""
from datetime import datetime
import hashlib
import io
import json
from pathlib import Path
import re
import runpy
import shutil
import stat
import subprocess
import zipfile

KIND = "original-signed-consumer-runtime/1"
RUNTIME_KIND = "ORIGINAL_SIGNED_CONSUMER_RUNTIME_CONTINUATION"
QUALIFIED = "ACTUAL_ORIGINAL_FRAMEWORK_EXTERNAL_IMPORT_LINK_RESOURCES_PASS"
REPOSITORY = "davidpovarsky/anytype-swift"
WORKFLOW = ".github/workflows/pinkha-original-editor-signed-consumer.yml"
BRANCH = "codex/otzaria-sdk-runtime-20261123"
JOB_NAME = "original-editor-signed-consumer"
WRAPPER = "signed-consumer-evidence.zip"
PRODUCER_SHA256 = "c42b0db5b53164f1bf363054788040a408a7b9eae81f59f3750c3ac3f920ee0e"
PRODUCER_PATH = "docs/hq-integration/original-editor-stageb-20261123/retained-original-producer.json"
REQUIRED_STEPS = [
    "Admit already executed focused source controls",
    "Qualify exact signed consumer in English and Hebrew",
    "Preserve actual runtime evidence",
    "Upload original signed consumer runtime evidence",
]
ORIGINAL_IDENTITY_KEYS = (
    "failed_step", "head_branch", "job_id", "job_name", "repository",
    "repository_id", "required_steps", "run_attempt", "run_id", "source_sha", "workflow_path",
)
RUNTIME_IDENTITY_KEYS = (
    "repository", "repository_id", "control_sha", "run_id", "run_attempt",
    "workflow_path", "head_branch", "job_name",
)


def require(value, message):
    if not value:
        raise RuntimeError(message)


def canonical_digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def common():
    return runpy.run_path(str(Path(__file__).with_name("original_editor_continuation_admission.py")))


def reviewed_producer():
    path = Path(__file__).resolve().parents[2] / PRODUCER_PATH
    require(path.is_file() and not path.is_symlink() and path.stat().st_size <= 32_768,
            "Missing reviewed retained producer")
    producer = json.loads(path.read_bytes())
    require(canonical_digest(producer) == PRODUCER_SHA256, "Reviewed retained producer changed")
    return producer


def validate_configuration(config):
    require(type(config.get("schema")) is int and config["schema"] == 2
            and config.get("continuation_kind") == KIND and config.get("repository") == REPOSITORY,
            "Wrong signed-consumer admission route")
    producer = reviewed_producer()
    require(config.get("framework_producer") == producer, "Original producer was replaced or relabeled")
    for field in ["repository_id", "source_sha", "run_id", "run_attempt", "job_id",
                  "job_name", "workflow_path", "required_steps"]:
        require(type(config.get(field)) is type(producer[field]) and config[field] == producer[field],
                "Original role alias differs: " + field)
    for field in ["framework_artifact", "evidence_artifact"]:
        require({k: v for k, v in config.get(field, {}).items() if k != "path"} == producer[field],
                "Original archive alias differs: " + field)
    artifact = producer["framework_artifact"]
    require(config.get("artifact_id") == artifact["id"]
            and config.get("archive_bytes") == artifact["size_in_bytes"]
            and config.get("archive_sha256") == artifact["sha256"]
            and config.get("archive_path") == config["framework_artifact"].get("path"),
            "Original distribution archive differs")
    for alias, original in [("distribution_manifest_sha256", "framework-distribution.json"),
                            ("hanlin_source_sha256", "original-hanlin-snapshot.json")]:
        require(config.get(alias) == producer["retained_input_sha256"][original],
                "Original retained evidence alias differs: " + alias)
    require(config.get("original_source_sha256") == producer["original_source_sha256"],
            "Original source digest differs")
    runtime = config.get("runtime_qualification_producer", {})
    require(runtime.get("repository") == REPOSITORY
            and runtime.get("repository_id") == producer["repository_id"]
            and runtime.get("workflow_path") == WORKFLOW and runtime.get("head_branch") == BRANCH
            and runtime.get("job_name") == JOB_NAME
            and type(runtime.get("run_attempt")) is int and runtime["run_attempt"] == 1,
            "Unreviewed signed-consumer runtime route")
    require(isinstance(runtime.get("control_sha"), str)
            and re.fullmatch(r"[a-f0-9]{40}", runtime["control_sha"])
            and runtime["control_sha"] != producer["source_sha"]
            and all(type(runtime.get(k)) is int and runtime[k] > 0 for k in ["run_id", "job_id"])
            and runtime["run_id"] != producer["run_id"],
            "Unfinalized distinct runtime producer")
    require(runtime.get("required_steps") == REQUIRED_STEPS, "Runtime successful steps differ")
    runtime_artifact = runtime.get("evidence_artifact", {})
    require(runtime_artifact.get("upload_step") == REQUIRED_STEPS[-1]
            and runtime_artifact.get("name") == "Otzaria-Original-Editor-Signed-Consumer-Runtime-"
                + runtime["control_sha"] + "-" + str(runtime["run_id"]) + "-1"
            and runtime_artifact.get("id") not in {producer[k]["id"] for k in
                ["framework_artifact", "evidence_artifact", "signed_consumer_artifact"]},
            "Runtime evidence belongs to another producer role")
    for item in [config["framework_artifact"], config["evidence_artifact"], runtime_artifact]:
        require(all(type(item.get(k)) is int and item[k] > 0 for k in ["id", "size_in_bytes"])
                and isinstance(item.get("sha256"), str) and re.fullmatch(r"[a-f0-9]{64}", item["sha256"])
                and isinstance(item.get("path"), str) and item["path"],
                "Unfinalized role-specific artifact")
    require(isinstance(config.get("qualification_sha256"), str)
            and re.fullmatch(r"[a-f0-9]{64}", config["qualification_sha256"])
            and config.get("qualification_member") == "runtime-qualification.json"
            and config.get("qualification_wrapper") == WRAPPER
            and isinstance(config.get("retained_execution_path"), str),
            "Unfinalized runtime sidecar or original build proof")
    return producer, runtime


def validate_qualification(config, qualification, *, surface=None):
    producer, runtime = validate_configuration(config)
    require(type(qualification.get("schema")) is int and qualification["schema"] == 2
            and qualification.get("kind") == RUNTIME_KIND
            and qualification.get("status") == QUALIFIED and qualification.get("phase") == "COMPLETE",
            "Signed consumer runtime did not qualify")
    require(qualification.get("framework_source_sha") == producer["source_sha"]
            and qualification.get("framework_producer") == {k: producer[k] for k in ORIGINAL_IDENTITY_KEYS}
            and qualification.get("runtime_qualification_producer") == {k: runtime[k] for k in RUNTIME_IDENTITY_KEYS},
            "Runtime confused original build and continuation provenance")
    for field, expected in [("framework_builds", 0), ("consumer_builds", 0), ("source_controls_replayed", 0),
                            ("native_editor_ui_tests", 0), ("simulator_attempts", 1),
                            ("retained_source_controls_passed", 245), ("retained_affected_controls_passed", 8)]:
        require(type(qualification.get(field)) is int and qualification[field] == expected,
                "Signed runtime execution count differs: " + field)
    require(qualification.get("original_framework_build") == "REUSED_SUCCESSFUL_ORIGINAL_PRODUCER"
            and qualification.get("external_consumer_build") == "REUSED_SUCCESSFUL_ORIGINAL_PRODUCER"
            and qualification.get("automatic_retry") is False and qualification.get("same_toolchain_only") is True,
            "Retained signed products were presented as a rebuild or automatic retry")
    require(qualification.get("swift") == producer["toolchain"]["swift"]
            and qualification.get("sdk") == producer["toolchain"]["sdk_version"]
            and qualification.get("preflight", {}).get("xcode") == producer["toolchain"]["xcode"]
            and qualification.get("compiled_consumer_api_probe_sha256") == producer["consumer_source_sha256"],
            "Runtime toolchain or compiled consumer source differs")
    require(qualification.get("distribution_unchanged") is True
            and qualification.get("distribution_manifest_sha256") == config["distribution_manifest_sha256"]
            and qualification.get("original_source_sha256") == config["original_source_sha256"]
            and qualification.get("original_clang_declarations", {}).get("manifest_sha256") == producer["clang_manifest_sha256"],
            "Exact original distribution or compiler declarations changed")
    actual_surface = qualification.get("actual_public_surface")
    require(canonical_digest(actual_surface) == producer["actual_public_surface_canonical_sha256"]
            and (surface is None or actual_surface == surface), "Original compiled public/SPI surface differs")
    observations = qualification.get("verified_runtime_observations", [])
    require(len(observations) == 2 and {row.get("language") for row in observations} == {"en", "he"}
            and all(row.get("status") == "ACTUAL_IMPORT_LINK_RESOURCE_RUNTIME_PASS"
                    and type(row.get("native_editor_ui_tests")) is int and row["native_editor_ui_tests"] == 0
                    for row in observations), "Actual English/Hebrew resource observations are incomplete")
    preflight = qualification.get("preflight", {})
    owned = preflight.get("selected", {}).get("ipad", {})
    cleanup = qualification.get("owned_simulator_cleanup", {})
    require(preflight.get("source_sha") == runtime["control_sha"]
            and preflight.get("run_id") == str(runtime["run_id"]) and preflight.get("run_attempt") == "1"
            and owned.get("name") == "Pinkha-UI27-" + str(runtime["run_id"]) + "-ipad"
            and isinstance(owned.get("udid"), str)
            and re.fullmatch(r"[A-Fa-f0-9-]{36}", owned["udid"])
            and cleanup.get("owned_udid") == owned["udid"]
            and qualification.get("owned_simulator_cleanup_completed") is True
            and cleanup.get("completed") is True and cleanup.get("owned_groups_drained") is True
            and cleanup.get("owned_device_proven_absent") is True
            and all(type(cleanup.get(key, {}).get("effective_returncode")) is int
                    and cleanup[key]["effective_returncode"] == 0 for key in ["delete", "post_state"]),
            "Owned simulator cleanup or runtime identity is incomplete")
    return {"framework_producer": producer, "runtime_qualification_producer": runtime,
            "qualification_path": config["qualification_path"], "qualification_sha256": config["qualification_sha256"],
            "retained_execution_path": config["retained_execution_path"], "continuation_kind": KIND}


def read_member(zipped, members, name, maximum=16 * 1024 * 1024, *, allow_empty=False):
    entry = members.get(name)
    require(entry is not None and (0 if allow_empty else 1) <= entry.file_size <= maximum,
            "Missing or oversized exact evidence member: " + name)
    return zipped.read(entry)


def original_payload(archive, producer):
    helpers = common()
    with zipfile.ZipFile(archive) as outer:
        members = helpers["zip_members"](outer)
        require(set(members) == {"Pinkha-Native-Derived-Evidence.zip"}, "Original evidence wrapper differs")
        raw = read_member(outer, members, "Pinkha-Native-Derived-Evidence.zip", producer["inner_evidence_bytes"])
    require(len(raw) == producer["inner_evidence_bytes"]
            and hashlib.sha256(raw).hexdigest() == producer["inner_evidence_sha256"], "Original evidence payload differs")
    retained = {}
    with zipfile.ZipFile(io.BytesIO(raw)) as inner:
        members = helpers["zip_members"](inner)
        for name, expected in producer["retained_input_sha256"].items():
            value = read_member(inner, members, name)
            require(hashlib.sha256(value).hexdigest() == expected, "Original evidence hash differs: " + name)
            retained[name] = value
        for name in ["framework-build", "external-consumer-build", "external-consumer-signature"]:
            command = json.loads(read_member(inner, members, name + ".command.json"))
            require(command.get("returncode") == 0 and command.get("timed_out") is False,
                    "Original successful build/signature command differs")
            for stream in ["stdout", "stderr"]:
                value = read_member(inner, members, name + "." + stream + ".log", 128 * 1024 * 1024, allow_empty=True)
                require(hashlib.sha256(value).hexdigest() == command[stream + "_sha256"], "Original command log differs")
    execution = json.loads(retained["execution.json"])
    require(execution.get("status") == "FAIL" and execution.get("phase") == "ACTUAL_EXTERNAL_RESOURCE_RUNTIME"
            and execution.get("error") == "Actual simctl does not advertise the required output options"
            and execution.get("original_framework_build") == execution.get("external_consumer_build") == "PASS"
            and execution.get("verified_runtime_observations") == []
            and execution.get("source_sha") == producer["source_sha"]
            and str(execution.get("run_id")) == str(producer["run_id"])
            and str(execution.get("run_attempt")) == "1"
            and canonical_digest(execution) == producer["execution_canonical_sha256"],
            "Original failed runtime or successful builds were relabeled")
    require(retained["source-before.json"] == retained["source-after.json"],
            "Original source changed during its successful build")
    return retained


def runtime_payload(archive, config):
    producer, _ = validate_configuration(config)
    helpers = common()
    with zipfile.ZipFile(archive) as outer:
        members = helpers["zip_members"](outer)
        require(set(members) == {WRAPPER}, "Signed runtime evidence wrapper differs")
        raw = read_member(outer, members, WRAPPER, 256 * 1024 * 1024)
    with zipfile.ZipFile(io.BytesIO(raw)) as inner:
        members = helpers["zip_members"](inner)
        qualification_raw = read_member(inner, members, "runtime-qualification.json")
        require(hashlib.sha256(qualification_raw).hexdigest() == config["qualification_sha256"],
                "Actual runtime qualification hash differs")
        qualification = json.loads(qualification_raw)
        validate_qualification(config, qualification)
        require(json.loads(read_member(inner, members, "execution.json")) == qualification,
                "Terminal runtime and qualification receipts differ")
        commands = json.loads(read_member(inner, members, "commands/COMMANDS.json"))
        require(isinstance(commands, list) and commands and len(commands) <= 100, "Malformed owned runtime command history")
        labels = [row.get("label") for row in commands]
        require(len(labels) == len(set(labels)), "Duplicate owned runtime command")
        for row in commands:
            require(row.get("status") == "TERMINAL"
                    and all(type(row.get(key)) is int and row[key] == 0 for key in ["returncode", "effective_returncode"])
                    and row.get("timed_out") is False and row.get("start_new_session") is True,
                    "An owned runtime command did not complete successfully")
            for stream in ["stdout", "stderr"]:
                name = row.get(stream, "")
                require(isinstance(name, str) and Path(name).name == name, "Unowned command stream path")
                value = read_member(inner, members, "commands/" + name, 8 * 1024 * 1024, allow_empty=True)
                require(hashlib.sha256(value).hexdigest() == row.get(stream + "_sha256"),
                        "Owned runtime command stream changed")
        for label in ["consumer-signature", "install", "launch-help", "consumer-en-launch", "consumer-he-launch",
                      "consumer-en-terminate", "consumer-he-terminate"]:
            require(labels.count(label) == 1, "Missing single original consumer command: " + label)
        pids, nonces = [], []
        for language in ["en", "he"]:
            launch = json.loads(read_member(inner, members, "consumer-" + language + "-launch-result.json", 8192))
            require(type(launch.get("pid")) is int and 0 < launch["pid"] < 2**31
                    and launch.get("stdout") == "org.otzaria.acceptance.original-editor: " + str(launch["pid"])
                    and launch.get("language") == language and isinstance(launch.get("nonce"), str)
                    and re.fullmatch(r"[A-F0-9-]{36}", launch["nonce"]), "Actual language launch identity differs")
            row = next(row for row in commands if row["label"] == "consumer-" + language + "-launch")
            require(inner.read(members["commands/" + row["stdout"]]).decode().strip() == launch["stdout"],
                    "Retained actual launch output and PID differ")
            observation = json.loads(read_member(inner, members, "consumer-" + language + "-observation.json", 65_536))
            require(observation.get("nonce") == launch["nonce"]
                    and observation.get("status") == "ACTUAL_EXTERNAL_CONSUMER_RESOURCE_OBSERVATION"
                    and observation.get("mainBundleIdentifier") == "org.otzaria.acceptance.original-editor",
                    "Observed resources belong to another launched process")
            pids.append(launch["pid"])
            nonces.append(launch["nonce"])
        require(len(set(pids)) == len(set(nonces)) == 2, "Language relaunch did not use distinct actual processes")
    return qualification_raw


def compiled_host_receipt(root, config, qualification, sdk):
    producer, _ = validate_configuration(config)
    validate_qualification(config, qualification)
    path = sdk["owned_path"](root, config["retained_execution_path"], build=True)
    require(path.is_file() and path.stat().st_size <= 16 * 1024 * 1024
            and sdk["digest"](path) == producer["retained_input_sha256"]["execution.json"],
            "Retained original compiled-Host receipt differs")
    original = json.loads(path.read_bytes())
    result = sdk["require_compiled_host_api"](qualification, retained_original=original)
    return {**result, "compiled_producer_source_sha": producer["source_sha"],
            "compiled_producer_run_id": producer["run_id"], "consumer_rebuilds_in_continuation": 0}


def verify_exact_upload_log(producer, upload, artifact, expected_artifact, raw):
    """Bind the artifact to its exact successful action, without clock tolerance."""
    require(isinstance(raw, bytes) and 0 < len(raw) <= 4 * 1024 * 1024,
            'Missing bounded authenticated original upload log')
    lines = raw.decode('utf-8-sig').splitlines()
    starts = [i for i, line in enumerate(lines) if '##[group]Run ' in line]
    blocks = []
    for position, start in enumerate(starts):
        end = starts[position + 1] if position + 1 < len(starts) else len(lines)
        if lines[start].endswith('##[group]Run actions/upload-artifact@v4'):
            block = lines[start:end]
            if any(line.partition(' ')[2].strip() == 'name: ' + expected_artifact['name'] for line in block):
                blocks.append(block)
    require(len(blocks) == 1, 'Original artifact has no unique matching upload action')
    block = blocks[0]
    expected = [
        'name: ' + expected_artifact['name'],
        'SHA256 digest of uploaded artifact zip is ' + expected_artifact['sha256'],
        'Artifact ' + expected_artifact['name'] + '.zip successfully finalized. Artifact ID ' + str(expected_artifact['id']),
        'Artifact ' + expected_artifact['name'] + ' has been successfully uploaded! Final size is '
            + str(expected_artifact['size_in_bytes']) + ' bytes. Artifact ID is ' + str(expected_artifact['id']),
        'Artifact download URL: https://github.com/' + REPOSITORY + '/actions/runs/'
            + str(producer['run_id']) + '/artifacts/' + str(expected_artifact['id']),
    ]
    instant = lambda value: datetime.fromisoformat(value.replace('Z', '+00:00'))
    statements, positions = [], []
    for message in expected:
        found = [(i, line) for i, line in enumerate(block) if line.partition(' ')[2].strip() == message]
        require(len(found) == 1, 'Original upload log does not bind exact artifact ID, size and digest')
        index, line = found[0]
        timestamp = line.partition(' ')[0]
        # Job step metadata has whole-second precision. Compare the log's
        # corresponding whole second, not the artifact service creation clock.
        second = instant(timestamp).replace(microsecond=0)
        require(instant(upload['started_at']) <= second <= instant(upload['completed_at']),
                'Artifact finalization statement is outside the exact successful upload step')
        positions.append(index)
        statements.append({'timestamp': timestamp, 'message': message})
    require(positions == sorted(set(positions)), 'Original upload finalization statements are out of order')
    return {'status': 'EXACT_SUCCESSFUL_UPLOAD_LOG_ARTIFACT_BINDING',
            'source_sha': producer.get('source_sha', producer.get('control_sha')), 'run_id': producer['run_id'], 'job_id': producer['job_id'],
            'upload_step': expected_artifact['upload_step'], 'artifact_id': expected_artifact['id'],
            'artifact_sha256': expected_artifact['sha256'], 'artifact_bytes': expected_artifact['size_in_bytes'],
            'artifact_created_at': artifact['created_at'], 'step_started_at': upload['started_at'],
            'step_completed_at': upload['completed_at'], 'authenticated_job_log_sha256': hashlib.sha256(raw).hexdigest(),
            'statements': statements, 'timestamp_tolerance_applied': False}


def stage(root, config, evidence, sdk, download):
    producer, runtime = validate_configuration(config)
    helpers = common()
    destination = helpers["validate_paths"](root, config, sdk)
    def api(endpoint, label):
        raw = subprocess.check_output(["gh", "api", "repos/" + REPOSITORY + "/actions/" + endpoint], cwd=root, timeout=90)
        value = json.loads(raw)
        sdk["write"](evidence / (label + ".json"), value)
        return value
    for role_name, role, items in [
        ("original", producer, [config["framework_artifact"], config["evidence_artifact"], producer["signed_consumer_artifact"]]),
        ("runtime", runtime, [runtime["evidence_artifact"]]),
    ]:
        run = api(f"runs/{role['run_id']}/attempts/{role['run_attempt']}", role_name + "-run")
        job = api("jobs/" + str(role["job_id"]), role_name + "-job")
        upload_path = evidence / (role_name + "-upload-job.log")
        error_path = evidence / (role_name + "-upload-job.stderr")
        require(not upload_path.exists() and not error_path.exists(), "Refusing to overwrite retained upload evidence")
        with upload_path.open("xb") as output, error_path.open("xb") as error:
            completed = subprocess.run(["gh", "api", "--allow-escape-sequences",
                "repos/" + REPOSITORY + "/actions/jobs/" + str(role["job_id"]) + "/logs"],
                cwd=root, stdout=output, stderr=error, timeout=90)
        require(completed.returncode == 0, "Authenticated upload log command failed")
        require(0 < upload_path.stat().st_size <= 4 * 1024 * 1024, "Oversized authenticated upload job log")
        upload_log = upload_path.read_bytes()
        for item in items:
            metadata = api("artifacts/" + str(item["id"]), role_name + "-artifact-" + str(item["id"]))
            binding = helpers["verify_role_metadata"](role, run, job, metadata, item,
                framework=role_name == "original", upload_log=upload_log)
            sdk["write"](evidence / (role_name + "-upload-binding-" + str(item["id"]) + ".json"), binding)
    # Read only authenticated evidence first. The retained signed app need not
    # be downloaded a second time by this Maktabah consumer.
    old_evidence = download(config["evidence_artifact"])
    runtime_archive = download(runtime["evidence_artifact"])
    original = original_payload(old_evidence, producer)
    qualification_raw = runtime_payload(runtime_archive, config)
    qualification = json.loads(qualification_raw)
    validate_qualification(config, qualification, surface=json.loads(original["actual-public-surface.json"]))
    archive = download(config["framework_artifact"])
    manifest = json.loads(original["framework-distribution.json"])
    expected = manifest["files"]
    require(len(expected) == 2528 and "QUALIFICATION.json" not in expected
            and sum(item["bytes"] for item in expected.values()) == manifest["bytes"] == 1_258_250_006,
            "Exact original full distribution closure differs")
    with zipfile.ZipFile(archive) as zipped:
        members = helpers["zip_members"](zipped)
        require(set(members) == {"distribution/" + name for name in expected} | {"UNQUALIFIED_PRODUCER.json"},
                "Original distribution archive membership differs")
        retained_raw = read_member(zipped, members, "UNQUALIFIED_PRODUCER.json")
        retained = json.loads(retained_raw)
        require(retained.get("source_sha") == producer["source_sha"]
                and str(retained.get("run_id")) == str(producer["run_id"])
                and str(retained.get("run_attempt")) == "1"
                and retained.get("qualified_distribution") is False and retained.get("restore_as_sdk_allowed") is False
                and retained.get("distribution_files") == expected and retained.get("distribution_bytes") == manifest["bytes"],
                "Original unqualified retention receipt was relabeled")
        helpers["write_exact"](evidence / "UNQUALIFIED_PRODUCER.json", retained_raw)
        if destination.exists():
            require(sdk["inventory"](destination) == expected, "Existing distribution differs from the original")
        else:
            destination.mkdir(parents=True)
            for name, commitment in expected.items():
                target = sdk["owned_path"](destination, name)
                entry = members["distribution/" + name]
                require(entry.file_size == commitment["bytes"], "Original member size differs")
                target.parent.mkdir(parents=True, exist_ok=True)
                with zipped.open(entry) as source, target.open("xb") as output:
                    shutil.copyfileobj(source, output)
                target.chmod(stat.S_IMODE((entry.external_attr >> 16) & 0xFFFF) or 0o644)
                require(target.stat().st_size == commitment["bytes"] and sdk["digest"](target) == commitment["sha256"],
                        "Original member bytes differ")
    require(sdk["inventory"](destination) == expected, "Restored original distribution differs")
    provenance_path = destination / "SourceProvenance/OriginalSource.json"
    provenance = json.loads(provenance_path.read_bytes())
    require(sdk["digest"](provenance_path) == config["original_source_sha256"]
            and provenance["application_source"] == producer["source_sha"]
            and provenance["original_trees"] == producer["source_trees"], "Original source provenance differs")
    for name, key in [("framework-distribution.json", "distribution_manifest_path"),
                      ("original-hanlin-snapshot.json", "hanlin_source_path"),
                      ("execution.json", "retained_execution_path")]:
        helpers["write_exact"](sdk["owned_path"](root, config[key], build=True), original[name])
    helpers["write_exact"](sdk["owned_path"](root, config["qualification_path"], build=True), qualification_raw)
    compiled_host_receipt(root, config, qualification, sdk)
    sdk["write"](evidence / "restoration.json", {
        "schema": 2, "continuation_kind": KIND,
        "status": "EXACT_ORIGINAL_PRODUCTS_AND_SEPARATE_SIGNED_CONSUMER_RUNTIME_RESTORED",
        "framework_producer": producer, "runtime_qualification_producer": runtime,
        "files": len(expected), "source_sha": producer["source_sha"],
        "qualification_sha256": config["qualification_sha256"], "native_editor_ui_tests": 0,
        "overwritten_inputs": 0, "framework_builds_performed": 0, "consumer_builds_performed": 0,
        "original_qualification_synthesized": False, "dotfile_repairs_performed": 0,
    })

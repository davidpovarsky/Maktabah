#!/usr/bin/env python3
"""One exact original Groups100 UI case on an owned, verified full-v40 install.

The original miniTest10 case and Native116/Release114 matrices are untouched.
The host reads actual app-PID Darwin RSS and original application operation logs.
It writes only observer acknowledgements, never application state or metrics.
"""
import argparse
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import plistlib
import re
import runpy
import secrets
import shutil
import stat
import sys
import threading
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
SELECTED = ["StudyGroupStressNativeAcceptanceTests/testOneHundredOriginalFullV40GroupSwitchesPreserveDocumentsAndColdRestore"]
PREFIX = "[NativeGroupSwitchPerformance] "
IDENTITY_KEYS = ("namespace", "sceneID", "profileID", "fromGroupID", "toGroupID", "fromDocumentID", "toDocumentID", "beforeRevision", "step")


def require(value, message):
    if not value:
        raise ValueError(message)


def canonical_uuid(value):
    require(isinstance(value, str) and len(value) == 36, "Expected a bounded UUID")
    return str(uuid.UUID(value)).upper()


def integer(value, minimum=0):
    return type(value) is int and value >= minimum


def matched_operation(rows, request, pid):
    """Same source identities/revision interval as original GroupStressMetricReader."""
    matches = []
    for row in rows:
        if row.get("namespace") != request["namespace"] or row.get("sceneID") != request["sceneID"]:
            continue
        if any(row.get(a) != request[b] for a, b in (
                ("fromGroupID", "fromGroupID"), ("toGroupID", "toGroupID"),
                ("observedGroupID", "toGroupID"), ("fromDocumentID", "fromDocumentID"),
                ("observedDocumentID", "toDocumentID"))):
            continue
        before, after = row.get("beforeRevision"), row.get("afterRevision")
        if not (integer(before) and integer(after) and request["beforeRevision"] <= before < after <= request["afterRevision"]):
            continue
        matches.append(row)
    require(len(matches) == 1, "Exactly one original operation must match the observed native transition")
    row = matches[0]
    require(type(row.get("schema")) is int and row["schema"] == 1 and row.get("returnedNormally") is True
            and row.get("processID") == pid and integer(row.get("sequence"), 1)
            and row.get("fromBackend") == row.get("observedBackend") == "otzaria"
            and row.get("timingScope") == "original group operation through ordinary session persistence"
            and row.get("memoryMetric") == "phys_footprint_bytes"
            and row.get("memoryScope") == "operation boundary samples; not continuous peak RSS"
            and integer(row.get("footprintBeforeBytes"), 1) and integer(row.get("footprintAfterBytes"), 1)
            and type(row.get("elapsedSeconds")) in (int, float)
            and math.isfinite(row["elapsedSeconds"]) and row["elapsedSeconds"] >= 0,
            "Original app operation, process or memory semantics are invalid")
    canonical_uuid(row.get("operationID")); canonical_uuid(row.get("launchID"))
    return row


def validate_cold_fields(proof, records, expected):
    require(isinstance(proof, dict) and type(proof.get("schema")) is int and proof["schema"] == 1,
            "Original cold proof schema is invalid")
    require(len(records) == 100, "Cold proof requires the complete native cohort")
    last = records[-1]
    for key, value in expected.items():
        require(proof.get(key) == value, "Cold proof changed " + key)
    pre, post = proof.get("preCold"), proof.get("postCold")
    require(isinstance(pre, dict) and isinstance(post, dict), "Both actual cold phases are required")
    require(integer(pre.get("processID"), 1) and integer(post.get("processID"), 1)
            and pre["processID"] == last["endSample"]["processID"]
            and post["processID"] != pre["processID"], "Cold launch did not prove a distinct original app PID")
    require(canonical_uuid(pre.get("requestID")) != canonical_uuid(post.get("requestID")),
            "The post-cold source observation reused the previous request")
    for phase in (pre, post):
        require(type(phase.get("observedUptime")) in (int, float) and math.isfinite(phase["observedUptime"])
                and phase["observedUptime"] >= 0 and isinstance(phase.get("sceneID"), str) and phase["sceneID"],
                "Actual original source-observer process/time/scene is missing")
        for key in ("profileID", "groupID", "documentID"):
            canonical_uuid(phase.get(key))
        require(integer(phase.get("workspaceRevision")), "Original cold workspace revision is missing")
    require(pre["sceneID"] == last["request"]["sceneID"]
            and pre["profileID"] == last["request"]["profileID"]
            and pre["groupID"] == last["request"]["toGroupID"]
            and pre["documentID"] == last["request"]["toDocumentID"]
            and pre["workspaceRevision"] >= last["request"]["afterRevision"]
            and post["workspaceRevision"] >= pre["workspaceRevision"], "Cold proof belongs to a different original owner/revision")
    require(isinstance(pre.get("canonicalLocator"), str) and 0 < len(pre["canonicalLocator"]) <= 8192,
            "Canonical native locator is missing")
    require(all(pre[key] == post[key] for key in ("profileID", "groupID", "documentID", "canonicalLocator")),
            "Cold launch changed actual group/document/locator ownership")
    return proof


def read_cold_proof(core, captures, udid, host, test_inputs, installation):
    manifest_path = captures / "manifest.json"
    manifest = core.bounded_json(manifest_path, 8_000_000)
    require(isinstance(manifest, list), "Actual xcresult export manifest must be a list")
    matches = []
    prefix = "groups100-v40-cold-process-and-installation-proof"
    pattern = re.compile(re.escape(prefix) + r"_[0-9]+_([0-9a-fA-F-]{36})\.json")
    for test in manifest:
        if test.get("testIdentifier", "").removesuffix("()") != SELECTED[0]:
            continue
        for attachment in test.get("attachments", []):
            match = pattern.fullmatch(attachment.get("suggestedHumanReadableName", ""))
            if match is None:
                continue
            canonical_uuid(match.group(1))
            require(attachment.get("deviceId", "").upper() == udid.upper(), "Cold proof belongs to another Simulator")
            name = attachment.get("exportedFileName")
            require(isinstance(name, str) and Path(name).name == name
                    and re.fullmatch(r"[0-9a-fA-F-]{36}\.json", name), "Exported cold proof filename is invalid")
            canonical_uuid(name.removesuffix(".json"))
            matches.append((attachment, captures / name))
    require(len(matches) == 1, "Exactly one original selected-case cold attachment is required")
    attachment, path = matches[0]
    proof = core.bounded_json(path, 65_536)
    expected = {"namespace": host.namespace, "catalogSHA256": test_inputs["catalog"]["sha256"],
                "databaseSHA256": installation["database"]["sha256"],
                "installationManifestSHA256": installation["installation_manifest"]["sha256"],
                "containerPath": str(host.container), "databasePath": str(host.container / host.database_relative)}
    validate_cold_fields(proof, host.records, expected)
    return {"proof": proof, "attachment": attachment, "file": core.witness(path),
            "export_manifest": core.witness(manifest_path),
            "scope": "Fresh original app source-observer PIDs/request IDs plus native locator and durable owner checks; source length and bounded native sample, not a full rendered-body digest"}


class GroupRSSHost(threading.Thread):
    def __init__(self, core, udid, container, out, installation):
        super().__init__(daemon=True)
        self.core, self.udid = core, udid
        self.container, self.out = Path(container).resolve(strict=True), Path(out)
        self.containers = self.container.parent
        self.documents = self.container / "Documents"
        self.database_relative = Path(installation["database"]["path"]).relative_to(self.container)
        self.expected_manifest = installation["installation_manifest"]
        self.expected_database_bytes = installation["database"]["bytes"]
        self.bound_container = None
        self.token, self.stop_event = secrets.token_hex(16), threading.Event()
        self.active, self.error, self.namespace = None, None, None
        self.records, self.seen = [], set()
        self.deadline = time.monotonic() + 2700

    def environment(self):
        return {"TEST_RUNNER_GROUPS100_V40_OBSERVER_TOKEN": self.token}

    def actual_sample(self):
        # Same original identity checks, bounded calls allow orderly observer stop.
        require(not self.stop_event.is_set(), "Observation was stopped")
        bundle = Path(self.core.command(["xcrun", "simctl", "get_app_container", self.udid,
                                        self.core.BUNDLE, "app"], timeout=8).stdout.strip()).resolve(strict=True)
        info = plistlib.loads(self.core.bounded_read(bundle / "Info.plist", 1_000_000))
        executable = str(bundle / info["CFBundleExecutable"])
        require(not self.stop_event.is_set(), "Observation was stopped")
        rows = self.core.command(["/bin/ps", "-ww", "-axo", "pid=,comm="], timeout=3).stdout.splitlines()
        matches = [int(parts[0]) for row in rows if len(parts := row.strip().split(None, 1)) == 2
                   and parts[0].isdigit() and parts[1] == executable]
        require(len(matches) == 1, "Exactly one actual installed original app PID is required")
        pid = matches[0]
        require(not self.stop_event.is_set(), "Observation was stopped")
        began = time.monotonic()
        fields = self.core.command(["/bin/ps", "-ww", "-p", str(pid), "-o", "pid=,rss=,time=,comm="],
                                   timeout=3).stdout.strip().split(None, 3)
        require(len(fields) == 4 and fields[0] == str(pid) and fields[1].isdigit() and fields[3] == executable,
                "Actual app PID/executable changed during RSS sample")
        sample = {"host_query_started_monotonic": began, "host_monotonic": time.monotonic(),
                  "host_wall_ns": time.time_ns(), "processID": pid, "rss_kib": int(fields[1]),
                  "cpu_time_reported": fields[2], "cpu_seconds": self.core.cpu_seconds(fields[2])}
        require(sample["rss_kib"] > 0, "Actual app RSS is unavailable")
        return sample, executable

    def admit_request_container(self, path):
        actual = Path(self.core.command(["xcrun", "simctl", "get_app_container", self.udid,
                                        self.core.BUNDLE, "data"], timeout=8).stdout.strip()).resolve(strict=True)
        require(actual.parent == self.containers and path.parent == actual / "Documents"
                and not actual.is_symlink() and not path.parent.is_symlink(),
                "Request is outside the actual same-device app data container")
        canonical_uuid(actual.name)
        metadata = actual / ".com.apple.mobile_container_manager.metadata.plist"
        require(plistlib.loads(self.core.bounded_read(metadata, 1_000_000)).get("MCMMetadataIdentifier") == self.core.BUNDLE,
                "Data container does not belong to the original app")
        if self.bound_container is not None:
            require(actual == self.bound_container, "Actual data container changed during 100 transitions")
            return
        require(self.active is None and not self.records, "Container can bind only before the first real transition")
        database = actual / self.database_relative
        require(database.is_file() and not database.is_symlink()
                and database.resolve(strict=True).is_relative_to(actual)
                and database.stat().st_size == self.expected_database_bytes, "Relocated managed database identity is invalid")
        manifest = self.core.witness(database.parent / "seforim-installation.json")
        require(all(manifest[k] == self.expected_manifest[k] for k in ("bytes", "sha256")),
                "Relocated production installation manifest changed")
        self.bound_container = actual
        self.core.write(self.out / "actual-request-container.json", {
            "original_container": str(self.container), "bound_container": str(actual),
            "changed_before_first_transition": actual != self.container,
            "metadata": self.core.witness(metadata), "database_relative_path": self.database_relative.as_posix(),
            "installation_manifest": manifest,
            "full_database_digest": "Host independently hashes before XCTest and after UI; native case verifies the pinned receipt plus actual manifest, size, SQL and source. No native whole-database hash is claimed."})
        self.container, self.documents = actual, actual / "Documents"

    def operation_rows(self):
        path = self.documents / "OtzariaLogs/otzaria-reader.log"
        fd = os.open(path, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW)
        try:
            before = os.fstat(fd)
            require(stat.S_ISREG(before.st_mode) and 0 < before.st_size <= 64 * 1024**2,
                    "Original reader log is not a bounded regular file")
            with os.fdopen(os.dup(fd), "rb") as stream:
                data = stream.read(before.st_size)
            after, at_path = os.fstat(fd), path.lstat()
            require((before.st_dev, before.st_ino) == (after.st_dev, after.st_ino) == (at_path.st_dev, at_path.st_ino)
                    and stat.S_ISREG(at_path.st_mode) and after.st_size >= before.st_size,
                    "Original log rotated or was replaced during observation")
        finally:
            os.close(fd)
        # The writer may append concurrently. Only complete original log lines.
        rows = []
        for line in data.splitlines(keepends=True):
            if not line.endswith(b"\n"):
                continue
            text = line.decode("utf-8", errors="strict")
            if PREFIX in text:
                row = json.loads(text.split(PREFIX, 1)[1])
                if row.get("namespace") == self.namespace:
                    rows.append(row)
        return rows

    def validate_request(self, request, name):
        require(isinstance(request, dict) and request.get("token") == self.token,
                "Observer token differs")
        nonce = canonical_uuid(request.get("nonce"))
        require(name == "groups100-v40-" + self.token + "-" + request["nonce"] + ".request.json",
                "Request file and nonce differ")
        require(nonce not in self.seen and request.get("operation") in ("begin", "end"),
                "Repeated nonce or unknown observation phase")
        require(integer(request.get("step"), 1) and request["step"] <= 100
                and integer(request.get("beforeRevision")), "Invalid step or revision")
        for key in ("namespace", "profileID", "fromGroupID", "toGroupID", "fromDocumentID", "toDocumentID"):
            canonical_uuid(request.get(key))
        require(isinstance(request.get("sceneID"), str) and 0 < len(request["sceneID"]) <= 512,
                "Actual scene identity is missing")
        require(request["fromGroupID"] != request["toGroupID"]
                and request["fromDocumentID"] != request["toDocumentID"],
                "Same-group or shared-document taps cannot count")
        if self.namespace is None:
            self.namespace = request["namespace"]
        require(request["namespace"] == self.namespace, "Workspace namespace changed")
        if request["operation"] == "end":
            require(integer(request.get("afterRevision")) and request["afterRevision"] > request["beforeRevision"],
                    "Original transition did not advance its durable revision")
        return nonce

    def handle(self, request):
        phase, step = request["operation"], request["step"]
        require(step == len(self.records) + 1, "Original transition order changed")
        if phase == "begin":
            require(self.active is None, "Overlapping group observations")
            sample, executable = self.actual_sample()
            if self.records:
                require(sample["processID"] == self.records[-1]["endSample"]["processID"],
                        "App PID changed inside the 100-step cohort")
            self.active = {"request": dict(request), "beginSample": sample, "executable": executable}
            operation_id = None
        else:
            require(self.active is not None and all(self.active["request"][k] == request[k] for k in IDENTITY_KEYS),
                    "End observation differs from its actual begin")
            sample, executable = self.actual_sample()
            require(sample["processID"] == self.active["beginSample"]["processID"]
                    and executable == self.active["executable"], "App process changed during original operation")
            deadline = time.monotonic() + 10
            while True:
                require(not self.stop_event.is_set(), "Observation was stopped")
                try:
                    metric = matched_operation(self.operation_rows(), request, sample["processID"])
                    break
                except (OSError, ValueError):
                    if time.monotonic() >= deadline:
                        raise
                    self.stop_event.wait(0.1)
            if self.records:
                previous = self.records[-1]["applicationMetric"]
                require(metric["sequence"] == previous["sequence"] + 1
                        and metric["launchID"] == previous["launchID"], "Original operation cohort is not contiguous")
            operation_id = metric["operationID"]
            require(operation_id not in {r["applicationMetric"]["operationID"] for r in self.records},
                    "Original operation was counted twice")
            record = {"step": step, "request": {k: v for k, v in request.items() if k != "token"},
                      "beginSample": self.active["beginSample"], "endSample": sample,
                      "executable": executable, "applicationMetric": metric}
            self.records.append(record); self.active = None
            self.core.write(self.out / "host-observations" / (str(step).zfill(3) + ".json"), record)
        ack = {"nonce": request["nonce"], "operation": phase, "step": step,
               "status": "ORIGINAL_APP_RSS_SAMPLE", "processID": sample["processID"],
               "rssBytes": sample["rss_kib"] * 1024, "hostMonotonic": sample["host_monotonic"]}
        if operation_id is not None:
            ack["operationID"] = operation_id
        return ack

    def run(self):
        try:
            while not self.stop_event.wait(0.05):
                require(time.monotonic() < self.deadline, "Owned Groups100 observation deadline exceeded")
                # XCTest may relocate the data container before launch. Locate our
                # exact token under this same device, then ask simctl for ownership.
                for path in sorted(self.containers.glob("*/Documents/groups100-v40-" + self.token + "-*.request.json")):
                    filename_nonce = path.name[len("groups100-v40-" + self.token + "-"):-len(".request.json")]
                    if filename_nonce.upper() in self.seen:
                        continue
                    request = self.core.bounded_json(path, 16_384)
                    if request.get("nonce", "").upper() in self.seen:
                        continue
                    nonce = self.validate_request(request, path.name)
                    self.admit_request_container(path)
                    ack = self.handle(request)
                    self.seen.add(nonce)
                    target = path.with_name(path.name.removesuffix(".request.json") + ".ack.json")
                    require(not target.exists() and not target.is_symlink(), "Observer ACK already exists")
                    self.core.write(target, ack)
                    retained = {"request": {k: v for k, v in request.items() if k != "token"}, "ack": ack}
                    self.core.write(self.out / "observer-ipc" / (nonce + ".json"), retained)
        except BaseException as error:
            self.error = type(error).__name__ + ": " + str(error).replace(self.token, "<redacted>")
            self.core.write(self.out / "observer-error.json", {"error": self.error})

    def stop(self):
        self.stop_event.set(); self.join(timeout=30)
        require(not self.is_alive(), "Owned RSS observer failed to stop")


def load_core():
    path = ROOT / "Scripts/CI/reader-full-v40-ui-observation.py"
    spec = importlib.util.spec_from_file_location("groups100_retained_v40", path)
    retained = importlib.util.module_from_spec(spec); spec.loader.exec_module(retained)
    return retained, retained.load_core()


def source_context(core, frozen):
    context = core.source_context(require_frozen=frozen)
    path = Path(__file__).resolve()
    relative = path.relative_to(ROOT).as_posix()
    if frozen:
        require(core.command(["git", "hash-object", str(path)]).stdout.strip() == core.git("rev-parse", "HEAD:" + relative),
                "Groups100 controller differs from the qualified checkout")
    context["groups100_controller"] = core.witness(path)
    context["executed_case_ids"] = SELECTED
    context["shared_profile_scope"] = "Full-v40 source/catalog admission only; the two Reader/Inspector cases are not executed by this controller"
    return context


def execute(args):
    require(sys.platform == "darwin", "Actual Apple Simulator required")
    retained, core = load_core()
    context = source_context(core, True)
    out = args.output.resolve()
    require(not out.exists(), "Never overwrite native Groups100 evidence")
    out.mkdir(parents=True)
    core.OUT = out
    config = json.loads(core.INPUTS.read_text())
    products, test_run, build = core.build_identity(context)
    sdk = core.command(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"]).stdout.strip()
    selected = os.environ.get("FAITHFUL_RUNTIME27_IDENTIFIER")
    runtimes = core.json_command(["xcrun", "simctl", "list", "runtimes", "available", "-j"])["runtimes"]
    runtimes = [r for r in runtimes if r.get("isAvailable") and r["identifier"] == selected
                and r["version"].split(".")[:2] == sdk.split(".")[:2] and r["version"].split(".")[0] == "27"]
    require(len(runtimes) == 1, "Explicit SDK-matched iPadOS27 runtime required")
    runtime = runtimes[0]
    types = [t for t in runtime["supportedDeviceTypes"] if "iPad Pro" in t["name"] and "13-inch" in t["name"]]
    owner = retained.RetainedV40Installation(core, args.owned_simulator, args.installation_result)
    udid, device_type, ownership = owner.admit_owner(config, runtime, types)
    image_bytes = sum(p.stat().st_size for name in ("Maktabah.app", "Maktabah-iOSUITests-Runner.app")
                      for p in (products / name).rglob("*") if p.is_file())
    budget = {"possible_app_runner_copy_bytes": image_bytes, "catalog_and_evidence_budget_bytes": 1024**3,
              "os_margin_bytes": 2_000_000_000, "other_reserved_bytes": args.reserved_other_bytes,
              "free_bytes": shutil.disk_usage(ROOT).free}
    require(budget["free_bytes"] >= image_bytes + 1024**3 + 2_000_000_000 + args.reserved_other_bytes,
            "Actual incremental Groups100 allocation and concurrent reservations do not fit")
    report = {"status": "STARTED_NOT_ACCEPTED", "source_before": context, "build_before": build,
              "runtime": runtime, "device_type": device_type, "capacity_before": budget, **ownership,
              "configuration": "Debug", "corpus_profile": "full-v40", "data_profile": "production",
              "selected_case_ids": SELECTED, "native116_acceptance": False, "release114_acceptance": False,
              "physical_device_acceptance": False, "performance_threshold_defined": False}
    host = database = installation = None
    failure = None
    post_failures = []
    try:
        core.command(["xcrun", "simctl", "boot", udid])
        core.command(["xcrun", "simctl", "bootstatus", udid, "-b"], timeout=900)
        core.command(["xcrun", "simctl", "install", udid, str(products / "Maktabah.app")], timeout=600)
        database, installation = owner.admit_current_installation(config, udid, build)
        catalog_dir, catalog = core.prepare_catalog(config, installation)
        container = Path(core.command(["xcrun", "simctl", "get_app_container", udid, core.BUNDLE, "data"]).stdout.strip()).resolve(strict=True)
        host = GroupRSSHost(core, udid, container, out, installation)
        environment = os.environ.copy()
        environment.update(host.environment())
        values = {"GROUPS100_V40_CATALOG_FILE": str(catalog_dir / "catalog.json"),
                  "GROUPS100_V40_CATALOG_SHA256": core.digest(catalog_dir / "catalog.json"),
                  "GROUPS100_V40_INSTALLATION_FILE": str(out / "actual-full-v40-installation.json"),
                  "GROUPS100_V40_INSTALLATION_SHA256": core.digest(out / "actual-full-v40-installation.json"),
                  "FAITHFUL_VIEWPORT_DIRECTORY": str(container / "Documents"), "SIMULATOR_UDID": udid,
                  "FAITHFUL_PRODUCTION_WORKSPACE_FILE": str(container / "Library/Application Support/ChavrusaText/StudyWorkspace/workspace-v1.json")}
        environment.update({"TEST_RUNNER_" + k: v for k, v in values.items()})
        report["test_inputs"] = {"catalog": core.witness(catalog_dir / "catalog.json"),
                               "installation": core.witness(out / "actual-full-v40-installation.json")}
        host.start()
        result_bundle = out / "groups100-full-v40.xcresult"
        command = ["xcodebuild", "test-without-building", "-xctestrun", str(test_run),
                   "-destination", "platform=iOS Simulator,id=" + udid, "-parallel-testing-enabled", "NO",
                   "-maximum-concurrent-test-simulator-destinations", "1", "-test-timeouts-enabled", "YES",
                   "-default-test-execution-time-allowance", "1800",
                   "-maximum-test-execution-time-allowance", "1800", "-resultBundlePath", str(result_bundle),
                   "-only-testing:Maktabah-iOSUITests/" + SELECTED[0]]
        log = out / "groups100-original-ui.log"
        report["xcodebuild_exit"] = core.bounded(command, log, 2400, environment)
        text = log.read_text(errors="replace").replace(host.token, "<redacted-observer-token>")
        log.write_text(text)
        strict = [sys.executable, "tools/verify_xcresult_zero_skips.py", "--xcresult", str(result_bundle),
                  "--log", str(log), "--scope", "focused-ui", "--expected-device", udid,
                  "--expected-os-major", "27", "--min-tests", "1", "--out", str(out / "zero-skip.json"),
                  "--required-case", SELECTED[0]]
        report["zero_skip_exit"] = core.command(strict, timeout=180, check=False).returncode
        declaration = runpy.run_path(str(ROOT / "Scripts/CI/verify-faithful-xctest.py"))["verify"](text, SELECTED, ROOT / "Maktabah-iOSUITests")
        core.write(out / "actual-test-cases.json", declaration)
        if result_bundle.is_dir():
            report["attachment_export_exit"] = core.command(["xcrun", "xcresulttool", "export", "attachments", "--path", str(result_bundle),
                          "--output-path", str(out / "captures")], timeout=300, check=False).returncode
        require(report["xcodebuild_exit"] == report["zero_skip_exit"] == 0 and declaration["status"] == "EXECUTED_PASS",
                "The exact production case must execute and pass without skips")
        require(host.error is None and host.active is None and len(host.records) == 100 and len(host.seen) == 200,
                "All 100 original operations require two actual app-PID RSS samples")
        require(report.get("attachment_export_exit") == 0, "Original native cold proof export failed")
        report["actual_cold_process_and_installation"] = read_cold_proof(
            core, out / "captures", udid, host, report["test_inputs"], installation)
        report["status"] = "ORIGINAL_FULL_V40_GROUPS100_UI_PASS_METRICS_OBSERVED"
    except BaseException as error:
        failure = error
        report.update(status="FAILED_OR_INCOMPLETE", error_type=type(error).__name__,
                      error=str(error).replace(host.token, "<redacted>") if host else str(error))
    finally:
        if host is not None:
            try:
                host.stop(); require(host.error is None, host.error or "Observer failed")
                core.write(out / "actual-operation-rss-observations.json", {
                    "scope": "Actual app operation metrics and Darwin RSS at 100 UI transition boundaries; no continuous peak or SLA",
                    "namespace": host.namespace, "count": len(host.records), "records": host.records})
                report["actual_observation_count"] = len(host.records)
                report["boundary_rss_bytes"] = core.percentiles([s[phase]["rss_kib"] * 1024 for s in host.records for phase in ("beginSample", "endSample")]) if host.records else None
            except Exception as error:
                post_failures.append("observer: " + type(error).__name__)
        if database is not None:
            try:
                database, relocation = owner.current_database(udid)
                report["database_after"] = core.witness(database)
                require(report["database_after"]["sha256"] == installation["database"]["sha256"]
                        and report["database_after"]["bytes"] == installation["database"]["bytes"], "Managed production corpus changed")
                report["current_installed_images_after_ui"] = owner.verify_installed_images(udid, build)
                report["original_installation_receipts_after"] = owner.verify_prior_receipts()
            except Exception as error:
                post_failures.append("installation: " + type(error).__name__)
        try:
            report["source_after"] = source_context(core, True)
            require(report["source_after"] == context, "Exact source changed during Groups100")
            require(core.build_identity(context)[2] == build, "Current app, test, SDK or runner images changed")
        except Exception as error:
            post_failures.append("source_build: " + type(error).__name__)
        if host is not None and host.is_alive():
            post_failures.append("observer_still_active_simulator_retained_without_shutdown")
        else:
            try:
                report["owned_cleanup"] = owner.retain_simulator(udid)
            except Exception as error:
                post_failures.append("retained_simulator: " + type(error).__name__)
        report["post_verification_failures"] = post_failures
        if post_failures:
            report["status"] = "FAILED_OR_INCOMPLETE"
        report["memory_scope"] = "Actual Simulator app PID Darwin RSS and original phys_footprint sampled separately at operation boundaries; not peak RSS or device acceptance"
        core.write(out / "RESULT.json", report)
    if failure is not None:
        raise failure
    require(not post_failures, "Post-execution identity or retention verification failed")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("phase", choices=["source-check", "execute"])
    parser.add_argument("--owned-simulator")
    parser.add_argument("--installation-result", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--reserved-other-bytes", type=int)
    args = parser.parse_args()
    if args.phase == "source-check":
        _, core = load_core()
        print(json.dumps({"status": "SOURCE_ONLY_NOT_UI", "source": source_context(core, False)}, indent=2))
        return
    require(args.owned_simulator and args.installation_result and args.output
            and args.reserved_other_bytes is not None and args.reserved_other_bytes >= 0,
            "Exact owner, prior installation receipt, new evidence directory and concurrent capacity reservation are required")
    execute(args)


if __name__ == "__main__":
    main()

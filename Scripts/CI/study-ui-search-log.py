#!/usr/bin/env python3
"""Own a bounded Simulator log capture for the original cold post-update R08.

This module observes the original app. It does not launch it, alter its provider,
write its trace, install data, or accept silence as proof of a submitted search.
The controller must first qualify the exact passed XCTest/exported attachment.
"""
import contextlib
import datetime as dt
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import shlex
import signal
import stat
import subprocess
import sys
import threading
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
CASE_ID = "Maktabah-iOSUITests/PublishedProductionSearchAfterBooksUpdateTests/testOriginalBooksUpdateRetainsV40PackagesButRejectsTheirReadinessAndQueries"
ATTACHMENT_STEM = "production-search-after-books-update-original-ui-and-trace-boundary"
MAX_RAW_BYTES = 16 * 1024 * 1024
MAX_STDERR_BYTES = 128 * 1024
MAX_LINE_BYTES = 128 * 1024
MAX_SECONDS = 2400
MAX_SAMPLE_GAP = 3.0
SUBMIT = re.compile(r"\[GlobalSearch\] submit revision=(\d+) generation=(\d+) backend=([a-z]+) scope=([a-z]+)\Z")
PS_ROW = re.compile(r"\s*(\d+)\s+(\d+)\s+([A-Za-z]{3}\s+[A-Za-z]{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2}\s+\d{4})\s+(.+)\Z")
REQUIRED_PAIRS = {
    "-OtzariaDataProfile": "production", "-preferredBackend": "otzaria",
    "-smokeBackend": "otzaria", "-GlobalSearchNativeTraceEnabled": "YES",
    "-lastSelectedTab": "0", "-ChavrusaTextFaithfulReaderUIEnabled": "YES",
    "-AppleLanguages": "(he)", "-AppleLocale": "he_IL",
}
FORBIDDEN = ("smokeBypassBootstrap", "smokeScenario", "studyWorkspaceTestingNamespace",
             "OTZARIA_SHARED_ROOT_OVERRIDE", "OTZARIA_PRODUCTION_DB_PATH")


def require(value, message):
    if not value:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def stamp(value):
    return (value.st_dev, value.st_ino, value.st_size, value.st_mtime_ns, value.st_ctime_ns)


def regular_bytes(path, maximum):
    path = Path(path)
    require(path.is_absolute() and path.resolve(strict=True) == path, "Evidence path is not canonical")
    before = path.lstat()
    require(stat.S_ISREG(before.st_mode) and before.st_size <= maximum, "Evidence is not a bounded regular file")
    with path.open("rb") as handle:
        require(stamp(os.fstat(handle.fileno())) == stamp(before), "Evidence changed before reading")
        raw = handle.read(maximum + 1)
        require(stamp(os.fstat(handle.fileno())) == stamp(before), "Evidence changed while reading")
    require(stamp(path.lstat()) == stamp(before) and len(raw) == before.st_size, "Evidence changed after reading")
    return raw, {"path": str(path), "bytes": len(raw), "sha256": digest(raw)}


def _pairs(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, "Duplicate JSON key: " + key)
        result[key] = value
    return result


def strict_json(raw):
    def invalid(value):
        raise ValueError("Non-finite JSON number: " + value)
    return json.loads(raw, object_pairs_hook=_pairs, parse_constant=invalid)


def unix_time(value, name):
    require(type(value) in (int, float) and math.isfinite(value) and value > 0, "Invalid timestamp: " + name)
    return float(value)


def log_time(value):
    require(isinstance(value, str), "Missing original log timestamp")
    parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    require(parsed.tzinfo is not None, "Log timestamp lacks an explicit timezone")
    return unix_time(parsed.timestamp(), "log timestamp")


def launch_scope(arguments, namespace):
    require(isinstance(arguments, list) and all(isinstance(v, str) and v and not any(c in v for c in "\x00\n\r") for v in arguments), "Invalid observed launch arguments")
    require(not any(word in argument for argument in arguments for word in FORBIDDEN), "A fixture or data override is present in the app command")
    for key, value in {**REQUIRED_PAIRS, "-GlobalSearchNativeTraceNamespace": namespace}.items():
        require(arguments.count(key) == 1, "Missing or repeated original launch option: " + key)
        index = arguments.index(key)
        require(index + 1 < len(arguments) and arguments[index + 1] == value, "Wrong original launch option: " + key)


def validate_attachment(value, *, udid, namespace):
    require(isinstance(value, dict) and type(value.get("schemaVersion")) is int and value["schemaVersion"] == 1, "Wrong native boundary schema")
    require(value.get("simulatorUDID") == udid and value.get("namespace") == namespace, "Native boundary belongs to another simulator or namespace")
    require(value.get("warmSameProcessUpdateVerified") is False and value.get("hostProcessLogGateRequired") is True, "Cold/host-required scope changed")
    require(type(value.get("sourceProcessID")) is int and value["sourceProcessID"] > 0, "Missing prior actual v40 PID")
    launch_scope(value.get("launchArguments"), namespace)
    environment = value.get("launchEnvironment")
    require(isinstance(environment, dict) and environment.get("OTZARIA_DATA_PROFILE") == "production"
            and environment.get("SIMCTL_CHILD_OTZARIA_DATA_PROFILE") == "production", "Native attachment does not retain production launch scope")
    require(not any(word in str(key) for key in environment for word in FORBIDDEN), "Native launch contains a data override")
    start = unix_time(value.get("launchStartedAtUnix"), "native launch")
    finish = unix_time(value.get("finishedAtUnix"), "native finish")
    require(start < finish and finish - start <= MAX_SECONDS, "Invalid native capture interval")
    attempts = value.get("attempts")
    require(isinstance(attempts, list) and len(attempts) == 2, "Need exactly two original query attempts")
    prior = start
    query_sha = digest("בראשית".encode("utf-8"))
    trace_identity = value.get("traceIdentity")
    require(isinstance(trace_identity, dict) and type(trace_identity.get("bytes")) is int and trace_identity["bytes"] > 0, "A positive existing trace prefix is required")
    require(re.fullmatch(r"[a-f0-9]{64}", value.get("traceSHA256", "")), "Missing exact trace digest")
    for index, (attempt, engine, scope) in enumerate(zip(attempts, ("otzaria", "zayit"), ("exact", "zayit")), 1):
        require(isinstance(attempt, dict) and attempt.get("engine") == engine
                and attempt.get("expectedLogScope") == scope
                and type(attempt.get("expectedSubmissionRevision")) is int
                and attempt["expectedSubmissionRevision"] == index, "Unexpected original query sequence")
        require(attempt.get("querySHA256") == query_sha and isinstance(attempt.get("visibleError"), str)
                and attempt["visibleError"], "Query or visible rejection is missing")
        times = [unix_time(attempt.get(k), k) for k in ("startedAtUnix", "submittedAtUnix", "rejectedAtUnix", "finishedAtUnix")]
        require(prior < times[0] <= times[1] <= times[2] < times[3] <= finish, "Original query times are not ordered")
        for key in ("traceOffsetBefore", "traceOffsetAfter"):
            require(type(attempt.get(key)) is int and attempt[key] == trace_identity["bytes"], "Trace offset changed during rejected query")
        require(attempt.get("traceSHA256Before") == attempt.get("traceSHA256After") == value["traceSHA256"], "Trace bytes changed during rejected query")
        prior = times[-1]
    return value


def parse_ndjson(raw):
    require(0 < len(raw) <= MAX_RAW_BYTES and raw.endswith(b"\n"), "Missing, oversized or truncated log stream")
    result = []
    for line in raw.splitlines():
        require(line and len(line) <= MAX_LINE_BYTES, "Empty or oversized NDJSON record")
        event = strict_json(line)
        require(isinstance(event, dict), "Log record is not an object")
        event_type = event.get("eventType")
        require(event_type in ("logEvent", "traceEvent"), "Dropped, loss, unknown or malformed log record")
        message = event.get("eventMessage")
        require(isinstance(message, str) and message, "Missing original log message")
        require(not any(term in message.lower() for term in ("dropped", "lost messages", "truncat")), "Log capture reports loss or truncation")
        require(type(event.get("processID")) is int and event["processID"] > 0, "Missing exact log PID")
        require(isinstance(event.get("processImagePath"), str) and Path(event["processImagePath"]).is_absolute(), "Missing exact log processImagePath")
        event["_observedUnix"] = log_time(event.get("timestamp"))
        result.append(event)
    return result


def parse_ps(raw):
    require(isinstance(raw, str) and len(raw.encode("utf-8")) <= 4 * 1024 * 1024, "Process inventory exceeds its bound")
    result = []
    for line in raw.splitlines():
        if not line.strip():
            continue
        match = PS_ROW.fullmatch(line)
        require(match is not None, "Unparseable original ps row")
        pid, ppid = int(match[1]), int(match[2])
        start = dt.datetime.strptime(match[3], "%a %b %d %H:%M:%S %Y").replace(tzinfo=dt.timezone.utc).timestamp()
        result.append({"pid": pid, "parentPID": ppid, "startTimeUTC": match[3], "startTimeUnixFloor": start, "command": match[4]})
    return result


def app_rows(rows, image):
    return [{**row, "processImagePath": image, "arguments": shlex.split(row["command"][len(image):].strip())}
            for row in rows if row["command"] == image or row["command"].startswith(image + " ")]


def owned_log_rows(rows, predicate):
    suffix = " stream --style ndjson --level debug --predicate " + predicate
    result = []
    for row in rows:
        command = row["command"]
        if command.endswith(suffix):
            executable = command[:-len(suffix)]
            if Path(executable).name == "log" and (executable.startswith("/") or executable == "log"):
                result.append(row)
    return result


def verify_capture(boundary, events, samples, capture):
    """Pure evidence gate; synthetic controls exercise it without native execution."""
    validate_attachment(boundary, udid=capture["simulatorUDID"], namespace=capture["namespace"])
    require(capture.get("errors") == [] and capture.get("unexpectedExit") is False, "Capture died or reported an observation failure")
    require(capture.get("rawTruncated") is False and capture.get("stderrClean") is True, "Capture was truncated or stderr was not clean")
    require(capture.get("cleanupVerified") is True, "Owned log process cleanup was not independently verified")
    ready = unix_time(capture.get("readyAtUnix"), "capture ready")
    stopped = unix_time(capture.get("stopRequestedAtUnix"), "capture stop")
    require(ready < boundary["launchStartedAtUnix"] and stopped >= boundary["finishedAtUnix"], "Capture does not enclose the complete original native case")
    require(stopped - capture["startedAtUnix"] <= MAX_SECONDS, "Capture exceeded its hard deadline")
    require(len(events) == 2, "Require exactly two submit records and no extra submissions or observation failures")
    pids = {event["processID"] for event in events}
    images = {event["processImagePath"] for event in events}
    require(len(pids) == len(images) == 1, "Submissions came from different PIDs or images")
    pid, image = next(iter(pids)), next(iter(images))
    require(pid != boundary["sourceProcessID"], "Cold case reused the original v40 process")
    submissions = []
    prior_generation = -1
    for event, attempt in zip(events, boundary["attempts"]):
        match = SUBMIT.fullmatch(event["eventMessage"])
        require(match is not None, "Unexpected message, failed trace write or malformed submission")
        revision, generation = int(match[1]), int(match[2])
        require(revision == attempt["expectedSubmissionRevision"] and match[3] == "otzaria"
                and match[4] == attempt["expectedLogScope"], "Observed revision/backend/scope differs from the original query")
        require(generation > 0 and generation > prior_generation, "Search generation did not advance")
        require(attempt["startedAtUnix"] <= event["_observedUnix"] <= attempt["rejectedAtUnix"], "Submission is outside its actual original UI attempt")
        submissions.append({"processID": pid, "processImagePath": image, "revision": revision,
                            "generation": generation, "backend": match[3], "scope": match[4],
                            "timestamp": event["timestamp"], "timestampUnix": event["_observedUnix"]})
        prior_generation = generation
    require(isinstance(samples, list) and len(samples) >= 3, "Process observation was not continuously sampled")
    previous = None
    for sample in samples:
        observed = unix_time(sample.get("observedAtUnix"), "process sample")
        require(sample.get("captureAlive") is True, "Log process was not alive throughout observation")
        require(sample.get("ownedLogAlive") is True, "Owned runtime log process disappeared")
        if previous is not None:
            require(0 < observed - previous <= MAX_SAMPLE_GAP, "Process observation has an unverified gap")
        previous = observed
    first_attempt = boundary["attempts"][0]["startedAtUnix"]
    last_finish = boundary["attempts"][-1]["finishedAtUnix"]
    prior_samples = [index for index, sample in enumerate(samples) if sample["observedAtUnix"] <= first_attempt]
    after_samples = [index for index, sample in enumerate(samples) if sample["observedAtUnix"] >= last_finish]
    require(prior_samples and after_samples, "Process samples do not enclose both complete attempts")
    # XCTest may release the app after the final native attachment. Only the
    # sampler/log process must remain alive past that final native timestamp.
    relevant = samples[prior_samples[-1]:after_samples[0]]
    if samples[after_samples[0]]["observedAtUnix"] == last_finish:
        relevant.append(samples[after_samples[0]])
    require(relevant and first_attempt - relevant[0]["observedAtUnix"] <= MAX_SAMPLE_GAP
            and last_finish - relevant[-1]["observedAtUnix"] <= MAX_SAMPLE_GAP, "App observation does not reach both query boundaries")
    identity = None
    for sample in relevant:
        rows = sample.get("appProcesses")
        require(sample.get("resolvedImagePath") == image and isinstance(rows, list) and len(rows) == 1, "Original app process/image ownership is ambiguous")
        row = rows[0]
        require(row.get("pid") == pid and row.get("processImagePath") == image, "App PID/image changed during original queries")
        launch_scope(row.get("arguments"), capture["namespace"])
        require(row["startTimeUnixFloor"] >= math.floor(boundary["launchStartedAtUnix"]), "Observed process predates the cold launch")
        key = (row["pid"], row["parentPID"], row["startTimeUTC"], row["command"])
        require(identity is None or key == identity, "App process identity/arguments changed during queries")
        identity = key
    return {"currentProcessID": pid, "processImagePath": image, "namespace": capture["namespace"],
            "submissions": submissions, "processIdentity": relevant[0]["appProcesses"][0],
            "processSamples": len(samples), "queryIntervalSamples": len(relevant),
            "maximumObservedSampleGapSeconds": max(b["observedAtUnix"] - a["observedAtUnix"] for a, b in zip(samples, samples[1:])),
            "scope": "Actual cold UI submissions and continuous bounded host log observation; no warm update, physical-offline or index-install acceptance"}


class SearchLogCapture:
    """One newly created Simulator log process; no Simulator/app lifecycle ownership."""

    def __init__(self, *, udid, output_dir, namespace, image_path_resolver, repository_root=ROOT):
        require(str(uuid.UUID(udid)).lower() == udid.lower(), "Invalid exact simulator UDID")
        require(str(uuid.UUID(namespace)).lower() == namespace.lower(), "Invalid existing native trace namespace")
        require(callable(image_path_resolver), "A real app-image resolver is required")
        self.udid, self.namespace = udid, namespace
        self.output = Path(output_dir)
        self.root = Path(repository_root).resolve(strict=True)
        self.resolver = image_path_resolver
        self.token = "R08_OWNED_LOG_" + uuid.uuid4().hex
        # The unique exact-message alternative is never emitted. It only makes
        # the runtime child's original command uniquely attributable for cleanup.
        self.predicate = ('eventMessage BEGINSWITH "[GlobalSearch] submit " OR '
                          'eventMessage BEGINSWITH "[GlobalSearchNativeObservation]" OR '
                          'eventMessage == "' + self.token + '"')
        self.process = None
        self.owned_log = None
        self.threads = []
        self.samples = []
        self.errors = []
        self.unexpected_exit = False
        self.truncated = False
        self.stop_event = threading.Event()
        self.started = None
        self.ready = None
        self.stop_requested = None
        self.cleanup_result = None
        self.cleanup_lock = threading.Lock()

    def _write(self, name, value):
        path = self.output / name
        require(not path.exists(), "Refusing to overwrite capture evidence")
        with path.open("x", encoding="utf-8") as handle:
            json.dump(value, handle, ensure_ascii=False, indent=2, allow_nan=False)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())

    def _ps(self):
        env = dict(os.environ, LC_ALL="C", TZ="UTC")
        result = subprocess.run(["/bin/ps", "-A", "-ww", "-o", "pid=,ppid=,lstart=,command="],
                                capture_output=True, text=True, timeout=2, env=env, check=True)
        require(not result.stderr.strip(), "ps emitted diagnostics")
        return parse_ps(result.stdout)

    def _image(self):
        value = self.resolver()
        require(isinstance(value, (str, Path)), "image_path_resolver must return one actual absolute Mach-O path")
        path = Path(value)
        require(path.is_absolute() and path.resolve(strict=True) == path and path.is_file(), "Resolved app image is missing or redirected")
        return str(path)

    def _drain(self, pipe, name, limit):
        try:
            count = 0
            with (self.output / name).open("xb") as output:
                while True:
                    block = pipe.read(65536)
                    if not block:
                        if name == "original-log.ndjson" and self.stop_requested is None and not self.stop_event.is_set():
                            self.errors.append("Original log stdout reached EOF before the requested capture stop")
                        break
                    if count + len(block) > limit:
                        output.write(block[:max(0, limit - count)])
                        self.truncated = True
                        self.errors.append(name + " exceeded its complete raw capture bound")
                        break
                    output.write(block)
                    count += len(block)
                output.flush()
                os.fsync(output.fileno())
        except Exception as error:
            self.errors.append(type(error).__name__ + ": " + str(error))
        finally:
            pipe.close()

    def _sample(self):
        image = self._image()
        rows = self._ps()
        logs = owned_log_rows(rows, self.predicate)
        require(len(logs) <= 1, "Multiple processes carry the owned runtime log command")
        if logs:
            key = (logs[0]["pid"], logs[0]["parentPID"], logs[0]["startTimeUTC"], logs[0]["command"])
            if self.owned_log is None:
                self.owned_log = logs[0]
            else:
                require(key == (self.owned_log["pid"], self.owned_log["parentPID"], self.owned_log["startTimeUTC"], self.owned_log["command"]), "Owned log PID/parent/start/command changed")
        sample = {"observedAtUnix": time.time(), "captureAlive": self.process.poll() is None,
                  "ownedLogAlive": bool(logs), "resolvedImagePath": image,
                  "appProcesses": app_rows(rows, image)}
        require(sample["captureAlive"], "Created log capture exited unexpectedly")
        if self.ready is not None:
            require(sample["ownedLogAlive"], "Owned runtime log process exited unexpectedly")
        self.samples.append(sample)
        return bool(logs)

    def _monitor(self):
        try:
            while not self.stop_event.wait(.4):
                require(time.monotonic() - self.started_monotonic <= MAX_SECONDS, "Capture hard deadline expired")
                self._sample()
                require(not self.truncated, "Raw log capture was truncated")
                require(not self.errors, "A raw capture reader failed")
        except Exception as error:
            self.errors.append(type(error).__name__ + ": " + str(error))
            if self.process.poll() is not None:
                self.unexpected_exit = True
            self.stop_event.set()
            # Bound a forgotten/failed capture without touching another owner.
            self._cleanup()

    def start(self):
        require(sys.platform == "darwin", "Native log capture requires the actual Apple host")
        require(self.process is None and self.started is None, "Capture was already started")
        require(self.output.is_absolute() and not self.output.exists()
                and self.output.parent.resolve(strict=True) == self.output.parent
                and self.output.is_relative_to(self.root / "build/artifacts"), "Use a fresh owned evidence directory under this checkout's build/artifacts")
        helper = self.root / "Scripts/CI/runtime27_interruption.py"
        source = self.root / "Scripts/CI/study-ui-search-log.py"
        sources = {}
        for path in (source, helper):
            raw, record = regular_bytes(path, 1_000_000)
            expected = subprocess.run(["git", "show", "HEAD:" + path.relative_to(self.root).as_posix()],
                                      cwd=self.root, capture_output=True, check=True, timeout=10).stdout
            require(raw == expected, "Capture source differs from the current committed checkout")
            sources[path.relative_to(self.root).as_posix()] = record
        spec = importlib.util.spec_from_file_location("owned_r08_interruption", helper)
        self.interruption = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.interruption)
        self.output.mkdir()
        self.started, self.started_monotonic = time.time(), time.monotonic()
        command = ["xcrun", "simctl", "spawn", self.udid, "log", "stream", "--style", "ndjson",
                   "--level", "debug", "--predicate", self.predicate]
        self.process = subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                        stderr=subprocess.PIPE, start_new_session=True, bufsize=0)
        try:
            self._write("LAUNCH.json", {"schemaVersion": 1, "caseID": CASE_ID, "simulatorUDID": self.udid,
                                       "namespace": self.namespace, "startedAtUnix": self.started,
                                       "ownedProcessGroup": self.process.pid, "command": command,
                                       "sources": sources, "rawByteLimit": MAX_RAW_BYTES,
                                       "deadlineSeconds": MAX_SECONDS, "ignoredDroppedEvents": False})
            for pipe, name, bound in ((self.process.stdout, "original-log.ndjson", MAX_RAW_BYTES),
                                      (self.process.stderr, "original-log.stderr", MAX_STDERR_BYTES)):
                thread = threading.Thread(target=self._drain, args=(pipe, name, bound), daemon=True)
                self.threads.append(thread)
                thread.start()
            deadline = time.monotonic() + 10
            while not self._sample():
                require(time.monotonic() < deadline, "Could not attribute the runtime log child")
                time.sleep(.1)
            self.ready = time.time()
            # Samples before the runtime log exists are startup, not continuous
            # coverage. The retained LAUNCH marks the earlier process creation.
            self.samples = [sample for sample in self.samples if sample["ownedLogAlive"]]
            self._write("READY.json", {"readyAtUnix": self.ready, "ownedRuntimeLog": self.owned_log,
                                       "resolvedImagePath": self.samples[-1]["resolvedImagePath"]})
            self.monitor = threading.Thread(target=self._monitor, daemon=True)
            self.monitor.start()
            return self
        except BaseException:
            self.stop_event.set()
            self._cleanup()
            raise

    def _cleanup(self):
        with self.cleanup_lock:
            return self._cleanup_locked()

    def _cleanup_locked(self):
        if self.cleanup_result is not None:
            return self.cleanup_result
        result = {"ownedRuntimeProcess": self.owned_log, "targetedSignals": []}
        if self.process is None:
            result["verified"] = False
            self.cleanup_result = result
            return result
        result["createdGroup"] = self.interruption.stop_owned_process_group(self.process, grace_seconds=1, kill_wait_seconds=.5)
        result["createdSubprocess"] = self.interruption.stop_owned_subprocess(self.process)
        try:
            for kind, allowance in ((signal.SIGINT, 1.0), (signal.SIGKILL, .5)):
                rows = owned_log_rows(self._ps(), self.predicate)
                if not rows:
                    break
                require(len(rows) == 1 and self.owned_log is not None, "Cannot attribute remaining runtime log process")
                current = rows[0]
                require((current["pid"], current["parentPID"], current["startTimeUTC"], current["command"])
                        == (self.owned_log["pid"], self.owned_log["parentPID"], self.owned_log["startTimeUTC"], self.owned_log["command"]), "Refusing to signal a changed process identity")
                os.kill(current["pid"], kind)
                result["targetedSignals"].append({"pid": current["pid"], "signal": int(kind), "identityRechecked": True})
                deadline = time.monotonic() + allowance
                while time.monotonic() < deadline:
                    if not owned_log_rows(self._ps(), self.predicate):
                        break
                    time.sleep(.05)
            result["remainingOwnedRuntimeProcesses"] = owned_log_rows(self._ps(), self.predicate)
            result["verified"] = (result["createdGroup"]["group_state"] == "GONE_CHECKED"
                                  and not result["remainingOwnedRuntimeProcesses"]
                                  and self.process.poll() is not None)
        except Exception as error:
            result["error"] = type(error).__name__ + ": " + str(error)
            result["verified"] = False
        self.cleanup_result = result
        return result

    def stop_and_verify(self, exported_attachment_path, *, expected_attachment_sha256):
        require(self.process is not None and self.ready is not None, "Capture never became ready")
        require(self.stop_requested is None, "Capture has already been stopped")
        self.stop_requested = time.time()
        if self.process.poll() is not None:
            self.unexpected_exit = True
        self.stop_event.set()
        self.monitor.join(timeout=4)
        if self.monitor.is_alive():
            self.errors.append("Process sampler did not terminate within its bound")
        cleanup = self._cleanup()
        for thread in self.threads:
            thread.join(timeout=3)
        if any(thread.is_alive() for thread in self.threads):
            self.errors.append("Raw capture reader remained active after owned cleanup")
        self._write("CLEANUP.json", cleanup)
        self._write("PROCESS_SAMPLES.json", self.samples)
        result = {"schemaVersion": 1, "status": "FAILED", "caseID": CASE_ID,
                  "simulatorUDID": self.udid, "namespace": self.namespace,
                  "startedAtUnix": self.started, "readyAtUnix": self.ready,
                  "stopRequestedAtUnix": self.stop_requested, "errors": list(self.errors),
                  "unexpectedExit": self.unexpected_exit, "rawTruncated": self.truncated,
                  "cleanupVerified": cleanup.get("verified") is True}
        try:
            raw, attachment = regular_bytes(exported_attachment_path, 2_000_000)
            require(re.fullmatch(r"[a-f0-9]{64}", expected_attachment_sha256 or "")
                    and attachment["sha256"] == expected_attachment_sha256, "Exported original native attachment changed")
            result["nativeAttachment"] = attachment
            boundary = strict_json(raw)
            result["lifecycleEvidence"] = {name: regular_bytes(self.output / name, 16 * 1024 * 1024)[1]
                                           for name in ("LAUNCH.json", "READY.json", "PROCESS_SAMPLES.json", "CLEANUP.json")}
            ndjson, result["rawLog"] = regular_bytes(self.output / "original-log.ndjson", MAX_RAW_BYTES)
            stderr, result["rawStderr"] = regular_bytes(self.output / "original-log.stderr", MAX_STDERR_BYTES)
            # No log-stream format warning, permission failure or loss notice is
            # silently waived. An unexpected real banner is retained and fails.
            result["stderrClean"] = not stderr.strip()
            events = parse_ndjson(ndjson)
            result["verified"] = verify_capture(boundary, events, self.samples, result)
            result["status"] = "ORIGINAL_COLD_R08_SUBMISSIONS_AND_LOG_SCOPE_VERIFIED"
        except Exception as error:
            result["failure"] = type(error).__name__ + ": " + str(error)
        finally:
            self._write("RESULT.json", result)
        require(result["status"] == "ORIGINAL_COLD_R08_SUBMISSIONS_AND_LOG_SCOPE_VERIFIED", result.get("failure", "Host search log gate failed"))
        return regular_bytes(self.output / "RESULT.json", 2_000_000)[1]

    def abort(self):
        """Controller finally hook: stop this capture even if XCTest/export fails."""
        self.stop_event.set()
        if hasattr(self, "monitor") and threading.current_thread() is not self.monitor:
            self.monitor.join(timeout=4)
        cleanup = self._cleanup()
        for thread in self.threads:
            thread.join(timeout=3)
        if self.output.exists() and not (self.output / "ABORTED.json").exists() and not (self.output / "RESULT.json").exists():
            self._write("ABORTED.json", {"status": "ABORTED_NO_UI_ACCEPTANCE", "cleanup": cleanup,
                                         "errors": self.errors, "unexpectedExit": self.unexpected_exit})
        return cleanup

#!/usr/bin/env python3
"""Separate full-v40 pending-fetch correctness observations, never PERF PASS.

The existing original host and passive collector supply source, image, MCM and
corpus admission. This module adds no product hook, delay, query, fixture, app
launch or input injection. Original XCTest actions remain the input producer.
"""
from __future__ import annotations

import importlib.util
from contextlib import contextmanager
import json
import math
import os
import shutil
import hashlib
import stat
import sys
from pathlib import Path
import re
import threading
import time
import uuid

SCHEMA = "otzaria.full-v40.pending-fetch-correctness/1"
SELECTOR = "Maktabah-iOSUITests/FullV40ReaderModeAcceptanceTests/testOriginalLargeChapterPendingFetchRemainsInteractiveAndRejectsSupersededContent"
COHORTS = ("overview", "unit-supersession", "backend-and-tab")
MAX_CAPTURES_PER_COHORT = 96
MAX_RAW_BYTES = 330 * 1024 * 1024
OUTPUT_RESERVATION_BYTES = 768 * 1024 * 1024
COMPILER_HELPER = "Scripts/CI/reader-v40-perbook-mode-performance.py"
SERVICE_SOURCE = "Source/Otzaria/Reading/OtzariaReadingUnitService.swift"
PRESENTATION_SOURCE = "Source/LibraryBackend/LibraryBackendModels.swift"
SOURCE_PATHS = (
    "Scripts/CI/study-ui-pending-sql.py",
    COMPILER_HELPER,
    "Maktabah-iOSUITests/Build8401SevenDefectsAcceptanceTests.swift",
    "docs/hq-integration/wave2-20261127/reader/FullV40ObservationCatalog.swift",
)


def require(value, reason):
    if not value:
        raise ValueError(reason)


def load_wait(root):
    path = Path(root) / "Scripts/CI/study-ui-sqlite-wait.py"
    spec = importlib.util.spec_from_file_location("pending_sql_original_wait_collector", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def allocated_bytes(directory):
    """Bounded metadata inventory of this helper's owned output only."""
    require(Path(directory).is_dir() and Path(directory).resolve(strict=True) == Path(directory),
            "Artifact budget requires the exact owned canonical directory")
    paths = list(Path(directory).rglob("*"))
    require(len(paths) <= 10000, "Owned pending artifact inventory exceeded its declared bound")
    total = 0
    for path in paths:
        value = path.lstat()
        require(not stat.S_ISLNK(value.st_mode) and (stat.S_ISREG(value.st_mode) or stat.S_ISDIR(value.st_mode)),
                "Owned output contains a redirected or unsupported artifact")
        total += max(value.st_size, value.st_blocks * 512) if stat.S_ISREG(value.st_mode) else value.st_blocks * 512
    return total


def verify_log(wait, record):
    """A successful original compiler can legitimately produce an empty log."""
    require(isinstance(record, dict) and set(record) == {"path", "bytes", "sha256"}, "Malformed actual log witness")
    require(type(record["bytes"]) is int and 0 <= record["bytes"] <= 64 * 1024 * 1024,
            "Actual log exceeds its bounded witness")
    if record["bytes"]:
        return wait.verify_witness(record, 64 * 1024 * 1024)
    path = wait.canonical(record["path"])
    fd = os.open(path, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW)
    try:
        before = os.fstat(fd)
        raw = os.read(fd, 1)
        after, located = os.fstat(fd), path.lstat()
        key = lambda value: (value.st_dev, value.st_ino, value.st_size, value.st_mtime_ns, value.st_ctime_ns)
        require(stat.S_ISREG(located.st_mode) and key(before) == key(after) == key(located)
                and before.st_size == 0 and raw == b"" and record["sha256"] == hashlib.sha256(b"").hexdigest(),
                "The actual empty compiler log changed")
        return raw
    finally:
        os.close(fd)


def admit_pending_catalog(wait, value, directory):
    """Validate complete actual source output, without recreating the service."""
    require(isinstance(value, dict) and type(value.get("schema")) is int and value["schema"] == 1
            and value.get("status") == "ORIGINAL_SOURCE_PENDING_SQL_MODES_ONLY_NOT_UI_OR_PERFORMANCE"
            and value.get("corpusProfile") == "full-v40" and value.get("databaseSHA256") == wait.DB_SHA
            and value.get("uiExecuted") == 0 and type(value["uiExecuted"]) is int
            and value.get("searchProviderExecuted") is False and value.get("performanceObserved") is False,
            "Require original source-only output, never a native or fabricated provider result")
    for name in ("sourceServiceSHA256", "presentationSourceSHA256", "catalogCompileInputsSHA256"):
        require(re.fullmatch(r"[a-f0-9]{64}", value.get(name, "")) is not None, "Actual source identity is missing")
    rows = value.get("targets")
    require(isinstance(rows, list) and len(rows) == 3 and {r.get("unitMode") for r in rows} == {"line", "paragraph", "chapter"},
            "All three complete original modes are required")
    references = {}
    for row in rows:
        require(row.get("bookID") == 8042 and row.get("focusLineIndex") == 26166
                and row.get("key") == "8042-pending-sql-" + row["unitMode"]
                and type(row.get("unitRowCount")) is int and row["unitRowCount"] > 0
                and row.get("allOriginalAnchorsChecked") == row["unitRowCount"]
                and type(row["allOriginalAnchorsChecked"]) is int
                and re.fullmatch(r"[a-f0-9]{64}", row.get("anchorsIdentitySHA256", "")),
                "Actual work, complete anchors or source mode identity changed")
        require(type(row.get("unitStartLineIndex")) is int and type(row.get("unitEndLineIndex")) is int
                and 0 <= row["unitStartLineIndex"] <= 26166 <= row["unitEndLineIndex"]
                and row.get("sectionLocator") == "otzaria|book:8042|line:" + str(row["unitStartLineIndex"])
                and row.get("focusLocator") == "otzaria|book:8042|line:26166", "Original canonical range identity changed")
        if row["unitMode"] == "line":
            require(row["unitRowCount"] == 1 and row["unitStartLineIndex"] == row["unitEndLineIndex"] == 26166,
                    "Original baseline must be the exact one-line unit")
        if row["unitMode"] == "chapter":
            require(row.get("unitID") == "toc:1948815" and row["unitRowCount"] == 52332
                    and row["unitStartLineIndex"] == 0 and row["unitEndLineIndex"] == 52331
                    and row.get("sourceUTF16Length") == 8307947,
                    "The actual large chapter cannot be truncated or reattributed")
        name = row.get("sourceFile")
        require(isinstance(name, str) and re.fullmatch(r"8042-[0-9]+-[0-9]+\.source\.utf8", name),
                "Unexpected or escaping original raw source filename")
        path = wait.canonical(Path(directory) / name)
        require(path.parent == Path(directory), "Complete source must stay in its own catalog")
        raw = wait.read(path, 64 * 1024 * 1024)
        require(type(row.get("sourceUTF8Bytes")) is int and row["sourceUTF8Bytes"] == len(raw)
                and row.get("sourceSHA256") == hashlib.sha256(raw).hexdigest()
                and type(row.get("sourceUTF16Length")) is int
                and row["sourceUTF16Length"] == len(raw.decode("utf-8").encode("utf-16-le")) // 2,
                "Complete original source bytes, UTF16 length or digest differ")
        references[row["key"]] = {"target": row, "reference": wait.witness(path, 64 * 1024 * 1024)}
    return references


@contextmanager
def owned_source_request(wait, path, request_id, lifetimes):
    """Hold actual fd/body ownership from creation through every fallible step.

    Any replacement or unprovable creation/retirement remains on disk, explicitly
    unverified. Evidence-directory/ENOSPC errors cannot skip this lifetime guard.
    """
    path = Path(path)
    expected = request_id.encode("ascii")
    require(len(expected) == 36, "Original passive request must be a UUID")
    wait.canonical_uuid(request_id)
    value = {"path": str(path), "requestID": request_id, "creationAttempted": False,
             "created": False, "bytesWritten": 0, "retirementVerified": False,
             "descriptorClosed": False, "error": None}
    lifetimes.append(value)
    descriptor = None
    try:
        value["creationAttempted"] = True
        descriptor = os.open(path, os.O_RDWR | os.O_CREAT | os.O_EXCL | os.O_CLOEXEC | os.O_NOFOLLOW, 0o600)
        value["created"] = True
        while value["bytesWritten"] < len(expected):
            wrote = os.write(descriptor, expected[value["bytesWritten"]:])
            require(type(wrote) is int and wrote > 0, "Original request write made no progress")
            value["bytesWritten"] += wrote
        yield value
    finally:
        cleanup_error = None
        try:
            if descriptor is None:
                # A creation attempt interrupted before fd assignment is not
                # declared harmless merely because no Python fd was retained.
                try:
                    path.lstat()
                except FileNotFoundError:
                    value["retirementVerified"] = True
                else:
                    raise ValueError("Creation outcome is unverified; never retire a possibly foreign request")
            else:
                before = os.fstat(descriptor)
                raw = os.pread(descriptor, len(expected) + 1, 0)
                after, located = os.fstat(descriptor), path.lstat()
                key = lambda item: (item.st_dev, item.st_ino, item.st_size, item.st_mtime_ns, item.st_ctime_ns)
                value["ownedFileIdentity"] = {"device": before.st_dev, "inode": before.st_ino,
                    "bytes": before.st_size, "mtimeNs": before.st_mtime_ns, "ctimeNs": before.st_ctime_ns}
                require(stat.S_ISREG(located.st_mode) and key(before) == key(after) == key(located)
                        and raw == expected[:value["bytesWritten"]] and before.st_size == value["bytesWritten"],
                        "Owned request inode/body changed; never retire a replacement")
                os.unlink(path)
                require(not path.exists() and not path.is_symlink(), "Request path was replaced during retirement")
                value["retirementVerified"] = True
        except BaseException as error:
            cleanup_error = error
            value["error"] = {"type": type(error).__name__, "message": str(error)}
        finally:
            if descriptor is not None:
                try:
                    os.close(descriptor); value["descriptorClosed"] = True
                except BaseException as error:
                    value["error"] = {"type": type(error).__name__, "message": str(error)}
                    cleanup_error = cleanup_error or error
            else:
                value["descriptorClosed"] = True
        if cleanup_error is not None:
            value["retirementVerified"] = False
            raise ValueError("Owned source-request cleanup is unverified; preserve simulator ownership") from cleanup_error


def writer_exit_verified(state):
    if state is None: return True
    worker = state.get("worker")
    if state.get("worker_start_attempted") and (worker is None or worker.ident is None):
        return False
    return worker is None or not worker.is_alive()


def join_owned_writer(state, *, timeout=5):
    worker = state.get("worker")
    if worker is not None and worker.ident is not None: worker.join(timeout=timeout)
    require(writer_exit_verified(state),
            "Passive writer start/exit is unverified; preserve simulator ownership")


def marker_sequence(cohort):
    return {"overview": ["chapter-request", "overview-action"],
            "unit-supersession": ["chapter-request", "overview-action", "unit-replacement"],
            "backend-and-tab": ["chapter-request", "overview-action", "tab-change", "backend-change"]}[cohort]


def required_markers(cohort):
    return set(marker_sequence(cohort))


def load_compiler(core):
    path = Path(core.ROOT) / COMPILER_HELPER
    spec = importlib.util.spec_from_file_location("pending_sql_original_catalog_compiler", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    require(module.ROOT == Path(core.ROOT), "Shared compiler belongs to another checkout")
    return module


def prepare_catalog(core, config, installation, directory, *, reserved_other_bytes):
    """One explicit actual source-only execution on the admitted installed DB.

    The integration owner calls this outside any UI/measurement epoch, after
    wait.bind_admission. Reuses the shared whole-source Swift compiler, never
    copies/reimplements the reading-unit algorithm or downloads/copies a DB.
    """
    require(sys.platform == "darwin" and core.CORPUS_NAME == "full-v40", "Actual catalog execution is Apple/full-v40 only")
    wait = load_wait(core.ROOT)
    admission = installation.get("sqlite_wait_admission")
    require(isinstance(admission, dict), "The original current-installation admission must precede source execution")
    # bind_admission attaches the byte-sealed FileWitness, not an arbitrary DB.
    actual = wait.decode(wait.verify_witness(admission, 8_000_000))
    require(actual["database"]["sha256"] == wait.DB_SHA
            and wait.identity(actual["database"]["path"]) == actual["database"]["identity"],
            "Only the exact currently admitted original installed corpus may be opened")
    directory = wait.canonical(directory, exists=False)
    require(not directory.exists() and type(reserved_other_bytes) is int and reserved_other_bytes >= 0,
            "Fresh owned output and an explicit concurrent storage reservation are required")
    wait.canonical(directory.parent, directory=True)
    require(shutil.disk_usage(directory.parent).free >= OUTPUT_RESERVATION_BYTES + reserved_other_bytes,
            "Complete original source outputs and pending raw evidence do not fit the declared reservation")
    source = wait.decode(wait.verify_witness(actual["source"], 8_000_000))
    for name in SOURCE_PATHS:
        ref = wait.witness(Path(core.ROOT) / name)
        require(source.get("execution_inputs", {}).get(name) == {key: ref[key] for key in ("bytes", "sha256")},
                "Actual frozen source closure omitted a pending producer input: " + name)
    directory.mkdir()
    report = {"schema": SCHEMA, "status": "STARTED_NOT_ACCEPTED", "admission": admission,
              "source": actual["source"], "uiExecuted": 0, "performanceObserved": False,
              "outputReservationBytes": OUTPUT_RESERVATION_BYTES, "reservedOtherBytes": reserved_other_bytes}
    try:
        compiled = load_compiler(core).compile_original_catalog(core, config, directory)
        report["compiled"] = compiled
        value = {"databaseURI": installation["uri"], "databaseSHA256": wait.DB_SHA,
                 "v40Targets": config["catalog_targets"], "pendingSQLModes": True,
                 "sourceService": compiled["sourceService"], "presentationSource": compiled["presentationSource"]}
        input_ref = wait.seal(directory / "input.json", value)
        command = [compiled["binary"]["path"], input_ref["path"], str(directory)]
        code = core.bounded(command, directory / "execution.log", 600)
        report.update(command=command, input=input_ref, executionExit=code,
                      executionLog=core.witness(directory / "execution.log"))
        require(code == 0, "The actual original source failed; keep the complete failed output")
        catalog = wait.decode(wait.read(directory / "pending-sql-modes.json", 8_000_000))
        report["catalog"] = wait.witness(directory / "pending-sql-modes.json", 8_000_000)
        report["completeOriginalSources"] = admit_pending_catalog(wait, catalog, directory)
        require(wait.identity(actual["database"]["path"]) == actual["database"]["identity"],
                "Admitted corpus changed during original source execution")
        report["status"] = "ORIGINAL_SOURCE_PENDING_SQL_MODES_EXECUTED_NOT_UI_OR_PERFORMANCE"
        return catalog
    except Exception as error:
        report.update(status="FAILED_NOT_QUALIFIED", errorType=type(error).__name__, error=str(error))
        raise
    finally:
        wait.seal(directory / "execution-result.json", report)


def overview_visible(viewport):
    rows = viewport.get("overviewPresentations")
    require(isinstance(rows, list) and len(rows) <= 16, "Original overview observation is absent or unbounded")
    return any(row.get("wantsOverview") is True and row.get("isViewLoaded") is True
               and row.get("isInWindow") is True and row.get("hasHostingController") is True
               and isinstance(row.get("presentedClass"), str) and row["presentedClass"]
               for row in rows if isinstance(row, dict))


def operation_identity(row):
    return {key: row[key] for key in ("sequence", "operationID", "connectionID", "beginNanoseconds",
                                    "nativeThreadID", "mainThread")}


def evaluate_overlap(wait, baseline, captures, final, database, cohort, marker_records):
    """Correlate real retained captures. No resource epoch or metrics invented.

    Each response is sampled on the original MainActor before the companion is
    generated. A changed original overview plus the identical still-active
    operation can prove processed UI overlap. HID/IPC/tap timestamps cannot.
    """
    result = {"schema": SCHEMA, "status": "NOT_QUALIFIED", "cohort": cohort,
              "reasons": [], "fullPerformanceAcceptance": False,
              "resourceEpochCoverage": "NOT_APPLICABLE_SEPARATE_INSTRUMENTED_CORRECTNESS_WORKLOAD",
              "exactSQLSteppingOrMappingAttribution": "NOT_QUALIFIED_REQUIRES_ACTUAL_MATCHING_THREAD_TRACE",
              "sqlStatementOrBookAttribution": "NOT_AVAILABLE_IN_ORIGINAL_PASSIVE_SCHEMA",
              "cancellationExceptionClassification": "NOT_AVAILABLE_TASK_FLAG_IS_NOT_EXCEPTION_TYPE"}
    reasons = result["reasons"]
    if baseline is None or final is None:
        reasons.append("ACTUAL_BASELINE_OR_FINAL_CAPTURE_MISSING")
        return result
    a, b = baseline["snapshot"], final["snapshot"]
    if ((baseline.get("sourceComparison") or {}).get("mode") != "line"
            or (final.get("sourceComparison") or {}).get("mode") != ("chapter" if cohort == "overview" else "line")):
        reasons.append("ORIGINAL_BASELINE_OR_FINAL_MODE_COMPARISON_MISSING")
    if baseline["identity"] != final["identity"] or a["processID"] != b["processID"]:
        reasons.append("CURRENT_IMAGE_CORPUS_OWNER_OR_PROCESS_CHANGED")
    counters = ("lifetimeDropped", "lifetimeDroppedForActiveCapacity", "lifetimeDroppedForConnectionCapacity",
                "lifetimeUnmatchedCompletions")
    if a["counterOverflowed"] or b["counterOverflowed"] or any(a[key] or b[key] for key in counters):
        reasons.append("DROPS_OR_OVERFLOW_CAN_HIDE_UNTRACKED_OPERATIONS")
    if a["active"] or b["active"]:
        reasons.append("PENDING_OPERATIONS_AT_BASELINE_OR_FINAL")
    if overview_visible(baseline["viewport"]):
        reasons.append("OVERVIEW_WAS_ALREADY_VISIBLE_AT_BASELINE")
    count = b["lifetimeStarted"] - a["lifetimeStarted"]
    rows = [row for row in b["completed"] if row["sequence"] > a["lifetimeStarted"]]
    if not (0 <= count <= 1024 and len(rows) == count
            and [row["sequence"] for row in rows] == list(range(a["lifetimeStarted"] + 1, b["lifetimeStarted"] + 1))
            and b["lifetimeFinished"] - a["lifetimeFinished"] == count):
        reasons.append("NEW_OPERATION_TERMINALS_MISSING_OR_OVERWRITTEN")
    terminals = {row["operationID"]: row for row in rows}
    connections = {row["connectionID"]: row for row in b["connections"]}
    armed = next((row.get("armedOperation") for row in captures if row.get("armedOperation")), None)
    if not armed:
        reasons.append("NO_ACTUAL_PERSISTING_NEW_V40_FETCH_WAS_ARMED")
        return result
    terminal = terminals.get(armed["operationID"])
    if not terminal or operation_identity(terminal) != armed:
        reasons.append("EXACT_ARMED_OPERATION_HAS_NO_RETAINED_TERMINAL")
        return result
    if terminal["nativeThreadID"] is None or not wait.connection_matches_corpus(connections[terminal["connectionID"]], database):
        reasons.append("ARMED_OPERATION_THREAD_OR_OPENED_V40_IDENTITY_UNAVAILABLE")
    by_request = {row["snapshot"]["requestID"]: row for row in captures}
    if len(by_request) != len(captures):
        reasons.append("ACTUAL_CAPTURE_REQUEST_WAS_REUSED")
    chapter_markers = [row for row in marker_records if row["event"] == "chapter-request"]
    overview_markers = [row for row in marker_records if row["event"] == "overview-action"]
    chapter_clock = chapter_markers[0].get("hostObservedBeforeOriginalUIRequest", {}) if len(chapter_markers) == 1 else {}
    overview_clock = overview_markers[0].get("hostObservedBeforeOriginalUIRequest", {}) if len(overview_markers) == 1 else {}
    chapter_after = chapter_clock.get("machUpperNs")
    overview_before, overview_after = overview_clock.get("machLowerNs"), overview_clock.get("machUpperNs")
    if type(chapter_after) is not int or chapter_after > armed["beginNanoseconds"]:
        reasons.append("ARMED_FETCH_PREDATES_OR_LACKS_THE_REAL_CHAPTER_REQUEST")
    timing_valid = type(overview_before) is int and type(overview_after) is int and overview_before <= overview_after
    prior = [row for row in captures if timing_valid and row["snapshot"]["snapshotNanoseconds"] <= overview_before
             and any(operation_identity(op) == armed for op in row["snapshot"]["active"])]
    if len({row["snapshot"]["requestID"] for row in prior}) < 2:
        reasons.append("PERSISTING_OPERATION_NEEDS_TWO_DISTINCT_ACTUAL_PENDING_OBSERVATIONS_BEFORE_THE_ACTION")
    overview_fence = by_request.get(overview_markers[0].get("freshPendingRequestID")) if len(overview_markers) == 1 else None
    if not overview_fence or overview_visible(overview_fence["viewport"]):
        reasons.append("OVERVIEW_WAS_NOT_HIDDEN_AT_ITS_FRESH_PRE_ACTION_FENCE")
    candidates = []
    for capture in captures:
        snapshot, viewport = capture["snapshot"], capture["viewport"]
        if capture["identity"] != baseline["identity"] or snapshot["processID"] != a["processID"]:
            reasons.append("MID_CAPTURE_OWNER_OR_PROCESS_CHANGED")
            continue
        active = next((row for row in snapshot["active"] if operation_identity(row) == armed), None)
        if active and overview_visible(viewport):
            stamp = snapshot["snapshotNanoseconds"]
            if (terminal["acquiredNanoseconds"] is not None
                    and timing_valid and overview_after <= stamp
                    and terminal["acquiredNanoseconds"] <= stamp < terminal["terminalNanoseconds"]
                    and capture.get("sourceComparison") is not None):
                candidates.append(capture)
    if not candidates:
        reasons.append("NO_CHANGED_ORIGINAL_UI_RESPONSE_WHILE_THE_IDENTICAL_ACQUIRED_FETCH_REMAINED_ACTIVE")
    result.update(armedOperation=armed, actualTerminal=terminal,
                  changedUIOverlapRequests=[row["snapshot"]["requestID"] for row in candidates],
                  observedNewFetches=len(rows),
                  otherConnectionSequences=[row["sequence"] for row in rows
                      if not wait.connection_matches_corpus(connections[row["connectionID"]], database)],
                  instrumentedProbeCount=len(captures),
                  markers=marker_records)
    # Markers prove an observed pending state immediately before an original UI
    # request. They deliberately do not timestamp input processing or an error
    # class. Actual native replacement/source checks remain in XCTest.
    required = required_markers(cohort)
    names = {row["event"] for row in marker_records}
    if names != required or [row["event"] for row in marker_records] != marker_sequence(cohort):
        reasons.append("DECLARED_NATIVE_ACTION_MARKER_MISSING_OR_DUPLICATED")
    fences = [row.get("freshPendingRequestID") for row in marker_records if row["event"] != "chapter-request"]
    if len(set(fences)) != len(fences):
        reasons.append("DECLARED_ACTIONS_REUSE_ONE_FRESH_PENDING_FENCE")
    for marker in marker_records:
        if marker["event"] == "chapter-request":
            continue
        fence = by_request.get(marker.get("freshPendingRequestID"))
        mark_time = marker.get("hostObservedBeforeOriginalUIRequest", {}).get("machLowerNs")
        if (not fence or marker.get("armedOperation") != armed
                or not any(operation_identity(row) == armed for row in fence["snapshot"]["active"])
                or type(mark_time) is not int
                or not (armed["beginNanoseconds"] <= fence["snapshot"]["snapshotNanoseconds"]
                        <= mark_time < terminal["terminalNanoseconds"])):
            reasons.append("DECLARED_ACTION_HAS_NO_FRESH_SAME_OPERATION_PENDING_FENCE")
    if cohort == "unit-supersession" and not (terminal["taskCancelledAtTerminal"] and not terminal["returnedNormally"]):
        reasons.append("ARMED_FETCH_DID_NOT_REPORT_CANCELLED_NON_NORMAL_TERMINATION")
    if reasons:
        result["reasons"] = sorted(set(reasons))
        return result
    result["status"] = "ACTUAL_PENDING_FETCH_UI_OVERLAP_OBSERVED_NATIVE_SEMANTIC_VERIFICATION_REQUIRED"
    result["scope"] = ("Original changed UIKit overview observed while the same acquired full-v40 fetch was active; "
                       "subsequent terminal retained. Source/selection/tab/backend outcomes must pass the exact native case. "
                       "No SQL-statement, MainActor-duration, latency, throughput, clean resource epoch or PERF claim.")
    return result


class PendingRecorder:
    def __init__(self, core, host, pending_dir, pending_catalog):
        self.core, self.host = core, host
        self.wait = load_wait(core.ROOT)
        require(core.CORPUS_NAME == "full-v40", "Standalone pending work is production v40 only")
        self.collector = getattr(host, "sqlite_wait_collector", None)
        require(self.collector is not None, "Compose after the actual separately admitted passive collector")
        self.collector._check_identity(process=False)
        self.clock = self.collector.clock
        self.admission = self.collector.admission
        self.out = self.wait.canonical(Path(core.OUT), directory=True) / "pending-fetch-correctness"
        require(not self.out.exists(), "Never overwrite a prior pending-fetch run")
        self.out.mkdir()
        # Preserve the exact admitted metadata before UI. Historical proof must
        # not depend on an old MCM pathname surviving a later legitimate move.
        self.manifest_copy_ref = self.wait.write_new(self.out / "admitted-installation-manifest.json",
            self.wait.verify_witness(self.admission["installationManifest"], 131072))
        self.pending_dir = self.wait.canonical(Path(pending_dir), directory=True)
        self.catalog_file = self.pending_dir / "pending-sql-modes.json"
        raw = self.wait.read(self.catalog_file, 8_000_000)
        require(self.wait.decode(raw) == pending_catalog, "Use the actual immutable separate catalog bytes")
        self.catalog_ref = self.wait.witness(self.catalog_file, 8_000_000)
        self.catalog = pending_catalog
        validated_references = admit_pending_catalog(self.wait, pending_catalog, self.pending_dir)
        require(pending_catalog.get("schema") == 1
                and pending_catalog.get("status") == "ORIGINAL_SOURCE_PENDING_SQL_MODES_ONLY_NOT_UI_OR_PERFORMANCE"
                and pending_catalog.get("corpusProfile") == "full-v40"
                and pending_catalog.get("databaseSHA256") == self.wait.DB_SHA,
                "Do not substitute a preview-provider, v32, fixture or fabricated mode catalog")
        modes = pending_catalog.get("targets")
        require(isinstance(modes, list) and len(modes) == 3 and {row["unitMode"] for row in modes} == {"line", "paragraph", "chapter"},
                "Exactly three complete original measured-work modes are required")
        self.targets = {row["unitMode"]: row for row in modes}
        require(all(row["bookID"] == 8042 and row["focusLineIndex"] == 26166 for row in modes), "Actual measured-work identity changed")
        chapter = self.targets["chapter"]
        require(chapter["unitID"] == "toc:1948815" and chapter["unitRowCount"] == 52332
                and chapter["unitStartLineIndex"] == 0 and chapter["unitEndLineIndex"] == 52331
                and chapter["sourceUTF16Length"] == 8307947,
                "The real complete measured chapter cannot be truncated or reattributed")
        self.references = validated_references
        self.catalog_allocated_bytes = allocated_bytes(self.pending_dir)
        require(self.catalog_allocated_bytes + 8 * 1024 * 1024 <= OUTPUT_RESERVATION_BYTES,
                "Actual compiler/source artifacts already exhausted the declared pending output reservation")
        source = self.wait.decode(self.wait.verify_witness(self.admission["source"], 8_000_000))
        self.source_inputs = {}
        for name in SOURCE_PATHS:
            record = self.wait.witness(Path(core.ROOT) / name)
            require(source.get("execution_inputs", {}).get(name) == {key: record[key] for key in ("bytes", "sha256")},
                    "Pending workload input is missing from actual frozen source closure: " + name)
            self.source_inputs[name] = record
        compile_path = self.pending_dir / "compile-inputs.json"
        self.compile_ref = self.wait.witness(compile_path, 8_000_000)
        require(self.compile_ref["sha256"] == pending_catalog.get("catalogCompileInputsSHA256"), "Actual catalog compilation receipt differs")
        compiled = self.wait.decode(self.wait.verify_witness(self.compile_ref, 8_000_000))
        compiled_sources = compiled.get("source_sha256")
        require(isinstance(compiled_sources, dict) and 0 < len(compiled_sources) <= 64, "Original catalog compile sources absent")
        for name, digest in compiled_sources.items():
            require(not Path(name).is_absolute() and ".." not in Path(name).parts, "Escaping catalog source input")
            require(self.wait.witness(Path(core.ROOT) / name)["sha256"] == digest, "Catalog was compiled against different current source")
        require(compiled_sources.get(SOURCE_PATHS[-1]) == self.source_inputs[SOURCE_PATHS[-1]]["sha256"],
                "Current actual catalog main source was not compiled")
        for field, name in (("sourceServiceSHA256", SERVICE_SOURCE), ("presentationSourceSHA256", PRESENTATION_SOURCE)):
            require(pending_catalog.get(field) == compiled_sources.get(name)
                    == self.wait.witness(Path(core.ROOT) / name)["sha256"],
                    "Original complete service/presentation source was not compiled")
        self.execution_ref = self.wait.witness(self.pending_dir / "execution-result.json", 8_000_000)
        executed = self.wait.decode(self.wait.verify_witness(self.execution_ref, 8_000_000))
        require(executed.get("schema") == SCHEMA
                and executed.get("status") == "ORIGINAL_SOURCE_PENDING_SQL_MODES_EXECUTED_NOT_UI_OR_PERFORMANCE"
                and executed.get("executionExit") == 0 and type(executed["executionExit"]) is int
                and executed.get("admission") == self.collector.admission_ref
                and executed.get("source") == self.admission["source"]
                and executed.get("catalog") == self.catalog_ref,
                "Actual same-installation source execution receipt is absent or unsuccessful")
        compile_result = self.wait.decode(self.wait.verify_witness(executed["compiled"]["compileResult"], 8_000_000))
        require(compile_result.get("exit") == 0 and type(compile_result["exit"]) is int
                and compile_result.get("inputs") == self.compile_ref
                and executed["compiled"]["compileInputs"] == self.compile_ref,
                "Actual compiler success/input witness is absent")
        for record in (compile_result["log"], executed["executionLog"]): verify_log(self.wait, record)
        self.wait.verify_witness(executed["compiled"]["binary"], 64 * 1024 * 1024)
        require(executed.get("completeOriginalSources") == self.references,
                "The actual execution did not retain the same complete original source witnesses")
        original_input = self.wait.decode(self.wait.verify_witness(executed["input"], 8_000_000))
        require(original_input.get("databaseURI") == self.host.installation["uri"]
                and original_input.get("databaseSHA256") == self.wait.DB_SHA
                and original_input.get("pendingSQLModes") is True
                and "previewTargets" not in original_input and "readerModeMatrix" not in original_input
                and executed["command"] == [executed["compiled"]["binary"]["path"], executed["input"]["path"], str(self.pending_dir)],
                "Actual source invocation used another corpus, algorithm mode or output")
        self.lock = threading.RLock()
        self.active = None
        self.results = []
        self.seen_pids = set()
        self.total_bytes = 0
        self.request_lifetimes = []
        self.complete = None
        self.finalized = False
        self.wait.seal(self.out / "INPUTS.json", {"schema": SCHEMA, "admission": self.collector.admission_ref,
            "hostClock": self.collector.clock_ref,
            "installationManifestCopy": self.manifest_copy_ref,
            "catalog": self.catalog_ref, "compileInputs": self.compile_ref, "execution": self.execution_ref, "sourceInputs": self.source_inputs,
            "sourceReferences": self.references, "selector": SELECTOR, "cohorts": list(COHORTS),
            "resourceEpochs": 0, "performanceAcceptance": False})

    def environment(self):
        return {"TEST_RUNNER_PENDING_SQL_MODES_CATALOG": str(self.catalog_file),
                "TEST_RUNNER_PENDING_SQL_MODES_CATALOG_SHA256": self.catalog_ref["sha256"],
                "TEST_RUNNER_PRODUCTION_SEARCH_CONTAINER_PARENT": str(Path(self.admission["owner"]["dataContainer"]).parent)}

    def idle(self):
        require(self.host.active is None and self.host.pending_inspector is None,
                "Pending correctness cannot overlap original resource or Inspector fences")

    def _source(self, viewport, expected_mode=None):
        sample = viewport.get("fullV32SourceObservation", {})
        require(sample.get("status") == "AVAILABLE", "Original mounted source sample is unavailable")
        matches = []
        for key, record in self.references.items():
            target = record["target"]
            native = viewport.get("nativeSelectionObservation", {})
            if (native.get("schema") != 1 or native.get("status") not in ("EMPTY", "AVAILABLE")
                    or native.get("requestID") != viewport.get("requestID")
                    or native.get("processID") != sample.get("processID")
                    or native.get("locator") != target["sectionLocator"]):
                continue
            if target["sourceUTF16Length"] != sample.get("sourceUTF16Length"):
                continue
            self.wait.verify_witness(record["reference"], 64 * 1024 * 1024)
            try:
                proof = self.core.exact_source_comparison(self.pending_dir, target, viewport)
            except (ValueError, AssertionError):
                continue
            matches.append({"key": key, "mode": target["unitMode"], "sourceSHA256": record["reference"]["sha256"],
                            "originalComparison": proof})
        # The caller may have navigated to another original backend or tab.
        # Unknown source does not become fabricated body equality. A later
        # original-mode final proof is still mandatory for qualification.
        # Original paragraph and line may legitimately have identical unit
        # boundaries/body. Do not invent a requirement that they differ. The
        # native case independently checks the persisted original UI mode;
        # this comparator establishes source identity/length/bounded slice.
        if expected_mode is not None:
            eligible = [row for row in matches if row["mode"] == expected_mode]
            return {**eligible[0], "matchingOriginalModes": [row["mode"] for row in matches]} if len(eligible) == 1 else None
        if len(matches) == 1: return matches[0]
        if matches:
            return {"mode": None, "matchingOriginalModes": [row["mode"] for row in matches],
                    "originalComparisons": matches,
                    "scope": "Actual bounded source matches these complete original units; source equality alone cannot identify the UI mode"}
        return None

    def _write_status(self, state):
        requests_retired = all(row["retirementVerified"] and row["descriptorClosed"] for row in self.request_lifetimes)
        value = {"schema": SCHEMA, "cohortID": state["id"], "cohort": state["name"],
                 "processID": state["identity"]["processID"], "captures": len(state["captures"]),
                 "armedOperation": state.get("armed"), "changedWhilePending": bool(state.get("overlap")),
                 "terminalObserved": state.get("terminalObserved"),
                 "watcherStopped": state.get("watcherStopped", False) and requests_retired and state.get("error") is None,
                 "watcherLoopEnded": state.get("watcherStopped", False), "ownedRequestRetirementVerified": requests_retired,
                 "error": state.get("error"), "scope": "Live provisional observation; final terminal/identity/native checks are still required"}
        tmp = state["status_path"].with_name(state["status_path"].name + "." + uuid.uuid4().hex + ".tmp")
        data = json.dumps(value, sort_keys=True).encode()
        require(len(data) < 32768, "Bound live pending status")
        with tmp.open("xb") as stream: stream.write(data)
        tmp.replace(state["status_path"])

    def _capture(self, state, label):
        self.idle()
        require(len(state["captures"]) < MAX_CAPTURES_PER_COHORT, "Declared bounded capture schedule exhausted")
        require(self.catalog_allocated_bytes + allocated_bytes(self.out) + 8 * 1024 * 1024 <= OUTPUT_RESERVATION_BYTES,
                "Actual owned source/capture artifacts exhausted their reservation; no new probe or automatic retry")
        # Full live MCM/image/source checks bracket the complete cohort. Each
        # retained capture additionally checks the exact admitted database and
        # manifest identities, and its fresh app-generated PID/clock/UUID.
        require(self.wait.identity(self.admission["database"]["path"]) == self.admission["database"]["identity"],
                "Actual admitted corpus identity changed during pending observation")
        self.wait.verify_witness(self.admission["installationManifest"], 131072)
        request_id = str(uuid.uuid4()).upper()
        paths = state["paths"]
        require(not paths["request"].exists(), "Another producer owns this source-request basename")
        # Complete fallible evidence preparation before publishing anything
        # into the app. Every operation after actual creation is guarded below.
        folder = state["folder"] / request_id; folder.mkdir()
        records = {"request": self.wait.write_new(folder / "request.txt", request_id.encode())}
        before = self.clock.sample()
        try:
            with owned_source_request(self.wait, paths["request"], request_id, self.request_lifetimes):
                deadline = time.monotonic() + 3
                viewport_raw = None
                while time.monotonic() < deadline:
                    if paths["viewport"].exists():
                        raw = self.wait.read(paths["viewport"], self.wait.MAX_VIEWPORT)
                        report = self.wait.decode(raw)
                        if report.get("requestID") == request_id:
                            viewport_raw = raw
                            break
                    time.sleep(0.025)
                require(viewport_raw is not None, "Original mounted Reader did not answer the fresh pending request")
                records["viewport"] = self.wait.write_new(folder / "viewport.json", viewport_raw)
                report = self.wait.decode(viewport_raw)
                descriptor = report.get("sqliteFetchWaitObservation")
                require(isinstance(descriptor, dict) and descriptor.get("status") == "AVAILABLE",
                        "A fresh unavailable descriptor cannot use the old companion")
                raw = self.wait.read(paths["companion"], self.wait.MAX_SNAPSHOT)
                records["companion"] = self.wait.write_new(folder / "sqlite-fetch-wait.json", raw)
                after = self.clock.sample()
                self.total_bytes += sum(value["bytes"] for value in records.values())
                require(self.total_bytes <= MAX_RAW_BYTES, "Bound actual retained pending raw bytes")
                snapshot = self.wait.validate_descriptor(report, raw, expected_path=str(paths["companion"]),
                    request_id=request_id, process_id=state["identity"]["processID"])
                lower, upper = before["machLowerNs"] - self.clock.quantum, after["machUpperNs"] + self.clock.quantum
                require(lower <= snapshot["snapshotNanoseconds"] <= upper, "Actual app snapshot is outside its fresh native clock bracket")
                source = report.get("fullV32SourceObservation", {})
                require(source.get("processID") == snapshot["processID"], "Original source and companion are from different processes")
                value = {"schema": SCHEMA, "label": label, "snapshot": snapshot, "viewport": report,
                         "identity": state["identity"], "raw": records, "sourceComparison": self._source(report, expected_mode="line" if label == "baseline" else state.get("final_mode")) if label in ("baseline", "final") else None,
                         "clock": {"beforeRequestWrite": before, "afterCompanionRead": after,
                                   "lowerNanoseconds": lower, "upperNanoseconds": upper},
                         "armedOperation": state.get("armed")}
                require(len(json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2, allow_nan=False).encode()) <= 3 * 1024 * 1024,
                        "Actual complete capture exceeds its admitted metadata reservation; never truncate it")
                ref = self.wait.seal(folder / "CAPTURE.json", value)
                value["captureReceipt"] = ref
                state["captures"].append(value)
                return value
        except Exception as error:
            self.wait.seal(folder / "REJECTED.json", {"schema": SCHEMA, "requestID": request_id,
                "label": label, "raw": records, "errorType": type(error).__name__, "error": str(error),
                "qualified": False})
            raise

    def begin(self, request, container):
        self.idle()
        require(self.active is None and len(self.results) < 3, "Three declared sequential cohorts only")
        name = request.get("cohort")
        require(name == COHORTS[len(self.results)], "No omitted, reordered or repeated cohort")
        ident = self.wait.canonical_uuid(request.get("cohortID"))
        actual = self.collector._check_identity()
        require(actual["processID"] not in self.seen_pids, "Every declared cohort requires an actual new app process")
        self.seen_pids.add(actual["processID"])
        basename = request.get("viewportBasename")
        paths = self.collector._paths(container, basename)
        folder = self.out / ident; folder.mkdir()
        state = {"id": ident, "name": name, "identity": actual, "paths": paths, "folder": folder,
                 "captures": [], "markers": [], "stop": threading.Event(), "capture_lock": threading.RLock(),
                 "armed": None, "overlap": None, "error": None, "worker_start_attempted": False,
                 "status_path": Path(container) / "Documents" / ("pending-sql-" + ident + ".status.json")}
        require(not state["status_path"].exists(), "Never reuse a live correctness cohort")
        self.active = state
        try:
            baseline = self._capture(state, "baseline")
            require(baseline["sourceComparison"] is not None
                    and baseline["sourceComparison"]["mode"] == "line"
                    and not baseline["snapshot"]["active"] and not baseline["snapshot"]["lifetimeDropped"]
                    and not overview_visible(baseline["viewport"]),
                    "A genuine mounted quiet original line baseline is required")
            state["baseline"] = baseline
        except Exception as error:
            state["error"] = {"type": type(error).__name__, "message": str(error)}
            state["watcherStopped"] = True; self._write_status(state)
            raise
        self._write_status(state)
        worker = threading.Thread(target=self._monitor, args=(state,), name="owned-pending-fetch-correctness", daemon=True)
        state["worker"] = worker
        state["worker_start_attempted"] = True
        worker.start()
        return {"cohortID": ident, "cohort": name, "processID": actual["processID"],
                "statusPath": str(state["status_path"]), "baseline": baseline["captureReceipt"],
                "scope": "Prepared real baseline; no SQL overlap or native outcome accepted yet"}

    def _monitor(self, state):
        previous = set()
        try:
            deadline = time.monotonic() + 40
            while not state["stop"].is_set() and time.monotonic() < deadline:
                with state["capture_lock"]:
                    if state["stop"].is_set(): break
                    capture = self._capture(state, "during-original-ui-actions")
                    snapshot = capture["snapshot"]
                    connections = {row["connectionID"]: row for row in snapshot["connections"]}
                    active = [row for row in snapshot["active"]
                              if row["sequence"] > state["baseline"]["snapshot"]["lifetimeStarted"]
                              and self.wait.connection_matches_corpus(connections[row["connectionID"]], self.admission["database"])]
                    persisting = [row for row in active if row["operationID"] in previous]
                    chapter_marker = next((row for row in state["markers"] if row["event"] == "chapter-request"), None)
                    if chapter_marker:
                        requested = chapter_marker["hostObservedBeforeOriginalUIRequest"]["machUpperNs"]
                        persisting = [row for row in persisting if row["beginNanoseconds"] >= requested]
                    if state["armed"] is None and persisting and chapter_marker:
                        state["armed"] = operation_identity(min(persisting, key=lambda row: row["sequence"]))
                    capture["armedOperation"] = state["armed"]
                    # The immutable raw CAPTURE receipt precedes this derived
                    # correlation. A separate record binds the derivation.
                    if state["armed"] is not None and any(operation_identity(row) == state["armed"] for row in active):
                        overview_marker = next((row for row in state["markers"] if row["event"] == "overview-action"), None)
                        if (overview_marker is not None
                                and snapshot["snapshotNanoseconds"] >= overview_marker["hostObservedBeforeOriginalUIRequest"]["machUpperNs"]
                                and overview_visible(capture["viewport"])
                                and capture["viewport"].get("fullV32SourceObservation", {}).get("status") == "AVAILABLE"):
                            state["overlap"] = capture["captureReceipt"]
                    previous = {row["operationID"] for row in active}
                    self.wait.seal(state["folder"] / (snapshot["requestID"] + ".correlation.json"),
                        {"capture": capture["captureReceipt"], "armedOperation": state["armed"],
                         "changedWhilePending": state["overlap"]})
                    self._write_status(state)
                    if state["overlap"] is not None and {row["event"] for row in state["markers"]} == required_markers(state["name"]):
                        # Actual changed-state overlap is already retained. The
                        # later final capture proves the exact terminal; no
                        # source work is needed through navigation transitions.
                        return
                    if state["armed"] is not None and any(
                            row["operationID"] == state["armed"]["operationID"] for row in snapshot["completed"]):
                        state["terminalObserved"] = capture["captureReceipt"]
                        # No more probes after this operation finishes. Source
                        # comparisons and native semantic actions are outside
                        # the outstanding-fetch observation window.
                        if state["overlap"] is None:
                            state["error"] = {"type": "CoverageUnavailable", "message": "Armed fetch ended before any changed original UI response"}
                        self._write_status(state)
                        return
                if state["stop"].wait(0.05): break
                # Leave two slots for an explicit pre-action fence and final.
                if len(state["captures"]) >= MAX_CAPTURES_PER_COHORT - 2:
                    raise ValueError("Pending overlap capture budget exhausted; no automatic retry")
            if not state["stop"].is_set():
                raise ValueError("Bounded pending correctness observation expired")
        except Exception as error:
            state["error"] = {"type": type(error).__name__, "message": str(error)}
            self._write_status(state)
        finally:
            state["watcherStopped"] = True
            self._write_status(state)

    def mark(self, request):
        self.idle(); state = self.active
        require(state is not None and request.get("cohortID") == state["id"], "Wrong actual pending cohort")
        event = request.get("event")
        sequence = marker_sequence(state["name"])
        require(len(state["markers"]) < len(sequence) and event == sequence[len(state["markers"])],
                "Unknown, reordered, out-of-cohort or duplicated native action marker")
        require(state["error"] is None, "Actual pending observation already failed")
        with state["capture_lock"]:
            fence = None
            if event == "chapter-request":
                require(not state["markers"] and state["armed"] is None, "The natural chapter request is the first action")
            else:
                require(state["armed"] is not None, "An actual persisting operation must precede a declared action")
                require(event == "overview-action" or state["overlap"] is not None,
                        "Later actions cannot replace missing actual processed-overview overlap")
                fence = self._capture(state, "fresh-before-" + event)
                require(any(operation_identity(row) == state["armed"] for row in fence["snapshot"]["active"]),
                        "The identical original fetch finished before the next action request")
                if event == "overview-action":
                    require(not overview_visible(fence["viewport"]), "Original overview must still be hidden before its actual action")
            record = {"event": event, "hostObservedBeforeOriginalUIRequest": self.clock.sample(),
                      "latestActualCapture": state["captures"][-1]["captureReceipt"],
                      "freshPendingRequestID": fence["snapshot"]["requestID"] if fence else None,
                      "armedOperation": state["armed"], "inputProcessingTimeQualified": False}
            state["markers"].append(record)
            self.wait.seal(state["folder"] / ("marker-" + event + ".json"), record)
            complete = state["overlap"] is not None and {row["event"] for row in state["markers"]} == required_markers(state["name"])
            if complete:
                state["stop"].set()
        if complete:
            join_owned_writer(state)
            require(all(row["retirementVerified"] and row["descriptorClosed"] for row in self.request_lifetimes),
                    "Do not acknowledge a second source writer while request retirement is unverified")
        return {"cohortID": state["id"], "event": event, "observed": True,
                "scope": "Actual fresh pending fence and host request marker only; input-processing time is unqualified"}

    def finish(self, request):
        self.idle(); state = self.active
        require(state is not None and request.get("cohortID") == state["id"], "Wrong pending correctness finish")
        state["stop"].set(); join_owned_writer(state)
        expected_mode = "chapter" if state["name"] == "overview" else "line"
        require(request.get("finalMode") == expected_mode, "The declared cohort cannot change its final original mode")
        state["final_mode"] = expected_mode
        with state["capture_lock"]:
            final = self._capture(state, "final")
        current = self.collector._check_identity()
        require(current == state["identity"], "Actual MCM/image/corpus/PID changed within the cohort")
        require(final["sourceComparison"] is not None and final["sourceComparison"]["mode"] == request.get("finalMode"),
                "Original final full-unit source must match the declared complete mode")
        # Compare every potentially qualifying changed-state response with the
        # original complete source oracle only AFTER the fetch/probe window.
        # This avoids repeated large-file reading/decoding as manufactured load.
        for capture in state["captures"]:
            if (capture["sourceComparison"] is None and state["armed"] is not None
                    and any(operation_identity(row) == state["armed"] for row in capture["snapshot"]["active"])
                    and overview_visible(capture["viewport"])):
                capture["sourceComparison"] = self._source(capture["viewport"])
                self.wait.seal(state["folder"] / (capture["snapshot"]["requestID"] + ".source-comparison.json"),
                    {"capture": capture["captureReceipt"], "comparison": capture["sourceComparison"],
                     "scope": "Actual original comparator after outstanding fetch/observation window"})
        result = evaluate_overlap(self.wait, state["baseline"], state["captures"], final,
                                  self.admission["database"], state["name"], state["markers"])
        result.update(cohortID=state["id"], processID=current["processID"],
                      baseline=state["baseline"]["captureReceipt"], final=final["captureReceipt"],
                      captures=[value["captureReceipt"] for value in state["captures"]],
                      observationError=state["error"], semanticOutcome=request.get("semanticOutcome"),
                      semanticOutcomeScope="Untrusted native declaration until exact xcresult/attachments are independently verified")
        if state["error"] is not None:
            result["status"] = "NOT_QUALIFIED"; result["reasons"].append("ORIGINAL_OBSERVATION_FAILED")
        reference = self.wait.seal(state["folder"] / "RESULT.json", result)
        self.results.append(reference); self.active = None
        return {"cohortID": state["id"], "status": result["status"], "result": reference,
                "reasons": result["reasons"], "fullPerformanceAcceptance": False}

    def abort(self, request):
        """Retain every declared attempt; a coverage failure never disappears."""
        self.idle()
        name, ident = request.get("cohort"), self.wait.canonical_uuid(request.get("cohortID"))
        require(len(self.results) < 3 and name == COHORTS[len(self.results)], "Abort must preserve the fixed declared cohort order")
        state = self.active
        require(state is None or (state["id"] == ident and state["name"] == name), "Cannot abort another live cohort")
        native = request.get("nativeFailure")
        require(isinstance(native, str) and 0 < len(native) <= 2048, "Keep a bounded actual native failure, not a fabricated success")
        if state is not None:
            state["stop"].set()
            join_owned_writer(state)
            folder = state["folder"]
            captures = [row["captureReceipt"] for row in state["captures"]]
            markers, pid, error = state["markers"], state["identity"]["processID"], state["error"]
        else:
            folder = self.out / ident
            require(not folder.exists(), "Cannot replace an earlier incomplete attempt")
            folder.mkdir(); captures, markers, pid, error = [], [], None, None
        require(all(row["retirementVerified"] and row["descriptorClosed"] for row in self.request_lifetimes),
                "Owned source request retirement is unverified; do not relaunch the app")
        result = {"schema": SCHEMA, "cohort": name, "cohortID": ident, "status": "ABORTED_NOT_QUALIFIED",
                  "processID": pid, "captures": captures, "markers": markers, "observationError": error,
                  "nativeFailure": native, "nativeFailureScope": "Native declaration retained, independently bind the exact xcresult",
                  "fullPerformanceAcceptance": False}
        ref = self.wait.seal(folder / "RESULT.json", result)
        self.results.append(ref); self.active = None
        return {"cohortID": ident, "status": result["status"], "result": ref, "ownedProbeWriterExited": True}

    def complete_case(self, request):
        self.idle()
        require(self.active is None and len(self.results) == 3 and self.complete is None, "Exactly three completed declared cohorts are required")
        rows = [self.wait.decode(self.wait.verify_witness(ref)) for ref in self.results]
        require([row["cohort"] for row in rows] == list(COHORTS)
                and len({row["processID"] for row in rows}) == 3
                and all(row["status"] == "ACTUAL_PENDING_FETCH_UI_OVERLAP_OBSERVED_NATIVE_SEMANTIC_VERIFICATION_REQUIRED" for row in rows),
                "Missing, repeated or unqualified native cohort cannot produce a completion")
        self.complete = self.wait.seal(self.out / "HOST_COMPLETION.json", {"schema": SCHEMA,
            "status": "THREE_ACTUAL_PENDING_FETCH_COHORTS_RECORDED_NATIVE_XCRESULT_REQUIRED",
            "selector": SELECTOR, "cohorts": self.results, "nativeDeclaration": request.get("nativeDeclaration"),
            "resourceEpochs": 0, "fullPerformanceAcceptance": False,
            "exactSQLSteppingOrMappingAttribution": "NOT_QUALIFIED_REQUIRES_ACTUAL_MATCHING_THREAD_TRACE"})
        return {"completion": self.complete, "fullPerformanceAcceptance": False}

    def request_stop(self):
        state = self.active
        if state is not None: state["stop"].set()

    def stop(self):
        # Finalization and the outer stop path may meet. Serialize publication
        # after requesting/joining the one owned writer; never double-seal.
        with self.lock:
            if self.active is not None:
                state = self.active; state["stop"].set()
                join_owned_writer(state)
                require(all(row["retirementVerified"] and row["descriptorClosed"] for row in self.request_lifetimes),
                        "Owned source request cleanup remains unverified at shutdown")
                if not (state["folder"] / "ABORTED.json").exists():
                    self.wait.seal(state["folder"] / "ABORTED.json", {"schema": SCHEMA,
                        "cohortID": state["id"], "status": "ABORTED_NOT_QUALIFIED", "error": state["error"],
                        "captures": [row["captureReceipt"] for row in state["captures"]],
                        "markers": state["markers"], "fullPerformanceAcceptance": False})

    def finalize(self):
        with self.lock:
            if self.finalized: return
            self.stop(); self.collector._check_identity(process=False)
            self.wait.verify_witness(self.catalog_ref, 8_000_000)
            self.wait.verify_witness(self.compile_ref, 8_000_000)
            self.wait.verify_witness(self.execution_ref, 8_000_000)
            for record in self.source_inputs.values(): self.wait.verify_witness(record)
            self.wait.seal(self.out / "RESULT.json", {"schema": SCHEMA,
                "status": "PENDING_FETCH_HOST_RECORDED_NATIVE_XCRESULT_REQUIRED" if self.complete else "INCOMPLETE_NOT_QUALIFIED",
                "admission": self.collector.admission_ref, "catalog": self.catalog_ref,
                "sourceInputs": self.source_inputs, "cohorts": self.results,
                "completion": self.complete, "rawBytes": self.total_bytes, "nativeUIAccepted": False,
                "resourceEpochs": 0, "fullPerformanceAcceptance": False})
            self.finalized = True


def observation_host(previous_host, core, pending_dir, pending_catalog):
    """Standalone only; common/v32 and the original two v40 cases stay intact."""
    class PendingObservationHost(previous_host):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, **kwargs)
            self.pending_sql = PendingRecorder(core, self, pending_dir, pending_catalog)

        def environment(self):
            original = super().environment()
            # This isolated workload has its actual three-mode catalog. Never
            # advertise a nonexistent historical/default catalog.json.
            original.pop("TEST_RUNNER_FULL_V32_CATALOG_FILE", None)
            return {**original, **self.pending_sql.environment()}

        def handle(self, request, container):
            action = request.get("action")
            if action == "pending_sql_begin": return self.pending_sql.begin(request, container)
            if action == "pending_sql_mark": return self.pending_sql.mark(request)
            if action == "pending_sql_finish": return self.pending_sql.finish(request)
            if action == "pending_sql_abort": return self.pending_sql.abort(request)
            if action == "pending_sql_complete": return self.pending_sql.complete_case(request)
            require(action == "process", "This standalone correctness host admits no resource, Reader or Inspector completion actions")
            return super().handle(request, container)

        def stop(self):
            self.stop_event.set(); self.pending_sql.request_stop()
            if self.ident is not None: self.join(timeout=30)
            require(not self.is_alive(), "Original observer exit is unverified; keep this simulator owned")
            self.pending_sql.stop()

        def run(self):
            try:
                return super().run()
            finally:
                try:
                    self.pending_sql.finalize()
                except Exception as error:
                    self.error = self.error or "PendingSQLFinalizationFailed:" + type(error).__name__
    return PendingObservationHost


class RejectResourceTrace:
    def require_running(self):
        raise ValueError("Standalone pending-fetch correctness admits no resource measurement epochs")


class PendingSQLHost:
    """One separate production-study selector; no default ten-target rerun.

    Caller supplies a FRESH original core module, unique phase OUT, frozen
    source-before/current build, wait.bind_admission's exact installation, and
    prepare_catalog's actual three-mode output. No method installs/downloads,
    launches an app, starts a trace, or hashes the 4GB corpus implicitly.
    """
    def __init__(self, core, udid, container, installation, pending_dir, pending_catalog):
        wait = load_wait(core.ROOT)
        require(core.CORPUS_NAME == "full-v40", "Standalone pending host is not the historical v32 run")
        require("sqlite_wait_admission" in installation, "The phase needs actual separately bracketed original admission")
        require(core.ObservationHost.__qualname__ == "ObservationHost", "Pass a fresh unmodified original core host class")
        cls = wait.observation_host(core.ObservationHost, core)
        cls = observation_host(cls, core, pending_dir, pending_catalog)
        self.host = cls(udid, container, pending_dir, pending_catalog, installation, RejectResourceTrace())
        self.core, self.wait = core, wait
        self.cleanup_receipt = None
        self.cleanup_state = None
        self.owned_activity_exited = False
        self.start_attempted = False
        self.started = False

    def start(self):
        require(not self.start_attempted, "Do not start this original observer twice")
        self.start_attempted = True
        self.host.start(); self.started = True
        return self.host.environment()

    def stop(self):
        """Always retain observed cleanup state before raising qualification.

        Root must ALSO verify its URL host and native test process-group exits.
        This object never releases, deletes or marks a simulator retainable.
        A timed-out observer/probe writer requires keeping ownership unresolved.
        """
        require(self.cleanup_receipt is None, "This stop attempt already has an immutable receipt")
        error = None
        try:
            self.host.stop()
        except Exception as caught:
            error = {"type": type(caught).__name__, "message": str(caught)}
        state = self.host.pending_sql.active
        worker = state.get("worker") if state is not None else None
        observer_start_verified = not self.start_attempted or self.host.ident is not None
        observer_exited = observer_start_verified and not self.host.is_alive()
        writer_exited = writer_exit_verified(state)
        lifetimes = self.host.pending_sql.request_lifetimes
        request_retired = all(row["retirementVerified"] and row["descriptorClosed"] for row in lifetimes)
        self.owned_activity_exited = observer_exited and writer_exited and request_retired
        # Publish the conservative in-memory state BEFORE attempting any disk
        # write. ENOSPC cannot turn an unknown start/exit into safe handoff.
        self.cleanup_state = {
            "schema": SCHEMA, "observerStarted": self.started, "observerStartAttempted": self.start_attempted,
            "observerStartVerified": observer_start_verified,
            "probeWriterStartAttempted": state.get("worker_start_attempted", False) if state is not None else False,
            "originalObserverThreadExited": observer_exited, "passiveProbeWriterExited": writer_exited,
            "ownedActivityExited": self.owned_activity_exited, "stopError": error,
            "ownedRequestRetirementVerified": request_retired, "ownedRequestLifetimes": lifetimes,
            "nativeTestProcessGroupExit": "NOT_OWNED_NOT_VERIFIED",
            "urlTransportHostExit": "NOT_OWNED_NOT_VERIFIED",
            "simulatorReleaseOrRetentionAuthorized": False,
            "scope": "Owned Python observer/writer exit only; root must verify every external owned job before simulator handoff"}
        self.cleanup_receipt = self.wait.seal(Path(self.core.OUT) / "pending-fetch-cleanup.json", self.cleanup_state)
        require(self.owned_activity_exited and error is None,
                "Pending observer cleanup unverified; preserve simulator ownership and the cleanup receipt")
        require(self.host.error is None and self.host.active is None and self.host.pending_inspector is None,
                "Standalone observer failed or retained an invalid resource fence")
        require(not self.host.epochs and self.host.reader_complete is None and self.host.inspector_complete is None,
                "Do not manufacture original Reader/Inspector performance cohorts")
        result = self.wait.decode(self.wait.read(Path(self.core.OUT) / "pending-fetch-correctness/RESULT.json", 8_000_000))
        require(result["status"] == "PENDING_FETCH_HOST_RECORDED_NATIVE_XCRESULT_REQUIRED",
                "All three declared pending cohorts and the actual native completion declaration are required")
        return {"proof": result, "cleanup": self.cleanup_receipt,
                "externalExitVerificationRequired": True, "fullPerformanceAcceptance": False}


def validate_clock_sample(sample, clock):
    """Recheck retained actual Mach arithmetic; never read a new clock."""
    fields = {"machBeforeTicks", "hostMonotonicNs", "machAfterTicks", "machLowerNs", "machUpperNs"}
    require(isinstance(sample, dict) and set(sample) == fields
            and all(type(value) is int and 0 <= value < 2 ** 64 for value in sample.values()),
            "Missing or malformed actual Mach clock sample")
    numer, denom = clock["machTimebaseNumer"], clock["machTimebaseDenom"]
    quantum = clock["integerConversionBoundNs"]
    lower = sample["machBeforeTicks"] * numer // denom
    upper = (sample["machAfterTicks"] * numer + denom - 1) // denom
    require(sample["machBeforeTicks"] <= sample["machAfterTicks"]
            and sample["machLowerNs"] == lower and sample["machUpperNs"] == upper
            and lower - quantum <= sample["hostMonotonicNs"] <= upper + quantum,
            "Retained host clock is not the actual recorded Mach bracket")
    return sample


def validate_manifest_copy(record, original, raw):
    """Bind an immutable artifact to admitted bytes, never reopen old app data."""
    require(isinstance(original, dict) and set(original) == {"path", "bytes", "sha256"}
            and record["bytes"] == original["bytes"] == len(raw)
            and record["sha256"] == original["sha256"] == hashlib.sha256(raw).hexdigest(),
            "Retained manifest copy is not the exact original admitted metadata")


def validate_capture_continuity(captures, wait):
    """Original lifetime counters and registered operation identities persist."""
    connections, operations, ids, completed = {}, {}, {}, {}
    prior = None
    for capture in captures:
        snapshot = capture["snapshot"]
        if prior is not None:
            require(all(snapshot[key] >= prior[key] for key in wait.COUNTERS)
                    and (not prior["counterOverflowed"] or snapshot["counterOverflowed"]),
                    "Original passive lifetime counters regressed within the same process")
        current = {row["connectionID"]: row for row in snapshot["connections"]}
        require(all(current.get(key) == row for key, row in connections.items()),
                "An immutable original registered connection disappeared or changed")
        connections.update(current)
        for row in snapshot["active"] + snapshot["completed"]:
            identity = operation_identity(row)
            require(operations.get(row["sequence"], identity) == identity
                    and ids.get(row["operationID"], row["sequence"]) == row["sequence"],
                    "Original operation sequence, identity or thread was reassigned")
            operations[row["sequence"]] = identity; ids[row["operationID"]] = row["sequence"]
        for row in snapshot["active"]:
            require(row["sequence"] not in completed, "An original completed fetch became active again")
        for row in snapshot["completed"]:
            require(completed.get(row["sequence"], row) == row, "An original terminal changed after publication")
            completed[row["sequence"]] = row
        prior = snapshot


def validate_compiler_invocation(compiled, sources, root, directory, binary):
    """Recheck the original recorded argv, keeping the swiftc driver intact.

    core.witness resolves the compiler symlink for its byte identity. That
    resolved executable path must not replace the observed driver in argv[0].
    Tool provenance comes from this exact original producer's retained inputs;
    this historical check neither hashes nor invokes the current toolchain.
    """
    command = compiled.get("command")
    require(isinstance(command, list) and command and all(isinstance(arg, str) for arg in command)
            and command.count("-sdk") == 1 and command.index("-sdk") + 1 < len(command),
            "Actual Swift compiler invocation is missing")
    driver, sdk = Path(command[0]), command[command.index("-sdk") + 1]
    require(driver.is_absolute() and ".." not in driver.parts and driver.name == "swiftc",
            "The observed swiftc driver cannot be replaced by a resolved frontend or another program")
    for tool in ("swiftc", "zstd"):
        record = compiled.get(tool)
        require(isinstance(record, dict) and set(record) == {"path", "bytes", "sha256"}
                and Path(record["path"]).is_absolute() and ".." not in Path(record["path"]).parts
                and type(record["bytes"]) is int and record["bytes"] > 0
                and re.fullmatch(r"[a-f0-9]{64}", record["sha256"]), "Original compiler/dependency identity was not retained")
    require(Path(compiled["swiftc"]["path"]).name in ("swiftc", "swift-frontend"),
            "Original resolved compiler file is not a Swift driver/frontend")
    zstd_parent = str(Path(compiled["zstd"]["path"]).parent)
    expected = [str(driver), "-parse-as-library", "-swift-version", "6", "-Xfrontend",
                "-strict-concurrency=complete", "-O", "-sdk", sdk, "-module-cache-path", str(directory / "module-cache"),
                "-L", zstd_parent, "-lzstd", "-Xlinker", "-rpath", "-Xlinker", zstd_parent,
                *[str(root / name) for name in sources], str(root / SOURCE_PATHS[-1]), "-o", binary]
    require(command == expected and Path(sdk).is_absolute() and ".." not in Path(sdk).parts and Path(sdk).name.endswith(".sdk"),
            "Retained executable was not compiled by the original complete-source driver command")


class RetainedPendingEvidence:
    """Read-only reconstruction using the current original prerequisite API.

    No constructor runs a clock, process query, source compiler or database
    operation. Every reread enters Evidence's immutable FileWitness registry.
    """
    def __init__(self, root_report, evidence):
        self.report, self.evidence = root_report, evidence
        self.core, self.wait = evidence.core, load_wait(evidence.root)
        self.refs = {}
        self.record = root_report.get("pending_sql")
        require(isinstance(self.record, dict) and self.record.get("fullPerformanceAcceptance") is False,
                "Missing original pending phase artifacts")
        self.host_ref = self.record["hostResult"]
        self.out = evidence.settings.canonical_path(Path(self.host_ref["path"]).parent, directory=True)
        require(self.out.name == "pending-fetch-correctness"
                and self.out.is_relative_to(evidence.root / "build/artifacts"),
                "Pending artifacts must remain in the actual owned phase output")
        self.phase_out = self.out.parent
        self.pending_dir = self.phase_out / "pending-source-catalog"
        self.host = self.read(self.host_ref, expected=self.out / "RESULT.json")
        self.inputs = self.read(self.record["hostInputs"], expected=self.out / "INPUTS.json")
        self.execution = self.read(self.record["sourceExecution"], expected=self.pending_dir / "execution-result.json")

    def read(self, record, *, expected=None, maximum=8_000_000, json_value=True):
        require(isinstance(record, dict) and set(record) == {"path", "bytes", "sha256"},
                "A claimed result must identify an actual immutable file")
        if expected is not None:
            require(record["path"] == str(expected), "Retained evidence escaped its original producer path")
        value = self.evidence.read_witness(record, maximum=maximum, json_value=json_value)
        prior = self.refs.get(record["path"])
        require(prior is None or prior == record, "Conflicting original evidence identity")
        self.refs[record["path"]] = record
        return value

    def path(self, path, *, maximum=8_000_000, json_value=True):
        record, value = self.evidence.read_path(path, maximum=maximum, json_value=json_value)
        self.refs[record["path"]] = record
        return record, value

    def admit(self):
        require(self.host.get("schema") == self.inputs.get("schema") == SCHEMA
                and self.host.get("status") == "PENDING_FETCH_HOST_RECORDED_NATIVE_XCRESULT_REQUIRED"
                and self.host.get("nativeUIAccepted") is False
                and self.host.get("resourceEpochs") == self.inputs.get("resourceEpochs") == 0
                and type(self.host["resourceEpochs"]) is type(self.inputs["resourceEpochs"]) is int
                and self.host.get("fullPerformanceAcceptance") is False
                and self.inputs.get("performanceAcceptance") is False
                and self.inputs.get("selector") == SELECTOR and self.inputs.get("cohorts") == list(COHORTS),
                "Original pending host scope or declared cohorts differ")
        require(self.record.get("host", {}).get("proof") == self.host
                and self.record["host"].get("externalExitVerificationRequired") is True
                and self.record["host"].get("fullPerformanceAcceptance") is False,
                "Controller host summary is not the byte-sealed original host result")
        self.admission = self.read(self.inputs["admission"], expected=self.phase_out / "sqlite-fetch-wait/admission.json")
        admission = self.admission
        require(self.host.get("admission") == self.inputs["admission"]
                and admission.get("schema") == self.wait.SCHEMA
                and admission.get("status") == "ORIGINAL_CURRENT_V40_HASH_IMAGE_ADMISSION_BRACKETED"
                and admission.get("simulatorUDID") == self.evidence.udid
                and admission.get("buildReceipt") == self.evidence.build["build_receipt"]
                and admission.get("checkoutSHA") == self.evidence.source["checkout_sha"]
                and admission.get("originalInstallation", {}).get("result") == self.evidence.original,
                "Original installation, build, source or device admission differs")
        self.wait.canonical_uuid(admission["runID"])
        self.evidence.settings.validate_owner_record(admission["owner"])
        require(admission["owner"]["simulatorUDID"] == self.evidence.udid,
                "Historical MCM record belongs to another device")
        source = self.read(admission["source"], expected=self.phase_out / "source-before.json")
        self.evidence.source_identity(source, "full-v40")
        require(source == self.report.get("source_before") == self.report.get("source_after"),
                "Pending source execution is not this exact original native phase")
        self.read(admission["buildReceipt"])
        original = self.read(admission["originalAdmission"], expected=self.phase_out / "actual-full-v40-installation.json")
        self.evidence.installation_admission(original)
        self.database = admission["database"]
        db = {key: self.database[key] for key in ("path", "bytes", "sha256")}
        self.evidence.database_identity(db)
        require(db == original.get("database") == self.report.get("database_after")
                and admission["installationManifest"] == original.get("installation_manifest")
                and Path(db["path"]).is_relative_to(Path(admission["owner"]["dataContainer"])),
                "Actual admitted corpus or manifest does not belong to this phase owner")
        # This revalidates the sealed admission, not a new 4GB hash/stat claim.
        # The outer current-device prerequisite owns any subsequent live check.
        identity = self.database.get("identity")
        require(isinstance(identity, dict) and set(identity) == {"device", "inode", "bytes", "mtimeNs", "ctimeNs"}
                and all(type(v) is int and 0 <= v < 2 ** 64 for v in identity.values())
                and identity["bytes"] == self.wait.DB_BYTES, "Malformed original admitted file identity")
        retained_manifest = self.inputs["installationManifestCopy"]
        raw_manifest = self.read(retained_manifest, expected=self.out / "admitted-installation-manifest.json",
                                 maximum=131072, json_value=False)
        validate_manifest_copy(retained_manifest, admission["installationManifest"], raw_manifest)
        prefix = "build/DerivedData/Build/Products/Debug-iphonesimulator/Maktabah.app/"
        expected = {key[len(prefix):]: value for key, value in self.evidence.build["complete_native_images"].items()
                    if key.startswith(prefix)}
        images = admission.get("installedImages", {})
        require(expected and admission.get("expectedNativeImages") == expected
                and set(images.get("images", {})) == set(expected), "Actual installed app image closure differs")
        installed_app = Path(images["appContainer"])
        require(installed_app.is_absolute() and ".." not in installed_app.parts and installed_app.name == "Maktabah.app"
                and "/Devices/" + self.evidence.udid + "/data/" in str(installed_app)
                and Path(images["executable"]).parent == installed_app
                and Path(images["executable"]).name in expected, "Actual native executable is outside this device/app")
        for name, record in images["images"].items():
            require(record.get("sha256") == expected[name]["sha256"]
                    and record.get("identity", {}).get("bytes") == expected[name]["bytes"],
                    "Retained installed native image differs from the qualified build")
        for key, names in (("sourceInputs", self.wait.SOURCE_PATHS),):
            require(set(admission.get(key, {})) == set(names), "Original collector source closure is incomplete")
            for name in names:
                ref = admission[key][name]
                self.read(ref, expected=self.evidence.root / name, json_value=False)
                require(source["execution_inputs"].get(name) == {k: ref[k] for k in ("bytes", "sha256")},
                        "Original collector source was omitted from frozen phase inputs")
        self.source = source
        self.clock = self.read(self.inputs["hostClock"], expected=self.phase_out / "sqlite-fetch-wait/host-clock.json")
        clock = self.clock
        require(clock.get("schema") == 1 and type(clock["schema"]) is int
                and clock.get("platform") == "darwin" and clock.get("implementation") == "mach_absolute_time()"
                and clock.get("monotonic") is True and clock.get("adjustable") is False
                and all(type(clock.get(key)) is int and 0 < clock[key] < 2 ** 32
                        for key in ("machTimebaseNumer", "machTimebaseDenom"))
                and type(clock.get("integerConversionBoundNs")) is int
                and clock["integerConversionBoundNs"] == math.ceil(clock["machTimebaseNumer"] / clock["machTimebaseDenom"]) + 1
                and isinstance(clock.get("python"), str) and clock["python"]
                and type(clock.get("resolutionSeconds")) in (int, float)
                and math.isfinite(clock["resolutionSeconds"]) and clock["resolutionSeconds"] > 0,
                "Actual retained CPython/Mach runtime calibration is absent")
        brackets = clock.get("runtimeBrackets")
        require(isinstance(brackets, list) and len(brackets) == 3, "Require every original actual clock compatibility bracket")
        for row in brackets:
            validate_clock_sample(row, clock)
        require(all(a["machAfterTicks"] <= b["machBeforeTicks"] for a, b in zip(brackets, brackets[1:])),
                "Original clock calibration order differs")

    def catalog(self):
        catalog_ref = self.inputs["catalog"]
        catalog = self.read(catalog_ref, expected=self.pending_dir / "pending-sql-modes.json")
        require(self.host.get("catalog") == catalog_ref, "Host and source catalog identities differ")
        self.references = admit_pending_catalog(self.wait, catalog, self.pending_dir)
        for row in self.references.values():
            self.read(row["reference"], maximum=64 * 1024 * 1024, json_value=False)
        require(self.inputs.get("sourceReferences") == self.references, "Complete original source references differ")
        require(set(self.inputs.get("sourceInputs", {})) == set(SOURCE_PATHS)
                and self.host.get("sourceInputs") == self.inputs["sourceInputs"], "Pending producer source closure is incomplete")
        for name, record in self.inputs["sourceInputs"].items():
            self.read(record, expected=self.evidence.root / name, json_value=False)
            require(self.source["execution_inputs"].get(name) == {key: record[key] for key in ("bytes", "sha256")},
                    "Current original producer source was omitted from native phase closure")
        compiled = self.read(self.inputs["compileInputs"], expected=self.pending_dir / "compile-inputs.json")
        require(self.inputs["compileInputs"]["sha256"] == catalog.get("catalogCompileInputsSHA256"),
                "Actual catalog was not produced by the retained original compilation")
        _, profile = self.path(self.evidence.root / "Scripts/CI/reader-full-v40-ui-observation.inputs.json")
        sources = profile["catalog_compiled_sources"]
        require(isinstance(sources, list) and 0 < len(sources) <= 63 and len(sources) == len(set(sources)),
                "Actual frozen complete-source compilation list is missing")
        require(set(compiled.get("source_sha256", {})) == set(sources + [SOURCE_PATHS[-1]]),
                "Catalog compilation omitted or substituted an original source")
        for name, digest in compiled["source_sha256"].items():
            relative = Path(name)
            require(not relative.is_absolute() and ".." not in relative.parts, "Escaping compile source")
            ref, _ = self.path(self.evidence.root / relative, json_value=False)
            require(ref["sha256"] == digest, "Actual source file changed since its original compilation")
        for key, name in (("sourceServiceSHA256", SERVICE_SOURCE), ("presentationSourceSHA256", PRESENTATION_SOURCE)):
            require(catalog.get(key) == compiled["source_sha256"].get(name), "Original service/presentation identity differs")
        execution = self.execution
        require(self.inputs["execution"] == self.record["sourceExecution"]
                and execution.get("schema") == SCHEMA
                and execution.get("status") == "ORIGINAL_SOURCE_PENDING_SQL_MODES_EXECUTED_NOT_UI_OR_PERFORMANCE"
                and type(execution.get("executionExit")) is int and execution["executionExit"] == 0
                and execution.get("admission") == self.inputs["admission"]
                and execution.get("source") == self.admission["source"] and execution.get("catalog") == catalog_ref
                and execution.get("completeOriginalSources") == self.references
                and execution.get("uiExecuted") == 0 and type(execution["uiExecuted"]) is int
                and execution.get("performanceObserved") is False,
                "Actual same-source execution did not produce these complete pending modes")
        compiler = execution["compiled"]
        require(compiler.get("compileInputs") == self.inputs["compileInputs"], "Actual compiler input witness differs")
        result = self.read(compiler["compileResult"], expected=self.pending_dir / "compile-result.json")
        require(type(result.get("exit")) is int and result["exit"] == 0 and result.get("inputs") == compiler["compileInputs"],
                "Actual successful original Swift execution is missing")
        self.read(result["log"], expected=self.pending_dir / "compile.log", maximum=64 * 1024 * 1024, json_value=False)
        self.read(execution["executionLog"], expected=self.pending_dir / "execution.log", maximum=64 * 1024 * 1024, json_value=False)
        self.read(compiler["binary"], expected=self.pending_dir / "original-source-catalog", maximum=64 * 1024 * 1024, json_value=False)
        validate_compiler_invocation(compiled, sources, self.evidence.root, self.pending_dir, compiler["binary"]["path"])
        original = self.read(execution["input"], expected=self.pending_dir / "input.json")
        admitted = self.read(self.admission["originalAdmission"])
        require(set(original) == {"databaseURI", "databaseSHA256", "v40Targets", "pendingSQLModes", "sourceService", "presentationSource"}
                and original["databaseURI"] == admitted.get("uri") and original["databaseSHA256"] == self.wait.DB_SHA
                and original["pendingSQLModes"] is True and original["v40Targets"] == profile["catalog_targets"]
                and execution.get("command") == [compiler["binary"]["path"], execution["input"]["path"], str(self.pending_dir)],
                "Original source execution used another corpus or work schedule")
        for key, name in (("sourceService", SERVICE_SOURCE), ("presentationSource", PRESENTATION_SOURCE)):
            expected_identity = {"path": str(self.evidence.root / name), "sha256": compiled["source_sha256"][name],
                                 "compileInputsPath": self.inputs["compileInputs"]["path"]}
            require(original[key] == compiler.get(key) == expected_identity, "Original source invocation identity differs")
        self.comparator = PendingRecorder.__new__(PendingRecorder)
        self.comparator.core, self.comparator.wait = self.core, self.wait
        self.comparator.pending_dir, self.comparator.references = self.pending_dir, self.references
        self.catalog_value = catalog

    def expected_identity(self, pid):
        require(type(pid) is int and pid > 0, "Actual native process identity is absent")
        return {"ownerSHA256": hashlib.sha256(json.dumps(self.admission["owner"], sort_keys=True).encode()).hexdigest(),
                "databaseIdentity": self.database["identity"],
                "manifestSHA256": self.admission["installationManifest"]["sha256"],
                "installedImagesSHA256": hashlib.sha256(json.dumps(self.admission["installedImages"], sort_keys=True).encode()).hexdigest(),
                "processID": pid, "executable": self.admission["installedImages"]["executable"]}

    def capture(self, reference, folder, identity):
        path = Path(reference["path"])
        request_id = self.wait.canonical_uuid(path.parent.name)
        require(path == folder / request_id / "CAPTURE.json", "Capture escaped its actual cohort/request")
        capture = self.read(reference, expected=path, maximum=3 * 1024 * 1024)
        require(capture.get("schema") == SCHEMA and capture.get("identity") == identity
                and set(capture.get("raw", {})) == {"request", "viewport", "companion"},
                "Capture has a different original process, owner or raw input set")
        request = self.read(capture["raw"]["request"], expected=path.parent / "request.txt", maximum=36, json_value=False)
        require(request == request_id.encode(), "The actual original request was missing or reused")
        viewport = self.read(capture["raw"]["viewport"], expected=path.parent / "viewport.json", maximum=self.wait.MAX_VIEWPORT)
        companion = self.read(capture["raw"]["companion"], expected=path.parent / "sqlite-fetch-wait.json",
                              maximum=self.wait.MAX_SNAPSHOT, json_value=False)
        descriptor = viewport.get("sqliteFetchWaitObservation", {})
        native_path = Path(descriptor.get("snapshotPath", ""))
        match = re.fullmatch(r"full-v32-reader-([0-9A-F-]{36})\.sqlite-fetch-wait\.json", native_path.name)
        require(match is not None and native_path.parent == Path(self.admission["owner"]["dataContainer"]) / "Documents",
                "Companion descriptor escaped the exact original MCM owner/basename")
        self.wait.canonical_uuid(match.group(1))
        snapshot = self.wait.validate_descriptor(viewport, companion, str(native_path), request_id, identity["processID"])
        require(snapshot is not None and capture.get("snapshot") == snapshot and capture.get("viewport") == viewport
                and viewport.get("requestID") == request_id
                and viewport.get("fullV32SourceObservation", {}).get("processID") == identity["processID"],
                "Raw original app bytes disagree with the stored capture or process")
        clock = capture.get("clock", {})
        before = validate_clock_sample(clock.get("beforeRequestWrite"), self.clock)
        after = validate_clock_sample(clock.get("afterCompanionRead"), self.clock)
        quantum = self.clock["integerConversionBoundNs"]
        require(before["machBeforeTicks"] >= self.clock["runtimeBrackets"][-1]["machAfterTicks"]
                and before["machAfterTicks"] <= after["machBeforeTicks"]
                and clock.get("lowerNanoseconds") == before["machLowerNs"] - quantum
                and clock.get("upperNanoseconds") == after["machUpperNs"] + quantum
                and clock["lowerNanoseconds"] <= snapshot["snapshotNanoseconds"] <= clock["upperNanoseconds"],
                "Original fresh request/companion was outside its actual Mach bracket")
        return {**capture, "captureReceipt": reference, "ownedRequestPath":
                str(native_path.with_name(native_path.name.removesuffix(".sqlite-fetch-wait.json") + ".request"))}

    def cohort(self, reference, name):
        folder = Path(reference["path"]).parent
        cohort_id = self.wait.canonical_uuid(folder.name)
        require(folder.parent == self.out, "Cohort escaped the actual original pending phase")
        result = self.read(reference, expected=folder / "RESULT.json")
        require(result.get("cohort") == name and result.get("cohortID") == cohort_id
                and result.get("schema") == SCHEMA and result.get("observationError") is None,
                "Missing, reordered or failed original cohort")
        identity = self.expected_identity(result.get("processID"))
        refs = result.get("captures")
        require(isinstance(refs, list) and 4 <= len(refs) <= MAX_CAPTURES_PER_COHORT
                and len({row.get("path") for row in refs}) == len(refs), "Complete original capture schedule is missing or duplicated")
        captures = [self.capture(row, folder, identity) for row in refs]
        validate_capture_continuity(captures, self.wait)
        require(captures[0]["label"] == "baseline" and captures[-1]["label"] == "final"
                and result.get("baseline") == refs[0] and result.get("final") == refs[-1]
                and sum(row["label"] == "baseline" for row in captures) == sum(row["label"] == "final" for row in captures) == 1,
                "Actual original baseline/final is missing or substituted")
        require(all(a["clock"]["afterCompanionRead"]["machAfterTicks"] <= b["clock"]["beforeRequestWrite"]["machBeforeTicks"]
                    and a["snapshot"]["snapshotNanoseconds"] < b["snapshot"]["snapshotNanoseconds"]
                    for a, b in zip(captures, captures[1:])), "Retained original capture order is not the actual serial request order")
        positions = {row["captureReceipt"]["path"]: index for index, row in enumerate(captures)}
        markers, marker_positions = [], []
        for event in marker_sequence(name):
            _, marker = self.path(folder / ("marker-" + event + ".json"))
            require(marker.get("event") == event and marker.get("inputProcessingTimeQualified") is False,
                    "A request marker was mistaken for input processing or belongs to another action")
            sampled = validate_clock_sample(marker.get("hostObservedBeforeOriginalUIRequest"), self.clock)
            latest = marker.get("latestActualCapture", {})
            index = positions.get(latest.get("path"))
            require(index is not None and latest == refs[index] and index + 1 < len(captures)
                    and captures[index]["clock"]["afterCompanionRead"]["machAfterTicks"] <= sampled["machBeforeTicks"]
                    and sampled["machAfterTicks"] <= captures[index + 1]["clock"]["beforeRequestWrite"]["machBeforeTicks"],
                    "Original action marker is not between its actual latest and subsequent capture")
            if event == "chapter-request":
                require(marker.get("freshPendingRequestID") is None and marker.get("armedOperation") is None,
                        "The initial Chapter request cannot adopt an earlier armed operation")
            else:
                require(captures[index]["label"] == "fresh-before-" + event
                        and marker.get("freshPendingRequestID") == captures[index]["snapshot"]["requestID"],
                        "Declared original UI action lacks its unique exact pending request fence")
            markers.append(marker); marker_positions.append(index)
        require(result.get("markers") == markers and all(a < b for a, b in zip(marker_positions, marker_positions[1:])),
                "Stored marker order differs from the actual immutable action records")
        armed, previous, overlap = None, set(), None
        baseline = captures[0]["snapshot"]
        for index, capture in enumerate(captures):
            require(capture.get("armedOperation") == armed, "Stored raw capture adopted an operation before its original derivation")
            snapshot = capture["snapshot"]
            connections = {row["connectionID"]: row for row in snapshot["connections"]}
            visible_markers = {marker["event"]: marker for marker, position in zip(markers, marker_positions) if position < index}
            label = capture["label"]
            if label == "during-original-ui-actions":
                active = [row for row in snapshot["active"] if row["sequence"] > baseline["lifetimeStarted"]
                          and self.wait.connection_matches_corpus(connections[row["connectionID"]], self.database)]
                persistent = [row for row in active if row["operationID"] in previous]
                chapter = visible_markers.get("chapter-request")
                if chapter:
                    lower = chapter["hostObservedBeforeOriginalUIRequest"]["machUpperNs"]
                    persistent = [row for row in persistent if row["beginNanoseconds"] >= lower]
                if armed is None and persistent and chapter:
                    armed = operation_identity(min(persistent, key=lambda row: row["sequence"]))
                capture["armedOperation"] = armed
                overview = visible_markers.get("overview-action")
                if (armed is not None and any(operation_identity(row) == armed for row in active)
                        and overview is not None and snapshot["snapshotNanoseconds"] >= overview["hostObservedBeforeOriginalUIRequest"]["machUpperNs"]
                        and overview_visible(capture["viewport"])
                        and capture["viewport"].get("fullV32SourceObservation", {}).get("status") == "AVAILABLE"):
                    overlap = capture["captureReceipt"]
                previous = {row["operationID"] for row in active}
                _, correlated = self.path(folder / (snapshot["requestID"] + ".correlation.json"))
                require(correlated == {"capture": capture["captureReceipt"], "armedOperation": armed, "changedWhilePending": overlap},
                        "Original operation/changed-state correlation cannot be reproduced from the raw captures")
            elif label.startswith("fresh-before-"):
                event = label.removeprefix("fresh-before-")
                require(event in marker_sequence(name)[1:]
                        and marker_positions[marker_sequence(name).index(event)] == index,
                        "An original pending fence is unused or assigned to another action")
            else:
                require(label in ("baseline", "final"), "Unexpected original observation was omitted from the declared schedule")
            if label in ("baseline", "final"):
                mode = "chapter" if label == "final" and name == "overview" else "line"
                computed = self.comparator._source(capture["viewport"], expected_mode=mode)
                require(computed is not None and capture.get("sourceComparison") == computed,
                        "Original full-unit source baseline/final comparison does not reproduce")
            else:
                require(capture.get("sourceComparison") is None, "Raw pending-window capture unexpectedly contains derived source work")
        require(armed is not None, "No original persisting source-qualified operation can be reconstructed")
        # Replay precisely the original post-window comparator, after the raw
        # active-operation derivation. A saved claimed comparison is insufficient.
        for capture in captures:
            if (capture["sourceComparison"] is None
                    and any(operation_identity(row) == armed for row in capture["snapshot"]["active"])
                    and overview_visible(capture["viewport"])):
                computed = self.comparator._source(capture["viewport"])
                _, record = self.path(folder / (capture["snapshot"]["requestID"] + ".source-comparison.json"))
                require(record == {"capture": capture["captureReceipt"], "comparison": computed,
                                   "scope": "Actual original comparator after outstanding fetch/observation window"},
                        "Post-window original source comparison differs from the complete original source bytes")
                capture["sourceComparison"] = computed
        computed = evaluate_overlap(self.wait, captures[0], captures, captures[-1], self.database, name, markers)
        require(all(result.get(key) == value for key, value in computed.items())
                and computed["status"] == "ACTUAL_PENDING_FETCH_UI_OVERLAP_OBSERVED_NATIVE_SEMANTIC_VERIFICATION_REQUIRED",
                "Claimed pending success does not reproduce from the original raw observations")
        # A rejected attempt cannot be hidden by omitting it from captures.
        members = list(folder.rglob("*"))
        require(len(members) <= MAX_CAPTURES_PER_COHORT * 8 + 32, "Original cohort artifact inventory exceeded its bound")
        actual_files = set()
        for path in members:
            mode = path.lstat().st_mode
            require(not stat.S_ISLNK(mode) and (stat.S_ISREG(mode) or stat.S_ISDIR(mode)),
                    "Redirected or unsupported retained cohort member")
            if stat.S_ISREG(mode): actual_files.add(str(path))
        read_files = {path for path in self.refs if Path(path).is_relative_to(folder)}
        require(actual_files == read_files, "Original cohort contains an omitted/rejected or unverified artifact")
        return {"result": result, "reference": reference, "computed": computed,
                "captures": captures, "cohortID": cohort_id, "processID": identity["processID"]}

    def attachment(self, directory, stem):
        selected = self.evidence.settings.selected_attachment(directory / "captures", SELECTOR, self.evidence.udid, stem)
        actual = self.read(selected["file"], maximum=8_000_000)
        self.read(selected["exportManifest"], expected=directory / "captures/manifest.json")
        require(actual == selected["contents"], "Original exported attachment changed during selection")
        return selected, actual

    def ack(self, value, action):
        require(isinstance(value, dict) and value.get("schema") == 1 and type(value["schema"]) is int
                and value.get("ok") is True and value.get("action") == action and value.get("udid") == self.evidence.udid,
                "The exported actual native ACK has a different action/device or failed")
        self.wait.canonical_uuid(value.get("nonce"))

    def annotations(self, value):
        require(isinstance(value, dict) and type(value.get("rowCount")) is int and 0 < value["rowCount"] <= 10000
                and type(value.get("logicalBytes")) is int and 0 < value["logicalBytes"] <= 128 * 1024 * 1024
                and re.fullmatch(r"[a-f0-9]{64}", value.get("logicalRowsSHA256", "")),
                "Original nonempty annotation observation is missing or truncated")
        columns = value.get("columns")
        require(isinstance(columns, list) and 0 < len(columns) <= 64
                and all(isinstance(name, str) and name for name in columns) and len(set(columns)) == len(columns)
                and {"id", "backendLocator", "startIndex", "length", "context"} <= set(columns),
                "Original persisted locator/UTF16/context columns are absent")
        path = Path(value.get("path", ""))
        require(path.is_absolute() and ".." not in path.parts and path.name == "Annotations.sqlite"
                and any(path.is_relative_to(Path(self.admission["owner"][key])) for key in ("dataContainer", "storageRoot")),
                "Original annotations were read outside the actual current app/storage owner")

    def join_native(self, cohorts):
        case = SELECTOR.removeprefix("Maktabah-iOSUITests/")
        report = self.report
        require(report.get("status") == "EXACT_REGISTERED_FULL_V40_STUDY_PHASE_UI_PASS"
                and report.get("study_phase") == "reader-pending-sql"
                and report.get("selected_case_ids") == [case] and report.get("post_verification_failures") == [],
                "Require the exact original passed standalone native phase before joining its attachments")
        rows = report.get("case_results")
        require(isinstance(rows, list) and len(rows) == 1 and rows[0].get("case") == case,
                "No omitted, alternate or expanded native case can supply pending correctness")
        row = rows[0]
        directory = self.evidence.settings.canonical_path(row.get("case_directory"), directory=True)
        require(directory.parent == self.phase_out and self.evidence.files.get(row["case_result"]["path"]) == row["case_result"],
                "Run the original Evidence.study_phase native/zero-skip gate before artifact reconstruction")
        actual_case = self.read(row["case_result"], expected=directory / "RESULT.json")
        require(actual_case == {key: value for key, value in row.items() if key != "case_result"}
                and actual_case.get("passed") is True and actual_case.get("declaration_status") == "EXECUTED_PASS"
                and all(type(actual_case.get(key)) is int and actual_case[key] == 0
                        for key in ("xcodebuild_exit", "zero_skip_exit", "attachment_export_exit")),
                "Native case result differs from the actual immutable passed execution")
        # Exact xcresult/zero-skip/source/build verification is the caller's
        # original Evidence.study_phase gate. Re-read the actual selected case
        # exports here and join them to every independently recomputed cohort.
        before_ref, before = self.attachment(directory, "pending-sql-original-nonempty-annotations-before")
        self.annotations(before)
        summary_ref, summary = self.attachment(directory, "pending-sql-original-three-cohort-summary")
        require(summary.get("failures") == [] and summary.get("fullPerformanceAcceptance") is False
                and isinstance(summary.get("cohorts"), list) and len(summary["cohorts"]) == 3,
                "All declared native outcomes and an empty actual failure list are required")
        native_refs, nonces = [], set()
        for cohort, declared in zip(cohorts, summary["cohorts"]):
            name, result = cohort["result"]["cohort"], cohort["result"]
            ref, native = self.attachment(directory, "pending-sql-original-cohort-" + name)
            require(native == declared and native.get("cohort") == name and native.get("cohortID") == cohort["cohortID"]
                    and {key: value for key, value in native.items() if key != "host"} == result.get("semanticOutcome"),
                    "Original native outcome does not identify the same actual host cohort/semantic declaration")
            original_id = self.wait.canonical_uuid(native.get("originalDocumentID"))
            final = native.get("finalReader", {})
            mode = "chapter" if name == "overview" else "line"
            target = self.references["8042-pending-sql-" + mode]["target"]
            require(final.get("documentID") == original_id and final.get("targetKey") == target["key"]
                    and final.get("canonicalLocator") == target["sectionLocator"]
                    and final.get("sourceSHA256") == target["sourceSHA256"]
                    and final.get("sourceUTF16Length") == target["sourceUTF16Length"]
                    and final.get("actualPersistedOriginalUnitMode") == mode,
                    "Native original tab, canonical locator, complete source or actual mode changed")
            viewport = final.get("actualViewport", {})
            self.wait.canonical_uuid(viewport.get("requestID"))
            require(viewport.get("fullV32SourceObservation", {}).get("processID") == cohort["processID"]
                    and self.comparator._source(viewport, expected_mode=mode) is not None,
                    "The actual native final reader does not match the complete original source oracle")
            self.annotations(native.get("annotations"))
            require(native["annotations"] == before, "Actual original nonempty annotation state changed during a declared cohort")
            ack = native.get("host")
            self.ack(ack, "pending_sql_finish")
            require(ack.get("cohortID") == cohort["cohortID"] and ack.get("result") == cohort["reference"]
                    and ack.get("status") == cohort["computed"]["status"] and ack.get("reasons") == []
                    and ack.get("fullPerformanceAcceptance") is False and ack["nonce"] not in nonces,
                    "Actual native finish ACK is not the same independently verified original result")
            nonces.add(ack["nonce"])
            if name == "backend-and-tab":
                second_id = self.wait.canonical_uuid(native.get("secondDocumentID"))
                changed = native.get("changedBackend", {})
                self.wait.canonical_uuid(changed.get("documentID"))
                canonical = changed.get("canonicalLocator", "")
                changed_view = changed.get("actualViewport", {})
                native_selection = changed_view.get("nativeSelectionObservation", {})
                source = changed_view.get("fullV32SourceObservation", {})
                self.wait.canonical_uuid(changed_view.get("requestID"))
                require(second_id != original_id
                        and isinstance(canonical, str) and canonical.startswith("sefaria|Genesis|ref:")
                        and source.get("processID") == cohort["processID"] and source.get("status") == "AVAILABLE"
                        and type(source.get("sourceUTF16Length")) is int and source["sourceUTF16Length"] > 0
                        and native_selection.get("schema") == 1 and native_selection.get("status") == "EMPTY"
                        and native_selection.get("processID") == cohort["processID"]
                        and native_selection.get("requestID") == changed_view["requestID"]
                        and native_selection.get("locator") == canonical,
                        "Actual original changed-tab/backend source/empty-selection result is absent")
            native_refs.append(ref)
        completion_ref, ack = self.attachment(directory, "pending-sql-original-host-completion")
        self.ack(ack, "pending_sql_complete")
        require(ack["nonce"] not in nonces and ack.get("completion") == self.host.get("completion")
                and ack.get("fullPerformanceAcceptance") is False, "Actual native completion does not join this host's completed schedule")
        completion = self.read(self.host["completion"], expected=self.out / "HOST_COMPLETION.json")
        require(completion.get("schema") == SCHEMA
                and completion.get("status") == "THREE_ACTUAL_PENDING_FETCH_COHORTS_RECORDED_NATIVE_XCRESULT_REQUIRED"
                and completion.get("selector") == SELECTOR and completion.get("cohorts") == self.host["cohorts"]
                and completion.get("nativeDeclaration") == {"cohortCount": 3, "actualAssertionsCompleted": True}
                and type(completion["nativeDeclaration"]["cohortCount"]) is int
                and completion.get("resourceEpochs") == 0 and type(completion["resourceEpochs"]) is int
                and completion.get("fullPerformanceAcceptance") is False,
                "A nonempty exact original native completion declaration is required")
        return {"caseResult": row["case_result"], "annotationsBefore": before_ref,
                "cohortAttachments": native_refs, "summaryAttachment": summary_ref, "completionAttachment": completion_ref,
                "scope": "Actual passed-case exported attachments joined to raw host proofs; original xcresult verification is owned by Evidence.study_phase"}

    def cleanup(self, cohorts):
        ref = self.record["host"]["cleanup"]
        cleanup = self.read(ref, expected=self.phase_out / "pending-fetch-cleanup.json")
        require(cleanup.get("schema") == SCHEMA and cleanup.get("ownedActivityExited") is True
                and cleanup.get("observerStarted") is True and cleanup.get("observerStartAttempted") is True
                and cleanup.get("observerStartVerified") is True and cleanup.get("stopError") is None
                and cleanup.get("originalObserverThreadExited") is True and cleanup.get("passiveProbeWriterExited") is True
                and cleanup.get("ownedRequestRetirementVerified") is True
                and cleanup.get("simulatorReleaseOrRetentionAuthorized") is False,
                "Actual original owned observer/writer/request retirement is incomplete")
        lifetimes = cleanup.get("ownedRequestLifetimes")
        all_captures = [capture for cohort in cohorts for capture in cohort["captures"]]
        require(isinstance(lifetimes, list) and len(lifetimes) == len(all_captures),
                "An original request creation/retirement was omitted from cleanup")
        for lifetime, capture in zip(lifetimes, all_captures):
            require(lifetime.get("requestID") == capture["snapshot"]["requestID"]
                    and lifetime.get("path") == capture["ownedRequestPath"]
                    and lifetime.get("creationAttempted") is True and lifetime.get("created") is True
                    and lifetime.get("bytesWritten") == 36 and type(lifetime["bytesWritten"]) is int
                    and lifetime.get("retirementVerified") is True and lifetime.get("descriptorClosed") is True
                    and lifetime.get("error") is None,
                    "Actual capture lacks its exact verified owned request lifetime")
            identity = lifetime.get("ownedFileIdentity", {})
            require(set(identity) == {"device", "inode", "bytes", "mtimeNs", "ctimeNs"}
                    and all(type(value) is int and 0 <= value < 2 ** 64 for value in identity.values())
                    and identity["bytes"] == 36, "Retired request was not identified by an actual fd/body/file witness")
        external = self.read(self.record["cleanup"], expected=self.phase_out / "pending-phase-cleanup.json")
        require(external.get("observerCleanup") == ref and external.get("observerState") == cleanup,
                "Root external owner cleanup does not refer to this actual observer/request cleanup")
        return ref


def validate_phase_artifacts(root_report, evidence):
    """Read-only pre-Settings gate; call after Evidence.study_phase's native gate.

    Rereads complete raw source/clock/capture/marker/companion files, reproduces
    the actual original arming and source comparator, reruns evaluate_overlap,
    and joins all three immutable results to the actual selected XCTest exports.
    No new native execution, clock measurement, process probe or corpus hash.
    Root separately verifies actual xcresult and all external process exits.
    """
    retained = RetainedPendingEvidence(root_report, evidence)
    retained.admit()
    retained.catalog()
    references = retained.host.get("cohorts")
    require(isinstance(references, list) and len(references) == 3
            and len({row.get("path") for row in references}) == 3, "All three exact original cohort results are required")
    cohorts = [retained.cohort(reference, name) for reference, name in zip(references, COHORTS)]
    require(len({row["processID"] for row in cohorts}) == len({row["cohortID"] for row in cohorts}) == 3,
            "Each declared original cohort needs a fresh app process and unique cohort identity")
    captures = [capture for cohort in cohorts for capture in cohort["captures"]]
    require(len({capture["snapshot"]["requestID"] for capture in captures}) == len(captures),
            "An original passive request was reused across cohorts")
    raw_bytes = sum(record["bytes"] for capture in captures for record in capture["raw"].values())
    require(type(retained.host.get("rawBytes")) is int and retained.host["rawBytes"] == raw_bytes <= MAX_RAW_BYTES,
            "Original complete raw observation inventory differs from its declared bound")
    native = retained.join_native(cohorts)
    cleanup = retained.cleanup(cohorts)
    members = list(retained.out.iterdir())
    expected = {"INPUTS.json", "RESULT.json", "HOST_COMPLETION.json", "admitted-installation-manifest.json",
                *[row["cohortID"] for row in cohorts]}
    require({path.name for path in members} == expected and all(not path.is_symlink() for path in members),
            "Original pending phase contains an omitted failed/extra cohort")
    return {"schema": SCHEMA, "status": "ORIGINAL_RAW_PENDING_ARTIFACTS_REVALIDATED_NATIVE_AND_EXTERNAL_CLEANUP_GATES_REQUIRED",
            "hostResult": retained.host_ref, "hostInputs": retained.record["hostInputs"],
            "sourceExecution": retained.record["sourceExecution"], "observerCleanup": cleanup,
            "recomputedCohorts": [{"result": row["reference"], "proof": row["computed"]} for row in cohorts],
            "nativeAttachmentJoin": native, "verifiedFiles": [retained.refs[path] for path in sorted(retained.refs)],
            "fullPerformanceAcceptance": False, "resourceEpochCoverage": "NOT_APPLICABLE_SEPARATE_INSTRUMENTED_CORRECTNESS_WORKLOAD",
            "exactSQLSteppingOrMappingAttribution": "NOT_QUALIFIED_REQUIRES_ACTUAL_MATCHING_THREAD_TRACE",
            "scope": "Read-only actual source/raw observation reconstruction and native attachment join; no current corpus rehash, new measurements or implicit native/cleanup pass"}

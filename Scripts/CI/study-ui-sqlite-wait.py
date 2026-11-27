#!/usr/bin/env python3
"""Retain real DEBUG SQLite fetch-lock companions; never manufacture PERF PASS.

Only the v40 wrapper may compose these hooks. No app/simulator/build is started
here. The original resource begin/end and their ACK semantics stay unchanged.
"""
from __future__ import annotations

import argparse
import ctypes
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import platform
import plistlib
import re
import stat
import sys
import time
import uuid

SCHEMA = "otzaria.full-v40.sqlite-fetch-wait/1"
NATIVE_STATUS = "PASSIVE_FETCH_LOCK_OBSERVATION_NOT_PERFORMANCE_ACCEPTANCE"
BUNDLE = "com.davidpovarsky.chavrusatext"
DB_BYTES = 4_355_063_808
DB_SHA = "8389709c1702753af6f0719ef1c98c09854450e48ebb05fe1f95486b26348b01"
SOURCE_PATHS = (
    "Source/Core/Database/SQLiteDatabase.swift",
    "Source/ChavrusaText/Testing/ReaderViewportAcceptanceObserver.swift",
    "Scripts/CI/reader-full-v32-ui-observation.py",
    "Scripts/CI/reader-full-v40-ui-observation.py",
    "Scripts/CI/study-ui-settings-receipts.py",
    "Scripts/CI/study-ui-sqlite-wait.py",
)
MAX_SNAPSHOT = 1_048_576
MAX_VIEWPORT = 32_768  # Preserve the existing host's tighter input bound.
MAX_METADATA = 2_000_000
MAX_CAPTURES = 160
MAX_TOTAL_BYTES = 192 * 1024**2
MAX_SOURCE_REFERENCE = 64 * 1024**2
CAPACITIES = {"completedCapacity": 1024, "activeCapacity": 64, "connectionCapacity": 64}
COUNTERS = (
    "lifetimeStarted", "lifetimeFinished", "lifetimeDropped", "lifetimeOverwritten",
    "lifetimeDroppedForActiveCapacity", "lifetimeDroppedForConnectionCapacity",
    "lifetimeUnmatchedCompletions",
)
QUALIFIED_IDENTITY = "VFS_CONFIRMED_OPENED_FILE_IDENTITY_AT_CONNECTION_OPEN"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def integer(value, name, maximum=2**64 - 1):
    require(type(value) is int and 0 <= value <= maximum, "Invalid integer: " + name)
    return value


def canonical_uuid(value):
    require(isinstance(value, str) and str(uuid.UUID(value)).upper() == value,
            "Require a canonical fresh UUID")
    return value


def finite(value, name):
    require(type(value) in (int, float) and math.isfinite(value), "Nonfinite value: " + name)
    return value


def decode(data):
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, "Duplicate JSON key")
            result[key] = value
        return result
    def invalid_constant(value):
        raise ValueError("Nonfinite JSON constant: " + value)
    return json.loads(data, object_pairs_hook=pairs, parse_constant=invalid_constant)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def canonical(path, *, directory=False, exists=True):
    path = Path(path)
    require(path.is_absolute() and path == path.resolve(strict=exists),
            "Noncanonical/redirected path: " + str(path))
    if exists:
        mode = path.lstat().st_mode
        require(stat.S_ISDIR(mode) if directory else stat.S_ISREG(mode),
                "Unexpected file type: " + str(path))
    return path


def identity(path):
    value = canonical(path).lstat()
    return {"device": value.st_dev, "inode": value.st_ino, "bytes": value.st_size,
            "mtimeNs": value.st_mtime_ns, "ctimeNs": value.st_ctime_ns}


def read(path, maximum):
    path = canonical(path)
    fd = os.open(path, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW)
    try:
        before = os.fstat(fd)
        require(stat.S_ISREG(before.st_mode) and 0 < before.st_size <= maximum,
                "Unbounded or empty evidence")
        with os.fdopen(os.dup(fd), "rb") as stream:
            raw = stream.read(maximum + 1)
        after, at_path = os.fstat(fd), path.lstat()
        key = lambda x: (x.st_dev, x.st_ino, x.st_size, x.st_mtime_ns, x.st_ctime_ns)
        require(stat.S_ISREG(at_path.st_mode) and key(before) == key(after) == key(at_path)
                and len(raw) == before.st_size <= maximum, "Evidence replaced or changed during read")
        return raw
    finally:
        os.close(fd)


def witness(path, maximum=MAX_METADATA):
    raw = read(path, maximum)
    return {"path": str(path), "bytes": len(raw), "sha256": sha(raw)}


def verify_witness(record, maximum=MAX_METADATA):
    require(isinstance(record, dict) and set(record) == {"path", "bytes", "sha256"},
            "Malformed immutable witness")
    require(integer(record["bytes"], "witness bytes", maximum) > 0
            and re.fullmatch(r"[a-f0-9]{64}", record["sha256"] or ""), "Invalid immutable witness")
    raw = read(record["path"], maximum)
    require(len(raw) == record["bytes"] and sha(raw) == record["sha256"], "Immutable input drift")
    return raw


def write_new(path, raw):
    path = canonical(path, exists=False)
    canonical(path.parent, directory=True)
    require(0 < len(raw) <= MAX_METADATA, "Bound the complete new evidence file")
    with path.open("xb") as stream:
        stream.write(raw)
    return witness(path)


def seal(path, value):
    raw = (json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2, allow_nan=False) + "\n").encode()
    return write_new(path, raw)


def validate_snapshot(value, *, request_id=None, process_id=None):
    """Strict native shape/counter validation, independent of any UI admission.

    Valid parsing means neither corpus identity nor complete epoch coverage.
    Native loss/overflow/unqualified identities remain observable values.
    """
    require(isinstance(value, dict) and value.get("schema") == 1
            and type(value["schema"]) is int and value.get("status") == NATIVE_STATUS
            and value.get("clock") == "DispatchTime.uptimeNanoseconds", "Wrong native snapshot contract")
    canonical_uuid(value["requestID"])
    pid = integer(value["processID"], "PID", 2**31 - 1)
    require(pid > 0 and (process_id is None or pid == process_id), "Wrong actual process")
    require(request_id is None or value["requestID"] == request_id, "Stale native request")
    stamp = integer(value["snapshotNanoseconds"], "snapshotNanoseconds")
    require(stamp > 0 and finite(value["observedUptime"], "observedUptime") >= 0,
            "Invalid native clock observation")
    require(isinstance(value.get("scope"), str) and 0 < len(value["scope"]) <= 1024, "Missing original scope")
    for key, expected in CAPACITIES.items():
        require(type(value.get(key)) is int and value[key] == expected, "Native capacity changed: " + key)
    for key in COUNTERS:
        integer(value[key], key)
    for key in ("counterOverflowed", "completeLifetimeCoverage"):
        require(type(value.get(key)) is bool, "Invalid native boolean: " + key)
    connections, active, completed = (value.get(key) for key in ("connections", "active", "completed"))
    require(isinstance(connections, list) and len(connections) <= 64
            and isinstance(active, list) and len(active) <= 64
            and isinstance(completed, list) and len(completed) <= 1024, "Unbounded native collections")
    require(integer(value["activeCount"], "activeCount", 64) == len(active)
            and integer(value["completedRetainedCount"], "completedRetainedCount", 1024) == len(completed),
            "Native collection counts disagree")
    by_connection = {}
    for row in connections:
        require(isinstance(row, dict), "Malformed native connection")
        key = canonical_uuid(row["connectionID"])
        require(key not in by_connection, "Duplicate connection identity")
        created = integer(row["capturedNanoseconds"], "connection clock")
        require(0 < created <= stamp, "Connection created after snapshot")
        status = row.get("identityStatus")
        require(isinstance(status, str) and 0 < len(status) <= 128, "Invalid connection qualification")
        opened = row.get("openedFile")
        if status == QUALIFIED_IDENTITY:
            require(isinstance(opened, dict)
                    and set(opened) == {"path", "device", "inode", "bytes", "modifiedNanoseconds"},
                    "Missing actual opened-file identity")
            path = opened["path"]
            require(isinstance(path, str) and path.startswith("/") and "\x00" not in path
                    and ".." not in Path(path).parts and len(path.encode()) <= 4096, "Unbounded opened pathname")
            for field in ("device", "inode", "bytes"):
                integer(opened[field], field, 2**63 - 1 if field == "bytes" else 2**64 - 1)
            modified = opened["modifiedNanoseconds"]
            require(type(modified) is int and -(2**63) <= modified < 2**63,
                    "Opened modification time is not the original signed Int64")
        else:
            require(status.startswith("UNAVAILABLE") and opened is None, "Unknown/contradictory opened identity")
        by_connection[key] = row
    seen_sequence, seen_operation = set(), set()
    for rows, is_complete in ((active, False), (completed, True)):
        prior = 0
        for row in rows:
            require(isinstance(row, dict), "Malformed operation")
            seq = integer(row["sequence"], "sequence")
            operation = canonical_uuid(row["operationID"])
            require(prior < seq <= value["lifetimeStarted"] and seq not in seen_sequence
                    and operation not in seen_operation, "Duplicate/unordered/unadmitted operation")
            prior = seq
            seen_sequence.add(seq); seen_operation.add(operation)
            connection = by_connection.get(row["connectionID"])
            require(connection is not None, "Operation has no retained connection")
            begin = integer(row["beginNanoseconds"], "beginNanoseconds")
            require(connection["capturedNanoseconds"] <= begin <= stamp, "Invalid operation begin time")
            thread = row.get("nativeThreadID")
            require(thread is None or integer(thread, "nativeThreadID") > 0, "Invalid actual native thread")
            require(type(row.get("mainThread")) is bool, "Invalid main-thread flag")
            if not is_complete:
                require(not any(k in row for k in ("terminalNanoseconds", "acquiredNanoseconds",
                    "waitStartNanoseconds", "lockAcquisitionWaitSeconds", "unacquiredWaitObservedThroughTerminalSeconds")),
                    "Pending operation invents completion or wait values")
                continue
            terminal = integer(row["terminalNanoseconds"], "terminalNanoseconds")
            require(begin <= terminal <= stamp, "Invalid terminal time")
            wait, acquired = row.get("waitStartNanoseconds"), row.get("acquiredNanoseconds")
            require("waitStartNanoseconds" in row and "acquiredNanoseconds" in row, "Missing explicit optional timestamps")
            for key in ("returnedNormally", "taskCancelledAtTerminal"):
                require(type(row.get(key)) is bool, "Invalid completion flag")
            if wait is None:
                require(acquired is None and row["returnedNormally"] is False
                        and "lockAcquisitionWaitSeconds" not in row
                        and "unacquiredWaitObservedThroughTerminalSeconds" not in row,
                        "Prior cancellation invents a lock wait")
            else:
                integer(wait, "waitStartNanoseconds")
                require(begin <= wait <= terminal, "Invalid wait start")
                if acquired is not None:
                    integer(acquired, "acquiredNanoseconds")
                    require(wait <= acquired <= terminal, "Invalid lock acquisition order")
                    field, other, finish = "lockAcquisitionWaitSeconds", "unacquiredWaitObservedThroughTerminalSeconds", acquired
                else:
                    require(row["returnedNormally"] is False, "Normal result without acquiring the lock")
                    field, other, finish = "unacquiredWaitObservedThroughTerminalSeconds", "lockAcquisitionWaitSeconds", terminal
                measured = finite(row.get(field), field)
                expected = (finish - wait) / 1_000_000_000
                require(other not in row and measured >= 0
                        and abs(measured - expected) <= 4 * math.ulp(expected), "Native wait value differs from its timestamps")
    if not value["counterOverflowed"]:
        require(value["lifetimeFinished"] == len(completed) + value["lifetimeOverwritten"], "Finished/ring accounting differs")
        require(len(completed) == min(value["lifetimeFinished"], 1024), "Native completed ring was truncated")
        require(value["lifetimeDropped"] == value["lifetimeDroppedForActiveCapacity"]
                + value["lifetimeDroppedForConnectionCapacity"] + value["lifetimeUnmatchedCompletions"],
                "Unexplained native loss")
        require(value["lifetimeStarted"] == value["lifetimeFinished"] + len(active)
                + value["lifetimeDropped"] - value["lifetimeUnmatchedCompletions"], "Started/terminal accounting differs")
    complete = (value["lifetimeDropped"] == 0 and value["lifetimeOverwritten"] == 0
                and not active and not value["counterOverflowed"])
    require(value["completeLifetimeCoverage"] is complete, "Misstated original complete-lifetime flag")
    return value


def validate_descriptor(viewport, raw, expected_path, request_id, process_id):
    descriptor = viewport.get("sqliteFetchWaitObservation")
    require(isinstance(descriptor, dict) and type(descriptor.get("schema")) is int
            and descriptor["schema"] == 1 and descriptor.get("requestID") == request_id
            and descriptor.get("processID") == process_id
            and len(json.dumps(descriptor, ensure_ascii=False).encode()) <= 2048,
            "Absent/unbounded/mismatched native companion descriptor")
    if descriptor.get("status") == "UNAVAILABLE":
        require(raw is None and isinstance(descriptor.get("reason"), str), "Never fall back to an older companion")
        return None
    require(descriptor.get("status") == "AVAILABLE" and raw is not None
            and descriptor.get("snapshotPath") == str(expected_path)
            and type(descriptor.get("bytes")) is int and 0 < descriptor["bytes"] <= MAX_SNAPSHOT
            and len(raw) == descriptor["bytes"] and sha(raw) == descriptor.get("sha256"),
            "Companion path/length/hash differs from the actual fresh descriptor")
    snapshot = validate_snapshot(decode(raw), request_id=request_id, process_id=process_id)
    for key in ("completeLifetimeCoverage", "activeCount", "completedRetainedCount", "lifetimeDropped", "lifetimeOverwritten"):
        require(type(descriptor.get(key)) is type(snapshot[key]) and descriptor[key] == snapshot[key],
                "Descriptor disagrees with complete native snapshot: " + key)
    return snapshot


class DarwinClock:
    """Actual runtime checks, not a presumed wall/CPU or cross-process offset."""
    def __init__(self):
        info = time.get_clock_info("monotonic")
        require(sys.platform == "darwin" and platform.python_implementation() == "CPython"
                and sys.version_info >= (3, 10) and info.implementation == "mach_absolute_time()"
                and info.monotonic and not info.adjustable, "Unsupported actual host monotonic implementation")
        class Timebase(ctypes.Structure):
            _fields_ = [("numer", ctypes.c_uint32), ("denom", ctypes.c_uint32)]
        self.lib = ctypes.CDLL("/usr/lib/libSystem.B.dylib")
        self.lib.mach_absolute_time.restype = ctypes.c_uint64
        self.lib.mach_absolute_time.argtypes = []
        self.lib.mach_timebase_info.restype = ctypes.c_int
        self.lib.mach_timebase_info.argtypes = [ctypes.POINTER(Timebase)]
        base = Timebase()
        require(self.lib.mach_timebase_info(ctypes.byref(base)) == 0 and base.numer > 0 and base.denom > 0,
                "Actual Mach timebase unavailable")
        self.numer, self.denom = int(base.numer), int(base.denom)
        self.quantum = math.ceil(self.numer / self.denom) + 1
        self.resolution_ns = math.ceil(finite(info.resolution, "clock resolution") * 1_000_000_000)
        self.record = {"schema": 1, "platform": sys.platform, "python": sys.version,
            "implementation": info.implementation, "monotonic": info.monotonic, "adjustable": info.adjustable,
            "resolutionSeconds": info.resolution, "machTimebaseNumer": self.numer,
            "machTimebaseDenom": self.denom, "integerConversionBoundNs": self.quantum,
            "scope": "Actual CPython monotonic_ns bracketed by native Mach absolute time; app clock still requires a fresh request bracket"}
        self.record["runtimeBrackets"] = [self.sample() for _ in range(3)]

    def sample(self):
        before = self.lib.mach_absolute_time()
        host = time.monotonic_ns()
        after = self.lib.mach_absolute_time()
        lower, upper = before * self.numer // self.denom, (after * self.numer + self.denom - 1) // self.denom
        require(before <= after and lower - self.quantum <= host <= upper + self.quantum,
                "Actual host monotonic clock does not match the recorded Mach bounds")
        return {"machBeforeTicks": before, "hostMonotonicNs": host, "machAfterTicks": after,
                "machLowerNs": lower, "machUpperNs": upper}


def epoch_bounds(value, resolution_ns):
    """Outward bounds for the original host's float monotonic timestamps."""
    finite(value, "original resource monotonic time")
    require(0 < value <= (2**64 - 1) / 1_000_000_000
            and type(resolution_ns) is int and 0 <= resolution_ns <= 1_000_000,
            "Unsupported original clock resolution")
    numerator, denominator = float(value).as_integer_ratio()
    uncertainty = math.ceil(math.ulp(float(value)) * 1_000_000_000) + resolution_ns + 1
    lower = numerator * 1_000_000_000 // denominator - uncertainty
    upper = (numerator * 1_000_000_000 + denominator - 1) // denominator + uncertainty
    return [lower, upper]


def connection_matches_corpus(row, database):
    opened = row.get("openedFile")
    return (row.get("identityStatus") == QUALIFIED_IDENTITY and isinstance(opened, dict)
            and opened == {"path": database["path"], "device": database["identity"]["device"],
                "inode": database["identity"]["inode"], "bytes": database["identity"]["bytes"],
                "modifiedNanoseconds": database["identity"]["mtimeNs"]})


def evaluate_epoch(baseline, end, epoch, database, *, resolution_ns):
    """Pure strict coverage decision. Inputs must already be sealed captures.

    Unknown coverage produces reasons, never estimated elapsed-minus-CPU wait.
    The only eligible metric scope is this exact admitted full-v40 database.
    """
    result = {"schema": SCHEMA, "status": "NOT_QUALIFIED", "epoch": epoch.get("epoch"),
              "full_performance_acceptance": False, "reasons": [],
              "scope": "Complete attributable operations on the admitted full-v40 SQLiteDatabase.fetch lock only"}
    reasons = result["reasons"]
    if baseline is None:
        reasons.append("NO_ACTUAL_PRE_EPOCH_BASELINE")
    if end is None:
        reasons.append("NO_ACTUAL_VALIDATED_POST_ACK_END_CAPTURE")
    if reasons:
        return result
    for row, role in ((baseline, "baseline"), (end, "end")):
        if row.get("qualification") != "SOURCE_AND_CURRENT_IDENTITY_VALIDATED":
            reasons.append(role.upper() + "_NOT_VALIDATED")
        if row.get("clock", {}).get("status") != "ACTUAL_NATIVE_REQUEST_BRACKET_VALIDATED":
            reasons.append(role.upper() + "_CLOCK_NOT_CALIBRATED")
        if row.get("snapshot") is None:
            reasons.append(role.upper() + "_NATIVE_SNAPSHOT_UNAVAILABLE")
    if reasons:
        return result
    a, b = validate_snapshot(baseline["snapshot"]), validate_snapshot(end["snapshot"])
    if baseline["runID"] != end["runID"] or baseline["admissionSHA256"] != end["admissionSHA256"]:
        reasons.append("SOURCE_BUILD_OWNER_OR_CORPUS_ADMISSION_CHANGED")
    if baseline["currentIdentity"] != end["currentIdentity"]:
        reasons.append("CURRENT_PROCESS_IMAGE_OWNER_OR_CORPUS_CHANGED")
    if a["processID"] != b["processID"] or b["processID"] != epoch.get("processID"):
        reasons.append("PROCESS_CHANGED")
    if baseline["requestID"] == end["requestID"]:
        reasons.append("REQUEST_REUSED")
    if end.get("epoch") != epoch.get("epoch") or baseline.get("epoch") != epoch.get("epoch"):
        reasons.append("WRONG_EPOCH_LINK")
    if epoch.get("status") != "OBSERVED_NOT_PERFORMANCE_ACCEPTANCE":
        reasons.append("ORIGINAL_RESOURCE_EPOCH_NOT_COMPLETE")
    start = epoch_bounds(epoch["resource_start_host_monotonic"], resolution_ns)
    finish = epoch_bounds(epoch["resource_end_host_monotonic"], resolution_ns)
    result["originalHostBoundaryNanoseconds"] = {"start": start, "end": finish}
    if not (a["snapshotNanoseconds"] <= start[0] <= start[1] < finish[0] <= finish[1] <= b["snapshotNanoseconds"]):
        reasons.append("NATIVE_SNAPSHOTS_DO_NOT_BRACKET_THE_ORIGINAL_EPOCH")
    if a["counterOverflowed"] or b["counterOverflowed"]:
        reasons.append("COUNTER_OVERFLOW")
    # A rejected begin returns nil, but the ORIGINAL fetch still executes.
    # finish(nil) records no terminal state. Even unchanged prior drop counters
    # therefore cannot prove that an untracked pre-baseline operation finished;
    # it may span this entire epoch while active[] is empty at both snapshots.
    if any(a[key] != 0 for key in ("lifetimeDropped", "lifetimeDroppedForActiveCapacity",
                                   "lifetimeDroppedForConnectionCapacity", "lifetimeUnmatchedCompletions")):
        reasons.append("PRIOR_DROPS_CAN_HIDE_UNTRACKED_SPANNING_OPERATIONS")
    if a["active"] or b["active"]:
        reasons.append("PENDING_OR_SPANNING_OPERATIONS_AT_SNAPSHOT")
    if any(b[key] < a[key] for key in COUNTERS):
        reasons.append("NATIVE_LIFETIME_COUNTER_REGRESSED")
    for key in ("lifetimeDropped", "lifetimeDroppedForActiveCapacity", "lifetimeDroppedForConnectionCapacity", "lifetimeUnmatchedCompletions"):
        if a[key] != b[key]:
            reasons.append("EPOCH_INTERVAL_LOSS_" + key)
    count = b["lifetimeStarted"] - a["lifetimeStarted"]
    new = [r for r in b["completed"] if r["sequence"] > a["lifetimeStarted"]]
    if not (0 <= count <= 1024 and len(new) == count
            and [r["sequence"] for r in new] == list(range(a["lifetimeStarted"] + 1, b["lifetimeStarted"] + 1))
            and b["lifetimeFinished"] - a["lifetimeFinished"] == count):
        reasons.append("NEW_OPERATION_SEQUENCE_COVERAGE_INCOMPLETE")
    # Old overwritten history is allowed only when all newly admitted operations
    # are retained and every overwrite is accounted for by these completions.
    if 0 <= count <= 1024 and b["lifetimeOverwritten"] - a["lifetimeOverwritten"] != max(0, len(a["completed"]) + count - 1024):
        reasons.append("UNEXPLAINED_RING_OVERWRITE")
    if reasons:
        return result
    by_connection = {r["connectionID"]: r for r in b["connections"]}
    before_connections = {r["connectionID"]: r for r in a["connections"]}
    if any(by_connection.get(k) != row for k, row in before_connections.items()):
        reasons.append("IMMUTABLE_CONNECTION_IDENTITY_CHANGED")
    included, outside = [], []
    for row in new:
        if row["terminalNanoseconds"] < start[0] or row["beginNanoseconds"] > finish[1]:
            outside.append(row["sequence"])
            continue
        if not (row["beginNanoseconds"] >= start[1] and row["terminalNanoseconds"] <= finish[0]):
            reasons.append("OPERATION_SPANS_OR_TOUCHES_UNCERTAIN_RESOURCE_BOUNDARY")
            continue
        if row["nativeThreadID"] is None:
            reasons.append("UNKNOWN_NATIVE_THREAD_IDENTITY")
        if not connection_matches_corpus(by_connection[row["connectionID"]], database):
            reasons.append("IN_EPOCH_CONNECTION_NOT_EXACT_ADMITTED_CORPUS")
        included.append(row)
    result.update(observedNewOperationCount=len(new), includedSequences=[r["sequence"] for r in included],
                  outsideEpochSequences=outside,
                  priorHistoryDropped=a["lifetimeDropped"], priorHistoryOverwritten=a["lifetimeOverwritten"])
    if reasons:
        result["reasons"] = sorted(set(reasons))
        return result
    acquired = [r["acquiredNanoseconds"] - r["waitStartNanoseconds"] for r in included if r["acquiredNanoseconds"] is not None]
    unacquired = [r["terminalNanoseconds"] - r["waitStartNanoseconds"] for r in included
                  if r["acquiredNanoseconds"] is None and r["waitStartNanoseconds"] is not None]
    result.update(status="EPOCH_COVERAGE_PROVEN_NOT_PERFORMANCE_ACCEPTANCE",
        metrics={"acquiredWaitNanoseconds": acquired, "unacquiredObservedWaitNanoseconds": unacquired,
            "acquiredWaitTotalNanoseconds": sum(acquired), "unacquiredObservedWaitTotalNanoseconds": sum(unacquired),
            "completedOperations": len(included), "returnedNormally": sum(r["returnedNormally"] for r in included),
            "mainThreadSequences": [r["sequence"] for r in included if r["mainThread"]],
            "cancelFlagIsNotExceptionClassification": True},
        attribution="Instrumented Debug fetch admission only; no SQLite busy-handler, query-time or UI-responsiveness inference")
    return result


def _settings(core):
    path = canonical(Path(core.ROOT) / "Scripts/CI/study-ui-settings-receipts.py")
    spec = importlib.util.spec_from_file_location("sqlite_wait_original_settings_ownership", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _owner(core, udid, settings):
    canonical_uuid(udid)
    container = canonical(Path(core.command(["xcrun", "simctl", "get_app_container", udid, BUNDLE, "data"], timeout=45).stdout.strip()), directory=True)
    result = settings.discover_owner(udid, container.parent)
    require(result["dataContainer"] == str(container), "simctl and original MCM discovery disagree")
    return result


def _image_state(core, udid, expected):
    app = canonical(Path(core.command(["xcrun", "simctl", "get_app_container", udid, BUNDLE, "app"], timeout=45).stdout.strip()), directory=True)
    require("/devices/" + udid.lower() + "/data/" in str(app).lower(), "Installed image is outside this device")
    info_path = app / "Info.plist"
    raw = read(info_path, 131072)
    info = plistlib.loads(raw)
    require(info.get("CFBundleIdentifier") == BUNDLE, "Foreign installed application")
    name = info.get("CFBundleExecutable")
    require(isinstance(name, str) and Path(name).name == name and name in expected, "Missing exact executable closure")
    require(isinstance(expected, dict) and 0 < len(expected) <= 256, "Unbounded installed code closure")
    images = {}
    for relative, record in sorted(expected.items()):
        require(isinstance(relative, str) and relative and not Path(relative).is_absolute()
                and ".." not in Path(relative).parts, "Escaping native image path")
        path = canonical(app / relative)
        require(path.is_relative_to(app), "Native image escaped its bundle")
        actual = identity(path)
        require(actual["bytes"] == record["bytes"] and re.fullmatch(r"[a-f0-9]{64}", record["sha256"] or ""),
                "Native image size/unqualified original hash differs")
        images[relative] = {"identity": actual, "sha256": record["sha256"]}
    return {"appContainer": str(app), "executable": str(app / name), "infoPlistSHA256": sha(raw), "images": images}


def bind_admission(core, retained, original_call, config, udid, build):
    """Bracket the ORIGINAL v40 hash/image admission, without another DB hash.

    Wrapper call: database, installation = bind_admission(core, self,
        original_bound_admit, config, udid, build). No original receipt changes.
    A changed inode/mtime/ctime/container requires a new real admission; a later
    stat alone is never presented as continuity with a historical hash.
    """
    require(core.CORPUS_NAME == "full-v40" and retained.udid == udid, "Only the explicit retained-v40 wrapper may bind this helper")
    source = config.get("source_database", {})
    require(source.get("databaseBytes") == DB_BYTES and source.get("databaseSHA256") == DB_SHA
            and source.get("releaseID") == 455390662 and source.get("assetID") == 782942035,
            "Wrong independent original v40 corpus identity")
    root = canonical(Path(core.ROOT), directory=True)
    out = canonical(Path(core.OUT), directory=True) / "sqlite-fetch-wait"
    require(out.is_relative_to(root) and not out.exists(), "Never reuse/overwrite a previous SQLite observation admission")
    context = decode(read(Path(core.OUT) / "source-before.json", 8_000_000))
    require(context == core.source_context(require_frozen=True), "Current frozen source closure changed")
    records = {}
    for relative in SOURCE_PATHS:
        actual = witness(root / relative)
        expected = context.get("execution_inputs", {}).get(relative)
        require(expected == {key: actual[key] for key in ("bytes", "sha256")}, "Collector/dependency missing from frozen execution closure: " + relative)
        records[relative] = actual
    build_bytes = verify_witness(build["build_receipt"], 8_000_000)
    build_result = decode(build_bytes)
    require(build_result.get("status") == "SIMULATOR_BUILD_FOR_REAL_UI_PASS"
            and build_result.get("checkout_sha") == context["checkout_sha"], "Actual same-source build is absent")
    prefix = "build/DerivedData/Build/Products/Debug-iphonesimulator/Maktabah.app/"
    expected_images = {name[len(prefix):]: record for name, record in build["complete_native_images"].items() if name.startswith(prefix)}
    settings = _settings(core)
    owner_before = _owner(core, udid, settings)
    database_before, _ = retained.current_database(udid)
    database_before = canonical(database_before)
    require(database_before.is_relative_to(Path(owner_before["dataContainer"])), "Original admitted database is outside its actual app owner")
    db_before = identity(database_before)
    require(db_before["bytes"] == DB_BYTES, "Wrong full-v40 database size")
    manifest_path = database_before.parent / "seforim-installation.json"
    manifest_before = witness(manifest_path, 131072)
    image_before = _image_state(core, udid, expected_images)
    # This is the existing original producer: full bytes/counts, manifest and
    # every installed image are independently checked there, exactly once.
    database, installation = original_call(config, udid, build)
    require(canonical(database) == database_before and identity(database) == db_before,
            "Database identity changed across the original full hash/count admission")
    require(installation.get("database") == {"path": str(database), "bytes": DB_BYTES, "sha256": DB_SHA},
            "Original producer did not admit this exact complete corpus")
    require(_owner(core, udid, settings) == owner_before and witness(manifest_path, 131072) == manifest_before
            and installation.get("installation_manifest") == manifest_before,
            "Actual MCM owner/manifest changed during original admission")
    image_after = _image_state(core, udid, expected_images)
    require(image_before == image_after, "Native image identities changed during original image hashing")
    qualified = installation.get("current_installed_images_before_ui", {}).get("Maktabah.app", {})
    require(qualified.get("installed_app_container") == image_after["appContainer"]
            and qualified.get("images") == expected_images, "Original installed image proof disagrees")
    source_before = witness(Path(core.OUT) / "source-before.json", 8_000_000)
    out.mkdir()
    admission = {"schema": SCHEMA, "status": "ORIGINAL_CURRENT_V40_HASH_IMAGE_ADMISSION_BRACKETED",
        "runID": str(uuid.uuid4()).upper(), "simulatorUDID": udid, "owner": owner_before,
        "database": {"path": str(database), "bytes": DB_BYTES, "sha256": DB_SHA, "identity": db_before},
        "installationManifest": manifest_before, "installedImages": image_after,
        "expectedNativeImages": expected_images, "source": source_before, "sourceInputs": records,
        "buildReceipt": build["build_receipt"], "checkoutSHA": context["checkout_sha"],
        "originalInstallation": installation["original_installation"],
        "originalAdmission": witness(Path(core.OUT) / "actual-full-v40-installation.json", 8_000_000),
        "scope": "Fresh before/after stat witnesses surround existing original hashes; no additional corpus hash or copied database"}
    record = seal(out / "admission.json", admission)
    return database, {**installation, "sqlite_wait_admission": record}


class Collector:
    """One bounded host-owned collector, outside original resource intervals."""
    def __init__(self, core, host):
        self.core, self.host = core, host
        require(core.CORPUS_NAME == "full-v40", "Do not attach this collector to historical v32")
        self.admission_ref = host.installation.get("sqlite_wait_admission")
        require(isinstance(self.admission_ref, dict), "Original hash/image admission needs its actual stat bracket")
        self.admission = decode(verify_witness(self.admission_ref))
        require(self.admission.get("schema") == SCHEMA
                and self.admission.get("status") == "ORIGINAL_CURRENT_V40_HASH_IMAGE_ADMISSION_BRACKETED"
                and self.admission.get("simulatorUDID") == host.udid, "Wrong current observation admission")
        require(self.admission.get("database", {}).get("bytes") == DB_BYTES
                and self.admission["database"].get("sha256") == DB_SHA,
                "Collector admission is not the independently pinned full-v40 corpus")
        self.run_id = canonical_uuid(self.admission["runID"])
        self.out = canonical(Path(self.admission_ref["path"]).parent, directory=True)
        self.capture_root, self.epoch_root = self.out / "captures", self.out / "epochs"
        self.capture_root.mkdir(); self.epoch_root.mkdir()
        self.settings = _settings(core)
        self.clock = DarwinClock()
        self.clock_ref = seal(self.out / "host-clock.json", self.clock.record)
        self.seen, self.total_bytes, self.capture_records, self.failed_records = set(), 0, [], []
        self.baselines, self.epoch_records, self.last_validated = {}, {}, None
        # The common host is created before XCTest launches the application.
        # First actual PID admission occurs when the original begin is handled.
        self._check_identity(process=False)

    def _check_identity(self, *, process=True):
        require(decode(verify_witness(self.admission_ref)) == self.admission, "Collector admission changed")
        for record in self.admission["sourceInputs"].values():
            verify_witness(record)
        verify_witness(self.admission["source"], 8_000_000)
        verify_witness(self.admission["buildReceipt"], 8_000_000)
        verify_witness(self.admission["originalAdmission"], 8_000_000)
        owner = _owner(self.core, self.host.udid, self.settings)
        require(owner == self.admission["owner"], "Current MCM owner changed; require fresh original admission")
        database = self.admission["database"]
        require(identity(database["path"]) == database["identity"], "Current corpus identity changed; never reuse its old hash")
        verify_witness(self.admission["installationManifest"], 131072)
        images = _image_state(self.core, self.host.udid, self.admission["expectedNativeImages"])
        require(images == self.admission["installedImages"], "Current installed image identities changed")
        result = {"ownerSHA256": sha(json.dumps(owner, sort_keys=True).encode()),
                  "databaseIdentity": database["identity"], "manifestSHA256": self.admission["installationManifest"]["sha256"],
                  "installedImagesSHA256": sha(json.dumps(images, sort_keys=True).encode())}
        if process:
            pid, executable = self.host.process()
            require(executable == images["executable"], "Live process is not the admitted original installed image")
            result.update(processID=pid, executable=executable)
        return result

    def _paths(self, container, basename):
        require(re.fullmatch(r"full-v32-reader-[0-9A-F-]{36}", basename or "") is not None,
                "Require the original constrained reader probe basename")
        canonical_uuid(basename.removeprefix("full-v32-reader-"))
        container = canonical(container, directory=True)
        require(str(container) == self.admission["owner"]["dataContainer"], "Probe belongs to a stale/foreign MCM owner")
        directory = canonical(container / "Documents", directory=True)
        return {"request": directory / (basename + ".request"),
                "viewport": directory / (basename + ".viewport.json"),
                "companion": directory / (basename + ".sqlite-fetch-wait.json")}

    def stage_source(self, request, container, *, baseline_start=None):
        """Retain raw bytes before super.validate_source retires the request.

        A staged record cannot qualify anything until original validation
        succeeds; its status and raw data survive a failed original call.
        """
        require(self.host.active is None and self.host.pending_inspector is None, "No source capture during resource/Inspector accounting")
        current = self._check_identity()
        paths = self._paths(container, request["viewportBasename"])
        request_raw, viewport_raw = read(paths["request"], 36), read(paths["viewport"], MAX_VIEWPORT)
        request_id = canonical_uuid(request_raw.decode())
        require(request_id not in self.seen and len(self.seen) < MAX_CAPTURES, "Fresh capture bound/request reuse")
        amount = len(request_raw) + len(viewport_raw)
        require(self.total_bytes + amount <= MAX_TOTAL_BYTES, "Total raw collector allocation bound exceeded")
        folder = self.capture_root / request_id
        folder.mkdir()
        raw_records = {"request": write_new(folder / "request.txt", request_raw),
                       "viewport": write_new(folder / "viewport.json", viewport_raw)}
        self.total_bytes += amount; self.seen.add(request_id)
        try:
            viewport = decode(viewport_raw)
            require(viewport.get("requestID") == request_id and viewport == request["viewport"], "Actual viewport differs from original supplied request")
            descriptor = viewport.get("sqliteFetchWaitObservation")
            require(isinstance(descriptor, dict), "Actual instrumented companion descriptor is absent")
            # The path is derived from the original constrained request, never
            # from an untrusted descriptor. UNAVAILABLE must not read an old file.
            companion_raw = read(paths["companion"], MAX_SNAPSHOT) if descriptor.get("status") == "AVAILABLE" else None
            if companion_raw is not None:
                require(self.total_bytes + len(companion_raw) <= MAX_TOTAL_BYTES, "Total raw collector allocation bound exceeded")
                raw_records["companion"] = write_new(folder / "sqlite-fetch-wait.json", companion_raw)
                self.total_bytes += len(companion_raw)
            # Retain bounded original bytes BEFORE hash/schema rejection so a
            # real malformed fresh output cannot disappear on the next request.
            snapshot = validate_descriptor(viewport, companion_raw, paths["companion"], request_id, current["processID"])
            read_clock = self.clock.sample()
            after = self._check_identity()
            require(after == current and read(paths["request"], 36) == request_raw
                    and read(paths["viewport"], MAX_VIEWPORT) == viewport_raw,
                    "Actual request/source/process identity changed while retaining the companion")
            if companion_raw is not None:
                require(read(paths["companion"], MAX_SNAPSHOT) == companion_raw, "Actual companion changed before retention")
            epoch = self.host.epochs.get(request.get("epoch"), {})
            clock = {"status": "NOT_CALIBRATED", "hostClock": self.clock_ref, "readCompleted": read_clock,
                     "scope": "No numeric conversion from XCTest ProcessInfo uptime or wall timestamps"}
            if snapshot is not None:
                upper = read_clock["machUpperNs"] + self.clock.quantum
                if baseline_start is not None:
                    lower = baseline_start["machLowerNs"] - self.clock.quantum
                    origin = "HOST_WRITTEN_FRESH_PASSIVE_REQUEST"
                    clock["beforeRequestWrite"] = baseline_start
                elif epoch and "resourceEndAcknowledgedUptime" in request:
                    lower = epoch_bounds(epoch["resource_end_host_monotonic"], self.clock.resolution_ns)[0]
                    origin = "ORIGINAL_POST_RESOURCE_END_ACK_CAUSAL_BRACKET"
                    # The unchanged original producer writes this UUID only after
                    # the actual end ACK. This is NOT an assumed equivalence of
                    # XCTest ProcessInfo uptime, app uptime and host wall clocks.
                    clock["originalResourceEndMonotonic"] = epoch["resource_end_host_monotonic"]
                else:
                    lower, origin = None, None
                if lower is not None:
                    require(lower <= snapshot["snapshotNanoseconds"] <= upper,
                            "Actual native DispatchTime snapshot lies outside its causal host/Mach bracket")
                    clock.update(status="ACTUAL_NATIVE_REQUEST_BRACKET_VALIDATED", lowerNanoseconds=lower,
                                 upperNanoseconds=upper, bracketOrigin=origin)
            ticket = {"schema": SCHEMA, "status": "CAPTURED_PENDING_ORIGINAL_VALIDATION",
                "qualification": "NOT_VALIDATED", "runID": self.run_id, "requestID": request_id,
                "admissionSHA256": self.admission_ref["sha256"], "currentIdentity": current,
                "epoch": request.get("epoch"), "targetKey": request["targetKey"],
                "viewportBasename": request["viewportBasename"], "raw": raw_records,
                "originalPaths": {key: str(value) for key, value in paths.items()}, "clock": clock,
                "snapshot": snapshot, "nativeDescriptor": descriptor, "full_performance_acceptance": False}
            ticket["pendingReceipt"] = seal(folder / "captured-pending.json", {k: v for k, v in ticket.items() if k != "snapshot"})
            return ticket
        except Exception as error:
            self.failed_records.append(seal(folder / "capture-rejected.json",
                {"schema": SCHEMA, "status": "RAW_CAPTURE_RETAINED_BUT_REJECTED", "runID": self.run_id,
                 "requestID": request_id, "raw": raw_records, "qualification": "NOT_VALIDATED",
                 "errorType": type(error).__name__, "error": str(error), "full_performance_acceptance": False}))
            raise

    def _finish(self, ticket, proof, *, baseline=False):
        request_id = ticket["requestID"]
        require(self._check_identity() == ticket["currentIdentity"], "Identity changed after original source validation")
        viewport_raw = verify_witness(ticket["raw"]["viewport"], MAX_VIEWPORT)
        require(read(ticket["originalPaths"]["viewport"], MAX_VIEWPORT) == viewport_raw,
                "Actual viewport changed after original validation")
        if "companion" in ticket["raw"]:
            companion = verify_witness(ticket["raw"]["companion"], MAX_SNAPSHOT)
            require(read(ticket["originalPaths"]["companion"], MAX_SNAPSHOT) == companion,
                    "Companion overwritten before original validation completed")
        if baseline:
            require(proof.get("native_process_id") == ticket["currentIdentity"]["processID"], "Baseline source comparison has another PID")
            proof_ref = seal(self.capture_root / request_id / "baseline-original-source-comparison.json", proof)
        else:
            require(proof.get("request_id") == request_id and proof.get("epoch") == ticket["epoch"]
                    and proof.get("target_key") == ticket["targetKey"]
                    and proof.get("native_process_id") == ticket["currentIdentity"]["processID"]
                    and proof.get("native_report") == {"path": ticket["originalPaths"]["viewport"],
                        "bytes": len(viewport_raw), "sha256": sha(viewport_raw)}, "Original successful source proof differs from retained capture")
            source_path = Path(self.core.OUT) / "source-proofs" / (request_id + ".json")
            require(decode(read(source_path, MAX_METADATA)) == proof, "Original host did not retain this exact successful source proof")
            proof_ref = witness(source_path)
        ticket.update(status="CAPTURED_NOT_PERFORMANCE_ACCEPTANCE",
                      qualification="SOURCE_AND_CURRENT_IDENTITY_VALIDATED", originalSourceProof=proof_ref,
                      observationRole="PASSIVE_PRE_EPOCH_BASELINE" if baseline else "ORIGINAL_POST_ACK_SOURCE_REQUEST")
        record = seal(self.capture_root / request_id / "capture.json", {k: v for k, v in ticket.items() if k != "snapshot"})
        self.capture_records.append(record)
        if not baseline:
            self.last_validated = {"basename": ticket["viewportBasename"], "targetKey": ticket["targetKey"],
                "container": str(Path(ticket["originalPaths"]["viewport"]).parent.parent),
                "processID": ticket["currentIdentity"]["processID"]}
            epoch_id = ticket["epoch"]
            if epoch_id is not None:
                epoch = self.host.epochs.get(epoch_id)
                require(epoch is not None, "Validated end capture has no original epoch")
                result = evaluate_epoch(self.baselines.get(epoch_id), ticket, epoch,
                                        self.admission["database"], resolution_ns=self.clock.resolution_ns)
                result.update(baselineCapture=(self.baselines.get(epoch_id) or {}).get("requestID"), endCapture=record,
                              originalEpoch=witness(Path(self.core.OUT) / "resource-epochs" / (epoch_id + ".json")))
                self.epoch_records[epoch_id] = seal(self.epoch_root / (epoch_id + ".json"), result)
        return ticket

    def accept_source(self, ticket, proof):
        return self._finish(ticket, proof)

    def reject_source(self, ticket, error, *, baseline_unavailable=False):
        if ticket is None:
            return
        name = "baseline-not-qualified.json" if baseline_unavailable else "original-validation-failed.json"
        record = seal(self.capture_root / ticket["requestID"] / name,
                      {"schema": SCHEMA, "status": "BASELINE_SOURCE_NOT_QUALIFIED" if baseline_unavailable else "CAPTURED_BUT_ORIGINAL_VALIDATION_FAILED",
                       "requestID": ticket["requestID"], "raw": ticket["raw"],
                       "candidateComparisons": ticket.get("baselineCandidateComparisons", []),
                       "errorType": type(error).__name__, "error": str(error), "full_performance_acceptance": False})
        self.failed_records.append(record)

    def _baseline_source(self, viewport, request, previous_key):
        """Match actual known original catalog bytes, never an assumed old tab.

        The ordinary warm case deliberately navigates away before begin. A
        failed match makes this OPTIONAL baseline unqualified, not a new UI
        correctness assertion. Corrupted source-oracle bytes remain a hard error.
        """
        targets = self.host.targets
        require(isinstance(targets, dict) and 0 < len(targets) <= 64, "Bound the actual original target catalog")
        sample = viewport.get("fullV32SourceObservation", {})
        length = sample.get("sourceUTF16Length") if isinstance(sample, dict) else None
        if not isinstance(sample, dict) or sample.get("status") != "AVAILABLE" or type(length) is not int or length <= 0:
            return None, [{"status": "ORIGINAL_MOUNTED_SOURCE_UNAVAILABLE"}]
        order = []
        requested = targets.get(request["targetKey"], {})
        # The existing reader-open workload's genuine 'away' target is an
        # ordering hint only. It is accepted solely after actual byte comparison.
        if request.get("kind") == "reader-open":
            away = next((row for row in self.host.catalog["targets"] if row.get("bookID") != requested.get("bookID")), None)
            if away is not None:
                order.append(away["key"])
        order.extend([request["targetKey"], previous_key, *targets.keys()])
        order = list(dict.fromkeys(order))
        attempts = []
        for key in order:
            target = targets.get(key)
            if target is None or target.get("sourceUTF16Length") != length:
                continue
            source = canonical(Path(self.host.catalog_dir) / target["sourceFile"])
            require(source.parent == canonical(self.host.catalog_dir, directory=True), "Original source oracle escaped its catalog")
            before = identity(source)
            source_record = witness(source, MAX_SOURCE_REFERENCE)
            require(source_record["sha256"] == target["sourceSHA256"] and identity(source) == before,
                    "Independent original baseline source bytes changed")
            try:
                proof = self.core.exact_source_comparison(self.host.catalog_dir, target, viewport)
            except (ValueError, KeyError, UnicodeError) as error:
                require(identity(source) == before, "Original source oracle changed during failed comparison")
                attempts.append({"targetKey": key, "source": source_record, "status": "CURRENT_SOURCE_DOES_NOT_MATCH",
                                 "reason": str(error)[:256]})
                continue
            require(identity(source) == before, "Original source oracle changed during actual comparison")
            attempts.append({"targetKey": key, "source": source_record, "status": "ACTUAL_ORIGINAL_BOUNDED_SOURCE_MATCH"})
            return (key, proof), attempts
        return None, attempts

    def before_begin(self, request):
        """Optional actual idle baseline, never a fabricated process-start one.

        This creates only the original passive request and removes only its own
        verified UUID. The original begin is not called until cleanup finishes.
        No new end probe is inserted before the resource-end acknowledgement.
        """
        epoch_id = canonical_uuid(request["epoch"])
        require(epoch_id not in self.baselines and epoch_id not in self.host.epochs, "Epoch baseline reuse")
        require(self.host.active is None and self.host.pending_inspector is None, "Baseline cannot overlap accounting")
        last = self.last_validated
        if last is None:
            self.baselines[epoch_id] = None
            return
        current = self._check_identity()
        # Even a new PID must answer a NEW actual request. No old-PID snapshot
        # or inferred process-start baseline is reused. An unknown/hidden probe
        # in the new process times out and remains unqualified below.
        paths = self._paths(last["container"], last["basename"])
        require(not paths["request"].exists() and not paths["request"].is_symlink(), "Never overwrite an existing original source request")
        request_id = str(uuid.uuid4()).upper()
        require(request_id not in self.seen and request_id not in self.host.source_request_ids, "Fresh baseline UUID required")
        before_write = self.clock.sample()
        with paths["request"].open("xb") as stream:
            stream.write(request_id.encode())
        request_identity = identity(paths["request"])
        ticket = None
        try:
            deadline = time.monotonic() + 3
            viewport = None
            while time.monotonic() < deadline:
                if paths["viewport"].exists():
                    candidate = decode(read(paths["viewport"], MAX_VIEWPORT))
                    if candidate.get("requestID") == request_id:
                        viewport = candidate
                        break
                time.sleep(0.05)
            if viewport is None:
                self.baselines[epoch_id] = None
                seal(self.epoch_root / (epoch_id + ".baseline-unavailable.json"),
                     {"schema": SCHEMA, "status": "NO_FRESH_MOUNTED_READER_BASELINE", "requestID": request_id,
                      "epoch": epoch_id, "full_performance_acceptance": False})
                return
            target_request = {"viewportBasename": last["basename"], "viewport": viewport,
                              "targetKey": last["targetKey"], "epoch": epoch_id}
            ticket = self.stage_source(target_request, last["container"], baseline_start=before_write)
            matched, comparisons = self._baseline_source(viewport, request, last["targetKey"])
            ticket["baselineCandidateComparisons"] = comparisons
            ticket["requestedResourceTargetKey"] = request["targetKey"]
            if matched is None:
                self.baselines[epoch_id] = None
                self.reject_source(ticket, ValueError("No known original catalog source matches the actually mounted reader"), baseline_unavailable=True)
                return
            ticket["targetKey"], proof = matched
            self.baselines[epoch_id] = self._finish(ticket, proof, baseline=True)
        except Exception as error:
            self.reject_source(ticket, error)
            raise
        finally:
            require(identity(paths["request"]) == request_identity and read(paths["request"], 36).decode() == request_id,
                    "Owned baseline request changed; never delete another producer's request")
            paths["request"].unlink()

    def finalize(self):
        self._check_identity(process=False)
        for record in self.capture_records:
            captured = decode(verify_witness(record))
            for raw in captured["raw"].values():
                verify_witness(raw, MAX_SNAPSHOT)
            verify_witness(captured["originalSourceProof"])
        for epoch_id, epoch in self.host.epochs.items():
            if epoch_id not in self.epoch_records:
                result = evaluate_epoch(self.baselines.get(epoch_id), None, epoch,
                                        self.admission["database"], resolution_ns=self.clock.resolution_ns)
                self.epoch_records[epoch_id] = seal(self.epoch_root / (epoch_id + ".json"), result)
        return seal(self.out / "RESULT.json", {"schema": SCHEMA,
            "status": "PASSIVE_COMPANIONS_RETAINED_REVIEW_EPOCH_QUALIFICATION" if self.capture_records else "NO_PASSIVE_COMPANIONS_RETAINED",
            "admission": self.admission_ref, "clock": self.clock_ref, "captures": self.capture_records,
            "rejectedCaptures": self.failed_records,
            "epochCoverage": self.epoch_records, "rawBytesRetained": self.total_bytes,
            "captureLimit": MAX_CAPTURES, "rawBytesLimit": MAX_TOTAL_BYTES,
            "full_performance_acceptance": False,
            "scope": "Actual source requests/corpus/process identities only; missing or ambiguous coverage is not measured"})


def observation_host(previous_host, core):
    """Compose AFTER the v40 natural-target subclass; do not patch common/v32.

    Hook methods are __init__, begin, validate_source, run. There is deliberately
    no end override: its original resource-end ACK contract stays unchanged.
    """
    class SQLiteWaitHost(previous_host):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, **kwargs)
            self.sqlite_wait_collector = Collector(core, self)

        def begin(self, request):
            self.sqlite_wait_collector.before_begin(request)
            return super().begin(request)

        def validate_source(self, request, container):
            ticket = None
            try:
                ticket = self.sqlite_wait_collector.stage_source(request, container)
                proof = super().validate_source(request, container)
                self.sqlite_wait_collector.accept_source(ticket, proof)
                return proof
            except Exception as error:
                self.sqlite_wait_collector.reject_source(ticket, error)
                raise

        def run(self):
            try:
                return super().run()
            finally:
                try:
                    self.sqlite_wait_collector.finalize()
                except Exception as error:
                    # The original driver's post-stop check consults host.error.
                    # A failed collector must not disappear as an unhandled
                    # daemon-thread exception after the original UI has passed.
                    self.error = self.error or "SQLiteWaitCollectorFinalizationFailed:" + type(error).__name__
                    try:
                        seal(self.sqlite_wait_collector.out / "FINALIZATION_FAILED.json",
                             {"schema": SCHEMA, "status": "COLLECTOR_FINALIZATION_FAILED",
                              "errorType": type(error).__name__, "error": str(error),
                              "full_performance_acceptance": False})
                    except Exception:
                        pass  # host.error remains the fail-closed original gate.
    return SQLiteWaitHost


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="operation", required=True)
    check = sub.add_parser("parse-component", help="Shape-check retained raw snapshots; never app/PERF qualification")
    check.add_argument("snapshot", type=Path, nargs="+")
    check.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    require(0 < len(args.snapshot) <= 32, "Bound component parser input list")
    rows = []
    for path in args.snapshot:
        path = canonical(path)
        record = witness(path, MAX_SNAPSHOT)
        value = validate_snapshot(decode(verify_witness(record, MAX_SNAPSHOT)))
        rows.append({"input": record, "nativeStatus": value["status"], "processID": value["processID"],
                     "requestID": value["requestID"], "completeLifetimeCoverage": value["completeLifetimeCoverage"]})
    seal(args.output, {"schema": SCHEMA, "status": "RETAINED_COMPONENT_SCHEMA_COMPATIBILITY_ONLY", "inputs": rows,
                      "nativeApplicationExecuted": False, "productionCorpusRead": False,
                      "epochCoverageQualified": False, "full_performance_acceptance": False})


if __name__ == "__main__":
    main()

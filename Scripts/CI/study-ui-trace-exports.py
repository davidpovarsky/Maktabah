#!/usr/bin/env python3
"""Export observed tables from an already stopped original v40 trace.

This module never records, launches an app, changes a Simulator, decodes a
metric or produces performance acceptance. It preserves actual raw exports
for a later, separately qualified row/timebase/PID/coverage interpretation.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import runpy
import shutil
import stat
import subprocess
import sys
import time
import uuid
import xml.etree.ElementTree as ET

SCHEMA = "otzaria.original-trace-exports/1"
REQUEST_SCHEMA = "otzaria.original-trace-export-request/1"
CAPTURE_STATUS = "ACTUAL_TRACE_RETAINED_COVERAGE_AND_SCHEMA_REVIEW_REQUIRED"
MAX_JSON = 4 * 1024 * 1024
MAX_TOC = 8 * 1024 * 1024
MAX_TRACE_FILES = 20000
MAX_TRACE_BYTES = 16 * 1024**3
MAX_TABLES = 32
PS_ROW = re.compile(r"\s*(\d+)\s+(\d+)\s+([A-Za-z]{3}\s+[A-Za-z]{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2}\s+\d{4})\s+(.+)\Z")
COMMON = "Scripts/CI/reader-full-v32-ui-observation.py"
SELF = "Scripts/CI/study-ui-trace-exports.py"
MISSING = {
    "longest_main_thread_slice": "NOT_QUALIFIED: exact main-thread identity, interval/state meaning, timebase and complete coverage require actual row review",
    "main_actor_execution": "NOT_QUALIFIED: no Swift actor/executor/job schema adapter or await-to-execution inference",
    "layout_hitches": "NOT_QUALIFIED: actual process/context/frame joins and event/drop coverage require actual row review",
    "fps": "NOT_QUALIFIED: hitch events do not count every displayed frame",
    "trace_to_host_clock": "NOT_QUALIFIED: original raw clocks retained; no assumed conversion from trace-relative time",
    "empty_or_dropped_tables": "NOT_QUALIFIED: absent/empty/unknown/drop-marked data never means zero hitches or zero main-thread work",
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def finite(value):
    return type(value) in (int, float) and math.isfinite(value)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def stable(st):
    # Reading may change atime. It is not evidence that file bytes changed.
    return (st.st_dev, st.st_ino, st.st_size, st.st_mtime_ns, st.st_ctime_ns, st.st_mode)


def path_file(value):
    path = Path(value)
    require(path.is_absolute() and path.resolve(strict=True) == path
            and stat.S_ISREG(path.lstat().st_mode), "Canonical regular input file required")
    return path


def file_record(value, limit=MAX_JSON, *, keep=False):
    path = path_file(value)
    data, h = bytearray(), hashlib.sha256()
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    with os.fdopen(fd, "rb") as stream:
        before = os.fstat(stream.fileno())
        require(before.st_size <= limit, "Actual file exceeds this explicit input bound")
        total = 0
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            total += len(block)
            require(total <= limit, "Input grew beyond its bound")
            h.update(block)
            if keep:
                data.extend(block)
        require(stable(before) == stable(os.fstat(stream.fileno())) == stable(path.stat()),
                "Input identity or bytes changed during readback")
    return {"path": str(path), "bytes": total, "sha256": h.hexdigest()}, bytes(data)


def verify(record, limit=MAX_JSON, *, keep=False):
    require(isinstance(record, dict) and set(record) == {"path", "bytes", "sha256"}
            and type(record["bytes"]) is int and 0 <= record["bytes"] <= limit
            and isinstance(record["sha256"], str) and re.fullmatch(r"[a-f0-9]{64}", record["sha256"]),
            "Exact immutable original FileWitness required")
    actual, raw = file_record(record["path"], limit, keep=keep)
    require(actual == record, "Original file witness no longer matches")
    return raw


def decode(raw):
    def pairs(items):
        value = {}
        for key, item in items:
            require(key not in value, "Duplicate JSON key")
            value[key] = item
        return value
    def invalid(value):
        raise ValueError("Nonfinite JSON value")
    def decimal(value):
        number = float(value)
        require(math.isfinite(number), "Nonfinite JSON exponent")
        return number
    return json.loads(raw, object_pairs_hook=pairs, parse_constant=invalid, parse_float=decimal)


def json_record(record):
    return decode(verify(record, keep=True))


def xml(raw, *, bound=MAX_TOC):
    require(raw and len(raw) <= bound and b"<!DOCTYPE" not in raw.upper()
            and b"<!ENTITY" not in raw.upper(), "Bounded XML without a DTD/entity declaration required")
    root = ET.fromstring(raw)
    require(sum(1 for _ in root.iter()) <= 200000, "XML node bound exceeded")
    return root


def xpath_literal(value):
    require(isinstance(value, str) and value and len(value) <= 4096
            and all(ord(c) >= 32 for c in value), "Bounded literal observed attribute value required")
    if '"' not in value:
        return '"' + value + '"'
    if "'" not in value:
        return "'" + value + "'"
    parts = value.split('"')
    return "concat(" + ',\'"\','.join('"' + part + '"' for part in parts) + ")"


def exact_predicate(attributes):
    require(attributes and all(re.fullmatch(r"[A-Za-z_][A-Za-z0-9_.-]*", key) for key in attributes),
            "Unexpected observed XML attribute name")
    # Without count(@*), a table with a strict superset of the selected
    # attributes also matches and silently combines two different streams.
    return "[count(@*)=" + str(len(attributes)) + " and " + " and ".join(
        "@" + key + "=" + xpath_literal(value) for key, value in sorted(attributes.items())) + "]"


def observed_tables(raw):
    root = xml(raw)
    require(root.tag == "trace-toc", "Only an actual xctrace trace-toc export is supported")
    runs = root.findall("run")
    require(runs and len(runs) <= 32, "Missing or excessive actual trace runs")
    records = []
    seen_runs = set()
    for run in runs:
        attrs = dict(run.attrib)
        require("number" in attrs and re.fullmatch(r"[1-9][0-9]*", attrs["number"])
                and attrs["number"] not in seen_runs, "Actual run identity is missing or duplicated")
        seen_runs.add(attrs["number"])
        for table in run.findall("data/table"):
            observed = dict(table.attrib)
            require(isinstance(observed.get("schema"), str) and observed["schema"], "Actual table has no observed schema")
            selector = "/trace-toc/run" + exact_predicate(attrs) + "/data/table" + exact_predicate(observed)
            record = {"run_attributes": attrs, "table_attributes": observed, "xpath": selector}
            record["table_id"] = digest(json.dumps(record, sort_keys=True, separators=(",", ":")).encode())
            records.append(record)
    require(len(records) <= 4096, "Actual TOC table inventory exceeded its bound")
    occurrences = {}
    for row in records:
        occurrences[row["table_id"]] = occurrences.get(row["table_id"], 0) + 1
    for row in records:
        row["ambiguous"] = occurrences[row["table_id"]] != 1
    return records


def select_observed_tables(inventory, selections):
    require(isinstance(selections, list) and 0 < len(selections) <= MAX_TABLES, "Explicit bounded actual table selections required")
    result, seen = [], set()
    for choice in selections:
        require(isinstance(choice, dict) and set(choice) == {"run_attributes", "table_attributes"},
                "Select complete observed run/table attributes, never guessed schema-only names")
        matches = [row for row in inventory if all(row[key] == choice[key] for key in choice)]
        require(len(matches) == 1 and not matches[0]["ambiguous"] and matches[0]["table_id"] not in seen,
                "Requested actual run/table is absent, ambiguous or repeated")
        seen.add(matches[0]["table_id"])
        result.append(matches[0])
    return result


def capture_identity(capture, start):
    require(capture.get("status") == CAPTURE_STATUS and type(capture.get("toc_export_exit")) is int
            and capture["toc_export_exit"] == 0
            and start.get("status") == "READY_ACTUAL_APPLE_NOTIFICATION"
            and capture.get("ready_signal") == start.get("ready_signal") == "xctrace --notify-tracing-started / Darwin notify",
            "A genuine stopped original capture and ready/TOC receipts are required")
    keys = ("command", "recorder_pid", "started_host_monotonic", "started_host_wall_ns",
            "ready_host_monotonic", "ready_host_wall_ns", "ready_signal")
    require(all(capture.get(key) == start.get(key) for key in keys), "Capture start/stop source identity differs")
    pid = capture.get("recorder_pid")
    cleanup = capture.get("owned_process_group_cleanup", {})
    require(type(pid) is int and pid > 1 and cleanup.get("owned_pgid") == pid
            and cleanup.get("group_state") == "GONE_CHECKED", "Original owned recorder exit is unverified")
    command = capture.get("command")
    require(isinstance(command, list) and command[:3] == ["xcrun", "xctrace", "record"]
            and command.count("--output") == command.count("--device") == 1
            and "--all-processes" in command and "--launch" not in command,
            "Only the existing owned Simulator AppleTraceCapture producer is admitted")
    directory = Path(command[command.index("--output") + 1])
    udid = command[command.index("--device") + 1]
    require(directory.is_absolute() and directory.suffix == ".trace"
            and str(uuid.UUID(udid)).upper() == udid, "Original trace path or actual owned UDID differs")
    mono = [capture.get(key) for key in ("started_host_monotonic", "ready_host_monotonic", "stopped_host_monotonic")]
    wall = [capture.get(key) for key in ("started_host_wall_ns", "ready_host_wall_ns", "stopped_host_wall_ns")]
    require(all(finite(value) and value >= 0 for value in mono) and mono == sorted(mono)
            and all(type(value) is int and value > 0 for value in wall), "Actual original clock anchors are absent or malformed")
    return directory, udid


def epoch_identity(value, capture, udid, images):
    identifier = value.get("epoch")
    require(isinstance(identifier, str) and str(uuid.UUID(identifier)).upper() == identifier
            and value.get("status") == "OBSERVED_NOT_PERFORMANCE_ACCEPTANCE", "Original completed resource epoch required")
    pid, executable = value.get("processID"), value.get("executable")
    require(type(pid) is int and pid > 1 and isinstance(executable, str) and Path(executable).is_absolute()
            and "/devices/" + udid.lower() + "/data/" in executable.lower(), "Actual original Simulator process identity is missing")
    app = images.get("Maktabah.app", {})
    container = Path(app.get("installed_app_container", "/unqualified"))
    path = Path(executable)
    require(path.is_relative_to(container) and path.relative_to(container).as_posix() in app.get("images", {}),
            "Epoch executable is not in the actual installed image receipt")
    begin, end = value.get("resource_start_host_monotonic"), value.get("resource_end_host_monotonic")
    require(all(finite(v) for v in (begin, end)) and capture["ready_host_monotonic"] <= begin <= end <= capture["stopped_host_monotonic"],
            "Original resource interval falls outside the actual ready/stopped trace anchors")
    require(all(type(value.get(key)) is int and value[key] > 0 for key in
                ("resource_start_host_wall_ns", "resource_end_host_wall_ns")), "Original integer wall-clock witnesses required")
    samples = value.get("samples")
    require(isinstance(samples, list) and 2 <= len(samples) <= 20000, "Original endpoint/resource samples are missing")
    previous = begin
    for row in samples:
        require(row.get("processID") == pid and finite(row.get("host_query_started_monotonic"))
                and finite(row.get("host_monotonic")) and previous <= row["host_monotonic"] <= end
                and row["host_query_started_monotonic"] <= row["host_monotonic"]
                and type(row.get("host_wall_ns")) is int and row["host_wall_ns"] > 0,
                "Actual resource sample PID/clock sequence differs")
        previous = row["host_monotonic"]
    return {"epoch": identifier, "processID": pid, "executable": executable,
            "installedImage": app["images"][path.relative_to(container).as_posix()],
            "resource_start_host_monotonic": begin, "resource_end_host_monotonic": end,
            "resource_start_host_wall_ns": value["resource_start_host_wall_ns"],
            "resource_end_host_wall_ns": value["resource_end_host_wall_ns"],
            "traceClockConversion": "NOT_QUALIFIED", "originalSampleCount": len(samples)}


def trace_manifest(capture, directory):
    require(directory.resolve(strict=True) == directory and directory.is_dir(), "Actual original trace directory was redirected")
    rows = capture.get("files")
    require(isinstance(rows, list) and 0 < len(rows) <= MAX_TRACE_FILES, "Original complete trace manifest required")
    paths = {row.get("path") for row in rows}
    require(len(paths) == len(rows) and sum(row.get("bytes", MAX_TRACE_BYTES + 1) for row in rows) <= MAX_TRACE_BYTES,
            "Original trace manifest is duplicated or exceeds its read bound")
    actual, pending, entries = set(), [directory], 0
    while pending:
        path = pending.pop(); entries += 1
        require(entries <= 2 * MAX_TRACE_FILES and not path.is_symlink(), "Trace tree contains an alias or excessive entries")
        if path.is_dir():
            pending.extend(path.iterdir())
        else:
            require(path.is_file(), "Unexpected trace-tree object")
            actual.add(str(path))
    require(paths == actual, "Trace tree differs from the stopped original manifest")
    for row in rows:
        require(Path(row["path"]).is_relative_to(directory), "Original trace member escaped its directory")
        verify(row, MAX_TRACE_BYTES)
    return {"files": len(rows), "bytes": sum(row["bytes"] for row in rows),
            "manifestSHA256": digest(json.dumps(rows, sort_keys=True, separators=(",", ":")).encode())}


def load_module(path):
    spec = importlib.util.spec_from_file_location("trace_export_" + path.stem.replace("-", "_"), path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def original_context(repository, producer):
    root = Path(repository)
    require(root.is_absolute() and root.resolve(strict=True) == root
            and Path(__file__).resolve() == root / SELF, "Use the current committed original helper checkout")
    wrapper = load_module(root / "Scripts/CI/reader-full-v40-ui-observation.py")
    core = wrapper.load_core()
    context = (load_module(root / "Scripts/CI/reader-v40-perbook-mode-performance.py").source_context(core, True)
               if producer == "per-book-mode-cell" else core.source_context(require_frozen=True))
    for name in (SELF, COMMON, "Scripts/CI/runtime27_interruption.py"):
        actual = core.command(["git", "hash-object", str(root / name)]).stdout.strip()
        require(actual == core.git("rev-parse", "HEAD:" + name), "Export/support source differs from current committed checkout")
    require(context["execution_inputs"][COMMON] == {k: file_record(root / COMMON)[0][k] for k in ("bytes", "sha256")},
            "Original capture source is not the recorded frozen execution source")
    return core, context


def plan(request_path, *, repository):
    request_ref, raw = file_record(request_path, keep=True)
    request = decode(raw)
    require(request.get("schema") == REQUEST_SCHEMA and request.get("producer") in ("full-v40", "per-book-mode-cell"),
            "Explicit existing original producer required")
    core, context = original_context(repository, request["producer"])
    result, capture, start = (json_record(request[key]) for key in ("original_result", "capture_result", "capture_start"))
    base = Path(request["original_result"]["path"]).parent
    require(Path(request["capture_result"]["path"]) == base / "traces/capture-result.json"
            and Path(request["capture_start"]["path"]) == base / "traces/capture-start.json"
            and result.get("actual_continuous_trace") == capture, "Original result and exact actual capture receipts differ")
    if request["producer"] == "full-v40":
        require(result.get("source") == context and result.get("corpus_profile") == "full-v40"
                and result.get("source_and_built_binary_bytes_unchanged") is True
                and result.get("database_bytes_unchanged") is True
                and result.get("cleanup_or_post_verification_failures") == [], "Original full-v40 source/image/corpus/cleanup post-verification is incomplete")
        images = result.get("current_installed_images_after_ui", {})
        inventory_base = base
    else:
        require(result.get("source_before") == result.get("source_after") == context
                and result.get("post_verification_failures") == []
                and result.get("owned_runtime_cleanup", {}).get("verified") is True,
                "Original mode-cell source/producer cleanup is incomplete")
        images = result.get("installed_images_after", {})
        inventory_base = base.parent
    require(Path(request["instrument_inventory"]["path"]) == inventory_base / "actual-apple-instrument-capabilities.json",
            "Use the actual original producer's tool inventory")
    instruments = json_record(request["instrument_inventory"])
    require(all(type(instruments.get(key)) is int and instruments[key] == 0
                for key in ("export_help_exit", "xctrace_version_exit", "xcode_exit"))
            and all(flag in instruments.get("export_help", "") for flag in ("--input", "--xpath", "--output")),
            "Original installed export interface/version was not observed successfully")
    directory, udid = capture_identity(capture, start)
    require(directory.parent == base / "traces", "Trace is not the actual original producer's owned bundle")
    trace = trace_manifest(capture, directory)
    toc_raw = verify(capture["toc"], MAX_TOC, keep=True)
    inventory = observed_tables(toc_raw)
    choices = request.get("tables")
    require(isinstance(choices, list), "An explicit observed selection list, empty only for inventory, is required")
    chosen = select_observed_tables(inventory, choices) if choices else []
    epoch_refs = request.get("epochs")
    require(isinstance(epoch_refs, list) and 0 < len(epoch_refs) <= 256, "Every actual original epoch witness must be supplied")
    expected = {str(path) for path in (base / "resource-epochs").iterdir()}
    require(len(epoch_refs) == len({row.get("path") for row in epoch_refs})
            and {row.get("path") for row in epoch_refs} == expected, "The actual resource-epoch directory was partially selected")
    epochs = []
    for record in epoch_refs:
        value = json_record(record)
        require(Path(record["path"]).name == value.get("epoch", "") + ".json", "Actual epoch file identity changed")
        epochs.append({"file": record, **epoch_identity(value, capture, udid, images)})
    schema_sources = request.get("installed_schema_snapshots", [])
    require(isinstance(schema_sources, list) and len(schema_sources) <= 16, "Bound installed schema snapshots")
    definitions = []
    for record in schema_sources:
        element = xml(verify(record, MAX_TOC, keep=True))
        require(element.tag == "schemas", "Actual installed schema-declaration snapshot required")
        definitions.append({"file": record, "names": [node.attrib.get("name") for node in element.findall("schema")],
                            "scope": "Retained installed declarations only; no proof these tables were captured"})
    return {"schema": SCHEMA, "status": ("OBSERVED_TABLE_EXPORT_PLAN_METRICS_UNQUALIFIED" if chosen
            else "OBSERVED_TOC_INVENTORY_NO_TABLES_SELECTED"), "request": request_ref,
            "source": context, "helper": file_record(Path(repository) / SELF)[0], "producer": request["producer"],
            "original_result": request["original_result"], "original_result_status": result.get("status"),
            "capture_start": request["capture_start"], "capture_result": request["capture_result"], "toc": capture["toc"],
            "trace_directory": str(directory), "trace_manifest": trace, "simulatorUDID": udid,
            "tool_inventory": request["instrument_inventory"], "observed_tables": inventory, "selected_tables": chosen,
            "epochs": epochs, "schema_declarations": definitions,
            "clock_anchors": {key: capture[key] for key in ("started_host_monotonic", "started_host_wall_ns",
                "ready_host_monotonic", "ready_host_wall_ns", "stopped_host_monotonic", "stopped_host_wall_ns")},
            "record_exit_scope": "Original source-qualified recorder group GONE_CHECKED; no invented numeric recorder exit code",
            "metrics": {}, "missing_or_unqualified_metrics": MISSING, "performance_acceptance": False,
            "native_executed_by_exporter": 0}


def allocated(directory):
    total, entries, pending, seen = 0, 0, [directory], set()
    while pending:
        path = pending.pop(); entries += 1
        try:
            value = path.lstat()
        except FileNotFoundError:
            continue
        require(entries <= 4096 and not stat.S_ISLNK(value.st_mode), "Owned export output contains an alias or excessive entries")
        if stat.S_ISDIR(value.st_mode):
            pending.extend(path.iterdir())
        else:
            require(stat.S_ISREG(value.st_mode), "Unexpected owned export output type")
            key = (value.st_dev, value.st_ino)
            if key not in seen:
                seen.add(key); total += value.st_blocks * 512
    return total


def write_new(path, value):
    with path.open("x") as stream:
        json.dump(value, stream, ensure_ascii=False, sort_keys=True, indent=2, allow_nan=False)
        stream.write("\n")


def inspect_raw_xml(path, byte_limit):
    """Bounded structural inventory, without interpreting an Apple row schema."""
    require(path_file(path) == path, "Actual raw export required")
    before = path.stat()
    parser = ET.XMLPullParser(events=("start", "end"))
    size = rows = nodes = depth = 0
    tail, root_tag, stack = b"", None, []
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(65536), b""):
            size += len(chunk)
            require(size <= byte_limit, "Actual raw export exceeds its declared byte bound")
            inspected = (tail + chunk).upper()
            require(b"<!DOCTYPE" not in inspected and b"<!ENTITY" not in inspected,
                    "Raw XML DTD/entity declarations are not supported")
            tail = chunk[-16:]
            parser.feed(chunk)
            for event, element in parser.read_events():
                if event == "start":
                    nodes += 1; depth += 1
                    stack.append(element)
                    require(nodes <= 2000000 and depth <= 64, "Raw XML structure exceeds this bounded inventory")
                    if root_tag is None:
                        root_tag = element.tag
                    if element.tag == "row":
                        rows += 1
                else:
                    depth -= 1
                    require(stack and stack.pop() is element, "Malformed raw XML stack")
                    if stack:
                        stack[-1].remove(element)
                    element.clear()
        parser.close()
    require(root_tag is not None and depth == 0 and stable(before) == stable(path.stat()),
            "Raw XML export is empty, incomplete or changed during inspection")
    return {"root_tag": root_tag, "observed_row_elements": rows, "observed_xml_nodes": nodes,
            "qualification": "RAW_ROW_ELEMENTS_RETAINED_NOT_QUALIFIED" if rows else "NO_ROW_ELEMENTS_OBSERVED_STRUCTURE_UNQUALIFIED",
            "row_definition": "Unnamespaced XML elements named row only; actual Apple schema, references, event absence and units remain unqualified"}


def kernel_process(pid):
    """Bounded actual Darwin identity; argv changes across xcrun exec are retained."""
    require(type(pid) is int and pid > 0, "A directly created positive PID is required")
    value = subprocess.run(["/bin/ps", "-ww", "-p", str(pid), "-o", "pid=,ppid=,lstart=,command="],
        capture_output=True, text=True, timeout=2, env={**os.environ, "LC_ALL": "C"})
    require(value.returncode in (0, 1) and not value.stderr and len(value.stdout.encode()) <= 32768,
            "Actual process identity is failed, diagnostic or outside its bound")
    rows = [line for line in value.stdout.splitlines() if line.strip()]
    if not rows:
        return None
    require(len(rows) == 1, "Ambiguous actual PID identity")
    match = PS_ROW.fullmatch(rows[0])
    require(match is not None and int(match[1]) == pid, "Malformed actual process identity")
    return {"pid": pid, "parentPID": int(match[2]), "startUTC": match[3], "command": match[4]}


def created_export_identity(child, row):
    """A reaped Popen may never acquire a later process with the same PID."""
    original_exit = child.poll()
    actual = kernel_process(child.pid)
    if original_exit is not None:
        require(actual is None, "Refuse a live reused PID after the original exporter was reaped")
        return None
    if actual is None:
        require(child.poll() is not None and kernel_process(child.pid) is None,
                "The original exporter has no verifiable live identity or observed exit")
        return None
    require(actual.get("pid") == child.pid and actual.get("parentPID") == row["parent_pid"],
            "Actual exporter PID or parent differs from its recorded creation")
    previous = row["original_kernel_identity"]
    if previous is not None:
        require(all(actual.get(key) == previous.get(key) for key in ("pid", "parentPID", "startUTC")),
                "Refuse a replaced original exporter kernel identity")
    try:
        require(os.getpgid(child.pid) == child.pid, "Actual exporter is outside its created process group")
    except ProcessLookupError:
        require(child.poll() is not None and kernel_process(child.pid) is None,
                "Exporter group vanished without an observed original exit")
        return None
    if child.poll() is not None:
        require(kernel_process(child.pid) is None, "A live PID replaced the exporter during identity observation")
        return None
    # xcrun may exec the selected tool without changing the actual process.
    # Its command observations are evidence, not a brittle equality to relative
    # launch argv. Parent/start/group and the unreaped direct Popen bind it.
    if previous is None:
        row["original_kernel_identity"] = dict(actual)
    row["last_verified_kernel_identity"] = dict(actual)
    return actual


def stop_created_export(child, row, interruption):
    def guarded_killpg(pgid, kind):
        require(pgid == child.pid, "Only the directly created exporter group may be examined")
        current = created_export_identity(child, row)
        if current is None:
            # A recycled group can outlive its replacement leader. Absence of
            # that leader therefore permits only a read-only absence probe,
            # never adopting any remaining group as ours and signaling it.
            os.killpg(pgid, 0)
            raise ValueError("A remaining group without its verifiable original leader is unowned")
        return os.killpg(pgid, kind)
    cleanup = interruption["stop_owned_process_group"](
        child, grace_seconds=1, kill_wait_seconds=.5, killpg_fn=guarded_killpg)
    row["original_owned_cleanup"] = cleanup
    row["actual_exit_observed_after_cleanup"] = child.poll()
    row["owned_cleanup_verified"] = (row["actual_exit_observed_after_cleanup"] is not None
        and cleanup.get("group_state") == "GONE_CHECKED" and cleanup.get("owned_pgid") == child.pid
        and not cleanup.get("probe_errors") and not cleanup.get("send_errors")
        and kernel_process(child.pid) is None)
    require(row["owned_cleanup_verified"], "Original exporter or created group exit remains unverified")


def export_child(command, *, directory, stem, timeout, hard_deadline, output_budget, free_reserve, interruption):
    require(command[:3] == ["xcrun", "xctrace", "export"], "Only an actual existing trace export may be launched")
    row = {"command": list(command), "status": "EXPORT_STARTED_NOT_QUALIFIED", "owned_cleanup_verified": False,
           "spawn_attempted": False, "parent_pid": os.getpid(), "original_kernel_identity": None,
           "started_monotonic_ns": time.monotonic_ns(), "started_unix_ns": time.time_ns()}
    child, failure = None, None
    try:
        used = allocated(directory)
        require(used < output_budget and shutil.disk_usage(directory).free >= output_budget - used + free_reserve,
                "Explicit export storage reservation does not fit")
        with (directory / (stem + ".stdout.log")).open("xb") as stdout, (directory / (stem + ".stderr.log")).open("xb") as stderr:
            require(time.monotonic() < hard_deadline, "Whole export-command deadline expired before launch")
            row["spawn_attempted"] = True
            child = subprocess.Popen(command, stdout=stdout, stderr=stderr, start_new_session=True)
            row["owned_pid"] = child.pid
            require(created_export_identity(child, row) is not None,
                    "Exporter ended before actual kernel identity qualification; preserve raw output without admission")
            deadline = min(hard_deadline, time.monotonic() + timeout)
            while child.poll() is None:
                require(time.monotonic() < deadline, "Owned exporter exceeded its explicit child/whole-session lifetime")
                require(allocated(directory) <= output_budget and shutil.disk_usage(directory).free >= free_reserve,
                        "Owned export crossed its explicit byte/free-space bound; preserve partial output")
                try:
                    child.wait(timeout=min(.25, max(.001, deadline - time.monotonic())))
                except subprocess.TimeoutExpired:
                    pass
        row["exit"] = child.returncode
        require(row["exit"] == 0, "Actual original table export failed")
        require(allocated(directory) <= output_budget, "Final export bytes exceeded the reserved bound")
        row["status"] = "RAW_EXPORT_COMPLETED_METRICS_UNQUALIFIED"
    except BaseException as error:
        failure = error
        row.update(status="FAILED_OR_INCOMPLETE_EXPORT", error_type=type(error).__name__, error=str(error))
    finally:
        if child is not None:
            try:
                stop_created_export(child, row, interruption)
            except BaseException as error:
                failure = failure or error
                row.update(status="FAILED_OR_INCOMPLETE_EXPORT", cleanup_error_type=type(error).__name__)
            row["actual_exit_observed_after_cleanup"] = child.poll()
        else:
            row["owned_cleanup_verified"] = not row["spawn_attempted"]
            row["child_scope"] = ("SPAWN_ATTEMPT_WITHOUT_HANDLE_UNVERIFIED" if row["spawn_attempted"]
                                  else "SPAWN_NOT_ATTEMPTED")
        row.update(finished_monotonic_ns=time.monotonic_ns(), finished_unix_ns=time.time_ns())
        write_new(directory / (stem + ".execution.json"), row)
    if failure is not None:
        raise failure
    return row


def execute(request_path, *, repository, output, output_budget, free_reserve, child_seconds, total_seconds):
    require(sys.platform == "darwin", "Actual original Apple exporter requires Darwin; source controls never execute it")
    require(type(output_budget) is int and 0 < output_budget <= 2 * 1024**3
            and type(free_reserve) is int and free_reserve >= 1
            and type(child_seconds) is int and 1 <= child_seconds <= 180
            and type(total_seconds) is int and child_seconds <= total_seconds <= 900,
            "Explicit finite output/free-space/child/session reservations required; these are not performance SLAs")
    before = plan(request_path, repository=repository)
    require(before["selected_tables"], "Inventory-only request cannot execute an export")
    out = Path(output)
    require(out.is_absolute() and not out.exists() and out.parent.resolve(strict=True) == out.parent
            and not out.is_relative_to(Path(before["trace_directory"])), "Fresh canonical separate export directory required")
    require(shutil.disk_usage(out.parent).free >= output_budget + free_reserve, "Export reservation does not fit")
    out.mkdir(mode=0o700)
    report = {"schema": SCHEMA, "status": "STARTED_NOT_QUALIFIED", "exports": [], "metrics": {},
              "performance_acceptance": False, "native_executed_by_exporter": 0,
              "missing_or_unqualified_metrics": MISSING, "output_budget_bytes": output_budget,
              "other_and_finalization_free_reserve_bytes": free_reserve}
    failure = None
    try:
        write_new(out / "PLAN.json", before)
        report["plan"] = file_record(out / "PLAN.json")[0]
        deadline = time.monotonic() + total_seconds
        core, _ = original_context(repository, before["producer"])
        def query(argv):
            require(time.monotonic() < deadline, "Whole export-command session deadline expired")
            return core.command(argv, timeout=min(15, max(1, deadline - time.monotonic())))
        version, xcode = query(["xcrun", "xctrace", "version"]), query(["xcodebuild", "-version"])
        tools_before = {"version": version.stdout + version.stderr, "xcode": xcode.stdout + xcode.stderr}
        original_tools = json_record(before["tool_inventory"])
        require(tools_before == {"version": original_tools["xctrace_version"], "xcode": original_tools["xcode"]},
                "Actual current Apple tool version differs from the recording's original inventory")
        tool_path = query(["xcrun", "--find", "xctrace"]).stdout.strip()
        tool_before = file_record(Path(tool_path).resolve(strict=True), 256 * 1024**2)[0]
        report.update(tool=tool_before, tool_versions=tools_before)
        interruption = runpy.run_path(str(Path(repository) / "Scripts/CI/runtime27_interruption.py"))
        for index, table in enumerate(before["selected_tables"], 1):
            stem = f"table-{index:02d}-{table['table_id'][:12]}"
            target = out / (stem + ".xml")
            command = ["xcrun", "xctrace", "export", "--input", before["trace_directory"],
                       "--xpath", table["xpath"], "--output", str(target)]
            execution = export_child(command, directory=out, stem=stem, timeout=child_seconds, hard_deadline=deadline,
                output_budget=output_budget, free_reserve=free_reserve, interruption=interruption)
            record, _ = file_record(target, output_budget)
            summary = inspect_raw_xml(target, output_budget)
            report["exports"].append({"observed_table": table, "raw": record, "actual_execution": execution,
                **summary,
                "dropped_event_coverage": "UNKNOWN_NO_QUALIFIED_COVERAGE_ADAPTER"})
        require(plan(request_path, repository=repository) == before, "Original source/receipt/trace/epoch inputs changed during export")
        require(file_record(tool_before["path"], 256 * 1024**2)[0] == tool_before, "Actual exporter binary changed")
        require(str(Path(query(["xcrun", "--find", "xctrace"]).stdout.strip()).resolve(strict=True)) == tool_before["path"],
                "Actual selected exporter location changed")
        report["status"] = "RAW_EXPORTS_RETAINED_METRICS_UNQUALIFIED"
    except BaseException as error:
        failure = error
        report.update(status="FAILED_OR_INCOMPLETE_EXPORTS", error_type=type(error).__name__, error=str(error))
    finally:
        report.update(finished_monotonic_ns=time.monotonic_ns(), finished_unix_ns=time.time_ns(),
                      retained_allocated_bytes=allocated(out), free_bytes_after=shutil.disk_usage(out).free)
        write_new(out / "RESULT.json", report)
    if failure is not None:
        raise failure
    return file_record(out / "RESULT.json")[0]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("plan", "export"))
    parser.add_argument("--request", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--output-budget-bytes", type=int)
    parser.add_argument("--free-reserve-bytes", type=int)
    parser.add_argument("--child-seconds", type=int)
    parser.add_argument("--total-seconds", type=int)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    if args.operation == "plan":
        print(json.dumps(plan(args.request, repository=root), ensure_ascii=False, sort_keys=True, allow_nan=False))
    else:
        require(args.output is not None, "Explicit fresh output required")
        print(json.dumps(execute(args.request, repository=root, output=args.output, output_budget=args.output_budget_bytes,
            free_reserve=args.free_reserve_bytes, child_seconds=args.child_seconds, total_seconds=args.total_seconds)))


if __name__ == "__main__":
    main()

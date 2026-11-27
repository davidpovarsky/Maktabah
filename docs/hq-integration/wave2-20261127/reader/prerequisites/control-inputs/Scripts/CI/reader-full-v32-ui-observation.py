#!/usr/bin/env python3
"""Original full-v32 UI observations. Source/metrics remain UNFINALIZED until reviewed.

Consumes an authentic same-source build; never weakens Native116/Release114,
provisions a replacement database, or interprets missing metrics as zero.
"""
import argparse
import contextlib
import ctypes
import datetime
import hashlib
import json
import math
import os
from pathlib import Path
import plistlib
import re
import runpy
import secrets
import shutil
import signal
import sqlite3
import stat
import subprocess
import sys
import threading
import time
import uuid
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
INPUTS = Path(__file__).with_suffix(".inputs.json")
HERE = ROOT / "docs/hq-integration/reader-full-v32-ui-observation-20261123"
OUT = ROOT / "build/artifacts/reader-full-v32-ui-observation"
BUNDLE = "com.davidpovarsky.chavrusatext"
# The v40 wrapper selects an independent profile before calling main().
# Without it, the original v32 install/identity/lifetime contract is unchanged.
CORPUS_NAME = "full-v32"
OBSERVATION_SCHEMA = "otzaria.full-v32.original-ui-observation/1"
CATALOG_SOURCE = HERE / "FullV32ObservationCatalog.swift"
REUSED_INSTALLATION = None
SELECTED = [
    "FaithfulProductionReleaseTests/testTwentyOriginalFullV32ReaderOpensAndForcedRelaunch",
    "FaithfulProductionReleaseTests/testOriginalFullV32InspectorRelationshipScalesAndReturn",
]

def require(value, message):
    if not value:
        raise ValueError(message)

def write(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".owned-tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n")
    temporary.replace(path)

def digest(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()

def witness(path):
    path = Path(path).resolve(strict=True)
    return {"path": str(path), "bytes": path.stat().st_size, "sha256": digest(path)}


def bounded_read(path, limit):
    """No symlink, regular file, capped allocation and exact read/path identity."""
    path = Path(path)
    descriptor = os.open(path, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW)
    try:
        before = os.fstat(descriptor)
        require(stat.S_ISREG(before.st_mode) and 0 < before.st_size <= limit, "Owned evidence is not a bounded regular file")
        with os.fdopen(os.dup(descriptor), "rb") as stream:
            data = stream.read(limit + 1)
        after, at_path = os.fstat(descriptor), path.lstat()
        identity = lambda item: (item.st_dev, item.st_ino, item.st_size, item.st_mtime_ns)
        require(stat.S_ISREG(at_path.st_mode) and identity(before) == identity(after) == identity(at_path)
                and len(data) == after.st_size <= limit, "Owned evidence grew, changed or was replaced while being read")
        return data
    finally:
        os.close(descriptor)

def bounded_json(path, limit):
    return json.loads(bounded_read(path, limit))

def rect(value):
    require(isinstance(value, dict) and set(value) == {"x", "y", "width", "height"}
            and all(type(v) in (int, float) and math.isfinite(v) for v in value.values())
            and value["width"] > 0 and value["height"] > 0, "Finite nonempty actual native rectangle required")
    return value

def contains(parent, child):
    a, b = rect(parent), rect(child)
    return (a["x"] <= b["x"] and a["y"] <= b["y"]
            and b["x"] + b["width"] <= a["x"] + a["width"]
            and b["y"] + b["height"] <= a["y"] + a["height"])


def command(args, timeout=90, check=True):
    result = subprocess.run(args, cwd=ROOT, text=True, capture_output=True, timeout=timeout)
    if check:
        require(result.returncode == 0, "Original command failed: " + str(args[0]))
    return result

def git(*args):
    return command(["git", *args]).stdout.strip()

def json_command(args, timeout=90):
    return json.loads(command(args, timeout=timeout).stdout)

def source_context(require_frozen):
    config = json.loads(INPUTS.read_text())
    require(config.get("schema") == OBSERVATION_SCHEMA, "Wrong observation schema")
    require(config["selected_case_ids"] == SELECTED, "The exact two original additive cases are required")
    head = git("rev-parse", "HEAD")
    source = config["application_source_sha"]
    trees = {p: git("rev-parse", "HEAD:" + p) for p in ("Source", "Vendor", "Maktabah.xcodeproj", "Maktabah-iOSUITests")}
    if require_frozen:
        require(re.fullmatch(r"[0-9a-f]{40}", source) is not None, "Application source is UNFINALIZED")
        require(head == os.environ.get("EXPECTED_CHECKOUT_SHA"), "Wrong immutable checkout")
        require(command(["git", "merge-base", "--is-ancestor", source, head], check=False).returncode == 0,
                "Frozen application source is not an ancestor")
        require(trees == config["application_trees"], "Actual compiled source/test trees differ from frozen inputs")
        require(all(git("rev-parse", source + ":" + p) == value for p, value in trees.items()), "Frozen tree drift")
    records = {}
    for path in config["execution_input_paths"]:
        local = ROOT / path
        require(local.is_file() and not local.is_symlink(), "Missing exact execution input: " + path)
        data = local.read_bytes()
        records[path] = {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}
        if require_frozen:
            expected = config["input_sha256"].get(path)
            require(expected is not None and records[path]["sha256"] == expected, "Execution byte pin changed: " + path)
            require(command(["git", "hash-object", str(local)]).stdout.strip() == git("rev-parse", "HEAD:" + path),
                    "Dirty committed execution input: " + path)
    return {"checkout_sha": head, "application_source_sha": source, "application_trees": trees,
            "inputs_file_sha256": digest(INPUTS), "execution_inputs": records,
            "scope": "Debug original production-corpus UI observation; no final Native116/Release114/device acceptance"}

def bounded(args, log, timeout, environment=None):
    interruption = runpy.run_path(str(ROOT / "Scripts/CI/runtime27_interruption.py"))
    with Path(log).open("w") as output:
        process = subprocess.Popen(args, cwd=ROOT, env=environment, stdout=output,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        try:
            return process.wait(timeout=timeout)
        except BaseException:
            cleanup = interruption["stop_owned_process_group"](process)
            write(Path(log).with_suffix(".process-cleanup.json"), cleanup)
            raise

def admit_installation(config, udid):
    report_path = ROOT / "build/artifacts/production-native-fixture-install.json"
    report = json.loads(report_path.read_text())
    source = config["source_database"]
    require(report.get("passed") is True and report.get("phase") == "install"
            and report.get("profileID") == "production" and report.get("quickCheck", "").lower() == "ok",
            "Original native production installer did not genuinely succeed")
    for key in ("releaseID", "releaseTag", "assetID", "assetName"):
        require(report.get(key) == source[key], "Actual native source identity differs: " + key)
    require(report.get("actualSHA256") == source["assetSHA256"], "Actual native compressed digest is not the qualified full-v32 asset")
    require(report.get("expectedSHA256") in (None, source["assetSHA256"]), "Native expected digest conflicts with the independent pin")
    # shaMatched alone is insufficient when the installer's expected SHA is absent.
    require(report.get("expectedCompressedBytes") == source["assetBytes"]
            and report.get("extractedBytes") == source["databaseBytes"]
            and report.get("bookCount") == 7876 and report.get("lineCount") == 7080797,
            "Actual full corpus bytes/counts differ")
    database = Path(report["finalPath"]).resolve(strict=True)
    require("/devices/" + udid.lower() + "/data/" in database.as_posix().lower(),
            "Database is not inside this exact newly created simulator")
    require(database.stat().st_size == source["databaseBytes"] and digest(database) == source["databaseSHA256"],
            "Actual installed full-v32 database bytes differ from the independent immutable digest")
    with contextlib.closing(sqlite3.connect(database.as_uri() + "?mode=ro&immutable=1", uri=True)) as sql:
        sql.execute("PRAGMA query_only=ON")
        counts = {table: sql.execute("SELECT COUNT(*) FROM " + table).fetchone()[0] for table in ("book", "line")}
        schema = sql.execute("SELECT type,name,tbl_name,sql FROM sqlite_master ORDER BY type,name").fetchall()
        require(counts == {"book": 7876, "line": 7080797}, "Independent immutable SQL counts changed")
        user_version = sql.execute("PRAGMA user_version").fetchone()[0]
        indexes = {table: sql.execute("PRAGMA index_list(" + table + ")").fetchall()
                   for table in ("book", "line", "link", "link_coverage", "link_suppressed_side")}
    result = {"native_report": witness(report_path), "database": witness(database),
              "native_report_expected_sha_present": report.get("expectedSHA256") is not None,
              "independent_compressed_digest_required": source["assetSHA256"], "counts": counts,
              "schema_sha256": hashlib.sha256(json.dumps(schema, ensure_ascii=False).encode()).hexdigest(),
              "sqlite_user_version": user_version, "sqlite_version": sqlite3.sqlite_version, "actual_indexes": indexes,
              "uri": database.as_uri() + "?mode=ro&immutable=1"}
    write(OUT / "actual-full-v32-installation.json", result)
    return database, result

def prepare_catalog(config, installation):
    catalog_dir = OUT / "source-catalog"
    catalog_dir.mkdir(parents=True, exist_ok=False)
    swiftc = command(["xcrun", "--sdk", "macosx", "--find", "swiftc"]).stdout.strip()
    sdk = command(["xcrun", "--sdk", "macosx", "--show-sdk-path"]).stdout.strip()
    zstd = (Path(command(["brew", "--prefix", "zstd"]).stdout.strip()) / "lib/libzstd.dylib").resolve(strict=True)
    binary = catalog_dir / "original-source-catalog"
    args = [swiftc, "-parse-as-library", "-swift-version", "6", "-Xfrontend", "-strict-concurrency=complete",
            "-O", "-sdk", sdk, "-L", str(zstd.parent), "-lzstd", "-Xlinker", "-rpath", "-Xlinker", str(zstd.parent),
            *[str(ROOT / p) for p in config["catalog_compiled_sources"]],
            str(CATALOG_SOURCE), "-o", str(binary)]
    write(catalog_dir / "compile-inputs.json", {"command": args, "swiftc": witness(swiftc), "zstd": witness(zstd),
          "source_sha256": {p: digest(ROOT / p) for p in config["catalog_compiled_sources"]}})
    require(bounded(args, catalog_dir / "compile.log", 300) == 0, "Original source-catalog Apple compilation failed")
    catalog_input = {"databaseURI": installation["uri"],
                     "databaseSHA256": installation["database"]["sha256"]}
    if CORPUS_NAME == "full-v40":
        catalog_input["v40Targets"] = config["catalog_targets"]
    write(catalog_dir / "input.json", catalog_input)
    require(bounded([str(binary), str(catalog_dir / "input.json"), str(catalog_dir)],
                    catalog_dir / "execution.log", 600) == 0, "Original source-catalog execution failed")
    catalog = json.loads((catalog_dir / "catalog.json").read_text())
    require(catalog["status"] == "ORIGINAL_SOURCE_CATALOG_ONLY_NOT_UI" and len(catalog["targets"]) == 10,
            "Original catalog is not complete")
    for item in catalog["targets"]:
        source = catalog_dir / item["sourceFile"]
        require(source.parent == catalog_dir and source.stat().st_size == item["sourceUTF8Bytes"]
                and digest(source) == item["sourceSHA256"], "Original complete unit source changed")
    write(catalog_dir / "native-executable.json", {"binary": witness(binary),
          "linkage": command(["otool", "-L", str(binary)]).stdout})
    return catalog_dir, catalog

def exact_source_comparison(catalog_dir, target, viewport):
    """No normalization, AX body transfer or digest-only replacement of actual bytes."""
    require(isinstance(viewport, dict) and re.fullmatch(r"[0-9A-F-]{36}", viewport.get("requestID", "")),
            "Missing fresh viewport request UUID")
    sample = viewport.get("fullV32SourceObservation", {})
    require(sample.get("schema") == 1 and sample.get("status") == "AVAILABLE", "Source sample is unavailable")
    location, length = sample.get("rangeLocation"), sample.get("rangeLength")
    require(type(location) is int and type(length) is int and location >= 0 and 0 < length <= 256,
            "Source range is not bounded UTF16")
    snippet = sample.get("sourceUTF8")
    require(isinstance(snippet, str) and 0 < len(snippet.encode("utf-8")) <= 1024
            and len(json.dumps(sample, ensure_ascii=False).encode()) <= 4096, "Native sample exceeds byte bounds")
    source = Path(catalog_dir) / target["sourceFile"]
    require(source.parent == Path(catalog_dir) and digest(source) == target["sourceSHA256"],
            "Independent original full source file changed")
    original = source.read_bytes().decode("utf-8", errors="strict")
    utf16 = original.encode("utf-16-le")
    require(len(utf16) // 2 == target["sourceUTF16Length"] == sample.get("sourceUTF16Length"),
            "Native original source length differs from the exact original unit")
    require(location <= len(utf16) // 2 and length <= len(utf16) // 2 - location,
            "Native probe range escapes the full source")
    expected = utf16[location * 2:(location + length) * 2].decode("utf-16-le", errors="strict")
    require(expected.encode("utf-8") == snippet.encode("utf-8"),
            "Actual bounded native source UTF8 differs from the independent original full unit")
    source_index = viewport.get("source")
    require(type(source_index) is int and location <= source_index < location + length,
            "Composed source sample does not contain the actual observed source index")
    require(type(sample.get("processID")) is int and sample["processID"] > 0
            and isinstance(sample.get("observedUptime"), (int, float))
            and math.isfinite(sample["observedUptime"]), "Native process/time identity unavailable")
    return {"status": "EXACT_UTF16_RANGE_AND_UTF8_SOURCE_MATCH",
            "source_sha256": target["sourceSHA256"], "range_location": location, "range_length": length,
            "snippet_sha256": hashlib.sha256(snippet.encode("utf-8")).hexdigest(),
            "native_process_id": sample["processID"], "scope": "bounded post-timing source proof; native Core/glyph evidence remains independently required"}

def cpu_seconds(value):
    require(re.fullmatch(r"(?:(?:[0-9]+)-)?[0-9]+(?::[0-9]{2}){1,2}(?:\.[0-9]+)?", value),
            "Actual Darwin ps CPU field has an unknown format")
    days, clock = (value.split("-", 1) if "-" in value else ("0", value))
    # Parse independently of the day prefix; reported ps precision is retained.
    parts = clock.split(":")
    return int(days) * 86400 + sum(float(v) * 60 ** (len(parts) - i - 1) for i, v in enumerate(parts))

def percentiles(values):
    require(values and all(isinstance(v, (int, float)) and math.isfinite(v) and v >= 0 for v in values),
            "Finite actual observations are required")
    ordered = sorted(values)
    return {"n": len(ordered), "method": "empirical nearest-rank ceil(p*n), no discarded failures",
            "p50": ordered[math.ceil(0.50 * len(ordered)) - 1],
            "p95": ordered[math.ceil(0.95 * len(ordered)) - 1],
            "individual": values}


class AppleTraceCapture:
    """One owned-device trace, with Apple's actual tracing-started notification.

    The trace is continuous across app relaunches; metric epochs identify the
    actual app PIDs and time windows. Post-epoch source/cache work remains in the
    raw trace but is explicitly excluded from those windows.
    """
    def __init__(self, udid, inventory):
        self.udid, self.inventory = udid, inventory
        self.process = self.output = None
        self.record = {"status": "NOT_STARTED", "scope": "owned Simulator all-process Time Profiler; exact app PID/epoch filtering required"}
        self.path = OUT / ("traces/original-" + CORPUS_NAME + ".trace")

    def start(self):
        help_text = self.inventory.get("record_help", "")
        needed = ("--template", "--all-processes", "--device", "--output", "--time-limit", "--notify-tracing-started")
        require("Time Profiler" in self.inventory.get("templates", "") and all(x in help_text for x in needed),
                "Actual Apple template/help lacks the required original-device capture capabilities")
        library = ctypes.CDLL("/usr/lib/libSystem.B.dylib")
        for name, args in (
            ("notify_register_check", [ctypes.c_char_p, ctypes.POINTER(ctypes.c_int32)]),
            ("notify_check", [ctypes.c_int32, ctypes.POINTER(ctypes.c_int)]),
            ("notify_cancel", [ctypes.c_int32]),
        ):
            function = getattr(library, name)
            function.argtypes, function.restype = args, ctypes.c_uint32
        name = ("com.davidpovarsky.chavrusatext.full-v32-trace-" + uuid.uuid4().hex).encode("ascii")
        token, changed = ctypes.c_int32(), ctypes.c_int()
        require(library.notify_register_check(name, ctypes.byref(token)) == 0, "Apple trace-ready observer registration failed")
        try:
            # Drain the initial registration state before the recorder starts.
            require(library.notify_check(token, ctypes.byref(changed)) == 0, "Apple trace-ready initial check failed")
            self.path.parent.mkdir(parents=True, exist_ok=True)
            require(not self.path.exists(), "Never overwrite a retained Apple trace")
            self.output = self.path.with_suffix(".record.log").open("w")
            args = ["xcrun", "xctrace", "record", "--template", "Time Profiler", "--all-processes",
                    "--device", self.udid, "--output", str(self.path), "--time-limit", "2400s",
                    "--notify-tracing-started", name.decode("ascii")]
            if "--no-prompt" in help_text:
                args.append("--no-prompt")
            self.process = subprocess.Popen(args, cwd=ROOT, stdout=self.output,
                stderr=subprocess.STDOUT, start_new_session=True)
            self.record.update(status="STARTED_NOT_READY", command=args, recorder_pid=self.process.pid,
                started_host_monotonic=time.monotonic(), started_host_wall_ns=time.time_ns())
            deadline = time.monotonic() + 45
            while time.monotonic() < deadline:
                require(self.process.poll() is None, "Original Apple trace recorder exited before its ready event")
                require(library.notify_check(token, ctypes.byref(changed)) == 0, "Apple trace-ready check failed")
                if changed.value:
                    self.record.update(status="READY_ACTUAL_APPLE_NOTIFICATION", ready_host_monotonic=time.monotonic(),
                        ready_host_wall_ns=time.time_ns(), ready_signal="xctrace --notify-tracing-started / Darwin notify")
                    write(OUT / "traces/capture-start.json", self.record)
                    return
                time.sleep(0.05)
            raise ValueError("Original Apple trace never emitted its ready notification")
        finally:
            require(library.notify_cancel(token) == 0, "Apple trace-ready observer cleanup failed")

    def require_running(self):
        require(self.process is not None and self.process.poll() is None
                and self.record["status"] == "READY_ACTUAL_APPLE_NOTIFICATION",
                "No live source-bound Apple trace is covering this resource epoch")

    def stop(self):
        if self.process is not None:
            interruption = runpy.run_path(str(ROOT / "Scripts/CI/runtime27_interruption.py"))
            self.record["owned_process_group_cleanup"] = interruption["stop_owned_process_group"](self.process, grace_seconds=20, kill_wait_seconds=5)
            self.process = None
        if self.output is not None:
            self.output.close()
            self.output = None
        self.record["stopped_host_monotonic"] = time.monotonic()
        self.record["stopped_host_wall_ns"] = time.time_ns()
        if self.path.is_dir():
            toc = self.path.with_suffix(".toc.xml")
            exported = command(["xcrun", "xctrace", "export", "--input", str(self.path), "--toc",
                                "--output", str(toc)], timeout=180, check=False)
            self.record["toc_export_exit"] = exported.returncode
            if exported.returncode == 0 and toc.is_file():
                root = ET.parse(toc).getroot()
                self.record.update(status="ACTUAL_TRACE_RETAINED_COVERAGE_AND_SCHEMA_REVIEW_REQUIRED",
                    toc=witness(toc), actual_table_schemas=sorted(
                        {x.attrib["schema"] for x in root.iter("table") if "schema" in x.attrib}))
            else:
                self.record.update(status="TRACE_EXPORT_UNAVAILABLE_NOT_QUALIFIED")
            self.record["files"] = [witness(p) for p in sorted(self.path.rglob("*")) if p.is_file() and not p.is_symlink()]
        else:
            self.record.update(status="TRACE_ABSENT_NOT_QUALIFIED")
        self.record["metric_boundary"] = "Only exact recorded app PID/resource epochs are eligible; source/cache/request/export intervals are excluded"
        write(OUT / "traces/capture-result.json", self.record)
        return self.record


def independent_inspector_samples(installation, target, samples, visible):
    """Immutable SQL witnesses for retained source identities; not a full-cache oracle."""
    results = []
    with contextlib.closing(sqlite3.connect(installation["uri"], uri=True)) as sql:
        sql.execute("PRAGMA query_only=ON")
        tables = {r[0] for r in sql.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        require({"book", "line", "link", "connection_type", "link_coverage", "link_suppressed_side"}.issubset(tables),
                "Qualified full-v32 relationship schema is missing")
        dependent = "'COMMENTARY','SUPER_COMMENTARY','TARGUM','MIDRASH','PARSHANUT','DIBUR_HAMATCHIL','ELUCIDATION','EXPLICATION','FOOTNOTES'"
        reference = "'REFERENCE','QUOTATION','MESORAT_HASHAS','EIN_MISHPAT','MISHNAH_IN_TALMUD','RELATED','OTHER','SIFREI_MITZVOT','ESSAY','ALLUSION','LITURGY','LAW','SUMMARY'"
        for sample in samples:
            match = re.fullmatch(r"otzaria:v1:([1-9][0-9]*):([0-9]+)", sample["sourceRef"])
            require(match is not None, "Original linked source reference format changed")
            book_id, index = map(int, match.groups())
            require(sample["canonicalBookID"] == "otzaria:book:" + str(book_id)
                    and sample["rawProviderPayload"] == "otzaria|book:" + str(book_id) + "|line:" + str(index),
                    "Actual original linked-source payload does not map to its canonical identity")
            require(sample["id"] == "|".join([sample["canonicalBookID"], sample["sourceRef"], sample["type"],
                                             sample["category"], "", ",".join(sample["anchorRefs"])]),
                    "Actual original adapter identity fields changed")
            lines = sql.execute("SELECT line.id,line.heRef,book.title FROM line JOIN book ON book.id=line.bookId WHERE line.bookId=? AND line.lineIndex=?",
                                (book_id, index)).fetchall()
            require(len(lines) == 1, "Original visible source line must exist uniquely in actual full-v32")
            line_id, he_ref, book_title = lines[0]
            require(sample["anchorRefs"] == ([he_ref] if he_ref is not None else [])
                    and sample["sourceHebrewRef"] in (None, he_ref),
                    "Original source reference/anchor metadata differs from immutable SQL")
            # This is the exact forward/inverse/range/suppression membership
            # domain from original OtzariaLineSourcesService, narrowed to one
            # independently identified linked line. No relationship counts are
            # fabricated from this sample query and no production cache is touched.
            query = f"""
                WITH win(id) AS (
                    SELECT id FROM line WHERE bookId=? AND lineIndex BETWEEN ? AND ?
                ), candidates AS (
                    SELECT link.* FROM link WHERE
                        (sourceBookId=? AND targetBookId=? AND targetLineId=?)
                        OR (targetBookId=? AND sourceBookId=? AND sourceLineId=?)
                ), matched(linkId,matchedSide,anchorLineId) AS (
                    SELECT id,0,sourceLineId FROM candidates WHERE sourceBookId=? AND sourceLineId IN (SELECT id FROM win)
                    UNION SELECT link.id,0,coverage.lineId FROM candidates link JOIN link_coverage coverage ON coverage.linkId=link.id
                        WHERE coverage.side=0 AND link.sourceBookId=? AND coverage.lineId IN (SELECT id FROM win)
                    UNION SELECT id,1,targetLineId FROM candidates WHERE targetBookId=? AND targetLineId IN (SELECT id FROM win)
                    UNION SELECT link.id,1,coverage.lineId FROM candidates link JOIN link_coverage coverage ON coverage.linkId=link.id
                        WHERE coverage.side=1 AND link.targetBookId=? AND coverage.lineId IN (SELECT id FROM win)
                )
                SELECT DISTINCT link.id,matched.matchedSide,COALESCE(connection_type.name,'OTHER')
                FROM matched JOIN candidates link ON link.id=matched.linkId
                LEFT JOIN connection_type ON connection_type.id=link.connectionTypeId
                WHERE (
                    matched.matchedSide=0
                    AND NOT EXISTS(SELECT 1 FROM link_suppressed_side hidden WHERE hidden.linkId=link.id AND hidden.side=0)
                ) OR (
                    matched.matchedSide=1 AND connection_type.name IN ({dependent},{reference})
                    AND NOT EXISTS(SELECT 1 FROM link_suppressed_side hidden WHERE hidden.linkId=link.id AND hidden.side=1)
                    AND (link.sourceBookId!=link.targetBookId OR (
                        connection_type.name IN ({reference}) AND (
                            EXISTS(SELECT 1 FROM link_suppressed_side source_hidden WHERE source_hidden.linkId=link.id AND source_hidden.side=0)
                            OR (matched.anchorLineId!=link.sourceLineId
                                AND NOT EXISTS(SELECT 1 FROM link_coverage source_coverage
                                    WHERE source_coverage.linkId=link.id AND source_coverage.side=0 AND source_coverage.lineId=matched.anchorLineId))
                        )
                    ))
                )
                ORDER BY link.id,matched.matchedSide
                LIMIT 129
            """
            book = target["bookID"]
            edges = sql.execute(query, (book, target["unitStartLineIndex"], target["unitEndLineIndex"],
                book, book_id, line_id, book, book_id, line_id, book, book, book, book)).fetchall()
            require(0 < len(edges) <= 128, "Bounded original relationship membership witness is absent or exceeds cap")
            actual_row = visible.get(sample["id"])
            if actual_row:
                display_hebrew = sample["sourceHebrewRef"]
                reference_label = display_hebrew if display_hebrew and display_hebrew.strip() else "שורה " + str(index)
                require(actual_row["label"].startswith(reference_label + ", "),
                        "Actual original native row label does not map to the source reference")
            results.append({"ordinal": sample["ordinal"], "source_id": sample["id"], "book_id": book_id,
                "line_index": index, "line_id": line_id, "book_title": book_title, "he_ref": he_ref,
                "actual_original_edges": edges, "visible_native_row": actual_row is not None,
                "scope": "exact retained source/label/range-edge identity only; not full row body or full-cache equality"})
    return results



class ObservationHost(threading.Thread):
    """One bounded observer; resource fencing never changes original app state."""
    def __init__(self, udid, container, catalog_dir, catalog, installation, trace):
        super().__init__(daemon=True)
        self.udid, self.containers = udid, Path(container).parent
        self.catalog_dir, self.catalog = Path(catalog_dir), catalog
        self.targets = {x["key"]: x for x in catalog["targets"]}
        self.installation, self.trace = installation, trace
        self.token, self.stop_event = secrets.token_hex(16), threading.Event()
        self.seen, self.epochs, self.source_proofs = set(), {}, []
        self.pending_inspector, self.inspector_records = None, {}
        self.source_request_ids = set()
        self.active, self.error = None, None
        self.deadline = time.monotonic() + 2400
        self.reader_complete = self.inspector_complete = None

    def environment(self):
        return {"TEST_RUNNER_FULL_V32_OBSERVER_TOKEN": self.token,
                "TEST_RUNNER_FULL_V32_CATALOG_FILE": str(self.catalog_dir / "catalog.json")}

    def process(self):
        bundle = Path(command(["xcrun", "simctl", "get_app_container", self.udid, BUNDLE, "app"], timeout=45).stdout.strip()).resolve(strict=True)
        info = plistlib.loads((bundle / "Info.plist").read_bytes())
        executable = bundle / info["CFBundleExecutable"]
        rows = command(["/bin/ps", "-ww", "-axo", "pid=,comm="], timeout=15).stdout.splitlines()
        matches = []
        for row in rows:
            fields = row.strip().split(None, 1)
            if len(fields) == 2 and fields[0].isdigit() and fields[1] == str(executable):
                matches.append(int(fields[0]))
        require(len(matches) == 1, "The exact installed original app executable must have one actual host PID")
        return matches[0], str(executable)

    def sample(self, pid, executable):
        began = time.monotonic()
        row = command(["/bin/ps", "-ww", "-p", str(pid), "-o", "pid=,rss=,time=,comm="], timeout=10).stdout.strip()
        fields = row.split(None, 3)
        require(len(fields) == 4 and fields[0] == str(pid) and fields[1].isdigit() and fields[3] == executable,
                "Actual original app PID/path changed during measurement")
        return {"host_query_started_monotonic": began, "host_monotonic": time.monotonic(),
                "host_wall_ns": time.time_ns(), "processID": pid, "rss_kib": int(fields[1]),
                "cpu_time_reported": fields[2], "cpu_seconds": cpu_seconds(fields[2])}

    def begin(self, request):
        require(self.active is None and self.pending_inspector is None,
                "Another resource or post-resource observation epoch is active")
        epoch, kind = request["epoch"], request["kind"]
        require(str(uuid.UUID(epoch)).upper() == epoch and epoch not in self.epochs, "Epoch must be fresh")
        require(request["targetKey"] in self.targets and kind in ("reader-open", "reader-overview", "inspector-open", "inspector-scroll"),
                "Unknown original Reader/Inspector epoch")
        if kind in ("reader-open", "reader-overview"):
            require(request["mode"] in ("process-cold", "warm")
                    and sum(x["kind"] == kind for x in self.epochs.values()) < 20,
                    "Each original twenty-open or twenty-overview cohort must retain its exact schedule")
        else:
            require(request["mode"] == "original-native" and sum(not x["kind"].startswith("reader-") for x in self.epochs.values()) < 30,
                    "Bounded original Inspector observation schedule exceeded")
        self.trace.require_running()
        pid, executable = self.process()
        first = self.sample(pid, executable)
        self.active = {"epoch": epoch, "kind": kind, "target_key": request["targetKey"], "mode": request["mode"],
            "processID": pid, "executable": executable, "samples": [first], "status": "ACTIVE_NOT_ACCEPTED",
            "resource_start_host_monotonic": first["host_monotonic"],
            "resource_start_host_wall_ns": first["host_wall_ns"],
            "trace_scope": "continuous actual Apple trace; filter this exact PID and resource interval"}
        self.epochs[epoch] = self.active
        return {"processID": pid, "epoch": epoch, "kind": kind}

    def end(self, request):
        require(self.active is not None and self.active["epoch"] == request["epoch"], "Wrong resource epoch end")
        self.trace.require_running()
        value = self.active
        value["samples"].append(self.sample(value["processID"], value["executable"]))
        # No trace export, source copying, cache hash or JSON membership work
        # occurs before this resource end and the ACK returned to the XCTest.
        value["resource_end_host_monotonic"] = time.monotonic()
        value["resource_end_host_wall_ns"] = time.time_ns()
        self.active = None
        first, last = value["samples"][0], value["samples"][-1]
        require(last["cpu_seconds"] >= first["cpu_seconds"], "Actual app cumulative CPU regressed")
        value.update(status="OBSERVED_NOT_PERFORMANCE_ACCEPTANCE",
            app_cpu_seconds=last["cpu_seconds"] - first["cpu_seconds"],
            sampled_max_rss_bytes=max(s["rss_kib"] for s in value["samples"]) * 1024,
            memory_scope="sampled Darwin host RSS of exact Simulator app PID; not phys_footprint or continuous peak",
            cpu_scope="difference of actual Darwin ps cumulative CPU fields; reported precision retained",
            sample_cadence_seconds=0.25)
        write(OUT / "resource-epochs" / (value["epoch"] + ".json"), value)
        return {k: value[k] for k in ("epoch", "kind", "processID", "app_cpu_seconds",
                                      "sampled_max_rss_bytes", "memory_scope", "cpu_scope")}

    def workspace(self, request, container, target, scene_id=None):
        path = container / "Library/Application Support/ChavrusaText/StudyWorkspace/workspace-v1.json"
        data = bounded_read(path, 4 * 1024 * 1024)
        workspace = json.loads(data)
        group_id, document_id = request["workspaceGroupID"], request["workspaceDocumentID"]
        require(str(uuid.UUID(group_id)).upper() == group_id and str(uuid.UUID(document_id)).upper() == document_id,
                "Observed original group/document UUIDs are required")
        groups = [g for g in workspace["groups"] if g["id"].upper() == group_id]
        require(len(groups) == 1, "Actual ordinary original group is missing or duplicated")
        group = groups[0]
        documents = [t for t in group["tabs"] if t["session"]["id"].upper() == document_id]
        require(len(documents) == 1 and documents[0]["backend"] == "otzaria"
                and documents[0]["session"]["bookId"] == target["bookID"],
                "Actual original document does not match the observed production book")
        scene_id = scene_id or workspace.get("lastActiveSceneID")
        scene = workspace["scenes"].get(scene_id)
        require(scene is not None and scene["groupID"].upper() == group_id
                and scene["profileID"] == group["profileID"], "Actual native scene selection does not own this group")
        active = scene.get("activeTabIDsByGroup") or {}
        # Codable UUID-key dictionaries are represented as alternating entries.
        if isinstance(active, list):
            require(len(active) % 2 == 0, "Malformed original UUID-key selection dictionary")
            pairs = list(zip(active[::2], active[1::2]))
            require(len({p[0] for p in pairs}) == len(pairs), "Duplicate original active group key")
            active = dict(pairs)
        require(isinstance(active, dict), "Unexpected original selection dictionary")
        requested = next((v for k, v in active.items() if k.upper() == group_id), group.get("activeTabID"))
        expected = requested if any(t["session"]["id"] == requested for t in group["tabs"]) else group["tabs"][0]["session"]["id"]
        require(expected.upper() == document_id, "Observed document is not the active original workspace projection")
        return {"workspace_path": str(path), "sha256": hashlib.sha256(data).hexdigest(),
                "scene_id": scene_id, "document_id": document_id, "group_id": group_id, "revision": workspace["revision"]}

    def route(self, route, container, target):
        fields, line = route["receiptFields"], route["nativeReceipt"]
        parsed = dict(part.split("=", 1) for part in line.split(" ", 2)[2].split())
        require(parsed == fields and set(fields) == {"request", "scene", "backend", "generation", "epoch", "revision", "destination", "presentation"},
                "Actual Core receipt fields changed or were substituted")
        require(str(uuid.UUID(fields["request"])).upper() == fields["request"].upper()
                and fields["backend"] == "otzaria" and fields["destination"] == "native.reader"
                and fields["presentation"] == "currentTab" and fields["epoch"] == "none"
                and fields["generation"].isdigit(), "Original Core route identity is not eligible")
        revisions = fields["revision"].split("->")
        require(len(revisions) == 2 and all(x.isdigit() for x in revisions)
                and int(revisions[1]) > int(revisions[0]), "Actual Core revision did not advance")
        lines = bounded_read(container / "Documents/OtzariaLogs/otzaria-reader.log", 33554432).decode("utf-8").splitlines()
        require(lines.count(line) == 1 and sum("request=" + fields["request"] + " " in x
                and "[NativeNavigationReceipt]" in x for x in lines) == 1,
                "Exact original Core/glyph-visible receipt is not unique in the actual app log")
        require(route["sectionLocator"] == target["sectionLocator"]
                and route.get("focusLocator") == (None if route.get("sectionOnly") is True else target["focusLocator"]),
                "Canonical actual section/focus binding changed")
        start, end = route["requestWrittenUptime"], route["nativeReceiptObservedUptime"]
        require(all(type(v) in (int, float) and math.isfinite(v) for v in (start, end))
                and end >= start and route["requestToNativeVisibleUpperBoundSeconds"] == end - start,
                "Actual monotonic visibility interval is malformed")
        return fields

    def validate_source(self, request, container):
        require(self.active is None and self.pending_inspector is None, "Source probes cannot overlap a resource/cache epoch")
        target = self.targets[request["targetKey"]]
        basename = request["viewportBasename"]
        require(re.fullmatch(r"full-v32-reader-[0-9A-F-]{36}", basename) is not None, "Owned viewport basename required")
        uuid.UUID(basename.removeprefix("full-v32-reader-"))
        report_path = container / "Documents" / (basename + ".viewport.json")
        request_path = container / "Documents" / (basename + ".request")
        viewport = bounded_json(report_path, 32768)
        require(viewport == request["viewport"] and bounded_read(request_path, 36).decode() == viewport["requestID"],
                "Independently read actual viewport/request differs from the XCTest witness")
        require(viewport["requestID"] not in self.source_request_ids, "Native source request UUID was reused")
        proof = exact_source_comparison(self.catalog_dir, target, viewport)
        pid, _ = self.process()
        require(proof["native_process_id"] == pid, "Native sample belongs to a stale/different PID")
        sample = viewport["fullV32SourceObservation"]
        requested, observed = request["sourceProbeRequestedUptime"], request["sourceProbeObservedUptime"]
        require(all(type(v) in (int, float) and math.isfinite(v) for v in (requested, observed))
                and requested <= sample["observedUptime"] <= observed,
                "Actual post-request observation timestamp is outside the XCTest observation interval")
        route = request.get("routeEvidence")
        fields = self.route(route, container, target) if route is not None else None
        workspace = self.workspace(request, container, target, fields["scene"] if fields else None)
        epoch_id = request.get("epoch")
        if epoch_id:
            epoch = self.epochs.get(epoch_id, {})
            require(epoch.get("status") == "OBSERVED_NOT_PERFORMANCE_ACCEPTANCE" and epoch.get("processID") == pid
                    and epoch["target_key"] == target["key"], "No completed matching resource epoch exists")
            end_ack = request["resourceEndAcknowledgedUptime"]
            require(type(end_ack) in (int, float) and math.isfinite(end_ack) and requested >= end_ack
                    and request_path.stat().st_mtime_ns >= epoch["resource_end_host_wall_ns"],
                    "Source request/report work started before resource accounting ended")
        proof.update(target_key=target["key"], epoch=epoch_id, request_id=viewport["requestID"],
            actual_workspace_document_id=workspace["document_id"], actual_workspace_group_id=workspace["group_id"],
            ordinary_workspace_sha256=workspace["sha256"], scene_id=workspace["scene_id"],
            native_core_receipt_present=route is not None, post_resource_epoch=True,
            native_core_request_id=fields["request"] if fields else None,
            route_visibility_upper_bound_seconds=route["requestToNativeVisibleUpperBoundSeconds"] if route else None,
            source_index=viewport["source"], pixel_offset=viewport["offset"], native_object=viewport["object"],
            native_report=witness(report_path), native_sample_observed_uptime=sample["observedUptime"],
            native_probe_requested_uptime=requested, native_probe_observed_uptime=observed)
        self.source_proofs.append(proof)
        self.source_request_ids.add(viewport["requestID"])
        write(OUT / "source-proofs" / (viewport["requestID"] + ".json"), proof)
        # Prevent a new coordinator on cold relaunch from consuming an old
        # opt-in request during a later resource epoch.
        require(bounded_read(request_path, 36).decode() == viewport["requestID"], "Source request changed before retirement")
        request_path.unlink()
        return proof

    def arm_inspector(self, request, container):
        require(self.active is None and self.pending_inspector is None, "Inspector observation requires an idle resource fence")
        target = self.targets[request["targetKey"]]
        epoch = self.epochs.get(request["epoch"], {})
        require(epoch.get("status") == "OBSERVED_NOT_PERFORMANCE_ACCEPTANCE"
                and epoch.get("kind") in ("inspector-open", "inspector-scroll")
                and epoch["target_key"] == target["key"], "Passive Inspector evidence has no matching completed epoch")
        pid, _ = self.process()
        require(pid == epoch["processID"], "Inspector observation crossed an actual process boundary")
        fields = self.route(request["routeEvidence"], container, target)
        require(request["routeEvidence"].get("sectionOnly") is True, "Original whole-section Inspector requires no focused segment")
        workspace = self.workspace(request, container, target, fields["scene"])
        rows = request["visibleRows"]
        require(0 <= len(rows) <= 3 and len({r["id"] for r in rows}) == len(rows),
                "At most three unique actual visible original source rows are eligible")
        empty = request.get("emptyState")
        if not rows:
            require(isinstance(empty, dict) and empty.get("label") in ("No results", "אין תוצאות")
                    and contains(empty["panelFrame"], empty["frame"]) and contains(empty["windowFrame"], empty["frame"]),
                    "No-row exploration requires a genuine original native empty-state witness")
        else:
            require(empty is None, "A source-row observation cannot simultaneously claim an empty original tool")
        for row in rows:
            require(row["identifier"] == "torah-inspector-source-" + row["id"]
                    and row["elementType"] == "button" and row["hittable"] is True
                    and 0 < len(row["id"].encode()) <= 4096
                    and 0 < len(row["label"].encode()) <= 8192
                    and contains(row["panelFrame"], row["frame"]) and contains(row["windowFrame"], row["frame"]),
                    "Original row identity, label or actual visible native geometry is invalid")
        require(request["selectedTool"] in ("commentaries", "links") and request["actualPanelIdentifier"] == "torah-inspector-panel",
                "The genuine original Inspector panel/tool witness is missing")
        basename = request["inspectorBasename"]
        require(re.fullmatch(r"full-v32-inspector-[0-9A-F-]{36}", basename) is not None, "Owned Inspector basename required")
        uuid.UUID(basename.removeprefix("full-v32-inspector-"))
        request_id = str(uuid.uuid4()).upper()
        relationship = "otzaria:unit:v1:{}:{}:{}:{}".format(
            target["bookID"], target["unitID"].replace(":", "_"), target["unitStartLineIndex"], target["unitEndLineIndex"])
        native = {"schema": 1, "requestID": request_id, "processID": pid, "sourceLocator": target["sectionLocator"],
                  "relationshipRef": relationship, "backendGeneration": fields["generation"],
                  "afterResourceEpoch": True, "visibleSourceIDs": [r["id"] for r in rows]}
        data = json.dumps(native, ensure_ascii=False, sort_keys=True).encode()
        require(len(data) <= 16384, "Inspector request exceeds the source observer's allocation cap")
        request_path = container / "Documents" / (basename + ".request.json")
        # Only this unique owned request path is written, after the resource end.
        write(request_path, native)
        actual = bounded_json(request_path, 16384)
        require(actual == native and request_path.stat().st_mtime_ns >= epoch["resource_end_host_wall_ns"],
                "Native request creation did not follow the completed resource epoch")
        self.pending_inspector = {"request_id": request_id, "request": native, "request_path": str(request_path),
            "response_path": str(container / "Documents" / (basename + ".observation.json")),
            "target_key": target["key"], "epoch": request["epoch"], "workspace": workspace, "visible_rows": rows,
            "selected_tool": request["selectedTool"], "empty_state": empty, "arm_host_monotonic": time.monotonic(),
            "arm_host_wall_ns": time.time_ns(), "container": str(container)}
        write(OUT / "inspector-proofs" / (request_id + ".armed.json"), self.pending_inspector)
        return {"requestID": request_id, "notificationName": BUNDLE + "." + basename, "processID": pid,
                "requestFile": request_path.name, "responseFile": basename + ".observation.json",
                "epoch": request["epoch"], "armedAfterResourceEpoch": True}

    def validate_inspector(self, request, container):
        pending = self.pending_inspector
        require(self.active is None and pending is not None and pending["request_id"] == request["requestID"]
                and pending["container"] == str(container), "No exact pending Inspector observation fence exists")
        try:
            native = bounded_json(pending["request_path"], 16384)
            report_path = Path(pending["response_path"])
            report = bounded_json(report_path, 65536)
            pid, _ = self.process()
            require(native == pending["request"] and report == request["nativeReport"]
                    and report["schema"] == 1 and report["requestID"] == pending["request_id"]
                    and report["processID"] == pid == native["processID"] and report["status"] == "AVAILABLE"
                    and report.get("currentnessRechecked") is True and report.get("isPeek") is False,
                    "Actual original passive response is unavailable, stale or substituted")
            for key in ("sourceLocator", "relationshipRef", "backendGeneration"):
                require(report[key] == native[key], "Actual original current context mismatch: " + key)
            require(report["selectionID"] == "otzaria:section:" + native["relationshipRef"] + ":"
                    and report["selectedTool"] == pending["selected_tool"]
                    and all(isinstance(report[k], str) and 0 < len(report[k].encode()) <= 256
                            for k in ("readerIdentity", "sessionIdentity", "ownerID", "contentID")),
                    "Mounted original selection/session/tool identity is incomplete")
            for key in ("ownerID", "contentID"):
                uuid.UUID(report[key])
            notification_time, observed_time = request["notificationPostedUptime"], request["responseObservedUptime"]
            require(all(type(v) in (int, float) and math.isfinite(v)
                        for v in (notification_time, observed_time, report["observedUptime"]))
                    and notification_time <= report["observedUptime"] <= observed_time,
                    "Inspector report was not produced after this explicit native notification")
            count = report["fullCachedCount"]
            require(type(count) is int and 0 <= count <= 100000
                    and re.fullmatch(r"[0-9a-f]{64}", report["orderedIdentitySHA256"]) is not None
                    and type(report["hashedBytes"]) is int and 0 < report["hashedBytes"] <= 32 * 1024 * 1024
                    and report["requestedVisibleIdentitiesMatched"] == len(pending["visible_rows"]),
                    "Whole original cache count/digest or visible-row matching is incomplete")
            samples = report["identitySamples"]
            require((len(samples) == 0 if count == 0 else 1 <= len(samples) <= 15)
                    and all(type(x["ordinal"]) is int and 0 <= x["ordinal"] < count for x in samples),
                    "Bounded original membership samples are malformed")
            visible = {row["id"]: row for row in pending["visible_rows"]}
            require(set(visible).issubset({x["id"] for x in samples}),
                    "Actual UI row identities are not present in the original cached array")
            sql = independent_inspector_samples(self.installation, self.targets[pending["target_key"]], samples, visible)
            proof = {"status": "ORIGINAL_CACHE_AND_VISIBLE_ROW_OBSERVATIONS_NOT_FULL_RENDER_ACCEPTANCE",
                "request_id": pending["request_id"], "epoch": pending["epoch"], "target_key": pending["target_key"],
                "native_process_id": pid, "full_cached_count": count, "native_ordered_identity_sha256": report["orderedIdentitySHA256"],
                "native_membership_digest_scope": "complete original cached order; independent SQL witnesses cover only retained bounded identities",
                "actual_visible_rows": pending["visible_rows"], "actual_empty_state": pending["empty_state"],
                "independent_sql_witnesses": sql,
                "native_report": report, "native_report_file": witness(report_path), "workspace": pending["workspace"],
                "post_resource_epoch": True, "native_notification_posted_uptime": notification_time,
                "native_response_observed_uptime": observed_time}
            self.inspector_records[proof["request_id"]] = proof
            write(OUT / "inspector-proofs" / (proof["request_id"] + ".json"), proof)
            Path(pending["request_path"]).unlink()
            return {"requestID": proof["request_id"], "fullCachedCount": count,
                    "nativeOrderedIdentitySHA256": report["orderedIdentitySHA256"], "visibleRows": len(visible),
                    "independentSQLSamples": len(sql), "postResourceEpoch": True}
        except Exception as error:
            write(OUT / "inspector-proofs" / (pending["request_id"] + ".failed.json"),
                  {"status": "FAILED_OBSERVATION_NOT_ACCEPTED", "requestID": pending["request_id"], "error_type": type(error).__name__})
            raise
        finally:
            # A verified response or explicit failed receipt ends this fence.
            self.pending_inspector = None

    def complete_reader(self, request):
        rows, restores = request["observations"], request["forcedRestoreEvidence"]
        epochs = {k: v for k, v in self.epochs.items() if v["kind"] == "reader-open"}
        require(self.active is None and self.pending_inspector is None
                and len(rows) == len(epochs) == 20 and request["forcedRelaunches"] == len(restores) == 10,
                "Actual twenty opens and ten forced relaunches are incomplete")
        require({(x["targetKey"], x["mode"]) for x in rows}
                == {(k, mode) for k in self.targets for mode in ("process-cold", "warm")}
                and {x["epoch"] for x in rows} == set(epochs), "Observed original twenty-open schedule differs")
        interaction_epochs = {k: v for k, v in self.epochs.items() if v["kind"] == "reader-overview"}
        require(len(interaction_epochs) == 20
                and {r["firstInteraction"]["epoch"] for r in rows} == set(interaction_epochs),
                "The existing twenty post-open original overview interactions are incomplete")
        proofs = {p["request_id"]: p for p in self.source_proofs}
        for row in rows:
            epoch = epochs[row["epoch"]]
            require(epoch["status"] == "OBSERVED_NOT_PERFORMANCE_ACCEPTANCE" and epoch["processID"] == row["processID"]
                    and epoch["target_key"] == row["targetKey"] and epoch["mode"] == row["mode"],
                    "A failed or mismatched resource epoch cannot disappear from the aggregate")
            proof = proofs.get(row["sourceObservationID"])
            require(proof is not None and proof["epoch"] == row["epoch"] and proof["native_core_receipt_present"]
                    and proof["native_core_request_id"] == row["route"]["receiptFields"]["request"]
                    and proof["route_visibility_upper_bound_seconds"] == row["route"]["requestToNativeVisibleUpperBoundSeconds"],
                    "Every actual open requires its exact independently retained post-timing source and Core/glyph evidence")
            interaction = row["firstInteraction"]
            observed = interaction_epochs[interaction["epoch"]]
            require(observed["status"] == "OBSERVED_NOT_PERFORMANCE_ACCEPTANCE"
                    and observed["processID"] == epoch["processID"] and observed["target_key"] == epoch["target_key"]
                    and observed["mode"] == epoch["mode"]
                    and observed["resource_start_host_monotonic"] >= epoch["resource_end_host_monotonic"]
                    and interaction["actualOverviewIdentifier"] == "study-groups-overview"
                    and interaction["actualDocumentID"] == proof["actual_workspace_document_id"]
                    and interaction["actualCardIdentifier"] in (
                        "tab-switcher-grid-cell-" + proof["actual_workspace_document_id"],
                        "tab-switcher-list-cell-" + proof["actual_workspace_document_id"]),
                    "Actual post-open original overview identity/resource chronology changed")
            start, action, end = (interaction[k] for k in ("observationStartedUptime", "nativeActionRequestedUptime", "originalOverviewObservedUptime"))
            require(all(type(v) in (int, float) and math.isfinite(v) for v in (start, action, end))
                    and start <= action <= end
                    and interaction["requestToOriginalOverviewUpperBoundSeconds"] == end - start
                    and interaction["nativeActionToOverviewUpperBoundSeconds"] == end - action,
                    "Original native overview interaction interval is malformed")
        require({x["targetKey"] for x in restores} == set(self.targets), "Actual forced restore target set differs")
        for row in restores:
            before, after = proofs[row["beforeRequestID"]], proofs[row["afterRequestID"]]
            require(before["target_key"] == after["target_key"] == row["targetKey"]
                    and before["native_process_id"] == row["beforeProcessID"]
                    and after["native_process_id"] == row["afterProcessID"]
                    and row["beforeProcessID"] != row["afterProcessID"]
                    and before["actual_workspace_document_id"] == after["actual_workspace_document_id"] == row["documentID"]
                    and before["actual_workspace_group_id"] == after["actual_workspace_group_id"] == row["groupID"]
                    and before["source_index"] == after["source_index"] == row["beforeSource"] == row["afterSource"]
                    and before["pixel_offset"] == row["beforeOffset"] and after["pixel_offset"] == row["afterOffset"]
                    and abs(before["pixel_offset"] - after["pixel_offset"]) <= 1,
                    "The actual original forced restore/document/source/pixel witness differs")
        self.reader_complete = {k: v for k, v in request.items() if k != "token"}
        write(OUT / "twenty-original-opens.json", self.reader_complete)
        return {"observations": 20, "verifiedForcedRestores": 10,
                "scope": "actual UI/component observations; final performance/device criteria remain separate"}

    def handle(self, request, container):
        action = request["action"]
        if action == "process":
            pid, _ = self.process()
            return {"processID": pid}
        if action == "require_idle":
            require(self.active is None and self.pending_inspector is None, "A resource/cache epoch is still active")
            return {"idle": True}
        if action == "begin": return self.begin(request)
        if action == "end": return self.end(request)
        if action == "validate_source": return self.validate_source(request, container)
        if action == "arm_inspector": return self.arm_inspector(request, container)
        if action == "validate_inspector": return self.validate_inspector(request, container)
        if action == "fail_inspector":
            pending = self.pending_inspector
            require(pending is not None and request["requestID"] == pending["request_id"], "No exact pending Inspector request")
            write(OUT / "inspector-proofs" / (pending["request_id"] + ".failed.json"),
                  {"status": "NATIVE_RESPONSE_NOT_OBSERVED", "requestID": pending["request_id"]})
            self.pending_inspector = None
            return {"fenceReleasedAfterExplicitFailure": True}
        if action == "complete_reader": return self.complete_reader(request)
        if action == "complete_inspector":
            require(self.active is None and self.pending_inspector is None, "Inspector completion has an active resource fence")
            ids, scales = request["observationIDs"], request["scales"]
            require(ids and len(ids) == len(set(ids)) and set(ids) == set(self.inspector_records),
                    "Every actual Inspector observation, including failed scales, must be retained")
            exploration = request["exploration"]
            inspector_ids = self.catalog["inspectorBookIDs"] if CORPUS_NAME == "full-v40" else (103, 28, 3152)
            expected_targets = {k for k, v in self.targets.items() if v["bookID"] in inspector_ids}
            require(len(exploration) == len(expected_targets) == 9
                    and {r["targetKey"] for r in exploration} == expected_targets,
                    "Original first/middle/last Inspector chapter exploration must retain all nine outcomes")
            for row in exploration:
                actual = self.inspector_records.get(row["observationID"])
                require(actual is not None and actual["target_key"] == row["targetKey"]
                        and actual["full_cached_count"] == row["actualCount"]
                        and len(actual["actual_visible_rows"]) == row["visibleRows"],
                        "A genuine original Inspector exploration outcome was changed or omitted")
            require([x["requestedCount"] for x in scales] == [100, 500, 2000], "Original Inspector required scales changed")
            for scale in scales:
                record = self.inspector_records.get(scale.get("observationID"))
                require(record is not None and record["full_cached_count"] == scale["actualCount"],
                        "A natural workload scale has no authentic original cached/UI observation")
                scale["atLeastRequestedCount"] = record["full_cached_count"] >= scale["requestedCount"] and bool(record["actual_visible_rows"])
                scale["exactRequestedCount"] = record["full_cached_count"] == scale["requestedCount"] and bool(record["actual_visible_rows"])
            self.inspector_complete = {k: v for k, v in request.items() if k != "token"}
            self.inspector_complete["exact_size_criterion_met"] = all(s["exactRequestedCount"] for s in scales)
            self.inspector_complete["natural_at_least_workloads_met"] = all(s["atLeastRequestedCount"] for s in scales)
            self.inspector_complete["full_row_rendering_acceptance"] = False
            write(OUT / "original-inspector-scales.json", self.inspector_complete)
            require(self.inspector_complete["natural_at_least_workloads_met"],
                    "Actual observed original chapters did not reach all required 100/500/2000 relationship workloads")
            return {"observations": len(ids), "exactSizeCriterionMet": self.inspector_complete["exact_size_criterion_met"],
                    "naturalAtLeastWorkloadsMet": True, "fullRowRenderingAcceptance": False}
        raise ValueError("Unknown bounded observation action")

    def run(self):
        next_sample = time.monotonic()
        try:
            while not self.stop_event.is_set() and time.monotonic() < self.deadline:
                if self.active is not None and time.monotonic() >= next_sample:
                    self.active["samples"].append(self.sample(self.active["processID"], self.active["executable"]))
                    require(len(self.active["samples"]) <= 10000, "Resource observation bound exceeded")
                    next_sample = time.monotonic() + 0.25
                for path in self.containers.glob("*/Documents/full-v32-" + self.token + "-*.request.json"):
                    if path in self.seen: continue
                    require(len(self.seen) < 512, "Owned observation request bound exceeded")
                    self.seen.add(path)
                    require(0 <= time.time() - path.stat().st_mtime < 30, "Stale owned observation request")
                    request = bounded_json(path, 262144)
                    nonce = request["nonce"]
                    require(request["schema"] == 1 and request["token"] == self.token and request["udid"] == self.udid
                            and str(uuid.UUID(nonce)).upper() == nonce
                            and path.name == "full-v32-" + self.token + "-" + nonce + ".request.json",
                            "Owned observation request identity mismatch")
                    response = {"schema": 1, "nonce": nonce, "udid": self.udid, "action": request["action"], "ok": False}
                    try:
                        current = Path(command(["xcrun", "simctl", "get_app_container", self.udid, BUNDLE, "data"], timeout=45).stdout.strip()).resolve(strict=True)
                        require(path.parent.parent.resolve() == current, "Observation request is in a stale app container")
                        response.update(self.handle(request, current), ok=True)
                    except Exception as error:
                        response["error_type"] = type(error).__name__
                        # All ValueError messages are fixed source strings; never include argv/token/path.
                        response["error"] = str(error)[:256].replace(self.token, "<redacted>")
                        write(OUT / "request-failures" / (nonce + ".json"), response)
                    write(path.with_name(path.name.replace(".request.json", ".ack.json")), response)
                self.stop_event.wait(0.05)
            if not self.stop_event.is_set(): self.error = "Owned observation host deadline expired"
        except Exception as error:
            self.error = type(error).__name__
        finally:
            if self.active is not None:
                value, self.active = self.active, None
                value["status"] = "ABORTED_NOT_ACCEPTED"
                write(OUT / "resource-epochs" / (value["epoch"] + ".json"), value)
            if self.pending_inspector is not None:
                write(OUT / "inspector-proofs" / (self.pending_inspector["request_id"] + ".failed.json"),
                      {"status": "HOST_STOPPED_WITH_PENDING_OBSERVATION", "requestID": self.pending_inspector["request_id"]})
                self.pending_inspector = None
            write(OUT / "observation-host.json", {"error": self.error, "requests": len(self.seen),
                "resource_epochs": len(self.epochs), "source_proofs": self.source_proofs,
                "inspector_observations": len(self.inspector_records), "reader_complete": self.reader_complete is not None,
                "inspector_complete": self.inspector_complete is not None})

    def stop(self):
        self.stop_event.set()
        self.join(timeout=150)
        require(not self.is_alive(), "Owned observation host cleanup is unverified")

def instrument_inventory():
    result = {}
    for key, args in (
        ("xcode", ["xcodebuild", "-version"]),
        ("xctrace_version", ["xcrun", "xctrace", "version"]),
        ("templates", ["xcrun", "xctrace", "list", "templates"]),
        ("record_help", ["xcrun", "xctrace", "record", "--help"]),
        ("export_help", ["xcrun", "xctrace", "export", "--help"]),
        ("darwin_ps_keywords", ["/bin/ps", "-L"]),
    ):
        value = command(args, timeout=60, check=False)
        result[key] = value.stdout + value.stderr
        result[key + "_exit"] = value.returncode
    write(OUT / "actual-apple-instrument-capabilities.json", result)
    return result

def build_identity(context):
    build = json.loads((ROOT / "build/hq-stage2/result.json").read_text())
    require(build.get("status") == "SIMULATOR_BUILD_FOR_REAL_UI_PASS"
            and build.get("checkout_sha") == context["checkout_sha"], "No authentic same-checkout app/UI test build")
    original = runpy.run_path(str(ROOT / "Scripts/CI/hq-stage2-focused-apple.py"))
    original["verify_actual_sources"](build)
    qualified_sdk = verify_qualified_sdk(build)
    products = ROOT / "build/DerivedData/Build/Products/Debug-iphonesimulator"
    bundles = [products / "Maktabah.app", products / "Maktabah-iOSUITests-Runner.app",
               products / "Maktabah-iOSUITests-Runner.app/PlugIns/Maktabah-iOSUITests.xctest"]
    binary_records = {}
    dwarf_uuids = {}
    for bundle in bundles:
        info = plistlib.loads((bundle / "Info.plist").read_bytes())
        binary_records[str(bundle.relative_to(ROOT))] = witness(bundle / info["CFBundleExecutable"])
        dwarf_uuids[str(bundle.relative_to(ROOT))] = command(["xcrun", "dwarfdump", "--uuid", str(bundle / info["CFBundleExecutable"])]).stdout
        require(re.search(r"UUID: [0-9A-Fa-f-]{36}", dwarf_uuids[str(bundle.relative_to(ROOT))]) is not None, "Actual Mach-O symbol identity missing")
    test_runs = sorted(products.parent.glob("*.xctestrun"))
    require(len(test_runs) == 1, "Exactly one original same-build xctestrun is required")
    result = {"built_binaries": binary_records, "actual_macho_dwarf_uuids": dwarf_uuids, "xctestrun": witness(test_runs[0]),
              "build_receipt": witness(ROOT / "build/hq-stage2/result.json"), "qualified_sdk_route": qualified_sdk,
              "complete_native_images": runpy.run_path(str(ROOT / "Scripts/CI/mac-prepared-inputs.py"))["code_images"](ROOT)}
    write(OUT / "actual-built-inputs.json", result)
    return products, test_runs[0], result


def verify_qualified_sdk(build):
    routes = build.get("original_editor_routes")
    require(isinstance(routes, dict), "Full-v32 observations require the final qualified original SDK routes")
    app = ROOT / "build/DerivedData/Build/Products/Debug-iphonesimulator/Maktabah.app"
    # The original build already executed symbol/runtime ownership checks.
    # Revalidate their exact code/resources/signatures without recompilation.
    return runpy.run_path(str(ROOT / "Scripts/CI/original_editor_sdk_routes.py"))["verify"](
        ROOT, routes["path"], "Debug", "iphonesimulator", app, route_sha256=routes["sha256"], after_ui=True)


def execute():
    config = json.loads(INPUTS.read_text())
    context = source_context(require_frozen=True)
    require(sys.platform == "darwin", "Genuine original UIKit observations require Apple macOS/Xcode")
    require(shutil.disk_usage(ROOT).free >= 7 * 1024**3, "Insufficient room for original managed native full-v32 install")
    write(OUT / "source-before.json", context)
    products, test_run, build = build_identity(context)
    instruments = instrument_inventory()
    sdk = command(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"]).stdout.strip()
    selected = os.environ.get("FAITHFUL_RUNTIME27_IDENTIFIER")
    runtimes = json_command(["xcrun", "simctl", "list", "runtimes", "available", "-j"])["runtimes"]
    runtimes = [r for r in runtimes if r.get("isAvailable") and r["identifier"] == selected
                and r["version"].split(".")[:2] == sdk.split(".")[:2] and r["version"].split(".")[0] == "27"]
    require(len(runtimes) == 1, "Original explicitly SDK-matched iPadOS27 runtime required")
    runtime = runtimes[0]
    types = [t for t in runtime["supportedDeviceTypes"] if "iPad Pro" in t["name"] and "13-inch" in t["name"]]
    require(types, "Actual supported original 13-inch iPad type missing")
    if REUSED_INSTALLATION is None:
        device_type = sorted(types, key=lambda t: t["identifier"])[-1]
        udid = command(["xcrun", "simctl", "create", "Original-full-v32-" + uuid.uuid4().hex[:8],
                        device_type["identifier"], runtime["identifier"]]).stdout.strip()
        require(str(uuid.UUID(udid)).upper() == udid, "Unexpected owned Simulator identity")
        ownership = {"created_owned_simulator": udid}
    else:
        udid, device_type, ownership = REUSED_INSTALLATION.admit_owner(config, runtime, types)
    report = {"status": "STARTED_NOT_ACCEPTED", "source": context, **ownership,
        "corpus_profile": CORPUS_NAME,
        "runtime": runtime, "device_type": device_type, "configuration": "Debug", "data_profile": "production",
        "full_native116_acceptance": False, "full_release114_acceptance": False,
        "physical_device_acceptance": False, "full_performance_acceptance": False}
    delivery = host = trace = None
    database = installation = None
    failure = None
    cleanup_failures = []
    try:
        command(["xcrun", "simctl", "boot", udid], timeout=90)
        command(["xcrun", "simctl", "bootstatus", udid, "-b"], timeout=900)
        command(["xcrun", "simctl", "install", udid, str(products / "Maktabah.app")], timeout=600)
        if REUSED_INSTALLATION is None:
            (ROOT / "sim_udid.txt").write_text(udid)
            require(not (ROOT / "build/artifacts/production-native-fixture-install.json").exists(),
                    "A retained original production installer report must not be overwritten/reused")
            require(bounded([sys.executable, "Scripts/CI/prepare-faithful-ipad-fixtures.py", "--profile", "production",
                             "--release-id", str(config["source_database"]["releaseID"])],
                            OUT / "original-production-install.log", 3900) == 0, "Original production native installer failed")
            database, installation = admit_installation(config, udid)
        else:
            database, installation = REUSED_INSTALLATION.admit_current_installation(config, udid, build)
            report["reused_installation"] = installation
        catalog_dir, catalog = prepare_catalog(config, installation)
        container = Path(command(["xcrun", "simctl", "get_app_container", udid, BUNDLE, "data"], timeout=45).stdout.strip())
        environment = os.environ.copy()
        environment["TEST_RUNNER_FAITHFUL_PRODUCTION_WORKSPACE_FILE"] = str(container / "Library/Application Support/ChavrusaText/StudyWorkspace/workspace-v1.json")
        environment["TEST_RUNNER_RUNTIME27_RECORD_CONFIGURATION"] = "1"
        delivery = runpy.run_path(str(ROOT / "Scripts/CI/runtime27-url-delivery.py"))["NativeURLDelivery"](udid, container, "full-v32", OUT)
        environment.update(delivery.start())
        trace = AppleTraceCapture(udid, instruments)
        trace.start()
        host = ObservationHost(udid, container, catalog_dir, catalog, installation, trace)
        environment.update(host.environment())
        environment["TEST_RUNNER_READER_OBSERVATION_CORPUS"] = CORPUS_NAME
        host.start()
        result_bundle = OUT / ("original-" + CORPUS_NAME + ".xcresult")
        args = ["xcodebuild", "test-without-building", "-xctestrun", str(test_run),
                "-destination", "platform=iOS Simulator,id=" + udid, "-parallel-testing-enabled", "NO",
                "-maximum-concurrent-test-simulator-destinations", "1",
                "-test-timeouts-enabled", "YES", "-maximum-test-execution-time-allowance", "600",
                "-resultBundlePath", str(result_bundle)]
        args.extend("-only-testing:Maktabah-iOSUITests/" + case for case in SELECTED)
        report["xcodebuild_exit"] = bounded(args, OUT / "original-ui-tests.log", 2100, environment)
        log = OUT / "original-ui-tests.log"
        text = delivery.redact_evidence(log.read_text(errors="replace")).replace(host.token, "<redacted-observer-token>")
        log.write_text(text)
        strict = [sys.executable, "tools/verify_xcresult_zero_skips.py", "--xcresult", str(result_bundle),
                  "--log", str(log), "--scope", "focused-ui", "--expected-device", udid,
                  "--expected-os-major", "27", "--min-tests", str(len(SELECTED)), "--out", str(OUT / "zero-skip.json")]
        for case in SELECTED:
            strict.extend(["--required-case", case])
        report["zero_skip_exit"] = command(strict, timeout=180, check=False).returncode
        verifier = runpy.run_path(str(ROOT / "Scripts/CI/verify-faithful-xctest.py"))
        declaration = verifier["verify"](text, SELECTED, ROOT / "Maktabah-iOSUITests")
        write(OUT / "actual-test-cases.json", declaration)
        if result_bundle.is_dir():
            command(["xcrun", "xcresulttool", "export", "attachments", "--path", str(result_bundle),
                     "--output-path", str(OUT / "captures")], timeout=300, check=False)
        require(report["xcodebuild_exit"] == report["zero_skip_exit"] == 0
                and declaration["status"] == "EXECUTED_PASS", "Every exact additive case must execute without skips")
        require(host.error is None and host.reader_complete is not None and host.inspector_complete is not None,
                "Original Reader/Inspector evidence incomplete")
        report["status"] = "ORIGINAL_UI_OBSERVATIONS_COMPLETE_METRICS_REVIEW_REQUIRED"
    except BaseException as error:
        failure = error
        report.update(status="FAILED_OR_INCOMPLETE", error_type=type(error).__name__,
                      error=str(error).replace(host.token, "<redacted>") if host else str(error))
    finally:
        cleanup = {}
        if host is not None:
            try:
                host.stop()
                require(host.error is None, "Owned observation host failed")
                if host.reader_complete:
                    rows = host.reader_complete["observations"]
                    report["reader_observations_by_mode"] = {}
                    for mode in ("process-cold", "warm"):
                        selected_rows = [r for r in rows if r["mode"] == mode]
                        report["reader_observations_by_mode"][mode] = {
                            "visibility_upper_bound_seconds": percentiles([r["route"]["requestToNativeVisibleUpperBoundSeconds"] for r in selected_rows]),
                            "application_cpu_seconds": percentiles([host.epochs[r["epoch"]]["app_cpu_seconds"] for r in selected_rows]),
                            "sampled_app_rss_bytes": percentiles([host.epochs[r["epoch"]]["sampled_max_rss_bytes"] for r in selected_rows]),
                            "first_original_overview_interaction_upper_bound_seconds": percentiles(
                                [r["firstInteraction"]["requestToOriginalOverviewUpperBoundSeconds"] for r in selected_rows]),
                            "first_original_overview_interaction_cpu_seconds": percentiles(
                                [host.epochs[r["firstInteraction"]["epoch"]]["app_cpu_seconds"] for r in selected_rows])}
                report["inspector_observation_counts"] = [v["full_cached_count"] for v in host.inspector_records.values()]
            except Exception as error:
                cleanup["observation_host"] = type(error).__name__
                cleanup_failures.append("observation_host")
        if trace is not None:
            try:
                report["actual_continuous_trace"] = trace.stop()
                require(report["actual_continuous_trace"]["status"] == "ACTUAL_TRACE_RETAINED_COVERAGE_AND_SCHEMA_REVIEW_REQUIRED"
                        and report["actual_continuous_trace"]["owned_process_group_cleanup"]["group_state"] == "GONE_CHECKED",
                        "Actual original trace or owned recorder cleanup is unverified")
            except Exception as error:
                cleanup["original_trace"] = type(error).__name__
                cleanup_failures.append("original_trace")
        if delivery is not None:
            try: delivery.stop()
            except Exception as error:
                cleanup["original_url_transport"] = type(error).__name__
                cleanup_failures.append("original_url_transport")
        if database is not None:
            try:
                if REUSED_INSTALLATION is not None:
                    database, relocation = REUSED_INSTALLATION.current_database(udid)
                    report["post_ui_data_container_relocation"] = relocation
                report["post_ui_database"] = witness(database)
                require(report["post_ui_database"]["sha256"] == installation["database"]["sha256"]
                        and report["post_ui_database"]["bytes"] == installation["database"]["bytes"],
                        "Original production database changed during observation")
                report["database_bytes_unchanged"] = True
            except Exception as error:
                cleanup["database_verification"] = type(error).__name__
                cleanup_failures.append("database_verification")
        try:
            require(source_context(require_frozen=True) == context, "Source changed during execution")
            for record in build["built_binaries"].values():
                require(digest(record["path"]) == record["sha256"], "Original built executable changed during execution")
            require(witness(ROOT / "build/hq-stage2/result.json") == build["build_receipt"],
                    "Original qualified build receipt changed during observation")
            require(runpy.run_path(str(ROOT / "Scripts/CI/mac-prepared-inputs.py"))["code_images"](ROOT)
                    == build["complete_native_images"], "Complete original app/SDK/UI-runner image closure changed")
            qualified = verify_qualified_sdk(json.loads((ROOT / "build/hq-stage2/result.json").read_bytes()))
            require(qualified == build["qualified_sdk_route"], "Qualified SDK route changed during full-v32 observations")
            report["qualified_sdk_route"] = qualified
            report["complete_native_image_count"] = len(build["complete_native_images"])
            report["source_and_built_binary_bytes_unchanged"] = True
            if REUSED_INSTALLATION is not None:
                report["current_installed_images_after_ui"] = REUSED_INSTALLATION.verify_installed_images(udid, build)
                report["original_installation_receipts_unchanged"] = REUSED_INSTALLATION.verify_prior_receipts()
        except Exception as error:
            cleanup["source_binary_verification"] = type(error).__name__
            cleanup_failures.append("source_binary_verification")
        if REUSED_INSTALLATION is None:
            for name, args, timeout in (
                ("shutdown", [sys.executable, "Scripts/CI/shutdown-faithful-simulator.py", udid], 240),
                ("delete", ["xcrun", "simctl", "delete", udid], 120),
            ):
                try:
                    result = command(args, timeout=timeout, check=False)
                    cleanup[name] = {"exit": result.returncode}
                    if result.returncode: cleanup_failures.append(name)
                except Exception as error:
                    cleanup[name] = {"error_type": type(error).__name__}
                    cleanup_failures.append(name)
        else:
            try:
                cleanup["retained_external_simulator"] = REUSED_INSTALLATION.retain_simulator(udid)
            except Exception as error:
                cleanup["retained_external_simulator"] = {"error_type": type(error).__name__}
                cleanup_failures.append("retained_external_simulator")
        report["owned_cleanup"] = cleanup
        report["cleanup_or_post_verification_failures"] = cleanup_failures
        if cleanup_failures:
            report["status"] = "FAILED_OR_INCOMPLETE"
        report["missing_or_unqualified_metrics"] = {
            "exact_first_pixel": "NOT_MEASURED; native visible receipt polling is an upper bound",
            "longest_main_actor_slice": "ACTUAL_TRACE_REVIEW_REQUIRED; CPU sampling is not a continuous actor-slice measurement",
            "layout_hitches": "ACTUAL_TRACE_SCHEMA_AND_COVERAGE_REVIEW_REQUIRED",
            "sql_wait": "NOT_INSTRUMENTED; original service signpost is not SQL wait",
            "continuous_peak_rss_or_phys_footprint": "NOT_MEASURED; sampled exact app-PID Darwin RSS only",
            "disk_cold": "NOT_CLAIMED; process-cold only",
            "exact_inspector_sizes": "MET_ONLY_IF_AUTHENTIC_ORIGINAL_COUNTS_EQUAL_100_500_2000; no truncation",
            "all_inspector_row_bodies": "NOT_AUTOMATICALLY_PROVEN; original row UI/screenshot and source witnesses retained for review",
            "reader_cancellation_selection_notes_nikud_rtl": "EXISTING_OR_FUTURE_NATIVE_CASES_REMAIN_SEPARATE; not inferred from these observations",
            "physical_ipad": "NOT_RUN",
        }
        write(OUT / "result.json", report)
    if failure is not None:
        raise failure
    require(not cleanup_failures, "Owned cleanup or immutable post-execution verification failed")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("phase", choices=["source-check", "execute"])
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    if args.phase == "source-check":
        context = source_context(require_frozen=False)
        declarations = runpy.run_path(str(ROOT / "Scripts/CI/verify-faithful-xctest.py"))["validate_selections"](
            SELECTED, ROOT / "Maktabah-iOSUITests")
        write(OUT / "source-only-admission.json", {"status": "SOURCE_ONLY_UNFINALIZED",
              "source": context, "declarations": declarations, "native_ui_executed": 0, "dispatch_authorized_by_this_check": False})
        require(declarations["status"] == "DECLARATIONS_MATCH", "Actual additive XCTest declarations are incomplete")
    else:
        execute()

if __name__ == "__main__":
    main()

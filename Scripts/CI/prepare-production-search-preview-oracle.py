#!/usr/bin/env python3
"""Produce an original-source preview oracle from one actual passed UI page.

This host program never launches the app, supplies search results, writes an app
store, downloads a corpus, or turns source compilation into native acceptance.
The existing Swift catalog and complete production service/presentation sources
remain unchanged. Execute only after the original preview-hit phase has passed.
"""
from __future__ import annotations

import argparse
import contextlib
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import sqlite3
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
SELF = "Scripts/CI/prepare-production-search-preview-oracle.py"
PROFILE = "Scripts/CI/reader-full-v40-ui-observation.inputs.json"
CATALOG = "docs/hq-integration/wave2-20261127/reader/FullV40ObservationCatalog.swift"
SERVICE = "Source/Otzaria/Reading/OtzariaReadingUnitService.swift"
PRESENTATION = "Source/LibraryBackend/LibraryBackendModels.swift"
CASE = "Maktabah-iOSUITests/PublishedProductionSearchDataTests/testPublishedV40NafshiFirstPageForIndependentFullContextOracle"
ATTACHMENT = "published-v40-nafshi-source-selection-for-independent-context-oracle"
V40_SHA = "8389709c1702753af6f0719ef1c98c09854450e48ebb05fe1f95486b26348b01"
V40_BYTES = 4_355_063_808
V40_COUNTS = {"book": 8259, "line": 7_925_185, "link": 7_001_824}
QUERY_SHA = hashlib.sha256("נפשי".encode()).hexdigest()
ORACLE_STATUS = "ORIGINAL_SOURCE_PREVIEW_CATALOG_ONLY_NOT_SEARCH_OR_UI"
MAX_ORACLE = 2_000_000  # Existing original study-controller runner input bound.
MAX_FILE = 64 * 1024 * 1024
MAX_ATTEMPTS = 100
MAX_SECONDS = 1_200
OUTPUT_BUDGET = 1024 ** 3
SQL_IDENTITY = ("SELECT l.id,l.bookId,l.lineIndex,b.title,COALESCE(l.heRef,'') "
                "FROM line l JOIN book b ON b.id=l.bookId WHERE l.bookId=? AND l.lineIndex=?")
RUNTIME_REQUIREMENTS = [
    "The chosen book must be absent from the next case's actual imported workspace tabs.",
    "The genuine selection case requires no pre-existing rendered annotation on the chosen line.",
    "Original native viewport, controls, source focus, persistence and navigation must still pass; no source oracle proves them.",
]


def require(value, message):
    if not value:
        raise ValueError(message)


def integer(value, minimum=0, maximum=2 ** 63 - 1):
    return type(value) is int and minimum <= value <= maximum


def digest(data):
    return hashlib.sha256(data).hexdigest()


def utf16(value):
    return len(value.encode("utf-16-le")) // 2


def canonical_uuid(value):
    require(isinstance(value, str) and str(uuid.UUID(value)).upper() == value, "Canonical original UUID required")
    return value


def load_module(root, relative):
    path = root / relative
    name = "preview_source_" + path.stem.replace("-", "_")
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    sys.modules[name] = value
    spec.loader.exec_module(value)
    return value


def git(root, *args):
    return subprocess.check_output(["git", "-c", "gc.auto=0", "-C", str(root), *args],
                                   text=True, timeout=30).strip()


def source_snapshot(root, settings, *, frozen):
    """Read the actual committed source closure; no build/device/corpus needed."""
    root = settings.canonical_path(root, directory=True)
    profile_record = settings.witness(root / PROFILE)
    config = settings.decode_json(settings.verify_witness(profile_record))
    require(config.get("schema") == "otzaria.full-v40.original-ui-observation/1"
            and config.get("source_database", {}).get("databaseSHA256") == V40_SHA
            and config["source_database"].get("databaseBytes") == V40_BYTES
            and config["source_database"].get("counts") == V40_COUNTS,
            "Use the original full-v40 profile and independently pinned complete corpus")
    compiled = config.get("catalog_compiled_sources")
    require(isinstance(compiled, list) and compiled and len(compiled) == len(set(compiled))
            and SERVICE in compiled and PRESENTATION in compiled and CATALOG not in compiled,
            "Require the original whole source-service and presentation compile closure")
    paths = [PROFILE, CATALOG, SELF, "Scripts/CI/reader-full-v32-ui-observation.py",
             "Scripts/CI/reader-full-v40-ui-observation.py", *compiled]
    records = {}
    for relative in paths:
        path = Path(relative)
        require(not path.is_absolute() and path.parts and ".." not in path.parts, "Source path escaped the original checkout")
        record = settings.witness(root / relative)
        require(git(root, "hash-object", record["path"]) == git(root, "rev-parse", "HEAD:" + relative),
                "Dirty/uncommitted original source: " + relative)
        records[relative] = record
        if frozen and relative != SELF and relative != PROFILE:
            require(config.get("input_sha256", {}).get(relative) == record["sha256"],
                    "Current source is not in the frozen execution closure: " + relative)
    snapshot = {"checkoutSHA": git(root, "rev-parse", "HEAD"), "files": records,
                "catalogCompiledSources": compiled, "profile": profile_record,
                "nativeUIExecuted": 0, "searchProviderExecuted": False}
    return snapshot, config


def compile_catalog(root, settings, snapshot, config, directory, module_cache=None):
    """Use the original prepare_catalog compiler recipe, without its DB run."""
    require(sys.platform == "darwin", "Whole original Swift source compilation requires Apple macOS/Xcode")
    directory.mkdir()
    def output(command):
        return subprocess.check_output(command, text=True, timeout=30).strip()
    # Keep the original driver's invocation name. Resolving swiftc's symlink
    # for argv[0] invokes swift-frontend directly and changes flag semantics.
    swiftc = Path(output(["xcrun", "--sdk", "macosx", "--find", "swiftc"]))
    swiftc_binary = swiftc.resolve(strict=True)
    sdk = output(["xcrun", "--sdk", "macosx", "--show-sdk-path"])
    zstd = (Path(output(["brew", "--prefix", "zstd"])) / "lib/libzstd.dylib").resolve(strict=True)
    binary = directory / "original-source-catalog"
    command = [str(swiftc), "-parse-as-library", "-swift-version", "6", "-Xfrontend", "-strict-concurrency=complete",
               "-O", "-sdk", sdk, "-L", str(zstd.parent), "-lzstd", "-Xlinker", "-rpath", "-Xlinker", str(zstd.parent)]
    cache = Path(module_cache) if module_cache is not None else directory / "module-cache"
    require(cache.is_absolute() and ".." not in cache.parts, "Require an explicitly owned absolute module cache")
    cache.mkdir(parents=True, exist_ok=True)
    require(cache.resolve(strict=True) == cache, "Module cache is redirected")
    command.extend(["-module-cache-path", str(cache)])
    command.extend([str(root / relative) for relative in config["catalog_compiled_sources"]])
    command.extend([str(root / CATALOG), "-o", str(binary)])
    for record in snapshot["files"].values():
        settings.verify_witness(record)
    inputs = {"command": command, "swiftc": settings.witness(swiftc_binary, 256 * 1024 * 1024),
              "swiftcDriverPath": str(swiftc),
              "zstd": settings.witness(zstd, 64 * 1024 * 1024),
              "source_sha256": {relative: snapshot["files"][relative]["sha256"] for relative in config["catalog_compiled_sources"]},
              "catalogSource": snapshot["files"][CATALOG], "sourceSnapshot": snapshot,
              "scope": "Unchanged original catalog and whole production source closure; compile only, no app/UI"}
    receipt = settings.write_new(directory / "compile-inputs.json", inputs)
    started = time.time()
    with (directory / "compile.log").open("xb") as stream:
        result = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT, timeout=300, check=False)
    completed = {"exit": result.returncode, "startedAtUnix": started, "finishedAtUnix": time.time(),
                 "inputs": receipt, "log": settings.witness(directory / "compile.log", MAX_FILE),
                 "scope": "Actual Apple whole-source compilation only; native UI not executed"}
    settings.write_new(directory / "compile-result.json", completed)
    require(result.returncode == 0, "Original whole-source catalog compilation failed; keep the actual log")
    linkage = output(["otool", "-L", str(binary)])
    executable = {"binary": settings.witness(binary, MAX_FILE), "linkage": linkage}
    settings.write_new(directory / "native-executable.json", executable)
    for record in snapshot["files"].values():
        settings.verify_witness(record)
    return receipt, executable


def actual_page(payload):
    """Validate original metadata without creating a query hit or source text."""
    require(isinstance(payload, dict) and payload.get("scope") ==
            "actual original UI query and provider page plus immutable SQL, not full-context acceptance",
            "Wrong original selected-page attachment scope")
    provider, publication, sql = payload.get("provider"), payload.get("publication"), payload.get("independentSQL")
    require(isinstance(provider, dict) and isinstance(publication, dict), "Original provider/publication is missing")
    require(provider.get("event") == "provider" and publication.get("event") == "published"
            and provider.get("engine") == publication.get("engine") == "otzaria"
            and provider.get("profileID") == publication.get("profileID") == "production", "Wrong original page engine/profile")
    for key in ("namespace", "sessionID"):
        require(canonical_uuid(provider.get(key)) == canonical_uuid(publication.get(key)), "Provider/publication identity differs: " + key)
    require(integer(provider.get("processID"), 1) and provider["processID"] == publication.get("processID")
            and integer(provider.get("submissionRevision"), 1)
            and provider["submissionRevision"] == publication.get("submissionRevision"),
            "Original provider/publication PID or submission differs")
    request = provider.get("request", {})
    require(request.get("querySHA256") == QUERY_SHA and "query" not in request
            and type(request.get("offset")) is int and request["offset"] == 0
            and type(request.get("limit")) is int and request["limit"] == 100,
            "Only the actual first 100-result page of the exact requested query is eligible")
    rows, items = provider.get("page", {}).get("results"), publication.get("items")
    require(all(isinstance(value, list) and len(value) == 100 for value in (rows, items, sql)),
            "All 100 original provider/publication/independent SQL rows are required")
    seen, selected = set(), []
    for index, (row, item, identity) in enumerate(zip(rows, items, sql)):
        require(all(isinstance(value, dict) for value in (row, item, identity)), "Malformed original source identity row")
        path = row.get("filePath", "")
        match = re.fullmatch(r"otzaria-book:([1-9][0-9]*)", path)
        require(match is not None and integer(row.get("segment")) and integer(row.get("id"), 0, 2 ** 64 - 1),
                "Unqualified original provider book/line/id")
        book, line = int(match[1]), row["segment"]
        stable = "otzaria:" + path + ":" + str(row["id"]) + ":" + str(line)
        require(stable not in seen, "Original provider page has a duplicate stable identity")
        seen.add(stable)
        require(row.get("reference") is None or isinstance(row.get("reference"), str), "Malformed original reference")
        reference = row.get("reference") or ""
        require(isinstance(row.get("title"), str) and row["title"] and isinstance(reference, str), "Missing original metadata")
        require(item.get("id") == stable and type(item.get("bookID")) is int and item["bookID"] == book
                and type(item.get("lineIndex")) is int and item["lineIndex"] == line
                and item.get("locator") == "otzaria|book:" + str(book) + "|line:" + str(line)
                and item.get("bookTitle") == row["title"] and item.get("reference") == reference,
                "Original publication differs from its provider row at index " + str(index))
        require(set(identity) == {"lineID", "bookID", "lineIndex", "bookTitle", "reference"}
                and integer(identity.get("lineID")) and type(identity.get("bookID")) is int and identity["bookID"] == book
                and type(identity.get("lineIndex")) is int and identity["lineIndex"] == line
                and identity.get("bookTitle") == row["title"] and identity.get("reference") == reference,
                "Original independent SQL identity differs at index " + str(index))
        selected.append({"pageIndex": index, "stableID": stable, "bookID": book, "focusLineIndex": line,
                         "locator": item["locator"], "providerRow": row, "publicationItem": item, "independentSQL": identity})
    return selected


def verify_sql_page(database, selected):
    require(len(selected) == 100, "Never verify only the chosen hit while ignoring the actual page")
    with contextlib.closing(sqlite3.connect(database.as_uri() + "?mode=ro&immutable=1", uri=True)) as connection:
        connection.execute("PRAGMA query_only=ON")
        require(connection.execute("PRAGMA query_only").fetchone() == (1,), "Source SQL connection must remain read-only")
        observed = []
        for item in selected:
            rows = connection.execute(SQL_IDENTITY, (item["bookID"], item["focusLineIndex"])).fetchall()
            require(len(rows) == 1, "Actual full corpus position is missing or ambiguous")
            row = dict(zip(("lineID", "bookID", "lineIndex", "bookTitle", "reference"), rows[0]))
            require(row == item["independentSQL"], "Original native page no longer matches independent immutable SQL")
            observed.append(row)
    return {"uri": database.as_uri() + "?mode=ro&immutable=1", "readOnly": True,
            "query": SQL_IDENTITY, "rows": observed, "rowsVerified": 100, "sqliteVersion": sqlite3.sqlite_version}


def hash_database(settings, database):
    before = settings.file_identity(database)
    require(before["bytes"] == V40_BYTES, "Actual complete corpus size is not production v40")
    value = hashlib.sha256()
    with database.open("rb") as stream:
        for chunk in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            value.update(chunk)
    require(settings.file_identity(database) == before and value.hexdigest() == V40_SHA,
            "Actual complete database changed or differs from the independent full-v40 hash")
    return {"database": {"path": str(database), "bytes": before["bytes"], "sha256": value.hexdigest()},
            "fileIdentityBefore": before, "fileIdentityAfter": settings.file_identity(database),
            "scope": "One fresh full-file hash with unchanged file identity; SQL corpus counts reused only from the exact-hash original admission"}


def validate_oracle(settings, path, selected, compile_receipt, snapshot):
    raw = settings.read_bytes(path, MAX_FILE)
    value = settings.decode_json(raw)
    require(isinstance(value, dict) and type(value.get("schema")) is int and value["schema"] == 1 and value.get("status") == ORACLE_STATUS
            and value.get("corpusProfile") == "full-v40" and value.get("databaseSHA256") == V40_SHA
            and type(value.get("uiExecuted")) is int and value["uiExecuted"] == 0
            and value.get("searchProviderExecuted") is False, "Do not turn source generation into UI or search acceptance")
    require(value.get("sourceServiceSHA256") == snapshot["files"][SERVICE]["sha256"]
            and value.get("presentationSourceSHA256") == snapshot["files"][PRESENTATION]["sha256"]
            and value.get("catalogCompileInputsSHA256") == compile_receipt["sha256"], "Oracle belongs to another actual source/compile closure")
    targets = value.get("targets")
    require(isinstance(targets, list) and len(targets) == 3
            and {item.get("unitMode") for item in targets} == {"line", "paragraph", "chapter"}, "Require exactly the three original modes")
    files = {}
    def check(target, *, root_target):
        require(target.get("bookID") == selected["bookID"] and integer(target.get("focusLineIndex"))
                and (not root_target or target["focusLineIndex"] == selected["focusLineIndex"]), "Original oracle target escaped the observed hit")
        require(target.get("bookTitle") == selected["independentSQL"]["bookTitle"], "Original canonical book title differs from the actual page")
        require(target.get("focusLocator") == "otzaria|book:" + str(target["bookID"]) + "|line:" + str(target["focusLineIndex"]), "Wrong original focused locator")
        anchors, text = target.get("anchors"), target.get("sourceUTF8")
        require(isinstance(text, str) and isinstance(anchors, list) and anchors
                and type(target.get("unitRowCount")) is int and target["unitRowCount"] == len(anchors)
                and target.get("allOriginalAnchorsChecked") == len(anchors)
                and target.get("sourceSHA256") == digest(text.encode())
                and target.get("sourceUTF8Bytes") == len(text.encode()) and target.get("sourceUTF16Length") == utf16(text),
                "Original complete unit source or all-anchor verification is incomplete")
        filename = target.get("sourceFile")
        require(isinstance(filename, str) and re.fullmatch(r"[0-9]+-(?:line|paragraph|chapter)-[0-9]+-[0-9]+\.source\.utf8", filename), "Source file escaped its candidate directory")
        require(integer(target.get("unitStartLineIndex")) and integer(target.get("unitEndLineIndex"))
                and target["unitStartLineIndex"] <= target["focusLineIndex"] <= target["unitEndLineIndex"]
                and anchors[0].get("lineIndex") == target["unitStartLineIndex"]
                and anchors[-1].get("lineIndex") == target["unitEndLineIndex"], "Original unit bounds differ from actual source anchors")
        source = settings.witness(path.parent / filename, MAX_FILE)
        require(source["bytes"] == len(text.encode()) and source["sha256"] == target["sourceSHA256"], "Complete source file differs from its unchanged Swift unit")
        files[source["path"]] = source
        seen, next_location = set(), 0
        source_utf16 = text.encode("utf-16-le")
        for anchor in anchors:
            require(integer(anchor.get("lineID")) and anchor["lineID"] not in seen
                    and anchor.get("bookID") == target["bookID"] and integer(anchor.get("lineIndex")), "Malformed/duplicate original anchor identity")
            seen.add(anchor["lineID"])
            original, preview = anchor.get("text"), anchor.get("previewPlainText")
            require(isinstance(original, str) and isinstance(preview, str)
                    and anchor.get("textSHA256") == digest(original.encode())
                    and anchor.get("previewPlainTextSHA256") == digest(preview.encode())
                    and anchor.get("previewUTF16Length") == utf16(preview)
                    and anchor.get("rangeLocation") == next_location and anchor.get("rangeLength") == utf16(original)
                    and anchor.get("segmentID") == "otzaria|book:" + str(target["bookID"]) + "|line:" + str(anchor["lineIndex"]),
                    "Original anchor source/presentation/range identity changed")
            start, end = next_location * 2, (next_location + utf16(original)) * 2
            require(source_utf16[start:end] == original.encode("utf-16-le"), "Anchor differs from the complete exact source slice")
            next_location += utf16(original) + 1
        require(next_location - 1 == utf16(text), "Last original anchor is not the actual complete source boundary")
        focused = [anchor for anchor in anchors if anchor["lineIndex"] == target["focusLineIndex"]]
        require(len(focused) == 1, "Original unit does not contain one unique actual focus anchor")
        if root_target:
            require(focused[0]["lineID"] == selected["independentSQL"]["lineID"]
                    and (focused[0].get("heRef") or "") == selected["independentSQL"]["reference"],
                    "Actual source focus does not match the selected original SQL row")
        rendered = target.get("backendReaderSourceUTF8")
        require(isinstance(rendered, str) and target.get("backendReaderSourceSHA256") == digest(rendered.encode())
                and target.get("backendReaderSourceUTF16Length") == utf16(rendered)
                and target.get("backendReaderMode") == "source", "Keep original Reader presentation separate from raw/preview source")
        toc = target.get("tocSelection")
        require(isinstance(toc, dict) and toc.get("schema") == 1 and isinstance(toc.get("headings"), list)
                and toc["headings"] and integer(toc.get("allTOCRowsChecked"), 1)
                and re.fullmatch(r"[a-f0-9]{64}", toc.get("tocSQLRowsSHA256", "")), "Original native-navigation TOC oracle is missing")
        neighbors = target.get("neighbors", {})
        require(isinstance(neighbors, dict) and set(neighbors) <= {"previous", "next"}, "Unexpected original neighbor scope")
        require(root_target or not neighbors, "The unchanged original catalog has only one neighbor level")
        for neighbor in neighbors.values():
            require(neighbor.get("unitMode") == target["unitMode"], "A neighbor changed original mode")
            check(neighbor, root_target=False)
    for target in targets:
        check(target, root_target=True)
    modes = {item["unitMode"]: item for item in targets}
    line, paragraph, chapter = (modes[name] for name in ("line", "paragraph", "chapter"))
    focus = [item for item in line["anchors"] if item["lineIndex"] == selected["focusLineIndex"]]
    require(len(focus) == 1, "The chosen actual line has no unique original focused anchor")
    reasons = []
    def eligible(condition, reason):
        if not condition:
            reasons.append(reason)
    eligible(selected["focusLineIndex"] > 0, "Actual hit is line zero; original F08 requires a nonzero source line")
    eligible(line["unitRowCount"] == 1 and paragraph["unitRowCount"] > 1
             and chapter["unitRowCount"] > paragraph["unitRowCount"], "Original complete line/paragraph/chapter sizes are not distinct")
    eligible(line["backendReaderSourceUTF16Length"] <= 2048, "Complete original line Reader body exceeds the native selection limit")
    eligible(bool(focus[0]["previewPlainText"]) and utf16(focus[0]["previewPlainText"]) <= 2048
             and "\n" not in focus[0]["previewPlainText"], "Original focused preview anchor cannot satisfy the exact native descendant contract")
    eligible(set(line.get("neighbors", {})) == {"previous", "next"}, "Original line has no two-way neighbor units")
    for name in ("paragraph", "chapter"):
        eligible("previous" in modes[name].get("neighbors", {}), "Original " + name + " has no previous unit")
    previous = chapter.get("neighbors", {}).get("previous")
    if previous:
        eligible(previous["tocSelection"]["canonicalLocator"] != chapter["tocSelection"]["canonicalLocator"],
                 "Previous original chapter has the same canonical selected TOC anchor")
    eligible(len(raw) <= MAX_ORACLE, "Complete original oracle exceeds the existing controller input bound; it was not truncated")
    return value, reasons, list(files.values())


def output_bytes(directory):
    paths = list(directory.rglob("*"))
    require(len(paths) <= 2000 and not any(path.is_symlink() for path in paths), "Output inventory escaped its bounded original attempt")
    return sum(path.stat().st_size for path in paths if path.is_file())


def original_source_limits():
    # A limit violation fails the entire actual-source execution. A partial
    # file is retained as failed evidence, never admitted as a complete unit.
    import resource
    resource.setrlimit(resource.RLIMIT_FSIZE, (MAX_FILE, MAX_FILE))


def produce(args):
    require(sys.platform == "darwin", "Execution uses the original retained Apple corpus and actual build/SDK admission")
    settings = load_module(ROOT, "Scripts/CI/study-ui-settings-receipts.py")
    output = settings.evidence_output(args.output, ROOT)
    require(not output.exists(), "Use a fresh owned output directory")
    output.mkdir()
    report = {"schema": "otzaria.original-search-preview-oracle-producer/1", "status": "STARTED_NOT_ACCEPTED",
              "nativeUIExecuted": 0, "searchProviderExecuted": False, "appStateWrites": 0,
              "requestedHitIndex": args.hit_index, "attempts": [], "runtimeRequirements": RUNTIME_REQUIREMENTS,
              "startedAtUnix": time.time()}
    failure = None
    try:
        require(integer(args.reserved_other_bytes), "Declare current concurrent storage reservation")
        require(shutil.disk_usage(ROOT).free >= OUTPUT_BUDGET + args.reserved_other_bytes,
                "Original complete candidate outputs and concurrent storage reservation do not fit")
        snapshot, config = source_snapshot(ROOT, settings, frozen=True)
        report["source"] = snapshot
        driver = load_module(ROOT, "Scripts/CI/production-study-v40-ui.py")
        retained, core = driver.load_core()
        core.OUT = output
        context = driver.source_context(core, "preview-hit", True)
        require(context["study_ui_execution_sources"].get(SELF) == snapshot["files"][SELF],
                "Integration owner must freeze this producer in the original study execution closure")
        _, _, build = core.build_identity(context)
        report.update(sourceContext=context, currentBuild=build)
        original = settings.read_json(args.installation_result)
        runtime = original.get("runtime")
        require(isinstance(runtime, dict) and runtime.get("identifier") == os.environ.get("FAITHFUL_RUNTIME27_IDENTIFIER"),
                "The explicit original runtime must match the retained installation")
        current = [row for row in core.json_command(["xcrun", "simctl", "list", "runtimes", "available", "-j"])["runtimes"]
                   if row.get("isAvailable") and row.get("identifier") == runtime["identifier"]]
        require(len(current) == 1 and all(current[0].get(key) == runtime.get(key) for key in ("identifier", "version", "buildversion")),
                "The actual retained runtime changed")
        sdk_version = core.command(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"]).stdout.strip()
        require(current[0]["version"].split(".")[:2] == sdk_version.split(".")[:2]
                and current[0]["version"].split(".")[0] == "27", "Original runtime does not match the actual qualified Apple SDK")
        types = [row for row in current[0]["supportedDeviceTypes"] if "iPad Pro" in row["name"] and "13-inch" in row["name"]]
        owner = retained.RetainedV40Installation(core, args.owned_simulator, args.installation_result)
        udid, _, ownership = owner.admit_owner(config, current[0], types)
        report.update(ownership)
        phase_record, phase = driver.verified_phase(core, settings, args.preview_phase_result,
                                                   "preview-hit", udid, build, owner.prior["result"])
        gates = load_module(ROOT, "Scripts/CI/study-ui-prerequisites.py")
        evidence = gates.Evidence(core=core, settings=settings, udid=udid, source=context, build=build,
                                  installation_result=owner.prior["result"])
        phase_proof = evidence.study_phase(phase_record, phase, "preview-hit", [CASE.split("/", 1)[1]])
        case_directory = Path(phase["case_results"][0]["case_directory"])
        attachment = settings.selected_attachment(case_directory / "captures", CASE, udid, ATTACHMENT)
        selected = actual_page(attachment["contents"])
        report.update(previewPhase=phase_record, phaseProof=phase_proof,
                      selectedPageAttachment={key: value for key, value in attachment.items() if key != "contents"})
        copied = output / "original-selected-page.json"
        with copied.open("xb") as stream:
            stream.write(settings.verify_witness(attachment["file"]))
        report["retainedRawAttachment"] = settings.witness(copied)
        database, relocation = owner.current_database(udid)
        actual_owner = driver.actual_owner(core, settings, udid)
        require(database == Path(actual_owner["storageRoot"]) / "Otzaria/seforim.db", "Actual MCM owner and original installer corpus differ")
        database_identity = hash_database(settings, database)
        require(phase["installation_before"]["counts"] == V40_COUNTS, "Original exact-hash native counts differ")
        database_identity.update(counts=V40_COUNTS, countsOriginalReceipt=phase_record,
                                 installationManifest=settings.raw_manifest(database.parent / "seforim-installation.json"))
        report.update(databaseAdmission=database_identity, actualOwner=actual_owner, relocation=relocation)
        sql = verify_sql_page(database, selected)
        report["independentSQL"] = settings.write_new(output / "actual-100-row-sql-identity.json", sql)
        compiled, executable = compile_catalog(ROOT, settings, snapshot, config, output / "source-compile", args.module_cache)
        report.update(compileInputs=compiled, nativeExecutable=executable)
        indices = [args.hit_index] if args.hit_index is not None else list(range(MAX_ATTEMPTS))
        require(all(integer(index, 0, 99) for index in indices), "Choose an index from the actual retained first page")
        candidates = output / "candidates"
        candidates.mkdir()
        selected_output = None
        for index in indices:
            require(time.time() - report["startedAtUnix"] <= MAX_SECONDS, "Source generation exceeded its bounded actual-page budget")
            # At most nine unique complete source files, one oracle and one
            # execution log come from three modes and one-level neighbors.
            require(output_bytes(output) + 11 * MAX_FILE <= OUTPUT_BUDGET,
                    "Retained complete attempts reached the declared output budget; do not delete or truncate evidence")
            require(shutil.disk_usage(ROOT).free >= args.reserved_other_bytes + 11 * MAX_FILE,
                    "Stop before consuming another owner's reserved storage")
            item = selected[index]
            attempt = {"pageIndex": index, "selectedOriginalHit": item, "status": "STARTED_NOT_ACCEPTED"}
            report["attempts"].append(attempt)
            if item["focusLineIndex"] == 0:
                attempt.update(status="INELIGIBLE_ORIGINAL_HIT", reasons=["Original F08 requires a nonzero source line"])
                continue
            directory = candidates / str(index).zfill(3)
            directory.mkdir()
            catalog_input = {"databaseURI": sql["uri"], "databaseSHA256": V40_SHA, "v40Targets": config["catalog_targets"],
                             "previewTargets": [{"bookID": item["bookID"], "focusLineIndex": item["focusLineIndex"], "mode": mode}
                                                for mode in ("line", "paragraph", "chapter")], "readerNavigationOracle": True}
            for key, relative in (("sourceService", SERVICE), ("presentationSource", PRESENTATION)):
                catalog_input[key] = {"path": str(ROOT / relative), "sha256": snapshot["files"][relative]["sha256"],
                                      "compileInputsPath": compiled["path"]}
            attempt["input"] = settings.write_new(directory / "input.json", catalog_input)
            settings.verify_witness(executable["binary"], MAX_FILE)
            command = [executable["binary"]["path"], attempt["input"]["path"], str(directory)]
            attempt["command"] = command
            with (directory / "execution.log").open("xb") as stream:
                result = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT, timeout=120,
                                        check=False, preexec_fn=original_source_limits)
            attempt["exit"] = result.returncode
            attempt["log"] = settings.witness(directory / "execution.log", MAX_FILE)
            require(result.returncode == 0, "Original Swift source execution failed at actual page index " + str(index)
                    + "; this is not an eligibility skip or a passing oracle")
            path = directory / "preview-targets.json"
            _, reasons, full_sources = validate_oracle(settings, path, item, compiled, snapshot)
            attempt.update(oracle=settings.witness(path, MAX_FILE), fullSourceFiles=full_sources,
                           reasons=reasons, status="INELIGIBLE_ORIGINAL_HIT" if reasons else "SOURCE_QUALIFIED_ACTUAL_HIT")
            settings.write_new(directory / "ATTEMPT.json", attempt)
            if not reasons:
                selected_output = attempt
                break
        require(selected_output is not None, "No inspected actual first-page hit met the unchanged source/UI eligibility contract")
        settings.verify_witness(attachment["file"])
        evidence.reverify_files()
        owner.verify_prior_receipts()
        require(driver.actual_owner(core, settings, udid) == actual_owner
                and settings.file_identity(database) == database_identity["fileIdentityAfter"]
                and settings.raw_manifest(database.parent / "seforim-installation.json") == database_identity["installationManifest"],
                "Original owner or full source changed during source generation")
        owner.require_test_runner = True
        report["currentInstalledImages"] = owner.verify_installed_images(udid, build)
        devices = core.json_command(["xcrun", "simctl", "list", "devices", "-j"])["devices"]
        unchanged_device = [row for rows in devices.values() for row in rows if row.get("udid") == udid]
        require(len(unchanged_device) == 1 and unchanged_device[0].get("state") == "Shutdown",
                "Read-only source generation must leave the owned Simulator shut down")
        report["readOnlySimulatorStateAfter"] = unchanged_device[0]
        require(driver.source_context(core, "preview-hit", True) == context and core.build_identity(context)[2] == build
                and source_snapshot(ROOT, settings, frozen=True)[0] == snapshot, "Source/build closure changed during source generation")
        oracle = selected_output["oracle"]
        runner = {"PRODUCTION_SEARCH_PREVIEW_ORACLE": oracle["path"], "PRODUCTION_SEARCH_PREVIEW_ORACLE_SHA256": oracle["sha256"],
                  "PRODUCTION_SEARCH_PREVIEW_SERVICE_SHA256": snapshot["files"][SERVICE]["sha256"],
                  "PRODUCTION_SEARCH_PREVIEW_PRESENTATION_SHA256": snapshot["files"][PRESENTATION]["sha256"],
                  "PRODUCTION_SEARCH_PREVIEW_COMPILE_SHA256": compiled["sha256"]}
        report["runnerInputs"] = settings.write_new(output / "runner-inputs.json", runner)
        report.update(status="ACTUAL_PASSED_PAGE_ORIGINAL_SOURCE_ORACLE_READY_NOT_PREVIEW_UI_ACCEPTANCE",
                      selectedActualHit=selected_output["selectedOriginalHit"], oracle=oracle,
                      actualPageNativeScope="Prior qualified first-page source-selection case only; this producer executes no native case")
    except BaseException as error:
        failure = error
        report.update(status="FAILED_OR_INCOMPLETE_NO_ORACLE_ACCEPTANCE", errorType=type(error).__name__, error=str(error))
    finally:
        report["finishedAtUnix"] = time.time()
        settings.write_new(output / "RESULT.json", report)
    if failure is not None:
        raise failure
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=["source-check", "execute"])
    parser.add_argument("--preview-phase-result", type=Path)
    parser.add_argument("--owned-simulator")
    parser.add_argument("--installation-result", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--hit-index", type=int)
    parser.add_argument("--reserved-other-bytes", type=int)
    parser.add_argument("--compile", action="store_true", help="Source-check only: compile exact original Swift, never run it on a corpus")
    parser.add_argument("--module-cache", type=Path)
    args = parser.parse_args()
    if args.operation == "source-check":
        require(not args.preview_phase_result and not args.owned_simulator and not args.installation_result
                and args.hit_index is None and args.reserved_other_bytes is None,
                "Source-check does not admit any native phase, owner, corpus or selected hit")
        settings = load_module(ROOT, "Scripts/CI/study-ui-settings-receipts.py")
        snapshot, config = source_snapshot(ROOT, settings, frozen=False)
        report = {"status": "SOURCE_CHECK_ONLY_NOT_NATIVE_OR_CORPUS_EXECUTION", "source": snapshot,
                  "nativeUIExecuted": 0, "searchProviderExecuted": False, "databaseReads": 0}
        require(not args.compile or args.output is not None, "Compile-only check needs a fresh retained output directory")
        path = None
        if args.output is not None:
            path = settings.evidence_output(args.output, ROOT)
            require(not path.exists(), "Keep prior source controls; choose a fresh output")
            path.mkdir()
        if args.compile:
            receipt, executable = compile_catalog(ROOT, settings, snapshot, config, path / "source-compile", args.module_cache)
            report.update(compileInputs=receipt, nativeExecutable=executable)
        if path is not None:
            settings.write_new(path / "RESULT.json", report)
        print(json.dumps(report, ensure_ascii=False, indent=2))
        return
    require(not args.compile, "Execute always records its own genuine current-source compile")
    require(args.preview_phase_result and args.owned_simulator and args.installation_result and args.output,
            "Actual passed preview-hit phase, exact owned install/UDID and fresh output are mandatory")
    canonical_uuid(args.owned_simulator)
    report = produce(args)
    print(json.dumps({"status": report["status"], "oracle": report["oracle"], "runnerInputs": report["runnerInputs"]}, indent=2))


if __name__ == "__main__":
    main()

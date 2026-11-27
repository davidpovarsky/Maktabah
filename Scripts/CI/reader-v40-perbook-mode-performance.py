#!/usr/bin/env python3
"""Nine source-qualified v40 Reader cells; candidate observations, not a SLA.

The original v32 host, original two v40 cases and application sources stay
unchanged. Each cell uses six actual process-cold/warm pairs and one continuous
Apple trace. All source/TOC/defaults inspection happens after resource end ACK.
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
import shutil
import stat
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
SCHEMA = "otzaria.full-v40.per-book-mode-measurements/1"
STATUS = "ORIGINAL_FULL_V40_PER_BOOK_MODE_UI_MEASUREMENTS_RETAINED_METRICS_REVIEW_REQUIRED"
CATALOG_STATUS = "ORIGINAL_SOURCE_READER_MODE_MATRIX_ONLY_NOT_UI_OR_PERFORMANCE"
DB_SHA = "8389709c1702753af6f0719ef1c98c09854450e48ebb05fe1f95486b26348b01"
BOOKS = [(103, "Berakhot", 2875), (28, "Tehillim", 2678), (3152, "DerashotHaRan", 528)]
MODES = ["line", "paragraph", "chapter"]
POSITIONS = ["first", "middle", "last"]
ORDER = ["first", "middle", "last", "last", "middle", "first"]
CELLS = [(book, mode, "FaithfulProductionReleaseTests/testFullV40" + name + mode.title() + "ColdWarmMeasurements")
         for book, name, _ in BOOKS for mode in MODES]
CATALOG_SOURCE = "docs/hq-integration/wave2-20261127/reader/FullV40ObservationCatalog.swift"
EXTRA_SOURCES = [
    "Scripts/CI/reader-v40-perbook-mode-performance.py", CATALOG_SOURCE,
    "Scripts/CI/production-study-v40-ui.py", "Scripts/CI/study-ui-settings-receipts.py",
    "Scripts/CI/reader-full-v40-ui-observation.py", "Scripts/CI/reader-full-v32-ui-observation.py",
    "Scripts/CI/runtime27_interruption.py", "Scripts/CI/runtime27-url-delivery.py",
    "Maktabah-iOSUITests/FaithfulReaderUIAcceptanceTests.swift",
    "Source/Otzaria/App/OtzariaAppContainer.swift", "Source/Features/Reader/iOS/Toolbar/TOCNodeRow.swift",
]
MISSING = {
    "first_pixel": "Original Core/glyph-visible receipt polling is an upper bound including transport; not exact first pixel.",
    "longest_main_thread_slice": "The retained Time Profiler trace still needs the genuine schema/clock/thread-state producer.",
    "main_actor_occupancy": "A source label, elapsed fetch duration or suspended task is not MainActor running time.",
    "layout_hitches_fps": "No invented table names, frame attribution, FPS or hitch threshold; actual trace qualification is pending.",
    "continuous_peak_memory": "Darwin sampled RSS is observed separately from phys_footprint and a continuous peak.",
    "sqlite_lock_wait_for_this_matrix": "Separate original full-v40/pending-SQL collectors own qualified wait observations; their admission is not copied here.",
    "before_after": "A second independently qualified build with this exact workload is required; no Windows/source-control baseline transfer.",
}


def require(value, message):
    if not value:
        raise ValueError(message)


def number(value, minimum=0):
    return type(value) in (int, float) and math.isfinite(value) and value >= minimum


def uuid_string(value):
    require(isinstance(value, str) and str(uuid.UUID(value)).upper() == value, "Canonical actual UUID required")
    return value


def support(name):
    path = ROOT / "Scripts/CI" / name
    spec = importlib.util.spec_from_file_location("perf01_" + name.replace("-", "_"), path)
    require(spec is not None and spec.loader is not None, "Original support module missing")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def source_context(core, frozen):
    context = core.source_context(require_frozen=frozen)
    records = {}
    for name in EXTRA_SOURCES:
        path = ROOT / name
        require(path.is_file() and not path.is_symlink() and path.stat().st_size <= 2 * 1024 * 1024,
                "Current bounded original measurement source missing: " + name)
        if frozen:
            require(core.command(["git", "hash-object", str(path)]).stdout.strip() == core.git("rev-parse", "HEAD:" + name),
                    "Measurement source is dirty: " + name)
        records[name] = core.witness(path)
    declarations = (ROOT / "Maktabah-iOSUITests/FaithfulReaderUIAcceptanceTests.swift").read_text()
    for _, _, case in CELLS:
        require(len(re.findall(r"\bfunc\s+" + case.split("/")[1] + r"\s*\(", declarations)) == 1,
                "Exactly one registered measurement selector required: " + case)
    context.update(perf01_execution_sources=records, selected_measurement_cases=[v[2] for v in CELLS],
        scope="Separate nine per-book/mode cases; no original twenty-open, full-v32, Native116 or full-PERF completion credit")
    return context


def admit_catalog(value):
    require(isinstance(value, dict) and value.get("schema") == 1 and value.get("status") == CATALOG_STATUS
            and value.get("corpusProfile") == "full-v40" and value.get("databaseSHA256") == DB_SHA
            and value.get("uiExecuted") == 0 and value.get("performanceObserved") is False
            and value.get("searchProviderExecuted") is False,
            "Independent original mode-matrix source output required")
    for key in ("sourceServiceSHA256", "presentationSourceSHA256", "catalogCompileInputsSHA256"):
        require(isinstance(value.get(key), str) and re.fullmatch(r"[a-f0-9]{64}", value[key]), "Missing real source digest: " + key)
    rows = value.get("targets")
    require(isinstance(rows, list) and len(rows) == 27 and len({v.get("key") for v in rows}) == 27,
            "All twenty-seven complete independent source targets required")
    for book, _, count in BOOKS:
        for mode in MODES:
            targets = [r for r in rows if r.get("bookID") == book and r.get("unitMode") == mode]
            require([r.get("matrixPosition") for r in targets] == POSITIONS, "Wrong actual first/middle/last cell")
            require(len({r.get("focusLineIndex") for r in targets}) == 3, "Distinct actual source positions required")
            for row in targets:
                require(row.get("bookLineCount") == count and row.get("key") == str(book) + "-perf01-" + mode + "-" + row["matrixPosition"]
                        and isinstance(row.get("bookTitle"), str) and row["bookTitle"]
                        and type(row.get("unitRowCount")) is int and row["unitRowCount"] > 0
                        and row.get("allOriginalAnchorsChecked") == row["unitRowCount"]
                        and all(type(row.get(k)) is int and row[k] >= 0 for k in ("unitStartLineIndex", "unitEndLineIndex", "focusLineIndex"))
                        and row["unitStartLineIndex"] <= row["focusLineIndex"] <= row["unitEndLineIndex"]
                        and row.get("sectionLocator") == "otzaria|book:" + str(book) + "|line:" + str(row["unitStartLineIndex"])
                        and row.get("focusLocator") == "otzaria|book:" + str(book) + "|line:" + str(row["focusLineIndex"]),
                        "The exact original unit/anchor/canonical identities differ")
                toc = row.get("tocSelection", {})
                require(toc.get("schema") == 1 and type(toc.get("sourceLineIndex")) is int
                        and 0 <= toc["sourceLineIndex"] <= row["unitStartLineIndex"]
                        and toc.get("canonicalLocator") == "otzaria|book:" + str(book) + "|line:" + str(toc["sourceLineIndex"])
                        and type(toc.get("allTOCRowsChecked")) is int and toc["allTOCRowsChecked"] > 0
                        and re.fullmatch(r"[a-f0-9]{64}", toc.get("tocSQLRowsSHA256", ""))
                        and isinstance(toc.get("headings"), list) and toc["headings"]
                        and all(r.get("sourceLineIndex") == toc["sourceLineIndex"] and isinstance(r.get("title"), str) for r in toc["headings"]),
                        "The actual complete SQL TOC binding is absent")
                require(isinstance(row.get("sourceFile"), str) and Path(row["sourceFile"]).name == row["sourceFile"]
                        and type(row.get("sourceUTF8Bytes")) is int and 0 < row["sourceUTF8Bytes"] <= 32 * 1024 * 1024
                        and type(row.get("sourceUTF16Length")) is int and row["sourceUTF16Length"] > 0
                        and re.fullmatch(r"[a-f0-9]{64}", row.get("sourceSHA256", "")), "A complete nonempty raw source file is required")
    return rows


def compile_original_catalog(core, config, directory):
    """Existing empty owned directory -> one exact original-source executable.

    This shared measurement seam compiles only. It never opens a corpus or
    chooses preview/PERF/pending-SQL targets. The caller records its own genuine
    input, execution exit and output, without fabricating a provider hit.
    """
    require(directory.is_dir() and directory.resolve(strict=True) == directory
            and not directory.is_symlink() and not any(directory.iterdir()), "A fresh empty canonical compiler directory is required")
    swiftc = core.command(["xcrun", "--sdk", "macosx", "--find", "swiftc"]).stdout.strip()
    sdk = core.command(["xcrun", "--sdk", "macosx", "--show-sdk-path"]).stdout.strip()
    zstd = (Path(core.command(["brew", "--prefix", "zstd"]).stdout.strip()) / "lib/libzstd.dylib").resolve(strict=True)
    binary = directory / "original-source-catalog"
    sources = config["catalog_compiled_sources"]
    require(len(sources) == len(set(sources)) and "Source/Otzaria/Reading/OtzariaReadingUnitService.swift" in sources
            and "Source/LibraryBackend/LibraryBackendModels.swift" in sources, "Complete original service/presentation source inputs required")
    args = [swiftc, "-parse-as-library", "-swift-version", "6", "-Xfrontend", "-strict-concurrency=complete", "-O",
            "-sdk", sdk, "-module-cache-path", str(directory / "module-cache"),
            "-L", str(zstd.parent), "-lzstd", "-Xlinker", "-rpath", "-Xlinker", str(zstd.parent),
            *[str(ROOT / p) for p in sources], str(ROOT / CATALOG_SOURCE), "-o", str(binary)]
    compile_path = directory / "compile-inputs.json"
    core.write(compile_path, {"command": args, "swiftc": core.witness(swiftc), "zstd": core.witness(zstd),
        "source_sha256": {p: core.digest(ROOT / p) for p in [*sources, CATALOG_SOURCE]}})
    code = core.bounded(args, directory / "compile.log", 300)
    core.write(directory / "compile-result.json", {"exit": code, "inputs": core.witness(compile_path),
        "log": core.witness(directory / "compile.log") if (directory / "compile.log").is_file() else None,
        "scope": "Actual original-source compiler only; no corpus, UI or performance execution"})
    require(code == 0, "Actual original-source catalog Apple compile failed")
    identity = lambda p: {"path": str(ROOT / p), "sha256": core.digest(ROOT / p), "compileInputsPath": str(compile_path)}
    return {"binary": core.witness(binary), "compileInputs": core.witness(compile_path),
        "compileResult": core.witness(directory / "compile-result.json"),
        "sourceService": identity("Source/Otzaria/Reading/OtzariaReadingUnitService.swift"),
        "presentationSource": identity("Source/LibraryBackend/LibraryBackendModels.swift")}


def prepare_catalog(core, config, installation, directory):
    """Compile the unchanged actual sources once; only the optional output varies."""
    directory.mkdir()
    compiled = compile_original_catalog(core, config, directory)
    binary = Path(compiled["binary"]["path"])
    compile_path = Path(compiled["compileInputs"]["path"])
    catalog_input = {"databaseURI": installation["uri"], "databaseSHA256": installation["database"]["sha256"],
        "v40Targets": config["catalog_targets"], "readerModeMatrix": True,
        "sourceService": compiled["sourceService"], "presentationSource": compiled["presentationSource"]}
    core.write(directory / "input.json", catalog_input)
    code = core.bounded([str(binary), str(directory / "input.json"), str(directory)], directory / "execution.log", 600)
    core.write(directory / "execution-result.json", {"exit": code, "compiled": compiled,
        "input": core.witness(directory / "input.json"), "scope": "Actual original service source oracle; not native UI/performance"})
    require(code == 0, "Actual original service did not generate every complete mode target")
    value = core.bounded_json(directory / "reader-mode-matrix.json", 1024 * 1024)
    rows = admit_catalog(value)
    require(value["catalogCompileInputsSHA256"] == core.digest(compile_path), "Actual catalog compile receipt changed")
    unique = {}
    for row in rows:
        path = directory / row["sourceFile"]
        require(not path.is_symlink() and path.resolve(strict=True).parent == directory, "Original source file escaped its own catalog")
        if row["sourceFile"] not in unique:
            data = core.bounded_read(path, 32 * 1024 * 1024)
            unique[row["sourceFile"]] = (len(data), hashlib.sha256(data).hexdigest(), len(data.decode("utf-8").encode("utf-16-le")) // 2)
        require(unique[row["sourceFile"]] == (row["sourceUTF8Bytes"], row["sourceSHA256"], row["sourceUTF16Length"]),
                "Whole original unit bytes/UTF16 changed; no prefix is allowed")
    require(sum(v[0] for v in unique.values()) <= 128 * 1024 * 1024, "Complete source oracle exceeds its admitted byte reservation")
    core.write(directory / "native-executable.json", {"binary": core.witness(binary),
        "linkage": core.command(["otool", "-L", str(binary)]).stdout,
        "scope": "Actual original Swift source execution only; native Reader still requires independent execution"})
    return value


def validate_cell(request, *, book, mode, catalog, catalog_sha, epochs, proofs, mode_proofs):
    """Validate existing real records without a fake twenty-open completion."""
    targets = {r["key"]: r for r in admit_catalog(catalog)}
    require(request.get("bookID") == book and request.get("unitMode") == mode and request.get("catalogSHA256") == catalog_sha,
            "Cell source identity changed")
    rows, pairs = request.get("observations"), request.get("pairs")
    require(isinstance(rows, list) and len(rows) == 12 and isinstance(pairs, list) and len(pairs) == 6,
            "All six actual cold/warm pairs must complete; no failed observations may disappear")
    require(len(epochs) == 24 and len(proofs) == 30 and len(mode_proofs) == 31, "Complete exact source/resource/mode schedule required")
    proof_map = {p["request_id"]: p for p in proofs}
    require(len(proof_map) == len(proofs), "Original source request UUID reused")
    used_sources, used_modes, used_epochs, cold_pids = set(), set(), set(), set()
    active_document = active_group = None

    def source(identifier, target_key, pid):
        uuid_string(identifier)
        require(identifier not in used_sources, "One original source sample cannot stand in for another operation")
        used_sources.add(identifier)
        p = proof_map.get(identifier, {})
        require(p.get("target_key") == target_key and p.get("native_process_id") == pid
                and p.get("post_resource_epoch") is True, "Fresh actual source/PID/target comparison missing")
        uuid_string(p.get("actual_workspace_document_id")); uuid_string(p.get("actual_workspace_group_id"))
        return p

    def mode_record(identifier, pid, stage):
        uuid_string(identifier)
        require(identifier not in used_modes, "Original mode observation cannot be reused")
        used_modes.add(identifier)
        p = mode_proofs.get(identifier, {})
        require(p.get("processID") == pid and p.get("unitMode") == mode and p.get("stage") == stage
                and p.get("status") == "ORIGINAL_PERSISTED_READER_MODE_OBSERVED",
                "Original persisted mode does not match this exact native process/stage")

    selected = [v for v in mode_proofs.values() if v.get("stage") == "selected"]
    require(len(selected) == 1 and selected[0].get("unitMode") == mode, "The original menu selection is absent")
    used_modes.add(selected[0]["proofID"])
    for i, position in enumerate(ORDER):
        pair = pairs[i]
        key = str(book) + "-perf01-" + mode + "-" + position
        target = targets[key]
        before_pid, pid = pair.get("beforeProcessID"), pair.get("afterProcessID")
        require(pair.get("pairIndex") == i + 1 and pair.get("targetKey") == key
                and type(pid) is int and type(before_pid) is int and pid > 1 and before_pid > 1
                and pid != before_pid and pid not in cold_pids, "A process-cold pair needs a genuinely new unique PID")
        cold_pids.add(pid)
        away = targets.get(pair.get("awayTargetKey"), {})
        require(away.get("bookID") != book and away.get("unitMode") == mode and away.get("matrixPosition") == "first",
                "A real other-book source must be active before cold launch and warm return")
        before = source(pair["beforeColdSourceID"], away["key"], before_pid)
        after = source(pair["afterColdSourceID"], away["key"], pid)
        warm_away = source(pair["warmAwaySourceID"], away["key"], pid)
        require(before.get("native_core_receipt_present") is True and warm_away.get("native_core_receipt_present") is True
                and after.get("native_core_receipt_present") is False,
                "Cold launch must restore the actual away document; warm preparation must issue a real route")
        for p in (before, after, warm_away):
            require(p["actual_workspace_document_id"] == pair.get("workspaceDocumentID")
                    and p["actual_workspace_group_id"] == pair.get("workspaceGroupID"), "Actual document/group changed across the pair")
        if active_document is None:
            active_document, active_group = pair["workspaceDocumentID"], pair["workspaceGroupID"]
        require(pair["workspaceDocumentID"] == active_document and pair["workspaceGroupID"] == active_group,
                "Same-tab measurement must retain its actual ordinary document/group")
        mode_record(pair["beforeModeProofID"], before_pid, "before-cold")
        mode_record(pair["afterModeProofID"], pid, "after-cold")
        mode_record(pair["warmModeProofID"], pid, "warm-ready")
        for j, temperature in enumerate(("process-cold", "warm")):
            row = rows[i * 2 + j]
            require(row.get("pairIndex") == i + 1 and row.get("targetKey") == key and row.get("mode") == temperature
                    and row.get("bookID") == book and row.get("unitMode") == mode and row.get("matrixPosition") == position
                    and row.get("processID") == pid, "Cold/warm observations are missing or reordered")
            epoch_id = uuid_string(row.get("epoch")); epoch = epochs.get(epoch_id, {})
            interaction = row.get("firstInteraction", {}); overview_id = uuid_string(interaction.get("epoch"))
            overview = epochs.get(overview_id, {})
            require(epoch_id not in used_epochs and overview_id not in used_epochs and epoch_id != overview_id, "Duplicate original resource epoch")
            used_epochs.update((epoch_id, overview_id))
            for value, kind in ((epoch, "reader-open"), (overview, "reader-overview")):
                require(value.get("status") == "OBSERVED_NOT_PERFORMANCE_ACCEPTANCE" and value.get("kind") == kind
                        and value.get("processID") == pid and value.get("target_key") == key and value.get("mode") == temperature
                        and number(value.get("app_cpu_seconds")) and number(value.get("sampled_max_rss_bytes"), 1),
                        "A failed, foreign or unmatched epoch cannot enter measurements")
            p = source(row["sourceObservationID"], key, pid)
            route = row.get("route", {})
            require(p.get("epoch") == epoch_id and p.get("native_core_receipt_present") is True
                    and p.get("native_core_request_id") == route.get("receiptFields", {}).get("request")
                    and p.get("route_visibility_upper_bound_seconds") == route.get("requestToNativeVisibleUpperBoundSeconds")
                    and number(route.get("requestToNativeVisibleUpperBoundSeconds"))
                    and p["actual_workspace_document_id"] == active_document and p["actual_workspace_group_id"] == active_group,
                    "Every measured open must bind its authentic source, actual current document and original glyph receipt")
            require(number(overview.get("resource_start_host_monotonic")) and number(epoch.get("resource_end_host_monotonic"))
                    and overview["resource_start_host_monotonic"] >= epoch["resource_end_host_monotonic"]
                    and interaction.get("actualOverviewIdentifier") == "study-groups-overview"
                    and interaction.get("actualDocumentID") == active_document
                    and interaction.get("actualCardIdentifier") in ("tab-switcher-grid-cell-" + active_document, "tab-switcher-list-cell-" + active_document),
                    "Original post-open overview identity/resource chronology changed")
            start, action, end = [interaction.get(k) for k in ("observationStartedUptime", "nativeActionRequestedUptime", "originalOverviewObservedUptime")]
            require(all(number(v) for v in (start, action, end)) and start <= action <= end
                    and interaction.get("requestToOriginalOverviewUpperBoundSeconds") == end - start
                    and interaction.get("nativeActionToOverviewUpperBoundSeconds") == end - action,
                    "Original overview timing is not an actual monotonic interval")
            mode_record(row["modeProofID"], pid, "post-open")
            toc, expected = row.get("tocEvidence", {}), target["tocSelection"]
            visible = toc.get("originalSelectedRows")
            require(all(toc.get(k) == expected[k] for k in ("canonicalLocator", "sourceLineIndex", "tocSQLRowsSHA256"))
                    and isinstance(visible, list) and visible
                    and all(v.get("identifier") == "toc-row-" + str(expected["sourceLineIndex"])
                            and v.get("selected") is True and v.get("value") == "selected"
                            and v.get("label") in {h["title"] for h in expected["headings"]} for v in visible),
                    "Original native-unit TOC identity/selection differs from the full SQL oracle")
    require(used_sources == set(proof_map) and used_modes == set(mode_proofs) and used_epochs == set(epochs),
            "Every actual source/mode/resource observation must appear in the completed workload")
    return {"observations": rows, "pairs": pairs, "actualOpens": 12, "actualColdWarmPairs": 6,
        "bookID": book, "unitMode": mode, "catalogSHA256": catalog_sha,
        "scope": "Process-cold means a new app PID with the other book visibly restored; no OS/disk-cache or unobserved internal-cache coldness claim"}


def observation_host(previous_host, core, book, mode, catalog_sha):
    class PerBookModeHost(previous_host):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, **kwargs)
            self.cell_complete, self.mode_proofs = None, {}

        def environment(self):
            values = super().environment()
            values.update(TEST_RUNNER_PERF01_READER_CATALOG_FILE=str(self.catalog_dir / "reader-mode-matrix.json"),
                TEST_RUNNER_PERF01_READER_CATALOG_SHA256=catalog_sha, TEST_RUNNER_PERF01_CELL=str(book) + "-" + mode)
            return values

        def begin(self, request):
            target = self.targets.get(request.get("targetKey"), {})
            require(target.get("bookID") == book and target.get("unitMode") == mode
                    and request.get("kind") in ("reader-open", "reader-overview"), "Only this source-qualified measurement cell is eligible")
            return super().begin(request)

        def handle(self, request, container):
            action = request.get("action")
            if action == "observe_perf01_mode":
                require(self.active is None and self.pending_inspector is None and len(self.mode_proofs) < 31
                        and request.get("unitMode") == mode and request.get("stage") in
                        {"selected", "before-cold", "after-cold", "warm-ready", "post-open"},
                        "Mode inspection must remain bounded and outside resource accounting")
                pid, executable = self.process()
                path = container / "Library/Preferences" / (core.BUNDLE + ".plist")
                data = core.bounded_read(path, 8 * 1024 * 1024)
                require(plistlib.loads(data).get("otzaria_reader_unit_mode") == mode, "Actual persisted original mode differs")
                identifier = uuid_string(request["nonce"])
                value = {"status": "ORIGINAL_PERSISTED_READER_MODE_OBSERVED", "proofID": identifier,
                    "unitMode": mode, "stage": request["stage"], "processID": pid, "executable": executable,
                    "observedHostMonotonic": time.monotonic(),
                    "preferenceObservation": {"path": str(path), "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()},
                    "scope": "Bounded original preference bytes at observation time; mutable preference file is not presented as a later immutable artifact"}
                self.mode_proofs[identifier] = value
                core.write(core.OUT / "mode-proofs" / (identifier + ".json"), value)
                return value
            if action == "complete_perf01_cell":
                require(self.active is None and self.pending_inspector is None and self.cell_complete is None,
                        "Complete the cell once, with all resource fences closed")
                self.cell_complete = validate_cell(request, book=book, mode=mode, catalog=self.catalog,
                    catalog_sha=catalog_sha, epochs=self.epochs, proofs=self.source_proofs, mode_proofs=self.mode_proofs)
                core.write(core.OUT / "twelve-original-cell-opens.json", self.cell_complete)
                return {"actualOpens": 12, "actualColdWarmPairs": 6, "bookID": book, "unitMode": mode,
                        "catalogSHA256": catalog_sha, "fullPerformanceAcceptance": False}
            require(action not in ("complete_reader", "complete_inspector", "arm_inspector", "validate_inspector"),
                    "This new measurement workload cannot claim an original twenty-open or Inspector completion")
            return super().handle(request, container)
    return PerBookModeHost


def measurements(core, completed, epochs):
    result = {}
    for temperature in ("process-cold", "warm"):
        rows = [r for r in completed["observations"] if r["mode"] == temperature]
        require(len(rows) == 6, "Exactly six observations per book/mode/temperature required")
        result[temperature] = {
            "visibility_upper_bound_seconds": core.percentiles([r["route"]["requestToNativeVisibleUpperBoundSeconds"] for r in rows]),
            "application_cpu_seconds": core.percentiles([epochs[r["epoch"]]["app_cpu_seconds"] for r in rows]),
            "sampled_app_rss_bytes": core.percentiles([epochs[r["epoch"]]["sampled_max_rss_bytes"] for r in rows]),
            "overview_upper_bound_seconds": core.percentiles([r["firstInteraction"]["requestToOriginalOverviewUpperBoundSeconds"] for r in rows]),
            "overview_cpu_seconds": core.percentiles([epochs[r["firstInteraction"]["epoch"]]["app_cpu_seconds"] for r in rows]),
            "positions_in_order": ORDER,
            "scope": "n=6 is two observations at each of three source positions; empirical nearest-rank p95 equals the maximum, not a population/single-chapter p95",
        }
    return result


def allocated_bytes(path, maximum_entries=200000):
    """Owned artifacts only; do not follow aliases or hash live trace payloads."""
    total, entries, seen = 0, 0, set()
    pending = [Path(path)]
    while pending:
        current = pending.pop()
        try:
            value = current.lstat()
        except FileNotFoundError:
            continue  # A live original producer may atomically rename a file.
        entries += 1
        require(entries <= maximum_entries and not stat.S_ISLNK(value.st_mode), "Owned artifact inventory exceeded its bound or traversed an alias")
        if stat.S_ISDIR(value.st_mode):
            pending.extend(current.iterdir())
        else:
            require(stat.S_ISREG(value.st_mode), "Unexpected owned artifact type")
            identity = (value.st_dev, value.st_ino)
            if identity not in seen:
                seen.add(identity); total += value.st_blocks * 512
    return total


class StorageGuard:
    def __init__(self, *, root_output, cell_output, catalog_output, trace_bytes, artifact_bytes,
                 catalog_bytes, other_bytes, os_bytes, stop_bytes):
        self.root, self.cell, self.catalog = root_output, cell_output, catalog_output
        self.trace_limit, self.artifact_limit, self.catalog_limit = trace_bytes, artifact_bytes, catalog_bytes
        self.margin = other_bytes + os_bytes + stop_bytes
        self.observations, self.failure = [], None

    def check(self):
        trace = allocated_bytes(self.cell / "traces")
        total = allocated_bytes(self.cell)
        catalog = allocated_bytes(self.catalog)
        free = shutil.disk_usage(self.root).free
        row = {"hostMonotonic": time.monotonic(), "traceAllocatedBytes": trace,
               "otherCellAllocatedBytes": max(0, total - trace), "catalogAllocatedBytes": catalog, "freeBytes": free}
        self.observations.append(row)
        require(len(self.observations) <= 2400, "Bound the retained storage observations")
        require(trace <= self.trace_limit and total - trace <= self.artifact_limit and catalog <= self.catalog_limit
                and free >= self.margin, "Owned phase exceeded its explicit trace/artifact/capacity reservation; retain all bytes and abort")
        return row


class BudgetedOriginalRunner:
    """Scoped core facade for the unchanged original one-case runner.

    Only its owned Popen handle is interrupted. Original argv/environment,
    original verifier/exporter and original process-group cleanup remain in use.
    A cap breach invalidates the run; finalization may grow bytes and is retained.
    """
    def __init__(self, core, guard, trace):
        self.core, self.guard, self.trace = core, guard, trace

    def __getattr__(self, name):
        return getattr(self.core, name)

    def command(self, args, timeout=90, check=True):
        # The unchanged original verifier and attachment exporter also run
        # while the trace is alive. Cover their entire subprocess lifetime,
        # not just the XCTest Popen interval, with the same owned-byte guard.
        self.guard.check(); self.trace.require_running()
        interruption = runpy.run_path(str(ROOT / "Scripts/CI/runtime27_interruption.py"))
        process = subprocess.Popen(args, cwd=ROOT, text=True, stdout=subprocess.PIPE,
            stderr=subprocess.PIPE, start_new_session=True)
        deadline = time.monotonic() + timeout
        try:
            while True:
                self.guard.check(); self.trace.require_running()
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise subprocess.TimeoutExpired(args, timeout)
                try:
                    stdout, stderr = process.communicate(timeout=min(1, remaining))
                    break
                except subprocess.TimeoutExpired:
                    continue
            self.guard.check()
            result = subprocess.CompletedProcess(args, process.returncode, stdout, stderr)
            if check:
                require(result.returncode == 0, "Original command failed: " + str(args[0]))
            return result
        except BaseException as error:
            self.guard.failure = type(error).__name__
            cleanup = interruption["stop_owned_process_group"](process)
            self.core.write(self.core.OUT / ("command-process-cleanup-" + uuid.uuid4().hex + ".json"), cleanup)
            raise

    def bounded(self, args, log, timeout, environment=None):
        require(args and args[0] == "xcodebuild" and "test-without-building" in args, "Only the original actual native invocation is budget guarded")
        self.guard.check(); self.trace.require_running()
        interruption = runpy.run_path(str(ROOT / "Scripts/CI/runtime27_interruption.py"))
        with Path(log).open("w") as output:
            process = subprocess.Popen(args, cwd=ROOT, env=environment, stdout=output,
                stderr=subprocess.STDOUT, start_new_session=True)
            deadline = time.monotonic() + timeout
            try:
                while process.poll() is None:
                    self.guard.check(); self.trace.require_running()
                    remaining = deadline - time.monotonic()
                    if remaining <= 0:
                        raise subprocess.TimeoutExpired(args, timeout)
                    try:
                        return process.wait(timeout=min(1, remaining))
                    except subprocess.TimeoutExpired:
                        pass
                return process.returncode
            except BaseException as error:
                self.guard.failure = type(error).__name__
                cleanup = interruption["stop_owned_process_group"](process)
                self.core.write(Path(log).with_suffix(".process-cleanup.json"), cleanup)
                raise


def run_cell(*, base_core, study, settings, owner, udid, test_run, build, source, installation,
             catalog_dir, catalog, inventory, output, book, mode, case, budget):
    core = support("reader-full-v40-ui-observation.py").load_core()
    core.OUT = output; output.mkdir()
    core.write(output / "source-before.json", source)
    catalog_sha = core.digest(catalog_dir / "reader-mode-matrix.json")
    guard = StorageGuard(root_output=base_core.OUT, cell_output=output, catalog_output=catalog_dir,
        trace_bytes=budget["trace_bytes_per_cell"], artifact_bytes=budget["artifact_bytes_per_cell"],
        catalog_bytes=budget["catalog_bytes"], other_bytes=budget["other_reserved_bytes"],
        os_bytes=budget["os_margin_bytes"], stop_bytes=budget["finalization_reserve_bytes"])
    result = {"schema": SCHEMA, "status": "STARTED_NOT_ACCEPTED", "bookID": book, "unitMode": mode,
        "caseID": case, "catalog": core.witness(catalog_dir / "reader-mode-matrix.json"),
        "source_before": source, "build_before": build, "simulatorUDID": udid,
        "missing_or_unqualified_metrics": MISSING, "full_performance_acceptance": False,
        "native_case_directory": str(output / "native")}
    host = delivery = trace = None
    error, cleanup = None, []
    try:
        guard.check()
        require(source_context(core, True) == source, "Current measurement source drifted before the cell")
        owner.verify_installed_images(udid, build)
        container = Path(core.command(["xcrun", "simctl", "get_app_container", udid, core.BUNDLE, "data"], timeout=45).stdout.strip())
        environment = os.environ.copy()
        environment.update(TEST_RUNNER_FAITHFUL_PRODUCTION_WORKSPACE_FILE=str(container / "Library/Application Support/ChavrusaText/StudyWorkspace/workspace-v1.json"),
            TEST_RUNNER_RUNTIME27_RECORD_CONFIGURATION="1", TEST_RUNNER_READER_OBSERVATION_CORPUS="full-v40")
        delivery = runpy.run_path(str(ROOT / "Scripts/CI/runtime27-url-delivery.py"))["NativeURLDelivery"](udid, container, "full-v32", output)
        environment.update(delivery.start())
        trace = core.AppleTraceCapture(udid, inventory)
        trace.start(); guard.check()
        Host = observation_host(core.ObservationHost, core, book, mode, catalog_sha)
        host = Host(udid, container, catalog_dir, catalog, installation, trace)
        environment.update(host.environment()); host.start()
        proxy = BudgetedOriginalRunner(core, guard, trace)
        result["native_attempt"] = study.run_original_case(proxy, test_run, udid, case, 600,
            output / "native", environment, private_values=(host.token, delivery.token))
        require(result["native_attempt"]["passed"] is True, "The exact original registered case did not pass with zero skips")
        result["verified_execution"] = settings.verified_execution(output / "native", "Maktabah-iOSUITests/" + case, udid, repository_root=ROOT)
        require(host.error is None and host.cell_complete is not None, "Actual original resource/source schedule is incomplete")
        result["measurement_completion"] = core.witness(output / "twelve-original-cell-opens.json")
        result["measurements_by_temperature"] = measurements(core, host.cell_complete, host.epochs)
        result["actual_opens"], result["actual_cold_warm_pairs"] = 12, 6
        result["status"] = "ORIGINAL_PER_BOOK_MODE_CELL_MEASURED_TRACE_REVIEW_REQUIRED"
    except BaseException as failure:
        error = failure
        result.update(status="FAILED_OR_INCOMPLETE", error_type=type(failure).__name__, error=str(failure))
    finally:
        for name, value in (("observer", host), ("trace", trace), ("url_delivery", delivery)):
            if value is None:
                continue
            try:
                closed = value.stop()
                if name == "observer":
                    require(host.error is None and not host.is_alive(), "Original observer did not stop cleanly")
                elif name == "trace":
                    result["actual_continuous_trace"] = closed
                    require(closed.get("status") == "ACTUAL_TRACE_RETAINED_COVERAGE_AND_SCHEMA_REVIEW_REQUIRED"
                            and closed.get("owned_process_group_cleanup", {}).get("group_state") == "GONE_CHECKED", "Actual trace/owned recorder cleanup incomplete")
            except Exception as failure:
                cleanup.append({"phase": name, "errorType": type(failure).__name__})
        try:
            guard.check()
            result["source_after"] = source_context(core, True)
            require(result["source_after"] == source, "Actual source changed during this original cell")
            result["installed_images_after"] = owner.verify_installed_images(udid, build)
            require(core.digest(catalog_dir / "reader-mode-matrix.json") == catalog_sha, "Actual complete mode catalog changed")
        except Exception as failure:
            cleanup.append({"phase": "post-verification", "errorType": type(failure).__name__})
        core.write(output / "storage-observations.json", {"reservation": budget, "observations": guard.observations,
            "failure": guard.failure, "scope": "Live allocated-byte checkpoints; all finalization growth/failures retained, never a truncation policy"})
        result["storage_observations"] = core.witness(output / "storage-observations.json")
        result["post_verification_failures"] = cleanup
        if cleanup:
            result["status"] = "FAILED_OR_INCOMPLETE"
            error = error or ValueError("Owned cell cleanup or post-verification failed")
        if host is not None:
            result["error"] = result.get("error", "").replace(host.token, "<redacted-observer-token>")
        core.write(output / "RESULT.json", result)
    if error is not None:
        raise error
    return {"result": core.witness(output / "RESULT.json"), "case": case,
            "case_directory": str(output / "native"), "case_result": core.witness(output / "native/RESULT.json")}


def execute(args, core, source):
    require(sys.platform == "darwin" and args.owned_simulator and args.installation_result, "Explicit original retained Simulator and genuine Mac required")
    for prefix in ("", "TEST_RUNNER_", "SIMCTL_CHILD_"):
        require(all(prefix + key not in os.environ for key in ("OTZARIA_SHARED_ROOT_OVERRIDE", "OTZARIA_PRODUCTION_DB_PATH",
                    "OTZARIA_NATIVE_BOOTSTRAP_ACCEPTANCE", "SMOKE_BYPASS_BOOTSTRAP", "OTZARIA_DATABASE_PATH")),
                "A corpus/bootstrap override is present")
    output = args.output.absolute()
    require(not output.exists() and output.is_relative_to(ROOT / "build/artifacts") and ".." not in output.parts,
            "Use a fresh owned output under build/artifacts; failed evidence cannot be reused")
    output.mkdir(parents=True)
    require(output.resolve(strict=True) == output, "Owned evidence path is redirected")
    core.OUT = output
    core.write(output / "source-before.json", source)
    config = core.bounded_json(core.INPUTS, 1024 * 1024)
    products, test_run, build = core.build_identity(source)
    study, settings = support("production-study-v40-ui.py"), support("study-ui-settings-receipts.py")
    sdk = core.command(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"]).stdout.strip()
    runtime_id = os.environ.get("FAITHFUL_RUNTIME27_IDENTIFIER")
    runtimes = core.json_command(["xcrun", "simctl", "list", "runtimes", "available", "-j"])["runtimes"]
    runtimes = [r for r in runtimes if r.get("isAvailable") and r.get("identifier") == runtime_id
                and r["version"].split(".")[:2] == sdk.split(".")[:2] and r["version"].split(".")[0] == "27"]
    require(len(runtimes) == 1, "Explicit original SDK-matched iPadOS27 runtime required")
    runtime = runtimes[0]
    types = [t for t in runtime["supportedDeviceTypes"] if "iPad Pro" in t["name"] and "13-inch" in t["name"]]
    retained = support("reader-full-v40-ui-observation.py")
    owner = retained.RetainedV40Installation(core, args.owned_simulator, args.installation_result)
    udid, device_type, ownership = owner.admit_owner(config, runtime, types)
    image_bytes = sum(p.stat().st_size for name in ("Maktabah.app", "Maktabah-iOSUITests-Runner.app")
                      for p in (products / name).rglob("*") if p.is_file())
    require(all(type(v) is int and 0 < v <= 64 * 1024**3 for v in
                (args.trace_bytes_per_cell, args.artifact_bytes_per_cell, args.catalog_bytes, args.os_margin_bytes, args.finalization_reserve_bytes))
            and type(args.reserved_other_bytes) is int and args.reserved_other_bytes >= 0, "Finite explicit incremental storage reservations required")
    required = image_bytes + args.catalog_bytes + 9 * (args.trace_bytes_per_cell + args.artifact_bytes_per_cell) \
        + args.reserved_other_bytes + args.os_margin_bytes + args.finalization_reserve_bytes
    budget = {"trace_bytes_per_cell": args.trace_bytes_per_cell, "artifact_bytes_per_cell": args.artifact_bytes_per_cell,
        "catalog_bytes": args.catalog_bytes, "possible_image_copy_bytes": image_bytes,
        "other_reserved_bytes": args.reserved_other_bytes, "os_margin_bytes": args.os_margin_bytes,
        "finalization_reserve_bytes": args.finalization_reserve_bytes, "required_free_bytes": required,
        "prospective_continuous_trace_bundles": 9, "prospective_resource_epochs": 216,
        "prospective_native_opens": 108, "prospective_overview_interactions": 108, "prospective_case_results": 9,
        "free_before": shutil.disk_usage(ROOT).free, "not_a_performance_SLA": True}
    report = {"schema": SCHEMA, "status": "STARTED_NOT_ACCEPTED", "source_before": source, "build_before": build,
        "runtime": runtime, "device_type": device_type, "configuration": "Debug", "data_profile": "production",
        "corpus_profile": "full-v40", **ownership, "capacity_before": budget, "case_results": [],
        "selected_case_ids": [v[2] for v in CELLS], "full_performance_acceptance": False,
        "native116_acceptance": False, "physical_device_acceptance": False, "missing_or_unqualified_metrics": MISSING,
        "comparison_status": "CANDIDATE_ONLY_NO_SECOND_GENUINELY_QUALIFIED_BUILD"}
    failure, post = None, []
    lifecycle = False
    database = installation = None
    try:
        require(budget["free_before"] >= required, "The entire bounded serial workload and other owners' reservations do not fit")
        lifecycle = True
        core.command(["xcrun", "simctl", "boot", udid], timeout=90)
        core.command(["xcrun", "simctl", "bootstatus", udid, "-b"], timeout=900)
        report["image_installation"] = study.install_images(core, owner, udid, products, build)
        database, installation = owner.admit_current_installation(config, udid, build)
        report["installation_before"] = installation
        catalog_dir = output / "mode-catalog"
        catalog = prepare_catalog(core, config, installation, catalog_dir)
        report["mode_catalog"] = core.witness(catalog_dir / "reader-mode-matrix.json")
        inventory = core.instrument_inventory()
        for book, mode, case in CELLS:
            report["case_results"].append(run_cell(base_core=core, study=study, settings=settings, owner=owner, udid=udid,
                test_run=test_run, build=build, source=source, installation=installation, catalog_dir=catalog_dir,
                catalog=catalog, inventory=inventory, output=output / (str(book) + "-" + mode), book=book, mode=mode, case=case, budget=budget))
            core.write(output / "PROGRESS.json", report)
        require(len(report["case_results"]) == 9, "Every separate exact registered cell must complete")
        report.update(status=STATUS, actual_opens=108, actual_cold_warm_pairs=54,
            actual_resource_epochs=216, actual_continuous_trace_bundles=9)
    except BaseException as error:
        failure = error
        report.update(status="FAILED_OR_INCOMPLETE", error_type=type(error).__name__, error=str(error))
    finally:
        if database is not None:
            try:
                current, relocation = owner.current_database(udid)
                record = core.witness(current)
                require(record["bytes"] == installation["database"]["bytes"] and record["sha256"] == DB_SHA,
                        "Actual installed corpus changed across the measurement matrix")
                report.update(database_after=record, data_container_relocation_after=relocation,
                    installed_images_after=owner.verify_installed_images(udid, build), original_receipts_after=owner.verify_prior_receipts())
            except Exception as error:
                post.append({"phase": "actual-corpus-images", "errorType": type(error).__name__})
        try:
            report["source_after"] = source_context(core, True)
            require(report["source_after"] == source, "Actual source closure changed")
            post_dir = output / "post-build"; post_dir.mkdir()
            old_out = core.OUT
            try:
                core.OUT = post_dir
                _, _, report["build_after"] = core.build_identity(source)
            finally:
                core.OUT = old_out
            require(report["build_after"] == build, "Actual same-checkout app/SDK/test build bytes changed")
        except Exception as error:
            post.append({"phase": "source-build", "errorType": type(error).__name__})
        if lifecycle:
            try:
                report["owned_cleanup"] = owner.retain_simulator(udid)
            except Exception as error:
                post.append({"phase": "retained-simulator", "errorType": type(error).__name__})
        report["post_verification_failures"] = post
        if post:
            report["status"] = "FAILED_OR_INCOMPLETE"
            failure = failure or ValueError("Matrix post-verification incomplete")
        core.write(output / "RESULT.json", report)
    if failure is not None:
        raise failure


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase", choices=["source-check", "execute"])
    parser.add_argument("--owned-simulator")
    parser.add_argument("--installation-result", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--trace-bytes-per-cell", type=int)
    parser.add_argument("--artifact-bytes-per-cell", type=int)
    parser.add_argument("--catalog-bytes", type=int)
    parser.add_argument("--reserved-other-bytes", type=int, default=0)
    parser.add_argument("--os-margin-bytes", type=int, default=2_000_000_000)
    parser.add_argument("--finalization-reserve-bytes", type=int, default=256 * 1024 * 1024)
    args = parser.parse_args()
    core = support("reader-full-v40-ui-observation.py").load_core()
    context = source_context(core, args.phase == "execute")
    if args.phase == "source-check":
        print(json.dumps({"schema": SCHEMA, "status": "SOURCE_ONLY_NOT_NATIVE_OR_PERFORMANCE_ACCEPTANCE",
            "source": context, "native_executed": 0, "prospective_cells": 9, "prospective_opens": 108,
            "prospective_continuous_trace_bundles": 9, "prospective_resource_epochs": 216}, ensure_ascii=False, sort_keys=True))
        return
    require(args.output is not None, "Fresh explicit output directory required")
    execute(args, core, context)


if __name__ == "__main__":
    main()

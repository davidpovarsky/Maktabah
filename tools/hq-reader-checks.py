"""Small portable tests of production reader logic. DB/decoder doubles are explicit.

No app build, SQLite corpus, UIKit or device-performance claim. Extraction only
isolates Apple-dependent integration boundaries; it never rewrites tested logic.
"""
from pathlib import Path
import argparse
import json
import subprocess
import sqlite3
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--suite", choices=["cache", "service", "bridge", "render", "sqlite", "all"], default="all")
args = parser.parse_args()
fixtures = ROOT / "Tests/HQ/reader"
reading = ROOT / "Source/Otzaria/Reading"
artifacts = ROOT / "docs/hq-reader/results"
artifacts.mkdir(parents=True, exist_ok=True)
selected = ["cache", "service", "bridge", "render", "sqlite"] if args.suite == "all" else [args.suite]
results = []

def write_log(path, value):
    # Keep compiler/test messages while making generated evidence diff-clean.
    path.write_text("\n".join(line.rstrip() for line in value.splitlines()).rstrip() + "\n", encoding="utf-8")

def method(source, marker):
    start = source.index(marker)
    opening = source.index("{", start)
    depth = 1
    end = opening + 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[start:end]

with tempfile.TemporaryDirectory(prefix="hq-reader-") as directory:
    temp = Path(directory)
    unit = temp / "ReadingUnit.swift"
    unit.write_text((reading / "OtzariaReadingUnit.swift").read_text(encoding="utf-8").split("#if os(iOS)")[0], encoding="utf-8")
    cache = temp / "SideCache.swift"
    cache.write_text((reading / "OtzariaMaktabahBridge+LineAnchors.swift").read_text(encoding="utf-8").split("extension OtzariaMaktabahBridge")[0], encoding="utf-8")
    app = (ROOT / "Source/Otzaria/App/OtzariaAppContainer.swift").read_text(encoding="utf-8")
    bridge = temp / "Bridge.swift"
    bridge.write_text((fixtures / "BridgeSupport.swift").read_text(encoding="utf-8") + "\n" + "\n".join([
        "extension OtzariaMaktabahBridge {",
        *[method(app, marker) for marker in ["func generationSnapshot()", "func withReadingUnitService<T>", "func withCachedReadingUnit(", "func withDatabase<T>"]],
        # Match bridge reset, not the MainActor container reset.
        method(app[app.index("final class OtzariaMaktabahBridge"):], "func resetConnection()"),
        method(app, "func clearAllCaches()"), "}",
    ]), encoding="utf-8")
    adapter = temp / "AdapterSection.swift"
    adapter_source = (ROOT / "Source/Otzaria/Compatibility/OtzariaGenericBackendAdapter.swift").read_text(encoding="utf-8")
    section_method = method(adapter_source, "func section(at")
    section_method = section_method.replace("#if os(iOS)", "").replace("#else\n        throw LibraryBackendError.capabilityUnavailable\n        #endif", "")
    adapter.write_text("import Foundation\nstruct OtzariaGenericBackendAdapter {\n" + section_method + "\n" + method(adapter_source, "func normalizedLocator(for") + "\n}\n", encoding="utf-8")
    for suite in selected:
        if suite == "sqlite":
            source = (reading / "OtzariaReadingUnitService.swift").read_text(encoding="utf-8")
            query = source.split('let mappings = try db.fetch(query: """', 1)[1].split('"""', 1)[0]
            db = sqlite3.connect(":memory:")
            db.executescript("""
                CREATE TABLE line(id INTEGER PRIMARY KEY, bookId INTEGER, lineIndex INTEGER);
                CREATE INDEX idx_line_book_index ON line(bookId, lineIndex);
                CREATE TABLE line_toc(lineId INTEGER, tocEntryId INTEGER, PRIMARY KEY(lineId, tocEntryId));
                INSERT INTO line VALUES (100,103,0),(101,103,1),(102,103,2),(200,104,0);
                INSERT INTO line_toc VALUES (100,11),(102,12),(200,21);
            """)
            actual = db.execute(query, [103]).fetchall()
            assert actual == [(0, 11), (1, None), (2, 12)], actual
            plan = db.execute("EXPLAIN QUERY PLAN " + query, [103]).fetchall()
            (artifacts / "sqlite-tests.log").write_text("PASS: actual production mapping query retains unmapped line and book isolation\n" + json.dumps({"rows": actual, "fixture_plan": plan}, indent=2) + "\n", encoding="utf-8")
            db.close()
            results.append({"suite": "sqlite", "test_exit": 0, "authority": "Python SQLite in-memory fixture, not production plan/performance"})
            print("sqlite: PASS - actual production LEFT JOIN query; unmapped line; book isolation", flush=True)
            continue
        if suite == "render":
            sources = [ROOT / "Source/LibraryBackend/LibraryBackendModels.swift"]
        else:
            sources = [unit, reading / "OtzariaLineAnchor.swift"]
            if suite != "bridge":
                sources += [cache]
            if suite in ["service", "bridge"]:
                sources += [reading / "OtzariaReadingUnitDescriptor.swift", reading / "OtzariaReadingUnitService.swift", fixtures / "ServiceSupport.swift"]
            if suite == "bridge":
                sources += [bridge, adapter, ROOT / "Source/LibraryBackend/LibraryBackendModels.swift", reading / "OtzariaMaktabahBridge+LineAnchors.swift", reading / "OtzariaMaktabahBridge+ReadingUnits.swift"]
        sources += [fixtures / f"{suite.title()}Tests.swift"]
        executable = temp / f"{suite}.exe"
        start = time.perf_counter()
        compile_result = subprocess.run(["swiftc", "-parse-as-library", *map(str, sources), "-o", str(executable)], capture_output=True, text=True, encoding="utf-8")
        write_log(artifacts / f"{suite}-compile.log", compile_result.stdout + compile_result.stderr)
        print(f"{suite}: compile exit={compile_result.returncode}", flush=True)
        if compile_result.returncode:
            print(compile_result.stderr, flush=True)
            results.append({"suite": suite, "compile_exit": compile_result.returncode})
            continue
        run = subprocess.run([str(executable)], capture_output=True, text=True, encoding="utf-8")
        write_log(artifacts / f"{suite}-tests.log", run.stdout + run.stderr)
        print(run.stdout, end="", flush=True)
        if run.returncode:
            print(run.stderr[:2000], flush=True)
        results.append({"suite": suite, "compile_exit": 0, "test_exit": run.returncode, "compile_and_test_seconds": round(time.perf_counter() - start, 3)})
summary_path = artifacts / "summary.json"
previous = json.loads(summary_path.read_text(encoding="utf-8")) if args.suite != "all" and summary_path.exists() else []
merged = {r["suite"]: r for r in previous}
merged.update({r["suite"]: r for r in results})
summary_path.write_text(json.dumps(list(merged.values()), indent=2) + "\n", encoding="utf-8")
raise SystemExit(any(r.get("test_exit", 1) != 0 for r in results))

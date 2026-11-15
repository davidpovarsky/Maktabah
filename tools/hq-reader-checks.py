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
import sys
import hashlib
import re

sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--suite", choices=["cache", "service", "bridge", "render", "sqlite", "corpus", "all"], default="all")
parser.add_argument("--artifacts-dir", type=Path, default=None)
parser.add_argument("--database", type=Path, help="Read-only miniTest10-v6 DB, verified against the committed profile")
args = parser.parse_args()
fixtures = ROOT / "Tests/HQ/reader"
reading = ROOT / "Source/Otzaria/Reading"
artifacts = args.artifacts_dir or ROOT / "docs/hq-reader/results"
artifacts.mkdir(parents=True, exist_ok=True)
selected = ["cache", "service", "bridge", "render", "sqlite"] if args.suite == "all" else [args.suite]
if args.suite == "all" and args.database:
    selected.append("corpus")
if args.suite == "render" and args.database:
    selected = ["corpus", "render"]
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

def line_sql(source):
    template = source.split('let result = try db.fetch(query: """', 1)[1].split('"""', 1)[0]
    lookup = source.split("switch lookup {", 1)[1].split("let result =", 1)[0]
    variants = re.findall(r'predicate = "([^"]*)"\s+order = "([^"]*)"', lookup)
    assert len(variants) == 4, variants
    return [template.replace('\\(predicate)', predicate).replace('\\(order)', order)
            for predicate, order in variants]

with tempfile.TemporaryDirectory(prefix="hq-reader-") as directory:
    temp = Path(directory)
    render_input = None
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
        if suite == "corpus":
            if args.database is None:
                raise SystemExit("--suite corpus requires --database (never uses an installed user DB)")
            profile = json.loads((ROOT / "Source/Otzaria/DataProfiles/miniTest10.profile.json").read_text(encoding="utf-8"))
            path = args.database.resolve()
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            assert digest == profile["sourceDatabase"]["databaseSHA256"]
            assert path.stat().st_size == profile["sourceDatabase"]["databaseBytes"]
            source = (reading / "OtzariaReadingUnitService.swift").read_text(encoding="utf-8")
            queries = line_sql(source)
            db = sqlite3.connect(path.as_uri() + "?mode=ro", uri=True)
            books = []
            render_books = []
            for book_id in [103, 28, 3152]:
                title = db.execute("SELECT title FROM book WHERE id = ?", [book_id]).fetchone()[0]
                indices = [r[0] for r in db.execute("SELECT lineIndex FROM line WHERE bookId = ? ORDER BY lineIndex", [book_id])]
                assert indices and len(indices) == len(set(indices))
                count = 0
                for position, index in enumerate(indices):
                    expected = [(index, indices[position-1] if position else None,
                                 indices[position+1] if position+1 < len(indices) else None)]
                    assert db.execute(queries[1], [book_id, index]).fetchall() == expected
                    previous = db.execute(queries[3], [book_id, index]).fetchall()
                    next_row = db.execute(queries[2], [book_id, index]).fetchall()
                    assert [r[0] for r in previous] == ([indices[position-1]] if position else [])
                    assert [r[0] for r in next_row] == ([indices[position+1]] if position+1 < len(indices) else [])
                    count += 3
                assert db.execute(queries[0], [book_id]).fetchone()[0] == indices[0]
                plans = [db.execute("EXPLAIN QUERY PLAN " + q, [book_id] if n == 0 else [book_id, indices[len(indices)//2]]).fetchall()
                         for n, q in enumerate(queries)]
                assert not any("SCAN " in r[3] or "TEMP B-TREE" in r[3] for p in plans for r in p), plans
                books.append({"book_id": book_id, "title": title, "source_rows": len(indices),
                              "queries_verified": count+1, "fixture_plans": plans})
                if args.suite == "render":
                    # Fixture preparation only, not the production Swift decoder.
                    import zstandard
                    dictionaries = [zstandard.ZstdCompressionDict(r[0]) for r in db.execute("SELECT dict FROM zstd_dict")]
                    decoders = {d.dict_id(): zstandard.ZstdDecompressor(dict_data=d) for d in dictionaries}
                    lines = []
                    for line_id, line_index, he_ref, content in db.execute("""
                        SELECT l.id, l.lineIndex, l.heRef, lc.content
                        FROM line l LEFT JOIN line_content lc ON lc.id = l.id
                        WHERE l.bookId = ? ORDER BY l.lineIndex
                    """, [book_id]):
                        assert content is not None
                        if isinstance(content, bytes):
                            frame = zstandard.get_frame_parameters(content)
                            assert frame.content_size <= 16 * 1024 * 1024
                            content = decoders[frame.dict_id].decompress(content).decode("utf-8")
                        assert isinstance(content, str)
                        lines.append({"id": line_id, "index": line_index, "heRef": he_ref, "text": content})
                    assert [r["index"] for r in lines] == indices
                    render_books.append({"bookID": book_id, "title": title, "lines": lines})
            db.close()
            evidence = {"profile": "miniTest10-v6", "database_sha256": digest,
                        "authority": "Python SQLite actual released corpus subset; SQL metadata only; no Swift decoder/UI/full-DB/iPad acceptance",
                        "sqlite_version": sqlite3.sqlite_version, "books": books}
            if render_books:
                render_input = temp / "genuine-render-input.json"
                render_input.write_text(json.dumps(render_books, ensure_ascii=False), encoding="utf-8")
                evidence["render_input"] = {"sha256": hashlib.sha256(render_input.read_bytes()).hexdigest(),
                                            "bytes": render_input.stat().st_size,
                                            "preparation": "Python zstandard fixture decoder; actual Swift neutral renderer tested separately"}
            (artifacts / "corpus-sql.json").write_text(json.dumps(evidence, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            results.append({"suite": "corpus", "test_exit": 0, "authority": evidence["authority"],
                            "queries_verified": sum(b["queries_verified"] for b in books)})
            print("corpus: PASS - exact SQL on all Berakhot/Tehillim/Derashot metadata in verified miniTest10-v6 (not full DB/device)", flush=True)
            continue
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
            # Exercise the exact bounded line-query template from production,
            # with the fixed predicates/order selected by its LineLookup switch.
            queries = line_sql(source)
            db.executemany("INSERT INTO line VALUES (?,103,?)", [(1000+i, i*2) for i in range(10_000)])
            # Include another book whose indices fall inside this book's holes.
            db.execute("INSERT INTO line VALUES (999999,104,9999)")
            line_plans = []
            cases = [(0, [103], [(0, None, 1)]),
                     (1, [103, 10_000], [(10_000, 9998, 10002)]),
                     (2, [103, 9999], [(10_000, 9998, 10002)]),
                     (3, [103, 10001], [(10_000, 9998, 10002)]),
                     (1, [103, 9999], []), (3, [103, 0], []),
                     (2, [103, 19998], []), (0, [105], [])]
            for variant, parameters, expected in cases:
                sql = queries[variant]
                steps = [0]
                def progress():
                    steps[0] += 1
                    return int(steps[0] > 2000)
                db.set_progress_handler(progress, 1)
                found = db.execute(sql, parameters).fetchall()
                db.set_progress_handler(None, 0)
                assert found == expected, (variant, parameters, found, expected)
                query_plan = db.execute("EXPLAIN QUERY PLAN " + sql, parameters).fetchall()
                assert not any("SCAN " in row[3] or "TEMP B-TREE" in row[3] for row in query_plan), query_plan
                line_plans.append({"variant": variant, "parameters": parameters, "rows": found,
                                   "sqlite_vm_steps": steps[0], "fixture_plan": query_plan})
            (artifacts / "sqlite-tests.log").write_text("PASS: actual production mapping and lazy-line SQL; sparse/foreign/missing/boundary isolation\n" + json.dumps({"rows": actual, "fixture_plan": plan, "line_queries": line_plans}, indent=2) + "\n", encoding="utf-8")
            db.close()
            results.append({"suite": "sqlite", "test_exit": 0, "authority": "Python SQLite in-memory fixture, not production plan/performance"})
            print("sqlite: PASS - production LEFT JOIN + 8 bounded line queries; actual SQLite fixture, no corpus/device claim", flush=True)
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
        render_output = temp / "render-output"
        render_output.mkdir(exist_ok=True)
        command = [str(executable)] + ([str(render_input), str(render_output)] if suite == "render" and render_input else [])
        run = subprocess.run(command, capture_output=True, text=True, encoding="utf-8")
        if suite == "render" and render_input and run.returncode == 0:
            output_hashes = {p.stem: {"bytes": p.stat().st_size, "sha256": hashlib.sha256(p.read_bytes()).hexdigest()}
                             for p in render_output.glob("*.txt")}
            assert set(output_hashes) == {"103", "28", "3152"}
            (artifacts / "render-corpus-output.json").write_text(json.dumps(output_hashes, indent=2) + "\n", encoding="utf-8")
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

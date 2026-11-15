#!/usr/bin/env python3
"""Focused portable Inspector checks; no app/user database.

Compiles the actual service/grouping/classifier and exact note-scope/tap methods
with fixture boundary types. Generated SQL runs against temporary SQLite via
Python. Default fixtures use stdlib and a counted plain-text decoder. The explicit
digest-pinned miniTest10 corpus case uses installed Python zstandard at the
decoder boundary. Apple frameworks, native Swift ZSTD and app UI are not tested.
"""
import json
import hashlib
import argparse
from contextlib import closing
import os
from pathlib import Path
import shutil
import sqlite3
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
READING = ROOT / "Source/Otzaria/Reading"


def make_database(path):
    with closing(sqlite3.connect(path)) as db, db:
        db.executescript("""
            CREATE TABLE category(id INTEGER, parentId INTEGER, title TEXT, level INTEGER, orderIndex INTEGER);
            CREATE TABLE book(id INTEGER PRIMARY KEY, title TEXT, filePath TEXT, categoryId INTEGER, orderIndex INTEGER, isBaseBook INTEGER, dependenceType TEXT);
            CREATE TABLE line(id INTEGER PRIMARY KEY, bookId INTEGER, lineIndex INTEGER, heRef TEXT, content TEXT);
            CREATE UNIQUE INDEX line_book_index ON line(bookId, lineIndex);
            CREATE TABLE line_content(id INTEGER PRIMARY KEY, content TEXT);
            CREATE TABLE connection_type(id INTEGER PRIMARY KEY, name TEXT);
            CREATE TABLE link(id INTEGER PRIMARY KEY, sourceBookId INTEGER, targetBookId INTEGER, sourceLineId INTEGER, targetLineId INTEGER, connectionTypeId INTEGER);
            CREATE INDEX link_source ON link(sourceBookId, sourceLineId);
            CREATE INDEX link_target ON link(targetBookId, targetLineId);
            CREATE TABLE link_coverage(linkId INTEGER, side INTEGER, lineId INTEGER);
            CREATE TABLE link_suppressed_side(linkId INTEGER, side INTEGER);
            INSERT INTO category VALUES(1, NULL, 'מפרשים', 0, 0);
            INSERT INTO book VALUES(1, 'תהילים', NULL, NULL, 0, 1, NULL);
            INSERT INTO book VALUES(2, 'פירוש על תהילים', NULL, 1, 1, 0, 'commentary');
            INSERT INTO connection_type VALUES(1, 'COMMENTARY');
            INSERT INTO connection_type VALUES(2, 'REFERENCE');
        """)
        for i in range(2000):
            db.execute("INSERT INTO line VALUES(?,1,?,?,?)", (i + 1, i * 2, f"תהילים {i}", f"base {i}"))
            db.execute("INSERT INTO line VALUES(?,2,?,?,?)", (10001 + i, i, f"פירוש {i}", f"snippet {i}"))
            db.execute("INSERT INTO line_content VALUES(?,?)", (10001 + i, f"snippet {i}"))
            db.execute("INSERT INTO link VALUES(?,1,2,?,?,1)", (i + 1, i + 1, 10001 + i))
        # Duplicate coverage across chunks must preserve one relationship.
        db.executemany("INSERT INTO link_coverage VALUES(1,0,?)", [(1,), (401,), (801,)])
        # A relationship in a sparse gap must not leak into a section query.
        db.execute("INSERT INTO line VALUES(9000,1,1,'gap','gap')")
        db.execute("INSERT INTO link VALUES(9000,1,2,9000,10001,1)")
        # An isolated window for inverse, per-side suppression and ranges.
        db.execute("INSERT INTO line VALUES(9001,1,9001,'special','special')")
        db.executemany("INSERT INTO link VALUES(?,2,1,10001,9001,1)", [(9100,), (9101,)])
        db.execute("INSERT INTO link_suppressed_side VALUES(9101,1)")
        db.execute("INSERT INTO link VALUES(9102,1,2,9001,10002,2)")
        db.execute("INSERT INTO link_suppressed_side VALUES(9102,0)")
        db.execute("INSERT INTO link VALUES(9103,1,2,9000,10003,1)")
        db.execute("INSERT INTO link_coverage VALUES(9103,0,9001)")


def query():
    request = json.load(sys.stdin)
    try:
        with closing(sqlite3.connect(Path(sys.argv[2]).resolve().as_uri() + "?mode=ro&immutable=1", uri=True)) as db:
            rows = db.execute(request["query"], request["parameters"]).fetchall()
            if os.environ.get("HQ_INSPECTOR_CORPUS") == "1":
                import zstandard
                dictionaries = {dictionary.dict_id(): dictionary for (data,) in db.execute("SELECT dict FROM zstd_dict") for dictionary in [zstandard.ZstdCompressionDict(data)]}
                decoded = 0
                def decode(value):
                    nonlocal decoded
                    if not isinstance(value, bytes):
                        return value
                    frame = zstandard.get_frame_parameters(value)
                    if frame.content_size > 16 * 1024 * 1024 or frame.dict_id not in dictionaries:
                        raise ValueError("invalid frame size/dictionary")
                    result = zstandard.ZstdDecompressor(dict_data=dictionaries[frame.dict_id]).decompress(value, max_output_size=16 * 1024 * 1024)
                    decoded += 1
                    return result.decode("utf-8")
                rows = [[decode(value) for value in row] for row in rows]
                plan = db.execute("EXPLAIN QUERY PLAN " + request["query"], request["parameters"]).fetchall()
                with Path(os.environ["HQ_INSPECTOR_QUERY_LOG"]).open("a", encoding="utf-8") as log:
                    log.write(json.dumps({"sql": request["query"], "parameters": request["parameters"], "rows": len(rows), "decodedFrames": decoded, "plan": plan}) + "\n")
        print(json.dumps({"rows": rows}))
    except (sqlite3.Error, ValueError) as error:
        print(json.dumps({"error": str(error)}))


def block(text, start, end):
    return text[text.index(start):text.index(end, text.index(start))]


def corpus_oracle():
    """Independent row/set oracle, not the service's SQL CTE/UNION query."""
    if os.environ.get("HQ_INSPECTOR_CORPUS") != "1":
        raise SystemExit("oracle is for the explicit corpus case only")
    request = json.load(sys.stdin)
    book, indexes = request["bookID"], set(request["indexes"])
    with closing(sqlite3.connect(Path(sys.argv[2]).resolve().as_uri() + "?mode=ro&immutable=1", uri=True)) as db:
        lines = {row[0]: row[1:] for row in db.execute("SELECT id, bookId, lineIndex FROM line")}
        window = {key for key, (work, index) in lines.items() if work == book and index in indexes}
        types = dict(db.execute("SELECT id, name FROM connection_type"))
        hidden = set(db.execute("SELECT linkId, side FROM link_suppressed_side"))
        coverage = {}
        for line, link, side in db.execute("SELECT lineId, linkId, side FROM link_coverage"):
            coverage.setdefault((link, side), set()).add(line)
        references = {"REFERENCE", "QUOTATION", "MESORAT_HASHAS", "EIN_MISHPAT", "MISHNAH_IN_TALMUD", "RELATED", "OTHER", "SIFREI_MITZVOT", "ESSAY", "ALLUSION", "LITURGY", "LAW", "SUMMARY"}
        dependent = {"COMMENTARY", "SUPER_COMMENTARY", "TARGUM", "MIDRASH", "PARSHANUT", "DIBUR_HAMATCHIL", "ELUCIDATION", "EXPLICATION", "FOOTNOTES"}
        expected = set()
        for key, source, target, source_line, target_line, kind in db.execute("SELECT id, sourceBookId, targetBookId, sourceLineId, targetLineId, connectionTypeId FROM link"):
            if source == book and (key, 0) not in hidden and ({source_line} | coverage.get((key, 0), set())) & window:
                expected.add((key, target, target_line, lines[target_line][1]))
            anchors = ({target_line} | coverage.get((key, 1), set())) & window
            eligible_same_work = types.get(kind) in references and ((key, 0) in hidden or any(anchor != source_line and anchor not in coverage.get((key, 0), set()) for anchor in anchors))
            if target == book and anchors and (key, 1) not in hidden and types.get(kind) in references | dependent and (source != target or eligible_same_work):
                expected.add((key, source, source_line, lines[source_line][1]))
    print(json.dumps({"rows": sorted(expected)}))


def write_corpus_report(report):
    import zstandard
    report.update(python=sys.version.split()[0], pythonZstandard=zstandard.__version__, zstdVersion=list(zstandard.ZSTD_VERSION),
                  sourceHashEncoding="UTF-8 production text with universal newlines, matching compiled fixture input")
    target = ROOT / "docs/hq-inspector/miniTest10-source-audit-20261115.json"
    target.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    metadata = [q for q in report["queries"] if "WITH win" in q["sql"]]
    summary = {key: value for key, value in report.items() if key != "queries"}
    summary.update(queries=len(report["queries"]), metadataQueries=len(metadata),
                   metadataDecodedFrames=sum(q["decodedFrames"] for q in metadata),
                   decodedFrames=sum(q["decodedFrames"] for q in report["queries"]),
                   metadataLineIndexSearches=sum(any("SEARCH line USING COVERING INDEX idx_line_book_index" in step[3] for step in q["plan"]) for q in metadata),
                   unindexedLinkScans=sorted({step[3] for q in metadata for step in q["plan"] if "SCAN " in step[3] and "link" in step[3].lower()}),
                   rawAuditSHA256=hashlib.sha256(target.read_bytes()).hexdigest())
    (target.parent / "miniTest10-source-summary-20261115.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"report": str(target), "metadataQueries": summary["metadataQueries"], "decodedFrames": summary["decodedFrames"], "databaseUnchanged": report["databaseUnchanged"]}))


def run():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-ref", help="Read production source from a Git commit for a regression baseline")
    parser.add_argument("--case", choices=["all", "scope", "tap", "notes", "selection", "document", "gate", "corpus"], default="all")
    parser.add_argument("--database", type=Path, help="Digest-pinned miniTest10 copy under this worktree's build directory; corpus case only")
    args = parser.parse_args()
    def production(path):
        if args.source_ref:
            relative = path.relative_to(ROOT).as_posix()
            return subprocess.check_output(["git", "show", f"{args.source_ref}:{relative}"], cwd=ROOT).decode("utf-8")
        return path.read_text(encoding="utf-8")

    swiftc = shutil.which("swiftc")
    if not swiftc:
        raise SystemExit("swiftc missing; no dependency installation attempted")
    with tempfile.TemporaryDirectory(prefix="hq-inspector-") as temp:
        temp = Path(temp)
        database = temp / "fixture.sqlite"
        if args.case == "corpus":
            if args.database is None:
                parser.error("corpus case requires --database")
            database = args.database.resolve()
            if not database.is_relative_to(ROOT / "build"):
                parser.error("corpus copy must be under this assigned worktree's build directory")
            profile = json.loads((ROOT / "Source/Otzaria/DataProfiles/miniTest10.profile.json").read_text(encoding="utf-8"))
            digest = hashlib.sha256(database.read_bytes()).hexdigest()
            if database.stat().st_size != profile["sourceDatabase"]["databaseBytes"] or digest != profile["sourceDatabase"]["databaseSHA256"]:
                raise SystemExit("database does not match digest-pinned miniTest10 profile")
        else:
            if args.database is not None:
                parser.error("--database is permitted only with --case corpus")
            make_database(database)
        models = production(ROOT / "Source/Otzaria/Domain/OtzariaModels.swift")
        source = production(READING / "OtzariaLineSourcesService.swift")
        source = source.replace("import TorahInspectorCore", "")
        adapter = production(READING / "MaktabahTorahInspectorAdapter.swift")
        units = production(READING / "OtzariaReadingUnit.swift")
        library = production(ROOT / "Source/LibraryBackend/LibraryBackendModels.swift")
        compatibility = production(ROOT / "Source/Otzaria/Data/OtzariaBookSchemaCompatibility.swift")
        contains = block(adapter, "    private func contains(", "    private func map(")
        contains = contains.replace("private func contains", "func contains")
        notes = block(adapter, "    private func notes(", "    private func contains(")
        notes = notes.replace("private func notes", "func notes")
        tap = production(READING / "ReaderViewModel+OtzariaLineSources.swift")
        tap = tap.replace("#if os(iOS)", "").replace("#endif", "").replace("#else\n        false", "")
        generated = [
            (ROOT / "Tests/HQ/inspector/FixtureBoundary.swift").read_text(encoding="utf-8"),
            block(compatibility, "struct OtzariaLineContentProjection:", "final class OtzariaLineContentDecoder"),
            block(compatibility, "struct OtzariaBookSchemaProjection:", "struct OtzariaTOCSchemaProjection:"),
            block(compatibility, "enum OtzariaBookSchemaCompatibility", "    static func projection(in database: OpaquePointer") + "}\n",
            block(models, "struct OtzariaLinkedSource:", "struct OtzariaSourceSection:"),
            production(READING / "OtzariaLineAnchor.swift"),
            block(units, "struct OtzariaReadingUnit:", "struct OtzariaUnitLevelOption:"),
            block(units, "public enum OtzariaUnitMode:", "#if os(iOS)"),
            production(READING / "OtzariaReadingUnitDescriptor.swift"),
            block(library, "struct TextVersionMetadata:", "struct LibraryReaderCapabilities:"),
            block(library, "struct LibraryTextLink:", "struct LibraryRelatedSource:"),
            block(library, "struct LibraryTextSection:", "struct LibrarySearchRequest:"),
            block(production(READING / "OtzariaInspectorRelationshipsProvider.swift"), "enum OtzariaInspectorDocumentMapper", "struct OtzariaInspectorRelationshipsProvider:"),
            (ROOT / "Tests/HQ/inspector/DocumentFixtureBoundary.swift").read_text(encoding="utf-8"),
            block(production(ROOT / "Source/Features/Annotations/Models/Annotation.swift"), "struct Annotation:", "extension Annotation {"),
            source,
            "@MainActor final class NoteScopeFixture { var otzariaUnitsByReference: [String: OtzariaReadingUnit] = [:]\n"
            "var readerViewModel: ReaderViewModel?\nlet coordinator = BackendCoordinator.shared\n"
            "let otzaria = OtzariaMaktabahBridge.shared\n"
            "var locatorsByReference: [String: TextLocator] = [:]\n"
            + block(adapter, "    func selection(", "    func locator(for selection:")
            + block(adapter, "    private func currentUnitSelection(", "    private func document(")
            + "func remember(_ locator: TextLocator, for reference: String) { locatorsByReference[cacheKey(providerID: locator.backend.rawValue, reference: reference)] = locator }\n"
            "func remember(_ unit: OtzariaReadingUnit, for reference: String) {}\n"
            'static func unitReference(for unit: OtzariaReadingUnit) -> String { "fixture-unit" }\n'
            + block(adapter, "    func locator(for selection:", "    private func currentUnitSelection(")
            + "func locator(for reference: String, providerID: String) -> TextLocator? {\n"
            "if let remembered = locatorsByReference[cacheKey(providerID: providerID, reference: reference)] { return remembered }\n"
            "guard let locator = readerViewModel?.selectedSegmentLocator, locator.backend.rawValue == providerID else { return nil }; return locator\n}\n"
            'static func reference(for locator: TextLocator) -> String { if case .canonicalRef(let ref) = locator.position { return ref }; return locator.persistenceKey }\n'
            'func cacheKey(providerID: String, reference: String) -> String { "\\(providerID):\\(reference)" }\n'
            + notes + contains + "}\n",
            block(adapter, "enum MaktabahTorahInspectorFormatting", "    static func relationshipKind(") + "}\n",
            "@MainActor final class DocumentScopeFixture {\n"
            "let coordinator = BackendCoordinator.shared\n"
            "let otzaria = OtzariaMaktabahBridge(database: SQLiteDatabase(path: CommandLine.arguments[3]))\n"
            "var preferredMode: LibraryReaderTextMode = .source\n"
            "var locators: [String: TextLocator] = [:]\n"
            "var units: [String: OtzariaReadingUnit] = [:]\n"
            "func remember(_ locator: TextLocator, for reference: String) { locators[reference] = locator }\n"
            "func remember(_ unit: OtzariaReadingUnit, for reference: String) { units[reference] = unit }\n"
            "func locator(for reference: String, providerID: String) -> TextLocator? {\n"
            "guard let value = locators[reference], value.backend.rawValue == providerID else { return nil }; return value\n}\n"
            + block(adapter, "    private func mapOtzariaDocument(", "    private func activeLocator(").replace("private func mapOtzariaDocument", "func mapOtzariaDocument")
            + block(adapter, "    private func activeLocator(", "    private func locator(for reference:").replace("private func activeLocator", "func activeLocator") + "}\n",
            tap,
            (ROOT / "Tests/HQ/inspector/InspectorFixtures.swift").read_text(encoding="utf-8"),
        ]
        swift_file = temp / "InspectorFixtures.swift"
        swift_file.write_text("\n".join(generated), encoding="utf-8")
        exe = temp / ("inspector-fixtures.exe" if os.name == "nt" else "inspector-fixtures")
        inputs = [swift_file]
        for name in ["OtzariaRelationshipClassifier.swift", "OtzariaCategoryPathResolver.swift",
                     "OtzariaLinkedSourceGrouping.swift", "OtzariaLinkedSourcePreview.swift"]:
            target = temp / name
            target.write_text(production(READING / name), encoding="utf-8")
            inputs.append(target)
        print(f"Source: {args.source_ref or 'working tree'}; case: {args.case}", flush=True)
        subprocess.run([swiftc, "-parse-as-library", *map(str, inputs), "-o", str(exe)], check=True)
        env = dict(os.environ, HQ_INSPECTOR_CASE=args.case)
        env.pop("HQ_INSPECTOR_CORPUS", None)
        env.pop("HQ_INSPECTOR_QUERY_LOG", None)
        if args.case == "corpus":
            env.update(HQ_INSPECTOR_CORPUS="1", HQ_INSPECTOR_QUERY_LOG=str(temp / "corpus-queries.jsonl"))
        completed = subprocess.run([str(exe), sys.executable, str(Path(__file__).resolve()), str(database)], env=env)
        if completed.returncode:
            raise SystemExit(completed.returncode)
        if args.case == "corpus":
            if hashlib.sha256(database.read_bytes()).hexdigest() != digest:
                raise SystemExit("read-only corpus database changed")
            queries = [json.loads(line) for line in (temp / "corpus-queries.jsonl").read_text(encoding="utf-8").splitlines()]
            report = {"profile": "miniTest10", "profileVersion": profile["profileVersion"], "databaseSHA256": digest, "databaseUnchanged": True,
                      "sqlite": sqlite3.sqlite_version, "decoder": "Python zstandard dictionary boundary, not production Swift decoder", "queries": queries,
                      "sourceHead": args.source_ref or subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                      "sourceSHA256": {name: hashlib.sha256(production(ROOT / name).encode("utf-8")).hexdigest() for name in [
                          "Source/Otzaria/Reading/OtzariaLineSourcesService.swift",
                          "Source/Otzaria/Data/OtzariaBookSchemaCompatibility.swift",
                          "Source/Otzaria/Reading/OtzariaLinkedSourceGrouping.swift",
                          "Source/Otzaria/Reading/OtzariaRelationshipClassifier.swift",
                          "Source/Otzaria/Reading/OtzariaCategoryPathResolver.swift"]}}
            write_corpus_report(report)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--query":
        query()
    elif len(sys.argv) > 1 and sys.argv[1] == "--oracle":
        corpus_oracle()
    else:
        run()

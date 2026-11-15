#!/usr/bin/env python3
"""Focused portable Inspector checks; stdlib only, no app/user database.

Compiles the actual service/grouping/classifier and exact note-scope/tap methods
with fixture boundary types. Generated SQL runs against temporary SQLite via
Python; Apple frameworks, production zstd and app UI are explicitly not tested.
"""
import json
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
        with closing(sqlite3.connect(f"file:{sys.argv[2]}?mode=ro", uri=True)) as db:
            rows = db.execute(request["query"], request["parameters"]).fetchall()
        print(json.dumps({"rows": rows}))
    except sqlite3.Error as error:
        print(json.dumps({"error": str(error)}))


def block(text, start, end):
    return text[text.index(start):text.index(end, text.index(start))]


def run():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-ref", help="Read production source from a Git commit for a regression baseline")
    parser.add_argument("--case", choices=["all", "scope", "tap", "notes", "selection"], default="all")
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
        make_database(database)
        models = production(ROOT / "Source/Otzaria/Domain/OtzariaModels.swift")
        source = production(READING / "OtzariaLineSourcesService.swift")
        source = source.replace("import TorahInspectorCore", "")
        adapter = production(READING / "MaktabahTorahInspectorAdapter.swift")
        contains = block(adapter, "    private func contains(", "    private func map(")
        contains = contains.replace("private func contains", "func contains")
        notes = block(adapter, "    private func notes(", "    private func contains(")
        notes = notes.replace("private func notes", "func notes")
        tap = production(READING / "ReaderViewModel+OtzariaLineSources.swift")
        tap = tap.replace("#if os(iOS)", "").replace("#endif", "").replace("#else\n        false", "")
        generated = [
            (ROOT / "Tests/HQ/inspector/FixtureBoundary.swift").read_text(encoding="utf-8"),
            block(models, "struct OtzariaLinkedSource:", "struct OtzariaSourceSection:"),
            production(READING / "OtzariaLineAnchor.swift"),
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
            "enum MaktabahTorahInspectorFormatting { static func otzariaBookID(from key: String) -> Int? { Int(key.dropFirst(5)) } }",
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
        completed = subprocess.run([str(exe), sys.executable, str(Path(__file__).resolve()), str(database)], env=env)
        if completed.returncode:
            raise SystemExit(completed.returncode)


if __name__ == "__main__":
    query() if len(sys.argv) > 1 and sys.argv[1] == "--query" else run()

#!/usr/bin/env python3
"""Synthetic parser/admission controls only; never native or production evidence.

No original app, search provider, simulator, compiler, network or full corpus is
executed. Tiny temporary SQLite rows and intentionally synthetic catalog-shaped
JSON test rejection/binding behavior only. No complete producer PASS is created.
"""
import argparse
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import sqlite3
import tempfile
import time
import unittest
import uuid


def module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


def sha(data):
    return hashlib.sha256(data).hexdigest()


def uid():
    return str(uuid.uuid4()).upper()


ARGS = None
P = None
S = None


def page():
    identity = {"engine": "otzaria", "namespace": uid(), "sessionID": uid(), "processID": 123,
                "profileID": "production", "submissionRevision": 1}
    rows, items, sql = [], [], []
    for index in range(100):
        book, line, rowid = 1000 + index, index + 1, 9000 + index
        title, ref = "SYNTHETIC PARSER BOOK " + str(book), "SYNTHETIC REF " + str(line)
        path = "otzaria-book:" + str(book)
        rows.append({"filePath": path, "segment": line, "id": index, "title": title, "reference": ref})
        items.append({"id": "otzaria:" + path + ":" + str(index) + ":" + str(line), "bookID": book,
                      "lineIndex": line, "locator": "otzaria|book:" + str(book) + "|line:" + str(line),
                      "bookTitle": title, "reference": ref})
        sql.append({"lineID": rowid, "bookID": book, "lineIndex": line, "bookTitle": title, "reference": ref})
    return {"scope": "actual original UI query and provider page plus immutable SQL, not full-context acceptance",
            "provider": {**identity, "event": "provider", "request": {"querySHA256": P.QUERY_SHA, "offset": 0, "limit": 100},
                         "page": {"results": rows}},
            "publication": {**identity, "event": "published", "items": items}, "independentSQL": sql,
            "SYNTHETIC_CONTROL_NOT_NATIVE_EVIDENCE": True}


def fixture(directory):
    selected = P.actual_page(page())[0]
    compiled = {"path": str(directory / "synthetic-compile.json"), "bytes": 1, "sha256": sha(b"synthetic compile")}
    snapshot = {"files": {P.SERVICE: {"sha256": sha(b"synthetic service")},
                           P.PRESENTATION: {"sha256": sha(b"synthetic presentation")}}}
    def target(mode, start, count, focus):
        text_rows = ["שלום " + str(index) for index in range(start, start + count)]
        text = "\n".join(text_rows)
        anchors, position = [], 0
        for index, body in zip(range(start, start + count), text_rows):
            anchors.append({"lineID": 8999 + index, "bookID": selected["bookID"], "lineIndex": index,
                            "heRef": "SYNTHETIC REF " + str(index), "rangeLocation": position,
                            "rangeLength": P.utf16(body), "text": body, "textSHA256": sha(body.encode()),
                            "segmentID": "otzaria|book:1000|line:" + str(index), "previewPlainText": body,
                            "previewPlainTextSHA256": sha(body.encode()), "previewUTF16Length": P.utf16(body)})
            position += P.utf16(body) + 1
        filename = "1000-" + mode + "-" + str(start) + "-" + str(start + count - 1) + ".source.utf8"
        (directory / filename).write_bytes(text.encode())
        return {"bookID": 1000, "bookTitle": selected["independentSQL"]["bookTitle"], "focusLineIndex": focus,
                "focusLocator": "otzaria|book:1000|line:" + str(focus), "unitMode": mode,
                "unitStartLineIndex": start, "unitEndLineIndex": start + count - 1, "unitRowCount": count,
                "allOriginalAnchorsChecked": count, "sourceFile": filename, "sourceUTF8": text,
                "sourceSHA256": sha(text.encode()), "sourceUTF8Bytes": len(text.encode()), "sourceUTF16Length": P.utf16(text),
                "anchors": anchors, "backendReaderSourceUTF8": text,
                "backendReaderSourceSHA256": sha(text.encode()), "backendReaderSourceUTF16Length": P.utf16(text),
                "backendReaderMode": "source", "tocSelection": {"schema": 1,
                "canonicalLocator": "otzaria|book:1000|line:" + str(start), "headings": [{"synthetic": True}],
                "allTOCRowsChecked": 10, "tocSQLRowsSHA256": sha(b"SYNTHETIC TOC")}}
    targets = [target("line", 1, 1, 1), target("paragraph", 1, 2, 1), target("chapter", 1, 3, 1)]
    for value in targets:
        mode = value["unitMode"]
        value["neighbors"] = {"previous": target(mode, 0, 1, 0), "next": target(mode, 4, 1, 4)}
    value = {"schema": 1, "status": P.ORACLE_STATUS, "corpusProfile": "full-v40", "databaseSHA256": P.V40_SHA,
             "uiExecuted": 0, "searchProviderExecuted": False,
             "sourceServiceSHA256": snapshot["files"][P.SERVICE]["sha256"],
             "presentationSourceSHA256": snapshot["files"][P.PRESENTATION]["sha256"],
             "catalogCompileInputsSHA256": compiled["sha256"], "targets": targets,
             "SYNTHETIC_CONTROL_NOT_ORIGINAL_SOURCE": True}
    path = directory / "preview-targets.json"
    path.write_text(json.dumps(value))
    return path, value, selected, compiled, snapshot


class Controls(unittest.TestCase):
    def test_synthetic_page_parser_retains_all_one_hundred_exact_rows(self):
        result = P.actual_page(page())
        self.assertEqual(len(result), 100)
        self.assertEqual([row["pageIndex"] for row in result], list(range(100)))
        self.assertEqual(result[0]["stableID"], "otzaria:otzaria-book:1000:0:1")

    def test_original_sql_query_checks_all_rows_and_never_writes(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "synthetic.sqlite"
            selected = P.actual_page(page())
            with sqlite3.connect(path) as db:
                db.execute("CREATE TABLE book (id INTEGER PRIMARY KEY,title TEXT)")
                db.execute("CREATE TABLE line (id INTEGER PRIMARY KEY,bookId INTEGER,lineIndex INTEGER,heRef TEXT)")
                db.executemany("INSERT INTO book VALUES (?,?)", [(row["bookID"], row["independentSQL"]["bookTitle"]) for row in selected])
                db.executemany("INSERT INTO line VALUES (?,?,?,?)", [(row["independentSQL"]["lineID"], row["bookID"], row["focusLineIndex"], row["independentSQL"]["reference"]) for row in selected])
            before = (S.file_identity(path), path.read_bytes())
            value = P.verify_sql_page(path, selected)
            self.assertEqual(value["rowsVerified"], 100)
            self.assertEqual((S.file_identity(path), path.read_bytes()), before)
            changed = copy.deepcopy(selected)
            changed[99]["independentSQL"]["lineID"] += 1
            with self.assertRaisesRegex(ValueError, "independent immutable SQL"):
                P.verify_sql_page(path, changed)

    def test_only_an_actual_complete_corpus_can_enter_the_hash_gate(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "synthetic.sqlite"
            path.write_bytes(b"SYNTHETIC NOT A PRODUCTION CORPUS")
            with self.assertRaisesRegex(ValueError, "size"):
                P.hash_database(S, path)

    def test_synthetic_source_shape_is_only_parser_eligibility_not_producer_pass(self):
        with tempfile.TemporaryDirectory() as temporary:
            path, value, selected, compiled, snapshot = fixture(Path(temporary))
            _, reasons, sources = P.validate_oracle(S, path, selected, compiled, snapshot)
            self.assertEqual(reasons, [])
            self.assertEqual(len(sources), 9)
            self.assertFalse((Path(temporary) / "runner-inputs.json").exists())
            self.assertFalse((Path(temporary) / "RESULT.json").exists())

    def test_original_context_eligibility_rejection_keeps_complete_sources(self):
        with tempfile.TemporaryDirectory() as temporary:
            path, value, selected, compiled, snapshot = fixture(Path(temporary))
            value["targets"][0]["neighbors"].pop("next")
            value["targets"][1]["neighbors"].pop("previous")
            value["targets"][2]["neighbors"]["previous"]["tocSelection"] = copy.deepcopy(value["targets"][2]["tocSelection"])
            path.write_text(json.dumps(value))
            before = {p.name: p.read_bytes() for p in Path(temporary).iterdir()}
            _, reasons, _ = P.validate_oracle(S, path, selected, compiled, snapshot)
            self.assertEqual(len(reasons), 3)
            self.assertEqual({p.name: p.read_bytes() for p in Path(temporary).iterdir()}, before)

    def test_oversize_complete_oracle_is_rejected_without_truncation(self):
        with tempfile.TemporaryDirectory() as temporary:
            path, value, selected, compiled, snapshot = fixture(Path(temporary))
            value["syntheticPaddingForBoundControl"] = "x" * P.MAX_ORACLE
            path.write_text(json.dumps(value))
            before = path.read_bytes()
            _, reasons, _ = P.validate_oracle(S, path, selected, compiled, snapshot)
            self.assertTrue(any("bound" in reason for reason in reasons))
            self.assertEqual(path.read_bytes(), before)

    def test_source_payload_symlink_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            path, value, selected, compiled, snapshot = fixture(Path(temporary))
            source = path.parent / value["targets"][0]["sourceFile"]
            retained = source.with_suffix(".original")
            source.rename(retained)
            source.symlink_to(retained)
            with self.assertRaises(ValueError):
                P.validate_oracle(S, path, selected, compiled, snapshot)


PAGE_MUTATIONS = {
    "foreign_query": lambda p: p["provider"]["request"].update(querySHA256="0" * 64),
    "raw_query": lambda p: p["provider"]["request"].update(query="נפשי"),
    "later_offset": lambda p: p["provider"]["request"].update(offset=100),
    "boolean_offset": lambda p: p["provider"]["request"].update(offset=False),
    "partial_limit": lambda p: p["provider"]["request"].update(limit=50),
    "foreign_engine": lambda p: p["provider"].update(engine="zayit"),
    "fixture_profile": lambda p: p["publication"].update(profileID="miniTest10"),
    "foreign_namespace": lambda p: p["publication"].update(namespace=uid()),
    "foreign_session": lambda p: p["publication"].update(sessionID=uid()),
    "foreign_pid": lambda p: p["publication"].update(processID=124),
    "foreign_revision": lambda p: p["publication"].update(submissionRevision=2),
    "missing_sql_row": lambda p: p["independentSQL"].pop(),
    "missing_provider_row": lambda p: p["provider"]["page"]["results"].pop(),
    "missing_publication_row": lambda p: p["publication"]["items"].pop(),
    "wrong_last_sql_id": lambda p: p["independentSQL"][99].update(lineID=-1),
    "wrong_last_sql_title": lambda p: p["independentSQL"][99].update(bookTitle="other"),
    "wrong_canonical_locator": lambda p: p["publication"]["items"][0].update(locator="sefaria|Psalms|ref:Psalms 35"),
    "wrong_stable_id": lambda p: p["publication"]["items"][0].update(id="0"),
    "unqualified_book": lambda p: p["provider"]["page"]["results"][0].update(filePath="1000"),
    "boolean_segment": lambda p: p["provider"]["page"]["results"][0].update(segment=True),
    "negative_provider_id": lambda p: p["provider"]["page"]["results"][0].update(id=-1),
    "malformed_reference": lambda p: p["provider"]["page"]["results"][0].update(reference=False),
}
ORACLE_MUTATIONS = {
    "foreign_corpus": lambda v: v.update(databaseSHA256="0" * 64),
    "ui_claim": lambda v: v.update(uiExecuted=1),
    "search_claim": lambda v: v.update(searchProviderExecuted=True),
    "other_service": lambda v: v.update(sourceServiceSHA256="0" * 64),
    "other_presentation": lambda v: v.update(presentationSourceSHA256="0" * 64),
    "other_compile": lambda v: v.update(catalogCompileInputsSHA256="0" * 64),
    "other_hit": lambda v: v["targets"][1].update(focusLineIndex=2),
    "source_escape": lambda v: v["targets"][0].update(sourceFile="../outside.source.utf8"),
    "false_complete_count": lambda v: v["targets"][2].update(allOriginalAnchorsChecked=2),
    "changed_full_source": lambda v: v["targets"][1].update(sourceUTF8="substitute"),
    "changed_reader_body": lambda v: v["targets"][2].update(backendReaderSourceUTF8="substitute"),
    "changed_preview": lambda v: v["targets"][0]["anchors"][0].update(previewPlainText="substitute"),
    "wrong_utf16": lambda v: v["targets"][0]["anchors"][0].update(rangeLocation=1),
    "wrong_focus_sql_id": lambda v: v["targets"][0]["anchors"][0].update(lineID=999),
    "missing_toc": lambda v: v["targets"][0].pop("tocSelection"),
}


def page_test(mutation):
    def check(self):
        value = page()
        mutation(value)
        with self.assertRaises((ValueError, TypeError, KeyError)):
            P.actual_page(value)
    return check


def oracle_test(mutation):
    def check(self):
        with tempfile.TemporaryDirectory() as temporary:
            path, value, selected, compiled, snapshot = fixture(Path(temporary))
            mutation(value)
            path.write_text(json.dumps(value))
            with self.assertRaises((ValueError, TypeError, KeyError)):
                P.validate_oracle(S, path, selected, compiled, snapshot)
    return check


for name, mutation in PAGE_MUTATIONS.items():
    setattr(Controls, "test_reject_page_" + name, page_test(mutation))
for name, mutation in ORACLE_MUTATIONS.items():
    setattr(Controls, "test_reject_oracle_" + name, oracle_test(mutation))


def main():
    global ARGS, P, S
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--settings-helper", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    ARGS = parser.parse_args()
    ARGS.output.mkdir()
    P = module(ARGS.candidate, "preview_producer_controls")
    S = module(ARGS.settings_helper, "original_settings_receipts_controls")
    started = time.time()
    with (ARGS.output / "controls.log").open("x") as stream:
        result = unittest.TextTestRunner(stream=stream, verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(Controls))
    report = {"status": "SOURCE_ADMISSION_CONTROLS_PASS_NOT_NATIVE" if result.wasSuccessful() else "SOURCE_ADMISSION_CONTROLS_FAILED",
              "controls": result.testsRun, "failures": len(result.failures), "errors": len(result.errors),
              "nativeUIExecuted": 0, "productionCorpusReads": 0, "genuinePreviewOracleProduced": False,
              "startedAtUnix": started, "finishedAtUnix": time.time(),
              "scope": "Synthetic parser/SQLite fixtures exercise rejection only; no actual UI or original-source output is inferred",
              "inputs": {str(path.resolve()): {"bytes": path.stat().st_size, "sha256": sha(path.read_bytes())}
                         for path in (ARGS.candidate, ARGS.settings_helper, Path(__file__))}}
    (ARGS.output / "RESULT.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    raise SystemExit(0 if result.wasSuccessful() else 1)


if __name__ == "__main__":
    main()

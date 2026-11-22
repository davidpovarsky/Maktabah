#!/usr/bin/env python3
"""Focused SQL-oracle controls; optional actual immutable fixture, no Native/provider."""
import argparse
import hashlib
import json
from pathlib import Path
import runpy
import sqlite3

ROOT = Path(__file__).resolve().parents[2]
SUBJECT = ROOT / "Scripts/CI/runtime27-live-paragraph-oracle.py"
derive = runpy.run_path(str(SUBJECT))["derive_live_paragraph"]
rows = []


def fixture():
    c = sqlite3.connect(":memory:")
    c.executescript("""
        CREATE TABLE line(id INTEGER PRIMARY KEY,bookId INTEGER,lineIndex INTEGER);
        CREATE TABLE tocEntry(id INTEGER PRIMARY KEY,bookId INTEGER,parentId INTEGER,level INTEGER);
        CREATE TABLE line_toc(lineId INTEGER,tocEntryId INTEGER);
        INSERT INTO tocEntry VALUES(10,7,NULL,0),(11,7,10,1),(12,7,10,1);
        INSERT INTO line VALUES(100,7,0),(101,7,518),(102,7,522),(103,7,523),(104,7,524),(105,7,525),(106,7,526);
        INSERT INTO line_toc VALUES(100,10),(101,11),(102,12),(103,12),(104,12),(105,12),(106,12);
    """)
    return c


def check(name, mutation=None, reject=False, requested=523, expected=None):
    with fixture() as c:
        if mutation:
            c.executescript(mutation)
        try:
            result = derive(c, 7, requested)
        except ValueError:
            assert reject, name
        else:
            assert not reject, name
            assert result["canonical_locator"] == "otzaria|book:7|line:522"
            assert result["requested_line_index"] == requested and not result["ui_observation_used"]
            assert result["source_line_indices"] == (expected or [522, 523, 524, 525, 526])
        rows.append({"control": name, "status": "PASS", "synthetic_fixture": True})


check("interior requested line has exact independently derived paragraph start")
check("last member still selects the same exact paragraph", requested=526)
check("actual discontiguous membership is preserved", "DELETE FROM line_toc WHERE lineId=104; DELETE FROM line WHERE id=104;",
      expected=[522,523,525,526])
check("missing requested line fails closed", requested=999, reject=True)
check("duplicate source mapping fails closed", "INSERT INTO line_toc VALUES(103,12);", reject=True)
check("foreign book mapping fails closed", "UPDATE tocEntry SET bookId=8 WHERE id=12;", reject=True)
check("non-leaf selected entry fails closed", "INSERT INTO tocEntry VALUES(13,7,12,2);", reject=True)
check("ambiguous other member fails closed", "INSERT INTO line_toc VALUES(104,11);", reject=True)
check("first-unit title ambiguity fails closed", "DELETE FROM line_toc WHERE lineId=101;", reject=True)
check("interleaved root title fails closed", "UPDATE line SET lineIndex=519 WHERE id=100;", reject=True)

parser = argparse.ArgumentParser()
parser.add_argument("--database", type=Path)
parser.add_argument("--output", type=Path, required=True)
args = parser.parse_args()
actual = None
if args.database:
    path = args.database.resolve(strict=True)
    before = hashlib.sha256(path.read_bytes()).hexdigest()
    assert before == "d3d9bfcc2320a987a0391ad23fa72abcf6fd1fa0f3cba95adc05096e05a9edef"
    with sqlite3.connect(path.as_uri()+"?mode=ro&immutable=1",uri=True) as c:
        selected = c.execute("SELECT l.sourceBookId,sl.lineIndex FROM link l JOIN line sl ON sl.id=l.sourceLineId ORDER BY l.id LIMIT 1").fetchone()
        actual = derive(c, *selected)
        assert actual["source_line_indices"] == [522,523,524,525,526]
        assert actual["toc_entry_id"] == 643037 and actual["requested_line_index"] == 523
        assert actual["canonical_locator"] == "otzaria|book:3891|line:522"
    assert hashlib.sha256(path.read_bytes()).hexdigest() == before
    actual["database_sha256"] = before
    actual["database_unchanged"] = True
report = {"status": "PASS", "oracle_sha256": hashlib.sha256(SUBJECT.read_bytes()).hexdigest(),
          "controls": rows, "synthetic_controls_passed": len(rows), "actual_original_fixture": actual,
          "native_tests_executed": 0, "provider_requests": 0, "real_credentials_read": False}
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
print(json.dumps({"status": report["status"], "synthetic_controls_passed":len(rows),
                  "actual_original_fixture": actual, "output":str(args.output)}))

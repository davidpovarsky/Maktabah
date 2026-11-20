#!/usr/bin/env python3
"""Independent full SQL oracle with exact, resumable row coverage.

The original producer splits book text on LF only. CR is ordinary whitespace
inside one document and is normalized by its original fold/strip/collapse pass.
The earlier failed attempt is retained; none of its incomplete scalars is reused.
Completed partitions are internal checkpoints, never a publishable result.
"""
import argparse
import datetime
import hashlib
import importlib.util
import json
from pathlib import Path
import sqlite3
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
spec = importlib.util.spec_from_file_location("original_sql_global", ROOT / "tools/hq-otzaria-full-sql-occurrence-oracle.py")
original = importlib.util.module_from_spec(spec)
spec.loader.exec_module(original)
BUILD = original.BUILD
QUERIES = original.QUERIES
SIZE = 100000
VALIDATION = BUILD / "full-sql-global-oracle/REGEX_FULL_MINI_AND_CR_PARITY.json"


def sha(path):
    return original.sha(path)


def sources():
    return {"sourceSHA256": sha(Path(__file__)),
            "originalOracleModuleSHA256": sha(ROOT / "tools/hq-otzaria-full-sql-occurrence-oracle.py"),
            "scannerSHA256": sha(ROOT / "tools/otzaria_original_sql_oracle.py")}


def save_new(path, value):
    assert not path.exists(), "preserve prior evidence: " + str(path)
    data = json.dumps(value, ensure_ascii=False, indent=2) + "\n"
    with path.open("x", encoding="utf-8", newline="\n") as output:
        output.write(data)


def scalar(text):
    result = dict.fromkeys(QUERIES, 0)
    for terms in original.token_positions(text):
        for query in QUERIES:
            result[query] += query in terms
    return result


def verify_text(raw):
    assert "\n" not in raw, "LF changes original producer document boundaries"
    normalized = original.normalize(raw)
    canonical = original.display_text(raw)
    assert " ".join(normalized.split()) == canonical
    actual = original.unquoted_counts(normalized)
    assert actual == scalar(canonical)
    return actual


def validate():
    start = time.monotonic()
    checkout = ROOT / "Vendor/OtzariaSearchEngine/Checkout/otzaria_search_engine"
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=checkout, text=True).strip()
    assert commit == "265a14ea54f959a3e266d6e8acfa3a3b98101d68"
    engine = checkout / "rust/src/api/search_engine.rs"
    normalizer = checkout / "rust/src/hebrew_query.rs"
    engine_text, normalizer_text = engine.read_text(encoding="utf-8"), normalizer.read_text(encoding="utf-8")
    assert "let lines: Vec<&str> = text.split('\\n').collect();" in engine_text
    fold = normalizer_text.split("fn fold_strip_collapse(", 1)[1].split("pub fn normalize_text_for_indexing", 1)[0]
    assert "if c.is_whitespace()" in fold and "out.push(' ');" in fold
    cr_controls = ["בראשית\rאברהם", "\rבראשית\r\rאברהם\r", "בראשית\r בראשית",
                   "אב\rרהם", 'א"ב\rרהם', "בראשית<br>\rאברהם", "בְּרֵאשִׁית\rאַבְרָהָם",
                   "אברהם\rאברהם", "x\rאברהם", "אברהם\rx", "\r"]
    for raw in cr_controls:
        verify_text(raw)
    assert verify_text(cr_controls[0]) == {"בראשית": 1, "אברהם": 1}
    assert verify_text("אב\rרהם") == {"בראשית": 0, "אברהם": 0}
    for raw in ("בראשית\nאברהם", "בראשית\r\nאברהם"):
        try:
            verify_text(raw)
        except AssertionError:
            pass
        else:
            raise AssertionError("LF document-boundary gate was weakened")
    grammar, old_controls = original.regex_controls(), original.self_check()
    mini_path = Path(r"C:\Users\DAVID\Code\Maktabah-actions-completion-20261120\build\actions-native-20261120\miniTest10\seforim.db")
    assert sha(mini_path) == "d3d9bfcc2320a987a0391ad23fa72abcf6fd1fa0f3cba95adc05096e05a9edef"
    con = sqlite3.connect(mini_path.as_uri() + "?mode=ro&immutable=1", uri=True)
    decoder = original.OriginalZstd(con, original.DLL)
    mini_counts = {q: {"occurrences": 0, "matchingLiveDocuments": 0} for q in QUERIES}
    mini_rows = 0
    for content, in con.execute("SELECT lc.content FROM line l JOIN line_content lc ON lc.id=l.id ORDER BY l.id"):
        counts = verify_text(decoder.decode(content))
        for query, count in counts.items():
            mini_counts[query]["occurrences"] += count
            mini_counts[query]["matchingLiveDocuments"] += count > 0
        mini_rows += 1
    assert mini_rows == con.execute("SELECT COUNT(*) FROM line").fetchone()[0] == 18879
    decoder.close(); con.close()
    assert mini_counts == {"בראשית": {"occurrences": 176, "matchingLiveDocuments": 131},
                           "אברהם": {"occurrences": 239, "matchingLiveDocuments": 195}}
    con = sqlite3.connect(original.DATABASE.as_uri() + "?mode=ro&immutable=1", uri=True)
    decoder = original.OriginalZstd(con, original.DLL)
    book_rows, cr_rows, cr_characters, cr_ids, offending = 0, 0, 0, [], None
    book_counts = {q: {"occurrences": 0, "matchingLiveDocuments": 0} for q in QUERIES}
    for line_id, content in con.execute("SELECT l.id,lc.content FROM line l JOIN line_content lc ON lc.id=l.id WHERE l.bookId=7428 ORDER BY l.lineIndex"):
        raw = decoder.decode(content)
        counts = verify_text(raw)
        book_rows += 1
        if "\r" in raw:
            cr_rows += 1; cr_characters += raw.count("\r"); cr_ids.append(line_id)
        if line_id == 6105588:
            offending = {"lineID": line_id, "rawSHA256": hashlib.sha256(raw.encode()).hexdigest(),
                         "carriageReturns": raw.count("\r"), "lineFeeds": raw.count("\n"),
                         "priorGuardRejects": "\r" in raw, "correctedGuardAllows": "\n" not in raw}
        for query, count in counts.items():
            book_counts[query]["occurrences"] += count
            book_counts[query]["matchingLiveDocuments"] += count > 0
    assert book_rows == con.execute("SELECT COUNT(*) FROM line WHERE bookId=7428").fetchone()[0]
    assert offending and offending["rawSHA256"] == "39bc103a630b3e1491a9146c7ecc386df6fc81a793ddeffe78504380504cef9b"
    assert offending["carriageReturns"] > 0 and offending["lineFeeds"] == 0 and cr_rows > 0
    decoder.close(); con.close()
    report = dict(passed=True, actualSQLRows=mini_rows, fullOriginalMiniBookScope=10,
                  queryCounts=mini_counts, regexGrammarControls=grammar, independentScannerControls=old_controls,
                  newCRControls=len(cr_controls), retainedLFRejectionControls=2,
                  decoderByteParityControls=32, actualOffendingBookID=7428, actualOffendingBookRows=book_rows,
                  actualCRRows=cr_rows, actualCRCharacters=cr_characters, actualCRLineIDs=cr_ids,
                  offendingRow=offending, offendingBookQueryCounts=book_counts,
                  originalProducer=commit, originalProducerSourceSHA256={str(engine):sha(engine),str(normalizer):sha(normalizer)},
                  seconds=round(time.monotonic()-start,3), engineLoaded=False, indexRead=False,
                  databaseMutated=False, **sources())
    save_new(VALIDATION, report)
    print(json.dumps(report, ensure_ascii=False), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--validate-only", action="store_true")
    parser.add_argument("--attempt")
    parser.add_argument("--resume", action="store_true")
    parser.add_argument("--deadline-seconds", type=int, default=3300)
    args = parser.parse_args()
    if args.validate_only:
        return validate()
    assert args.attempt and all(c in "abcdefghijklmnopqrstuvwxyz0123456789-_" for c in args.attempt)
    validation = json.loads(VALIDATION.read_text(encoding="utf-8"))
    assert validation["passed"] and all(validation[key] == value for key,value in sources().items())
    out = BUILD / "full-sql-global-oracle" / args.attempt
    assert args.resume == out.exists(), "existing attempt requires explicit resume"
    out.mkdir(exist_ok=True)
    assert not (out / "RESULT.json").exists()
    start = time.monotonic()
    assert original.DATABASE.stat().st_size == 3821240320 and sha(original.DATABASE) == original.DATABASE_SHA
    con = sqlite3.connect(original.DATABASE.as_uri() + "?mode=ro&immutable=1", uri=True)
    con.execute("PRAGMA query_only=ON"); con.execute("PRAGMA cache_size=-65536")
    mmap_bytes = con.execute("PRAGMA mmap_size=4294967296").fetchone()[0]
    decoder = original.OriginalZstd(con, original.DLL)
    metadata = dict(databaseSHA256=original.DATABASE_SHA, partitionRows=SIZE, queries=list(QUERIES),
                    validationSHA256=sha(VALIDATION), **sources())
    if args.resume:
        assert json.loads((out/"START.json").read_text()) == metadata
    else:
        save_new(out/"START.json", metadata)
    parts, last_id, rows, candidates = [], 0, 0, 0
    for p in sorted(out.glob("partition-*.json")):
        part=json.loads(p.read_text(encoding="utf-8"))
        assert p.name == f"partition-{len(parts):04}.json" and part["complete"]
        assert part["firstRowOrdinal"] == rows and part["previousLineID"] == last_id
        assert part["sourceIdentity"] == metadata and 0 < part["rows"] <= SIZE
        parts.append(part); rows+=part["rows"]; candidates+=part["candidateRows"]; last_id=part["lastLineID"]
    current=None
    try:
        for line_id, compressed in con.execute("SELECT l.id,lc.content FROM line l JOIN line_content lc ON lc.id=l.id WHERE l.id>? ORDER BY l.id",(last_id,)):
            if current is None:
                current=dict(firstRowOrdinal=rows,previousLineID=last_id,firstLineID=line_id,rows=0,candidateRows=0,
                             carriageReturnRows=0,carriageReturns=0,normalizationControls=0,scalarControls=0,
                             multiplicities={q:[] for q in QUERIES})
                coverage=hashlib.sha256()
            raw=decoder.decode(compressed)
            if "\n" in raw:
                failure=dict(status="INCOMPLETE_NO_SCALAR",reason="LF changes original producer document boundaries",
                             lineID=line_id,rowOrdinal=rows,rawSHA256=hashlib.sha256(raw.encode()).hexdigest(),
                             completePartitions=len(parts),**sources())
                save_new(out/f"failure-at-row-{rows}.json",failure)
                raise AssertionError(json.dumps(failure))
            normalized=original.normalize(raw)
            if rows<1000 or "\r" in raw:
                assert " ".join(normalized.split()) == original.display_text(raw)
                current["normalizationControls"]+=1
            if "\r" in raw:
                current["carriageReturnRows"]+=1;current["carriageReturns"]+=raw.count("\r")
            maybe=normalized.translate(original.PREFILTER_TRANSLATION).lower()
            if any(query in maybe for query in QUERIES):
                candidates+=1;current["candidateRows"]+=1
                counts=original.unquoted_counts(normalized)
                if candidates<=1000 or line_id%1009==0 or "\r" in raw:
                    assert counts==scalar(normalized),f"scalar mismatch at {line_id}"
                    current["scalarControls"]+=1
                for query,count in counts.items():
                    if count:current["multiplicities"][query].append([line_id,count])
            coverage.update(f"{line_id}\n".encode())
            rows+=1;current["rows"]+=1;last_id=line_id
            if current["rows"]==SIZE:
                current.update(complete=True,partialNotPublishable=True,lastLineID=last_id,rowIDCoverageSHA256=coverage.hexdigest(),sourceIdentity=metadata)
                save_new(out/f"partition-{len(parts):04}.json",current);parts.append(current);current=None
                progress=dict(rowsScanned=rows,expectedRows=7080797,seconds=round(time.monotonic()-start,3),
                              completePartitions=len(parts),partialNotPublishable=True)
                (out/"PROGRESS.json").write_text(json.dumps(progress)+"\n")
                print(json.dumps(progress),flush=True)
                assert time.monotonic()-start<args.deadline_seconds,"bounded deadline; completed partitions retained, no complete scalar"
        if current is not None:
            current.update(complete=True,partialNotPublishable=True,lastLineID=last_id,rowIDCoverageSHA256=coverage.hexdigest(),sourceIdentity=metadata)
            save_new(out/f"partition-{len(parts):04}.json",current);parts.append(current)
        assert rows == con.execute("SELECT COUNT(*) FROM line").fetchone()[0] == 7080797
        assert con.execute("SELECT COUNT(DISTINCT bookId) FROM line").fetchone()[0] == 7876
        # Re-read just primary keys to prove every original SQL row appears once
        # and in order across the completed checkpoint partitions.
        keys=iter(con.execute("SELECT id FROM line ORDER BY id"))
        for part in parts:
            actual=hashlib.sha256();ids=[]
            for _ in range(part["rows"]):
                key=next(keys)[0];actual.update(f"{key}\n".encode())
                if not ids:ids.append(key)
                final=key
            assert ids[0]==part["firstLineID"] and final==part["lastLineID"]
            assert actual.hexdigest()==part["rowIDCoverageSHA256"]
        assert next(keys,None) is None
    finally:
        decoder.close();con.close()
    assert sha(original.DATABASE)==original.DATABASE_SHA
    counts={}
    for query in QUERIES:
        multiplicities=[row for part in parts for row in part["multiplicities"][query]]
        assert all(a[0]<b[0] for a,b in zip(multiplicities,multiplicities[1:]))
        digest=hashlib.sha256()
        for line_id,count in multiplicities:digest.update(f"{line_id}:{count}\n".encode())
        counts[query]=dict(occurrences=sum(row[1] for row in multiplicities),matchingLiveDocuments=len(multiplicities),
                           firstMatchingLineIDs=[row[0] for row in multiplicities[:25]],matchingLineMultiplicitySHA256=digest.hexdigest())
    result=dict(status="COMPLETE_INDEPENDENT_SQL_ORACLE_NOT_ENGINE_QUALIFICATION",database=str(original.DATABASE),
                databaseSHA256BeforeAndAfter=original.DATABASE_SHA,rowsScanned=rows,originalBooks=7876,
                candidateRowsTokenized=candidates,seconds=round(time.monotonic()-start,3),counts=counts,
                completedAt=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                independentScannerControls=validation["independentScannerControls"],regexGrammarControls=validation["regexGrammarControls"],
                newCRControls=validation["newCRControls"],retainedLFRejectionControls=validation["retainedLFRejectionControls"],
                actualNormalizationCrossChecks=sum(p["normalizationControls"] for p in parts),
                actualSQLScalarParityControls=sum(p["scalarControls"] for p in parts),
                actualCarriageReturnRows=sum(p["carriageReturnRows"] for p in parts),
                actualCarriageReturns=sum(p["carriageReturns"] for p in parts),
                retainedDictionaryByteParityControls=decoder.reference_checks,validationSHA256=sha(VALIDATION),
                partitionCount=len(parts),partitionSHA256={p.name:sha(p) for p in sorted(out.glob("partition-*.json"))},
                allOriginalRowIDsVerifiedExactlyOnce=True,sqliteVersion=sqlite3.sqlite_version,
                zstdDLLSHA256=sha(original.DLL),readOnlySQLiteMmapBytes=mmap_bytes,
                engineLoaded=False,indexRead=False,databaseDownloaded=False,partial=False,**sources())
    save_new(out/"RESULT.json",result)
    print(json.dumps(result,ensure_ascii=False),flush=True)


if __name__ == "__main__":
    main()

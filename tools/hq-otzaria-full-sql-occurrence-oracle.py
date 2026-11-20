#!/usr/bin/env python3
"""Bounded independent count of two exact tokens over EVERY original full-v32 SQL row.

No engine is loaded and no index is read. The necessary-condition text prefilter
only avoids tokenizing rows which cannot contain either token; all SQL contents
are still decoded and normalized. Final counts come from the independent token
position scanner, with per-row full-mini and sampled full-v32 scalar parity;
never from the prefilter or a search result candidate set.
"""
import argparse
import datetime
import hashlib
import json
import re
import random
import sqlite3
import time
from pathlib import Path

from otzaria_original_sql_oracle import (
    ATTACHED, BREAK_TAGS, GERESH, GERSHAYIM, PRESENTATION, TRANSPARENT, WORD_MARKS,
    OriginalZstd, display_text, self_check, token_positions,
)

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build/index-read-qualification-20261120"
DATABASE = Path(r"C:\Users\DAVID\Code\Maktabah-perf02-completion-20261120\build\perf02-20261120\full-v32\seforim.db")
DATABASE_SHA = "2f4dcd72e8bdb1fc5c0516ae9705e57759c017ec2981b49c35115625c3d3f765"
DLL = Path(r"C:\Users\DAVID\AppData\Local\Microsoft\WinGet\Packages\oschwartz10612.Poppler_Microsoft.Winget.Source_8wekyb3d8bbwe\poppler-25.07.0\Library\bin\libzstd.dll")
QUERIES = ("בראשית", "אברהם")
MARKUP = re.compile(r"<[^>]*>|&[^;]+;")
NAME = re.compile(r"/?([A-Za-z0-9]+)")
WHITESPACE_ENTITIES = re.compile(r"&(?:nbsp|thinsp|ensp|emsp);")
INGESTION_TRANSLATION = {ord(c): value for c, value in PRESENTATION.items()}
MARK_TRANSLATION = {ord(c): None for c in ATTACHED}
INGESTION_TRANSLATION.update(MARK_TRANSLATION)
PREFILTER_TRANSLATION = {ord(c): None for c in TRANSPARENT | WORD_MARKS | set(GERESH + GERSHAYIM)}
TOKEN_TRANSLATION = {ord(c): None for c in TRANSPARENT}
TOKEN_TRANSLATION.update({ord(c): "'" for c in GERESH})
TOKEN_TRANSLATION.update({ord(c): '"' for c in GERSHAYIM})
UNQUOTED_TRANSLATION = {ord(c): None for c in WORD_MARKS | set("'\"")}
# Explicitly for these short unquoted Hebrew queries. Marks remain in the
# boundary grammar until after a token is found, so quotes separated by a
# combining mark are not incorrectly treated as an invalid quote run.
CONTINUATION = r"(?:[^\W_]|[\u0300-\u036f])"
TOKEN_GRAMMAR = re.compile(r"[^\W_]" + CONTINUATION + "*" + r"(?:(?:''|'|\")" + CONTINUATION + "+)*'?")


def unquoted_counts(normalized):
    counts = {query: 0 for query in QUERIES}
    for match in TOKEN_GRAMMAR.finditer(normalized.translate(TOKEN_TRANSLATION)):
        token = match.group().translate(UNQUOTED_TRANSLATION).lower()
        if token in counts:
            counts[token] += 1
    return counts


def regex_controls():
    rng = random.Random(20261120)
    pieces = list(QUERIES) + ["א", "ברהם", "x", " ", "\n", "'", "''", "'''", '"', '""', "\u0300", "\u0307", ".", "[", "]", "\u200f", ",", "־"]
    for _ in range(5000):
        text = "".join(rng.choice(pieces) for _ in range(rng.randint(1, 20)))
        expected = {query: 0 for query in QUERIES}
        for terms in token_positions(text):
            for query in QUERIES:
                expected[query] += query in terms
        assert unquoted_counts(text) == expected, repr(text)
    return 5000


def sha(path):
    h = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(4 * 1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def normalize(raw):
    def replace(match):
        text = match.group()
        if text.startswith("<"):
            name = NAME.match(text[1:-1])
            if name and name.group(1).lower() in BREAK_TAGS:
                return " "
        return ""
    if "&" in raw:
        raw = WHITESPACE_ENTITIES.sub(" ", raw)
    if "<" in raw or "&" in raw:
        raw = MARKUP.sub(replace, raw)
    # Presentation decompositions may themselves contain attached marks.
    return raw.translate(INGESTION_TRANSLATION).translate(MARK_TRANSLATION)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--attempt", required=True)
    parser.add_argument("--deadline-seconds", type=int, default=3300)
    args = parser.parse_args()
    assert args.attempt and all(c in "abcdefghijklmnopqrstuvwxyz0123456789-_" for c in args.attempt)
    output = BUILD / "full-sql-global-oracle" / args.attempt
    assert not output.exists()
    output.mkdir(parents=True)
    start = time.monotonic()
    assert DATABASE.stat().st_size == 3821240320 and sha(DATABASE) == DATABASE_SHA
    connection = sqlite3.connect(DATABASE.as_uri() + "?mode=ro&immutable=1", uri=True)
    connection.execute("PRAGMA query_only=ON")
    connection.execute("PRAGMA cache_size=-65536")
    # Connection-only, read-only mapping of the already verified database.
    # Record SQLite's actual capped mapping rather than assuming the request.
    mmap_bytes = connection.execute("PRAGMA mmap_size=4294967296").fetchone()[0]
    decoder = OriginalZstd(connection, DLL)
    counts = {query: {"occurrences": 0, "matchingLiveDocuments": 0, "firstMatchingLineIDs": []} for query in QUERIES}
    digests = {query: hashlib.sha256() for query in QUERIES}
    rows = candidates = consistency_controls = scalar_parity_controls = 0
    controls = self_check()
    grammar_controls = regex_controls()
    try:
        for line_id, compressed in connection.execute("SELECT l.id,lc.content FROM line l JOIN line_content lc ON lc.id=l.id ORDER BY l.id"):
            raw = decoder.decode(compressed)
            assert "\n" not in raw and "\r" not in raw
            normalized = normalize(raw)
            if rows < 1000:
                assert " ".join(normalized.split()) == display_text(raw)
                consistency_controls += 1
            maybe = normalized.translate(PREFILTER_TRANSLATION).lower()
            if any(query in maybe for query in QUERIES):
                candidates += 1
                per_row = unquoted_counts(normalized)
                if candidates <= 1000 or line_id % 1009 == 0:
                    reference = {query: 0 for query in QUERIES}
                    for terms in token_positions(normalized):
                        for query in QUERIES:
                            reference[query] += query in terms
                    assert per_row == reference, f"independent regex/scalar discrepancy at original line {line_id}"
                    scalar_parity_controls += 1
                for query, count in per_row.items():
                    if count:
                        counts[query]["occurrences"] += count
                        counts[query]["matchingLiveDocuments"] += 1
                        if len(counts[query]["firstMatchingLineIDs"]) < 25:
                            counts[query]["firstMatchingLineIDs"].append(line_id)
                        digests[query].update(f"{line_id}:{count}\n".encode())
            rows += 1
            if rows % 100000 == 0:
                elapsed = time.monotonic() - start
                progress = {"rowsScanned": rows, "expectedRows": 7080797, "seconds": round(elapsed, 3), "candidateRows": candidates, "partialNotPublishable": True}
                (output / "PROGRESS.json").write_text(json.dumps(progress) + "\n", encoding="utf-8")
                print(json.dumps(progress), flush=True)
                assert elapsed < args.deadline_seconds, "bounded SQL oracle timeout; no complete count published"
        assert rows == connection.execute("SELECT COUNT(*) FROM line").fetchone()[0] == 7080797
        assert connection.execute("SELECT COUNT(DISTINCT bookId) FROM line").fetchone()[0] == 7876
    finally:
        decoder.close()
        connection.close()
    assert sha(DATABASE) == DATABASE_SHA
    result = {"status": "COMPLETE_INDEPENDENT_SQL_ORACLE_NOT_ENGINE_QUALIFICATION", "database": str(DATABASE),
              "databaseSHA256BeforeAndAfter": DATABASE_SHA, "rowsScanned": rows, "originalBooks": 7876,
              "candidateRowsTokenized": candidates, "seconds": round(time.monotonic() - start, 3),
              "counts": {query: dict(values, matchingLineMultiplicitySHA256=digests[query].hexdigest()) for query, values in counts.items()},
              "completedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "independentScannerControls": controls, "actualNormalizationCrossChecks": consistency_controls,
              "regexGrammarControls": grammar_controls, "actualSQLScalarParityControls": scalar_parity_controls,
              "retainedDictionaryByteParityControls": decoder.reference_checks,
              "sourceSHA256": sha(Path(__file__)), "scannerSHA256": sha(ROOT / "tools/otzaria_original_sql_oracle.py"),
              "sqliteVersion": sqlite3.sqlite_version, "zstdDLLSHA256": sha(DLL),
              "readOnlySQLiteMmapBytes": mmap_bytes,
              "engineLoaded": False, "indexRead": False, "databaseDownloaded": False, "partial": False}
    (output / "RESULT.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    main()

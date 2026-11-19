#!/usr/bin/env python3
"""Read-only independent source evidence for typed-action Native acceptance.

This never calls an app/provider or changes the database. It proves the exact
fixture relationship and source rows, not an Apple/native action result.
"""
import argparse
import hashlib
import html
import json
from pathlib import Path
import re
import shutil
import sqlite3
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument("--profile", type=Path, required=True)
parser.add_argument("--database", type=Path, required=True)
parser.add_argument("--archive", type=Path, required=True)
parser.add_argument("--output", type=Path, required=True)
args = parser.parse_args()
profile = json.loads(args.profile.read_text(encoding="utf-8"))
assert (profile["profileID"], profile["profileVersion"]) == ("miniTest10", 6)
digest = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
assert args.database.stat().st_size == profile["sourceDatabase"]["databaseBytes"] == 15470592
assert args.archive.stat().st_size == profile["databaseCompressedBytes"] == 7774478
before = digest(args.database)
assert before == profile["sourceDatabase"]["databaseSHA256"] == "d3d9bfcc2320a987a0391ad23fa72abcf6fd1fa0f3cba95adc05096e05a9edef"
assert digest(args.archive) == profile["databaseCompressedSHA256"] == "e9e6dedd2ceaadbe46234612c359e5bd8add00c348be8eaeba85cf029fa5c4d3"
sql = """
WITH matched(linkId, side) AS (
 SELECT id, 0 FROM link WHERE sourceBookId=28 AND sourceLineId=6188105
 UNION SELECT l.id, 0 FROM link_coverage c JOIN link l ON l.id=c.linkId
       WHERE c.side=0 AND c.lineId=6188105 AND l.sourceBookId=28
 UNION SELECT id, 1 FROM link WHERE targetBookId=28 AND targetLineId=6188105
 UNION SELECT l.id, 1 FROM link_coverage c JOIN link l ON l.id=c.linkId
       WHERE c.side=1 AND c.lineId=6188105 AND l.targetBookId=28
)
SELECT DISTINCT l.id, m.side, ct.name AS rawConnectionType,
 l.sourceBookId, l.targetBookId, l.sourceLineId, l.targetLineId,
 CASE m.side WHEN 0 THEN l.targetBookId ELSE l.sourceBookId END AS linkedBookID,
 CASE m.side WHEN 0 THEN l.targetLineId ELSE l.sourceLineId END AS linkedLineID
FROM matched m JOIN link l ON l.id=m.linkId
JOIN connection_type ct ON ct.id=l.connectionTypeId
WHERE (CASE m.side WHEN 0 THEN l.targetBookId ELSE l.sourceBookId END)=3276
 AND NOT EXISTS (SELECT 1 FROM link_suppressed_side s WHERE s.linkId=l.id AND s.side=m.side)
ORDER BY l.id, m.side
"""
connection = sqlite3.connect(args.database.resolve().as_uri() + "?mode=ro&immutable=1", uri=True)
connection.row_factory = sqlite3.Row
try:
    assert connection.execute("PRAGMA quick_check").fetchone()[0] == "ok"
    assert connection.execute("SELECT COUNT(*) FROM line").fetchone()[0] == 18879
    books = [dict(r) for r in connection.execute(
        "SELECT id,title,isBaseBook,dependenceType FROM book WHERE id IN (28,3276) ORDER BY id")]
    assert books[0]["id"] == 28 and books[0]["isBaseBook"] == 1
    assert books[1]["id"] == 3276 and books[1]["dependenceType"] == "commentary"
    links = [dict(r) for r in connection.execute(sql)]
    # Preserve the inverse REFERENCE too. The original classifier explicitly
    # classifies REFERENCE as .link, while forward COMMENTARY is .commentary.
    # Only the latter is eligible for the Core commentary action.
    assert [(r["id"], r["side"], r["rawConnectionType"]) for r in links] == [
        (6528846, 1, "REFERENCE"), (6529212, 0, "COMMENTARY")]
    commentary_links = [r for r in links if r["rawConnectionType"] == "COMMENTARY" and r["side"] == 0]
    assert len(commentary_links) == 1
    link = commentary_links[0]
    assert (link["id"], link["side"], link["rawConnectionType"], link["linkedLineID"]) == (6529212, 0, "COMMENTARY", 6609893)
    assert not list(connection.execute("SELECT * FROM link_suppressed_side WHERE linkId=6529212"))
    assert not list(connection.execute("SELECT * FROM link_coverage WHERE linkId=6529212"))
    dictionary = connection.execute("SELECT dict FROM zstd_dict ORDER BY id LIMIT 1").fetchone()[0]
    rows = []
    with tempfile.TemporaryDirectory(prefix="otzaria-native-source-") as temporary:
        dictionary_path = Path(temporary) / "source.dict"
        dictionary_path.write_bytes(dictionary)
        for line_id, book_id, line_index in [(6188105, 28, 2), (6609893, 3276, 4)]:
            row = connection.execute(
                "SELECT l.id,l.bookId,l.lineIndex,l.heRef,c.content FROM line l JOIN line_content c ON c.id=l.id WHERE l.id=?",
                (line_id,)).fetchone()
            assert tuple(row[:3]) == (line_id, book_id, line_index)
            raw = row[4]
            if isinstance(raw, bytes):
                zstd = shutil.which("zstd")
                assert zstd, "Original zstd dictionary decompression requires the zstd CLI"
                raw = subprocess.run([zstd, "-d", "--stdout", "-D", str(dictionary_path)], input=raw,
                                     stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True, timeout=20).stdout.decode("utf-8")
            plain = html.unescape(re.sub("<[^>]*>", "", raw)).strip()
            rows.append({"id": row[0], "bookId": row[1], "lineIndex": row[2], "heRef": row[3],
                         "html": raw, "plainText": plain, "plainSHA256": hashlib.sha256(plain.encode()).hexdigest()})
finally:
    connection.close()
assert digest(args.database) == before, "Read-only inspection must preserve exact source bytes"
report = {
    "kind": "INDEPENDENT_SOURCE_RELATION_AND_TEXT_NOT_NATIVE_PASS",
    "profileID": "miniTest10", "profileVersion": 6, "databaseBytes": args.database.stat().st_size,
    "databaseSHA256": before, "archiveSHA256": digest(args.archive),
    "dictionarySHA256": hashlib.sha256(dictionary).hexdigest(),
    "scriptSHA256": digest(Path(__file__)), "profileSHA256": digest(args.profile),
    "quickCheck": "ok", "readOnly": True, "databaseUnchanged": True,
    "sql": sql.strip(), "books": books, "links": links, "eligibleCommentaryLinks": commentary_links,
    "excludedReferenceLinkIDs": [6528846], "classificationSource": "Source/Otzaria/Reading/OtzariaRelationshipClassifier.swift",
    "suppressedSides": [], "coverage": [], "rows": rows,
}
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
print(json.dumps({"output": str(args.output), "sha256": digest(args.output), "linkID": link["id"],
                  "rows": [{"id": r["id"], "plainSHA256": r["plainSHA256"]} for r in rows]}))

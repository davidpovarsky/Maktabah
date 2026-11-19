#!/usr/bin/env python3
"""Freeze exact native routing text from the immutable original miniTest10 SQL."""
import argparse
import hashlib
import json
from html.parser import HTMLParser
from pathlib import Path
import sqlite3
import zstandard

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--database", type=Path, required=True)
parser.add_argument("--output", type=Path, required=True)
args = parser.parse_args()
profile = json.loads((ROOT / "Source/Otzaria/DataProfiles/miniTest10.profile.json").read_text(encoding="utf-8"))
database = args.database.resolve()
before = hashlib.sha256(database.read_bytes()).hexdigest()
assert before == profile["sourceDatabase"]["databaseSHA256"]
assert database.stat().st_size == profile["sourceDatabase"]["databaseBytes"]
assert not args.output.exists(), "Preserve the previous sealed oracle"
connection = sqlite3.connect(database.as_uri() + "?mode=ro&immutable=1", uri=True)
dictionaries = [zstandard.ZstdCompressionDict(row[0]) for row in connection.execute("SELECT dict FROM zstd_dict")]
decoders = {item.dict_id(): zstandard.ZstdDecompressor(dict_data=item) for item in dictionaries}
bootstrap_sql = """SELECT l.sourceBookId, sourceLine.id, sourceLine.lineIndex
FROM link l JOIN line sourceLine ON sourceLine.id = l.sourceLineId ORDER BY l.id LIMIT 1"""
bootstrap = connection.execute(bootstrap_sql).fetchone()
assert bootstrap is not None
book, initial_id, initial_index = bootstrap
nonzero = connection.execute("SELECT id FROM line WHERE bookId = ? AND lineIndex > 0 ORDER BY lineIndex", [book]).fetchall()
assert len(nonzero) > 10
ids = sorted({1, 2, 2634912, initial_id, nonzero[0][0], nonzero[9][0]})
class PlainSource(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.parts = []
    def handle_data(self, data):
        self.parts.append(data)
    def handle_starttag(self, tag, attrs):
        if tag == "br":
            self.parts.append("\n")
    def handle_endtag(self, tag):
        if tag in {"p", "div", "h1", "h2", "h3", "h4", "h5", "h6", "li"}:
            self.parts.append("\n")

rows = []
for line_id in ids:
    record = connection.execute("""SELECT l.id, l.bookId, l.lineIndex, lc.content
FROM line l JOIN line_content lc ON lc.id=l.id WHERE l.id=?""", [line_id]).fetchone()
    assert record is not None
    _, book_id, index, content = record
    if isinstance(content, bytes):
        frame = zstandard.get_frame_parameters(content)
        assert frame.content_size <= 16 * 1024 * 1024
        content = decoders[frame.dict_id].decompress(content).decode("utf-8")
    assert isinstance(content, str)
    plain = PlainSource()
    plain.feed(content)
    text = "".join(plain.parts).strip()
    assert text
    rows.append({"id": line_id, "bookId": book_id, "lineIndex": index,
                 "sourceHTML": content, "plainText": text,
                 "plainSHA256": hashlib.sha256(text.encode()).hexdigest()})
connection.close()
assert hashlib.sha256(database.read_bytes()).hexdigest() == before
output = {"profileID": profile["profileID"], "profileVersion": profile["profileVersion"],
          "databaseSHA256": before,
          "purpose": "Independent read-only SQL/Zstandard source text; exact installed Native Reader oracle, including short headings. No production renderer or app output used.",
          "bootstrapRowID": initial_id, "bootstrapSQL": bootstrap_sql, "rows": rows}
data = (json.dumps(output, ensure_ascii=False, indent=2) + "\n").encode()
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_bytes(data)
print(json.dumps({"path": str(args.output), "sha256": hashlib.sha256(data).hexdigest(),
                  "bootstrap": list(bootstrap),
                  "rows": [{"id": x["id"], "book": x["bookId"], "line": x["lineIndex"],
                            "plain_characters": len(x["plainText"])} for x in rows],
                  "database_unchanged": True}, ensure_ascii=False))

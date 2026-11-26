#!/usr/bin/env python3
"""Read-only identity selection; not a replacement for the real Swift catalog."""
import collections
import hashlib
import json
from pathlib import Path
import sqlite3
import sys

path = Path(sys.argv[1]).resolve(strict=True)
expected = "8389709c1702753af6f0719ef1c98c09854450e48ebb05fe1f95486b26348b01"
with path.open("rb") as stream:
    sha = hashlib.file_digest(stream, "sha256").hexdigest()
assert path.stat().st_size == 4355063808 and sha == expected, "Not the exact full v40 database"
with sqlite3.connect(path.as_uri() + "?mode=ro&immutable=1", uri=True) as sql:
    sql.execute("PRAGMA query_only=ON")
    books = [dict(zip(("bookID", "title", "lineCount"), row)) for row in sql.execute(
        "SELECT b.id,b.title,COUNT(l.id) FROM book b JOIN line l ON l.bookId=b.id WHERE b.id IN(103,28,3152) GROUP BY b.id ORDER BY CASE b.id WHEN 103 THEN 0 WHEN 28 THEN 1 ELSE 2 END")]
    entries = {row[0]: (row[1], row[2]) for row in sql.execute(
        "SELECT id,parentId,COALESCE(level,0) FROM tocEntry WHERE bookId=8042")}
    children = collections.defaultdict(list)
    for entry, (parent, level) in entries.items():
        if parent is not None: children[parent].append(entry)
    leaves = {}
    for line, entry in sql.execute("SELECT l.lineIndex,lt.tocEntryId FROM line l LEFT JOIN line_toc lt ON lt.lineId=l.id WHERE l.bookId=8042 ORDER BY l.lineIndex,lt.tocEntryId"):
        if entry in entries and (line not in leaves or entries[leaves[line]][1] < entries[entry][1]): leaves[line] = entry
    root_counts = collections.Counter(leaf for leaf in leaves.values() if entries[leaf][0] is None and children[leaf])
    held_roots = {entry for entry, count in root_counts.items() if count <= 3}
    def root(entry):
        seen = set()
        while entry in entries and entries[entry][0] in entries:
            assert entry not in seen, "TOC cycle"
            seen.add(entry)
            entry = entries[entry][0]
        return entry
    def chapter(leaf):
        current = best = leaf
        seen = set()
        while current in entries:
            assert current not in seen, "TOC cycle"
            seen.add(current)
            parent = entries[current][0]
            if parent not in entries: return best
            if entries[parent][0] is not None: best = parent
            current = parent
        return best
    groups, held = {}, collections.defaultdict(list)
    for line, leaf in sorted(leaves.items()):
        if leaf in held_roots:
            held[leaf].append(line)
            continue
        entry = chapter(leaf)
        if entry not in groups: groups[entry] = held.pop(root(entry), [])
        groups[entry].append(line)
    for entry, lines in sorted(held.items()): groups.setdefault(entry, lines)
    selected = [(entry, sorted(lines)) for entry, lines in groups.items() if len(lines) == 52332]
    assert len(selected) == 1, "Retained 52,332-row chapter is not unique"
    entry, lines = selected[0]
    title = sql.execute("SELECT COALESCE(tt.text,'') FROM tocEntry te LEFT JOIN tocText tt ON tt.id=te.textId WHERE te.id=?", (entry,)).fetchone()[0]
    counts = {name: sql.execute("SELECT COUNT(*) FROM " + name).fetchone()[0] for name in ("book", "line", "link")}
    assert counts == {"book": 8259, "line": 7925185, "link": 7001824}
    result = {"status": "READ_ONLY_IDENTITY_SELECTION_NOT_SWIFT_OR_UI_ACCEPTANCE", "database": {"path": str(path), "bytes": path.stat().st_size, "sha256": sha}, "counts": counts,
        "catalog_targets": {"books": books, "retainedChapter": {"bookID": 8042, "focusLineIndex": lines[len(lines)//2], "unitID": "toc:"+str(entry), "unitRowCount": len(lines), "unitStartLineIndex": min(lines), "unitEndLineIndex": max(lines), "sourceUTF16Length": 8307947}},
        "retained_chapter_title": title, "retained_source_length_requires_actual_swift_revalidation": True,
        "recipe_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
print(json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2))

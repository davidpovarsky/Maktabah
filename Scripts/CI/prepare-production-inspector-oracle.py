#!/usr/bin/env python3
"""Derive bounded Inspector semantic oracles from admitted immutable full v40.

This reads the original SQLite corpus and its retained whole-file hash witness.
It does not import an application cache, mutate a database, or grant UI acceptance.
"""
import argparse
import ctypes
import ctypes.util
import hashlib
import html
from html.parser import HTMLParser
import json
from pathlib import Path
import sqlite3
import unicodedata

V40_SHA = "8389709c1702753af6f0719ef1c98c09854450e48ebb05fe1f95486b26348b01"
AUTHORS = {
    "twoWorks": "רבי דוד אלטשולר",
    "quoting": "רבי אברהם סבע",
    "similarA": 'רבנו משה בן מימון [הרמב"ם]',
    "similarB": 'רבנו משה ב"ר נחמן [הרמב"ן]',
}
COMMENTARY_TYPES = {
    "COMMENTARY": "פירוש", "SUPER_COMMENTARY": "סופר-פירוש",
    "PARSHANUT": "פרשנות", "DIBUR_HAMATCHIL": "דיבור המתחיל",
    "ELUCIDATION": "ביאור", "EXPLICATION": "הסבר", "FOOTNOTES": "הערות",
    "OTHER": "פירוש", "RELATED": "פירוש", "LINKER": "פירוש",
    "ESSAY": "פירוש", "ALLUSION": "פירוש", "LITURGY": "פירוש",
    "LAW": "פירוש", "SUMMARY": "פירוש",
}
INVERSE_TYPES = tuple(COMMENTARY_TYPES.keys() - {"LINKER"}) + (
    "TARGUM", "MIDRASH", "REFERENCE", "QUOTATION", "MESORAT_HASHAS",
    "EIN_MISHPAT", "MISHNAH_IN_TALMUD", "SIFREI_MITZVOT",
)


def require(value, message):
    if not value:
        raise RuntimeError(message)


def stat(path):
    s = path.stat()
    return dict(device=s.st_dev, inode=s.st_ino, bytes=s.st_size,
                mtime_ns=s.st_mtime_ns, ctime_ns=s.st_ctime_ns, mode=s.st_mode)


class PlainHTML(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.parts = []

    def handle_data(self, data):
        self.parts.append(data)

    def handle_starttag(self, tag, attrs):
        if tag in ("p", "br", "div", "h1", "h2", "h3", "li"):
            self.parts.append(" ")

    def handle_endtag(self, tag):
        if tag in ("p", "div", "h1", "h2", "h3", "li"):
            self.parts.append(" ")


def plain(value):
    parser = PlainHTML()
    parser.feed(value)
    return " ".join(unicodedata.normalize("NFC", html.unescape("".join(parser.parts))).split())


class Decoder:
    def __init__(self, sql):
        self.lib = ctypes.CDLL(ctypes.util.find_library("zstd"))
        self.lib.ZSTD_createDCtx.restype = ctypes.c_void_p
        self.lib.ZSTD_getFrameContentSize.argtypes = [ctypes.c_void_p, ctypes.c_size_t]
        self.lib.ZSTD_getFrameContentSize.restype = ctypes.c_ulonglong
        self.lib.ZSTD_getDictID_fromFrame.argtypes = [ctypes.c_void_p, ctypes.c_size_t]
        self.lib.ZSTD_getDictID_fromFrame.restype = ctypes.c_uint
        self.lib.ZSTD_decompress_usingDict.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t,
            ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t]
        self.lib.ZSTD_decompress_usingDict.restype = ctypes.c_size_t
        self.lib.ZSTD_isError.argtypes = [ctypes.c_size_t]
        self.lib.ZSTD_isError.restype = ctypes.c_uint
        self.context = self.lib.ZSTD_createDCtx()
        require(self.context, "Cannot allocate bounded source decoder")
        self.dictionaries = dict(sql.execute("SELECT id,dict FROM zstd_dict"))

    def decode(self, content):
        if isinstance(content, str):
            return content
        require(content[:4] == b"\x28\xb5\x2f\xfd", "Unknown source compression")
        size = self.lib.ZSTD_getFrameContentSize(content, len(content))
        require(0 < size <= 4 * 1024 * 1024, "Source sample exceeds bounded decoder")
        dictionary_id = self.lib.ZSTD_getDictID_fromFrame(content, len(content))
        dictionary = self.dictionaries.get(dictionary_id, b"")
        require(dictionary_id == 0 or dictionary, "Original source dictionary is absent")
        output = ctypes.create_string_buffer(size)
        count = self.lib.ZSTD_decompress_usingDict(self.context, output, size,
            content, len(content), dictionary, len(dictionary))
        require(not self.lib.ZSTD_isError(count) and count == size, "Original source decompression failed")
        return output.raw[:count].decode("utf-8", errors="strict")


def members(sql, start, end, author_ids):
    # The three Psalms windows are base-book units. Only explicitly admitted,
    # non-base commentary works by the selected SQL authors become group oracles.
    # Forward/inverse membership includes ranges and suppression; it is never
    # inferred from a visible row count or a warmed application cache.
    values = ",".join("?" for _ in INVERSE_TYPES)
    author_values = ",".join("?" for _ in author_ids)
    query = f"""
    WITH win(id) AS (SELECT id FROM line WHERE bookId=28 AND lineIndex BETWEEN ? AND ?),
    matched(linkId,side) AS (
      SELECT id,0 FROM link WHERE sourceBookId=28 AND sourceLineId IN (SELECT id FROM win)
      UNION SELECT k.id,0 FROM link k JOIN link_coverage c ON c.linkId=k.id
        WHERE k.sourceBookId=28 AND c.side=0 AND c.lineId IN (SELECT id FROM win)
      UNION SELECT id,1 FROM link WHERE targetBookId=28 AND targetLineId IN (SELECT id FROM win)
      UNION SELECT k.id,1 FROM link k JOIN link_coverage c ON c.linkId=k.id
        WHERE k.targetBookId=28 AND c.side=1 AND c.lineId IN (SELECT id FROM win)
    )
    SELECT DISTINCT m.side,k.id,ct.name,b.id,b.title,b.isBaseBook,b.dependenceType,
      l.id,l.lineIndex,l.heRef,a.id,a.name
    FROM matched m JOIN link k ON k.id=m.linkId
    JOIN connection_type ct ON ct.id=k.connectionTypeId
    JOIN book b ON b.id=CASE m.side WHEN 0 THEN k.targetBookId ELSE k.sourceBookId END
    JOIN line l ON l.id=CASE m.side WHEN 0 THEN k.targetLineId ELSE k.sourceLineId END
    JOIN book_author ba ON ba.bookId=b.id JOIN author a ON a.id=ba.authorId
    WHERE b.id!=28 AND a.id IN ({author_values})
      AND NOT EXISTS(SELECT 1 FROM link_suppressed_side hidden WHERE hidden.linkId=k.id AND hidden.side=m.side)
      AND (m.side=0 OR ct.name IN ({values}))
    ORDER BY b.id,l.lineIndex,ct.name,m.side,k.id
    """
    groups = {}
    for side, edge, raw_type, book_id, title, is_base, dependence, line_id, index, ref, author_id, name in sql.execute(
            query, (start, end, *author_ids, *INVERSE_TYPES)):
        if is_base or dependence != "commentary":
            continue
        author_count = sql.execute("SELECT COUNT(*) FROM book_author WHERE bookId=?", (book_id,)).fetchone()[0]
        require(author_count == 1, "Curated author oracle must not guess multi-author display policy")
        if raw_type == "QUOTATION":
            kind, display_type, category = "quotingCommentary", "ציטוט פירוש", "Quoting Commentary"
        elif raw_type in COMMENTARY_TYPES:
            kind, display_type, category = "commentary", COMMENTARY_TYPES[raw_type], "Commentary"
        else:
            # Explicit reference/source/Targum/Midrash/Halakhah links belong
            # to the Links tool and are not commentary-group membership.
            continue
        require(ref and "|" not in ref, "Selected source requires an unambiguous original human reference")
        source_id = f"otzaria:book:{book_id}|otzaria:v1:{book_id}:{index}|{display_type}|{category}||{ref}"
        key = kind + "|" + str(author_id)
        group = groups.setdefault(key, dict(authorID=author_id, author=name, kind=kind,
            groupID="author:" + name, members={}))
        source = group["members"].setdefault(source_id, dict(id=source_id, bookID=book_id,
            bookTitle=title, lineID=line_id, lineIndex=index, heRef=ref,
            sourceRef=f"otzaria:v1:{book_id}:{index}", category=category,
            displayType=display_type, rawEdges=[]))
        source["rawEdges"].append(dict(id=edge, matchedSide=side, connectionType=raw_type))
    return groups


def finish_groups(groups, sql, decoder, include_text):
    result = []
    for group in groups.values():
        rows = list(group["members"].values())
        works = sorted(set(row["bookID"] for row in rows))
        samples = []
        for book_id in works:
            row = next(row for row in rows if row["bookID"] == book_id)
            if include_text and ("תהילים" in row["bookTitle"] or group["kind"] == "quotingCommentary"):
                raw = sql.execute("SELECT content FROM line_content WHERE id=?", (row["lineID"],)).fetchone()[0]
                decoded = decoder.decode(raw)
                row = dict(row, plainText=plain(decoded),
                    decodedHTMLSHA256=hashlib.sha256(decoded.encode()).hexdigest())
                require(row["plainText"], "Original linked-line content cannot be empty")
                samples.append(row)
        result.append({k: v for k, v in group.items() if k != "members"} | dict(
            count=len(rows), workIDs=works, memberIDs=sorted(group["members"]),
            samples=samples[:4]))
    return sorted(result, key=lambda row: (row["kind"], row["authorID"]))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--database", type=Path, required=True)
    parser.add_argument("--identity", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    path = args.database.resolve(strict=True)
    identity_bytes = args.identity.read_bytes()
    identity = json.loads(identity_bytes)
    require(identity["status"] == "EXACT_V40_READ_ONLY_HASH_ADMITTED" and
        identity["database_sha256"] == V40_SHA and identity["database_path"] == str(path),
        "A matching actual full-v40 hash admission is required")
    before = stat(path)
    require(before == identity["stat_after"] and before["bytes"] == 4355063808,
            "Source changed after whole-file admission")
    require(not args.output.exists(), "Refuse to replace an existing oracle")
    sql = sqlite3.connect(path.as_uri() + "?mode=ro&immutable=1", uri=True)
    sql.execute("PRAGMA query_only=ON")
    decoder = Decoder(sql)
    author_ids = {}
    for role, name in AUTHORS.items():
        found = sql.execute("SELECT id FROM author WHERE name=?", (name,)).fetchall()
        require(len(found) == 1, "The declared real author must exist uniquely: " + name)
        author_ids[role] = found[0][0]
    chapters = sql.execute("""SELECT e.id,t.text,l.lineIndex FROM tocEntry e
        JOIN tocText t ON t.id=e.textId JOIN line l ON l.id=e.lineId
        WHERE e.bookId=28 AND e.level=1 ORDER BY l.lineIndex""").fetchall()
    require(len(chapters) == 150, "The full source must have 150 real Psalms chapters")
    cases = []
    for ordinal in (1, 75, 150):
        toc_id, title, start = chapters[ordinal - 1]
        end = chapters[ordinal][2] - 1 if ordinal < 150 else 2677
        groups = finish_groups(members(sql, start, end, tuple(author_ids.values())), sql, decoder, True)
        david = next(row for row in groups if row["authorID"] == author_ids["twoWorks"] and row["kind"] == "commentary")
        require({3323, 3436}.issubset(david["workIDs"]), "Each of three chapters needs the same author across both actual Psalms works")
        require(any(row["authorID"] == author_ids["quoting"] and row["kind"] == "quotingCommentary" for row in groups),
                "Each chapter requires genuine quoting-commentary payloads")
        lines = []
        for line_id, index, ref, content in sql.execute("""SELECT l.id,l.lineIndex,l.heRef,c.content
                FROM line l JOIN line_content c ON c.id=l.id
                WHERE l.bookId=28 AND l.lineIndex BETWEEN ? AND ? ORDER BY l.lineIndex""", (start, end)):
            lines.append(dict(lineID=line_id, lineIndex=index, heRef=ref, plainText=plain(decoder.decode(content)),
                groups=finish_groups(members(sql, index, index, tuple(author_ids.values())), sql, decoder, False)))
        cases.append(dict(chapter=ordinal, tocID=toc_id, tocTitle=title,
            startLineIndex=start, endLineIndex=end, groups=groups, lines=lines))
    last = cases[-1]
    require(all(any(g["authorID"] == author_ids[role] and g["kind"] == "commentary" for g in last["groups"])
        for role in ("similarA", "similarB")), "Last chapter must retain both similarly named authors as distinct real groups")
    require(stat(path) == before, "Read-only oracle source changed during derivation")
    result = dict(schema=1, status="SOURCE_ORACLE_PREPARED_UI_NOT_RUN", databaseSHA256=V40_SHA,
        databaseBytes=before["bytes"], releaseID=455390662, releaseTag="v40-20261123094345",
        kitRevision="23db0f84e88d9ee9c7053c49de86903fc7bb5785", bookID=28, bookTitle="תהילים",
        authors={role: dict(id=author_ids[role], name=name) for role, name in AUTHORS.items()}, cases=cases,
        identityReceiptSHA256=hashlib.sha256(identity_bytes).hexdigest(), statBefore=before, statAfter=stat(path),
        scope="Original immutable SQL author/work/line payloads for three real chapters; no UI execution or performance claim")
    encoded = json.dumps(result, ensure_ascii=False, indent=2).encode() + b"\n"
    require(len(encoded) <= 2_000_000, "Semantic oracle exceeds its declared bound")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("xb") as output:
        output.write(encoded)
    print(json.dumps(dict(status=result["status"], output=str(args.output), bytes=len(encoded),
        sha256=hashlib.sha256(encoded).hexdigest(), chapterGroups=[dict(chapter=c["chapter"], groups=[
            dict(author=g["author"], kind=g["kind"], count=g["count"], works=len(g["workIDs"])) for g in c["groups"]]) for c in cases]), ensure_ascii=False))


if __name__ == "__main__":
    main()

"""Independent SQL/text oracle for the original265 single-token index contract.

This module does not import the search engine, inspect postings, or obtain expected
counts from either executable. Its explicit character/HTML rules follow the
unchanged producer's published ingestion specification. It scans original SQL
rows, decompresses their original Zstandard dictionaries, and counts positions.
It is qualification tooling, never an application tokenizer or fallback.
"""
import ctypes
import hashlib
import re
import sqlite3
import unicodedata
from collections import Counter
from pathlib import Path

BREAK_TAGS = set("address article aside blockquote br caption center dd div dl dt figcaption figure footer h1 h2 h3 h4 h5 h6 header hr li main nav ol p pre section table tbody td tfoot th thead tr ul".split())
GERESH = "'\u05f3\u2018\u2019"
GERSHAYIM = '"\u05f4\u201c\u201d'
TRANSPARENT = set("*[]^$\\+.~`") | set(map(chr, range(0x200b, 0x2010))) | set(map(chr, range(0x202a, 0x202f))) | set(map(chr, range(0x2066, 0x206a))) | {"\ufeff"}
ATTACHED = set(map(chr, range(0x591, 0x5c8))) - set("\u05be\u05c0\u05c3\u05c6")
WORD_MARKS = ATTACHED | set(map(chr, range(0x300, 0x370))) | {"\ufb1e"}
PRESENTATION = {chr(n): unicodedata.normalize("NFKD", chr(n)) for n in range(0xfb1d, 0xfb50) if n != 0xfb29}
PRESENTATION["\ufb1e"] = ""


def display_text(raw, pdf=False):
    """Original text field ingestion; deliberately NOT HTML entity decoding."""
    for entity in ("&nbsp;", "&thinsp;", "&ensp;", "&emsp;"):
        raw = raw.replace(entity, " ")

    def tag(match):
        name = re.match(r"/?([A-Za-z0-9]+)", match.group()[1:-1])
        return " " if name and name.group(1).lower() in BREAK_TAGS else ""

    text = re.sub(r"<[^>]*>|&[^;]+;", lambda m: tag(m) if m.group().startswith("<") else "", raw)
    folded = "".join(PRESENTATION.get(c, c) for c in text)
    if pdf:
        folded = "".join(c for c in folded if c not in TRANSPARENT or c in "*[]^$\\+.~`")
    return " ".join("".join(c for c in folded if c not in ATTACHED).split())


def token_positions(text):
    """One set of index terms per genuine position; quote twin is not extra count."""
    def word(c):
        return c.isalnum() or c in WORD_MARKS

    position = 0
    while position < len(text):
        while position < len(text) and (not text[position].isalnum() or text[position] in WORD_MARKS):
            position += 1
        if position >= len(text):
            return
        start = position
        end = position
        while True:
            while end < len(text) and word(text[end]):
                end += 1
            cursor = end
            singles = doubles = 0
            first_quote_end = None
            first_single = False
            while cursor < len(text):
                char = text[cursor]
                if char in GERESH + GERSHAYIM:
                    if first_quote_end is None:
                        first_quote_end = cursor + 1
                        first_single = char in GERESH
                    singles += char in GERESH
                    doubles += char in GERSHAYIM
                elif char not in TRANSPARENT:
                    break
                cursor += 1
            if cursor < len(text) and word(text[cursor]) and (singles, doubles) in ((0, 0), (1, 0), (2, 0), (0, 1)):
                end = cursor
                continue
            if not (cursor < len(text) and word(text[cursor])) and first_single:
                end = first_quote_end
            break
        spelling = []
        for char in text[start:end]:
            if char in WORD_MARKS or char in TRANSPARENT:
                continue
            if char in GERESH:
                if spelling and spelling[-1] == "'":
                    spelling.pop()
                    if not spelling or spelling[-1] != '"':
                        spelling.append('"')
                else:
                    spelling.append("'")
            elif char in GERSHAYIM:
                if not spelling or spelling[-1] != '"':
                    spelling.append('"')
            else:
                spelling.extend(c for c in PRESENTATION.get(char, char) if c not in ATTACHED)
        token = "".join(spelling)
        terms = {token}
        if "'" in token or '"' in token:
            terms.add(token.replace("'", "").replace('"', ""))
        # Tantivy RemoveLongFilter precedes LowerCaser and rejects >=128 bytes.
        terms = {item.lower() for item in terms if item and len(item.encode("utf-8")) < 128}
        if terms:
            yield terms
        position = end


class OriginalZstd:
    def __init__(self, connection, dll):
        self.lib = ctypes.CDLL(str(dll))
        declarations = {
            "ZSTD_getFrameContentSize": (ctypes.c_ulonglong, [ctypes.c_void_p, ctypes.c_size_t]),
            "ZSTD_getDictID_fromFrame": (ctypes.c_uint, [ctypes.c_void_p, ctypes.c_size_t]),
            "ZSTD_getDictID_fromDict": (ctypes.c_uint, [ctypes.c_void_p, ctypes.c_size_t]),
            "ZSTD_createDCtx": (ctypes.c_void_p, []),
            "ZSTD_freeDCtx": (ctypes.c_size_t, [ctypes.c_void_p]),
            "ZSTD_createDDict": (ctypes.c_void_p, [ctypes.c_void_p, ctypes.c_size_t]),
            "ZSTD_freeDDict": (ctypes.c_size_t, [ctypes.c_void_p]),
            "ZSTD_decompress_usingDict": (ctypes.c_size_t, [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t]),
            "ZSTD_decompress_usingDDict": (ctypes.c_size_t, [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p]),
            "ZSTD_isError": (ctypes.c_uint, [ctypes.c_size_t]),
        }
        for name, (restype, argtypes) in declarations.items():
            fn = getattr(self.lib, name); fn.restype = restype; fn.argtypes = argtypes
        self.context = self.lib.ZSTD_createDCtx()
        assert self.context
        self.dictionaries = {}
        self.prepared_dictionaries = {}
        self.reference_checks = 0
        for row in connection.execute("SELECT dict FROM zstd_dict"):
            data = bytes(row[0])
            key = self.lib.ZSTD_getDictID_fromDict(data, len(data))
            assert key not in self.dictionaries
            self.dictionaries[key] = data
            prepared = self.lib.ZSTD_createDDict(data, len(data))
            assert prepared
            self.prepared_dictionaries[key] = prepared

    def decode(self, content):
        if isinstance(content, str):
            return content
        assert isinstance(content, bytes)
        size = self.lib.ZSTD_getFrameContentSize(content, len(content))
        assert 0 <= size <= 16 * 1024 * 1024, "reject unknown or unbounded frame"
        dictionary_id = self.lib.ZSTD_getDictID_fromFrame(content, len(content))
        dictionary = self.dictionaries[dictionary_id] if dictionary_id else b""
        prepared = self.prepared_dictionaries[dictionary_id] if dictionary_id else None
        output = ctypes.create_string_buffer(max(size, 1))
        actual = self.lib.ZSTD_decompress_usingDDict(self.context, output, size, content, len(content), prepared)
        assert not self.lib.ZSTD_isError(actual) and actual == size
        if self.reference_checks < 32:
            reference = ctypes.create_string_buffer(max(size, 1))
            previous = self.lib.ZSTD_decompress_usingDict(self.context, reference, size, content, len(content), dictionary, len(dictionary))
            assert not self.lib.ZSTD_isError(previous) and previous == size
            assert reference.raw[:size] == output.raw[:size]
            self.reference_checks += 1
        return output.raw[:size].decode("utf-8")

    def close(self):
        if self.context:
            assert not self.lib.ZSTD_isError(self.lib.ZSTD_freeDCtx(self.context))
            self.context = None
            for prepared in self.prepared_dictionaries.values():
                assert not self.lib.ZSTD_isError(self.lib.ZSTD_freeDDict(prepared))
            self.prepared_dictionaries.clear()


def self_check():
    examples = [
        ("א.ב", [{"אב"}]), ("יב[ע]ר", [{"יבער"}]),
        ("שלום,עולם", [{"שלום"}, {"עולם"}]),
        ("כי־גר", [{"כי"}, {"גר"}]),
        ("תוס'", [{"תוס'", "תוס"}]),
        ('רמב"ם', [{'רמב"ם', "רמבם"}]),
        ("רמב''ם", [{'רמב"ם', "רמבם"}]),
        ('רמב"', [{"רמב"}]),
        ("שָׁלוֹם", [{"שלום"}]),
        ("שָׁלוֹם", [{"שלום"}]),
        ("שלום\u200fשלום", [{"שלוםשלום"}]),
        ("תורה תורה", [{"תורה"}, {"תורה"}]),
        ("A" * 128, []), ("A" * 127, [{"a" * 127}]),
    ]
    for raw, expected in examples:
        assert list(token_positions(display_text(raw))) == expected, raw
    assert display_text("א</p><p>ב") == "א ב"
    assert display_text("מי<b>לה") == "מילה"
    assert display_text("a&amp;b") == "ab"
    assert display_text("לאמר&nbsp;שירה") == "לאמר שירה"
    return len(examples) + 4


def scan(connection, decoder, book_ids, queries):
    assert book_ids and all(isinstance(n, int) and n > 0 for n in book_ids)
    terms = {}
    for query in queries:
        positions = list(token_positions(query))
        assert len(positions) == 1
        # Query analyzer does not emit a quote-free twin.
        value = next(iter(positions[0])) if len(positions[0]) == 1 else next(x for x in positions[0] if "'" in x or '"' in x)
        terms[query] = value
    counts = {query: {"occurrences": 0, "matchingLiveDocuments": 0, "books": {}} for query in queries}
    rows = {}
    digests = {book: hashlib.sha256() for book in book_ids}
    total_rows = 0
    sql = "SELECT l.id,l.bookId,l.lineIndex,lc.content FROM line l JOIN line_content lc ON lc.id=l.id WHERE l.bookId IN (" + ",".join("?" for _ in book_ids) + ") ORDER BY l.bookId,l.lineIndex"
    for line_id, book_id, line_index, content in connection.execute(sql, book_ids):
        raw = decoder.decode(content)
        assert "\n" not in raw and "\r" not in raw, "SQL line must map to one producer text document"
        normalized = display_text(raw)
        position_counts = Counter(term for variants in token_positions(normalized) for term in variants)
        rows[(book_id, line_index)] = (line_id, raw, normalized)
        digest = digests[book_id]
        digest.update(f"{line_id}\0{line_index}\0".encode()); digest.update(raw.encode()); digest.update(b"\0")
        total_rows += 1
        for query, term in terms.items():
            occurrence_count = position_counts[term]
            result = counts[query]
            result["occurrences"] += occurrence_count
            result["matchingLiveDocuments"] += occurrence_count > 0
            book = result["books"].setdefault(str(book_id), {"occurrences": 0, "matchingLiveDocuments": 0})
            book["occurrences"] += occurrence_count
            book["matchingLiveDocuments"] += occurrence_count > 0
    return {"rowsScanned": total_rows, "bookIds": book_ids, "queries": counts,
            "decodedBookSHA256": {str(k): v.hexdigest() for k, v in digests.items()},
            "unicodeDataVersion": unicodedata.unidata_version, "selfChecks": self_check(),
            "retainedDictionaryByteParityControls": decoder.reference_checks}, rows

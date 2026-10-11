#!/usr/bin/env python3
"""Verify that a miniTest10 database is a faithful schema-6 subset."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sqlite3
from typing import Iterable, Sequence


MAX_DECOMPRESSED_LINE_BYTES = 16 * 1024 * 1024


def placeholders(values: Sequence[object]) -> str:
    return ",".join("?" for _ in values)


def encode_value(value: object) -> bytes:
    if value is None:
        return b"n"
    if isinstance(value, bytes):
        return b"b" + len(value).to_bytes(8, "big") + value
    data = str(value).encode("utf-8")
    return b"s" + len(data).to_bytes(8, "big") + data


def table_digest(
    connection: sqlite3.Connection,
    table: str,
    where: str,
    parameters: Sequence[object],
) -> tuple[int, str]:
    columns = [row[1] for row in connection.execute(f'PRAGMA table_info("{table}")')]
    if not columns:
        raise RuntimeError(f"missing table or columns: {table}")
    quoted = ",".join(f'"{column}"' for column in columns)
    order = ",".join(str(index + 1) for index in range(len(columns)))
    rows = connection.execute(
        f'SELECT {quoted} FROM "{table}" WHERE {where} ORDER BY {order}', parameters
    )
    digest = hashlib.sha256()
    count = 0
    for row in rows:
        count += 1
        for value in row:
            digest.update(encode_value(value))
        digest.update(b"\n")
    return count, digest.hexdigest()


def decoder(connection: sqlite3.Connection):
    try:
        import zstandard  # type: ignore[import-not-found]
    except ImportError as error:
        raise RuntimeError("install the Python zstandard package") from error

    dictionaries = {
        int(row[0]): zstandard.ZstdCompressionDict(bytes(row[1]))
        for row in connection.execute("SELECT id, dict FROM zstd_dict")
    }

    def decode(value: object) -> str:
        if isinstance(value, str):
            return value
        if not isinstance(value, bytes):
            raise RuntimeError(f"unsupported line content type: {type(value).__name__}")
        parameters = zstandard.get_frame_parameters(value)
        dictionary = dictionaries.get(parameters.dict_id) if parameters.dict_id else None
        if parameters.dict_id and dictionary is None:
            raise RuntimeError(f"missing zstd dictionary {parameters.dict_id}")
        context = zstandard.ZstdDecompressor(dict_data=dictionary)
        return context.decompress(value, max_output_size=MAX_DECOMPRESSED_LINE_BYTES).decode("utf-8")

    return decode


def selected_line_ids(connection: sqlite3.Connection, books: Sequence[int]) -> tuple[int, ...]:
    return tuple(
        int(row[0])
        for row in connection.execute(
            f"SELECT id FROM line WHERE bookId IN ({placeholders(books)}) ORDER BY id", books
        )
    )


def selected_link_ids(connection: sqlite3.Connection, books: Sequence[int]) -> tuple[int, ...]:
    marker = placeholders(books)
    return tuple(
        int(row[0])
        for row in connection.execute(
            f"SELECT id FROM link WHERE sourceBookId IN ({marker}) "
            f"AND targetBookId IN ({marker}) ORDER BY id",
            tuple(books) + tuple(books),
        )
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--mini", required=True, type=Path)
    parser.add_argument("--seed", required=True, type=Path)
    arguments = parser.parse_args()

    seed = json.loads(arguments.seed.read_text(encoding="utf-8"))
    books = tuple(int(value) for value in seed["bookIDs"])
    source = sqlite3.connect(f"file:{arguments.source.as_posix()}?mode=ro", uri=True)
    mini = sqlite3.connect(f"file:{arguments.mini.as_posix()}?mode=ro", uri=True)
    try:
        source_lines = selected_line_ids(source, books)
        source_links = selected_link_ids(source, books)
        line_marker = placeholders(source_lines)
        link_marker = placeholders(source_links)
        book_marker = placeholders(books)
        comparisons: dict[str, dict[str, object]] = {}
        filters: Iterable[tuple[str, str, Sequence[object]]] = (
            ("schema_meta", "1", ()),
            ("zstd_dict", "1", ()),
            ("book", f"id IN ({book_marker})", books),
            ("line", f"bookId IN ({book_marker})", books),
            ("line_content", f"id IN ({line_marker})", source_lines),
            ("line_ref", f"bookId IN ({book_marker})", books),
            ("line_dh", f"bookId IN ({book_marker})", books),
            ("tocEntry", f"bookId IN ({book_marker})", books),
            ("alt_toc_structure", f"bookId IN ({book_marker})", books),
            ("line_toc", f"lineId IN ({line_marker})", source_lines),
            ("line_alt_toc", f"lineId IN ({line_marker})", source_lines),
            (
                "link",
                f"sourceBookId IN ({book_marker}) AND targetBookId IN ({book_marker})",
                books + books,
            ),
            ("link_anchor", f"linkId IN ({link_marker})", source_links),
            ("link_range", f"linkId IN ({link_marker})", source_links),
            ("link_coverage", f"linkId IN ({link_marker})", source_links),
            ("link_suppressed_side", f"linkId IN ({link_marker})", source_links),
            ("book_version", f"bookId IN ({book_marker})", books),
        )
        for table, where, parameters in filters:
            expected = table_digest(source, table, where, parameters)
            actual = table_digest(mini, table, where, parameters)
            if actual != expected:
                raise RuntimeError(f"{table} parity mismatch: expected {expected}, got {actual}")
            comparisons[table] = {"rows": actual[0], "sha256": actual[1]}

        decode_source = decoder(source)
        decode_mini = decoder(mini)
        sampled: list[dict[str, object]] = []
        for book_id in books:
            rows = source.execute(
                "SELECT l.id, l.lineIndex, lc.content FROM line l "
                "JOIN line_content lc ON lc.id=l.id WHERE l.bookId=? ORDER BY l.lineIndex",
                (book_id,),
            ).fetchall()
            for row in (rows[0], rows[len(rows) // 2], rows[-1]):
                mini_value = mini.execute(
                    "SELECT content FROM line_content WHERE id=?", (row[0],)
                ).fetchone()[0]
                expected_text = decode_source(row[2])
                actual_text = decode_mini(mini_value)
                if not actual_text or actual_text != expected_text:
                    raise RuntimeError(f"decoded line parity mismatch for line {row[0]}")
                sampled.append(
                    {
                        "bookID": book_id,
                        "lineID": int(row[0]),
                        "lineIndex": int(row[1]),
                        "utf8SHA256": hashlib.sha256(actual_text.encode("utf-8")).hexdigest(),
                    }
                )

        mini_books = [row[0] for row in mini.execute("SELECT id FROM book ORDER BY id")]
        schema_meta = dict(mini.execute("SELECT key, value FROM schema_meta"))
        foreign_keys = mini.execute("PRAGMA foreign_key_check").fetchall()
        integrity = mini.execute("PRAGMA integrity_check").fetchone()[0]
        if mini_books != list(books) or len(mini_books) != 10:
            raise RuntimeError(f"book set mismatch: {mini_books}")
        if schema_meta.get("db_schema_version") != "6":
            raise RuntimeError(f"expected schema 6, got {schema_meta}")
        if foreign_keys or integrity != "ok":
            raise RuntimeError(f"database validation failed: fk={foreign_keys[:3]} integrity={integrity}")

        print(
            json.dumps(
                {
                    "bookIDs": mini_books,
                    "comparisons": comparisons,
                    "decodedSamples": sampled,
                    "foreignKeyViolations": len(foreign_keys),
                    "integrity": integrity,
                    "schemaMeta": schema_meta,
                },
                ensure_ascii=False,
                sort_keys=True,
            )
        )
    finally:
        source.close()
        mini.close()


if __name__ == "__main__":
    main()

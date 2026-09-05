#!/usr/bin/env python3
"""Build a deterministic Otzaria seforim.db subset without changing canonical IDs."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sqlite3
from typing import Iterable, Sequence


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while chunk := handle.read(8 * 1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def placeholders(values: Sequence[object]) -> str:
    if not values:
        raise ValueError("an empty SQL IN list is not valid")
    return ",".join("?" for _ in values)


class MiniDatabaseBuilder:
    def __init__(self, source: Path, output: Path, requested_books: Sequence[int]) -> None:
        self.source_path = source
        self.output_path = output
        self.requested_books = tuple(dict.fromkeys(requested_books))
        self.source = sqlite3.connect(f"file:{source.as_posix()}?mode=ro", uri=True)
        self.source.row_factory = sqlite3.Row
        self.output = sqlite3.connect(output)
        self.output.execute("PRAGMA foreign_keys=OFF")

    def close(self) -> None:
        self.source.close()
        self.output.close()

    def scalar_set(self, query: str, parameters: Sequence[object] = ()) -> set[int]:
        return {int(row[0]) for row in self.source.execute(query, parameters)}

    def resolve_book_closure(self) -> tuple[int, ...]:
        selected = set(self.requested_books)
        missing = selected - self.scalar_set(
            f"SELECT id FROM book WHERE id IN ({placeholders(self.requested_books)})",
            self.requested_books,
        )
        if missing:
            raise RuntimeError(f"requested book IDs do not exist: {sorted(missing)}")

        while True:
            current = tuple(sorted(selected))
            dependencies = self.scalar_set(
                f"""
                SELECT baseBookId FROM book_base_text WHERE bookId IN ({placeholders(current)})
                UNION
                SELECT bookId FROM default_commentator WHERE commentatorBookId IN ({placeholders(current)})
                UNION
                SELECT bookId FROM default_targum WHERE targumBookId IN ({placeholders(current)})
                """,
                current + current + current,
            )
            expanded = selected | dependencies
            if expanded == selected:
                return tuple(sorted(selected))
            selected = expanded

    def create_tables(self) -> None:
        rows = self.source.execute(
            "SELECT name, sql FROM sqlite_master WHERE type='table' AND sql IS NOT NULL ORDER BY name"
        ).fetchall()
        virtual_tables = {
            row["name"] for row in rows if row["sql"].lstrip().upper().startswith("CREATE VIRTUAL TABLE")
        }
        shadow_prefixes = tuple(f"{name}_" for name in virtual_tables)
        for row in rows:
            name = row["name"]
            if name.startswith("sqlite_") or (shadow_prefixes and name.startswith(shadow_prefixes)):
                continue
            self.output.execute(row["sql"])

    def copy(self, table: str, where: str = "1", parameters: Sequence[object] = ()) -> int:
        columns = [row[1] for row in self.source.execute(f'PRAGMA table_info("{table}")')]
        quoted = ",".join(f'"{column}"' for column in columns)
        insert = f'INSERT INTO "{table}" ({quoted}) VALUES ({placeholders(columns)})'
        cursor = self.source.execute(f'SELECT {quoted} FROM "{table}" WHERE {where}', parameters)
        count = 0
        while rows := cursor.fetchmany(10_000):
            self.output.executemany(insert, (tuple(row) for row in rows))
            count += len(rows)
        return count

    def build(self) -> dict[str, object]:
        books = self.resolve_book_closure()
        book_in = placeholders(books)
        self.create_tables()
        counts: dict[str, int] = {}

        counts["schema_meta"] = self.copy("schema_meta")
        counts["book"] = self.copy("book", f"id IN ({book_in})", books)

        category_ids = self.scalar_set(
            f"""
            SELECT DISTINCT cc.ancestorId
            FROM book b JOIN category_closure cc ON cc.descendantId=b.categoryId
            WHERE b.id IN ({book_in})
            UNION SELECT categoryId FROM book WHERE id IN ({book_in})
            """,
            books + books,
        )
        category_values = tuple(sorted(category_ids))
        category_in = placeholders(category_values)
        counts["category"] = self.copy("category", f"id IN ({category_in})", category_values)
        counts["category_closure"] = self.copy(
            "category_closure",
            f"ancestorId IN ({category_in}) AND descendantId IN ({category_in})",
            category_values + category_values,
        )

        counts["source"] = self.copy(
            "source", f"id IN (SELECT sourceId FROM book WHERE id IN ({book_in}))", books
        )
        for table in ("book_acronym", "book_author", "book_base_text", "book_generation",
                      "book_has_links", "book_pub_date", "book_pub_place", "book_topic"):
            counts[table] = self.copy(table, f"bookId IN ({book_in})", books)

        counts["author"] = self.copy(
            "author", f"id IN (SELECT authorId FROM book_author WHERE bookId IN ({book_in}))", books
        )
        counts["generation"] = self.copy(
            "generation", f"id IN (SELECT generationId FROM book_generation WHERE bookId IN ({book_in}))", books
        )
        counts["pub_date"] = self.copy(
            "pub_date", f"id IN (SELECT pubDateId FROM book_pub_date WHERE bookId IN ({book_in}))", books
        )
        counts["pub_place"] = self.copy(
            "pub_place", f"id IN (SELECT pubPlaceId FROM book_pub_place WHERE bookId IN ({book_in}))", books
        )
        counts["topic"] = self.copy(
            "topic", f"id IN (SELECT topicId FROM book_topic WHERE bookId IN ({book_in}))", books
        )
        counts["book_version"] = self.copy("book_version", f"bookId IN ({book_in})", books)

        counts["line"] = self.copy("line", f"bookId IN ({book_in})", books)
        counts["tocEntry"] = self.copy("tocEntry", f"bookId IN ({book_in})", books)
        counts["alt_toc_structure"] = self.copy(
            "alt_toc_structure", f"bookId IN ({book_in})", books
        )
        counts["alt_toc_entry"] = self.copy(
            "alt_toc_entry",
            f"structureId IN (SELECT id FROM alt_toc_structure WHERE bookId IN ({book_in}))",
            books,
        )

        text_ids = self.scalar_set(
            f"SELECT textId FROM tocEntry WHERE bookId IN ({book_in}) "
            f"UNION SELECT e.textId FROM alt_toc_entry e JOIN alt_toc_structure s ON s.id=e.structureId "
            f"WHERE s.bookId IN ({book_in})",
            books + books,
        )
        text_values = tuple(sorted(text_ids))
        counts["tocText"] = self.copy(
            "tocText", f"id IN ({placeholders(text_values)})", text_values
        ) if text_values else 0

        counts["line_toc"] = self.copy(
            "line_toc", f"lineId IN (SELECT id FROM line WHERE bookId IN ({book_in}))", books
        )
        counts["line_alt_toc"] = self.copy(
            "line_alt_toc", f"lineId IN (SELECT id FROM line WHERE bookId IN ({book_in}))", books
        )

        link_ids = self.scalar_set(
            f"SELECT id FROM link WHERE sourceBookId IN ({book_in}) AND targetBookId IN ({book_in})",
            books + books,
        )
        link_values = tuple(sorted(link_ids))
        if link_values:
            link_in = placeholders(link_values)
            counts["link"] = self.copy("link", f"id IN ({link_in})", link_values)
            for table in ("link_anchor", "link_coverage", "link_range"):
                counts[table] = self.copy(table, f"linkId IN ({link_in})", link_values)
            counts["connection_type"] = self.copy(
                "connection_type",
                f"id IN (SELECT connectionTypeId FROM link WHERE id IN ({link_in}))",
                link_values,
            )
        else:
            for table in ("link", "link_anchor", "link_coverage", "link_range", "connection_type"):
                counts[table] = 0

        counts["default_commentator"] = self.copy(
            "default_commentator",
            f"bookId IN ({book_in}) AND commentatorBookId IN ({book_in})",
            books + books,
        )
        counts["default_targum"] = self.copy(
            "default_targum",
            f"bookId IN ({book_in}) AND targumBookId IN ({book_in})",
            books + books,
        )
        counts["version_line"] = self.copy(
            "version_line",
            f"versionId IN (SELECT id FROM book_version WHERE bookId IN ({book_in})) "
            f"AND lineId IN (SELECT id FROM line WHERE bookId IN ({book_in}))",
            books + books,
        )

        self.output.commit()
        self.recreate_indexes_and_fts()
        self.output.execute("PRAGMA foreign_keys=ON")
        foreign_key_errors = self.output.execute("PRAGMA foreign_key_check").fetchall()
        if foreign_key_errors:
            raise RuntimeError(f"foreign-key violations: {foreign_key_errors[:10]}")
        integrity = self.output.execute("PRAGMA integrity_check").fetchone()[0]
        if integrity != "ok":
            raise RuntimeError(f"integrity_check failed: {integrity}")
        actual_books = tuple(row[0] for row in self.output.execute("SELECT id FROM book ORDER BY id"))
        if actual_books != books:
            raise RuntimeError(f"book identity mismatch: expected {books}, got {actual_books}")
        self.output.execute("VACUUM")
        self.output.execute("PRAGMA optimize")
        self.output.commit()
        return {"bookIDs": list(books), "counts": counts, "integrityCheck": integrity}

    def recreate_indexes_and_fts(self) -> None:
        rows = self.source.execute(
            "SELECT type, name, sql FROM sqlite_master "
            "WHERE type IN ('index','trigger','view') AND sql IS NOT NULL ORDER BY type,name"
        ).fetchall()
        for row in rows:
            self.output.execute(row["sql"])
        virtual_rows = self.source.execute(
            "SELECT name, sql FROM sqlite_master WHERE type='table' AND sql IS NOT NULL "
            "AND upper(ltrim(sql)) LIKE 'CREATE VIRTUAL TABLE%' ORDER BY name"
        ).fetchall()
        for row in virtual_rows:
            self.output.execute(row["sql"])
            try:
                self.output.execute(
                    f"INSERT INTO \"{row['name']}\"(\"{row['name']}\") VALUES('rebuild')"
                )
            except sqlite3.DatabaseError as error:
                raise RuntimeError(f"could not rebuild FTS table {row['name']}: {error}") from error
        self.output.commit()


def compress_zstd(source: Path, destination: Path) -> None:
    try:
        import zstandard  # type: ignore[import-not-found]
    except ImportError as error:
        raise RuntimeError("install the Python zstandard package to use --compress") from error
    with source.open("rb") as input_handle, destination.open("wb") as output_handle:
        zstandard.ZstdCompressor(level=19, threads=-1).copy_stream(input_handle, output_handle)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--seed", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--compress", action="store_true")
    arguments = parser.parse_args()
    seed = json.loads(arguments.seed.read_text(encoding="utf-8"))
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    if arguments.output.exists():
        raise RuntimeError(f"refusing to overwrite existing output: {arguments.output}")

    builder = MiniDatabaseBuilder(arguments.source, arguments.output, seed["bookIDs"])
    try:
        result = builder.build()
    finally:
        builder.close()

    compressed_path = arguments.output.with_suffix(arguments.output.suffix + ".zst")
    if arguments.compress:
        compress_zstd(arguments.output, compressed_path)
    provenance = {
        "formatVersion": 1,
        "profileID": seed["profileID"],
        "profileVersion": seed["profileVersion"],
        "source": seed["source"],
        "sourceDatabaseBytes": arguments.source.stat().st_size,
        "sourceDatabaseSHA256": sha256(arguments.source),
        "databaseBytes": arguments.output.stat().st_size,
        "databaseSHA256": sha256(arguments.output),
        "compressedBytes": compressed_path.stat().st_size if arguments.compress else None,
        "compressedSHA256": sha256(compressed_path) if arguments.compress else None,
        **result,
    }
    provenance_path = arguments.output.with_suffix(".provenance.json")
    provenance_path.write_text(
        json.dumps(provenance, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(provenance, ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    main()

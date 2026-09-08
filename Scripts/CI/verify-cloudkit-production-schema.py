#!/usr/bin/env python3
"""Semantically verify the ChavrusaText custom CloudKit schema."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


EXPECTED = {
    "Annotation": {
        "bkId": "INT64",
        "contentId": "INT64",
        "rangeLocation": "INT64",
        "rangeLength": "INT64",
        "rangeDiacLocation": "INT64",
        "rangeDiacLength": "INT64",
        "colorHex": "STRING",
        "type": "INT64",
        "note": "STRING",
        "createdAt": "INT64",
        "context": "STRING",
        "page": "INT64",
        "part": "INT64",
        "lastModified": "INT64",
        "tags": "LIST<STRING>",
        "backendLocator": "STRING",
    },
    "SearchFolder": {
        "name": "STRING",
        "lastModified": "INT64",
        "parentCkRecordId": "STRING",
    },
    "SearchResult": {
        "name": "STRING",
        "query": "STRING",
        "searchMode": "INT64",
        "nearDistance": "INT64",
        "archive": "INT64",
        "bkId": "INT64",
        "contentId": "STRING",
        "lastModified": "INT64",
        "folderCkRecordId": "STRING",
    },
    "ReadingEntry": {
        "bookId": "INT64",
        "lastContentId": "INT64",
        "lastOpenedAt": "TIMESTAMP",
        "favoritedAt": "TIMESTAMP",
        "positionUpdatedAt": "TIMESTAMP",
        "isFavorite": "INT64",
        "lastModified": "INT64",
    },
}

RECORD_PATTERN = re.compile(
    r'RECORD\s+TYPE\s+(?:"([^"]+)"|([A-Za-z_][A-Za-z0-9_]*))\s*'
    r"\((.*?)\)\s*;",
    flags=re.IGNORECASE | re.DOTALL,
)
FIELD_PATTERN = re.compile(
    r'^\s*(?:"([^"]+)"|([A-Za-z_][A-Za-z0-9_]*))\s+'
    r"(LIST\s*<\s*[A-Za-z][A-Za-z0-9_()]*\s*>|"
    r"[A-Za-z][A-Za-z0-9_]*(?:\(\d+\))?)(?=\s|$)",
    flags=re.IGNORECASE,
)


def parse_schema(path: Path) -> dict[str, dict[str, str]]:
    source = path.read_text(encoding="utf-8")
    source = re.sub(r"/\*.*?\*/", "", source, flags=re.DOTALL)
    source = re.sub(r"//.*", "", source)
    records: dict[str, dict[str, str]] = {}

    for match in RECORD_PATTERN.finditer(source):
        record_name = match.group(1) or match.group(2)
        fields: dict[str, str] = {}
        for declaration in match.group(3).split(","):
            field_match = FIELD_PATTERN.match(declaration)
            if not field_match:
                continue
            field_name = field_match.group(1) or field_match.group(2)
            if field_name.startswith("___") or field_name.upper() == "GRANT":
                continue
            field_type = re.sub(r"\s+", "", field_match.group(3)).upper()
            fields[field_name] = field_type
        records[record_name] = fields
    return records


def find_mismatches(actual: dict[str, dict[str, str]]) -> list[str]:
    failures: list[str] = []
    for record_name, required_fields in EXPECTED.items():
        if record_name not in actual:
            failures.append(f"missing record type: {record_name}")
            continue

        fields = actual[record_name]
        missing = sorted(set(required_fields) - set(fields))
        extra = sorted(set(fields) - set(required_fields))
        wrong = sorted(
            f"{name}: expected {required_fields[name]}, found {fields[name]}"
            for name in set(required_fields) & set(fields)
            if fields[name] != required_fields[name]
        )
        if missing:
            failures.append(f"{record_name} missing fields: {', '.join(missing)}")
        if extra:
            failures.append(
                f"{record_name} unexpected custom fields: {', '.join(extra)}"
            )
        failures.extend(f"{record_name}.{item}" for item in wrong)
        if len(fields) != len(required_fields):
            failures.append(
                f"{record_name} custom field count: expected "
                f"{len(required_fields)}, found {len(fields)}"
            )

    total = sum(len(actual.get(name, {})) for name in EXPECTED)
    if total != 35:
        failures.append(
            f"total required-record custom field count: expected 35, found {total}"
        )
    return failures


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("schema", type=Path)
    args = parser.parse_args()

    actual = parse_schema(args.schema)
    failures = find_mismatches(actual)
    if failures:
        print("::error::Production CloudKit schema mismatch")
        for failure in failures:
            print(f"::error::{failure}")
        return 1

    print("Production CloudKit schema verified semantically:")
    for name in EXPECTED:
        print(f"  {name}: {len(actual[name])} custom fields")
    print("  total: 35 custom fields")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

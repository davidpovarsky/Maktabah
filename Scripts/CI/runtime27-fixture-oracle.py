#!/usr/bin/env python3
"""Read-only independent identity oracle from the real owned native installation."""
import hashlib
import json
from pathlib import Path
import sqlite3
import subprocess
from contextlib import closing


def sidebar_paths(connection):
    """Exact catalog hierarchy, derived independently of any UI observation."""
    result = {}
    for key, title in (("HQ_SIDEBAR_MATCH_PATH", "מסילת ישרים"),
                       ("HQ_SIDEBAR_EXCLUDED_PATH", "בראשית")):
        books = connection.execute("SELECT id, categoryId FROM book WHERE title = ?", (title,)).fetchall()
        if len(books) != 1:
            raise RuntimeError("Sidebar fixture requires one exact book title: " + title)
        book_id, category = books[0]
        ancestors, seen = [], set()
        while category is not None:
            if category in seen or len(seen) >= 64:
                raise RuntimeError("Cyclic or excessively deep fixture category hierarchy")
            seen.add(category)
            row = connection.execute("SELECT parentId, title FROM category WHERE id = ?", (category,)).fetchone()
            if row is None or not row[1]:
                raise RuntimeError("Missing or unnamed actual fixture category")
            category, name = row
            ancestors.append(name)
        result[key] = {"book_id": book_id, "path": [*reversed(ancestors), title]}
    return result


def canonical_search_candidates(database_sha256):
    path = Path("Tests/HQ/search/canonical-miniTest10-query-candidates.json")
    raw = path.read_bytes()
    if hashlib.sha256(raw).hexdigest() != "da066b440d54ca6015fc7387c00d36d7df0648e3f25f4d95be98750ba38cc5a3":
        raise RuntimeError("Independent search-query source evidence changed")
    evidence = json.loads(raw)
    if (evidence["databaseSHA256"] != database_sha256
            or evidence["profileID"] != "miniTest10" or evidence["profileVersion"] != 6
            or evidence["sourceRows"] != 18879):
        raise RuntimeError("Query candidates do not belong to this actual installed fixture")
    for key in ("GLOBAL_SEARCH_TEST_QUERY", "GLOBAL_SEARCH_PAGING_QUERY"):
        row = evidence["queries"][key]
        if not row["query"].strip() or row["matching_source_rows"] <= 100:
            raise RuntimeError("Search candidate is not supported by actual source rows")
    return evidence


def derive_oracle(udid, size, include_sidebar=False, include_search=False):
    report_path = Path(f"build/artifacts/miniTest10-native-fixture-install-{size}.json")
    installed = json.loads(report_path.read_text())
    if (installed.get("passed") is not True or installed.get("profileID") != "miniTest10"
            or not installed.get("expectedSHA256") or installed.get("shaMatched") is not True
            or installed.get("expectedSHA256") != installed.get("actualSHA256")
            or installed.get("quickCheck", "").lower() != "ok"):
        raise RuntimeError("No verified actual native fixture installation")
    database = Path(installed["finalPath"]).resolve(strict=True)
    # A different device/container or user DB must never become this oracle.
    if f"/devices/{udid.lower()}/data/" not in database.as_posix().lower():
        raise RuntimeError("Fixture database is outside this owned disposable simulator")
    before = hashlib.sha256(database.read_bytes()).hexdigest()
    sql = ("SELECT l.sourceBookId, sourceLine.lineIndex, b.title FROM link l "
           "JOIN line sourceLine ON sourceLine.id=l.sourceLineId "
           "JOIN book b ON b.id=l.sourceBookId ORDER BY l.id LIMIT 1")
    with closing(sqlite3.connect(database.as_uri() + "?mode=ro&immutable=1", uri=True)) as connection:
        if connection.execute("PRAGMA quick_check").fetchone() != ("ok",):
            raise RuntimeError("Actual fixture database failed read-only quick_check")
        selected = connection.execute(sql).fetchone()
        fallback = selected is None
        if fallback:
            selected = connection.execute("SELECT id,1,title FROM book WHERE id=1").fetchone()
        if not selected or not selected[2]:
            raise RuntimeError("Actual fixture cannot resolve the app's independently selected book")
        schema = connection.execute("PRAGMA user_version").fetchone()[0]
        sidebar = sidebar_paths(connection) if include_sidebar else None
        search = canonical_search_candidates(before) if include_search else None
    if hashlib.sha256(database.read_bytes()).hexdigest() != before:
        raise RuntimeError("Read-only oracle unexpectedly changed the DB")
    evidence = {"database_path": str(database), "database_sha256": before, "schema": schema,
                "native_installation_report_sha256": hashlib.sha256(report_path.read_bytes()).hexdigest(),
                "profileID": installed["profileID"], "profileVersion": installed["profileVersion"],
                "expected_compressed_sha256": installed["expectedSHA256"], "sql": sql,
                "selected": {"sourceBookId": selected[0], "lineIndex": selected[1], "title": selected[2]},
                "fallback_book1_because_no_link": fallback, "ui_observation_used": False,
                "sidebar_catalog_paths": sidebar, "search_query_source_evidence": search}
    Path(f"build/artifacts/runtime27/fixture-oracle-{size}.json").write_text(json.dumps(evidence, indent=2) + "\n")
    environment = {"TEST_RUNNER_R27_EXPECTED_OTZARIA_WORK_KEY": f"book:{selected[0]}",
                   "TEST_RUNNER_R27_EXPECTED_OTZARIA_BOOK_TITLE": selected[2]}
    if sidebar:
        environment.update({"TEST_RUNNER_" + key: json.dumps(value["path"], ensure_ascii=False)
                            for key, value in sidebar.items()})
    if search:
        environment.update({"TEST_RUNNER_" + key: value["query"]
                            for key, value in search["queries"].items()})
    return environment

#!/usr/bin/env python3
"""Read-only independent identity oracle from the real owned native installation."""
import hashlib
import json
from pathlib import Path
import sqlite3
import subprocess


def derive_oracle(udid, size):
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
    with sqlite3.connect(database.as_uri() + "?mode=ro&immutable=1", uri=True) as connection:
        if connection.execute("PRAGMA quick_check").fetchone() != ("ok",):
            raise RuntimeError("Actual fixture database failed read-only quick_check")
        selected = connection.execute(sql).fetchone()
        fallback = selected is None
        if fallback:
            selected = connection.execute("SELECT id,1,title FROM book WHERE id=1").fetchone()
        if not selected or not selected[2]:
            raise RuntimeError("Actual fixture cannot resolve the app's independently selected book")
        schema = connection.execute("PRAGMA user_version").fetchone()[0]
    if hashlib.sha256(database.read_bytes()).hexdigest() != before:
        raise RuntimeError("Read-only oracle unexpectedly changed the DB")
    evidence = {"database_path": str(database), "database_sha256": before, "schema": schema,
                "native_installation_report_sha256": hashlib.sha256(report_path.read_bytes()).hexdigest(),
                "profileID": installed["profileID"], "profileVersion": installed["profileVersion"],
                "expected_compressed_sha256": installed["expectedSHA256"], "sql": sql,
                "selected": {"sourceBookId": selected[0], "lineIndex": selected[1], "title": selected[2]},
                "fallback_book1_because_no_link": fallback, "ui_observation_used": False}
    Path(f"build/artifacts/runtime27/fixture-oracle-{size}.json").write_text(json.dumps(evidence, indent=2) + "\n")
    return {"TEST_RUNNER_R27_EXPECTED_OTZARIA_WORK_KEY": f"book:{selected[0]}",
            "TEST_RUNNER_R27_EXPECTED_OTZARIA_BOOK_TITLE": selected[2]}

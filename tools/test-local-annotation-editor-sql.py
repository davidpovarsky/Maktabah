#!/usr/bin/env python3
"""Execute source-extracted SQL statement controls, not Swift policy/session tests.

The complete Swift consumer suite is separate and must run on Apple. These
owned SQLite files exercise actual statement constraints, transaction rollback,
cold reopen and original-table preservation without claiming Swift execution.
"""
from pathlib import Path
import argparse
import base64
import datetime
import hashlib
import json
import re
import sqlite3
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
LEDGER = "Source/ChavrusaText/Annotations/Exchange/AnnotationExchangeLedger.swift"
LOCAL = "Source/ChavrusaText/Annotations/LocalEditor/AnnotationLocalEditorPersistence.swift"
QUEUE = "Source/Core/CloudKit/SyncPendingStore.swift"
REPOSITORY = "Source/Features/Annotations/Database/AnnotationRepository.swift"
UUID = "11111111-2222-3333-4444-555555555555"
MUTATION = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
NAMESPACE = "otzaria.local.annotation"


def statements(text):
    for match in re.finditer(r'"""(.*?)"""|"((?:\\.|[^"\\])*)"', text, re.S):
        value = match.group(1) if match.group(1) is not None else match.group(2)
        if value.lstrip().startswith(("CREATE ", "INSERT ", "UPDATE ", "SELECT ")):
            yield value.strip()


def exactly(values, prefix):
    found = [x for x in values if x.startswith(prefix)]
    if len(found) != 1:
        raise ValueError((prefix, len(found)))
    return found[0]


def source_sql(root):
    ledger = (root / LEDGER).read_text()
    local = (root / LOCAL).read_text()
    queue = (root / QUEUE).read_text()
    repo = (root / REPOSITORY).read_text()
    names = dict(re.findall(r'private static let (\w+) = "([^"]+)"', ledger))
    columns = dict(re.findall(r'    let (\w+) = "([^"]+)"', repo))
    def substitute(sql):
        sql = re.sub(r'\\\(Self\.(\w+)\)', lambda m: names[m[1]], sql)
        return re.sub(r'\\\((\w+)\)', lambda m: columns[m[1]], sql)
    install = ledger.split("let statements = [", 1)[1].split("for statement in statements", 1)[0]
    all_ledger = list(statements(ledger))
    all_local = list(statements(local))
    all_queue = list(statements(queue))
    annotation = exactly(statements(repo), "CREATE TABLE IF NOT EXISTS \\(annotationsTable)")
    # These original columns are introduced by original explicit ALTERs after
    # createAnnotationsTableAndSchemaIfNeeded; preserve their actual order.
    original = [substitute(annotation)] + [
        "ALTER TABLE annotations ADD COLUMN ckRecordId TEXT;",
        "ALTER TABLE annotations ADD COLUMN lastModified INTEGER;",
        "ALTER TABLE annotations ADD COLUMN backendLocator TEXT;",
        substitute(exactly(statements(repo), "CREATE TABLE IF NOT EXISTS \\(tagsTable)")),
        substitute(exactly(statements(repo), "CREATE TABLE IF NOT EXISTS \\(annotationTagsTable)")),
        exactly(all_queue, "CREATE TABLE IF NOT EXISTS sync_pending"),
    ]
    return {
        "original": original,
        "install": [substitute(s) for s in statements(install)],
        "preview": exactly(all_local, "UPDATE annotations SET note"),
        "delete_guard": exactly(all_local, "SELECT COUNT(*) FROM sync_pending"),
        "pending": exactly(all_queue, "INSERT OR REPLACE INTO sync_pending"),
        "version": substitute(exactly(all_ledger, "INSERT INTO \\(Self.versions)")),
        "head": substitute(exactly(all_ledger, "INSERT INTO \\(Self.heads)")),
        "original_update": substitute(exactly(statements(repo), "UPDATE \\(annotationsTable) SET \\(colAnnColor)")),
    }


class StatementControls(unittest.TestCase):
    sql = None
    owned_root = None

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="sql-owned-", dir=self.owned_root)
        self.path = Path(self.directory.name) / "Annotations.sqlite"
        self.db = self.connection(self.path)
        for statement in self.sql["original"]:
            self.db.execute(statement)
        self.db.execute("INSERT INTO annotations VALUES(1,28,2,4,5,6,7,'#123456',1,'original',1700000001,'context',1,9,?,1700000002,'opaque-locator');", (UUID,))
        self.db.execute("INSERT INTO tags VALUES(1,'עיון','עיון');")
        self.db.execute("INSERT INTO annotation_tags VALUES(1,1);")
        self.db.execute("INSERT INTO sync_pending VALUES('unrelated-delete','delete',1700000000);")
        self.payload = json.dumps({"schemaVersion": 1, "fixtureOpaqueBody": {"blocks": ["שלום", "שני"]}, "unknown": [1, {"keep": "exact"}]}, ensure_ascii=False, separators=(",", ":")).encode()

    @staticmethod
    def connection(path):
        db = sqlite3.connect(path, isolation_level=None)
        db.execute("PRAGMA journal_mode=WAL;")
        return db

    def tearDown(self):
        self.db.close()
        self.directory.cleanup()

    def dump(self):
        return "\n".join(self.db.iterdump())

    def install(self):
        for statement in self.sql["install"]:
            self.db.execute(statement)

    def write(self, mutation=MUTATION, revision=1, payload=None, before_head=None):
        payload = self.payload if payload is None else payload
        self.db.execute("BEGIN TRANSACTION;")
        try:
            self.install()
            self.db.execute(self.sql["preview"], ("תצוגה", 1700000100, 1, UUID))
            self.db.execute(self.sql["pending"], (UUID, "upload", 1700000100))
            self.db.execute(self.sql["version"], (mutation, NAMESPACE, UUID, revision, "a" * 64,
                hashlib.sha256(payload).hexdigest(), base64.b64encode(payload).decode(), "active", "[]"))
            if before_head:
                before_head()
            self.db.execute(self.sql["head"], (NAMESPACE, UUID, revision))
            self.db.execute("COMMIT;")
        except BaseException:
            self.db.execute("ROLLBACK;")
            raise

    def test_preview_body_and_original_queue_commit_together(self):
        self.write()
        self.assertEqual(self.db.execute("SELECT note,lastModified FROM annotations;").fetchone(), ("תצוגה", 1700000100))
        row = self.db.execute("SELECT payload_base64,destinations_json FROM otzaria_annotation_exchange_versions;").fetchone()
        self.assertEqual(base64.b64decode(row[0]), self.payload)
        self.assertEqual(row[1], "[]")
        self.assertEqual(self.db.execute("SELECT operation FROM sync_pending WHERE ck_record_id=?;", (UUID,)).fetchone(), ("upload",))

    def test_all_unedited_original_columns_and_tags_are_identical(self):
        before = self.db.execute("SELECT * FROM annotations;").fetchone()
        tags = self.db.execute("SELECT * FROM annotation_tags;").fetchall()
        self.write()
        after = self.db.execute("SELECT * FROM annotations;").fetchone()
        self.assertEqual(tuple(v for i,v in enumerate(before) if i not in (9,15)), tuple(v for i,v in enumerate(after) if i not in (9,15)))
        self.assertEqual(self.db.execute("SELECT * FROM annotation_tags;").fetchall(), tags)

    def test_no_outbox_or_inbox_created_by_local_statement_sequence(self):
        self.write()
        for table in ("outbox", "inbox"):
            self.assertEqual(self.db.execute("SELECT COUNT(*) FROM otzaria_annotation_exchange_" + table).fetchone()[0], 0)

    def test_unrelated_cloudkit_delete_bytes_are_preserved(self):
        before = self.db.execute("SELECT * FROM sync_pending WHERE ck_record_id='unrelated-delete';").fetchall()
        self.write()
        self.assertEqual(self.db.execute("SELECT * FROM sync_pending WHERE ck_record_id='unrelated-delete';").fetchall(), before)

    def test_late_failure_rolls_back_preview_body_head_and_queue(self):
        before = self.dump()
        def fail():
            raise RuntimeError("owned failure after version insert")
        with self.assertRaisesRegex(RuntimeError, "owned failure"):
            self.write(before_head=fail)
        self.assertEqual(self.dump(), before)

    def test_real_sqlite_abort_rolls_back_preview_and_queue(self):
        self.install()
        self.db.execute("CREATE TRIGGER owned_abort BEFORE INSERT ON otzaria_annotation_exchange_heads BEGIN SELECT RAISE(ABORT,'owned rejection'); END;")
        before = self.dump()
        with self.assertRaises(sqlite3.IntegrityError):
            self.write()
        self.assertEqual(self.dump(), before)

    def test_oversized_version_constraint_rolls_back_all_originals(self):
        before = self.dump()
        with self.assertRaises(sqlite3.IntegrityError):
            self.write(payload=b"a" * 70_000)
        self.assertEqual(self.dump(), before)

    def test_duplicate_mutation_constraint_prevents_second_sql_write(self):
        self.write(); before = self.dump()
        with self.assertRaises(sqlite3.IntegrityError):
            self.write(revision=2)
        self.assertEqual(self.dump(), before)

    def test_duplicate_revision_constraint_preserves_history(self):
        self.write(); before = self.dump()
        with self.assertRaises(sqlite3.IntegrityError):
            self.write(mutation="BBBBBBBB-BBBB-CCCC-DDDD-EEEEEEEEEEEE", revision=1)
        self.assertEqual(self.dump(), before)

    def test_later_revision_keeps_exact_original_version_bytes(self):
        self.write(); before = self.db.execute("SELECT * FROM otzaria_annotation_exchange_versions WHERE revision=1;").fetchall()
        self.write(mutation="BBBBBBBB-BBBB-CCCC-DDDD-EEEEEEEEEEEE", revision=2, payload=b"new opaque version")
        self.assertEqual(self.db.execute("SELECT * FROM otzaria_annotation_exchange_versions WHERE revision=1;").fetchall(), before)
        self.assertEqual(self.db.execute("SELECT revision FROM otzaria_annotation_exchange_heads;").fetchone(), (2,))

    def test_cold_sqlite_reopen_retains_uuid_rich_bytes_and_plain_note(self):
        self.write(); before = self.dump(); self.db.close(); self.db = self.connection(self.path)
        self.assertEqual(self.dump(), before)
        self.assertEqual(self.db.execute("SELECT ckRecordId,note FROM annotations;").fetchone(), (UUID, "תצוגה"))

    def test_opaque_binary_and_unknown_fields_survive_exact_storage(self):
        body = bytes(range(256)) + self.payload
        self.write(payload=body)
        row = self.db.execute("SELECT payload_base64,payload_digest FROM otzaria_annotation_exchange_versions;").fetchone()
        self.assertEqual(base64.b64decode(row[0]), body)
        self.assertEqual(row[1], hashlib.sha256(body).hexdigest())

    def test_original_plain_save_does_not_delete_rich_history(self):
        self.write(); before = self.db.execute("SELECT * FROM otzaria_annotation_exchange_versions;").fetchall()
        self.db.execute(self.sql["original_update"], ("#abcdef", 0, "ordinary note", 1700000300, 1))
        self.assertEqual(self.db.execute("SELECT * FROM otzaria_annotation_exchange_versions;").fetchall(), before)
        self.assertEqual(self.db.execute("SELECT note FROM annotations;").fetchone(), ("ordinary note",))

    def test_original_delete_keeps_version_bytes_for_explicit_review(self):
        self.write(); before = self.db.execute("SELECT * FROM otzaria_annotation_exchange_versions;").fetchall()
        self.db.execute("DELETE FROM annotation_tags WHERE annotationId=1;"); self.db.execute("DELETE FROM annotations WHERE id=1;")
        self.assertEqual(self.db.execute("SELECT * FROM otzaria_annotation_exchange_versions;").fetchall(), before)

    def test_actual_pending_delete_query_matches_uuid_case(self):
        self.db.execute("INSERT INTO sync_pending VALUES(?,'delete',1);", (UUID.lower(),))
        self.assertEqual(self.db.execute(self.sql["delete_guard"], (UUID,)).fetchone(), (1,))

    def test_preview_where_clause_does_not_write_another_uuid(self):
        before = self.dump()
        self.db.execute(self.sql["preview"], ("not admitted", 2, 1, "99999999-2222-3333-4444-555555555555"))
        self.assertEqual(self.dump(), before)

    def test_preview_where_clause_does_not_write_another_row_id(self):
        before = self.dump(); self.db.execute(self.sql["preview"], ("not admitted", 2, 2, UUID))
        self.assertEqual(self.dump(), before)

    def test_dangling_tag_association_is_not_removed_by_body_commit(self):
        self.db.execute("INSERT INTO annotation_tags VALUES(1,999);")
        before = self.db.execute("SELECT * FROM annotation_tags ORDER BY tagId;").fetchall()
        self.write(); self.assertEqual(self.db.execute("SELECT * FROM annotation_tags ORDER BY tagId;").fetchall(), before)


class RecordingResult(unittest.TextTestResult):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs); self.rows = []
    def addSuccess(self, test):
        super().addSuccess(test); self.rows.append({"id": test.id(), "status": "PASS"})
    def addFailure(self, test, error):
        super().addFailure(test, error); self.rows.append({"id": test.id(), "status": "FAIL"})
    def addError(self, test, error):
        super().addError(test, error); self.rows.append({"id": test.id(), "status": "ERROR"})


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--artifacts-dir", type=Path, required=True)
    args = parser.parse_args(); output = args.artifacts_dir.resolve(); output.mkdir(parents=True, exist_ok=True)
    if (output / "RESULT.json").exists():
        raise ValueError("fresh result directory required")
    paths = [LEDGER, LOCAL, QUEUE, REPOSITORY, "tools/test-local-annotation-editor-sql.py"]
    before = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths}
    StatementControls.sql = source_sql(ROOT); StatementControls.owned_root = output
    (output / "EXTRACTED_SQL.json").write_bytes((json.dumps(StatementControls.sql, indent=2) + "\n").encode())
    result = unittest.TextTestRunner(verbosity=2, resultclass=RecordingResult).run(unittest.defaultTestLoader.loadTestsFromTestCase(StatementControls))
    after = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths}
    report = {"scope": "SOURCE_EXTRACTED_SQL_STATEMENTS_ONLY", "swift_executed": 0, "native_ui_executed": 0,
        "cloudkit_executed": 0, "anytype_executed": 0, "sqlite_version": sqlite3.sqlite_version,
        "observed_at": datetime.datetime.now(datetime.timezone.utc).isoformat(), "checks": result.rows,
        "source_before": before, "source_after": after, "source_unchanged": before == after,
        "status": "PASS_SQL_STATEMENTS_ONLY" if result.wasSuccessful() and before == after else "FAIL"}
    (output / "RESULT.json").write_bytes((json.dumps(report, sort_keys=True, indent=2) + "\n").encode())
    return 0 if report["status"] == "PASS_SQL_STATEMENTS_ONLY" else 1


if __name__ == "__main__":
    raise SystemExit(main())

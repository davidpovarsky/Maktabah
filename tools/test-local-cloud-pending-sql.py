#!/usr/bin/env python3
"""Real SQLite premises for the owned pending ACK; not a Swift/CloudKit run.

Use the unchanged original schema and exact new DELETE statement on owned DBs.
These controls establish counter and snapshot behavior; the complete production
Swift ownership/session fixture must still run on an actual installed Apple SDK.
"""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import re
import sqlite3
import tempfile


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--root", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    args = p.parse_args()
    if args.output.exists():
        raise RuntimeError("Preserve prior receipt")
    original_path = args.root / "Source/Core/CloudKit/SyncPendingStore.swift"
    candidate_path = args.root / "Source/ChavrusaText/Annotations/LocalEditor/AnnotationLocalEditorPersistence.swift"
    original = original_path.read_text()
    candidate = candidate_path.read_text()
    schema = re.search(r'static let createTableSQL = """\n(.*?)\n\s*"""', original, re.S).group(1)
    replacements = re.findall(r'query: "(INSERT OR REPLACE INTO sync_pending \(ck_record_id, operation, queued_at\) VALUES \(\?, \?, \?\);)"', original)
    if len(replacements) != 1:
        raise RuntimeError("Original pending replacement not uniquely found")
    original_replace = replacements[0]
    deletes = re.findall(r'"""\n\s*(DELETE FROM sync_pending WHERE rowid = .*?)\n\s*"""', candidate, re.S)
    if len(deletes) != 1:
        raise RuntimeError("Exact new pending DELETE not uniquely found")
    owned_delete = deletes[0]
    expected = "DELETE FROM sync_pending WHERE rowid = ? AND ck_record_id = ? COLLATE BINARY AND operation = 'upload' AND queued_at = ?;"
    if " ".join(owned_delete.split()) != expected:
        raise RuntimeError("Owned DELETE statement changed")
    before = {str(x.relative_to(args.root)): hashlib.sha256(x.read_bytes()).hexdigest() for x in (original_path, candidate_path)}
    rows = []

    def require(value, message):
        if not value:
            raise AssertionError(message)

    def stamp(connection):
        return connection.total_changes, connection.execute("PRAGMA data_version;").fetchone()[0]

    def pending(connection):
        return connection.execute("SELECT rowid,ck_record_id,operation,queued_at FROM sync_pending ORDER BY rowid;").fetchall()

    with tempfile.TemporaryDirectory(prefix="otzaria-owned-pending-sql-") as directory:
        owned = Path(directory)

        def run(name, work):
            database = owned / (name + ".sqlite")
            first = sqlite3.connect(database, isolation_level=None, timeout=0.1)
            second = None
            try:
                require(first.execute("PRAGMA journal_mode=WAL;").fetchone()[0] == "wal", "WAL unavailable")
                first.execute(schema)
                first.execute("CREATE TABLE unrelated(value INTEGER NOT NULL);")
                first.execute("INSERT INTO unrelated VALUES(0);")
                first.execute("INSERT INTO sync_pending VALUES('same-uuid','upload',2000000000);")
                first.execute("INSERT INTO sync_pending VALUES('other-delete','delete',1999999999);")
                second = sqlite3.connect(database, isolation_level=None, timeout=0.1)
                observations = work(first, second)
                rows.append({"name": name, "status": "PASS", "observations": observations})
            except Exception as error:
                rows.append({"name": name, "status": "FAIL", "error": str(error)})
            finally:
                for connection in (second, first):
                    if connection is not None:
                        if connection.in_transaction:
                            connection.rollback()
                        connection.close()

        def same_second_legacy(first, second):
            before = pending(first)
            first.execute("INSERT OR REPLACE INTO sync_pending VALUES('same-uuid','upload',2000000000);")
            replacement = pending(first)
            # Original SyncPendingStore's optional maxQueuedAt is seconds-only;
            # even this narrower original query removes the newer replacement.
            first.execute("DELETE FROM sync_pending WHERE ck_record_id IN (?) AND operation = ? AND queued_at <= ?;",
                          ("same-uuid", "upload", 2000000000))
            remaining = pending(first)
            require(not any(x[1] == "same-uuid" for x in remaining), "Counterexample did not reproduce")
            require(replacement != before, "Actual replacement missing")
            return {"old": before, "replacement": replacement, "legacy_remaining": remaining}
        run("seconds_only_original_queue_removal_can_erase_newer_replacement", same_second_legacy)

        def same_connection(first, second):
            old = stamp(first)
            first.execute("INSERT OR REPLACE INTO sync_pending VALUES('same-uuid','upload',2000000000);")
            new = stamp(first)
            require(new[0] > old[0] and new[1] == old[1], "Same connection counter premise failed")
            return {"before": old, "after": new, "guard_must_defer": True}
        run("same_connection_same_second_replacement_advances_total_changes", same_connection)

        def foreign_original_replace(first, second):
            old = stamp(first); contents = pending(first)
            second.execute(original_replace, ("same-uuid", "upload", 2000000000))
            new = stamp(first); replaced = pending(first)
            old_row = next(x for x in contents if x[1] == "same-uuid")
            new_row = next(x for x in replaced if x[1] == "same-uuid")
            require(old_row[1:] == new_row[1:] and new[0] == old[0] and new[1] != old[1], "Original foreign replacement was not detected")
            return {"before": old, "after": new, "old_row": old_row, "new_row": new_row,
                    "original_columns_identical": True, "guard_must_defer": True}
        run("foreign_original_same_second_replacement_advances_data_version", foreign_original_replace)

        def foreign_same_bytes(first, second):
            old = stamp(first); contents = pending(first)
            row = next(x for x in contents if x[1] == "same-uuid")
            # An adversarial same-rowid replacement is stronger than the real
            # producer's INSERT OR REPLACE, which does not supply rowid.
            second.execute("INSERT OR REPLACE INTO sync_pending(rowid,ck_record_id,operation,queued_at) VALUES(?,?,?,?);", row)
            new = stamp(first)
            require(pending(first) == contents and new[0] == old[0] and new[1] != old[1], "Same-rowid foreign replacement was not detected")
            return {"before": old, "after": new, "all_queue_values_identical": True, "guard_must_defer": True}
        run("foreign_identical_row_replacement_advances_data_version", foreign_same_bytes)

        def foreign_noop(first, second):
            old = stamp(first); contents = pending(first)
            second.execute("UPDATE sync_pending SET queued_at=queued_at WHERE ck_record_id='same-uuid';")
            new = stamp(first)
            require(pending(first) == contents and new[0] == old[0], "No-op changed observed pending state")
            return {"before": old, "after": new, "queue_values_identical": True,
                    "foreign_sql_changes": second.total_changes,
                    "scope": "SQLite may omit physical writes for a no-op UPDATE; it is not the original pending enqueue operation"}
        run("foreign_noop_update_does_not_claim_a_new_pending_enqueue", foreign_noop)

        def foreign_aba(first, second):
            old = stamp(first); contents = pending(first)
            second.execute("BEGIN;")
            second.execute("UPDATE sync_pending SET queued_at=2000000001 WHERE ck_record_id='same-uuid';")
            second.execute("UPDATE sync_pending SET queued_at=2000000000 WHERE ck_record_id='same-uuid';")
            second.commit()
            new = stamp(first)
            require(pending(first) == contents and new[0] == old[0] and new[1] != old[1], "Committed foreign ABA was not detected")
            return {"before": old, "after": new, "queue_values_restored": True, "guard_must_defer": True}
        run("foreign_committed_pending_aba_advances_data_version", foreign_aba)

        def foreign_delete_recreate(first, second):
            # Force reuse of the original rowid and every value, with a real
            # delete/reinsert transaction that must still be detected.
            old = stamp(first); contents = pending(first)
            row = next(x for x in contents if x[1] == "same-uuid")
            second.execute("BEGIN;")
            second.execute("DELETE FROM sync_pending WHERE ck_record_id=?;", (row[1],))
            second.execute("INSERT INTO sync_pending(rowid,ck_record_id,operation,queued_at) VALUES(?,?,?,?);", row)
            second.commit()
            new = stamp(first)
            require(pending(first) == contents and new[0] == old[0] and new[1] != old[1], "Foreign delete/recreate was not detected")
            return {"before": old, "after": new, "rowid_and_values_restored": True, "guard_must_defer": True}
        run("foreign_delete_recreate_same_rowid_advances_data_version", foreign_delete_recreate)

        def foreign_read_snapshot(first, second):
            first.execute("BEGIN;")
            old = pending(first)
            second.execute("INSERT OR REPLACE INTO sync_pending VALUES('same-uuid','upload',2000000000);")
            target = next(x for x in old if x[1] == "same-uuid")
            try:
                first.execute(owned_delete, (target[0], target[1], target[3]))
            except sqlite3.OperationalError as error:
                code = error.sqlite_errorcode
                require(code == sqlite3.SQLITE_BUSY_SNAPSHOT, "Unexpected read-to-write rejection")
            else:
                raise AssertionError("Stale WAL reader upgraded and deleted")
            first.rollback()
            require(any(x[1] == "same-uuid" for x in pending(first)), "New queue row was lost")
            return {"sqlite_errorcode": code, "newer_pending_preserved": True}
        run("foreign_commit_after_read_cannot_upgrade_stale_ack_transaction", foreign_read_snapshot)

        def rollback(first, second):
            old = stamp(first); values = pending(first)
            second.execute("BEGIN;")
            second.execute("UPDATE sync_pending SET queued_at=2000000001 WHERE ck_record_id='same-uuid';")
            second.rollback()
            require(stamp(first) == old and pending(first) == values, "Rolled-back foreign effect escaped")
            return {"before": old, "after": stamp(first), "pending_unchanged": True}
        run("foreign_rollback_has_no_committed_pending_change", rollback)

        def committed_capture(first, second):
            first.execute("BEGIN;")
            first.execute("UPDATE unrelated SET value=1;")
            first.execute("INSERT OR REPLACE INTO sync_pending VALUES('same-uuid','upload',2000000001);")
            provisional = stamp(first)
            first.commit()
            require(stamp(first) == provisional, "Own COMMIT unexpectedly restamped counters")
            return {"after_own_writes": provisional, "after_commit": stamp(first)}
        run("own_write_stamp_survives_outer_commit_for_post_commit_validation", committed_capture)

        def unrelated(first, second):
            old = stamp(first); values = pending(first)
            first.execute("UPDATE unrelated SET value=1;")
            require(stamp(first) != old and pending(first) == values, "Unrelated-write deferral premise failed")
            return {"before": old, "after": stamp(first), "queue_unchanged": True, "conservative_deferral": True}
        run("unrelated_write_is_conservatively_detectable", unrelated)

        def exact_delete(first, second):
            old = stamp(first); target = next(x for x in pending(first) if x[1] == "same-uuid")
            first.execute("BEGIN;")
            first.execute(owned_delete, (target[0], target[1], target[3]))
            require(first.execute("SELECT changes();").fetchone()[0] == 1, "Exact ACK did not affect exactly one row")
            first.commit()
            require(first.total_changes == old[0] + 1 and pending(first) == [(2, "other-delete", "delete", 1999999999)],
                    "Exact ACK changed another pending row")
            return {"total_changes_before": old[0], "after": first.total_changes, "unrelated_delete_preserved": True}
        run("exact_candidate_delete_preserves_unrelated_original_pending_delete", exact_delete)

        def later_delete(first, second):
            target = next(x for x in pending(first) if x[1] == "same-uuid")
            first.execute("UPDATE sync_pending SET operation='delete' WHERE ck_record_id='same-uuid';")
            first.execute(owned_delete, (target[0], target[1], target[3]))
            require(first.execute("SELECT changes();").fetchone()[0] == 0
                    and any(x[1:3] == ("same-uuid", "delete") for x in pending(first)), "Later deletion was erased")
            return {"candidate_delete_changes": 0, "later_delete_preserved": True}
        run("candidate_delete_never_removes_later_delete_operation", later_delete)

    after = {str(x.relative_to(args.root)): hashlib.sha256(x.read_bytes()).hexdigest() for x in (original_path, candidate_path)}
    require(before == after and len(rows) == 13, "Source changed or missing controls")
    failed = sum(x["status"] != "PASS" for x in rows)
    result = {"status": "PASS_SQLITE_PREMISES_ONLY" if failed == 0 else "FAIL",
        "observed_at": datetime.datetime.now(datetime.timezone.utc).isoformat(), "sqlite_version": sqlite3.sqlite_version,
        "cases": rows, "passed": len(rows)-failed, "failed": failed, "source_before": before, "source_after": after,
        "swift_executed": 0, "cloudkit_executed": 0, "native_ui_executed": 0,
        "scope": "Actual SQLite counter, transaction and exact SQL premises only; full production Swift controls remain NOT_RUN"}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes((json.dumps(result, indent=2, sort_keys=True) + "\n").encode())
    print(json.dumps({"status": result["status"], "passed": result["passed"], "failed": failed, "swift_executed": 0}))
    raise SystemExit(1 if failed else 0)


if __name__ == "__main__":
    main()

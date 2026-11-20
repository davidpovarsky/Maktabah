#!/usr/bin/env python3
"""Negative controls for the Python evidence gate, not execution of Swift."""
from pathlib import Path
import argparse
import base64
import copy
import datetime
import hashlib
import importlib.util
import json
import sqlite3
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


gate = load("local_editor_gate", ROOT / "tools/hq-local-annotation-editor-acceptance.py")
sql = load("local_editor_sql", ROOT / "tools/test-local-annotation-editor-sql.py")


class GateControls(unittest.TestCase):
    def setUp(self):
        self.names = gate.declaration_names((ROOT / gate.SOURCES[-1]).read_text())
        self.rows = [{"name": name, "status": "PASS"} for name in self.names]
        self.first = self.record(1, 101)
        self.second = self.record(2, 102)
        self.observations = [self.observation(i) for i in range(3)]

    def record(self, revision, pid):
        raw = ("opaque fixture payload " + str(revision)).encode()
        source = ("explicit synthetic source " + str(revision)).encode()
        return {"processID": pid, "databasePath": "/not-opened-by-receipt-controls",
                "rowID": 1, "annotationUUID": "11111111-2222-3333-4444-555555555555",
                "mutationID": ("AAAAAAAA" if revision == 1 else "BBBBBBBB") + "-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
                "revision": revision, "note": "preview" + str(revision), "tags": ["עיון"],
                "source": base64.b64encode(source).decode(), "sourceSHA256": hashlib.sha256(source).hexdigest(),
                "payload": base64.b64encode(raw).decode(), "payloadSHA256": hashlib.sha256(raw).hexdigest(),
                "body": base64.b64encode(b"fixture only").decode()}

    def observation(self, i):
        record = self.first if i == 0 else self.second
        return {"mode": gate.COLD_MODES[i], "processID": 101 + i,
                "priorProcessID": None if i == 0 else 100 + i,
                "annotationUUID": record["annotationUUID"], "revision": 1 if i == 0 else 2,
                "payloadSHA256": record["payloadSHA256"], "sourceSHA256": record["sourceSHA256"],
                "originalPendingUpload": True, "exchangeDestinations": 0,
                "sqliteVersion": "explicit synthetic receipt", "status": "PASS_COMPONENT_COLD_PROCESS"}

    def cold(self):
        gate.verify_cold(self.observations, self.first, self.second)

    def test_exact_declared_component_set_is_required(self):
        gate.verify_cases(self.rows, self.names)
        with self.assertRaises(ValueError): gate.verify_cases(self.rows[:-1], self.names)

    def test_duplicate_case_cannot_replace_missing_case(self):
        self.rows[-1] = copy.deepcopy(self.rows[0])
        with self.assertRaises(ValueError): gate.verify_cases(self.rows, self.names)

    def test_unexecuted_case_is_not_success(self):
        for status in ("FAIL", "SKIP", "NOT_RUN", None):
            self.rows[0]["status"] = status
            with self.assertRaises(ValueError): gate.verify_cases(self.rows, self.names)

    def test_pass_label_does_not_hide_case_error(self):
        self.rows[0]["error"] = "actual failure"
        with self.assertRaises(ValueError): gate.verify_cases(self.rows, self.names)

    def test_three_ordered_cold_processes_are_required(self):
        self.cold()
        self.observations.pop()
        with self.assertRaises(ValueError): self.cold()

    def test_same_process_cannot_claim_cold_reopen(self):
        self.observations[2]["processID"] = 102
        with self.assertRaises(ValueError): self.cold()

    def test_process_lineage_is_not_inferred_from_uuid(self):
        self.observations[2]["priorProcessID"] = 101
        with self.assertRaises(ValueError): self.cold()

    def test_bool_cannot_become_revision(self):
        self.observations[0]["revision"] = True
        with self.assertRaises(ValueError): self.cold()
        self.observations[0]["revision"] = 1
        self.first["revision"] = True
        with self.assertRaises(ValueError): self.cold()

    def test_changed_annotation_uuid_fails(self):
        self.second["annotationUUID"] = "99999999-2222-3333-4444-555555555555"
        with self.assertRaises(ValueError): self.cold()

    def test_reused_mutation_is_not_new_revision(self):
        self.second["mutationID"] = self.first["mutationID"]
        with self.assertRaises(ValueError): self.cold()

    def test_payload_bytes_are_hashed_independently(self):
        self.second["payload"] = base64.b64encode(b"changed").decode()
        with self.assertRaises(ValueError): self.cold()

    def test_source_bytes_are_hashed_independently(self):
        self.first["source"] = base64.b64encode(b"changed").decode()
        with self.assertRaises(ValueError): self.cold()

    def test_external_destination_is_not_offline_success(self):
        self.observations[1]["exchangeDestinations"] = 1
        with self.assertRaises(ValueError): self.cold()

    def test_original_pending_upload_is_required(self):
        self.observations[2]["originalPendingUpload"] = False
        with self.assertRaises(ValueError): self.cold()

    def test_independent_database_verifier_uses_actual_original_schema(self):
        statements = sql.source_sql(ROOT)
        with tempfile.TemporaryDirectory(prefix="local-editor-gate-owned-") as directory:
            root = Path(directory)
            profile = root / "cold-profile"
            profile.mkdir()
            database = profile / "Annotations.sqlite"
            connection = sqlite3.connect(database)
            try:
                for statement in statements["original"] + statements["install"]:
                    connection.execute(statement)
                for record in (self.first, self.second): record["databasePath"] = str(database)
                connection.execute("INSERT INTO annotations VALUES(1,28,2,4,5,6,7,'#123456',1,?,1700000001,'context',1,9,?,1700000002,'opaque-locator')", (self.second["note"], self.second["annotationUUID"]))
                connection.execute("INSERT INTO tags VALUES(1,'עיון','עיון')")
                connection.execute("INSERT INTO annotation_tags VALUES(1,1)")
                connection.execute("INSERT INTO sync_pending VALUES(?,'upload',1700000002)", (self.second["annotationUUID"],))
                connection.execute("INSERT INTO sync_pending VALUES('unrelated-delete','delete',1700000000)")
                for record in (self.first, self.second):
                    connection.execute(statements["version"], (record["mutationID"], sql.NAMESPACE, record["annotationUUID"], record["revision"], record["sourceSHA256"], record["payloadSHA256"], record["payload"], "active", "[]"))
                    connection.execute(statements["head"], (sql.NAMESPACE, record["annotationUUID"], record["revision"]))
                connection.commit()
                proof = gate.verify_sqlite(root, self.first, self.second)
                self.assertEqual(proof["versions"], 2)
                connection.execute("UPDATE otzaria_annotation_exchange_heads SET revision=1")
                connection.commit()
                with self.assertRaisesRegex(ValueError, "current rich head"):
                    gate.verify_sqlite(root, self.first, self.second)
            finally:
                connection.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--artifacts-dir", required=True, type=Path)
    args = parser.parse_args()
    args.artifacts_dir.mkdir(parents=True, exist_ok=True)
    if (args.artifacts_dir / "RESULT.json").exists(): raise RuntimeError("Use a fresh evidence directory")
    paths = ["tools/test-local-annotation-editor-gate.py", "tools/hq-local-annotation-editor-acceptance.py",
             "tools/test-local-annotation-editor-sql.py", *gate.SOURCES]
    before = {p: gate.sha(ROOT / p) for p in paths}
    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(GateControls))
    after = {p: gate.sha(ROOT / p) for p in paths}
    report = {"observed_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "scope": "PYTHON_RECEIPT_GATE_CONTROLS_WITH_EXPLICIT_SYNTHETIC_RECEIPTS",
              "tests": result.testsRun, "failures": len(result.failures), "errors": len(result.errors),
              "skipped": len(result.skipped), "swift_executed": 0, "native_executed": 0,
              "source_before": before, "source_after": after,
              "status": "PASS" if result.wasSuccessful() and before == after else "FAIL"}
    gate.write_json(args.artifacts_dir / "RESULT.json", report)
    raise SystemExit(0 if report["status"] == "PASS" else 1)

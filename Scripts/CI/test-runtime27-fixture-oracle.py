#!/usr/bin/env python3
"""Independent DB oracle safety/identity fixtures; no simulator execution."""
import hashlib
import json
import os
from pathlib import Path
import runpy
import sqlite3
import tempfile
import unittest
from contextlib import closing

derive = runpy.run_path(str(Path(__file__).with_name("runtime27-fixture-oracle.py")))["derive_oracle"]


class FixtureOracleTests(unittest.TestCase):
    def setUp(self):
        self.previous = Path.cwd()
        self.folder = tempfile.TemporaryDirectory()
        self.root = Path(self.folder.name)
        os.chdir(self.root)
        self.addCleanup(self.cleanup)
        self.udid = "00000000-0000-0000-0000-000000000027"
        self.database = self.root / "Devices" / self.udid / "data/Containers/owned/seforim.db"
        self.database.parent.mkdir(parents=True)
        with closing(sqlite3.connect(self.database)) as db, db:
            db.executescript("CREATE TABLE book(id INTEGER PRIMARY KEY,title TEXT); CREATE TABLE line(id INTEGER PRIMARY KEY,lineIndex INTEGER); CREATE TABLE link(id INTEGER PRIMARY KEY,sourceBookId INTEGER,sourceLineId INTEGER);")
            db.execute("INSERT INTO book VALUES(1,'fallback')")
            db.execute("INSERT INTO book VALUES(3,'מסילת ישרים')")
            db.execute("INSERT INTO line VALUES(9,17)")
            db.execute("INSERT INTO link VALUES(2,3,9)")
        self.report = {"passed": True, "profileID": "miniTest10", "profileVersion": 6, "expectedSHA256": "pinned",
                       "actualSHA256": "pinned", "shaMatched": True, "quickCheck": "ok", "finalPath": str(self.database)}
        Path("build/artifacts/runtime27").mkdir(parents=True)

    def cleanup(self):
        os.chdir(self.previous)
        self.folder.cleanup()

    def run_oracle(self, udid=None):
        Path("build/artifacts/miniTest10-native-fixture-install-11.json").write_text(json.dumps(self.report))
        return derive(udid or self.udid, "11")

    def test_independent_first_link_identity_and_no_writes(self):
        before = hashlib.sha256(self.database.read_bytes()).hexdigest()
        environment = self.run_oracle()
        self.assertEqual(environment["TEST_RUNNER_R27_EXPECTED_OTZARIA_WORK_KEY"], "book:3")
        self.assertEqual(environment["TEST_RUNNER_R27_EXPECTED_OTZARIA_BOOK_TITLE"], "מסילת ישרים")
        self.assertEqual(hashlib.sha256(self.database.read_bytes()).hexdigest(), before)
        evidence = json.loads(Path("build/artifacts/runtime27/fixture-oracle-11.json").read_text())
        self.assertFalse(evidence["ui_observation_used"])
        self.assertEqual(evidence["selected"]["lineIndex"], 17)

    def test_only_no_link_uses_original_book1_fallback(self):
        with closing(sqlite3.connect(self.database)) as db, db:
            db.execute("DELETE FROM link")
        self.assertEqual(self.run_oracle()["TEST_RUNNER_R27_EXPECTED_OTZARIA_WORK_KEY"], "book:1")

    def test_other_device_never_read_as_oracle(self):
        with self.assertRaises(RuntimeError):
            self.run_oracle("different-owned-device")

    def test_unverified_native_data_never_counts_as_ready(self):
        for key, value in [("passed", False), ("profileID", "production"), ("shaMatched", False),
                           ("expectedSHA256", None), ("actualSHA256", "different"), ("quickCheck", "corrupt")]:
            with self.subTest(key=key):
                original = self.report[key]
                self.report[key] = value
                with self.assertRaises(RuntimeError):
                    self.run_oracle()
                self.report[key] = original


if __name__ == "__main__":
    unittest.main(verbosity=2)

#!/usr/bin/env python3
"""Python admission/collection controls only; zero Swift/Repository execution."""
from __future__ import annotations

import argparse
import copy
import importlib.util
import json
import os
from pathlib import Path
import signal
import sqlite3
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


route = load(ROOT / "Scripts/CI/annotation-disconnect-apple.py", "disconnect_route_under_test")
driver = load(ROOT / "tools/hq-annotation-disconnect-acceptance.py", "disconnect_driver_under_test")


def authority():
    head = "a" * 40
    ref = "refs/heads/" + route.BRANCH
    environment = {"GITHUB_EVENT_NAME": "push", "GITHUB_REPOSITORY": route.REPOSITORY,
        "GITHUB_REPOSITORY_ID": str(route.REPOSITORY_ID), "GITHUB_REF": ref,
        "GITHUB_WORKFLOW_REF": route.REPOSITORY + "/" + route.WORKFLOW + "@" + ref,
        "GITHUB_SHA": head, "EXPECTED_CHECKOUT_SHA": head, "GITHUB_WORKFLOW_SHA": head,
        "GITHUB_RUN_ID": "123", "GITHUB_RUN_ATTEMPT": "1"}
    event = {"ref": ref, "after": head, "deleted": False,
             "repository": {"id": route.REPOSITORY_ID, "full_name": route.REPOSITORY, "fork": False}}
    return environment, event


def process_receipt(*, baseline=True):
    return {"timed_out": baseline, "timeout_seconds": driver.BASELINE_TIMEOUT if baseline else driver.CASE_TIMEOUT,
            "pid": 90001, "process_group": 90001, "terminate_sent": baseline,
            "reaped": True, "process_group_gone": True,
            "exit_code": -signal.SIGTERM if baseline else 0}


def write_markers(root, events):
    directory = root / "markers"
    directory.mkdir()
    for index, event in enumerate(events, 1):
        driver.write_json(directory / f"{index:03d}-{event}.json",
                          {"sequence": index, "event": event, "uptimeNanoseconds": index * 1000})


def cold_fixture(root, name=driver.BASELINE_NAME):
    """Synthetic owned SQLite rows test only the independent reader's rejection.

    This is not a replacement for the Swift production Repository fixture.
    """
    sub = root / "progress"
    sub.mkdir()
    database = sub / "Annotations.sqlite"
    identity = "11111111-2222-4333-8444-555555555555"
    note = driver.COMMITTED_NOTE if name in ("progress_default", "progress_captured") else driver.ORIGINAL_NOTE
    connection = sqlite3.connect(database)
    connection.executescript("""
    CREATE TABLE annotations(id INTEGER,ckRecordId TEXT,note TEXT);
    CREATE TABLE tags(id INTEGER,name TEXT);
    CREATE TABLE annotation_tags(annotationId INTEGER,tagId INTEGER);
    CREATE TABLE sync_pending(ck_record_id TEXT,operation TEXT);
    INSERT INTO tags VALUES(1,'second'),(2,'עיון');
    INSERT INTO annotation_tags VALUES(1,1),(1,2);
    INSERT INTO sync_pending VALUES('unrelated-delete','delete');
    """)
    connection.execute("INSERT INTO annotations VALUES(1,?,?)", (identity, note))
    connection.execute("INSERT INTO sync_pending VALUES(?,'upload')", (identity,))
    connection.commit()
    connection.close()
    driver.write_json(root / "COLD_EXPECTED.json", {"databaseRelativePath": "progress/Annotations.sqlite",
        "annotationID": 1, "annotationUUID": identity, "note": note, "annotations": 1, "tags": 2, "pending": 2,
        "uncommittedNote": driver.UNCOMMITTED_NOTE})
    return database


class Controls(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="owned-disconnect-python-controls-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def test_exact_push_authority_accepts_actual_attempt_numbers(self):
        env, event = authority()
        self.assertEqual(route.identity(env, event)["run_attempt"], 1)
        env["GITHUB_RUN_ATTEMPT"] = "2"
        self.assertEqual(route.identity(env, event)["run_attempt"], 2)

    def test_manual_pull_request_schedule_and_wrong_ref_are_denied(self):
        for key, bad in (("GITHUB_EVENT_NAME", "workflow_dispatch"), ("GITHUB_EVENT_NAME", "pull_request"),
                         ("GITHUB_EVENT_NAME", "schedule"), ("GITHUB_REF", "refs/heads/main")):
            env, event = authority()
            env[key] = bad
            with self.subTest(key=key, bad=bad), self.assertRaises(ValueError):
                route.identity(env, event)

    def test_wrong_repository_workflow_and_checkout_are_denied(self):
        for key, bad in (("GITHUB_REPOSITORY", "someone/fork"), ("GITHUB_REPOSITORY_ID", "1"),
                         ("GITHUB_WORKFLOW_REF", "other/path@ref"), ("EXPECTED_CHECKOUT_SHA", "b" * 40),
                         ("GITHUB_WORKFLOW_SHA", "b" * 40)):
            env, event = authority()
            env[key] = bad
            with self.subTest(key=key), self.assertRaises(ValueError):
                route.identity(env, event)

    def test_zero_missing_and_noninteger_run_attempt_are_denied(self):
        for key in ("GITHUB_RUN_ID", "GITHUB_RUN_ATTEMPT"):
            for value in ("", "0", "-1", "01", "1.0", "true"):
                env, event = authority()
                env[key] = value
                with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                    route.identity(env, event)

    def test_mixed_payload_head_ref_repository_and_deletion_are_denied(self):
        for change in (lambda e: e.update(after="b" * 40), lambda e: e.update(ref="refs/heads/main"),
                       lambda e: e.update(deleted=True), lambda e: e["repository"].update(fork=True),
                       lambda e: e["repository"].update(id=str(route.REPOSITORY_ID))):
            env, event = authority()
            change(event)
            with self.assertRaises(ValueError):
                route.identity(env, event)

    def test_reviewed_binding_and_unchanged_counts(self):
        binding = route.load_json(ROOT / route.BINDING)
        # A synthetic positive admission input; never activate an unsealed
        # on-disk route while the shared Apple compile repair is pending.
        binding["source_sealed"] = True
        route.validate_binding(binding)
        for name in binding["counts"]:
            bad = copy.deepcopy(binding)
            bad["counts"][name] += 1
            with self.subTest(name=name), self.assertRaises(ValueError):
                route.validate_binding(bad)
        bad = copy.deepcopy(binding)
        bad["counts"]["original_deadlock_red"] = True
        with self.assertRaises(ValueError):
            route.validate_binding(bad)

    def test_draft_baseline_and_new_core_substitutions_are_denied(self):
        original = route.load_json(ROOT / route.BINDING)
        original["source_sealed"] = True
        for key, value in (("source_sealed", False), ("source_base", "b" * 40), ("core_tree", "c" * 40)):
            bad = copy.deepcopy(original)
            bad[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                route.validate_binding(bad)
        bad = copy.deepcopy(original)
        bad["original_repository"]["sha256"] = "a" * 64
        with self.assertRaises(ValueError):
            route.validate_binding(bad)

    def test_actual_ten_declarations_and_reviewed_whole_repository_hash(self):
        text = (ROOT / driver.FIXTURE).read_text()
        self.assertEqual(driver.declaration_names(text), list(driver.CASES))
        self.assertEqual(driver.sha(ROOT / driver.REPOSITORY), driver.CANDIDATE_SHA256)
        for value in (text.replace('case "progress_default":', 'case "renamed":', 1),
                      text + '\n        case "extra":\n'):
            with self.assertRaises(ValueError):
                driver.declaration_names(value)

    def test_numbered_original_cycle_is_red_never_a_pass(self):
        write_markers(self.root, driver.BASELINE_MARKERS)
        value = driver.verify_baseline(self.root, process_receipt())
        self.assertEqual(value["status"], "EXPECTED_ORIGINAL_DEADLOCK_REPRODUCED")
        self.assertIs(value["counts_as_pass"], False)

    def test_timeout_without_lifetime_or_helper_marker_is_rejected(self):
        write_markers(self.root, driver.BASELINE_MARKERS[:3])
        with self.assertRaises(ValueError):
            driver.verify_baseline(self.root, process_receipt())

    def test_missing_terminate_reap_group_and_wrong_exit_are_rejected(self):
        write_markers(self.root, driver.BASELINE_MARKERS)
        for key, value in (("timed_out", False), ("terminate_sent", False), ("reaped", False),
                           ("process_group_gone", False), ("process_group", 2), ("exit_code", 0),
                           ("exit_code", 1), ("timeout_seconds", 1)):
            receipt = process_receipt()
            receipt[key] = value
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                driver.verify_baseline(self.root, receipt)

    def test_original_error_or_early_completion_never_counts_as_deadlock(self):
        write_markers(self.root, driver.BASELINE_MARKERS)
        driver.write_json(self.root / "CASE.json", {"name": driver.BASELINE_NAME, "status": "FAIL"})
        with self.assertRaises(ValueError):
            driver.verify_baseline(self.root, process_receipt())

    def test_duplicate_sequence_and_regressing_monotonic_marker_are_rejected(self):
        write_markers(self.root, driver.BASELINE_MARKERS)
        path = self.root / "markers/003-disconnect_requested.json"
        original = driver.read_json(path)
        for key, value in (("sequence", 2), ("uptimeNanoseconds", 1)):
            bad = copy.deepcopy(original)
            bad[key] = value
            driver.write_json(path, bad)
            with self.subTest(key=key), self.assertRaises(ValueError):
                driver.verify_baseline(self.root, process_receipt())

    def test_candidate_progress_requires_real_probe_and_both_returns(self):
        write_markers(self.root, driver.PROGRESS_MARKERS)
        driver.write_json(self.root / "CASE.json", {"name": "progress_default", "status": "PASS", "sourceKind": "candidate"})
        self.assertEqual(driver.verify_candidate(self.root, "progress_default", process_receipt(baseline=False))["status"], "PASS")
        (self.root / "markers/004-repository_state_read_while_database_held.json").unlink()
        with self.assertRaises(ValueError):
            driver.verify_candidate(self.root, "progress_default", process_receipt(baseline=False))

    def test_candidate_failed_skipped_wrong_name_source_and_timeout_are_denied(self):
        name = "matched_capture_detaches_only_original_owner"
        write_markers(self.root, ())
        original = {"name": name, "status": "PASS", "sourceKind": "candidate"}
        for key, value in (("status", "SKIP"), ("status", "FAIL"), ("name", "wrong"), ("sourceKind", "original-baseline"), ("error", "actual failure")):
            row = dict(original)
            row[key] = value
            driver.write_json(self.root / "CASE.json", row)
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                driver.verify_candidate(self.root, name, process_receipt(baseline=False))
        driver.write_json(self.root / "CASE.json", original)
        receipt = process_receipt(baseline=False)
        receipt["timed_out"] = True
        with self.assertRaises(ValueError):
            driver.verify_candidate(self.root, name, receipt)

    def test_independent_sqlite_cold_reader_checks_original_note_uuid_tags_and_queue(self):
        cold_fixture(self.root)
        row = driver.cold_read(self.root, driver.BASELINE_NAME)
        self.assertEqual((row["annotation_count"], row["tag_count"], row["pending_count"]), (1, 2, 2))
        self.assertEqual(row["note"], driver.ORIGINAL_NOTE)

    def test_uncommitted_write_or_lost_tag_or_pending_delete_is_rejected(self):
        database = cold_fixture(self.root)
        for statement in ("UPDATE annotations SET note='uncommitted-before-disconnect'",
                          "DELETE FROM annotation_tags WHERE tagId=2",
                          "DELETE FROM sync_pending WHERE operation='delete'"):
            connection = sqlite3.connect(database)
            before = list(connection.iterdump())
            connection.execute(statement)
            connection.commit()
            connection.close()
            with self.subTest(statement=statement), self.assertRaises(ValueError):
                driver.cold_read(self.root, driver.BASELINE_NAME)
            database.unlink()
            connection = sqlite3.connect(database)
            connection.executescript("\n".join(before))
            connection.close()

    def test_candidate_progress_cold_read_requires_committed_original_helper_note(self):
        database = cold_fixture(self.root, "progress_default")
        self.assertEqual(driver.cold_read(self.root, "progress_default")["note"], driver.COMMITTED_NOTE)
        connection = sqlite3.connect(database)
        connection.execute("UPDATE annotations SET note=?", (driver.ORIGINAL_NOTE,))
        connection.commit()
        connection.close()
        with self.assertRaises(ValueError):
            driver.cold_read(self.root, "progress_default")

    def test_path_escape_and_symlink_are_denied_without_opening_external_database(self):
        database = cold_fixture(self.root)
        path = self.root / "COLD_EXPECTED.json"
        original = driver.read_json(path)
        bad = dict(original)
        bad["databaseRelativePath"] = "../not-owned/Annotations.sqlite"
        driver.write_json(path, bad)
        with self.assertRaises(ValueError):
            driver.cold_read(self.root, driver.BASELINE_NAME)
        driver.write_json(path, original)
        retained = self.root / "retained.sqlite"
        database.rename(retained)
        database.symlink_to(retained)
        with self.assertRaises(ValueError):
            driver.cold_read(self.root, driver.BASELINE_NAME)

    def test_duplicate_malformed_and_oversized_json_are_rejected(self):
        path = self.root / "value.json"
        for data in (b'{"a":1,"a":2}', b'{"a":NaN}', b'{', b'x' * 65_537):
            path.write_bytes(data)
            with self.subTest(size=len(data)), self.assertRaises((ValueError, json.JSONDecodeError)):
                driver.read_json(path)

    def test_owned_process_timeout_preserves_output_and_does_not_signal_other_group(self):
        outsider = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(10)"], start_new_session=True)
        try:
            report = {"commands": []}
            receipt = driver.run_owned([sys.executable, "-c", "import time; print('BEFORE_TIMEOUT',flush=True); time.sleep(10)"],
                                       self.root, self.root, "owned-timeout", 0.15, report)
            self.assertTrue(receipt["timed_out"] and receipt["reaped"] and receipt["process_group_gone"])
            self.assertEqual(receipt["pid"], receipt["process_group"])
            self.assertIn(b"BEFORE_TIMEOUT", (self.root / "owned-timeout.stdout.log").read_bytes())
            self.assertIsNone(outsider.poll())
            self.assertNotEqual(outsider.pid, receipt["pid"])
        finally:
            if outsider.poll() is None:
                os.killpg(outsider.pid, signal.SIGTERM)
            outsider.wait(timeout=3)

    def test_actual_child_failure_is_retained_and_never_normal_completion(self):
        report = {"commands": []}
        with self.assertRaises(ValueError):
            driver.normal_command([sys.executable, "-c", "import sys; print('ACTUAL_FAILURE'); sys.exit(7)"],
                                  self.root, self.root, "child-error", 3, report)
        self.assertEqual(report["commands"][0]["exit_code"], 7)
        self.assertFalse(report["commands"][0]["timed_out"])
        self.assertIn(b"ACTUAL_FAILURE", (self.root / "child-error.stdout.log").read_bytes())

    def test_source_report_rejects_missing_changed_or_wrong_run_inputs(self):
        observed = {"identity": {"head_sha": "a" * 40}, "files": {"whole.swift": {"sha256": "b" * 64}}}
        original = {"source_before": {"whole.swift": "b" * 64}, "source_after": {"whole.swift": "b" * 64},
                    "source_unchanged": True, "source_sha": "a" * 40}
        route.source_report(original, observed, ["whole.swift"])
        for change in (lambda x: x.update(source_before={}), lambda x: x.update(source_after={}),
                       lambda x: x.update(source_sha="c" * 40), lambda x: x.update(source_unchanged=False)):
            report = copy.deepcopy(original)
            change(report)
            with self.assertRaises(ValueError):
                route.source_report(report, observed, ["whole.swift"])

    def test_source_file_traversal_and_symlink_are_rejected(self):
        (self.root / "actual.swift").write_text("actual bytes")
        (self.root / "linked.swift").symlink_to(self.root / "actual.swift")
        self.assertEqual(route.exact_file(self.root, "actual.swift").read_text(), "actual bytes")
        for relative in ("../actual.swift", "/actual.swift", "linked.swift", "a\\b.swift"):
            with self.subTest(relative=relative), self.assertRaises(ValueError):
                route.exact_file(self.root, relative)


def case_names():
    return unittest.defaultTestLoader.getTestCaseNames(Controls)


class RecordingResult(unittest.TextTestResult):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.rows = []
        self.failed_current = False
    def startTest(self, test):
        self.failed_current = False
        self.started = time.monotonic()
        super().startTest(test)
    def addFailure(self, test, err):
        self.failed_current = True
        super().addFailure(test, err)
    def addError(self, test, err):
        self.failed_current = True
        super().addError(test, err)
    def addSkip(self, test, reason):
        self.failed_current = True
        super().addSkip(test, reason)
    def addSubTest(self, test, subtest, err):
        if err is not None:
            self.failed_current = True
        super().addSubTest(test, subtest, err)
    def stopTest(self, test):
        self.rows.append({"name": test._testMethodName, "status": "FAIL" if self.failed_current else "PASS",
                          "seconds": time.monotonic() - self.started})
        super().stopTest(test)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--artifacts-dir", type=Path, required=True)
    args = parser.parse_args()
    args.artifacts_dir.mkdir(parents=True, exist_ok=True)
    destination = args.artifacts_dir / "RESULT.json"
    if destination.exists():
        raise ValueError("Preserve prior controls attempt")
    result = unittest.TextTestRunner(verbosity=2, resultclass=RecordingResult).run(unittest.defaultTestLoader.loadTestsFromTestCase(Controls))
    expected = case_names()
    passed = result.wasSuccessful() and not result.skipped and [row["name"] for row in result.rows] == expected
    report = {"status": "PASS_PYTHON_ADMISSION_COLLECTION_CONTROLS" if passed else "FAILED",
              "scope": "Synthetic authority/collector inputs, owned Python child process termination and SQLite reader controls only",
              "actual_swift_cases": 0, "actual_repository_races": 0, "native_ui_executed": 0,
              "expected_names": expected, "cases": result.rows, "executed": result.testsRun,
              "failures": len(result.failures), "errors": len(result.errors), "skips": len(result.skipped)}
    destination.write_bytes(route.json_bytes(report))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())

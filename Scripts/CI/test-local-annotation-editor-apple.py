#!/usr/bin/env python3
"""Python gate controls with synthetic process receipts; no Swift execution."""
from pathlib import Path
import argparse
import copy
import datetime
import hashlib
import importlib.util
import json
import os
import shutil
import sqlite3
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]


def load(name, relative):
    spec = importlib.util.spec_from_file_location(name, ROOT / relative)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


gate = load("annotation_apple_gate", "Scripts/CI/local-annotation-editor-apple.py")
local = load("annotation_original_local", gate.LOCAL_DRIVER)
exchange = load("annotation_original_exchange", gate.EXCHANGE_DRIVER)
prior = load("annotation_prior_python_controls", "tools/test-local-annotation-editor-gate.py")
sql = load("annotation_original_sql", "tools/test-local-annotation-editor-sql.py")


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(gate.json_bytes(value))


def environment(head="a" * 40):
    ref = "refs/heads/" + gate.BRANCH
    return {"GITHUB_EVENT_NAME": "push", "GITHUB_REPOSITORY": gate.REPOSITORY,
            "GITHUB_REPOSITORY_ID": str(gate.REPOSITORY_ID), "GITHUB_REF": ref,
            "GITHUB_WORKFLOW_REF": gate.REPOSITORY + "/" + gate.WORKFLOW + "@" + ref,
            "GITHUB_SHA": head, "EXPECTED_CHECKOUT_SHA": head, "GITHUB_WORKFLOW_SHA": head,
            "GITHUB_RUN_ID": "123456", "GITHUB_RUN_ATTEMPT": "1"}


class ResultFixture:
    """Actual original SQL schema, explicitly synthetic execution/receipt rows."""
    def __init__(self, root):
        self.root = Path(root)
        self.binding = gate.load_json(ROOT / gate.BINDING)
        for relative in self.binding["source_pins"]:
            dest = self.root / relative
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / relative, dest)
        self.files = {path: gate.record(self.root, path) for path in self.binding["source_pins"]}
        self.observed = {"identity": gate.environment_identity(environment()),
                         "case_names": gate.declared_cases(self.root), "files": self.files}
        self.outcomes = {name: "success" for name in ("toolchain", "local", "exchange")}
        self.developer = "/synthetic/apple/developer/not-an-executed-sdk"
        write(self.root / gate.ROUTE_OUTPUT / "toolchain.json", {
            "status": "MATCHED_MATRIX_PAIR_SELECTED", "toolchains_installed": False,
            "global_xcode_select_changed": False, "selected": {"developer_dir": self.developer}})
        self.local_owned = self.owned(gate.LOCAL_OUTPUT, "1", local, "LocalAnnotationEditorAcceptance")
        self.exchange_owned = self.owned(gate.EXCHANGE_OUTPUT, "2", exchange, "ExchangeAcceptance")
        self.fixtures = self.local_owned / "fixtures"
        controls = prior.GateControls(); controls.setUp()
        self.first, self.second, self.processes = controls.first, controls.second, controls.observations
        database = self.fixtures / "cold-profile/Annotations.sqlite"
        database.parent.mkdir()
        for record in (self.first, self.second):
            record["databasePath"] = str(database)
        statements = sql.source_sql(self.root)
        connection = sqlite3.connect(database)
        try:
            for statement in statements["original"] + statements["install"]:
                connection.execute(statement)
            connection.execute("INSERT INTO annotations VALUES(1,28,2,4,5,6,7,'#123456',1,?,1700000001,'context',1,9,?,1700000002,'opaque-locator')",
                               (self.second["note"], self.second["annotationUUID"]))
            connection.execute("INSERT INTO tags VALUES(1,'עיון','עיון')")
            connection.execute("INSERT INTO annotation_tags VALUES(1,1)")
            connection.execute("INSERT INTO sync_pending VALUES(?,'upload',1700000002)", (self.second["annotationUUID"],))
            connection.execute("INSERT INTO sync_pending VALUES('unrelated-delete','delete',1700000000)")
            for record in (self.first, self.second):
                connection.execute(statements["version"], (record["mutationID"], sql.NAMESPACE,
                    record["annotationUUID"], record["revision"], record["sourceSHA256"],
                    record["payloadSHA256"], record["payload"], "active", "[]"))
                connection.execute(statements["head"], (sql.NAMESPACE, record["annotationUUID"], record["revision"]))
            connection.commit()
        finally:
            connection.close()
        write(self.fixtures / "cold-expected-1.json", self.first)
        write(self.fixtures / "cold-expected-2.json", self.second)
        local_sources = set(local.SOURCES) | {gate.LOCAL_DRIVER, "Maktabah.xcodeproj/project.pbxproj",
            "Source/Core/Database/CloudKitSyncManager.swift", "Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift"}
        self.local = self.common("local", local_sources)
        self.local.update(status="PASS_APPLE_FOUNDATION_COMPONENT", source_unchanged=True,
            cold_reopen_gates=2, native_ui_executed=0, anytype_executed=0,
            cloudkit_transport_executed=0, app_relaunch_executed=0, live_exchange_enabled=False,
            owned_directory=str(self.local_owned), cold_processes=self.processes,
            commands=[{"label": label, "timeout_seconds": timeout, "exit_code": 0} for label, timeout in
                (("compile", 480), ("binary-path", 30), ("component-cases", 180),
                 ("cold-write", 45), ("cold-reopen", 45), ("cold-reopen-final", 45))],
            independent_sqlite_readback=local.verify_sqlite(self.fixtures, self.first, self.second))
        exchange_sources = set(exchange.SOURCES) | {gate.EXCHANGE_DRIVER,
            "Source/Features/Annotations/Database/AnnotationRepository.swift", "Source/Core/Configuration/ReusableFunc.swift"}
        self.exchange = self.common("exchange", exchange_sources)
        self.exchange.update(status="PASS_ACTUAL_SQLITE_COMPONENT", source_bytes_unchanged_during_run=True,
            compile_exit=0, execute_exit=0, sqlite_module_provider="Original Apple SDK SQLite3 module",
            digest_provider="Production CryptoKit SHA256", live_capability_enabled=False,
            owned_directory=str(self.exchange_owned), process_termination_checks=[])
        exchange_fixtures = self.exchange_owned / "fixtures"
        for phase, mode in (("after", "crash-after-commit"), ("before", "crash-before-outer-commit")):
            self.exchange["process_termination_checks"].append({"phase": phase, "status": "PASS",
                "terminated_exit": 73, "expected_terminated_exit": 73, "verify_exit": 0,
                "actual_journal_observation": "CRASH_JOURNAL_MODE wal; synchronous=2",
                "termination_command": ["explicit-synthetic-executable", mode, str(exchange_fixtures)],
                "verify_command": ["explicit-synthetic-executable", "verify-crash-" + phase, str(exchange_fixtures)]})
            (self.root / gate.EXCHANGE_OUTPUT / ("verify-crash-" + phase + ".log")).write_text(
                "PASS actual_process_termination_" + phase + "_commit_reopen\n", encoding="utf-8")
        payload, cloud = b"explicit-synthetic-rich-byte-receipt", b'[{"explicit":"synthetic queue"}]'
        for name, data in (("rich-payload.json", payload), ("rich-payload.sha256", gate.digest(payload).encode()),
                           ("cloud-before-ledger.json", cloud), ("cloud-after-ledger.json", cloud)):
            (exchange_fixtures / name).write_bytes(data)
        self.exchange.update(independent_python_SHA256=gate.digest(payload), cloudkit_queue_bytes_unchanged=True,
                             cloudkit_queue_rows_SHA256=gate.digest(cloud), cloudkit_queue_rows_count=1)
        self.persist()

    def common(self, kind, sources):
        hashes = {path: self.files[path]["sha256"] for path in sources}
        rows = [{"name": name, "status": "PASS"} for name in self.observed["case_names"][kind]]
        if kind == "exchange":
            for row in rows: row["milliseconds"] = 0.25
        report = {"source_sha": self.observed["identity"]["head_sha"], "cases": rows,
                  "passed_cases": len(rows), "failed_cases": 0}
        keys = ("source_before", "source_after") if kind == "local" else ("source_files_before", "source_files_after")
        for key in keys: report[key] = copy.deepcopy(hashes)
        return report

    def owned(self, relative, character, module, target):
        owned = self.root / relative / ("owned-" + character * 8 + "-" + character * 4 + "-" + character * 4 + "-" + character * 4 + "-" + character * 12)
        (owned / "fixtures").mkdir(parents=True)
        source = owned / "package/Sources" / target
        source.mkdir(parents=True)
        for relative_source in module.SOURCES:
            shutil.copyfile(self.root / relative_source, source / Path(relative_source).name)
        (owned / "package/Package.swift").write_text("// Explicit synthetic manifest; never compiled.\n")
        return owned

    def persist(self):
        write(self.root / gate.LOCAL_OUTPUT / "RESULT.json", self.local)
        write(self.root / gate.EXCHANGE_OUTPUT / "RESULT.json", self.exchange)

    def verify(self):
        self.persist()
        with patch.dict(os.environ, {"DEVELOPER_DIR": self.developer}):
            return gate.verify_results(self.root, self.observed, self.outcomes)


class Results(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="annotation-apple-gate-owned-")
        self.addCleanup(self.temp.cleanup)
        self.fixture = ResultFixture(self.temp.name)

    def test_complete_synthetic_receipts_and_real_sqlite_readback(self):
        value = self.fixture.verify()
        self.assertEqual((value["local_cases"], value["local_cold_reopen_gates"],
                          value["exchange_cases"], value["exchange_abrupt_process_reopen_gates"]), (43, 2, 28, 2))

    def test_missing_local_case_is_not_success(self):
        self.fixture.local["cases"].pop()
        with self.assertRaises(ValueError): self.fixture.verify()

    def test_duplicate_exchange_case_cannot_replace_original(self):
        self.fixture.exchange["cases"][-1] = self.fixture.exchange["cases"][0]
        with self.assertRaises(ValueError): self.fixture.verify()

    def test_skip_or_error_is_not_success(self):
        self.fixture.local["cases"][0]["status"] = "SKIP"
        with self.assertRaises(ValueError): self.fixture.verify()
        self.fixture.local["cases"][0].update(status="PASS", error="real error")
        with self.assertRaises(ValueError): self.fixture.verify()

    def test_boolean_counts_are_rejected(self):
        self.fixture.local["failed_cases"] = False
        with self.assertRaises(ValueError): self.fixture.verify()

    def test_actual_exchange_timing_is_required_but_local_has_no_fabricated_timing(self):
        self.fixture.verify()
        self.fixture.exchange["cases"][0].pop("milliseconds")
        with self.assertRaises(ValueError): self.fixture.verify()

    def test_wrong_checkout_is_rejected(self):
        self.fixture.exchange["source_sha"] = "b" * 40
        with self.assertRaises(ValueError): self.fixture.verify()

    def test_missing_or_mutated_driver_source_closure_is_rejected(self):
        key = next(iter(self.fixture.local["source_before"]))
        self.fixture.local["source_before"].pop(key)
        with self.assertRaises(ValueError): self.fixture.verify()

    def test_matching_fabricated_source_hash_is_rejected(self):
        key = next(iter(self.fixture.exchange["source_files_before"]))
        self.fixture.exchange["source_files_before"][key] = "0" * 64
        self.fixture.exchange["source_files_after"][key] = "0" * 64
        with self.assertRaises(ValueError): self.fixture.verify()

    def test_compile_or_workflow_failure_cannot_become_pass(self):
        for name in ("toolchain", "local", "exchange"):
            self.fixture.outcomes[name] = "failure"
            with self.assertRaises(ValueError): self.fixture.verify()
            self.fixture.outcomes[name] = "success"

    def test_missing_actual_process_or_changed_deadline_is_rejected(self):
        self.fixture.local["commands"][-1]["timeout_seconds"] = 90
        with self.assertRaises(ValueError): self.fixture.verify()

    def test_cold_reopen_requires_distinct_pids(self):
        self.fixture.local["cold_processes"][-1]["processID"] = 102
        with self.assertRaises(ValueError): self.fixture.verify()

    def test_cold_reopen_requires_actual_prior_process(self):
        self.fixture.local["cold_processes"][-1]["priorProcessID"] = 101
        with self.assertRaises(ValueError): self.fixture.verify()

    def test_current_sqlite_head_cannot_be_replaced_by_receipt(self):
        connection = sqlite3.connect(self.fixture.fixtures / "cold-profile/Annotations.sqlite")
        connection.execute("UPDATE otzaria_annotation_exchange_heads SET revision=1")
        connection.commit(); connection.close()
        with self.assertRaises(ValueError): self.fixture.verify()

    def test_crash_exit_and_verifier_must_both_match(self):
        gate_row = self.fixture.exchange["process_termination_checks"][0]
        gate_row["terminated_exit"] = 0
        with self.assertRaises(ValueError): self.fixture.verify()
        gate_row["terminated_exit"], gate_row["verify_exit"] = 73, 1
        with self.assertRaises(ValueError): self.fixture.verify()

    def test_crash_reopen_output_is_required(self):
        (self.fixture.root / gate.EXCHANGE_OUTPUT / "verify-crash-before.log").write_text("no completed assertion\n")
        with self.assertRaises(ValueError): self.fixture.verify()

    def test_one_crash_phase_cannot_be_counted_twice(self):
        self.fixture.exchange["process_termination_checks"][1] = self.fixture.exchange["process_termination_checks"][0]
        with self.assertRaises(ValueError): self.fixture.verify()

    def test_original_queue_and_payload_bytes_are_independently_checked(self):
        path = self.fixture.exchange_owned / "fixtures/cloud-after-ledger.json"
        path.write_bytes(b"[]")
        with self.assertRaises(ValueError): self.fixture.verify()

    def test_copied_compile_input_cannot_drift(self):
        path = self.fixture.local_owned / "package/Sources/LocalAnnotationEditorAcceptance/AnnotationStore.swift"
        path.write_bytes(path.read_bytes() + b"\n// synthetic drift\n")
        with self.assertRaises(ValueError): self.fixture.verify()

    def test_extra_compiled_source_is_rejected(self):
        (self.fixture.exchange_owned / "package/Sources/ExchangeAcceptance/Injected.swift").write_text("// synthetic extra\n")
        with self.assertRaises(ValueError): self.fixture.verify()

    def test_foreign_owned_directory_is_rejected(self):
        self.fixture.local["owned_directory"] = str(self.fixture.exchange_owned)
        with self.assertRaises(ValueError): self.fixture.verify()


class SourceAndAuthority(unittest.TestCase):
    def test_whole_original_node_and_exact_catalog_boundary_are_present(self):
        gate.verify_local_model_closure(ROOT, local.SOURCES)

    def test_missing_original_node_is_rejected_before_compile(self):
        sources = [path for path in local.SOURCES if path != gate.LOCAL_NODE]
        with self.assertRaisesRegex(ValueError, "Whole original AnnotationNode"):
            gate.verify_local_model_closure(ROOT, sources)

    def test_replacement_node_in_boundary_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for relative in local.SOURCES + [gate.LOCAL_CATALOG]:
                target = root / relative; target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / relative, target)
            boundary = root / gate.LOCAL_BOUNDARY
            boundary.write_bytes(boundary.read_bytes() + b"\nfinal class AnnotationNode {}\n")
            with self.assertRaisesRegex(ValueError, "unique original whole model"):
                gate.verify_local_model_closure(root, local.SOURCES)

    def test_unmatched_synthetic_localization_key_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for relative in local.SOURCES + [gate.LOCAL_CATALOG]:
                target = root / relative; target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / relative, target)
            catalog = gate.load_json(root / gate.LOCAL_CATALOG)
            del catalog["strings"]["Today"]
            write(root / gate.LOCAL_CATALOG, catalog)
            with self.assertRaisesRegex(ValueError, "catalog does not contain"):
                gate.verify_local_model_closure(root, local.SOURCES)
            shutil.copyfile(ROOT / gate.LOCAL_CATALOG, root / gate.LOCAL_CATALOG)
            boundary = root / gate.LOCAL_BOUNDARY
            boundary.write_bytes(boundary.read_bytes().replace(b'{ "Today" }', b'{ "Invented label" }'))
            with self.assertRaisesRegex(ValueError, "boundary differs from original keys"):
                gate.verify_local_model_closure(root, local.SOURCES)

    def test_exact_environment(self):
        self.assertEqual(gate.environment_identity(environment())["run_attempt"], 1)

    def test_wrong_push_identity_is_denied(self):
        for key in ("GITHUB_EVENT_NAME", "GITHUB_REPOSITORY", "GITHUB_REPOSITORY_ID", "GITHUB_REF",
                    "GITHUB_WORKFLOW_REF", "GITHUB_SHA", "EXPECTED_CHECKOUT_SHA", "GITHUB_WORKFLOW_SHA",
                    "GITHUB_RUN_ID", "GITHUB_RUN_ATTEMPT"):
            value = environment(); value[key] = "wrong"
            with self.subTest(key=key), self.assertRaises(ValueError): gate.environment_identity(value)

    def test_duplicate_json_keys_are_denied(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "receipt.json"; path.write_text('{"status":"PASS","status":"FAIL"}')
            with self.assertRaises(ValueError): gate.load_json(path)

    def test_original_source_pins_match_complete_local_projection(self):
        binding = gate.load_json(ROOT / gate.BINDING)
        for relative, expected in binding["source_pins"].items():
            self.assertEqual(gate.record(ROOT, relative), expected, relative)
        self.assertEqual(gate.declared_cases(ROOT), binding["case_names"])

    def test_source_unsafe_path_or_symlink_is_denied(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); (root / "source.swift").write_text("// fixture\n")
            for relative in ("../source.swift", "/source.swift", "a//b", "./source.swift", "a\\b"):
                with self.assertRaises(ValueError): gate.exact_file(root, relative)
            (root / "link.swift").symlink_to(root / "source.swift")
            with self.assertRaises(ValueError): gate.exact_file(root, "link.swift")

    def test_failed_source_capture_retains_changed_bytes_without_pass(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); output = root / "evidence"; output.mkdir()
            (root / "changed.swift").write_text("// actual changed bytes\n")
            before = {"source": {"files": {"changed.swift": {}, "missing.swift": {}}}}
            result = gate.retain_unverified_after(root, before, output)
            self.assertEqual(result["status"], "UNVERIFIED_AFTER_FAILURE")
            self.assertEqual((result["captured_files"], result["missing_or_unsafe_files"]), (1, 1))
            raw = gate.load_json(output / "after-unverified-source.json")
            self.assertEqual(raw["files"]["changed.swift"]["sha256"], gate.digest(b"// actual changed bytes\n"))

    def test_git_working_tree_snapshot_and_extra_core_input(self):
        with tempfile.TemporaryDirectory(prefix="annotation-source-owned-") as directory:
            root = Path(directory)
            binding = gate.load_json(ROOT / gate.BINDING)
            for relative in set(binding["source_pins"]) | set(gate.CI_INPUTS):
                target = root / relative; target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / relative, target)
            core = root / gate.CORE; core.mkdir(parents=True)
            (core / "Package.swift").write_text("// Explicit Git closure fixture; no Swift compile.\n")
            def command(*args):
                return subprocess.check_output(["git", *args], cwd=root, stderr=subprocess.STDOUT)
            command("init", "-q"); command("config", "user.name", "Evidence Fixture")
            command("config", "user.email", "fixture@invalid.example")
            command("add", "."); command("commit", "-qm", "Explicit source closure fixture")
            binding["core_tree_sha"] = command("rev-parse", "HEAD:" + gate.CORE).decode().strip()
            write(root / gate.BINDING, binding); command("add", gate.BINDING)
            command("commit", "-qm", "Bind fixture Core tree")
            identity = environment(command("rev-parse", "HEAD").decode().strip())
            baseline = gate.observe_source(root, identity)
            archive = root / "raw-before.tar.gz"
            self.assertGreater(gate.archive_sources(root, baseline, archive)["members"], 20)
            (core / "Injected.swift").write_text("// Untracked compiled fixture\n")
            with self.assertRaisesRegex(ValueError, "Untracked compiled Core input"):
                gate.observe_source(root, identity)
            (core / "Injected.swift").unlink()
            (core / "Package.swift").write_text("// changed\n")
            with self.assertRaisesRegex(ValueError, "Dirty tracked"):
                gate.observe_source(root, identity)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--artifacts-dir", type=Path, required=True)
    args = parser.parse_args()
    args.artifacts_dir.mkdir(parents=True, exist_ok=True)
    destination = args.artifacts_dir / "RESULT.json"
    if destination.exists(): raise RuntimeError("Preserve prior Python attempt")
    inputs = [gate.SELF, gate.TESTS, gate.BINDING, gate.WORKFLOW,
              *gate.load_json(ROOT / gate.BINDING)["source_pins"]]
    before = {path: gate.record(ROOT, path) for path in sorted(set(inputs))}
    suite = unittest.TestSuite([unittest.defaultTestLoader.loadTestsFromTestCase(kind)
                               for kind in (Results, SourceAndAuthority)])
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    after = {path: gate.record(ROOT, path) for path in sorted(set(inputs))}
    report = {"observed_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "status": "PASS" if result.wasSuccessful() and before == after else "FAIL",
              "tests": result.testsRun, "failures": len(result.failures), "errors": len(result.errors),
              "skipped": len(result.skipped), "swift_executed": 0, "apple_executed": 0,
              "scope": "Python verifier controls with explicit synthetic receipts and actual original SQLite schema",
              "source_before": before, "source_after": after}
    destination.write_bytes(gate.json_bytes(report))
    raise SystemExit(0 if report["status"] == "PASS" else 1)

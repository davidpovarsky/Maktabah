"""Only new Live connection-diagnostic boundaries; no Simulator/Native/provider work."""
import ast
import base64
import contextlib
import copy
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import re
import tempfile
import time
import unittest
from unittest import mock
import uuid

HERE = Path(__file__).resolve().parent
DRIVER = HERE / "inputs/Scripts/CI/runtime27-hanlin-live.py"
SESSION = HERE / "inputs/Source/ChavrusaText/HanlinHostAdapter/OtzariaHanlinChatSession.swift"
PREIMAGE = HERE / "preimage/Scripts/CI/runtime27-hanlin-live.py"
spec = importlib.util.spec_from_file_location("owned_new_live_diagnostic_candidate", DRIVER)
driver = importlib.util.module_from_spec(spec)
spec.loader.exec_module(driver)  # Complete candidate; __main__ is deliberately not invoked.
SYNTHETIC_CREDENTIAL = "LOCAL_ONLY_SYNTHETIC_PRIVACY_CANARY_7D8B3E21"
SYNTHETIC_FIXTURE_TOKEN = "LOCAL_ONLY_SYNTHETIC_FIXTURE_CANARY_0C51D394"
OWNED_DEVICE = "55A74903-A60D-4DAA-B280-8DD2220304A2"
OBSERVATIONS = []

def payload(events=None, overflow=False):
    return {"schemaVersion": 1, "overflow": overflow, "events": events or [
        {"sequence": 1, "stage": "inputConsumed", "reason": "none", "flags": {}}]}

def event(number=2, stage="connectEntered", reason="none", flags=None):
    return {"sequence": number, "stage": stage, "reason": reason, "flags": flags or {}}

def raw_json(value):
    return json.dumps(value, separators=(",", ":"), ensure_ascii=False).encode("utf-8")

class DiagnosticBoundaryTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="hanlin-new-diagnostic-")
        self.base = Path(self.temporary.name).resolve()
        self.project = self.base / "project"
        self.application_root = self.base / "Application"
        self.container = self.application_root / "APP-A"
        (self.container / "Documents").mkdir(parents=True)
        self.work = self.project / "build/hanlin-live-private"
        self.out = self.project / "build/hanlin-live-evidence"
        self.work.mkdir(parents=True)
        self.out.mkdir(parents=True)
        self.patchers = [
            mock.patch.object(driver, "ROOT", self.project),
            mock.patch.object(driver, "WORK", self.work),
            mock.patch.object(driver, "OUT", self.out),
            # An explicit local application-root dependency seam; filesystem,
            # mode, resolution, glob, scanner and complete methods remain real.
            mock.patch.object(driver, "owned_application_root", return_value=self.application_root),
        ]
        for patcher in self.patchers:
            patcher.start()
        self.live = driver.LiveAcceptance(SYNTHETIC_CREDENTIAL, SYNTHETIC_FIXTURE_TOKEN)

    def tearDown(self):
        for patcher in reversed(self.patchers):
            patcher.stop()
        self.temporary.cleanup()

    def note(self, kind, detail, raw=None):
        row = {"case": self._testMethodName, "kind": kind, "detail": detail}
        if type(raw) is bytes:
            row.update(bytes=len(raw), sha256=hashlib.sha256(raw).hexdigest())
        OBSERVATIONS.append(row)

    def rejected(self, raw, variant):
        with self.subTest(variant=variant):
            with self.assertRaises(ValueError):
                driver.validate_connection_diagnostic(raw)
            self.note("rejected", variant, raw)

    def journal(self, raw=None, nonce=None, container=None, mode=0o600):
        path = (container or self.container) / "Documents" / (
            driver.CONNECTION_DIAGNOSTIC_PREFIX + (nonce or self.live.nonce) + ".json")
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(raw if raw is not None else raw_json(payload()))
        path.chmod(mode)
        return path

    def rejected_capture(self, message):
        with self.assertRaisesRegex(ValueError, message):
            self.live.capture_connection_diagnostic(self.application_root)
        self.assertFalse((self.work / "connection-stages.json").exists())
        self.assertIsNone(self.live.witness)
        self.note("capture-rejected", message)

    def test_01_actual_swift_python_enum_parity_and_all_declared_values(self):
        swift = SESSION.read_text(encoding="utf-8")
        def cases(name):
            body = re.search(r"enum " + name + r": String \{(.*?)\n    \}", swift, re.S).group(1)
            return {part.strip() for line in body.splitlines() if line.strip().startswith("case ")
                    for part in line.strip()[5:].split(",")}
        self.assertEqual(cases("Stage"), driver.CONNECTION_DIAGNOSTIC_STAGES)
        self.assertEqual(cases("Reason"), driver.CONNECTION_DIAGNOSTIC_REASONS)
        self.assertEqual(cases("Flag"), driver.CONNECTION_DIAGNOSTIC_FLAGS)
        self.assertEqual((len(cases("Stage")), len(cases("Reason")), len(cases("Flag"))), (29, 9, 29))
        stages = sorted(driver.CONNECTION_DIAGNOSTIC_STAGES - {"inputConsumed"})
        reasons = sorted(driver.CONNECTION_DIAGNOSTIC_REASONS)
        flags = sorted(driver.CONNECTION_DIAGNOSTIC_FLAGS)
        events = payload()["events"]
        for number, stage in enumerate(stages, 2):
            start = ((number - 2) * 9) % len(flags)
            names = [flags[(start + index) % len(flags)] for index in range(9)]
            events.append(event(number, stage, reasons[(number - 2) % len(reasons)],
                                {name: index % 2 == 0 for index, name in enumerate(names)}))
        value = payload(events)
        self.assertEqual(driver.validate_connection_diagnostic(raw_json(value)), value)
        self.note("accepted", "all actual Swift and Python enum values, both boolean values", raw_json(value))

    def test_02_minimum_and_exact_maximum_byte_bound(self):
        raw = raw_json(payload())
        self.assertEqual(driver.validate_connection_diagnostic(raw), payload())
        padded = raw + b" " * (65536 - len(raw))
        self.assertEqual(driver.validate_connection_diagnostic(padded), payload())
        self.note("accepted", "65536 bytes including legal JSON trailing whitespace", padded)
        for variant, bad in [("empty", b""), ("65537 bytes", padded + b" "),
                             ("text not bytes", raw.decode()), ("bytearray not bytes", bytearray(raw))]:
            self.rejected(bad, variant)

    def test_03_exact_top_level_schema_and_version_kind(self):
        base = payload()
        for key in base:
            bad = copy.deepcopy(base); del bad[key]
            self.rejected(raw_json(bad), "missing-" + key)
        for variant, change in [
            ("unknown field", {"privateText": "not permitted"}),
            ("bool version", {"schemaVersion": True}),
            ("float version", {"schemaVersion": 1.0}),
            ("wrong version", {"schemaVersion": 2}),
            ("string version", {"schemaVersion": "1"}),
        ]:
            bad = copy.deepcopy(base); bad.update(change)
            self.rejected(raw_json(bad), variant)
        for bad in [[], None, False, 1, "journal"]:
            self.rejected(raw_json(bad), "top-level-" + type(bad).__name__)

    def test_04_boolean_kinds_are_not_integers_or_strings(self):
        for value in [0, 1, "true", None, [], {}]:
            bad = payload(); bad["overflow"] = value
            self.rejected(raw_json(bad), "overflow-" + repr(value))
            bad = payload([payload()["events"][0], event(flags={"closed": value})])
            self.rejected(raw_json(bad), "flag-" + repr(value))
        valid = payload([payload()["events"][0], event(flags={"closed": True, "connecting": False})], True)
        self.assertEqual(driver.validate_connection_diagnostic(raw_json(valid)), valid)

    def test_05_exact_event_schema(self):
        for key in ["sequence", "stage", "reason", "flags"]:
            bad = payload([payload()["events"][0], event()]); del bad["events"][1][key]
            self.rejected(raw_json(bad), "missing-" + key)
        bad = payload([payload()["events"][0], event()]); bad["events"][1]["credential"] = "not allowed"
        self.rejected(raw_json(bad), "unknown event field")
        for value in [None, [], True, "event"]:
            self.rejected(raw_json(payload([payload()["events"][0], value])), "non-object-event-" + repr(value))

    def test_06_unknown_enum_values_and_wrong_kinds(self):
        for field, values in [("stage", ["unboundedFreeText", 2, None, False]),
                              ("reason", ["customErrorText", 2, None, False])]:
            for value in values:
                bad = payload([payload()["events"][0], event()]); bad["events"][1][field] = value
                self.rejected(raw_json(bad), field + "-" + repr(value))
        self.rejected(raw_json(payload([payload()["events"][0], event(flags={"unknownProperty": True})])),
                      "unknown flag")
        for value in [[], None, True, 1, "flags"]:
            bad = payload([payload()["events"][0], event()]); bad["events"][1]["flags"] = value
            self.rejected(raw_json(bad), "flags-container-" + repr(value))

    def test_07_duplicate_keys_at_each_object_level(self):
        base = raw_json(payload([payload()["events"][0], event(flags={"closed": False})]))
        for variant, raw in [
            ("top-level", base.replace(b'"schemaVersion":1', b'"schemaVersion":1,"schemaVersion":1', 1)),
            ("event", base.replace(b'"sequence":2', b'"sequence":2,"sequence":2', 1)),
            ("flag", base.replace(b'"closed":false', b'"closed":false,"closed":true', 1)),
        ]:
            self.rejected(raw, variant)

    def test_08_invalid_utf8_json_and_nonfinite_numbers(self):
        for variant, raw in [("invalid UTF8", b"\xff"), ("incomplete JSON", b"{"),
                             ("trailing object", raw_json(payload()) + b"{}"),
                             ("UTF8 BOM", b"\xef\xbb\xbf" + raw_json(payload()))]:
            self.rejected(raw, variant)
        for token in [b"NaN", b"Infinity", b"-Infinity"]:
            self.rejected(raw_json(payload()).replace(b'"overflow":false', b'"overflow":' + token), token.decode())

    def test_09_event_count_and_list_bound(self):
        first = payload()["events"][0]
        events = [first] + [event(number) for number in range(2, 97)]
        self.assertEqual(len(driver.validate_connection_diagnostic(raw_json(payload(events)))["events"]), 96)
        self.rejected(raw_json(payload(events + [event(97)])), "97 events")
        for value in [[], {}, None, "events", True]:
            bad = payload(); bad["events"] = value
            self.rejected(raw_json(bad), "event-container-" + repr(value))

    def test_10_flags_count_bound(self):
        keys = sorted(driver.CONNECTION_DIAGNOSTIC_FLAGS)
        good = payload([payload()["events"][0], event(flags={key: True for key in keys[:9]})])
        self.assertEqual(driver.validate_connection_diagnostic(raw_json(good)), good)
        self.rejected(raw_json(payload([payload()["events"][0], event(flags={key: True for key in keys[:10]})])),
                      "10 flags")

    def test_11_sequence_is_contiguous_exact_integer(self):
        for value in [True, 1, 3, 2.0, "2", -2, None]:
            bad = payload([payload()["events"][0], event()]); bad["events"][1]["sequence"] = value
            self.rejected(raw_json(bad), "second-sequence-" + repr(value))
        bad = payload(); bad["events"][0]["sequence"] = True
        self.rejected(raw_json(bad), "first bool sequence")
        self.rejected(raw_json(payload([payload()["events"][0], event(2), event(2)])), "repeated sequence")

    def test_12_exact_single_input_consumption_anchor(self):
        self.rejected(raw_json(payload([event(1)])), "wrong first stage")
        self.rejected(raw_json(payload([payload()["events"][0], event(2, "inputConsumed")])), "repeated anchor")
        for field, value in [("reason", "cancelled"), ("flags", {"closed": False})]:
            bad = payload(); bad["events"][0][field] = value
            self.rejected(raw_json(bad), "noncanonical anchor " + field)

    def test_13_nonce_is_original_canonical_uuid_and_new_instance_is_distinct(self):
        self.assertEqual(str(uuid.UUID(self.live.nonce)).upper(), self.live.nonce)
        other = driver.LiveAcceptance(SYNTHETIC_CREDENTIAL)
        self.assertNotEqual(other.nonce, self.live.nonce)
        self.assertEqual(self.live.connection_diagnostic_status, "NOT_CAPTURED")

    def test_14_real_private_file_capture_and_exact_admission(self):
        value = payload([payload()["events"][0], event(flags={"credentialPresent": True})])
        raw = raw_json(value); file = self.journal(raw)
        self.assertEqual(file.stat().st_mode & 0o777, 0o600)
        self.live.capture_connection_diagnostic(self.application_root)
        self.assertEqual(self.live.connection_diagnostic_status, "OBSERVED")
        self.assertIsNone(self.live.witness)
        self.assertEqual((self.work / "connection-stages.json").read_bytes(), raw)
        self.assertTrue(self.live.admit(self.work / "connection-stages.json", "connection-stages.json"))
        self.assertEqual((self.out / "connection-stages.json").read_bytes(), raw)
        self.assertNotIn(self.live.nonce.encode(), raw)
        self.note("real-posix-admitted", "regular mode0600 exact nonce filename; unchanged typed bytes", raw)

    def test_15_missing_and_wrong_nonce_journals_are_not_observed(self):
        self.live.capture_connection_diagnostic(self.application_root)
        self.assertEqual(self.live.connection_diagnostic_status, "NOT_OBSERVED")
        wrong = str(uuid.uuid4()).upper()
        file = self.journal(nonce=wrong)
        self.live.capture_connection_diagnostic(self.application_root)
        self.assertEqual(self.live.connection_diagnostic_status, "NOT_OBSERVED")
        self.assertTrue(file.exists())
        self.assertFalse((self.work / "connection-stages.json").exists())
        self.assertIsNone(self.live.witness)

    def test_16_stale_exact_nonce_stops_stage_before_input_or_ownership_write(self):
        file = self.journal()
        with self.assertRaisesRegex(ValueError, "previous connection diagnostic"):
            self.live.stage(OWNED_DEVICE, self.container, "11", [driver.SELECTOR])
        self.assertIsNone(self.live.udid)
        self.assertFalse(self.live.staged)
        self.assertFalse((self.work / "ownership.json").exists())
        self.assertFalse((self.container / driver.PRIVATE_RELATIVE).exists())
        self.assertEqual(file.read_bytes(), raw_json(payload()))

    def test_17_ambiguous_container_match_refused(self):
        self.journal()
        self.journal(container=self.application_root / "APP-B")
        self.rejected_capture("Ambiguous original connection diagnostic")

    def test_18_symlink_file_refused(self):
        target = self.base / "outside.json"
        target.write_bytes(raw_json(payload())); target.chmod(0o600)
        file = self.container / "Documents" / (driver.CONNECTION_DIAGNOSTIC_PREFIX + self.live.nonce + ".json")
        file.symlink_to(target)
        self.rejected_capture("Invalid original connection diagnostic file")
        self.assertEqual(target.read_bytes(), raw_json(payload()))

    def test_19_symlink_parent_escape_refused(self):
        docs = self.container / "Documents"; docs.rmdir()
        outside = self.base / "outside"; outside.mkdir()
        docs.symlink_to(outside, target_is_directory=True)
        file = self.journal()
        self.assertFalse(file.resolve().is_relative_to(self.application_root))
        self.rejected_capture("Invalid original connection diagnostic file")

    def test_20_nonprivate_mode_refused(self):
        self.journal(mode=0o644)
        self.rejected_capture("Invalid original connection diagnostic file")

    def test_21_nonregular_matching_path_refused(self):
        path = self.container / "Documents" / (driver.CONNECTION_DIAGNOSTIC_PREFIX + self.live.nonce + ".json")
        path.mkdir()
        self.rejected_capture("Invalid original connection diagnostic file")

    def test_22_oversized_private_file_refused_before_scanning(self):
        self.journal(b" " * 65537)
        with mock.patch.object(self.live, "scan", side_effect=AssertionError("must reject size before scanner")):
            self.rejected_capture("Invalid original connection diagnostic file")

    def test_23_invalid_typed_payload_is_never_copied(self):
        bad = payload(); bad["events"][0]["privateValue"] = "forbidden"
        self.journal(raw_json(bad))
        self.rejected_capture("Unexpected connection diagnostic event")

    def test_24_raw_credential_is_refused_before_decoder(self):
        self.journal(raw_json(payload()) + SYNTHETIC_CREDENTIAL.encode())
        with mock.patch.object(driver, "validate_connection_diagnostic",
                               side_effect=AssertionError("scanner must precede JSON decoding")):
            self.rejected_capture("Credential detected")

    def test_25_base64_credential_is_refused_before_decoder(self):
        self.journal(raw_json(payload()) + base64.b64encode(SYNTHETIC_CREDENTIAL.encode()))
        with mock.patch.object(driver, "validate_connection_diagnostic",
                               side_effect=AssertionError("scanner must precede JSON decoding")):
            self.rejected_capture("Credential detected")

    def test_26_fixture_token_and_encoded_token_are_refused(self):
        for raw in [SYNTHETIC_FIXTURE_TOKEN.encode(), base64.b64encode(SYNTHETIC_FIXTURE_TOKEN.encode())]:
            with self.subTest(encoded=raw != SYNTHETIC_FIXTURE_TOKEN.encode()):
                self.journal(raw_json(payload()) + raw)
                self.rejected_capture("Credential detected")

    def test_27_already_retained_journal_is_preserved(self):
        self.journal()
        self.live.capture_connection_diagnostic(self.application_root)
        retained = self.work / "connection-stages.json"; before = retained.read_bytes()
        with self.assertRaisesRegex(ValueError, "Preserve an already captured"):
            self.live.capture_connection_diagnostic(self.application_root)
        self.assertEqual(retained.read_bytes(), before)

    def test_28_overflow_reports_incompleteness_without_witness(self):
        raw = raw_json(payload(overflow=True)); self.journal(raw)
        self.live.capture_connection_diagnostic(self.application_root)
        self.assertEqual(self.live.connection_diagnostic_status, "OVERFLOW")
        self.assertIsNone(self.live.witness)
        self.assertEqual((self.work / "connection-stages.json").read_bytes(), raw)

    def test_29_capture_precedes_required_final_witness_on_real_failure_path(self):
        self.live.udid = OWNED_DEVICE
        raw = raw_json(payload([payload()["events"][0], event(2, "consentCaptured")]))
        self.journal(raw)
        with self.assertRaisesRegex(ValueError, "original native live witness did not complete"):
            self.live.capture(OWNED_DEVICE, "11")
        self.assertEqual(self.live.connection_diagnostic_status, "OBSERVED")
        self.assertEqual((self.work / "connection-stages.json").read_bytes(), raw)
        self.assertIsNone(self.live.witness)
        self.assertTrue(self.live.admit(self.work / "connection-stages.json", "connection-stages.json"))

    def test_30_wrong_capture_device_or_label_cannot_collect(self):
        self.live.udid = OWNED_DEVICE; self.journal()
        for device, label in [(str(uuid.uuid4()).upper(), "11"), (OWNED_DEVICE, "13")]:
            with self.subTest(deviceMismatch=device != OWNED_DEVICE, label=label):
                with self.assertRaisesRegex(ValueError, "Wrong live witness device"):
                    self.live.capture(device, label)
        self.assertEqual(self.live.connection_diagnostic_status, "NOT_CAPTURED")
        self.assertFalse((self.work / "connection-stages.json").exists())

    def run_actual_main_with_explicit_external_probes(self, matrix_pass=False, corrupt_admission=False):
        # These probes replace only external source/build/matrix ownership inputs.
        # They make NO Native/Live assertion. The complete original main, capture,
        # scanner, admission and cleanup/error decision bodies execute unchanged.
        self.work.rmdir(); self.out.rmdir()
        state = {}
        def matrix(live_provider):
            live = live_provider; state["live"] = live
            live.udid = OWNED_DEVICE
            live.staged = True; live.consumed = True; live.removed = True
            raw = raw_json(payload([payload()["events"][0], event(2, "connectFailed", "staleContext")]))
            file = self.container / "Documents" / (driver.CONNECTION_DIAGNOSTIC_PREFIX + live.nonce + ".json")
            file.write_bytes(raw); file.chmod(0o600)
            with self.assertRaisesRegex(ValueError, "original native live witness did not complete"):
                live.capture(OWNED_DEVICE, "11")
            if corrupt_admission:
                (self.work / "connection-stages.json").write_bytes(raw + SYNTHETIC_CREDENTIAL.encode())
            artifacts = self.project / "build/artifacts"
            driver.write(artifacts / "faithful-ipad-matrix.json",
                         {"devices": [{"status": "EXECUTED_PASS" if matrix_pass else "FAILED",
                                       "failedPhase": "FINAL_NATIVE_WITNESS", "ownedSimulatorCleanup": "PASS"}]})
            driver.write(artifacts / "runtime27/verified-11.json",
                         {"status": "EXECUTED_PASS", "required_ui_cases": [driver.SELECTOR],
                          "executed_total": 1, "skipped": 0, "failed": 0})
            return 0 if matrix_pass else 1
        def matrix_loader(path, *args, **kwargs):
            self.assertEqual(Path(path), self.project / "Scripts/CI/run-faithful-ipad-matrix.py")
            return {"main": matrix}
        captured = io.StringIO()
        with contextlib.ExitStack() as stack:
            stack.enter_context(mock.patch.dict(os.environ,
                {"OTZARIA_HANLIN_LIVE_API_KEY": SYNTHETIC_CREDENTIAL,
                 "GITHUB_RUN_ID": "LOCAL_DIAGNOSTIC_CONTROL", "GITHUB_RUN_ATTEMPT": "1"}, clear=True))
            stack.enter_context(mock.patch.object(driver, "source_context", return_value={"local_external_probe": True}))
            stack.enter_context(mock.patch.object(driver, "prepare_selection", return_value=None))
            stack.enter_context(mock.patch.object(driver.runpy, "run_path", side_effect=matrix_loader))
            stack.enter_context(mock.patch.object(driver.subprocess, "run",
                side_effect=AssertionError("No child command may execute in diagnostic controls")))
            stack.enter_context(mock.patch.object(driver.subprocess, "check_output",
                side_effect=AssertionError("No child command may execute in diagnostic controls")))
            stack.enter_context(contextlib.redirect_stdout(captured))
            code = driver.main()
        return code, json.loads(captured.getvalue()), state

    def test_31_failed_case_admits_diagnostic_but_stays_fail(self):
        code, stdout, state = self.run_actual_main_with_explicit_external_probes()
        self.assertEqual(code, 1); self.assertEqual(stdout["status"], "FAIL")
        report = json.loads((self.out / "result.json").read_bytes())
        self.assertEqual(report["status"], "FAIL")
        self.assertEqual(report["connection_diagnostic_status"], "OBSERVED")
        self.assertEqual(report["verified_completed_provider_conversations"], 0)
        self.assertFalse(report["native116_acceptance"]); self.assertFalse(report["release114_acceptance"])
        self.assertTrue(report["prior_artifacts_restored"])
        self.assertTrue((self.out / "connection-stages.json").is_file())
        self.assertIn("connection-stages.json", json.loads((self.out / "admission.json").read_bytes())["files"])
        self.assertIsNone(state["live"].witness)
        self.note("real-main-failure-decision", "complete main with explicit external-only probes; no Native qualification")

    def test_32_observed_journal_cannot_replace_witness_even_if_external_matrix_claims_pass(self):
        code, stdout, state = self.run_actual_main_with_explicit_external_probes(matrix_pass=True)
        self.assertEqual(code, 1); self.assertEqual(stdout["status"], "FAIL")
        report = json.loads((self.out / "result.json").read_bytes())
        self.assertEqual(report["failure_phase"], "STRICT_NATIVE_VERIFICATION")
        self.assertEqual(report["verified_completed_provider_conversations"], 0)
        self.assertIsNone(state["live"].witness)

    def test_33_final_allowlist_scan_failure_removes_partial_upload(self):
        code, stdout, state = self.run_actual_main_with_explicit_external_probes(corrupt_admission=True)
        self.assertEqual(code, 1); self.assertEqual(stdout["status"], "FAIL")
        self.assertEqual(stdout["failure_phase"], "EVIDENCE_ADMISSION")
        self.assertFalse(stdout["artifact_admitted"])
        self.assertFalse(self.out.exists())
        self.assertTrue((self.work / "connection-stages.json").exists())
        self.assertTrue((self.work / "artifact-isolation.json").exists())

    def test_34_old_cleanup_scanner_witness_and_success_gates_are_unchanged(self):
        original = ast.parse(PREIMAGE.read_bytes(), filename=str(PREIMAGE))
        candidate = ast.parse(DRIVER.read_bytes(), filename=str(DRIVER))
        def function(tree, name, cls=None):
            if cls is not None:
                tree = next(node for node in tree.body if isinstance(node, ast.ClassDef) and node.name == cls)
            return next(node for node in tree.body if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))
                        and node.name == name)
        dump = lambda node: ast.dump(node, include_attributes=False)
        for name in ["cleanup", "scan", "redact_evidence", "admit", "validate_selection"]:
            self.assertEqual(dump(function(original, name, "LiveAcceptance")),
                             dump(function(candidate, name, "LiveAcceptance")), name)
        for name in ["clean_private_input", "cleanup_owned_device", "emergency_cleanup", "restore_artifacts"]:
            self.assertEqual(dump(function(original, name)), dump(function(candidate, name)), name)
        old_capture = function(original, "capture", "LiveAcceptance")
        new_capture = copy.deepcopy(function(candidate, "capture", "LiveAcceptance"))
        added = new_capture.body.pop(2)
        self.assertIsInstance(added, ast.Expr)
        self.assertEqual(added.value.func.attr, "capture_connection_diagnostic")
        self.assertEqual(dump(old_capture), dump(new_capture))
        old_main = function(original, "main"); new_main = function(candidate, "main")
        def requirements(node):
            return [dump(item) for item in ast.walk(node)
                    if isinstance(item, ast.Call) and isinstance(item.func, ast.Name) and item.func.id == "require"]
        self.assertEqual(requirements(old_main), requirements(new_main))
        self.assertEqual([dump(item) for item in ast.walk(old_main) if isinstance(item, ast.Return)],
                         [dump(item) for item in ast.walk(new_main) if isinstance(item, ast.Return)])


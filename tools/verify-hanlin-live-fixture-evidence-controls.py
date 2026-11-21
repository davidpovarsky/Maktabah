"""Disposable failed-fixture controls. No real credentials, provider, Xcode or Native execution."""
import base64
from contextlib import redirect_stdout
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
from unittest.mock import patch

HERE = Path(__file__).resolve().parents[1]
SUBJECT = HERE / "Scripts/CI/runtime27-hanlin-live.py"
PROVIDER = "PUBLIC_PROVIDER_CONTROL_LITERAL_NOT_A_CREDENTIAL_0123456789"
FIXTURE_TOKEN = "PUBLIC_FIXTURE_CONTROL_LITERAL_NOT_A_CREDENTIAL_0123456789"
REPORT_NAMES = [
    "miniTest10-native-fixture-install-11.json",
    "miniTest10-native-fixture-install-11-attempt-1.json",
    "miniTest10-native-fixture-install-11-before-reboot.json",
    "miniTest10-native-fixture-termination-11.json",
    "miniTest10-native-fixture-termination-11-before-reboot.json",
]
FAILURE = {"status": "FAIL", "failedPhase": "PROVISIONING_NATIVE_FIXTURES",
           "error": "CalledProcessError: original fixture subprocess exited 1",
           "ownedSimulatorCleanup": "PASS"}
rows = []


def run_control(name, leak=None, token=FIXTURE_TOKEN, change_source=False):
    spec = importlib.util.spec_from_file_location("fixture_control_subject", SUBJECT)
    subject = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(subject)
    with tempfile.TemporaryDirectory() as temporary:
        subject.ROOT = Path(temporary)
        subject.WORK = subject.ROOT / "build/hanlin-live-private"
        subject.OUT = subject.ROOT / "build/hanlin-live-evidence"
        artifacts = subject.ROOT / "build/artifacts"
        artifacts.mkdir(parents=True)
        (artifacts / "original.bin").write_bytes(bytes(range(256)))
        original_identity = subject.evidence_identity(artifacts)
        contexts = []
        matrix_calls = []
        expected_fixture = {}

        def source_context():
            assert "OTZARIA_HANLIN_LIVE_API_KEY" not in os.environ
            assert os.environ.get("GH_TOKEN", "") == token
            contexts.append(True)
            return {"disposable_source": len(contexts) if change_source else 1}

        def prepare_selection():
            subject.write(subject.WORK / "selection.json", {"disposable_control": True})

        def failed_matrix(live_provider):
            matrix_calls.append(True)
            assert live_provider._key == PROVIDER
            assert not live_provider.staged and live_provider.udid is None
            live_provider.validate_selection(False, None, [subject.SELECTOR])
            subject.write(artifacts / "faithful-ipad-matrix.json", {"devices": [FAILURE]})
            for filename in REPORT_NAMES:
                value = {"disposable_control": True, "passed": False, "profileID": "miniTest10",
                         "phase": "install", "errors": [leak or "PUBLIC_CONTROL_FIXTURE_FAILURE"]}
                subject.write(artifacts / filename, value)
                expected_fixture[filename] = (artifacts / filename).read_bytes()
            # An unrelated raw file is never part of the fixed report admission.
            (artifacts / "unlisted-private-control.txt").write_text(PROVIDER)
            assert not (artifacts / "runtime27/verified-11.json").exists()
            return 1

        def load_matrix(path):
            assert Path(path) == subject.ROOT / "Scripts/CI/run-faithful-ipad-matrix.py"
            return {"main": failed_matrix}

        environment = {"OTZARIA_HANLIN_LIVE_API_KEY": PROVIDER, "GH_TOKEN": token,
                       "GITHUB_RUN_ID": "disposable-control", "GITHUB_RUN_ATTEMPT": "1"}
        output = io.StringIO()
        with patch.dict(os.environ, environment, clear=True), \
             patch.object(subject, "source_context", source_context), \
             patch.object(subject, "prepare_selection", prepare_selection), \
             patch.object(subject.runpy, "run_path", load_matrix), \
             patch.object(subject.subprocess, "run", side_effect=AssertionError("No child process allowed")), \
             patch.object(subject.subprocess, "check_output", side_effect=AssertionError("No child process allowed")), \
             redirect_stdout(output):
            code = subject.main()
        assert code == 1 and len(contexts) == 2 and len(matrix_calls) == 1
        assert subject.evidence_identity(artifacts) == original_identity
        for literal in [PROVIDER, FIXTURE_TOKEN]:
            assert literal not in output.getvalue()
            assert base64.b64encode(literal.encode()).decode() not in output.getvalue()
        if leak is not None:
            assert not subject.OUT.exists(), "A credential-bearing fixture must remove the entire admitted directory"
        else:
            result = json.loads((subject.OUT / "result.json").read_text())
            assert result["status"] == "FAIL" and result["matrix_exit_code"] == 1
            assert result["failure_phase"] == ("SOURCE_AFTER" if change_source else "NATIVE_MATRIX")
            assert result["error_kind"] == "ValueError", "Missing strict evidence must not obscure the primary failure"
            if not change_source:
                assert result["matrix_failures"] == [FAILURE]
            assert result["verified_completed_provider_conversations"] == 0
            assert all(result[key] is False for key in ["private_input_staged", "private_input_consumed",
                "private_input_removed", "native116_acceptance", "release114_acceptance"])
            assert result["prior_artifacts_restored"] is True
            admission = json.loads((subject.OUT / "admission.json").read_text())
            assert admission["status"] == "SCANNED_ALLOWLIST_ONLY"
            assert not (subject.OUT / "unlisted-private-control.txt").exists()
            for filename, expected in expected_fixture.items():
                assert (subject.OUT / filename).read_bytes() == expected
                assert admission["files"][filename] == {"sha256": hashlib.sha256(expected).hexdigest(), "bytes": len(expected)}
    rows.append({"control": name, "status": "PASS"})


run_control("original failed fixture phase and error retained; absent strict evidence not read; five exact reports admitted")
run_control("provider raw bytes in fixture reject the entire evidence publication", leak=PROVIDER)
run_control("provider base64 bytes in fixture reject the entire evidence publication", leak=base64.b64encode(PROVIDER.encode()).decode())
run_control("GitHub token raw bytes in fixture reject the entire evidence publication", leak=FIXTURE_TOKEN)
run_control("GitHub token base64 bytes in fixture reject the entire evidence publication", leak=base64.b64encode(FIXTURE_TOKEN.encode()).decode())
run_control("absent fixture token does not introduce an empty secret pattern", token="")
run_control("failed fixture does not bypass unchanged before and after source validation", change_source=True)

report = {"status": "DISPOSABLE_FIXTURE_EVIDENCE_CONTROLS_PASS", "runner_sha256": hashlib.sha256(SUBJECT.read_bytes()).hexdigest(),
          "controls": rows, "controls_passed": len(rows), "native_tests_executed": 0,
          "provider_requests": 0, "real_credentials_read": False, "prior_18_controls_rerun": False}
destination = HERE / "docs/hq-integration/completion-20261121/hanlin-live-ci/LIVE_FIXTURE_EVIDENCE_CONTROLS.json"
destination.parent.mkdir(parents=True, exist_ok=True)
destination.write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps({key: value for key, value in report.items() if key != "controls"}))

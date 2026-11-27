"""Control-flow regression checks, with explicit device/UI/SDK doubles.

No macOS command, database, Simulator, network or XCTest is executed here.
These checks exercise the real controller's failure/cleanup/publication order.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
from types import SimpleNamespace as NS
import tempfile
import unittest
from unittest.mock import patch

parser = argparse.ArgumentParser(add_help=False)
parser.add_argument("--candidate", type=Path, default=Path(__file__).with_name("production-study-v40-ui.py"))
candidate_args, unittest_args = parser.parse_known_args()
SPEC = importlib.util.spec_from_file_location("study_controller", candidate_args.candidate.resolve(strict=True))
DRIVER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(DRIVER)
UDID = "12345678-1234-1234-1234-123456789ABC"


def witness(path):
    path = Path(path)
    data = path.read_bytes()
    return {"path": str(path), "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def write(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, sort_keys=True))


class Scenario:
    def __init__(self, root, phase):
        self.root, self.phase, self.events = root, phase, []
        self.source_changed = self.native_failure = self.cleanup_failure = False
        self.prerequisite_failure = self.context_changed = self.updated_changed = False
        self.current_v40_calls = self.sealed = self.native_calls = 0
        self.source = {"checkout_sha": "a" * 40}
        self.build = {"build_receipt": {"path": "synthetic-build", "bytes": 1, "sha256": "b" * 64}}
        self.owner_record = {"dataContainer": str(root / "appdata"), "storageRoot": str(root / "appdata")}
        self.container = root / "appdata"
        self.container.mkdir()
        self.database = self.container / "seforim.db"
        self.database.write_bytes(b"synthetic-control-only-not-production")
        self.products = root / "products"
        for name in ("Maktabah.app", "Maktabah-iOSUITests-Runner.app"):
            (self.products / name).mkdir(parents=True)
            (self.products / name / "image").write_bytes(b"synthetic")
        self.input = root / "inputs.json"
        write(self.input, {})
        self.installation_file = root / "installer.json"
        write(self.installation_file, {"scope": "synthetic control only"})
        self.original = witness(self.installation_file)
        self.pages_file = root / "pages.json"
        write(self.pages_file, {"scope": "synthetic pages control"})
        self.context_file = root / "context.json"
        write(self.context_file, {"scope": "synthetic context control"})
        self.binding = {"input": witness(self.context_file), "effective": witness(self.context_file), "relocations": []}
        runtime = {"identifier": "synthetic-runtime", "version": "27.0", "isAvailable": True,
                   "supportedDeviceTypes": [{"name": "iPad Pro 13-inch", "identifier": "synthetic-type"}]}
        self.core = NS(ROOT=root, INPUTS=self.input, BUNDLE="test.control.bundle", OUT=None,
                       write=write, witness=witness, digest=lambda p: witness(p)["sha256"],
                       bounded_json=lambda p, n: json.loads(Path(p).read_text()),
                       build_identity=lambda context: (self.products, root / "original.xctestrun", self.build),
                       json_command=lambda args: {"runtimes": [runtime]},
                       git=lambda *args: "a" * 40, command=self.command)
        scenario = self
        class Owner:
            def __init__(self, *args):
                self.prior = {"result": scenario.original}
            def admit_owner(self, config, runtime, types):
                return UDID, types[0], {"reused_external_owned_simulator": UDID, "original_installation": self.prior}
            def admit_current_installation(self, *args):
                scenario.current_v40_calls += 1
                return scenario.database, {"database": witness(scenario.database)}
            def current_database(self, *args):
                scenario.current_v40_calls += 1
                return scenario.database, {}
            def verify_installed_images(self, *args):
                scenario.events.append("images-verified")
                return {"scope": "synthetic image control"}
            def verify_prior_receipts(self):
                return {"installer": scenario.original}
            def retain_simulator(self, *args):
                scenario.events.append("simulator-retained")
                return {"scope": "synthetic cleanup control"}
        self.retained = NS(RetainedV40Installation=Owner)
        self.settings = NS(witness=witness, verify_witness=self.verify_witness, decode_json=json.loads,
                           capture_before=self.before, verified_execution=lambda *a, **k: {},
                           seal_success=self.seal, selected_attachment=self.attachment)
        class SearchHost:
            def __init__(self, **kwargs):
                self.threads, self.token = [], "synthetic-private-token"
                self.monitor = NS(is_alive=lambda: False)
            def start(self):
                scenario.events.append("host-started")
            def stop_and_verify(self, *args, **kwargs):
                scenario.events.append("host-verified-and-stopped")
                return {"scope": "synthetic host control"}
            def abort(self):
                scenario.events.append("host-aborted")
                return {"verified": not scenario.cleanup_failure}
        class PullHost:
            def __init__(self, **kwargs):
                self.processes = [NS(poll=lambda: 0)]
                self.resolver_thread = NS(is_alive=lambda: False)
                self.token = "c" * 48
            def start(self):
                scenario.events.append("host-started")
                return {"TEST_RUNNER_READER_CONTINUOUS_PULL_TOKEN": self.token}
            def stop(self):
                scenario.events.append("host-stopped")
                if scenario.cleanup_failure:
                    raise ValueError("synthetic contact acceptance failed; processes stopped")
                return {"scope": "synthetic contact control"}
        self.modules = {"study-ui-settings-receipts.py": self.settings,
                        "study-ui-prerequisites.py": NS(admit_before_settings=self.prerequisites),
                        "study-ui-search-log.py": NS(SearchLogCapture=SearchHost),
                        "reader-continuous-pull-host.py": NS(ContinuousPullHost=PullHost)}

    def command(self, args, **kwargs):
        self.events.append("command:" + ":".join(args[:3]))
        return NS(stdout="27.0", returncode=0)

    def verify_witness(self, record, *args):
        if witness(record["path"]) != record:
            raise ValueError("actual control input changed")
        return Path(record["path"]).read_bytes()

    def before(self, **kwargs):
        write(kwargs["output"], {"snapshot": {"installationManifest": {"sha256": "d" * 64}}})
        return witness(kwargs["output"])

    def seal(self, **kwargs):
        self.sealed += 1
        self.events.append("settings-sealed")
        write(kwargs["output"], {"scope": "synthetic seal control"})
        return witness(kwargs["output"])

    def prerequisites(self, *args, **kwargs):
        self.events.append("prerequisites")
        if self.prerequisite_failure:
            raise ValueError("synthetic unqualified required producer")
        return {"proof": {"receipts": {"study:pages": witness(self.pages_file)}}}

    def attachment(self, *args, **kwargs):
        return {"file": witness(self.pages_file), "contents": {}}

    def source_context(self, core, phase, frozen):
        if self.source_changed and self.native_calls:
            return {"checkout_sha": "f" * 40}
        return self.source

    def run_case(self, core, test_run, udid, case, allowance, output, environment, private_values):
        self.native_calls += 1
        self.events.append("synthetic-ui-result")
        output.mkdir()
        if self.context_changed:
            write(self.context_file, {"scope": "changed during control execution"})
        result = {"case": case, "case_directory": str(output), "passed": not self.native_failure}
        write(output / "RESULT.json", result)
        return result

    def snapshot(self, *args):
        if self.updated_changed and self.native_calls:
            raise ValueError("synthetic updated file identity changed")
        return {"database": witness(self.database)}

    def run(self):
        args = NS(study_phase=self.phase, owned_simulator=UDID, installation_result=self.installation_file,
                  output=self.root / "build/artifacts/run", reserved_other_bytes=0, runner_inputs=None,
                  prerequisites=self.pages_file, pages_phase_result=self.pages_file,
                  settings_phase_result=self.pages_file, pinned_hid_tools=self.root, annotations_path=None)
        input_values = {key: ("a" * 64 if key.endswith("SHA256") else str(self.pages_file))
                        for key in DRIVER.PHASES[self.phase]["inputs"]}
        envelope = {"after": {"database": witness(self.database)}, "traceBaseline": {"namespace": UDID}}
        changes = {
            "ROOT": self.root, "load_core": lambda: (self.retained, self.core),
            "load_support": lambda name: self.modules[name], "source_context": self.source_context,
            "input_values": lambda *a: input_values, "observe_inputs": lambda *a: {},
            "install_images": lambda *a: {"scope": "synthetic install control"},
            "actual_owner": lambda *a: self.owner_record,
            "prepare_context": lambda *a: (self.owner_record, self.binding),
            "official_metadata": lambda *a: ({}, {}),
            "positive_trace": lambda *a: ({}, witness(self.pages_file)),
            "admit_updated": lambda *a: (witness(self.pages_file), envelope, self.snapshot(), witness(self.pages_file)),
            "updated_snapshot": self.snapshot, "image_resolver": lambda *a: lambda: "synthetic-image",
            "run_original_case": self.run_case,
        }
        with patch.multiple(DRIVER, **changes), patch.object(DRIVER.sys, "platform", "darwin"), \
             patch.object(DRIVER.shutil, "disk_usage", return_value=NS(free=100 * DRIVER.GIB)), \
             patch.dict(DRIVER.os.environ, {"FAITHFUL_RUNTIME27_IDENTIFIER": "synthetic-runtime"}):
            try:
                DRIVER.execute(args)
                error = None
            except Exception as value:
                error = value
        return error, json.loads((args.output / "RESULT.json").read_text())


class ControllerChecks(unittest.TestCase):
    def scenario(self, phase):
        temp = tempfile.TemporaryDirectory(prefix="study-controller-source-control-")
        self.addCleanup(temp.cleanup)
        return Scenario(Path(temp.name), phase)

    def test_unqualified_prerequisites_never_boot_or_update(self):
        s = self.scenario("settings-update-last"); s.prerequisite_failure = True
        error, result = s.run()
        self.assertIsNotNone(error); self.assertEqual(s.native_calls, 0); self.assertEqual(s.sealed, 0)
        self.assertNotIn("command:xcrun:simctl:boot", s.events)
        self.assertEqual(result["status"], "FAILED_OR_INCOMPLETE")

    def test_source_change_prevents_settings_seal_after_ui(self):
        s = self.scenario("settings-update-last"); s.source_changed = True
        error, result = s.run()
        self.assertIsNotNone(error); self.assertEqual(s.native_calls, 1); self.assertEqual(s.sealed, 0)
        self.assertIn("simulator-retained", s.events)
        self.assertEqual(result["status"], "FAILED_OR_INCOMPLETE")

    def test_actual_effective_context_change_prevents_seal(self):
        s = self.scenario("settings-update-last"); s.context_changed = True
        error, result = s.run()
        self.assertIsNotNone(error); self.assertEqual(s.sealed, 0)
        self.assertTrue(any(v.startswith("source_build:") for v in result["post_verification_failures"]))

    def test_settings_seal_happens_after_image_postcheck(self):
        s = self.scenario("settings-update-last")
        error, result = s.run()
        self.assertIsNone(error); self.assertEqual(s.sealed, 1)
        self.assertLess(s.events.index("images-verified"), s.events.index("settings-sealed"))
        self.assertLess(s.events.index("settings-sealed"), s.events.index("simulator-retained"))
        self.assertEqual(result["status"], DRIVER.STUDY_PASS)

    def test_failed_native_search_aborts_host_before_retention(self):
        s = self.scenario("search-after-settings"); s.native_failure = True
        error, result = s.run()
        self.assertIsNotNone(error); self.assertEqual(s.current_v40_calls, 0)
        self.assertLess(s.events.index("host-aborted"), s.events.index("simulator-retained"))
        self.assertEqual(result["status"], "FAILED_OR_INCOMPLETE")

    def test_unverified_host_cleanup_defers_simulator_shutdown(self):
        s = self.scenario("search-after-settings"); s.native_failure = s.cleanup_failure = True
        error, result = s.run()
        self.assertIsNotNone(error); self.assertNotIn("simulator-retained", s.events)
        self.assertEqual(result["owned_cleanup"]["status"], "NOT_SHUT_DOWN_HOST_CLEANUP_UNVERIFIED")

    def test_changed_v41_identity_fails_after_both_ui_and_log(self):
        s = self.scenario("search-after-settings"); s.updated_changed = True
        error, result = s.run()
        self.assertIsNotNone(error); self.assertIn("host-verified-and-stopped", s.events)
        self.assertEqual(s.current_v40_calls, 0); self.assertEqual(result["status"], "FAILED_OR_INCOMPLETE")

    def test_post_settings_success_has_separate_source_scope(self):
        s = self.scenario("search-after-settings")
        error, result = s.run()
        self.assertIsNone(error); self.assertEqual(result["status"], DRIVER.POST_UPDATE_PASS)
        self.assertNotEqual(result["status"], DRIVER.STUDY_PASS); self.assertEqual(s.current_v40_calls, 0)

    def test_pull_transport_failure_with_stopped_workers_is_not_ui_pass(self):
        s = self.scenario("reader-continuous-pull"); s.cleanup_failure = True
        error, result = s.run()
        self.assertIsNotNone(error); self.assertIn("simulator-retained", s.events)
        self.assertLess(s.events.index("host-stopped"), s.events.index("simulator-retained"))
        self.assertEqual(result["status"], "FAILED_OR_INCOMPLETE")


if __name__ == "__main__":
    unittest.main(argv=[__file__, *unittest_args], verbosity=2)

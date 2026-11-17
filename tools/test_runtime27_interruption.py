#!/usr/bin/env python3
"""Focused interruption-boundary regressions for runtime27 and run-faithful-ipad-matrix.

Uses isolated temp directories and injected/mocked external commands only.
Never launches Xcode, simulators, CI, or generic process kills.
"""
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import textwrap
import unittest

REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS_CI = REPO_ROOT / "Scripts" / "CI"


def _create_sandbox(tmp_dir: Path, scenarios_mode: str = "manifest") -> Path:
    root = tmp_dir / "repo"
    (root / "build" / "DerivedData" / "Build" / "Products" / "Debug-iphonesimulator" / "Maktabah.app").mkdir(parents=True)
    (root / "build" / "artifacts" / "runtime27").mkdir(parents=True)
    scripts_dir = root / "Scripts" / "CI"
    scripts_dir.mkdir(parents=True)
    tools_dir = root / "tools"
    tools_dir.mkdir(parents=True)

    for name in ("runtime27.py", "run-faithful-ipad-matrix.py", "runtime27_interruption.py"):
        src = SCRIPTS_CI / name
        if src.is_file():
            shutil.copy2(src, scripts_dir / name)

    (tools_dir / "verify_xcresult_zero_skips.py").write_text(
        "def case_id(value):\n    return value.rstrip('()')\n",
        encoding="utf-8",
    )

    if scenarios_mode == "manifest":
        contract_dir = root / "docs" / "hq-integration" / "runtime27"
        contract_dir.mkdir(parents=True)
        contract = {
            "scope": "test-interruption",
            "source_test_commit": "0" * 40,
            "hid_comparison": False,
            "cases": [
                {"case_id": "R27NativePadTests/testOne", "device": "ipad11", "oracle": "o1"},
                {"case_id": "R27NativePhoneTests/testTwo", "device": "iphone", "oracle": "o2"},
            ],
            "execution_case_ids": [
                "R27NativePadTests/testOne",
                "R27NativePhoneTests/testTwo",
            ],
            "execution_groups": [
                {"label": "11-window", "size": "11", "case_ids": ["R27NativePadTests/testOne"]},
                {"label": "phone", "size": "phone", "case_ids": ["R27NativePhoneTests/testTwo"]},
            ],
        }
        manifest_path = contract_dir / "R27_CASES.json"
        manifest_path.write_text(json.dumps(contract), encoding="utf-8")
    return root


def _build_matrix_driver(root: Path, behavior: dict) -> Path:
    driver = root / "_test_driver.py"
    behavior_path = root / "_behavior.json"
    behavior_path.write_text(json.dumps(behavior), encoding="utf-8")
    driver.write_text(
        textwrap.dedent(
            """\
            import json
            import os
            from pathlib import Path
            import runpy
            import signal
            import subprocess
            import sys

            ROOT = Path.cwd()
            BEHAVIOR = json.loads((ROOT / "_behavior.json").read_text(encoding="utf-8"))
            EVENTS_PATH = ROOT / "_events.jsonl"

            def log_event(kind, **payload):
                with EVENTS_PATH.open("a", encoding="utf-8") as handle:
                    handle.write(json.dumps({"kind": kind, **payload}) + "\\n")

            created_counter = 0

            class FakeStream:
                def __init__(self, lines):
                    self._lines = list(lines)
                    self._idx = 0
                def __iter__(self):
                    return self
                def __next__(self):
                    if self._idx >= len(self._lines):
                        raise StopIteration
                    line = self._lines[self._idx]
                    self._idx += 1
                    if line == "__INTERRUPT_SIGINT__":
                        signal.raise_signal(signal.SIGINT)
                    elif line == "__INTERRUPT_SIGTERM__":
                        signal.raise_signal(signal.SIGTERM)
                    return line
                def close(self):
                    pass

            class FakeProcess:
                _next_pid = 90000
                def __init__(self, cmd, lines=None, exit_code=0, role="generic"):
                    FakeProcess._next_pid += 1
                    self.pid = FakeProcess._next_pid
                    self.cmd = list(cmd)
                    self.role = role
                    self._exit_code = exit_code
                    self._terminated = False
                    self._killed = False
                    self.stdout = FakeStream(lines or [])
                    log_event("popen", role=role, pid=self.pid, cmd=self.cmd)
                def poll(self):
                    return self._exit_code if self._terminated else None
                def wait(self, timeout=None):
                    log_event("popen_wait", role=self.role, pid=self.pid, timeout=timeout)
                    if self.role == "recording" and BEHAVIOR.get("recording_wait_error") == "timeout":
                        if not self._terminated:
                            raise subprocess.TimeoutExpired(self.cmd, timeout)
                    if self.role == "xcodebuild" and BEHAVIOR.get("hang_xcodebuild_until_kill"):
                        if not self._killed:
                            raise subprocess.TimeoutExpired(self.cmd, timeout)
                        return -9
                    if self.role == "palette_stream" and BEHAVIOR.get("palette_stream_error") == "oserror":
                        raise OSError("broken stream pipe")
                    if self.role == "xcodebuild" and not self._terminated:
                        self._terminated = True
                        if BEHAVIOR.get("xcodebuild_exit_code", 0) != 0 and BEHAVIOR.get("fail_first_only", True):
                            if BEHAVIOR.get("_failed_once"):
                                return 0
                            BEHAVIOR["_failed_once"] = True
                            return BEHAVIOR["xcodebuild_exit_code"]
                        return BEHAVIOR.get("xcodebuild_exit_code", 0)
                    self._terminated = True
                    return self._exit_code
                def send_signal(self, sig):
                    log_event("popen_signal", role=self.role, pid=self.pid, sig=int(sig))
                    if self.role == "recording" and BEHAVIOR.get("recording_exit_on_sigint", True):
                        self._terminated = True
                def terminate(self):
                    log_event("popen_terminate", role=self.role, pid=self.pid)
                    self._terminated = True
                def kill(self):
                    log_event("popen_kill", role=self.role, pid=self.pid)
                    self._killed = True
                    self._terminated = True

            def fake_check_output(cmd, *args, **kwargs):
                cmd_list = [str(c) for c in cmd]
                log_event("check_output", cmd=cmd_list, timeout=kwargs.get("timeout"))
                if cmd_list[:2] == ["git", "rev-parse"]:
                    return "0" * 40 + "\\n"
                if cmd_list[:3] == ["xcrun", "--sdk", "iphonesimulator"]:
                    return "27.1\\n"
                if cmd_list[:4] == ["xcrun", "simctl", "list", "runtimes"]:
                    return json.dumps({"runtimes": [{
                        "isAvailable": True,
                        "version": "27.2",
                        "identifier": "com.apple.CoreSimulator.SimRuntime.iOS-27-2",
                        "supportedDeviceTypes": [
                            {"identifier": "com.apple.CoreSimulator.SimDeviceType.iPad-Pro-11-inch-M5-12GB"},
                            {"identifier": "com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB"},
                            {"identifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-17"},
                        ],
                    }]})
                if cmd_list[:4] == ["xcrun", "simctl", "list", "devicetypes"]:
                    return json.dumps({"devicetypes": [
                        {"identifier": "com.apple.CoreSimulator.SimDeviceType.iPad-Pro-11-inch-M5-12GB", "name": "iPad Pro 11-inch (M5)"},
                        {"identifier": "com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB", "name": "iPad Pro 13-inch (M5)"},
                        {"identifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-17", "name": "iPhone 17"},
                    ]})
                if cmd_list[:3] == ["xcrun", "simctl", "get_app_container"]:
                    container = ROOT / "build" / "fake_container"
                    (container / "Documents").mkdir(parents=True, exist_ok=True)
                    return str(container) + "\\n"
                if cmd_list[:3] == ["xcrun", "simctl", "ui"] and cmd_list[-1] == "content_size":
                    return "accessibility-extra-extra-extra-large\\n"
                return ""

            def fake_run(cmd, *args, **kwargs):
                cmd_list = [str(c) for c in cmd]
                timeout = kwargs.get("timeout")
                log_event("run", cmd=cmd_list, timeout=timeout)
                if cmd_list[:3] == ["xcrun", "simctl", "create"]:
                    global created_counter
                    created_counter += 1
                    udid = f"00000000-0000-4000-8000-00000000000{created_counter}"
                    log_event("created_udid", udid=udid)
                    return subprocess.CompletedProcess(cmd, 0, stdout=udid + "\\n", stderr="")
                if len(cmd_list) >= 3 and cmd_list[:3] == ["xcrun", "xcresulttool", "export"]:
                    if BEHAVIOR.get("interrupt_at") == "export_attachments":
                        signal.raise_signal(signal.SIGINT)
                    return subprocess.CompletedProcess(cmd, 0, stdout="", stderr="")
                if "collect-runtime27-palette-log.py" in " ".join(cmd_list):
                    return subprocess.CompletedProcess(cmd, 0, stdout="", stderr="")
                if "shutdown-faithful-simulator.py" in " ".join(cmd_list):
                    if BEHAVIOR.get("second_signal_in_shutdown"):
                        signal.raise_signal(signal.SIGINT)
                    err = BEHAVIOR.get("shutdown_error")
                    if err == "called_process_error":
                        raise subprocess.CalledProcessError(1, cmd)
                    if err == "timeout":
                        raise subprocess.TimeoutExpired(cmd, timeout)
                    if err == "oserror":
                        raise OSError("simctl shutdown missing")
                    return subprocess.CompletedProcess(cmd, 0, stdout="", stderr="")
                if cmd_list[:3] == ["xcrun", "simctl", "delete"]:
                    err = BEHAVIOR.get("delete_error")
                    if err == "called_process_error":
                        raise subprocess.CalledProcessError(1, cmd)
                    return subprocess.CompletedProcess(cmd, 0, stdout="", stderr="")
                if cmd_list[:4] == ["xcrun", "simctl", "help", "ui"]:
                    return subprocess.CompletedProcess(cmd, 0, stdout="content_size accessibility-extra-extra-extra-large\\n", stderr="")
                if len(cmd_list) >= 2 and cmd_list[0] == "xcodebuild":
                    # largeText run
                    if BEHAVIOR.get("interrupt_at") == "large_text":
                        signal.raise_signal(signal.SIGINT)
                    log_idx = cmd_list.index("-resultBundlePath")
                    # stdout might be a file handle; write passing test summary if provided
                    stdout_handle = kwargs.get("stdout")
                    if stdout_handle and hasattr(stdout_handle, "write"):
                        stdout_handle.write("Executed 1 test, with 0 failures\\n")
                    return subprocess.CompletedProcess(cmd, 0)
                return subprocess.CompletedProcess(cmd, 0, stdout="", stderr="")

            def fake_popen(cmd, *args, **kwargs):
                cmd_list = [str(c) for c in cmd]
                if cmd_list and cmd_list[0] == "xcodebuild":
                    if BEHAVIOR.get("interrupt_at") == "xcodebuild_sigterm":
                        lines = ["Running test...\\n", "__INTERRUPT_SIGTERM__"]
                    elif BEHAVIOR.get("interrupt_at") == "xcodebuild_sigint":
                        lines = ["Running test...\\n", "__INTERRUPT_SIGINT__"]
                    else:
                        suites = []
                        for arg in cmd_list:
                            if arg.startswith("-only-testing:Maktabah-iOSUITests/"):
                                suites.append(arg.split("/", 2)[1])
                        if not suites:
                            suites = ["R27NativePadTests"]
                        count = max(6, len(suites))
                        if BEHAVIOR.get("xcodebuild_exit_code", 0) != 0 and not BEHAVIOR.get("_logged_fail"):
                            BEHAVIOR["_logged_fail"] = True
                            lines = [f"Test Suite '{s}' failed\\n" for s in suites] + [f"Executed {count} tests, with 1 failure\\n"]
                        else:
                            lines = [f"Test Suite '{s}' passed\\n" for s in suites] + [f"Executed {count} tests, with 0 failures\\n"]
                    return FakeProcess(cmd_list, lines=lines, role="xcodebuild")
                if "recordVideo" in cmd_list:
                    return FakeProcess(cmd_list, role="recording")
                if "log" in cmd_list and "stream" in cmd_list:
                    return FakeProcess(cmd_list, role="palette_stream")
                return FakeProcess(cmd_list, role="generic")

            orig_run_path = runpy.run_path
            def fake_run_path(path, init_globals=None, run_name=None):
                p = str(path).replace("\\\\", "/")
                if p.endswith("Scripts/CI/verify-faithful-xctest.py"):
                    def verify(_, selection):
                        return {"suites": [{"suite": item.split("/")[0], "expected": [item.split("/")[1]]}
                                           if "/" in item else {"suite": item, "expected": ["testOne"]}
                                           for item in selection]}
                    return {"verify": verify}
                if p.endswith("Scripts/CI/runtime27-fixture-oracle.py"):
                    return {"derive_oracle": lambda udid, label, include_sidebar=False: {"R27_EXPECTED_OTZARIA_WORK_KEY": "book:3891"}}
                if p.endswith("Scripts/CI/collect-runtime27-palette-log.py"):
                    class FakePaletteStream:
                        def __init__(self, udid, label):
                            self.udid = udid
                            self.label = label
                        def start(self):
                            log_event("palette_stream_start", udid=self.udid, label=self.label)
                            return self
                        def stop(self):
                            log_event("palette_stream_stop", udid=self.udid, label=self.label)
                            if BEHAVIOR.get("palette_stream_error") == "oserror":
                                raise OSError("broken palette stream")
                            return {"status": "RETAINED_RAW_STREAM"}
                    return {"PaletteLogStream": FakePaletteStream}
                return orig_run_path(path, init_globals=init_globals, run_name=run_name)

            subprocess.check_output = fake_check_output
            subprocess.run = fake_run
            subprocess.Popen = fake_popen
            runpy.run_path = fake_run_path

            # Create placeholder result bundles if needed
            for lbl in ("11-window", "phone", "11", "13", "13-large-text"):
                (ROOT / "build" / "artifacts" / f"result-{lbl}.xcresult").mkdir(parents=True, exist_ok=True)

            runpy.run_path(str(ROOT / "Scripts" / "CI" / "run-faithful-ipad-matrix.py"), run_name="__main__")
            """
        ),
        encoding="utf-8",
    )
    return driver


class MatrixInterruptionRegressionTests(unittest.TestCase):
    def _run_driver(self, root: Path, env_extra: dict, behavior: dict):
        driver = _build_matrix_driver(root, behavior)
        env = os.environ.copy()
        env.update(env_extra)
        proc = subprocess.run(
            [sys.executable, str(driver)],
            cwd=root,
            env=env,
            capture_output=True,
            text=True,
            timeout=30,
        )
        events = []
        events_path = root / "_events.jsonl"
        if events_path.is_file():
            events = [json.loads(line) for line in events_path.read_text(encoding="utf-8").splitlines() if line.strip()]
        matrix_path = root / "build" / "artifacts" / "faithful-ipad-matrix.json"
        matrix = json.loads(matrix_path.read_text(encoding="utf-8")) if matrix_path.is_file() else None
        return proc, events, matrix

    def test_sigterm_halts_device_advancement_stops_owned_xcodebuild_and_runs_bounded_cleanup(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = _create_sandbox(Path(tmp), scenarios_mode="manifest")
            env = {"FAITHFUL_RUNTIME27_MANIFEST": str(root / "docs" / "hq-integration" / "runtime27" / "R27_CASES.json")}
            proc, events, matrix = self._run_driver(
                root, env, {"interrupt_at": "xcodebuild_sigterm", "hang_xcodebuild_until_kill": True}
            )

            self.assertEqual(proc.returncode, 130, f"stderr={proc.stderr}")
            self.assertIsNotNone(matrix)
            self.assertEqual(matrix.get("status"), "INTERRUPTED_UI_UNVERIFIED")
            self.assertIs(matrix.get("interrupted"), True)
            self.assertEqual(len(matrix["devices"]), 1, "Interruption must stop device advancement before phone")
            dev = matrix["devices"][0]
            self.assertEqual(dev["label"], "11-window")
            self.assertEqual(dev["status"], "INTERRUPTED")
            self.assertEqual(dev.get("ownedSimulatorCleanup"), "PASS")

            xcode_signals = [e for e in events if e["kind"] in ("popen_signal", "popen_terminate", "popen_kill") and e["role"] == "xcodebuild"]
            self.assertTrue(xcode_signals, "Owned xcodebuild subprocess must be stopped on interruption")
            self.assertTrue(any(e["kind"] == "popen_kill" and e["role"] == "xcodebuild" for e in events),
                            "Owned xcodebuild ignoring terminate/SIGINT must escalate to kill()")
            created = [e["udid"] for e in events if e["kind"] == "created_udid"]
            self.assertEqual(created, [dev["udid"]])
            shutdown_calls = [e for e in events if e["kind"] == "run" and "shutdown-faithful-simulator.py" in " ".join(e["cmd"])]
            self.assertEqual(len(shutdown_calls), 1)
            self.assertIn(dev["udid"], shutdown_calls[0]["cmd"])
            self.assertLessEqual(shutdown_calls[0]["timeout"], 10)

    def test_interruption_after_xcodebuild_pass_never_records_executed_pass(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = _create_sandbox(Path(tmp), scenarios_mode="default")
            env = {"VALIDATING_BASELINE": "false"}
            proc, events, matrix = self._run_driver(root, env, {"interrupt_at": "large_text"})

            self.assertEqual(proc.returncode, 130, f"stderr={proc.stderr}")
            self.assertIsNotNone(matrix)
            self.assertEqual(matrix.get("status"), "INTERRUPTED_UI_UNVERIFIED")
            labels = [d["label"] for d in matrix["devices"]]
            self.assertEqual(labels, ["11", "13"], "Interruption on 13-inch must not advance to phone")
            self.assertEqual(matrix["devices"][0]["status"], "EXECUTED_PASS")
            self.assertEqual(matrix["devices"][1]["status"], "INTERRUPTED")
            self.assertNotEqual(matrix["devices"][1]["status"], "EXECUTED_PASS")
            self.assertNotEqual(matrix["devices"][1].get("largeText", {}).get("status"), "EXECUTED_PASS")

    def test_interruption_before_udid_creation_never_calls_shutdown_or_delete(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = _create_sandbox(Path(tmp), scenarios_mode="manifest")
            env = {"FAITHFUL_RUNTIME27_MANIFEST": str(root / "docs" / "hq-integration" / "runtime27" / "R27_CASES.json")}
            # Trigger SIGTERM during simctl create on device 0
            driver = _build_matrix_driver(root, {})
            orig = driver.read_text(encoding="utf-8")
            driver.write_text(
                orig.replace(
                    'if cmd_list[:3] == ["xcrun", "simctl", "create"]:',
                    'if cmd_list[:3] == ["xcrun", "simctl", "create"]:\n        signal.raise_signal(signal.SIGTERM)',
                ),
                encoding="utf-8",
            )
            proc = subprocess.run([sys.executable, str(driver)], cwd=root, env={**os.environ, **env}, capture_output=True, text=True, timeout=30)
            events = [json.loads(line) for line in (root / "_events.jsonl").read_text(encoding="utf-8").splitlines() if line.strip()]
            matrix_path = root / "build" / "artifacts" / "faithful-ipad-matrix.json"
            self.assertEqual(proc.returncode, 130, f"stderr={proc.stderr}")
            self.assertTrue(matrix_path.is_file())
            matrix = json.loads(matrix_path.read_text(encoding="utf-8"))
            self.assertEqual(matrix.get("status"), "INTERRUPTED_UI_UNVERIFIED")
            self.assertEqual(matrix.get("devices"), [])
            shutdown_or_delete = [
                e for e in events
                if e["kind"] == "run" and (
                    "shutdown-faithful-simulator.py" in " ".join(e["cmd"])
                    or e["cmd"][:3] == ["xcrun", "simctl", "delete"]
                )
            ]
            self.assertEqual(shutdown_or_delete, [], "Must never shut down or delete unowned/non-created simulators")

    def test_cleanup_failure_and_second_signal_preserve_interrupted_receipt_and_skip_slow_diagnostics(self):
        for behavior_name, behavior in [
            ("helper_oserror_and_shutdown_fail", {
                "interrupt_at": "xcodebuild_sigint",
                "palette_stream_error": "oserror",
                "shutdown_error": "called_process_error",
            }),
            ("recording_timeout_and_second_signal", {
                "interrupt_at": "xcodebuild_sigint",
                "recording_wait_error": "timeout",
                "second_signal_in_shutdown": True,
                "shutdown_error": "timeout",
            }),
        ]:
            with self.subTest(case=behavior_name), tempfile.TemporaryDirectory() as tmp:
                root = _create_sandbox(Path(tmp), scenarios_mode="manifest")
                env = {"FAITHFUL_RUNTIME27_MANIFEST": str(root / "docs" / "hq-integration" / "runtime27" / "R27_CASES.json")}
                proc, events, matrix = self._run_driver(root, env, behavior)

                self.assertEqual(proc.returncode, 130, f"{behavior_name}: stderr={proc.stderr}")
                self.assertIsNotNone(matrix)
                self.assertEqual(matrix.get("status"), "INTERRUPTED_UI_UNVERIFIED")
                self.assertEqual(len(matrix["devices"]), 1)
                dev = matrix["devices"][0]
                self.assertEqual(dev["status"], "INTERRUPTED")
                self.assertEqual(dev.get("ownedSimulatorCleanup"), "FAIL")
                self.assertTrue(dev.get("ownedSimulatorCleanupError"))
                palette_collect = [e for e in events if e["kind"] == "run" and "collect-runtime27-palette-log.py" in " ".join(e["cmd"])]
                self.assertEqual(palette_collect, [], "Slow 60s palette log show must be skipped on interruption")

    def test_normal_path_cleanup_and_failure_continuation_remain_unchanged(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = _create_sandbox(Path(tmp), scenarios_mode="manifest")
            env = {"FAITHFUL_RUNTIME27_MANIFEST": str(root / "docs" / "hq-integration" / "runtime27" / "R27_CASES.json")}
            proc, events, matrix = self._run_driver(root, env, {})

            self.assertEqual(proc.returncode, 0, f"stderr={proc.stderr}")
            self.assertEqual([d["label"] for d in matrix["devices"]], ["11-window", "phone"])
            self.assertTrue(all(d["status"] == "EXECUTED_PASS" for d in matrix["devices"]))
            self.assertTrue(all(d["ownedSimulatorCleanup"] == "PASS" for d in matrix["devices"]))
            palette_collect = [e for e in events if e["kind"] == "run" and "collect-runtime27-palette-log.py" in " ".join(e["cmd"])]
            self.assertEqual(len(palette_collect), 1)
            self.assertEqual(palette_collect[0]["timeout"], 60)
            shutdowns = [e for e in events if e["kind"] == "run" and "shutdown-faithful-simulator.py" in " ".join(e["cmd"])]
            self.assertEqual([s["timeout"] for s in shutdowns], [300, 300])
            deletes = [e for e in events if e["kind"] == "run" and e["cmd"][:3] == ["xcrun", "simctl", "delete"]]
            self.assertEqual([d["timeout"] for d in deletes], [120, 120])

        with tempfile.TemporaryDirectory() as tmp:
            root = _create_sandbox(Path(tmp), scenarios_mode="manifest")
            env = {"FAITHFUL_RUNTIME27_MANIFEST": str(root / "docs" / "hq-integration" / "runtime27" / "R27_CASES.json")}
            proc, events, matrix = self._run_driver(root, env, {"xcodebuild_exit_code": 65, "fail_first_only": True})

            self.assertNotEqual(proc.returncode, 0)
            self.assertEqual([d["label"] for d in matrix["devices"]], ["11-window", "phone"],
                             "Non-interruption failure on first device must still run remaining devices")
            self.assertEqual(matrix["devices"][0]["status"], "FAIL")
            self.assertEqual(matrix["devices"][1]["status"], "EXECUTED_PASS")


class Runtime27SupervisorInterruptionTests(unittest.TestCase):
    def test_runtime27_stop_owned_process_group_and_interrupted_result_preserved(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = _create_sandbox(Path(tmp), scenarios_mode="manifest")
            driver = root / "_rt27_driver.py"
            driver.write_text(
                textwrap.dedent(
                    """\
                    import importlib.util
                    import json
                    import os
                    from pathlib import Path
                    import signal
                    import subprocess
                    import sys
                    import unittest.mock

                    ROOT = Path.cwd()
                    spec = importlib.util.spec_from_file_location("runtime27", ROOT / "Scripts" / "CI" / "runtime27.py")
                    rt = importlib.util.module_from_spec(spec)
                    spec.loader.exec_module(rt)

                    killpg_calls = []
                    def fake_killpg(pgid, sig):
                        killpg_calls.append((pgid, int(sig)))
                        if sig == 0:
                            # First poll after SIGINT hits PermissionError; still must send SIGKILL!
                            if len([c for c in killpg_calls if c[1] == 0]) == 1:
                                raise PermissionError("transient eperm")
                            if any(c[1] == int(getattr(signal, "SIGKILL", signal.SIGTERM)) for c in killpg_calls):
                                raise ProcessLookupError()

                    class FakeChild:
                        def __init__(self):
                            self.pid = 77777
                            self.returncode = None
                        def poll(self):
                            return self.returncode
                        def wait(self, timeout=None):
                            raise KeyboardInterrupt("External signal 15")

                    orig_platform = sys.platform
                    sys.platform = "darwin"
                    os.killpg = fake_killpg
                    os.environ["RUNTIME27_MODE"] = "ui"
                    os.environ["EXPECTED_CHECKOUT_SHA"] = "0" * 40

                    # Create dummy inputs required by runtime27 before matrix
                    for p in [
                        "Scripts/CI/hq-stage2-focused-apple.py",
                        "Scripts/CI/hq-stage2-focused-apple.inputs.json",
                        "Scripts/CI/runtime27-fixture-oracle.py",
                        "Scripts/CI/collect-runtime27-palette-log.py",
                        "Scripts/CI/runtime27-hid.py",
                        "Scripts/CI/runtime27-fixture-recovery.py",
                        "Scripts/CI/runtime27-url-delivery.py",
                        "Scripts/CI/shutdown-faithful-simulator.py",
                    ]:
                        target = ROOT / p
                        target.parent.mkdir(parents=True, exist_ok=True)
                        if not target.exists():
                            target.write_text("# stub\\n", encoding="utf-8")

                    palette_dir = ROOT / "Source/ChavrusaText/Dependencies/CommandPalette/Sources/CommandPalette"
                    palette_dir.mkdir(parents=True, exist_ok=True)
                    (palette_dir / "Dummy.swift").write_text("// stub\\n", encoding="utf-8")

                    sidebar_file = ROOT / "Source/ChavrusaText/ReaderHost/ReaderSidebarPager.swift"
                    sidebar_file.parent.mkdir(parents=True, exist_ok=True)
                    sidebar_file.write_text("#if canImport(SwiftUI)\\nprivate struct ReaderSidebarSplitConfiguration: {}\\n#endif\\n", encoding="utf-8")

                    pinned_test = ROOT / "Maktabah-iOSUITests/R27NativeInteractionAcceptanceTests.swift"
                    pinned_test.parent.mkdir(parents=True, exist_ok=True)
                    # Note: runtime27 checks exact sha256; test run_logged + collect_cases + main interruption directly!

                    def fake_collect_cases(report, contract):
                        raise KeyboardInterrupt("signal during collect_cases")

                    rt.OUT.mkdir(parents=True, exist_ok=True)
                    marker = None
                    try:
                        with unittest.mock.patch.object(rt.subprocess, "Popen", return_value=FakeChild()):
                            with unittest.mock.patch.object(rt, "collect_cases", side_effect=fake_collect_cases):
                                try:
                                    rt.run_logged(["python3", "Scripts/CI/run-faithful-ipad-matrix.py"], "native-matrix-driver.log", 10)
                                except KeyboardInterrupt:
                                    pass
                                # Test main's finally when collect_cases raises KeyboardInterrupt!
                                report = {"status": "INTERRUPTED_UI_UNVERIFIED", "mode": "ui"}
                                # Simulate main's finally behavior via direct call to write_interrupted_result or main
                    finally:
                        sys.platform = orig_platform

                    (ROOT / "_killpg_calls.json").write_text(json.dumps(killpg_calls), encoding="utf-8")
                    """
                ),
                encoding="utf-8",
            )
            proc = subprocess.run([sys.executable, str(driver)], cwd=root, capture_output=True, text=True, timeout=30)
            self.assertEqual(proc.returncode, 0, f"stderr={proc.stderr}")
            killpg_calls = json.loads((root / "_killpg_calls.json").read_text(encoding="utf-8"))
            self.assertTrue(all(pgid == 77777 for pgid, _ in killpg_calls))
            sigkill = int(getattr(signal, "SIGKILL", signal.SIGTERM))
            self.assertIn([77777, sigkill], killpg_calls,
                          "Transient PermissionError on os.killpg(pgid, 0) must not skip SIGKILL fallback")
            marker = json.loads((root / "build/artifacts/runtime27/native-matrix-driver.log.interrupted.json").read_text(encoding="utf-8"))
            self.assertEqual(marker["status"], "INTERRUPTED_CHILD_UNVERIFIED")
            self.assertEqual(marker["cleanup"]["owned_pgid"], 77777)
            self.assertEqual(marker["cleanup"]["group_state"], "GONE_CHECKED")
            self.assertEqual(marker["cleanup"]["off_group_simulator_agents"], "NOT_INDEPENDENTLY_VERIFIED")

    def test_runtime27_main_writes_result_json_even_if_collect_cases_interrupted(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = _create_sandbox(Path(tmp), scenarios_mode="manifest")
            driver = root / "_rt27_main_driver.py"
            driver.write_text(
                textwrap.dedent(
                    """\
                    import hashlib
                    import importlib.util
                    import json
                    import os
                    from pathlib import Path
                    import signal
                    import subprocess
                    import sys
                    import unittest.mock

                    ROOT = Path.cwd()
                    spec = importlib.util.spec_from_file_location("runtime27", ROOT / "Scripts" / "CI" / "runtime27.py")
                    rt = importlib.util.module_from_spec(spec)
                    spec.loader.exec_module(rt)

                    def fake_capture(cmd, name):
                        if cmd[:2] == ["git", "rev-parse"]:
                            return "0" * 40 + "\\n"
                        if cmd[:2] == ["xcodebuild", "-version"]:
                            return "Xcode 27.1\\n"
                        if cmd[:2] == ["xcrun", "swiftc"]:
                            return "Apple Swift 6.4\\n"
                        if "--show-sdk-version" in cmd:
                            return "27.1\\n"
                        if "--show-sdk-path" in cmd:
                            return "/fake/sdk\\n"
                        if "--schema" in cmd:
                            return "{}"
                        if "runtimes" in cmd:
                            return json.dumps({"runtimes": [{"isAvailable": True, "version": "27.2"}]})
                        return "{}"

                    for p in [
                        "Scripts/CI/hq-stage2-focused-apple.py",
                        "Scripts/CI/hq-stage2-focused-apple.inputs.json",
                        "Scripts/CI/runtime27-fixture-oracle.py",
                        "Scripts/CI/collect-runtime27-palette-log.py",
                        "Scripts/CI/runtime27-hid.py",
                        "Scripts/CI/runtime27-fixture-recovery.py",
                        "Scripts/CI/runtime27-url-delivery.py",
                        "Scripts/CI/shutdown-faithful-simulator.py",
                    ]:
                        target = ROOT / p
                        target.parent.mkdir(parents=True, exist_ok=True)
                        if not target.exists():
                            target.write_text("# stub\\n", encoding="utf-8")

                    (ROOT / "Source/ChavrusaText/Dependencies/CommandPalette/Sources/CommandPalette").mkdir(parents=True, exist_ok=True)
                    (ROOT / "Source/ChavrusaText/Dependencies/CommandPalette/Sources/CommandPalette/Dummy.swift").write_text("// stub\\n", encoding="utf-8")
                    sidebar = ROOT / "Source/ChavrusaText/ReaderHost/ReaderSidebarPager.swift"
                    sidebar.parent.mkdir(parents=True, exist_ok=True)
                    sidebar.write_text("#if canImport(SwiftUI)\\nprivate struct ReaderSidebarSplitConfiguration: {}\\n#endif\\n", encoding="utf-8")
                    (ROOT / "Maktabah-iOSUITests").mkdir(parents=True, exist_ok=True)

                    products = ROOT / "build/DerivedData/Build/Products/Debug-iphonesimulator"
                    for b, exe in [
                        (products / "Maktabah.app", "Maktabah"),
                        (products / "Maktabah-iOSUITests-Runner.app", "Runner"),
                        (products / "Maktabah-iOSUITests-Runner.app/PlugIns/Maktabah-iOSUITests.xctest", "UITest"),
                    ]:
                        b.mkdir(parents=True, exist_ok=True)
                        import plistlib
                        (b / "Info.plist").write_bytes(plistlib.dumps({"CFBundleExecutable": exe}))
                        (b / exe).write_bytes(b"stub")

                    sys.platform = "darwin"
                    os.environ["RUNTIME27_MODE"] = "ui"
                    os.environ["EXPECTED_CHECKOUT_SHA"] = "0" * 40

                    real_sha = hashlib.sha256
                    class PinnedHash:
                        def __init__(self, digest): self._d = digest
                        def hexdigest(self): return self._d
                    orig_path_read = Path.read_bytes
                    def fake_read_bytes(self):
                        if self.name == "R27NativeInteractionAcceptanceTests.swift":
                            return b"pinned"
                        return orig_path_read(self)

                    def fake_sha256(data=b""):
                        if data == b"pinned":
                            return PinnedHash("d4ff446db4acdbb61e0ad19c14696e5194bafbba239ef86876e85a2de30e70cc")
                        return real_sha(data)

                    def fake_run_logged(cmd, name, timeout):
                        if name == "native-matrix-driver.log":
                            signal.raise_signal(signal.SIGTERM)
                        return 0

                    with unittest.mock.patch.object(rt, "capture", side_effect=fake_capture), \\
                         unittest.mock.patch.object(rt, "run_logged", side_effect=fake_run_logged), \\
                         unittest.mock.patch.object(rt, "capture_palette_code_images", return_value={"images": []}), \\
                         unittest.mock.patch.object(rt, "collect_cases", side_effect=KeyboardInterrupt("late interrupt")), \\
                         unittest.mock.patch.object(rt.urllib.request, "urlopen", return_value=type("R", (), {"read": lambda self: b"skill"})()), \\
                         unittest.mock.patch.object(rt.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)), \\
                         unittest.mock.patch.object(rt.hashlib, "sha256", side_effect=fake_sha256), \\
                         unittest.mock.patch.object(Path, "read_bytes", fake_read_bytes):
                        (ROOT / "Maktabah-iOSUITests/R27NativeInteractionAcceptanceTests.swift").write_text("// stub", encoding="utf-8")
                        code = rt.main()
                    sys.exit(code)
                    """
                ),
                encoding="utf-8",
            )
            proc = subprocess.run([sys.executable, str(driver)], cwd=root, capture_output=True, text=True, timeout=30)
            self.assertEqual(proc.returncode, 130, f"stderr={proc.stderr}")
            result_path = root / "build/artifacts/runtime27/result.json"
            self.assertTrue(result_path.is_file(), "runtime27/result.json must be written even if collect_cases is interrupted")
            result = json.loads(result_path.read_text(encoding="utf-8"))
            self.assertEqual(result["status"], "INTERRUPTED_UI_UNVERIFIED")


if __name__ == "__main__":
    unittest.main(verbosity=2)

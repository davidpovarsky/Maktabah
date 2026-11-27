#!/usr/bin/env python3
"""Portable controls for the actual paired controller; all Apple/domain boundaries are explicit doubles.

These controls never execute xcodebuild, simctl, codesign, a real installation,
a native app, a real corpus or an account. Their results are SOURCE_ONLY.
"""
import argparse
import contextlib
import copy
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import traceback
import unittest.mock as mock
import uuid

parser = argparse.ArgumentParser()
parser.add_argument("--controller", type=Path, required=True)
parser.add_argument("--output", type=Path, required=True)
args = parser.parse_args()
spec = importlib.util.spec_from_file_location("paired_source_under_test", args.controller)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
checks = []


def check(name, action):
    try:
        action()
        checks.append({"name": name, "passed": True})
    except BaseException as error:
        checks.append({"name": name, "passed": False, "error": type(error).__name__ + ": " + str(error),
                       "traceback": traceback.format_exc()})


def rejected(action):
    try:
        action()
    except (RuntimeError, ValueError, KeyError, FileNotFoundError):
        return
    raise AssertionError("The actual controller admitted the invalid controlled input")


class Fixture:
    def __enter__(self):
        self.temp = tempfile.TemporaryDirectory(prefix="paired-source-control-")
        self.root = Path(self.temp.name).resolve()
        self.stack = contextlib.ExitStack()
        self.stack.enter_context(mock.patch.object(m, "ROOT", self.root))
        self.products = self.root / "build/DerivedData/Build/Products"
        self.app = self.products / "Debug-iphonesimulator/Maktabah.app"
        self.runner = self.products / "Debug-iphonesimulator/Maktabah-iOSUITests-Runner.app"
        self.bundle = self.runner / "PlugIns/Maktabah-iOSUITests.xctest"
        for p in (self.app, self.runner, self.bundle):
            p.mkdir(parents=True, exist_ok=True)
        self.images = {}
        for p in (self.app / "Maktabah", self.runner / "Maktabah-iOSUITests-Runner",
                  self.bundle / "Maktabah-iOSUITests"):
            p.write_bytes(b"CONTROLLED_NON_NATIVE_IMAGE_" + p.name.encode())
            self.images[str(p.relative_to(self.root))] = {"bytes": p.stat().st_size, "sha256": m.digest(p)}
        self.info = {"CFBundleIdentifier": m.BUNDLE, "CFBundleExecutable": "Maktabah",
                     "CFBundleDisplayName": "Controlled original app", "UIFileSharingEnabled": True,
                     "OtzariaDefaultDataProfile": "production"}
        (self.app / "Info.plist").write_bytes(plistlib.dumps(self.info))
        self.target = {"BlueprintName": "Maktabah-iOSUITests", "IsUITestBundle": True,
                       "TestHostPath": "__TESTROOT__/Debug-iphonesimulator/Maktabah-iOSUITests-Runner.app",
                       "TestBundlePath": "__TESTHOST__/PlugIns/Maktabah-iOSUITests.xctest",
                       "UITargetAppPath": "__TESTROOT__/Debug-iphonesimulator/Maktabah.app",
                       "DependentProductPaths": ["__TESTROOT__/Debug-iphonesimulator/Maktabah.app"],
                       "CommandLineArguments": []}
        self.test_run = self.products / "Maktabah.xctestrun"
        self.save_target()
        self.helper = self.root / "Scripts/CI/prepare-faithful-ipad-fixtures.py"
        self.helper.parent.mkdir(parents=True)
        self.helper.write_text("# CONTROLLED nonexecuted original-helper stand-in\n")
        self.build = self.root / "build/hq-stage2/result.json"
        self.build.parent.mkdir(parents=True)
        self.build.write_text(json.dumps({"status": "SIMULATOR_BUILD_FOR_REAL_UI_PASS",
                                         "simulator_embedded_data_profile": "production",
                                         "built_app_info_sha256": m.digest(self.app / "Info.plist")}))
        self.metadata = self.root / "official-control-metadata"
        self.metadata.mkdir()
        for name in ("v40_release.raw", "archive.manifest.json", "library_stats.json", "build_provenance.json"):
            (self.metadata / name).write_text('{"CONTROL_ONLY":true}\n')
        self.network_root = self.root / "private-network-control"
        self.network_root.mkdir(mode=0o700)
        self.pointer = self.network_root / "source-pointer.json"
        self.pointer.write_text('{"CONTROL_ONLY":true}\n')
        self.source = {"checkout_sha": "a" * 40, "application_source_sha": "b" * 40,
                       "application_trees": {"Source": "c" * 40}}
        self.trace = []

        def source():
            self.trace.append("original-local-source")
            return self.source

        def v40_source(*arguments, **keywords):
            self.trace.append("original-v40-source")
            assert arguments == (self.source["checkout_sha"],) and keywords == {"allow_build_projection": True}
            return {"CONTROL_ONLY": "immutable-original-inputs"}

        def qualified(app):
            self.trace.append("original-qualified-build")
            assert app == self.app
            if json.loads(self.build.read_bytes())["status"] != "SIMULATOR_BUILD_FOR_REAL_UI_PASS":
                raise RuntimeError("controlled original build gate failure")
            return {"build_receipt": m.witness(self.build), "complete_native_images": self.images}

        self.contracts = {"local": {"source_context": source},
                          "v40": {"source_context": v40_source, "qualified_build_context": qualified,
                                  "metadata_context": lambda: ({}, {}, {}, {}),
                                  "METADATA": self.metadata, "ARCHIVE": "archive",
                                  "WORK_BYTES": 24_000_000_000, "DEFAULT_OS_MARGIN_BYTES": 2_000_000_000},
                          "exchange": {"network_fixture": lambda: {
                              "root": str(self.network_root), "pointer_sha256": m.digest(self.pointer)}},
                          "containers": {}}
        self.inputs = {"schema": m.INPUT_SCHEMA, "source": self.source, "app": str(self.app),
                       "productFiles": [{"path": str(self.root / relative), **record}
                                        for relative, record in self.images.items()],
                       "buildReceipt": m.witness(self.build), "fixtureHelper": m.witness(self.helper),
                       "xctestrun": m.witness(self.test_run), "networkFixtureRoot": str(self.network_root),
                       "networkFixturePointer": m.witness(self.pointer),
                       "runtimeIdentifier": "com.apple.CoreSimulator.SimRuntime.iOS-27-0",
                       "runtimeVersion": "27.0", "reservedOtherBytes": 0}
        self.stack.enter_context(mock.patch.dict(os.environ, {
            "OTZARIA_NATIVE_SPACE_ARCHIVE_LEASE": "ordinary-ui-exclusive",
            "OTZARIA_ANYTYPE_NETWORK_FIXTURE_ROOT": str(self.network_root)}, clear=True))
        return self

    def save_target(self, *, v2=False):
        root = ({"TestConfigurations": [{"TestTargets": [self.target]}]} if v2
                else {"Maktabah-iOSUITests": self.target})
        self.test_run.write_bytes(plistlib.dumps(root))

    def __exit__(self, *exc):
        self.stack.close()
        self.temp.cleanup()


def products(mutator=None, expect_rejection=False):
    with Fixture() as f:
        values = copy.deepcopy(f.inputs["productFiles"])
        if mutator:
            mutator(f, values)
        action = lambda: m.validate_product_files(values, f.images)
        if expect_rejection:
            rejected(action)
        else:
            actual = action()
            assert len(actual) == 3


check("complete actual controlled file closure admitted", lambda: products())
check("empty caller product closure rejected", lambda: products(lambda f, v: v.clear(), True))
check("incomplete caller closure rejected", lambda: products(lambda f, v: v.pop(), True))
check("duplicate caller image rejected", lambda: products(lambda f, v: v.append(v[0]), True))
check("changed image bytes rejected", lambda: products(lambda f, v: Path(v[0]["path"]).write_bytes(b"CHANGED"), True))
check("arbitrary caller digest rejected", lambda: products(lambda f, v: v[0].update(sha256="f" * 64), True))
check("arbitrary caller size rejected", lambda: products(lambda f, v: v[0].update(bytes=1), True))


def xctest(mutator=None, *, reject=False, v2=False):
    with Fixture() as f:
        if mutator:
            mutator(f)
        f.save_target(v2=v2)
        action = lambda: m.bind_xctestrun(f.test_run, f.app)
        if reject:
            rejected(action)
        else:
            result = action()
            assert result["target_app"] == str(f.app) and result["test_bundle"] == str(f.bundle)


check("original v1 xctestrun paths bind app runner bundle", lambda: xctest())
check("original v2 xctestrun paths bind app runner bundle", lambda: xctest(v2=True))
check("wrong app product in xctestrun rejected",
      lambda: xctest(lambda f: f.target.update(UITargetAppPath=str(f.runner)), reject=True))
check("wrong runner product in xctestrun rejected",
      lambda: xctest(lambda f: f.target.update(TestHostPath=str(f.app)), reject=True))
check("wrong test bundle in xctestrun rejected",
      lambda: xctest(lambda f: f.target.update(TestBundlePath=str(f.app)), reject=True))
check("miniTest10 xctestrun environment rejected",
      lambda: xctest(lambda f: f.target.update(EnvironmentVariables={"OTZARIA_DATA_PROFILE": "miniTest10"}), reject=True))
check("smoke scenario xctestrun arguments rejected",
      lambda: xctest(lambda f: f.target.update(CommandLineArguments=["-smokeScenario", "readerDetail"]), reject=True))
check("test workspace xctestrun arguments rejected",
      lambda: xctest(lambda f: f.target.update(CommandLineArguments=["-studyWorkspaceTestingNamespace", "fake"]), reject=True))
check("non-UI test runner rejected",
      lambda: xctest(lambda f: f.target.update(IsUITestBundle=False), reject=True))


def admission(mutator=None, *, reject=False):
    with Fixture() as f:
        if mutator:
            mutator(f)
        with mock.patch.object(m, "run", return_value=""):
            action = lambda: m.admitted_context(f.inputs, f.contracts)
            if reject:
                rejected(action)
            else:
                result = action()
                assert result["source"] == f.source
                assert f.trace == ["original-local-source", "original-v40-source", "original-qualified-build"]


check("admission invokes original source and qualified build gates", lambda: admission())
check("unqualified original build receipt rejected",
      lambda: admission(lambda f: f.build.write_text('{"status":"NOT_BUILT"}'), reject=True))
check("old unbound input schema rejected",
      lambda: admission(lambda f: f.inputs.update(schema="otzaria.original.two-full-apps.inputs.v1"), reject=True))
check("false caller source claim rejected",
      lambda: admission(lambda f: f.inputs.update(source={"checkout_sha": "d" * 40}), reject=True))
check("empty images cannot pass composed admission",
      lambda: admission(lambda f: f.inputs.update(productFiles=[]), reject=True))
check("built mini profile rejected",
      lambda: admission(lambda f: (f.info.update(OtzariaDefaultDataProfile="miniTest10"),
                                  (f.app / "Info.plist").write_bytes(plistlib.dumps(f.info))), reject=True))
check("missing exclusive original Space lease rejected",
      lambda: admission(lambda f: os.environ.pop("OTZARIA_NATIVE_SPACE_ARCHIVE_LEASE"), reject=True))
check("inherited raw database override rejected",
      lambda: admission(lambda f: os.environ.update(OTZARIA_PRODUCTION_DB_PATH="/fake.db"), reject=True))
check("inherited fake viewport rejected",
      lambda: admission(lambda f: os.environ.update(TEST_RUNNER_FAITHFUL_VIEWPORT_DIRECTORY="/fake"), reject=True))
check("foreign original account fixture root rejected",
      lambda: admission(lambda f: os.environ.update(OTZARIA_ANYTYPE_NETWORK_FIXTURE_ROOT="/other"), reject=True))


def installation(low_space=False):
    with Fixture() as f:
        directory = f.root / "install-control"
        directory.mkdir()
        calls = []

        def child(command, **keywords):
            calls.append((command, keywords))
            return subprocess.CompletedProcess(command, 0)
        with mock.patch.object(m.shutil, "disk_usage", return_value=shutil._ntuple_diskusage(
                40_000_000_000, 0, 100 if low_space else 30_000_000_000)), \
                mock.patch.object(m.subprocess, "run", side_effect=child), \
                mock.patch.object(m, "production_observation", return_value={"SOURCE_ONLY_CONTROL": True}):
            action = lambda: m.install_production("CONTROL", directory, f.helper, f.inputs, f.contracts)
            if low_space:
                rejected(action)
                assert not calls
            else:
                action()
                command, keywords = calls[0]
                assert command[command.index("--profile") + 1] == "production"
                assert command[command.index("--release-id") + 1] == "455390662"
                assert keywords["timeout"] >= 3600 + 90 + 60
                assert command[1] == str(f.helper) and keywords["cwd"] == directory


check("original production installer receives full profile release and time budget", lambda: installation())
check("original full-v40 disk reserve blocks before installer", lambda: installation(True))


class Simulators:
    def __init__(self, home, *, fault=None):
        self.home, self.fault = home, fault
        self.ids = [str(uuid.uuid4()).upper(), str(uuid.uuid4()).upper()]
        self.present, self.calls = set(self.ids), []
        for udid in self.ids:
            self.path(udid).mkdir(parents=True)

    def path(self, udid):
        return self.home / "Library/Developer/CoreSimulator/Devices" / udid

    def child(self, command, **keywords):
        operation = command[2]
        if operation == "list":
            payload = {"devices": {"CONTROL": [{"udid": x} for x in sorted(self.present)]}}
            return subprocess.CompletedProcess(command, 0, json.dumps(payload).encode(), b"")
        udid = command[3]
        self.calls.append((operation, udid))
        if udid == self.ids[0] and self.fault == operation + "-timeout":
            raise subprocess.TimeoutExpired(command, keywords["timeout"], output=b"controlled partial output")
        if udid == self.ids[0] and self.fault == operation + "-failure":
            return subprocess.CompletedProcess(command, 1, b"", b"controlled failure")
        if operation == "delete" and not (udid == self.ids[0] and self.fault == "delete-remains"):
            self.present.discard(udid)
            shutil.rmtree(self.path(udid))
        return subprocess.CompletedProcess(command, 0, b"", b"")


def cleanup(fault=None, protected=False):
    with Fixture() as f:
        sims = Simulators(f.root / "home", fault=fault)
        with mock.patch.object(Path, "home", return_value=sims.home), \
                mock.patch.object(m.subprocess, "run", side_effect=sims.child):
            actual = m.cleanup_owned([m.PROTECTED, sims.ids[1]] if protected else sims.ids)
        assert ("delete", sims.ids[1]) in sims.calls, "Second owned device was skipped"
        assert actual["passed"] is (fault is None and not protected)
        if protected:
            assert not any(udid == m.PROTECTED for operation, udid in sims.calls)
        if fault:
            assert len(actual["devices"]) == 2


check("both owned devices require observed complete deletion", lambda: cleanup())
check("first shutdown timeout still attempts deletion and second device", lambda: cleanup("shutdown-timeout"))
check("first delete timeout does not skip the second device", lambda: cleanup("delete-timeout"))
check("nonzero delete is not cleanup success", lambda: cleanup("delete-failure"))
check("delete exit zero with device still present is rejected", lambda: cleanup("delete-remains"))
check("protected device never receives shutdown or delete", lambda: cleanup(protected=True))


def primary_failure():
    with Fixture() as f:
        sims = Simulators(f.root / "home", fault="delete-timeout")
        out = f.root / "private-results"
        inputs_path = f.root / "inputs.json"
        inputs_path.write_text(json.dumps(f.inputs))
        directory_by_id = {udid: sims.path(udid) / "data/Containers/Data/Application" / str(uuid.uuid4()).upper()
                           for udid in sims.ids}
        for path in directory_by_id.values():
            path.mkdir(parents=True)
        created, installs = [], []

        def native(*command, **keywords):
            if command[:3] == ("xcrun", "simctl", "list"):
                if command[3] == "devicetypes":
                    return json.dumps({"devicetypes": [{"name": "iPad Pro 11-inch (M5)", "identifier": "CONTROL_DEVICE"}]})
                return json.dumps({"runtimes": [{"isAvailable": True, "version": "27.0",
                    "identifier": f.inputs["runtimeIdentifier"], "supportedDeviceTypes": [{"identifier": "CONTROL_DEVICE"}]}]})
            if command[:2] == ("xcrun", "--sdk"):
                return "27.0"
            if command[:3] == ("xcrun", "simctl", "create"):
                udid = sims.ids[len(created)]
                created.append(udid)
                return udid
            return ""

        production = {"SOURCE_ONLY_CONTROL": True, "data_container": str(directory_by_id[sims.ids[0]])}

        def install(udid, directory, *unused):
            installs.append(udid)
            if len(installs) == 2:
                raise ValueError("controlled second production installation failure")
            path = directory / "production-receipt.json"
            path.write_text(json.dumps(production))
            return production, m.witness(path)

        original_run = m.run

        def native_or_cleanup(*command, **keywords):
            if command[:4] == ("xcrun", "simctl", "list", "devices"):
                return original_run(*command, **keywords)
            return native(*command, **keywords)

        with mock.patch.object(m, "PRIVATE_BUILD_ROOT", f.root), \
                mock.patch.object(m.sys, "platform", "darwin"), \
                mock.patch.object(m.sys, "argv", ["controlled", "--inputs", str(inputs_path), "--out", str(out)]), \
                mock.patch.object(m, "original_contracts", return_value=f.contracts), \
                mock.patch.object(m, "admitted_context", return_value={"SOURCE_ONLY_CONTROL": True}), \
                mock.patch.object(m, "owned_container", side_effect=lambda udid, _: directory_by_id[udid]), \
                mock.patch.object(m, "installed_images", return_value={"SOURCE_ONLY_CONTROL": True}), \
                mock.patch.object(m, "production_observation", return_value=production), \
                mock.patch.object(m, "install_production", side_effect=install), \
                mock.patch.object(m, "run", side_effect=native_or_cleanup), \
                mock.patch.object(m.subprocess, "run", side_effect=sims.child), \
                mock.patch.object(Path, "home", return_value=sims.home), \
                contextlib.redirect_stdout(io.StringIO()):
            code = m.main()
        result = json.loads((out / "result.json").read_bytes())
        assert code == 1 and result["status"] == "FAILED"
        assert result["primaryErrorType"] == "ValueError"
        assert len(result["ownedSimulatorCleanup"]["devices"]) == 2
        assert ("delete", sims.ids[1]) in sims.calls
        assert result["ownedSimulatorCleanup"]["passed"] is False
        assert (out / "primary-failure-private.log").is_file()


check("actual main preserves primary installation failure and cleans both despite timeout", primary_failure)
report = {"status": "SOURCE_CONTROLS_PASS" if all(x["passed"] for x in checks) else "SOURCE_CONTROLS_FAIL",
          "scope": "Actual controller functions and main; explicit Apple/domain/installation doubles only",
          "controller": str(args.controller.resolve()),
          "controllerSHA256": hashlib.sha256(args.controller.read_bytes()).hexdigest(),
          "controlSourceSHA256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
          "passed": sum(x["passed"] for x in checks), "failed": sum(not x["passed"] for x in checks),
          "nativeRuns": 0, "realInstallations": 0, "accountAccess": False, "checks": checks}
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps({key: value for key, value in report.items() if key != "checks"}))
raise SystemExit(0 if report["failed"] == 0 else 1)

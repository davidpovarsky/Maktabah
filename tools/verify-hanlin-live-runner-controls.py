"""Disposable CI safety controls only. No credentials, provider, Xcode or Native execution."""
import ast
import base64
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import subprocess

HERE = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("live_control_subject", HERE / "Scripts/CI/runtime27-hanlin-live.py")
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
rows = []
FAKE = "PUBLIC_TEST_LITERAL_NOT_A_CREDENTIAL_0123456789"
UDID = "00112233-4455-6677-8899-AABBCCDDEEFF"
os.environ["GITHUB_RUN_ID"] = "disposable-control"
os.environ["GITHUB_RUN_ATTEMPT"] = "1"


def passed(name):
    rows.append({"control": name, "status": "PASS"})


def rejected(call):
    try:
        call()
    except ValueError:
        return
    raise AssertionError("Expected bounded rejection")


def fresh(directory):
    m.ROOT = Path(directory)
    m.WORK = m.ROOT / "build/hanlin-live-private"
    m.OUT = m.ROOT / "build/hanlin-live-evidence"
    m.WORK.mkdir(parents=True)
    m.OUT.mkdir()


live = m.LiveAcceptance(FAKE)
rejected(lambda: live.scan(FAKE.encode()))
passed("raw credential admission rejected")
rejected(lambda: live.scan(base64.b64encode(FAKE.encode())))
passed("encoded credential admission rejected")
assert FAKE not in live.redact_evidence("header: " + FAKE)
passed("stdout redacted before write")
rejected(lambda: live.validate_selection(False, None, ["Other/testCase"]))
rejected(lambda: live.validate_selection(False, {}, [m.SELECTOR]))
passed("live input cannot join standard or Release selection")

with tempfile.TemporaryDirectory() as temporary:
    fresh(temporary)
    original = m.ROOT / "build/artifacts"
    original.mkdir()
    (original / "original.bin").write_bytes(bytes(range(256)))
    before = m.evidence_identity(original)
    m.isolate_artifacts()
    (original / "new-live.json").write_text("{}")
    m.restore_artifacts()
    assert m.evidence_identity(original) == before
    assert (m.WORK / "artifacts/new-live.json").read_text() == "{}"
    m.restore_artifacts()
    assert m.evidence_identity(original) == before
    passed("original evidence bytes and directory restored idempotently")

with tempfile.TemporaryDirectory() as temporary:
    fresh(temporary)
    original = m.ROOT / "build/artifacts"
    original.mkdir()
    (original / "original.bin").write_bytes(b"preserve")
    m.write(m.WORK / "artifact-isolation.json", {"run_id": os.environ["GITHUB_RUN_ID"],
        "run_attempt": "1", "had_prior": True, "prior_identity": m.evidence_identity(original)})
    m.restore_artifacts()
    assert (original / "original.bin").read_bytes() == b"preserve"
    assert not (m.WORK / "artifacts").exists()
    passed("interruption before rename preserves original directory")

with tempfile.TemporaryDirectory() as temporary:
    fresh(temporary)
    original = m.ROOT / "build/artifacts"
    original.mkdir()
    (original / "original.bin").write_bytes(b"preserve")
    m.isolate_artifacts()
    (m.WORK / "prior-artifacts/original.bin").write_bytes(b"altered")
    rejected(m.restore_artifacts)
    assert (original / "original.bin").read_bytes() == b"altered"
    passed("changed original evidence rejects restoration acceptance")

original_owned = m.owned_application_root
with tempfile.TemporaryDirectory() as temporary:
    fresh(temporary)
    root = m.ROOT / "Devices" / UDID / "data/Containers/Data/Application"
    root.mkdir(parents=True)
    m.owned_application_root = lambda value: root if value == UDID else (_ for _ in ()).throw(ValueError("wrong device"))
    private = root / "A" / m.PRIVATE_RELATIVE
    private.parent.mkdir(parents=True)
    private.write_text(FAKE)
    private.chmod(0o600)
    live = m.LiveAcceptance(FAKE)
    live.udid, live.staged = UDID, True
    live.cleanup(UDID)
    assert live.removed and not live.consumed and not private.exists()
    passed("unconsumed private input is removed without claiming consumption")
    live.cleanup(UDID)
    assert not live.consumed
    passed("second cleanup preserves original unconsumed outcome")
    private.write_text(FAKE)
    rejected(lambda: live.cleanup(UDID))
    private.unlink()
    passed("reappearing private input rejects acceptance")
    consumed = m.LiveAcceptance(FAKE)
    consumed.udid, consumed.staged = UDID, True
    consumed.cleanup(UDID)
    assert consumed.consumed and consumed.removed
    passed("consumed private input verified on still-owned device")
    secret_source = m.WORK / "unsafe.json"
    secret_source.write_text(FAKE)
    rejected(lambda: live.admit(secret_source, "unsafe.json"))
    assert not (m.OUT / "unsafe.json").exists()
    passed("unsafe source never enters upload directory")
    safe_source = m.WORK / "safe.json"
    safe_source.write_text("{}")
    link = m.WORK / "link.json"
    link.symlink_to(safe_source)
    rejected(lambda: live.admit(link, "link.json"))
    passed("symlink evidence rejected")
m.owned_application_root = original_owned

original_cleanup, original_restore = m.cleanup_owned_device, m.restore_artifacts
calls = []
m.cleanup_owned_device = lambda: calls.append("owned")
def fail_restore():
    calls.append("restore")
    raise ValueError("controlled restoration failure")
m.restore_artifacts = fail_restore
assert m.emergency_cleanup() == 1 and calls == ["owned", "restore"]
passed("restoration failure cannot skip private/device cleanup")
m.cleanup_owned_device, m.restore_artifacts = original_cleanup, original_restore

with tempfile.TemporaryDirectory() as temporary:
    fresh(temporary)
    root = m.ROOT / "Devices" / UDID / "data/Containers/Data/Application"
    root.mkdir(parents=True)
    m.owned_application_root = lambda value: root
    m.write(m.WORK / "ownership.json", {"udid": UDID, "run_id": os.environ["GITHUB_RUN_ID"], "run_attempt": "1"})
    original_clean, original_run = m.clean_private_input, m.subprocess.run
    calls = []
    def fail_private(_):
        calls.append("private")
        raise ValueError("controlled private removal failure")
    def fake_run(command, **kwargs):
        calls.append("delete" if "delete" in command else "shutdown")
    m.clean_private_input, m.subprocess.run = fail_private, fake_run
    rejected(m.cleanup_owned_device)
    assert calls == ["private", "shutdown", "delete"]
    passed("private removal failure still attempts owned shutdown and deletion")
    calls.clear()
    m.write(m.WORK / "ownership.json", {"udid": UDID, "run_id": "different", "run_attempt": "1"})
    rejected(m.cleanup_owned_device)
    assert not calls
    passed("wrong workflow attempt cannot remove a device")
    m.clean_private_input, m.subprocess.run = original_clean, original_run
m.owned_application_root = original_owned


class StandardProjection(ast.NodeTransformer):
    def visit_Compare(self, node):
        node = self.generic_visit(node)
        if (isinstance(node.left, ast.Name) and node.left.id == "live_provider" and len(node.ops) == 1
                and isinstance(node.comparators[0], ast.Constant) and node.comparators[0].value is None):
            if isinstance(node.ops[0], ast.Is):
                return ast.Constant(True)
            if isinstance(node.ops[0], ast.IsNot):
                return ast.Constant(False)
        return node

    def visit_BoolOp(self, node):
        node = self.generic_visit(node)
        if isinstance(node.op, ast.And):
            if any(isinstance(v, ast.Constant) and v.value is False for v in node.values):
                return ast.Constant(False)
            node.values = [v for v in node.values if not (isinstance(v, ast.Constant) and v.value is True)]
            if len(node.values) == 1:
                return node.values[0]
        return node

    def visit_If(self, node):
        node = self.generic_visit(node)
        if isinstance(node.test, ast.Constant) and type(node.test.value) is bool:
            return node.body if node.test.value else node.orelse
        return node

    def visit_FunctionDef(self, node):
        node = self.generic_visit(node)
        if node.name == "main":
            assert len(node.args.args) == 1 and node.args.args[0].arg == "live_provider"
            node.args.args = []
            node.args.defaults = []
        return node


old = ast.parse(subprocess.check_output(["git", "show", "04bb2a540e9843e80e26b50f4fcd37b73481f0a1:Scripts/CI/run-faithful-ipad-matrix.py"], cwd=HERE).decode("utf-8"))
new = ast.parse((HERE / "Scripts/CI/run-faithful-ipad-matrix.py").read_text())
assert ast.dump(old) == ast.dump(StandardProjection().visit(new))
passed("standard matrix AST is identical when live hook is unselected")

import yaml
workflow = yaml.load((HERE / ".github/workflows/otzaria-hanlin-live-native.yml").read_text(), Loader=yaml.BaseLoader)
steps = workflow["jobs"]["live-native"]["steps"]
cache_save = next(i for i, step in enumerate(steps) if step.get("uses") == "actions/cache/save@v4")
live_step = next(i for i, step in enumerate(steps) if step.get("id") == "live_case")
assert cache_save < live_step
assert [i for i, step in enumerate(steps) if "OTZARIA_HANLIN_LIVE_API_KEY" in step.get("env", {})] == [live_step]
assert [step["with"]["path"] for step in steps if step.get("uses") == "actions/upload-artifact@v4"] == ["build/hanlin-live-evidence/"]
passed("cache precedes secret delivery and upload is allowlisted only")

report = {"status": "DISPOSABLE_CONTROLS_PASS", "controls": rows, "controls_passed": len(rows),
          "native_tests_executed": 0, "provider_requests": 0, "real_credentials_read": False}
(HERE / "docs/hq-integration/completion-20261121/hanlin-live-ci/LIVE_RUNNER_CONTROLS.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps({key: value for key, value in report.items() if key != "controls"}))

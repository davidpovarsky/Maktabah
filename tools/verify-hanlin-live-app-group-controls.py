"""Disposable filesystem/CLI-boundary controls; no Simulator, provider or credential."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("live_group_subject", ROOT / "Scripts/CI/runtime27-hanlin-live.py")
subject = importlib.util.module_from_spec(spec)
spec.loader.exec_module(subject)
UDID = "00112233-4455-6677-8899-AABBCCDDEEFF"
OTHER_UDID = "10112233-4455-6677-8899-AABBCCDDEEFF"
PAYLOAD = b"PUBLIC_DISPOSABLE_FIXTURE_BYTES_NOT_A_REAL_DATABASE"
SHA = hashlib.sha256(PAYLOAD).hexdigest()
rows = []


def rejected(operation):
    try:
        operation()
    except (ValueError, FileNotFoundError):
        return
    raise AssertionError("Expected ownership/hash rejection")


def passed(name):
    rows.append({"control": name, "status": "PASS"})


with tempfile.TemporaryDirectory(prefix="hanlin-shared-fixture-") as temporary:
    root = Path(temporary).resolve()
    application = root / "Devices" / UDID / "data/Containers/Data/Application"
    application.mkdir(parents=True)
    groups = application.parents[1] / "Shared/AppGroup"
    groups.mkdir(parents=True)
    original_root = subject.owned_application_root
    original_resolver = subject.subprocess.check_output
    actual_group = groups / "FIRST-GROUP"
    actual_group.mkdir()
    fixture = actual_group / subject.FIXTURE_RELATIVE
    fixture.parent.mkdir(parents=True)
    fixture.write_bytes(PAYLOAD)
    resolver_output = str(actual_group) + "\n"
    calls = []

    def owned(value):
        if value != UDID:
            raise ValueError("Not the owned disposable device")
        return application

    def resolve(arguments, *, text, timeout):
        assert arguments == ["xcrun", "simctl", "get_app_container", UDID,
                             "com.davidpovarsky.chavrusatext", "group.com.davidpovarsky.itorah"]
        assert text is True and timeout == 45
        calls.append(arguments)
        return resolver_output

    subject.owned_application_root = owned
    subject.subprocess.check_output = resolve
    try:
        database, group = subject.owned_fixture_database(UDID, SHA, str(fixture))
        assert database == fixture and group == actual_group and not database.is_relative_to(application)
        passed("real layout: installed App Group fixture is distinct from private provider container")

        sibling = groups / "ANOTHER-APPLICATION-GROUP" / subject.FIXTURE_RELATIVE
        sibling.parent.mkdir(parents=True)
        sibling.write_bytes(PAYLOAD)
        rejected(lambda: subject.owned_fixture_database(UDID, SHA, str(sibling)))
        passed("same-hash sibling group cannot replace the installed application's resolved group")

        other_group = root / "Devices" / OTHER_UDID / "data/Containers/Shared/AppGroup/FOREIGN"
        other_group.mkdir(parents=True)
        resolver_output = str(other_group)
        rejected(lambda: subject.owned_fixture_database(UDID, SHA))
        resolver_output = str(actual_group)
        passed("another Simulator is rejected even if the CLI boundary returns its path")

        private_fixture = application / "PRIVATE" / subject.FIXTURE_RELATIVE
        private_fixture.parent.mkdir(parents=True)
        private_fixture.write_bytes(PAYLOAD)
        rejected(lambda: subject.owned_fixture_database(UDID, SHA, str(private_fixture)))
        passed("private-container copy cannot substitute for canonical shared fixture")

        fixture.write_bytes(PAYLOAD + b"changed")
        rejected(lambda: subject.owned_fixture_database(UDID, SHA))
        fixture.write_bytes(PAYLOAD)
        passed("same-path database mutation fails original SHA verification")

        alias = actual_group / "alias.db"
        alias.symlink_to(fixture)
        rejected(lambda: subject.owned_fixture_database(UDID, SHA, str(alias)))
        passed("reported database symlink is rejected")

        fixture.unlink()
        fixture.symlink_to(sibling)
        rejected(lambda: subject.owned_fixture_database(UDID, SHA))
        fixture.unlink()
        fixture.write_bytes(PAYLOAD)
        passed("canonical leaf redirection is rejected even with identical bytes")

        for invalid in ["", str(actual_group) + "\n" + str(sibling.parent), "relative/group"]:
            resolver_output = invalid
            rejected(lambda: subject.owned_fixture_database(UDID, SHA))
        resolver_output = str(actual_group)
        passed("empty multiple and relative CLI outputs fail before private-input staging")

        relocated = groups / "AFTER-XCTEST-RELOCATION"
        relocated_fixture = relocated / subject.FIXTURE_RELATIVE
        relocated_fixture.parent.mkdir(parents=True)
        relocated_fixture.write_bytes(PAYLOAD)
        resolver_output = str(relocated)
        after, after_group = subject.owned_fixture_database(UDID, SHA)
        assert after == relocated_fixture and after_group == relocated and len(calls) > 1
        assert fixture.read_bytes() == PAYLOAD and private_fixture.read_bytes() == PAYLOAD
        passed("post-test verification resolves current exact app group without copying or deleting either fixture")
    finally:
        subject.owned_application_root = original_root
        subject.subprocess.check_output = original_resolver

print(json.dumps({"status": "PASS_DISPOSABLE_APP_GROUP_CONTROLS", "executed": len(rows),
    "passed": len(rows), "controls": rows, "real_simctl": "NOT_RUN", "native_fixture": "NOT_RUN",
    "provider": "NOT_RUN", "credential_access": False}, indent=2))

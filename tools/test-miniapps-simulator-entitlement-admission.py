#!/usr/bin/env python3
"""Check the new Simulator entitlement adapter only; no Apple/UI cases execute."""
import importlib.util
import json
from pathlib import Path
import plistlib
import struct
import subprocess
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("existing_container_fixtures",
    ROOT / "tools/test-miniapps-simulator-containers.py")
fixtures = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixtures)
resolver = fixtures.resolver


class SimulatorEntitlementAdmissionTests(unittest.TestCase):
    def setUp(self):
        # Reuse fixture setup without loading/rerunning its eight accepted tests.
        self.fixture = fixtures.NativeContainerAdmissionTests()
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)
        groups = ["group.com.davidpovarsky.chavrusatext",
                  "group.com.davidpovarsky.itorah", "group.com.itorah.shared"]
        self.entitlements = {"application-identifier": "NA6HPWARQ2." + resolver.CONSUMER,
                             "com.apple.security.application-groups": groups}
        payload = plistlib.dumps(self.entitlements)
        command_size = 72 + 80
        offset = 32 + command_size
        size = offset + len(payload)
        image = struct.pack("<8I", 0xFEEDFACF, 0x0100000C, 0, 2, 1, command_size, 0, 0)
        image += struct.pack("<II16sQQQQIIII", 0x19, command_size, b"__TEXT",
                             0, size, 0, size, 7, 5, 1, 0)
        image += struct.pack("<16s16sQQIIIIIIII", b"__entitlements", b"__TEXT",
                             0, len(payload), offset, 0, 0, 0, 0, 0, 0, 0)
        image += payload
        for app in (self.fixture.source, self.fixture.app):
            (app / "Maktabah").write_bytes(image)

    def test_original_image_section_and_existing_os_group_are_both_required(self):
        before = {str(path.relative_to(self.fixture.data)) for path in self.fixture.data.rglob("*")}
        with mock.patch.object(resolver.subprocess, "check_output", side_effect=self.fixture.native_timeout), \
                mock.patch.object(resolver.subprocess, "run",
                                  return_value=subprocess.CompletedProcess(["codesign"], 0, b"", b"")) as signature:
            path = resolver.resolve_container(self.fixture.udid, resolver.CONSUMER,
                "group.com.itorah.shared", source_app=self.fixture.source)
        self.assertEqual(path, self.fixture.group)
        self.assertIn("--verify", signature.call_args.args[0])
        self.assertEqual(before, {str(path.relative_to(self.fixture.data)) for path in self.fixture.data.rglob("*")})
        rows = [json.loads(line) for line in resolver.AUDIT.read_text().splitlines()]
        self.assertEqual(rows[0]["status"], "NATIVE_QUERY_TIMEOUT")
        proof = next(row for row in rows if row["status"] == "ACTUAL_SIMULATOR_ENTITLEMENTS_VERIFIED")
        self.assertEqual(proof["simulator_entitlements"]["source"], "__TEXT,__entitlements")
        self.assertEqual(proof["simulator_entitlements"]["entitlements"], self.entitlements)
        self.assertEqual(proof["simulator_entitlements"]["executable_sha256"],
                         resolver.digest(self.fixture.app / "Maktabah"))
        self.assertEqual(proof["physical_signing_status"], "NOT_QUALIFIED_BY_SIMULATOR")
        self.assertEqual(rows[-1]["status"], "ACTUAL_MCM_IDENTITY_RESOLVED")
        self.assertEqual(rows[-1]["native_ui_acceptance"], "STILL_REQUIRED")

    def test_valid_embedded_groups_do_not_override_signature_failure(self):
        failure = subprocess.CalledProcessError(1, ["codesign", "--verify", "--strict"])
        with mock.patch.object(resolver.subprocess, "check_output", side_effect=self.fixture.native_timeout), \
                mock.patch.object(resolver.subprocess, "run", side_effect=failure):
            with self.assertRaises(subprocess.CalledProcessError):
                resolver.resolve_container(self.fixture.udid, resolver.CONSUMER,
                    "group.com.itorah.shared", source_app=self.fixture.source)
        rows = [json.loads(line) for line in resolver.AUDIT.read_text().splitlines()]
        self.assertEqual(rows[-1]["status"], "METADATA_IDENTITY_REJECTED")
        self.assertFalse(any(row["status"] == "ACTUAL_MCM_IDENTITY_RESOLVED" for row in rows))


if __name__ == "__main__":
    unittest.main(verbosity=2)

"""New journal vocabulary/privacy controls only; no native/provider execution."""
import ast
import copy
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[3]
BASE = "1969b2065469b55e38e42cbb838a469ffa6a80f7"
DRIVER_PATH = "Scripts/CI/runtime27-hanlin-live.py"
SESSION_PATH = "Source/ChavrusaText/HanlinHostAdapter/OtzariaHanlinChatSession.swift"
spec = importlib.util.spec_from_file_location("hanlin_stream_journal_candidate", ROOT / DRIVER_PATH)
driver = importlib.util.module_from_spec(spec)
spec.loader.exec_module(driver)
swift = (ROOT / SESSION_PATH).read_text()
old_driver = subprocess.check_output(["git", "show", BASE + ":" + DRIVER_PATH], cwd=ROOT).decode()
old_swift = subprocess.check_output(["git", "show", BASE + ":" + SESSION_PATH], cwd=ROOT).decode()
VOCABULARY = {"CONNECTION_DIAGNOSTIC_STAGES", "CONNECTION_DIAGNOSTIC_REASONS", "CONNECTION_DIAGNOSTIC_FLAGS"}

def swift_cases(source, name):
    body = re.search(r"enum " + name + r": String \{(.*?)\n    \}", source, re.S).group(1)
    return {part.strip() for line in body.splitlines() if line.strip().startswith("case ")
            for part in line.strip()[5:].split(",")}

def payload(events):
    return {"schemaVersion": 1, "overflow": False, "events": [
        {"sequence": 1, "stage": "inputConsumed", "reason": "none", "flags": {}}
    ] + [{"sequence": index, **event} for index, event in enumerate(events, 2)]}

def raw(value):
    return json.dumps(value, separators=(",", ":")).encode()

class StreamJournalSchemaTests(unittest.TestCase):
    def test_01_new_vocabularies_match_swift_and_preserve_original_values(self):
        additions = {}
        for name, key in [("Stage", "STAGES"), ("Reason", "REASONS"), ("Flag", "FLAGS")]:
            current = swift_cases(swift, name)
            prior = swift_cases(old_swift, name)
            self.assertEqual(current, getattr(driver, "CONNECTION_DIAGNOSTIC_" + key))
            self.assertTrue(prior <= current)
            additions[name] = len(current - prior)
        self.assertEqual(additions, {"Stage": 19, "Reason": 15, "Flag": 7})

    def test_02_all_new_stage_reason_and_boolean_values_are_accepted(self):
        stages = sorted(swift_cases(swift, "Stage") - swift_cases(old_swift, "Stage"))
        reasons = sorted(swift_cases(swift, "Reason") - swift_cases(old_swift, "Reason"))
        flags = sorted(swift_cases(swift, "Flag") - swift_cases(old_swift, "Flag"))
        events = [{"stage": stage, "reason": reasons[index % len(reasons)],
                   "flags": {flag: (index + number) % 2 == 0 for number, flag in enumerate(flags)}}
                  for index, stage in enumerate(stages)]
        expected = payload(events)
        self.assertEqual(driver.validate_connection_diagnostic(raw(expected)), expected)

    def test_03_new_flags_cannot_carry_strings_or_numeric_identifiers(self):
        flags = swift_cases(swift, "Flag") - swift_cases(old_swift, "Flag")
        for flag in sorted(flags):
            for forbidden in ["SYNTHETIC_PRIVATE_VALUE_NEVER_ACCEPT", 1]:
                with self.subTest(flag=flag, value_kind=type(forbidden).__name__):
                    value = payload([{"stage": "hostResultObserved", "reason": "none", "flags": {flag: forbidden}}])
                    with self.assertRaises(ValueError):
                        driver.validate_connection_diagnostic(raw(value))

    def test_04_original_collector_and_swift_journal_guards_are_unchanged(self):
        # A reviewed immutable source rebinding is metadata. Verify it against
        # the real build input and all four original application/test trees
        # before excluding only that constant from the collector-code check.
        inputs = json.loads((ROOT / "Scripts/CI/hq-stage2-focused-apple.inputs.json").read_text())
        self.assertRegex(driver.REVIEWED_SOURCE, r"\A[0-9a-f]{40}\Z")
        self.assertEqual(driver.REVIEWED_SOURCE, inputs["application_source_sha"])
        for path in ["Source", "Vendor", "Maktabah.xcodeproj", "Maktabah-iOSUITests"]:
            with self.subTest(reviewed_tree=path):
                reviewed = subprocess.check_output(
                    ["git", "rev-parse", driver.REVIEWED_SOURCE + ":" + path], cwd=ROOT)
                current = subprocess.check_output(["git", "rev-parse", "HEAD:" + path], cwd=ROOT)
                self.assertEqual(reviewed, current)
        def normalized_driver(source):
            tree = ast.parse(source)
            tree.body = [node for node in tree.body if not (
                isinstance(node, ast.Assign) and len(node.targets) == 1
                and isinstance(node.targets[0], ast.Name)
                and node.targets[0].id in VOCABULARY | {"REVIEWED_SOURCE"})]
            return ast.dump(tree, include_attributes=False)
        self.assertEqual(normalized_driver(old_driver), normalized_driver((ROOT / DRIVER_PATH).read_text()))
        # The actual owned-input binding, 96-event/9-flag cap, atomic private write,
        # and compile-time simulator guards remain byte-for-byte original.
        begin = "    /// Only the original one-use input consumer calls this after validating,"
        end = "\n}\n\n/// Scene-owned presentation state"
        self.assertEqual(old_swift[old_swift.index(begin):old_swift.index(end)],
                         swift[swift.index(begin):swift.index(end)])

if __name__ == "__main__":
    unittest.main(verbosity=2)

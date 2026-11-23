#!/usr/bin/env python3
"""Focused finite-schema and source controls; never a Host/provider runtime test."""
import argparse
import ast
import copy
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import unittest

BASE = "fdb78a44778c318b277506f0b09ba91c3b678e91"
ROOT = Path(__file__).resolve().parents[3]
PACKET = Path(__file__).resolve().parent
SESSION = "Source/ChavrusaText/HanlinHostAdapter/OtzariaHanlinChatSession.swift"
RUNNER = "Scripts/CI/runtime27-hanlin-live.py"
NAMES = {
    "Stage": "CONNECTION_DIAGNOSTIC_STAGES",
    "Reason": "CONNECTION_DIAGNOSTIC_REASONS",
    "Flag": "CONNECTION_DIAGNOSTIC_FLAGS",
}


def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args], timeout=30)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def validator_from(raw):
    tree = ast.parse(raw)
    nodes = [node for node in tree.body if
             isinstance(node, ast.FunctionDef) and node.name in {"require", "validate_connection_diagnostic"}
             or isinstance(node, ast.Assign)
             and any(isinstance(target, ast.Name) and target.id in NAMES.values() for target in node.targets)]
    namespace = {"json": json}
    exec(compile(ast.Module(body=nodes, type_ignores=[]), RUNNER, "exec"), namespace)
    return namespace


def encoded(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":")).encode()


def initial():
    return {"schemaVersion": 1, "overflow": False, "events": [
        {"sequence": 1, "stage": "inputConsumed", "reason": "none", "flags": {}}
    ]}


def append(value, stage, reason="none", flags=None):
    value["events"].append({"sequence": len(value["events"]) + 1, "stage": stage,
                            "reason": reason, "flags": flags or {}})


class DiagnosticControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.session = (ROOT / SESSION).read_text()
        cls.runner = (ROOT / RUNNER).read_bytes()
        cls.original_runner = git("show", BASE + ":" + RUNNER)
        cls.current = validator_from(cls.runner)
        cls.original = validator_from(cls.original_runner)
        cls.validate = staticmethod(cls.current["validate_connection_diagnostic"])

    def test_new_enums_match_actual_swift_and_admit_only_schema_values(self):
        for enum, constant in NAMES.items():
            match = re.search(r"enum " + enum + r": String \{([^}]+)\}", self.session)
            self.assertIsNotNone(match)
            names = set()
            for line in match[1].splitlines():
                if line.strip().startswith("case "):
                    names.update(part.strip() for part in line.strip()[5:].split(","))
            self.assertEqual(names, self.current[constant])
        value = initial()
        for stage in sorted(self.current[NAMES["Stage"]] - self.original[NAMES["Stage"]]):
            append(value, stage)
        for reason in sorted(self.current[NAMES["Reason"]] - self.original[NAMES["Reason"]]):
            append(value, "streamFinishObserved", reason=reason)
        for flag in sorted(self.current[NAMES["Flag"]] - self.original[NAMES["Flag"]]):
            append(value, "streamStepStarted", flags={flag: True})
        self.assertEqual(self.validate(encoded(value)), value)

    def test_new_entries_reject_dynamic_payloads_strings_and_unknown_flags(self):
        legitimate = initial()
        append(legitimate, "streamStepStarted", flags={"searchAdvertised": True})
        mutations = []
        for field, value in [("stage", "dynamic-provider-event"), ("reason", "provider-payload")]:
            bad = copy.deepcopy(legitimate)
            bad["events"][1][field] = value
            mutations.append(bad)
        for flags in [{"searchAdvertised": "true"}, {"searchAdvertised": 1},
                      {"providerPayload": True}, {"operationID": True}]:
            bad = copy.deepcopy(legitimate)
            bad["events"][1]["flags"] = flags
            mutations.append(bad)
        bad = copy.deepcopy(legitimate)
        bad["events"][1]["payload"] = "synthetic-control-only"
        mutations.append(bad)
        for bad in mutations:
            with self.subTest(value=bad["events"][1]):
                with self.assertRaises(ValueError):
                    self.validate(encoded(bad))

    def test_expanded_schema_still_fits_original_event_and_byte_limits(self):
        value = initial()
        stage = max(self.current[NAMES["Stage"]], key=len)
        reason = max(self.current[NAMES["Reason"]], key=len)
        flags = {name: False for name in sorted(self.current[NAMES["Flag"]], key=len, reverse=True)[:9]}
        for _ in range(95):
            append(value, stage, reason, flags)
        self.assertLessEqual(len(encoded(value)), 65536)
        self.assertEqual(len(self.validate(encoded(value))["events"]), 96)
        append(value, stage, reason, flags)
        with self.assertRaises(ValueError):
            self.validate(encoded(value))

    def test_runner_execution_and_privacy_code_is_unchanged_outside_enum_sets(self):
        def functional_ast(raw):
            tree = ast.parse(raw)
            tree.body = [node for node in tree.body if not (
                isinstance(node, ast.Assign) and
                any(isinstance(target, ast.Name) and target.id in NAMES.values() for target in node.targets))]
            return ast.dump(tree, include_attributes=False)
        self.assertEqual(functional_ast(self.runner), functional_ast(self.original_runner))
        old = ast.parse(self.original_runner)
        new = ast.parse(self.runner)
        original_validator = next(n for n in old.body if isinstance(n, ast.FunctionDef)
                                  and n.name == "validate_connection_diagnostic")
        candidate_validator = next(n for n in new.body if isinstance(n, ast.FunctionDef)
                                   and n.name == "validate_connection_diagnostic")
        self.assertEqual(ast.dump(original_validator, include_attributes=False),
                         ast.dump(candidate_validator, include_attributes=False))

    def test_exact_diagnostic_inverse_restores_original_two_source_files(self):
        proof = json.loads((PACKET / "DIAGNOSTIC_SOURCE_DELTA.json").read_text())
        self.assertEqual(proof["base"], BASE)
        self.assertEqual({row["path"] for row in proof["files"]}, {SESSION, RUNNER})
        for row in proof["files"]:
            restored = (ROOT / row["path"]).read_text()
            for replacement in reversed(row["replacements"]):
                self.assertEqual(restored.count(replacement["after"]), 1)
                restored = restored.replace(replacement["after"], replacement["before"], 1)
            self.assertEqual(restored.encode(), git("show", BASE + ":" + row["path"]))
        patch = git("diff", BASE, "--binary", "--", SESSION, RUNNER)
        self.assertEqual(patch, (PACKET / "DIAGNOSTIC_ONLY.patch").read_bytes())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(DiagnosticControls)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    rows = {}
    for path in [SESSION, RUNNER, str(Path(__file__).relative_to(ROOT)),
                 str((PACKET / "DIAGNOSTIC_SOURCE_DELTA.json").relative_to(ROOT)),
                 str((PACKET / "DIAGNOSTIC_ONLY.patch").relative_to(ROOT))]:
        raw = (ROOT / path).read_bytes()
        rows[path] = {"bytes": len(raw), "sha256": sha(raw)}
    report = {"status": "PASS_SOURCE_AND_SCHEMA_CONTROLS" if result.wasSuccessful() else "FAIL",
              "base": BASE, "controls_run": result.testsRun,
              "failures": len(result.failures), "errors": len(result.errors),
              "scope": "Synthetic finite-schema controls and exact source inverse only",
              "provider_called": False, "native_or_host_runtime_qualified": False,
              "apple_build": "NOT_RUN", "source_inputs": rows}
    args.out.write_text(json.dumps(report, sort_keys=True, indent=2) + "\n")
    print(json.dumps(report, sort_keys=True))
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(main())

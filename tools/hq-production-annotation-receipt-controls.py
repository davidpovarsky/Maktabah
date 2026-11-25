#!/usr/bin/env python3
"""Focused controller controls: actual Swift stage contract, no native/UI credit."""
from pathlib import Path
import hashlib
import json
import re
import runpy

ROOT = Path(__file__).resolve().parents[1]
DRIVER = ROOT / "Scripts/CI/production-annotation-native.py"
UI = ROOT / "Maktabah-iOSUITests/ProductionAnnotationEditorAcceptanceTests.swift"


def run():
    module = runpy.run_path(str(DRIVER))
    actual = re.findall(r'attachStorage\([^\n]*stage: "([^"]+)"', UI.read_text())
    expected = [
        "saved-plain-row", "native-clear-kept-same-uuid", "native-body-saved-same-uuid",
        "discard-preserved-canonical-bytes", "cold-open-preserved-same-rich-body",
        "backfill-saved-plain-row", "backfill-confirmation-cancelled", "backfill-native-body-saved",
        "backfill-repeat-kept-same-version", "backfill-cold-native-render-kept-body",
    ]
    assert actual == expected
    assert module["STAGES"] == expected and len(set(expected)) == 10
    assert len(module["SELECTORS"]) == 2
    passed = ["actual_original_and_backfill_swift_stage_contract"]

    def observer():
        result = module["OrdinaryEvidence"]()
        result.persist = lambda: None  # Isolated log-schema control; never a native receipt.
        return result

    def value(stage):
        return {
            "stage": stage, "annotation_id": 1, "annotation_uuid": "00000000-0000-4000-8000-000000000001",
            "revision": 0, "payload_sha256": "", "native_body_bytes": 0, "native_body_sha256": "",
            "source_sha256": "", "mutation_id": "", "sqlite_open_mode": "read-only",
            "qualification_mode": False,
        }

    def line(payload):
        return module["PREFIX"] + json.dumps(payload, sort_keys=True)

    def refuse(name, callback):
        try:
            callback()
        except (ValueError, AssertionError):
            passed.append(name)
        else:
            raise AssertionError(name + " was incorrectly admitted")

    valid = observer()
    for stage in expected:
        message = line(value(stage))
        assert valid.redact_evidence(message) == message
    assert [row["stage"] for row in valid.state["observations"]] == expected
    passed.append("all_ten_declared_log_observations_are_parsed")
    duplicate = observer()
    duplicate.redact_evidence(line(value(expected[0])))
    refuse("duplicate_stage_refused_before_capture",
           lambda: duplicate.redact_evidence(line(value(expected[0]))))
    refuse("unknown_stage_refused",
           lambda: observer().redact_evidence(line(value("fixture-undeclared-stage"))))
    qualified = value(expected[0]); qualified["qualification_mode"] = True
    refuse("qualification_mode_refused", lambda: observer().redact_evidence(line(qualified)))
    writable = value(expected[0]); writable["sqlite_open_mode"] = "read-write"
    refuse("writable_observation_refused", lambda: observer().redact_evidence(line(writable)))
    extra = value(expected[0]); extra["injected_body"] = "fixture"
    refuse("unexpected_private_payload_field_refused", lambda: observer().redact_evidence(line(extra)))
    ambiguous = line(value(expected[0])) + module["PREFIX"]
    refuse("ambiguous_prefix_refused", lambda: observer().redact_evidence(ambiguous))
    oversized = value(expected[0]); oversized["payload_sha256"] = "0" * 8193
    try:
        observer().redact_evidence(line(oversized))
    except ValueError as error:
        assert str(error) == "Oversized ordinary storage observation"
        passed.append("oversized_observation_refused")
    else:
        raise AssertionError("Oversized otherwise valid observation was admitted")
    # No callback.capture(), SQLite mutation, SDK call, XCTest invocation or
    # genuine native result is synthesized by these controls.
    return {
        "status": "LOG_SCHEMA_AND_ACTUAL_SWIFT_STAGE_CONTROLS_PASS",
        "passed": len(passed), "controls": passed, "native_tests_executed": 0,
        "native_readback_or_ui_accepted": False,
        "driver_sha256": hashlib.sha256(DRIVER.read_bytes()).hexdigest(),
        "actual_ui_source_sha256": hashlib.sha256(UI.read_bytes()).hexdigest(),
    }


if __name__ == "__main__":
    print(json.dumps(run(), indent=2))

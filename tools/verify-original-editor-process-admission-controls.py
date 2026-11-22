#!/usr/bin/env python3
"""New process-resume receipt admission controls; no Apple/native execution."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import runpy


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--source-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    source = args.source_root.resolve() / "Scripts/CI/hq-original-editor-distribution.py"
    source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
    admit = runpy.run_path(str(source))["require_compiled_host_api"]
    fixture = {
        "public_host_api": "EXPOSED_COMPILED_NATIVE_EDITOR_NOT_RUN",
        "editable_mount": "API_COMPILED_NATIVE_UI_NOT_RUN",
        "native_editor_ui_tests": 0,
        "compiled_consumer_api_probe_sha256": "a" * 64,
        "actual_public_surface": {
            "status": "ACTUAL_TARGET_PUBLIC_SURFACE_INSPECTED",
            "target": "AnytypeOriginalEditor",
            "reviewed_host_and_spi_requirements_observed": 38,
            "editable_mount_api": "EXPOSED_COMPILED_NATIVE_EDITOR_NOT_RUN",
            "qualification_spi_scope_verified": True,
            "public_host_scope_verified": True,
            "public_original_editor_or_writer_declarations": [],
            "own_public_symbols": [{"path": ["synthetic-unit-symbol-" + str(i)], "spi": True}
                                   for i in range(38)],
        },
    }
    rows = []
    report = {"scope": "SYNTHETIC_PROCESS_RESUME_RECEIPT_ADMISSION_ONLY",
              "source_sha256": source_hash, "apple_build": "NOT_RUN",
              "native_editor_ui_tests": 0, "prior_passed_controls_reexecuted": False,
              "controls": rows, "status": "FAILED"}

    def reject(value):
        try:
            admit(value)
        except RuntimeError:
            return
        raise AssertionError("Incomplete process-resume SDK receipt was admitted")

    try:
        before = copy.deepcopy(fixture)
        result = admit(fixture)
        assert fixture == before and result["native_editor_ui_tests"] == 0
        assert result["actual_public_surface"] == fixture["actual_public_surface"]
        rows.append({"name": "complete_38_requirement_receipt_keeps_native_not_run", "status": "PASS"})

        old = copy.deepcopy(fixture)
        old["actual_public_surface"]["reviewed_host_and_spi_requirements_observed"] = 21
        old["actual_public_surface"]["own_public_symbols"] = old["actual_public_surface"]["own_public_symbols"][:21]
        reject(old)
        rows.append({"name": "old_21_requirement_sdk_cannot_admit_process_resume", "status": "PASS"})

        for field, value in [("reviewed_host_and_spi_requirements_observed", 37),
                             ("reviewed_host_and_spi_requirements_observed", "38"),
                             ("qualification_spi_scope_verified", False),
                             ("public_host_scope_verified", False),
                             ("own_public_symbols", fixture["actual_public_surface"]["own_public_symbols"][:37])]:
            incomplete = copy.deepcopy(fixture)
            incomplete["actual_public_surface"][field] = value
            reject(incomplete)
        rows.append({"name": "partial_or_unverified_process_resume_surface_is_rejected", "status": "PASS"})
        assert hashlib.sha256(source.read_bytes()).hexdigest() == source_hash
        report["status"] = "PASS"
    except Exception as error:
        report["error"] = type(error).__name__ + ": " + str(error)
        raise
    finally:
        args.out.mkdir(parents=True, exist_ok=False)
        (args.out / "result.json").write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()

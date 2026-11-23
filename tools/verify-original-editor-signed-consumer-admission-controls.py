#!/usr/bin/env python3
"""Focused evidence admission controls; no Apple runtime or product builds."""
import argparse
import copy
import hashlib
import io
import json
from pathlib import Path
import runpy
import tempfile
import zipfile


def rejected(operation, contains=None):
    try:
        operation()
    except (RuntimeError, ValueError, KeyError, OSError) as error:
        if contains is not None:
            assert contains in str(error), str(error)
        return
    raise AssertionError("An unqualified or altered evidence input was accepted")


def configuration_fixture(producer, adapter):
    """Parser-only in-memory fixture. It is never a native qualification pin."""
    config = {key: producer[key] for key in ["repository", "repository_id", "source_sha", "run_id", "run_attempt",
              "job_id", "job_name", "workflow_path", "required_steps"]}
    config.update(schema=2, continuation_kind=adapter["KIND"], framework_producer=copy.deepcopy(producer))
    for name in ["framework_artifact", "evidence_artifact"]:
        config[name] = {**producer[name], "path": "build/source-control/" + name + ".zip"}
    config.update(archive_path=config["framework_artifact"]["path"],
                  artifact_id=producer["framework_artifact"]["id"],
                  archive_bytes=producer["framework_artifact"]["size_in_bytes"],
                  archive_sha256=producer["framework_artifact"]["sha256"],
                  distribution_root="build/source-control/distribution",
                  distribution_manifest_path="build/source-control/distribution.json",
                  distribution_manifest_sha256=producer["retained_input_sha256"]["framework-distribution.json"],
                  hanlin_source_path="build/source-control/hanlin.json",
                  hanlin_source_sha256=producer["retained_input_sha256"]["original-hanlin-snapshot.json"],
                  original_source_sha256=producer["original_source_sha256"],
                  qualification_path="build/source-control/runtime.json",
                  qualification_sha256="0" * 64, qualification_member="runtime-qualification.json",
                  qualification_wrapper=adapter["WRAPPER"], retained_execution_path="build/source-control/original.json")
    runtime = {"repository": producer["repository"], "repository_id": producer["repository_id"],
               "control_sha": "1" * 40, "run_id": 1, "run_attempt": 1, "job_id": 1,
               "workflow_path": adapter["WORKFLOW"], "head_branch": adapter["BRANCH"],
               "job_name": adapter["JOB_NAME"], "required_steps": adapter["REQUIRED_STEPS"]}
    runtime["evidence_artifact"] = {"id": 1, "size_in_bytes": 1, "sha256": "0" * 64,
        "path": "build/source-control/runtime.zip", "upload_step": adapter["REQUIRED_STEPS"][-1],
        "name": "Otzaria-Original-Editor-Signed-Consumer-Runtime-" + runtime["control_sha"] + "-1-1"}
    config["runtime_qualification_producer"] = runtime
    return config


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--source-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--group", choices=["source", "runtime"], required=True)
    parser.add_argument("--original-evidence", type=Path, required=True)
    parser.add_argument("--failed-runtime-evidence", type=Path)
    parser.add_argument("--admission-json", type=Path)
    parser.add_argument("--runtime-evidence", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    root = args.source_root.resolve()
    ci = root / "Scripts/CI"
    adapter = runpy.run_path(str(ci / "original_editor_signed_consumer_admission.py"))
    common = runpy.run_path(str(ci / "original_editor_continuation_admission.py"))
    sdk = runpy.run_path(str(ci / "hq-original-editor-distribution.py"))
    producer = adapter["reviewed_producer"]()
    rows = []
    report = {"scope": "EVIDENCE_ADMISSION_SOURCE_CONTROLS_ONLY", "group": args.group,
              "native_tests_executed": 0, "product_builds_executed": 0,
              "prior_controls_reexecuted": False, "controls": rows}
    def control(name, operation):
        operation()
        rows.append({"name": name, "status": "PASS"})
    def require(value):
        assert value
    def mutation(config, change):
        modified = copy.deepcopy(config)
        change(modified)
        return modified
    try:
        raw = args.original_evidence.read_bytes()
        assert len(raw) == producer["evidence_artifact"]["size_in_bytes"]
        assert hashlib.sha256(raw).hexdigest() == producer["evidence_artifact"]["sha256"]
        retained = adapter["original_payload"](args.original_evidence, producer)
        original = json.loads(retained["execution.json"])
        if args.group == "source":
            config = configuration_fixture(producer, adapter)
            control("explicit_signed_route_and_unchanged_legacy_selection", lambda: (
                require(common["signed_consumer_route"]({}) is None),
                rejected(lambda: common["signed_consumer_route"]({"continuation_kind": "unknown"})),
                require(common["validate_configuration"](config)[0] == producer)))
            control("actual_original_build_proof_keeps_its_failed_runtime", lambda: require(
                original["status"] == "FAIL" and original["original_framework_build"] == "PASS"
                and original["external_consumer_build"] == "PASS" and original["verified_runtime_observations"] == []))
            def original_role():
                for change in [lambda c: c["framework_producer"].update(source_sha="2" * 40),
                               lambda c: c.update(run_attempt=True),
                               lambda c: c.update(source_sha="2" * 40),
                               lambda c: c["framework_artifact"].update(id=1)]:
                    rejected(lambda: common["validate_configuration"](mutation(config, change)))
            control("original_producer_or_alias_substitution_rejected", original_role)
            def runtime_role():
                for change in [lambda c: c["runtime_qualification_producer"].update(run_attempt=True),
                               lambda c: c["runtime_qualification_producer"].update(run_id=producer["run_id"]),
                               lambda c: c["runtime_qualification_producer"].update(control_sha="UNFINALIZED"),
                               lambda c: c["runtime_qualification_producer"]["evidence_artifact"].update(
                                   id=producer["evidence_artifact"]["id"])]:
                    rejected(lambda: common["validate_configuration"](mutation(config, change)))
            control("runtime_producer_must_have_distinct_finalized_identity", runtime_role)
            control("old_failed_execution_cannot_be_runtime_qualification", lambda: rejected(
                lambda: common["validate_qualification"](config, original)))
            control("declared_host_flag_alone_cannot_grant_compiled_runtime", lambda: rejected(
                lambda: sdk["require_compiled_host_api"](original)))
            with tempfile.TemporaryDirectory(prefix="original-editor-admission-control-") as temporary:
                location = Path(temporary)
                def paths():
                    common["validate_paths"](location, config, sdk)
                    changed = mutation(config, lambda c: c.update(retained_execution_path=c["qualification_path"]))
                    rejected(lambda: common["validate_paths"](location, changed, sdk))
                    changed = mutation(config, lambda c: c.update(
                        retained_execution_path=c["distribution_root"] + "/QUALIFICATION.json"))
                    rejected(lambda: common["validate_paths"](location, changed, sdk))
                control("retained_and_runtime_receipts_cannot_alias_or_enter_products", paths)
            assert args.failed_runtime_evidence is not None
            control("actual_failed_continuation_archive_cannot_qualify", lambda: rejected(
                lambda: adapter["runtime_payload"](args.failed_runtime_evidence, config)))
            report["runtime_fixture_scope"] = "Parser-only in-memory identity; never written to admission inputs or used for native credit"
        else:
            assert args.admission_json is not None and args.runtime_evidence is not None
            config = json.loads(args.admission_json.read_bytes())
            runtime_artifact = config["runtime_qualification_producer"]["evidence_artifact"]
            raw = args.runtime_evidence.read_bytes()
            assert len(raw) == runtime_artifact["size_in_bytes"]
            assert hashlib.sha256(raw).hexdigest() == runtime_artifact["sha256"]
            qualification_raw = adapter["runtime_payload"](args.runtime_evidence, config)
            qualification = json.loads(qualification_raw)
            control("authentic_signed_runtime_and_retained_compiled_api_admitted_separately", lambda: (
                common["validate_qualification"](config, qualification, surface=json.loads(retained["actual-public-surface.json"])),
                sdk["require_compiled_host_api"](qualification, retained_original=original)))
            def scope():
                for change in [lambda q: q.update(external_consumer_build="PASS"),
                               lambda q: q.update(consumer_builds=1),
                               lambda q: q.update(native_editor_ui_tests=1),
                               lambda q: q.update(source_controls_replayed=245)]:
                    rejected(lambda: common["validate_qualification"](config, mutation(qualification, change)))
            control("retained_products_cannot_claim_rebuild_or_native_ui_credit", scope)
            def observations():
                for change in [lambda q: q.update(verified_runtime_observations=q["verified_runtime_observations"][:1]),
                               lambda q: q["verified_runtime_observations"][1].update(language="en"),
                               lambda q: q["actual_public_surface"].update(public_host_scope_verified=False)]:
                    rejected(lambda: common["validate_qualification"](config, mutation(qualification, change)))
            control("both_actual_languages_and_exact_compiled_surface_required", observations)
            def cleanup():
                for change in [lambda q: q.update(owned_simulator_cleanup_completed=False),
                               lambda q: q["owned_simulator_cleanup"].update(owned_device_proven_absent=False),
                               lambda q: q["owned_simulator_cleanup"].update(owned_udid="0" * 36),
                               lambda q: q["owned_simulator_cleanup"]["delete"].update(effective_returncode=False)]:
                    rejected(lambda: common["validate_qualification"](config, mutation(qualification, change)))
            control("owned_simulator_identity_absence_and_real_exit_status_required", cleanup)
            control("mutated_retained_compiler_receipt_rejected", lambda: rejected(lambda:
                sdk["require_compiled_host_api"](qualification, retained_original=mutation(original,
                    lambda q: q.update(compiled_consumer_api_probe_sha256="0" * 64)))))
            def same_pid():
                with zipfile.ZipFile(io.BytesIO(raw)) as outer:
                    payload = outer.read(adapter["WRAPPER"])
                with zipfile.ZipFile(io.BytesIO(payload)) as inner:
                    files = {name: inner.read(name) for name in inner.namelist()}
                english = json.loads(files["consumer-en-launch-result.json"])
                hebrew = json.loads(files["consumer-he-launch-result.json"])
                hebrew.update(pid=english["pid"], stdout=english["stdout"])
                files["consumer-he-launch-result.json"] = json.dumps(hebrew).encode()
                commands = json.loads(files["commands/COMMANDS.json"])
                command = next(row for row in commands if row["label"] == "consumer-he-launch")
                content = (english["stdout"] + "\n").encode()
                files["commands/" + command["stdout"]] = content
                command["stdout_sha256"] = hashlib.sha256(content).hexdigest()
                files["commands/COMMANDS.json"] = json.dumps(commands).encode()
                inner_bytes = io.BytesIO()
                with zipfile.ZipFile(inner_bytes, "w", zipfile.ZIP_DEFLATED) as inner:
                    for name, content in files.items():
                        inner.writestr(name, content)
                with tempfile.TemporaryDirectory(prefix="original-editor-pid-control-") as temporary:
                    archive = Path(temporary) / "changed-runtime.zip"
                    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as outer:
                        outer.writestr(adapter["WRAPPER"], inner_bytes.getvalue())
                    rejected(lambda: adapter["runtime_payload"](archive, config), "distinct actual processes")
            control("two_language_receipts_cannot_reuse_one_consistent_process_id", same_pid)
        report.update(status="PASS", controls_passed=len(rows), controls_failed=0)
        return 0
    except BaseException as error:
        report.update(status="FAIL", controls_passed=len(rows), controls_failed=1,
                      error=type(error).__name__ + ": " + str(error))
        return 1
    finally:
        names = ["Scripts/CI/original_editor_signed_consumer_admission.py",
                 "Scripts/CI/original_editor_continuation_admission.py",
                 "Scripts/CI/hq-original-editor-distribution.py",
                 "tools/verify-original-editor-signed-consumer-admission-controls.py", adapter["PRODUCER_PATH"]]
        report["source_sha256"] = {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in names}
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
        print(json.dumps({key: report.get(key) for key in ["status", "group", "controls_passed", "controls_failed", "error"]}))


if __name__ == "__main__":
    raise SystemExit(main())

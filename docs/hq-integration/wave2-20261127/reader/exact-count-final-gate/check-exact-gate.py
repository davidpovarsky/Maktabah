#!/usr/bin/env python3
"""Source-only rejection controls for the additional v40 exact-count gate."""
import copy
import hashlib
import json
from pathlib import Path
import runpy
import sys
import tempfile
from types import SimpleNamespace

HERE = Path(__file__).resolve().parent
SOURCE = Path(sys.argv[1]).resolve(strict=True) if len(sys.argv) == 2 else HERE / "reader-full-v40-ui-observation.py"
gate = runpy.run_path(str(SOURCE))["require_exact_inspector_scales"]
base_report = {
    "corpus_profile": "full-v40",
    "status": "ORIGINAL_UI_OBSERVATIONS_COMPLETE_METRICS_REVIEW_REQUIRED",
    "database_bytes_unchanged": True,
    "source_and_built_binary_bytes_unchanged": True,
    "cleanup_or_post_verification_failures": [],
    "reused_external_owned_simulator": "11111111-2222-4333-8444-555555555555",
    "source": {"scope": "synthetic controller input, not a native execution receipt"},
}
base_completion = {
    "observationIDs": ["observed-a", "observed-b", "observed-c"],
    "scales": [{"observationID": key, "requestedCount": count, "actualCount": count,
                "exactRequestedCount": True}
               for key, count in zip(["observed-a", "observed-b", "observed-c"], [100, 500, 2000])],
    "exact_size_criterion_met": True,
    "natural_at_least_workloads_met": True,
}


def witness(path):
    data = Path(path).read_bytes()
    return {"path": str(path), "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def bounded_json(path, limit):
    data = Path(path).read_bytes()
    assert len(data) <= limit
    return json.loads(data)


def write(path, value):
    Path(path).write_text(json.dumps(value, sort_keys=True, indent=2) + "\n")


cases = []


def check(name, edit=None, expected=False):
    report, completion = copy.deepcopy(base_report), copy.deepcopy(base_completion)
    if edit:
        edit(report, completion)
    with tempfile.TemporaryDirectory(prefix="wave2-v40-gate-control-") as directory:
        out = Path(directory)
        write(out / "result.json", report)
        write(out / "original-inspector-scales.json", completion)
        before = {p.name: p.read_bytes() for p in out.iterdir()}
        error = None
        try:
            gate(SimpleNamespace(OUT=out, bounded_json=bounded_json, witness=witness, write=write))
        except Exception as caught:
            error = caught
        receipt = bounded_json(out / "v40-exact-inspector-final-gate.json", 2_000_000)
        passed = ((error is None) is expected and receipt["status"] == ("MET" if expected else "NOT_MET")
                  and all((out / name).read_bytes() == raw for name, raw in before.items())
                  and receipt["full_performance_acceptance"] is False
                  and receipt["full_row_rendering_acceptance"] is False)
        cases.append({"name": name, "passed": passed,
                      "scope": "synthetic host-receipt rejection control; not app/native acceptance"})


check("exact_three_natural_observations", expected=True)
check("at_least_cannot_be_exact", lambda r, c: c["scales"][0].update(actualCount=101, exactRequestedCount=False))
check("declared_exact_flag_cannot_override_actual_count", lambda r, c: c["scales"][2].update(actualCount=2001))
check("boolean_is_not_integer_count", lambda r, c: c["scales"][0].update(actualCount=True))
check("float_is_not_integer_count", lambda r, c: c["scales"][0].update(actualCount=100.0))
check("missing_scale_cannot_pass", lambda r, c: c["scales"].pop())
check("duplicate_observation_cannot_cover_two_scales", lambda r, c: c["scales"][1].update(observationID="observed-a"))
check("unobserved_scale_cannot_pass", lambda r, c: c["scales"][1].update(observationID="unobserved"))
check("host_exact_flag_must_agree", lambda r, c: c.update(exact_size_criterion_met=False))
check("each_original_scale_must_be_exact", lambda r, c: c["scales"][1].update(exactRequestedCount=False))
check("original_ui_failure_cannot_pass", lambda r, c: r.update(status="FAILED_OR_INCOMPLETE"))
check("changed_database_cannot_pass", lambda r, c: r.update(database_bytes_unchanged=False))
check("changed_source_cannot_pass", lambda r, c: r.update(source_and_built_binary_bytes_unchanged=False))
check("cleanup_failure_cannot_pass", lambda r, c: r.update(cleanup_or_post_verification_failures=["observation_host"]))
check("v32_receipt_cannot_be_relabelled", lambda r, c: r.update(corpus_profile="full-v32"))
check("absent_device_cannot_pass", lambda r, c: r.pop("reused_external_owned_simulator"))
check("missing_source_cannot_pass", lambda r, c: r.pop("source"))

result = {"scope": "Python source-only exact-cardinality gate controls; no native test executed",
          "source_sha256": witness(SOURCE)["sha256"], "cases": cases,
          "passed": sum(x["passed"] for x in cases), "failed": sum(not x["passed"] for x in cases)}
print(json.dumps(result, indent=2))
raise SystemExit(0 if result["failed"] == 0 else 1)

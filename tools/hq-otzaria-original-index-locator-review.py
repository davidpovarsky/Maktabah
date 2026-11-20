#!/usr/bin/env python3
"""Re-evaluate sealed actual C results against original packed-ID/segment semantics.

The original failed evaluator/result remains immutable. Only the missing SQL
locator verification and an additional real producer rollback/reopen are run.
No original search or occurrence run is relabeled or repeated.
"""
import importlib.util
import argparse
import json
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("old_index_runtime", ROOT / "tools/hq-otzaria-old-index-runtime.py")
runtime = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runtime)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--review-name", required=True)
    args = parser.parse_args()
    assert runtime.re_safe_name(args.review_name)
    original = runtime.BUILD / "runtime/miniTest10-v6/attempt3"
    out = runtime.BUILD / "runtime/miniTest10-v6" / args.review_name
    assert not out.exists()
    out.mkdir(parents=True)
    original_bytes = {p.name: runtime.sha(p) for p in original.iterdir() if p.is_file()}
    prior = json.loads((original / "RESULT.json").read_text(encoding="utf-8"))
    failed = [item["name"] for item in prior["checks"] if not item["passed"]]
    assert failed == ["actual_ranked_page_locators_bind_original_sql_rows"]
    actual = {}
    for label in ("producer265", "consumerd5"):
        result = json.loads((original / (label + "-result.json")).read_text(encoding="utf-8"))
        assert result["exit"] == 0 and result["logSHA256"] == runtime.sha(original / (label + "-consumer.log"))
        actual[label] = result
    database, expected_sha, expected_bytes = runtime.DATABASES["miniTest10-v6"]
    assert database.stat().st_size == expected_bytes and runtime.sha(database) == expected_sha
    connection = sqlite3.connect(database.as_uri() + "?mode=ro&immutable=1", uri=True)
    decoder = runtime.OriginalZstd(connection, runtime.ZSTD_DLL)
    locators = runtime.sql_locator_checks(connection, decoder, runtime.common_cases(), actual["consumerd5"]["responses"])
    decoder.close(); connection.close()
    runtime.save(out / "SQL_LOCATORS.json", locators)
    assert locators and all(row["passed"] for row in locators)
    copies = runtime.BUILD / "read-copies/miniTest10-v6"
    receipt = json.loads((runtime.BUILD / "artifacts/miniTest10-v6/INPUT_VERIFIED.json").read_text(encoding="utf-8"))
    before = runtime.inventory(copies / "consumerd5")
    assert all(before.get(name) == metadata for name, metadata in receipt["published_files"].items())
    executable, build = runtime.compile_consumer("265")
    rollback = runtime.run_consumer(executable, copies / "consumerd5", runtime.common_cases(), out, "producer265_reopen_after_d5")
    after = runtime.inventory(copies / "consumerd5")
    runtime.save(out / "before-rollback-inventory.json", before)
    runtime.save(out / "after-rollback-inventory.json", after)
    checks = {
        "350_original_result_locators_use_actual_segment_and_SQL_line_id": len(locators) == 350 and all(x["passed"] for x in locators),
        "packed_catalogue_ID_low_word_equals_segment_plus_one": all(x["packedIDOrdinalValid"] for x in locators),
        "original265_actually_reopens_after_d5": rollback["exit"] == 0 and rollback["responses"].get("closed", {}).get("closed") is True,
        "producer_rollback_actual_document_count_unchanged": all(rollback["responses"].get("document_count_" + when, {}).get("value") == 18879 for when in ("before", "after")),
        "producer_rollback_retains_all21_original_query_results": all(rollback["responses"].get(name) == actual["producer265"]["responses"][name] for name, _, _ in runtime.common_cases()),
        "all_original_payload_and_created_metadata_bytes_unchanged_by_rollback": before == after,
        "original_SQL_bytes_unchanged": runtime.sha(database) == expected_sha,
        "original_failed_postprocessor_and_raw_run_unchanged": original_bytes == {p.name: runtime.sha(p) for p in original.iterdir() if p.is_file()},
    }
    result = {"passed": all(checks.values()), "checks": checks, "originalAttemptCounts": prior["counts"],
              "originalEvaluatorFailure": "Treated packed64 ID as line ordinal, then compared snippets with whole lines. Actual original API stores segment, emits HTML-escaped bounded snippets, and uses segment for navigation.",
              "correctedLocatorComparisons": len(locators), "originalRunSHA256": original_bytes,
              "reviewDriverSHA256": runtime.sha(Path(__file__)),
              "sourceEvaluatorSHA256": runtime.sha(ROOT / "tools/hq-otzaria-old-index-runtime.py"),
              "SQLScannerSHA256": runtime.sha(ROOT / "tools/otzaria_original_sql_oracle.py"),
              "originalSearchAndOccurrenceRunsRepeated": False, "additionalRealRollbackQueryCases": 21,
              "productionPolicyEnabled": False, "AppleSDK": "NOT_RUN", "Native": "NOT_RUN"}
    runtime.save(out / "RESULT.json", result)
    print(json.dumps(result, ensure_ascii=False))
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())

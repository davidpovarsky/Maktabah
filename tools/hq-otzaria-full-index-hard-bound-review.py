#!/usr/bin/env python3
"""Preserve the first full run; resolve evaluators and repeat bounded denials.

The five original default-limit denials remain failures/unsupported workloads,
never scalar results. This follow-up uses only the already built candidate C
consumer and the owned authenticated original index. Two global scalars remain
unqualified until a separate complete independent SQL scan agrees.
"""
import importlib.util
import json
import sqlite3
from pathlib import Path
from otzaria_original_sql_oracle import token_positions

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("old_index_runtime", ROOT / "tools/hq-otzaria-old-index-runtime.py")
r = importlib.util.module_from_spec(spec)
spec.loader.exec_module(r)
LIMITS = {"maxCandidateDocuments": 1000000, "maxPositions": 10000000,
          "maxPositionsPerDocument": 262144, "maxSegments": 4096}
FAILED = {"occ_books10_0", "occ_books10_3", "occ_books10_4", "occ_books10_7", "occ_book103_4"}


def proof_matches(response, request, receipt):
    query_positions = list(token_positions(request["query"]))
    assert len(query_positions) == 1
    proof = (response.get("value") or {}).get("proof") or {}
    actual_segments = sorted((x["segmentId"], x["deleteOpstamp"])
                            for x in proof.get("searcherGeneration", {}).get("segments", []))
    expected_segments = sorted((x["segment_id"].replace("-", ""),
                                None if x.get("deletes") is None else x["deletes"]["opstamp"])
                               for x in receipt["original_segments"])
    return (response.get("ok") is True and proof.get("exact") is True
            and proof.get("countKind") == "distinctTokenPositions"
            and proof.get("engineRepository") == "davidpovarsky/otzaria_search_engine"
            and proof.get("engineBranch") == "codex/otzaria-exact-occurrences-20261120"
            and proof.get("engineCommit") == r.CONSUMER and proof.get("originalUpstreamBase") == r.PRODUCER
            and proof.get("indexSchemaVersion") == 4 and proof.get("liveIndexDocuments") == 7080797
            and proof.get("analyzedToken") in query_positions[0]
            and proof.get("requestedFacets") == (sorted({f"/book/{b}" for b in request["bookIds"]}) if "bookIds" in request else ["/"])
            and proof.get("requestToken", 0) > 0 and actual_segments == expected_segments)


def expected_scoped(oracle, request):
    return {key: sum(oracle["queries"][request["query"]]["books"].get(str(book), {}).get(key, 0)
                     for book in request["bookIds"])
            for key in ("occurrences", "matchingLiveDocuments")}


def main():
    original = r.BUILD / "runtime/full-v32/attempt1"
    out = r.BUILD / "runtime/full-v32/hard-bounds-and-source-review1"
    assert not out.exists()
    out.mkdir(parents=True)
    sealed = {p.name: r.sha(p) for p in original.iterdir() if p.is_file()}
    prior = json.loads((original / "RESULT.json").read_text(encoding="utf-8"))
    first = json.loads((original / "consumerd5-result.json").read_text(encoding="utf-8"))
    assert first["exit"] == 0 and first["logSHA256"] == r.sha(original / "consumerd5-consumer.log")
    receipt = json.loads((r.BUILD / "artifacts/full-v32/INPUT_VERIFIED.json").read_text(encoding="utf-8"))
    oracle = json.loads((original / "SQL_ORACLE.json").read_text(encoding="utf-8"))
    assert oracle["rowsScanned"] == 18879 and oracle["allSQLDocuments"] == 7080797
    requests = {name: request for name, _, request in r.occurrence_cases("full-v32")}
    denials = {name: response for name, response in first["responses"].items()
              if name in requests and response.get("ok") is not True}
    assert set(denials) == FAILED
    assert all(x.get("value") is None and x.get("error", {}).get("code") == "budget_exceeded"
               for x in denials.values())
    successful_original_proofs = {name: proof_matches(first["responses"][name], request, receipt)
                                 for name, request in requests.items() if name not in FAILED}
    assert len(successful_original_proofs) == 20 and all(successful_original_proofs.values())
    database, database_sha, size = r.DATABASES["full-v32"]
    assert database.stat().st_size == size and r.sha(database) == database_sha
    connection = sqlite3.connect(database.as_uri() + "?mode=ro&immutable=1", uri=True)
    decoder = r.OriginalZstd(connection, r.ZSTD_DLL)
    locators = r.sql_locator_checks(connection, decoder, r.common_cases(), first["responses"])
    decoder.close(); connection.close()
    r.save(out / "SQL_LOCATORS.json", locators)
    assert locators and all(x["passed"] for x in locators)
    index = r.BUILD / "read-copies/full-v32/consumerd5"
    before = r.inventory(index)
    assert all(before.get(name) == value for name, value in receipt["published_files"].items())
    assert json.loads((index / "meta.json").read_text(encoding="utf-8"))["segments"] == receipt["original_segments"]
    r.save(out / "BEFORE_INVENTORY.json", before)
    cases = []
    for name in sorted(FAILED):
        cases.append(("hard_" + name, "occurrences", dict(requests[name], limits=LIMITS)))
    for number, query in enumerate(("בראשית", "אברהם")):
        cases.append(("global_sql_pending_" + str(number), "occurrences",
                      {"version": 1, "mode": "exact", "query": query, "timeoutMs": 60000, "limits": LIMITS}))
    executable, build = r.compile_consumer("d5")
    actual = r.run_consumer(executable, index, cases, out, "consumerd5-hard-bounds")
    after = r.inventory(index)
    r.save(out / "AFTER_INVENTORY.json", after)
    responses = actual["responses"]
    assert actual["exit"] == 0 and responses.get("closed", {}).get("closed") is True
    assert responses.get("build_info") == first["responses"].get("build_info")
    assert all(responses.get("document_count_" + when, {}).get("value") == 7080797 for when in ("before", "after"))
    rows = []
    for name, _, request in cases:
        response = responses.get(name, {})
        value = response.get("value") or {}
        if response.get("ok") is True:
            assert proof_matches(response, request, receipt)
            work = value.get("work") or {}
            assert 0 <= work.get("visitedCandidateDocuments", -1) <= LIMITS["maxCandidateDocuments"]
            assert 0 <= work.get("inspectedPositions", -1) <= LIMITS["maxPositions"]
            assert 0 <= work.get("visitedSegments", -1) <= LIMITS["maxSegments"]
            expected = expected_scoped(oracle, request) if "bookIds" in request else None
            if expected is not None:
                assert all(value.get(key) == count for key, count in expected.items())
            status = "SCOPED_INDEPENDENT_SQL_MATCH" if expected is not None else "GLOBAL_RAW_SCALAR_PENDING_COMPLETE_SQL_ORACLE"
        else:
            assert response.get("value") is None
            assert response.get("error", {}).get("code") in ("budget_exceeded", "deadline_exceeded")
            expected = None
            status = "UNSUPPORTED_WITHIN_PUBLISHED_HARD_BOUNDS_NO_SCALAR"
        rows.append({"case": name, "request": request, "response": response, "expected": expected, "status": status})
    checks = {
        "original_21_legacy_results_and_actual_rollback_preserved": all(x["passed"] for x in prior["checks"] if x["name"].startswith("legacy_parity_") or x["name"].startswith("original265_cold_")),
        "corrected_all_original_SQL_locators_pass": bool(locators) and all(x["passed"] for x in locators),
        "original_twenty_successful_default_proofs_use_canonical_facets": all(successful_original_proofs.values()),
        "original_five_default_denials_preserved_without_scalar": len(denials) == 5,
        "all_payload_and_created_metadata_bytes_unchanged": before == after,
        "original_database_bytes_unchanged": r.sha(database) == database_sha,
        "original_attempt_and_failed_evaluator_bytes_unchanged": sealed == {p.name: r.sha(p) for p in original.iterdir() if p.is_file()},
    }
    result = {"checksPassed": all(checks.values()), "checks": checks, "originalAttemptCounts": prior["counts"],
              "originalAttemptSHA256": sealed, "originalDefaultBudgetDenials": denials,
              "correctedSQLLocatorComparisons": len(locators), "correctedDefaultSuccessfulProofs": successful_original_proofs,
              "followupCases": rows, "hardBoundsScopedSupported": sum(x["status"] == "SCOPED_INDEPENDENT_SQL_MATCH" for x in rows),
              "hardBoundsUnsupported": sum(x["status"] == "UNSUPPORTED_WITHIN_PUBLISHED_HARD_BOUNDS_NO_SCALAR" for x in rows),
              "globalSQLComparison": "PENDING_SEPARATE_COMPLETE_ORACLE",
              "consumerExecutableSHA256": actual["executableSHA256"], "consumerLibrarySHA256": build["inputs"]["librarySHA256"],
              "driverSHA256": r.sha(Path(__file__)), "runtimeEvaluatorSHA256": r.sha(ROOT / "tools/hq-otzaria-old-index-runtime.py"),
              "productionPolicyEnabled": False, "indexRebuilt": False, "AppleSDK": "NOT_RUN", "Native": "NOT_RUN"}
    r.save(out / "RESULT.json", result)
    print(json.dumps({"checksPassed": result["checksPassed"], "locators": len(locators),
                      "cases": [{"case": x["case"], "status": x["status"], "actual": x["response"]} for x in rows]}, ensure_ascii=False))
    return 0 if all(checks.values()) else 1


if __name__ == "__main__":
    raise SystemExit(main())

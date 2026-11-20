#!/usr/bin/env python3
"""Review sealed actual old-index evidence; never enable an app contract.

This command refuses to publish a qualification summary without the COMPLETE
independent full SQL oracle. It does not open, rebuild or mutate any index or
database, and does not rerun the original native/C/Swift tests.
"""
import ast
import datetime
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build/index-read-qualification-20261120"
PRODUCER = "265a14ea54f959a3e266d6e8acfa3a3b98101d68"
CONSUMER = "d5d59d1269bdf87fb0a6901cf31941726a0c699b"
MANIFESTS = {
    "miniTest10-v6": ("ae3bd170dc4650806a9fdda1beefe682eeefb5abde886363d6feac999603f8d4", 18879),
    "full-v32": ("34319ced48e76f22a5ae2df23745a03332160ddab2dd64244a5c917e0ce00a57", 7080797),
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    input_digests = {}

    def read(relative):
        path = BUILD / relative
        assert path.exists(), "Required actual evidence is not complete: " + relative
        data = path.read_bytes()
        input_digests[relative] = hashlib.sha256(data).hexdigest()
        return json.loads(data)

    def verify_sealed(directory, hashes):
        for name, expected in hashes.items():
            relative = directory + "/" + name
            actual = digest(BUILD / relative)
            assert actual == expected, "Original sealed evidence changed: " + relative
            input_digests[relative] = actual

    producer_build = read("binaries/265/BUILD_ATTEMPT1.json")
    consumer_copy = read("binaries/d5/SNAPSHOT.json")
    assert producer_build["exit"] == 0 and producer_build["engine_checkout_pristine_after"] is True
    assert producer_build["engine_commit"] == PRODUCER
    assert consumer_copy["source_bridge_commit"] == "99f7927e4da72f2463417f5c2de2c4d20c6aa168"
    assert consumer_copy["source_library_unchanged_after_copy"] is True
    builds = {name: read("binaries/" + name + "/READ_CONSUMER_BUILD.json") for name in ("265", "d5")}
    assert builds["265"]["inputs"]["librarySHA256"] == producer_build["artifact_sha256"] == "16f6d54b9bacc49d708da4017051ebac0825c1f2adae163bf53a3908bb8b6cf7"
    assert builds["d5"]["inputs"]["librarySHA256"] == consumer_copy["library_sha256"] == "7f23e3e87aa604b410f9cd21f1b56aab2d30596c697d46c8fb19ad160e34c7a0"
    assert all(build["exit"] == 0 for build in builds.values())
    assert all(build["inputs"]["sourceSHA256"] == digest(ROOT / "Tests/HQ/search/OriginalIndexReadConsumer.c") for build in builds.values())

    def verify_raw_run(directory, label, engine):
        result = read(directory + "/" + label + "-result.json")
        assert result["exit"] == 0 and result["executableSHA256"] == builds[engine]["executableSHA256"]
        verify_sealed(directory, {label + "-consumer.log": result["logSHA256"],
                                  label + "-commands.tsv": result["commandsSHA256"]})
        responses = {}
        for line in (BUILD / directory / (label + "-consumer.log")).read_text(encoding="utf-8", errors="strict").splitlines():
            if line.startswith("OTZARIA_QUAL\t"):
                _, name, payload = line.split("\t", 2)
                assert name not in responses
                responses[name] = json.loads(payload)
        assert responses == result["responses"] and responses["closed"]["closed"] is True
        return result

    oracle_directory = "full-sql-global-oracle/attempt4-partitioned"
    oracle = read(oracle_directory + "/RESULT.json")
    assert oracle["status"] == "COMPLETE_INDEPENDENT_SQL_ORACLE_NOT_ENGINE_QUALIFICATION"
    assert oracle["partial"] is False and oracle["engineLoaded"] is False and oracle["indexRead"] is False
    assert oracle["rowsScanned"] == 7080797 and oracle["originalBooks"] == 7876
    assert oracle["databaseSHA256BeforeAndAfter"] == "2f4dcd72e8bdb1fc5c0516ae9705e57759c017ec2981b49c35115625c3d3f765"
    assert oracle["allOriginalRowIDsVerifiedExactlyOnce"] is True and oracle["partitionCount"] == 71
    assert oracle["actualCarriageReturnRows"] >= 5 and oracle["actualCarriageReturns"] >= 34
    corrected_validation = read("full-sql-global-oracle/REGEX_FULL_MINI_AND_CR_PARITY.json")
    assert corrected_validation["passed"] and corrected_validation["actualSQLRows"] == 18879
    assert corrected_validation["actualOffendingBookID"] == 7428 and corrected_validation["actualOffendingBookRows"] == 3535
    assert corrected_validation["actualCRRows"] == 5 and corrected_validation["actualCRCharacters"] == 34
    assert corrected_validation["newCRControls"] == oracle["newCRControls"] == 11
    assert corrected_validation["retainedLFRejectionControls"] == oracle["retainedLFRejectionControls"] == 2
    assert corrected_validation["offendingRow"]["priorGuardRejects"] and corrected_validation["offendingRow"]["correctedGuardAllows"]
    failed_row = read("full-sql-global-oracle/attempt3/FAILED_ROW_DIAGNOSIS.json")
    assert failed_row["countsPublished"] is False and failed_row["found"][0]["lineID"] == 6105588
    assert not (BUILD / "full-sql-global-oracle/attempt3/RESULT.json").exists()
    partition_driver = ROOT / "tools/hq-otzaria-full-sql-occurrence-partitions.py"
    assert digest(partition_driver) == oracle["sourceSHA256"] == corrected_validation["sourceSHA256"]
    previous_id, covered = 0, 0
    multiplicities = {query: [] for query in oracle["counts"]}
    for number, (name, expected_digest) in enumerate(sorted(oracle["partitionSHA256"].items())):
        assert name == f"partition-{number:04}.json"
        part = read(oracle_directory + "/" + name)
        assert input_digests[oracle_directory + "/" + name] == expected_digest
        assert part["complete"] is True and part["partialNotPublishable"] is True
        assert part["firstRowOrdinal"] == covered and part["previousLineID"] == previous_id
        assert part["firstLineID"] > previous_id and part["lastLineID"] >= part["firstLineID"]
        assert part["rows"] == (100000 if number < 70 else 80797)
        assert part["sourceIdentity"]["sourceSHA256"] == oracle["sourceSHA256"]
        assert part["sourceIdentity"]["databaseSHA256"] == oracle["databaseSHA256BeforeAndAfter"]
        covered += part["rows"]; previous_id = part["lastLineID"]
        for query, rows in part["multiplicities"].items():
            assert query in multiplicities
            assert all(part["firstLineID"] <= line_id <= part["lastLineID"] and count > 0 for line_id, count in rows)
            multiplicities[query].extend(rows)
    assert covered == 7080797
    for query, rows in multiplicities.items():
        assert all(a[0] < b[0] for a, b in zip(rows, rows[1:]))
        row_digest = hashlib.sha256()
        for line_id, count in rows:
            row_digest.update(f"{line_id}:{count}\n".encode())
        assert sum(count for _, count in rows) == oracle["counts"][query]["occurrences"]
        assert len(rows) == oracle["counts"][query]["matchingLiveDocuments"]
        assert row_digest.hexdigest() == oracle["counts"][query]["matchingLineMultiplicitySHA256"]
    parity = read("full-sql-global-oracle/REGEX_FULL_MINI_PARITY.json")
    assert parity["passed"] is True and parity["actualSQLRows"] == 18879
    assert parity["regexGrammarControls"] == oracle["regexGrammarControls"] == 5000
    assert parity["decoderByteParityControls"] == oracle["retainedDictionaryByteParityControls"] == 32
    # Only read-only SQLite mmap selection was added after the complete mini
    # row parity run. All module constants and scanner functions are identical.
    old_driver = BUILD / "source-snapshots" / (parity["driverSHA256"] + "-hq-otzaria-full-sql-occurrence-oracle.py")
    current_driver = ROOT / "tools/hq-otzaria-full-sql-occurrence-oracle.py"
    assert digest(old_driver) == parity["driverSHA256"]
    assert digest(current_driver) == oracle["originalOracleModuleSHA256"] == corrected_validation["originalOracleModuleSHA256"]
    def semantics(path):
        module = ast.parse(path.read_text(encoding="utf-8-sig"))
        return [ast.dump(node, include_attributes=False) for node in module.body
                if not isinstance(node, ast.Expr) and not isinstance(node, ast.If)
                and not (isinstance(node, ast.FunctionDef) and node.name == "main")]
    assert semantics(old_driver) == semantics(current_driver)
    assert parity["scannerSHA256"] == oracle["scannerSHA256"] == digest(ROOT / "tools/otzaria_original_sql_oracle.py")
    inputs = {}
    for profile, (manifest_sha, count) in MANIFESTS.items():
        receipt = read("artifacts/" + profile + "/INPUT_VERIFIED.json")
        assert receipt["immutable_release"] is True and receipt["engine_opened"] is False
        assert receipt["index_rebuilt"] is False and receipt["database_downloaded"] is False
        assert receipt["manifest_sha256"] == manifest_sha
        assert receipt["metadata_document_count_before_any_engine_open"] == count
        assert receipt["producer"]["commit"] == PRODUCER
        manifest_path = BUILD / "artifacts" / profile / "otzaria-search-manifest.json"
        assert digest(manifest_path) == manifest_sha
        inputs[profile] = {"release": receipt["release"], "releaseID": receipt["release_id"],
                           "manifestSHA256": manifest_sha, "artifactIdentity": receipt["artifact_identity"],
                           "documents": count, "originalSegments": receipt["original_segments"],
                           "publishedFiles": receipt["published_files"]}
    mini = read("runtime/miniTest10-v6/attempt3/RESULT.json")
    mini_review = read("runtime/miniTest10-v6/attempt3-reviewed2/RESULT.json")
    assert mini["counts"] == {"checks": 75, "passed": 74, "failed": 1, "skipped": 0}
    assert mini_review["passed"] is True and all(mini_review["checks"].values())
    assert mini_review["correctedLocatorComparisons"] == 350
    assert mini["legacyCases"] == 21 and mini["occurrenceCases"] == 33
    assert all(x["passed"] for x in mini["checks"] if x["name"] != "actual_ranked_page_locators_bind_original_sql_rows")
    verify_sealed("runtime/miniTest10-v6/attempt3", mini_review["originalRunSHA256"])
    for label, engine in (("producer265", "265"), ("consumerd5", "d5")):
        verify_raw_run("runtime/miniTest10-v6/attempt3", label, engine)
    mini_rollback = verify_raw_run("runtime/miniTest10-v6/attempt3-reviewed2", "producer265_reopen_after_d5", "265")
    mini_baseline = read("runtime/miniTest10-v6/attempt3/producer265-result.json")
    mini_query_names = [line.split("\t", 1)[0] for line in
                        (BUILD / "runtime/miniTest10-v6/attempt3/producer265-commands.tsv").read_text(encoding="utf-8").splitlines()]
    assert len(mini_query_names) == len(set(mini_query_names)) == 21
    assert all(mini_rollback["responses"][name] == mini_baseline["responses"][name] for name in mini_query_names)
    full = read("runtime/full-v32/attempt1/RESULT.json")
    full_review = read("runtime/full-v32/hard-bounds-and-source-review1/RESULT.json")
    assert full["counts"] == {"checks": 96, "passed": 81, "failed": 15, "skipped": 0}
    assert full["legacyCases"] == 21 and full["occurrenceCases"] == 25
    assert full_review["checksPassed"] is True and all(full_review["checks"].values())
    assert full_review["correctedSQLLocatorComparisons"] == 450
    assert full_review["hardBoundsScopedSupported"] == 5 and full_review["hardBoundsUnsupported"] == 0
    original_denied = {"occ_books10_0", "occ_books10_3", "occ_books10_4", "occ_books10_7", "occ_book103_4"}
    expected_original_failures = ({"actual_ranked_page_locators_bind_original_sql_rows"}
                                  | {"independent_sql_" + name for name in original_denied}
                                  | {"held_original_snapshot_proof_" + name for name in original_denied}
                                  | {"held_original_snapshot_proof_occ_books10_" + str(n) for n in (1, 2, 5, 6)})
    assert {row["name"] for row in full["checks"] if not row["passed"]} == expected_original_failures
    verify_sealed("runtime/full-v32/attempt1", full_review["originalAttemptSHA256"])
    for label, engine in (("producer265", "265"), ("consumerd5", "d5"), ("producer265_reopen_after_d5", "265")):
        verify_raw_run("runtime/full-v32/attempt1", label, engine)
    verify_raw_run("runtime/full-v32/hard-bounds-and-source-review1", "consumerd5-hard-bounds", "d5")
    assert len(full_review["originalDefaultBudgetDenials"]) == 5
    for response in full_review["originalDefaultBudgetDenials"].values():
        assert response["ok"] is False and response["value"] is None
        assert response["error"]["code"] == "budget_exceeded"
    comparisons = []
    for row in full_review["followupCases"]:
        if row["status"] != "GLOBAL_RAW_SCALAR_PENDING_COMPLETE_SQL_ORACLE":
            continue
        query, response = row["request"]["query"], row["response"]
        assert response["ok"] is True and row["request"]["limits"] == {
            "maxCandidateDocuments":1000000,"maxPositions":10000000,
            "maxPositionsPerDocument":262144,"maxSegments":4096}
        expected = oracle["counts"][query]
        value = response["value"]
        assert all(value[key] == expected[key] for key in ("occurrences", "matchingLiveDocuments")), query
        proof = value["proof"]
        assert proof["engineCommit"] == CONSUMER and proof["originalUpstreamBase"] == PRODUCER
        assert proof["requestedFacets"] == ["/"] and proof["liveIndexDocuments"] == 7080797
        comparisons.append({"query": query, "occurrences": value["occurrences"],
                            "matchingLiveDocuments": value["matchingLiveDocuments"],
                            "originalSQLMultiplicitySHA256": expected["matchingLineMultiplicitySHA256"],
                            "actualWork": value["work"], "proof": proof})
    assert len(comparisons) == 2
    red = read("policy-actual-resources/red-2ba-attempt3/RESULT.json")
    green = read("policy-actual-resources/green-two-actual-resources/RESULT.json")
    assert red["cases"]["counts"] == {"failed":7,"passed":92,"skipped":0,"total":99}
    assert green["cases"]["counts"] == {"failed":0,"passed":99,"skipped":0,"total":99}
    policy = ROOT / "Source/Otzaria/Search/Distribution/OtzariaSearchArtifactPolicy.swift"
    assert digest(policy) == green["candidate_policy_sha256"]
    assert "private static let qualifiedContracts: Set<Contract> = []" in policy.read_text(encoding="utf-8-sig")
    assert all(green["exact_writer_methods_unchanged"].values())
    original_regression = read("regression-original-search-readiness/attempt1/RESULT.json")
    assert original_regression["passed"] and original_regression["exit"] == 0
    assert original_regression["sourceCommit"] == "6968a3db1bf31d5aef387fea5014892a8fc31e9b"
    assert original_regression["portableSearchAssertions"] == 191 and original_regression["cachedReadinessAssertions"] == 14
    assert original_regression["driverUnchanged"] and original_regression["policyUnchanged"]
    assert original_regression["policySHA256"] == green["candidate_policy_sha256"]
    verify_sealed("regression-original-search-readiness/attempt1", {"original-driver.log": original_regression["logSHA256"]})
    parity_path = ROOT / "docs/hq-integration/index-read-compatibility-20261120/ENGINE_SOURCE_PARITY.json"
    source_parity = json.loads(parity_path.read_text(encoding="utf-8-sig"))
    assert source_parity["producer_commit"] == PRODUCER and source_parity["consumer_commit"] == CONSUMER
    assert source_parity["base_is_ancestor"] is True
    assert source_parity["api_parity"]["candidate_without_added_block_is_exact_base"] is True
    assert all(value["same_bytes"] for value in source_parity["unchanged_dependencies"].values())
    result = {"status":"ACTUAL_WINDOWS_READ_AND_COUNT_QUALIFICATION_READY_FOR_OWNER_REVIEW_REGISTRY_DISABLED",
              "observedAt":datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "producerCommit":PRODUCER,"consumerCommit":CONSUMER,
              "contract":"otzaria-265-to-d5-lexical-read-v1","inputs":inputs,
              "originalSourceParitySHA256":digest(parity_path),
              "actualBinaries":{name:{"librarySHA256":build["inputs"]["librarySHA256"],
                                        "consumerExecutableSHA256":build["executableSHA256"],
                                        "consumerSourceSHA256":build["inputs"]["sourceSHA256"]}
                                 for name,build in builds.items()},
              "mini":{"legacyParityCases":21,"occurrenceSQLComparisons":33,"sourceSQLRows":18879,
                      "strictSQLLocatorComparisons":350,"actualColdProducerRollbackQueryCases":21,
                      "originalFailedEvaluatorCounts":mini["counts"]},
              "full":{"legacyParityCases":21,"defaultScopedSQLScalarMatches":20,
                      "defaultNoScalarBudgetDenialsRetained":5,"hardBoundsScopedSQLMatches":5,
                      "strictSQLLocatorComparisons":450,"actualColdProducerRollbackQueryCases":21,
                      "fullSQLRows":7080797,"fullSQLBooks":7876,"globalSQLComparisons":comparisons,
                      "independentSQLAttempt":"attempt4-partitioned","exactOriginalRowCoveragePartitions":71,
                      "fullRowIDCoverageVerifiedExactlyOnce":True,
                      "actualCRRows":oracle["actualCarriageReturnRows"],
                      "priorAttempt3":"FAILED on an invalid CR rejection assumption; no partial scalar reused or published",
                      "originalFailedEvaluatorAndBudgetCounts":full["counts"]},
              "policyPortable":{"red":red["cases"]["counts"],"green":green["cases"]["counts"],
                                "exactWriterMethodsUnchanged":green["exact_writer_methods_unchanged"]},
              "originalPortableRegressionAssertions":{"search":191,"cachedReadiness":14,"notTestCaseCount":True},
              "originalEngineCreatedFiles": {"mini":mini["additionalEngineCreatedFiles"],"full":full["additionalEngineCreatedFiles"]},
              "inputEvidenceSHA256":input_digests,"reviewerSourceSHA256":digest(Path(__file__)),
              "productionRegistryEnabled":False,"applicationEnginePinChanged":False,
              "appInstallRecovery":"PORTABLE_SOURCE_FLOW_ONLY_NOT_NATIVE",
              "AppleSDK":"NOT_RUN_BY_THIS_QUALIFICATION","Native":"NOT_RUN_BY_THIS_QUALIFICATION",
              "physicalDevice":"NOT_RUN","universalQueryCoverage":False}
    out=BUILD/"QUALIFICATION_REVIEW.json"
    assert not out.exists(), "preserve prior reviewed evidence"
    out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"status":result["status"],"globalSQLComparisons":comparisons,
                      "output":str(out),"sha256":digest(out)},ensure_ascii=False))


if __name__=="__main__":
    main()

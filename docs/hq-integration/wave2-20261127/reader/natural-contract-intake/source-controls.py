#!/usr/bin/env python3
"""Synthetic contract controls only. Never app/SQL/service/UI/PERF evidence."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import runpy
import tempfile
import types
import uuid


def digest(data):
    return hashlib.sha256(data).hexdigest()


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def witness(path):
    data = Path(path).read_bytes()
    return {"path": str(path), "bytes": len(data), "sha256": digest(data)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--baseline", type=Path, required=True)
    parser.add_argument("--natural-helper", type=Path, required=True)
    parser.add_argument("--selected-candidates", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    helpers = runpy.run_path(str(args.natural_helper))
    selected = json.loads(args.selected_candidates.read_bytes())
    candidates = helpers["admit_candidates"](selected)
    assert [x["candidateRawRelationshipCount"] for x in candidates] == [100, 500, 2006]
    results = []
    with tempfile.TemporaryDirectory(prefix="synthetic-natural-contract-") as temporary:
        root = Path(temporary)
        scripts = root / "Scripts/CI"
        scripts.mkdir(parents=True)
        wrapper = scripts / "reader-full-v40-ui-observation.py"
        wrapper.write_bytes(args.candidate.read_bytes())
        (scripts / "reader-v40-natural-inspector-catalog.py").write_bytes(args.natural_helper.read_bytes())
        candidate_path = root / "synthetic-fixture/selected-candidates.json"
        candidate_path.parent.mkdir()
        candidate_path.write_bytes(args.selected_candidates.read_bytes())
        write(wrapper.with_suffix(".inputs.json"), {"natural_inspector_catalog": {
            "candidates_file": candidate_path.relative_to(root).as_posix()}})
        current = runpy.run_path(str(wrapper))
        baseline = runpy.run_path(str(args.baseline))

        def fixture(name):
            out = root / "synthetic-fixture" / name
            catalog_root = out / "natural-inspector-catalog"
            scales, completion_rows, sql_targets = [], [], []
            for candidate in candidates:
                count = candidate["candidateRawRelationshipCount"]
                requested = candidate["requestedCount"]
                key = "SYNTHETIC_IDENTITY_PROJECTION_" + str(requested)
                identities = [{"ordinal": i, "id": "synthetic-" + str(i),
                    "sourceRef": "synthetic-ref-" + str(i), "rawProviderPayload": "synthetic-payload-" + str(i)}
                    for i in range(count)]
                encoded = bytearray()
                values = ["otzaria.original-inspector-membership/1", str(count)]
                for i, identity in enumerate(identities):
                    values.extend([str(i), identity["id"], identity["sourceRef"], identity["rawProviderPayload"]])
                for value in values:
                    raw = value.encode()
                    encoded.extend(len(raw).to_bytes(8, "big")); encoded.extend(raw)
                projection = {"schema": 1, "status": "ORIGINAL_IDENTITY_PROJECTION_REQUIRES_NATIVE_ARRAY_COMPARISON",
                    "count": count, "identityDigestEncoding": helpers["IDENTITY_ENCODING"],
                    "identities": identities, "orderedIdentitySHA256": digest(encoded), "hashedBytes": len(encoded)}
                projection_path = catalog_root / (key + ".json")
                write(projection_path, projection)
                scale = {"requestedCount": requested, "originalMetadataCount": count,
                    "target": {"key": key, "bookID": candidate["bookID"], "unitID": candidate["unitID"]},
                    "identityProjectionFile": projection_path.name,
                    "identityProjectionBytes": projection_path.stat().st_size,
                    "identityProjectionSHA256": witness(projection_path)["sha256"],
                    "nativeOrderedIdentitySHA256": projection["orderedIdentitySHA256"],
                    "nativeIdentityHashedBytes": projection["hashedBytes"],
                    "rawMembershipSHA256": candidate["rawMembershipSHA256"]}
                scales.append(scale)
                completion_rows.append({"requestedCount": requested, "actualCount": count,
                    "targetKey": key, "observationID": str(uuid.uuid4()).upper(),
                    "atLeastRequestedCount": True, "exactRequestedCount": count == requested,
                    "nativeFullMembershipMatched": True,
                    "nativeOrderedIdentitySHA256": scale["nativeOrderedIdentitySHA256"],
                    "identityProjectionSHA256": scale["identityProjectionSHA256"],
                    "independentCompleteMembershipSHA256": scale["rawMembershipSHA256"]})
                sql_targets.append({"bookID": candidate["bookID"], "unitID": candidate["unitID"],
                    "sourceLineIndices": candidate["sourceLineIndices"],
                    "completeMembership": candidate["candidateRawMembership"],
                    "membershipSHA256": candidate["rawMembershipSHA256"]})
            sql_path = catalog_root / "installed-sql-memberships.json"
            write(sql_path, {"status": "EXACT_INSTALLED_SQL_MEMBERSHIP_NOT_SWIFT_OR_NATIVE_ACCEPTANCE",
                "databaseSHA256": helpers["DATABASE_SHA256"], "databaseBefore": {"synthetic": True},
                "databaseAfter": {"synthetic": True}, "targets": sql_targets})
            compile_path = catalog_root / "compile-inputs.json"
            write(compile_path, {"synthetic": True, "compilerExecuted": False})
            catalog = {"schema": 1, "corpusProfile": "full-v40",
                "status": "ORIGINAL_NATURAL_UNIT_AND_METADATA_CATALOG_NOT_NATIVE_ACCEPTANCE",
                "databaseSHA256": helpers["DATABASE_SHA256"],
                "candidateReceiptSHA256": witness(candidate_path)["sha256"],
                "installedSQLReceiptSHA256": witness(sql_path)["sha256"],
                "compileInputsSHA256": witness(compile_path)["sha256"], "scales": scales}
            catalog_path = catalog_root / "natural-inspector-targets.json"
            write(catalog_path, catalog)
            for row, scale in zip(completion_rows, scales):
                row["naturalCatalogSHA256"] = witness(catalog_path)["sha256"]
                request = row["observationID"]
                native = {"orderedIdentitySHA256": scale["nativeOrderedIdentitySHA256"],
                    "identityDigestEncoding": helpers["IDENTITY_ENCODING"],
                    "hashedBytes": scale["nativeIdentityHashedBytes"], "synthetic": True}
                raw_path = out / "synthetic-native" / (request + ".json")
                write(raw_path, native)
                observed = {"request_id": request, "target_key": row["targetKey"],
                    "native_report_file": witness(raw_path), "native_report": native,
                    "full_cached_count": row["actualCount"], "actual_visible_rows": [{"synthetic": True}],
                    "native_ordered_identity_sha256": scale["nativeOrderedIdentitySHA256"]}
                write(out / "inspector-proofs" / (request + ".json"), observed)
                proof = helpers["match_native_projection"](scale, observed, {
                    "fullCachedCount": row["actualCount"], "nativeOrderedIdentitySHA256": row["nativeOrderedIdentitySHA256"]})
                proof["naturalCatalog"] = witness(catalog_path)
                write(out / "natural-inspector-membership-proofs" / (request + ".json"), proof)
            completion = {"scales": completion_rows, "observationIDs": [x["observationID"] for x in completion_rows],
                "exact_size_criterion_met": False, "natural_at_least_workloads_met": True}
            write(out / "original-inspector-scales.json", completion)
            write(out / "result.json", {"corpus_profile": "full-v40",
                "status": "ORIGINAL_UI_OBSERVATIONS_COMPLETE_METRICS_REVIEW_REQUIRED",
                "database_bytes_unchanged": True, "source_and_built_binary_bytes_unchanged": True,
                "source": {"SYNTHETIC_CONTROL_ONLY": True}, "cleanup_or_post_verification_failures": [],
                "reused_external_owned_simulator": str(uuid.uuid4()).upper()})
            return out

        def alter(path, change):
            document = json.loads(path.read_bytes()); change(document); write(path, document)

        def control(name, mutator=None, old=False, succeeds=False):
            out = fixture(name)
            if mutator: mutator(out)
            core = types.SimpleNamespace(OUT=out, witness=witness, write=write,
                bounded_json=lambda path, maximum: json.loads(Path(path).read_bytes()))
            error = None
            try:
                (baseline["require_exact_inspector_scales"] if old else current["require_natural_inspector_scales"])(core)
            except Exception as caught:
                error = {"type": type(caught).__name__, "message": str(caught)}
            actual = error is None
            result = {"name": name, "passed": actual == succeeds, "expectedAdmitted": succeeds,
                "actuallyAdmitted": actual, "error": error, "syntheticOnly": True}
            if actual and not old:
                receipt = json.loads((out / "v40-natural-inspector-final-gate.json").read_bytes())
                result["actualCounts"] = receipt["actual_counts"]
                result["exactSizeCriterionMet"] = receipt["exact_size_criterion_met"]
                assert receipt["actual_counts"] == [100, 500, 2006] and receipt["exact_size_criterion_met"] is False
            results.append(result)

        control("historical-extra-exact-gate-rejects-complete2006", old=True)
        control("original-at-least-contract-accepts-complete2006", succeeds=True)
        control("under-threshold-count-rejected", lambda out: alter(out / "original-inspector-scales.json",
            lambda d: d["scales"][2].update(actualCount=1999)))
        control("false-exact-claim-rejected", lambda out: alter(out / "original-inspector-scales.json",
            lambda d: d["scales"][2].update(exactRequestedCount=True)))
        control("duplicate-natural-target-rejected", lambda out: alter(out / "original-inspector-scales.json",
            lambda d: d["scales"][2].update(targetKey=d["scales"][1]["targetKey"])))
        def corrupt_projection(out):
            catalog = json.loads((out / "natural-inspector-catalog/natural-inspector-targets.json").read_bytes())
            path = out / "natural-inspector-catalog" / catalog["scales"][2]["identityProjectionFile"]
            alter(path, lambda d: d["identities"][1000].update(id="CHANGED_INTERIOR"))
        control("interior-projection-corruption-rejected", corrupt_projection)
        control("native-array-report-change-rejected", lambda out: alter(next((out / "synthetic-native").glob("*.json")),
            lambda d: d.update(orderedIdentitySHA256="0" * 64)))
        control("missing-complete-membership-proof-rejected", lambda out:
            next((out / "natural-inspector-membership-proofs").glob("*.json")).unlink())
        control("original-postcheck-failure-rejected", lambda out: alter(out / "result.json",
            lambda d: d.update(cleanup_or_post_verification_failures=["synthetic failure"])))
    report = {"schema": 1, "status": "SYNTHETIC_CONTRACT_CONTROLS_ONLY_NOT_NATIVE_ACCEPTANCE",
        "passed": sum(x["passed"] for x in results), "total": len(results), "controls": results,
        "inputs": {key: witness(getattr(args, key)) for key in
            ("candidate", "baseline", "natural_helper", "selected_candidates")},
        "compilerExecuted": False, "databaseOpened": False, "nativeUIExecuted": False}
    write(args.output, report)
    print(json.dumps({key: report[key] for key in ("status", "passed", "total")}))
    if not all(x["passed"] for x in results):
        raise SystemExit(1)


if __name__ == "__main__":
    main()

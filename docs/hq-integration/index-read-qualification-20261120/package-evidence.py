#!/usr/bin/env python3
"""Package already completed owned evidence; never run or qualify an engine."""
import argparse
import datetime
import gzip
import hashlib
import json
from pathlib import Path


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", type=Path, required=True)
    args = parser.parse_args()
    root = args.repository.resolve()
    build = root / "build/index-read-qualification-20261120"
    review_path = build / "QUALIFICATION_REVIEW.json"
    review = json.loads(review_path.read_text(encoding="utf-8"))
    assert review["status"] == "ACTUAL_WINDOWS_READ_AND_COUNT_QUALIFICATION_READY_FOR_OWNER_REVIEW_REGISTRY_DISABLED"
    assert review["productionRegistryEnabled"] is False
    assert review["applicationEnginePinChanged"] is False
    oracle = json.loads((build / "full-sql-global-oracle/attempt4-partitioned/RESULT.json").read_text(encoding="utf-8"))
    assert oracle["partial"] is False and oracle["rowsScanned"] == 7080797
    assert oracle["partitionCount"] == 71 and oracle["allOriginalRowIDsVerifiedExactlyOnce"]
    for name, expected in review["inputEvidenceSHA256"].items():
        assert sha((build / name).read_bytes()) == expected, name
    files = {review_path}

    def direct_files(directory, suffixes):
        if directory.is_dir():
            files.update(p for p in directory.iterdir() if p.is_file() and p.suffix in suffixes)

    for profile in ("miniTest10-v6", "full-v32"):
        for name in ("GITHUB_RELEASE.json", "INPUT_VERIFIED.json", "otzaria-search-manifest.json"):
            files.add(build / "artifacts" / profile / name)
        files.add(build / "read-copies" / profile / "COPY_VERIFIED.json")
        directory = build / "runtime" / profile
        direct_files(directory, {".json", ".log", ".tsv"})
        for attempt in directory.iterdir():
            if attempt.is_dir():
                direct_files(attempt, {".json", ".log", ".tsv"})
    direct_files(build / "runtime", {".log", ".json"})
    for engine in ("265", "d5"):
        direct_files(build / "binaries" / engine, {".json", ".log", ".h"})
    direct_files(build / "source-snapshots", {".py", ".c"})
    for name in ("full-sql-global-oracle", "policy-actual-resources", "regression-original-search-readiness", "producer-intermediate-cleanup-20261120"):
        directory = build / name
        direct_files(directory, {".json", ".log", ".py"})
        for attempt in directory.iterdir():
            if attempt.is_dir():
                direct_files(attempt, {".json", ".log", ".py", ".swift"})
    names = {p.relative_to(build).as_posix() for p in files}
    assert set(review["inputEvidenceSHA256"]) <= names
    assert len([n for n in names if n.startswith("full-sql-global-oracle/attempt4-partitioned/partition-")]) == 71
    blobs = {}
    for path in sorted(files):
        assert path.is_file() and not path.is_symlink(), path
        assert path.stat().st_size < 8 * 1024 * 1024, path
        blobs[path.relative_to(build).as_posix()] = path.read_bytes()
    assert sum(map(len, blobs.values())) < 80 * 1024 * 1024
    tools = [
        "Tests/HQ/search/OriginalIndexReadConsumer.c",
        "tools/hq-otzaria-old-index-inputs.py",
        "tools/hq-otzaria-old-index-runtime.py",
        "tools/hq-otzaria-original-index-locator-review.py",
        "tools/hq-otzaria-full-index-hard-bound-review.py",
        "tools/hq-otzaria-full-sql-occurrence-oracle.py",
        "tools/hq-otzaria-full-sql-occurrence-partitions.py",
        "tools/hq-otzaria-old-index-qualification-review.py",
        "tools/otzaria_original_sql_oracle.py",
    ]
    source_hashes = {name: sha((root / name).read_bytes()) for name in tools}
    assert source_hashes["tools/hq-otzaria-old-index-qualification-review.py"] == review["reviewerSourceSHA256"]
    assert source_hashes["tools/hq-otzaria-full-sql-occurrence-partitions.py"] == oracle["sourceSHA256"]
    assert source_hashes["tools/otzaria_original_sql_oracle.py"] == oracle["scannerSHA256"]
    docs = root / "docs/hq-integration/index-read-qualification-20261120"
    assert not docs.exists(), "preserve any earlier package instead of overwriting it"
    docs.mkdir(parents=True)
    ledger = []
    for name, raw in sorted(blobs.items()):
        stored = gzip.compress(raw, compresslevel=9, mtime=0)
        relative = "raw/" + name + ".gz"
        destination = docs / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(stored)
        assert gzip.decompress(destination.read_bytes()) == raw
        ledger.append({"originalPathRelativeToOwnedBuild": name, "path": relative,
                       "originalBytes": len(raw), "originalSHA256": sha(raw),
                       "storedBytes": len(stored), "storedSHA256": sha(stored)})
    package_source = Path(__file__).read_bytes()
    (docs / "package-evidence.py").write_bytes(package_source)
    (docs / "QUALIFICATION_REVIEW.json").write_bytes(review_path.read_bytes())
    manifest = {
        "createdAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "ownedBuildRoot": str(build), "noIndexArchiveOrDatabaseCopiedIntoGit": True,
        "rawEvidenceFiles": len(ledger), "uncompressedBytes": sum(e["originalBytes"] for e in ledger),
        "storedBytes": sum(e["storedBytes"] for e in ledger),
        "qualificationReviewSHA256": sha(review_path.read_bytes()),
        "packagingSourceSHA256": sha(package_source), "sourceFilesSHA256": source_hashes,
        "entries": ledger,
    }
    (docs / "SHA256SUMS.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    global_rows = "\n".join(
        f"| {x['query']} | {x['occurrences']:,} | {x['matchingLiveDocuments']:,} | exact match |"
        for x in review["full"]["globalSQLComparisons"])
    text = f"""# Original 265 index to d5 reader — actual qualification evidence

The original published miniTest10 v6 and full v32 indices were opened by separately built original 265 and candidate d5 engines in owned read copies. The original payloads and databases were never rebuilt. The complete independent full SQL scan finished and both supported global occurrence results match it exactly. The production compatibility registry is still **OFF**; this package is ready for the owner's integration review.

This is the exact directional contract otzaria-265-to-d5-lexical-read-v1: producer 265a14ea54f959a3e266d6e8acfa3a3b98101d68 from Otzaria/otzaria_search_engine to consumer d5d59d1269bdf87fb0a6901cf31941726a0c699b from davidpovarsky/otzaria_search_engine. It is not a generic schema-compatible allowance. The new occurrence API is scoped to an exact, non-fuzzy query that the original analyzer accepts as one token; phrase/proximity and semantic counts are outside this qualification.

## Authenticated inputs and actual engine binaries

| Input | Original document count | Original raw manifest SHA-256 |
| --- | ---: | --- |
| miniTest10-v6, release 410332048 | 18,879 | ae3bd170dc4650806a9fdda1beefe682eeefb5abde886363d6feac999603f8d4 |
| full-v32, release 419282321 | 7,080,797 | 34319ced48e76f22a5ae2df23745a03332160ddab2dd64244a5c917e0ce00a57 |

Every original archive was checked against its published digest before extraction. The pristine input directory already contained the original nonempty meta/segment payload before either engine opened a read copy. COPY_VERIFIED receipts record separate owned producer/candidate copies. No user index was opened. The existing owned full database was reused without another database download.

The full source database has 7,876 books, 7,080,797 rows, 3,821,240,320 bytes, and SHA-256 2f4dcd72e8bdb1fc5c0516ae9705e57759c017ec2981b49c35115625c3d3f765. The mini source database has 15,470,592 bytes and SHA-256 d3d9bfcc2320a987a0391ad23fa72abcf6fd1fa0f3cba95adc05096e05a9edef. Before/after hashes remain identical.

The Windows baseline static library SHA-256 is 16f6d54b9bacc49d708da4017051ebac0825c1f2adae163bf53a3908bb8b6cf7. The candidate static library SHA-256 is 7f23e3e87aa604b410f9cd21f1b56aab2d30596c697d46c8fb19ad160e34c7a0, from bridge producer 99f7927e4da72f2463417f5c2de2c4d20c6aa168. Exact compile/link commands, library and executable hashes, real C build-info responses, and raw standard output are retained. The C consumer never calls add, delete, commit, or reindex APIs.

## What ran and passed

| Actual evidence | miniTest10 | full v32 |
| --- | ---: | ---: |
| Original versus candidate complete legacy JSON comparisons | 21 | 21 |
| Strict returned locator to original SQL row comparisons | 350 | 450 |
| Actual original-engine cold reopen after candidate access | 21 queries | 21 queries |
| Supported occurrence scalars compared with independent scoped SQL | 33 | 20 at default bounds plus 5 at published hard bounds |

Legacy comparisons cover exact phrase, exact word, fuzzy, book/facet filtering, pages, relevance/catalogue order, advanced distance/negative/paragraph, same-section/identical-text grouping, absent terms, and book/facet counts. Equality includes result ordering, identities, segment locators, text, highlights, and counts. An empty vocalized mini result remains an honest empty result. These are a finite reviewed matrix, not universal query coverage.

The original packed result ID is preserved. Strict source checks bind its ordinal bits and its zero-based segment to the actual SQL book/line index and source text. The original Tantivy snippet is bounded and HTML escaped, so source validation decodes its original escaping and removes only generated highlight tags before checking the actual source substring. It does not mislabel the packed ID as a database primary key or require a bounded snippet to equal the entire source line.

Both engines created the original small otzaria_index_meta.json descriptor and zero-length Tantivy lock files in their owned read copies. The descriptor records schema/engine/Tantivy versions and time; it does not restamp the index with the consumer commit. The seven published payload files and all existing/created metadata bytes were checked across candidate access and actual original-engine rollback. The read contract does not relax writer, seed, or checkpoint identity equality.

## Complete independent occurrence oracle

The original SQL/zstd data was read independently of the engine and index. A retained original dictionary decodes each SQL row. The optimized scanner follows the original 265 normalization/tokenization domain and was compared against a separate scalar implementation over all 18,879 mini rows, all 3,535 rows of the actual offending CR book, 5,000 grammar controls, 18 existing scanner controls, 11 new CR controls, and two retained LF-boundary rejections. Thirty-two decompressions were independently byte-compared.

The full scan covered all 7,080,797 original row IDs exactly once in 71 sealed partitions. A final second traversal of SQL primary keys checked each partition's coverage digest and order; the full database hash was checked before and after. The final scan reports {oracle['actualCarriageReturnRows']:,} rows containing CR and {oracle['actualCarriageReturns']:,} CR characters, {oracle['actualNormalizationCrossChecks']:,} actual normalization checks, and {oracle['actualSQLScalarParityControls']:,} scalar parity checks. The complete elapsed time was {oracle['seconds']} seconds. Partial partition counts were never published as a full result.

| Original token | SQL occurrences | SQL matching documents | Actual candidate C result |
| --- | ---: | ---: | --- |
{global_rows}

These two global requests and the five previously budget-denied scoped requests use the published hard limits: 1,000,000 candidate documents, 10,000,000 positions, 262,144 positions per document, 4,096 segments, and a 60-second request deadline. The original five default-budget denials remain recorded with no scalar. Work counts describe actual postings traversal, including documents excluded later by scope; they are not relabeled as scoped hits.

## Failures retained and corrected

Original mini attempt3 remains **74/75**, and original full attempt1 remains **81/96** in their immutable reports. The later reviewer does not overwrite them. The mini failure and one full failure were incorrect new evaluator assumptions about packed IDs and bounded snippets; strict corrected SQL checks passed 350 and 450 actual locators. Five full requests correctly returned budget_exceeded at the default limit, causing their scalar/proof checks to fail; all five later completed under the published hard bounds and matched independent SQL. Four further original proof checks incorrectly required insertion-order facet arrays; the actual canonical facet set and all held-snapshot identity fields were subsequently verified.

The first full SQL attempts were explicitly stopped because the independent Python scan was too slow. Attempt3 then failed on a wrong harness assumption that CR is a document delimiter. The exact original source splits only on LF and normalizes CR as whitespace. Actual row 6105588 in book 7428 contains 22 CR and zero LF; that failed record and log remain preserved. Corrected attempt4 was validated against the real affected book and complete mini database before a fresh complete scan. None of attempt3's partial scalars were reused. Initial C link/stack failures and earlier evaluator failures are retained separately and receive no runtime credit.

## Policy and source parity

The whole original Swift policy and producer-preserving install/recovery paths were exercised with meaningful negative cases. The identical fixture produced **92/99** against the earlier three-resource runtime assumption and **99/99** against the correction that projects the two actual required C resources while still validating the full three-resource manifest. The registry remains empty. Original checkpoint/seed writer methods remain byte-identical. Existing search/readiness regression produced **191 search assertions plus 14 cached-readiness assertions**; those are assertion counts, not 205 XCTest cases.

The immutable ENGINE_SOURCE_PARITY.json in the preceding index-read-compatibility evidence binds the exact 265 ancestor to d5. Removing only the additive API block gives the exact original search_engine.rs bytes; original Cargo.toml/Cargo.lock and the indexed semantics are unchanged. App coverage must separately retain the complete authenticated producer manifest and current managed database fingerprint. A bare identity helper or custom database is insufficient occurrence-count proof.

## Limits and ownership

The actual local engine qualification used Windows lexical builds with no default features. It does not claim Apple runtime occurrence execution, a complete new Apple app build, Native install/recovery, Native UI acceptance, physical-device acceptance, semantic-search equivalence, or every possible query. Separate authenticated Apple framework evidence lives in the occurrence-apple-framework-44661774024-20261120 directory and retains the original overall workflow FAILURE alongside successful framework jobs.

The policy's production registry and application engine pin are unchanged by this package. Enabling the exact reviewed read contract requires the owner's integration review and separately owned managed coverage/Native gates. Writer identity remains exact; there is no index restamping or generic descendant compatibility rule.

## Reproduction and evidence map

QUALIFICATION_REVIEW.json is the machine-readable sealed review. SHA256SUMS.json records both the original and stored deterministic-gzip hashes for every raw evidence file. Raw C response logs, commands, complete result objects, original manifests, archive verification receipts, before/after inventories, rollback runs, source snapshots, failures, and all 71 SQL coverage partitions are included. Large database/index/library/executable payloads remain in their owned authenticated locations and are represented by their exact verified digests.

The source files listed in SHA256SUMS.json are committed with this package. The final reviewer never opens an engine or database; it parses and hashes the completed original records, compares complete SQL counts to actual C scalars, and checks that production remains disabled. The packaging script only preserves evidence after that reviewer has succeeded.
"""
    (docs / "README.md").write_text(text, encoding="utf-8", newline="\n")
    print(json.dumps({"docs": str(docs), "rawEvidenceFiles": len(ledger),
                      "storedBytes": manifest["storedBytes"],
                      "reviewSHA256": manifest["qualificationReviewSHA256"],
                      "sourcePaths": tools}, ensure_ascii=False))


if __name__ == "__main__":
    main()

# Original 265 index to d5 reader — actual qualification evidence

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

The full scan covered all 7,080,797 original row IDs exactly once in 71 sealed partitions. A final second traversal of SQL primary keys checked each partition's coverage digest and order; the full database hash was checked before and after. The final scan reports 7 rows containing CR and 37 CR characters, 1,007 actual normalization checks, and 1,239 scalar parity checks. The complete elapsed time was 2697.859 seconds. Partial partition counts were never published as a full result.

| Original token | SQL occurrences | SQL matching documents | Actual candidate C result |
| --- | ---: | ---: | --- |
| בראשית | 143,982 | 104,120 | exact match |
| אברהם | 170,515 | 109,419 | exact match |

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

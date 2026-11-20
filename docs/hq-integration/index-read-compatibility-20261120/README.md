# Exact directional lexical READ candidate — production admission disabled

Base: `7e777509d486a17bec5b4bd437a9ac7f51d3a43a`.
Branch: `codex/otzaria-index-read-compatibility-20261120`.
Owned worktree: `C:\Users\DAVID\Code\Maktabah-index-read-compatibility-20261120`.

This tranche implements a candidate compatibility policy and fixes producer metadata preservation. **It does not qualify or enable a new runtime, change an engine pin, accept an old index in production, or claim a Native/Apple/real-index test.** The production `qualifiedContracts` set is empty and immutable. Existing exact-producer admission remains in force.

## Why the change is needed

The reviewed engine adds one bounded occurrence-count method to the original `SearchEngine` implementation. The producer of the existing official lexical indexes is still `Otzaria/otzaria_search_engine` at `265a14ea54f959a3e266d6e8acfa3a3b98101d68`. The candidate consumer truthfully identifies itself as `davidpovarsky/otzaria_search_engine` at `d5d59d1269bdf87fb0a6901cf31941726a0c699b`. Repository, commit and schema identity cannot be replaced with a generic same-schema or descendant exemption.

The existing bulk installer, streaming installer and managed-index recovery construct index identity from the current runtime's build information. That is correct while producer and consumer are identical. Under a prospective directional read exemption, those three paths would relabel the old index as produced by the new engine. This would erase provenance, break the old runtime's metadata rollback check, and make a read contract appear to be a writer contract.

The new identity constructor records engine fields and resource values from the original artifact manifest. It retains the previous required-resource projection for exact-build artifacts, the current database fingerprint, the manifest's catalogue hash, and the existing nil semantic registration. The trusted manifest, its artifact identity, the index payload and Tantivy metadata are not restamped. The consumer's real build information remains unchanged.

## Candidate and qualification are separate

`OtzariaLexicalIndexReadCompatibility.candidateContract` recognizes exactly one direction:

| Field | Original producer | Candidate consumer |
|---|---|---|
| Repository | `Otzaria/otzaria_search_engine` | `davidpovarsky/otzaria_search_engine` |
| Commit | `265a14ea54f959a3e266d6e8acfa3a3b98101d68` | `d5d59d1269bdf87fb0a6901cf31941726a0c699b` |
| Consumer branch | — | `codex/otzaria-exact-occurrences-20261120` |
| Engine / adapter versions | `0.1.0` / `0.1.0` | `0.1.0` / `0.1.0` |
| Index schema / generation | `4` / `5` | `4` / `5` |
| Producer Tantivy | `0.26.1` | Immutable engine dependency lock is identical; actual binary still requires qualification |
| Semantic sidecar revision | `e836ea6cac05e695efdb03ef227e78cd1a624149` | Same revision |
| Lexical resources | Exact canonical three-resource SHA-256 map | Same exact map |

The contract ID is `otzaria-265-to-d5-lexical-read-v1`. A changed repository, branch, commit, future descendant, schema, generation, adapter, engine version, semantic revision, resource hash or resource set is ineligible. Equality of versions or schema alone does not admit anything.

`validateReadCompatibilityCandidate` is a qualification probe. It applies the same original format, profile, active-profile, source-database, resource, document/source totals, part digest format, offset, path, compression and extracted-layout gates as normal validation. Returning a candidate ID does not insert it into the production registry and cannot authorize normal discovery or installation. There is no environment variable, preference, manifest flag or test switch that enables the production registry.

`identityMatchesArtifactProducer` is a pure metadata binding, also not authorization. It checks the actual producer commit, engine, schema, generation, adapter, catalogue and resource fields. Existing identity JSON has no producer repository field. Therefore the production cross-revision identity path additionally requires a fully validated trusted original manifest and a runtime-qualified directional contract. A bare commit in a local identity is insufficient.

## Caller inventory and defaults

| Caller | Change / retained behavior |
|---|---|
| `OtzariaSearchArtifactInstaller.install` | Constructs identity from the producer manifest; original path/extraction/engine/count/promotion/rollback gates retained. |
| `OtzariaSearchArtifactInstaller.installStreaming` | Same producer preservation; original context, cancellation, deletion-after-extraction and atomic promotion behavior retained. |
| `OtzariaSearchIndexManager.recoverTrustedManagedIndex` | Repairs identity to original producer fields after the same full manifest, compatibility and exact document-count checks. Correct existing producer metadata is not rewritten. |
| `OtzariaSearchIndexManager.validateCurrentIndex` | For a managed cross-revision identity only, obtains a fully validated trusted manifest through the new read-only `trustedManagedReadManifest` helper. Normal policy still denies the unqualified contract. |
| `OtzariaSearchIndexManager.trustedManagedArtifactIdentity` | Unchanged normal policy call; candidate artifacts remain unavailable. |
| `OtzariaSearchArtifactReleaseClient` (both validation sites) | Unchanged normal policy calls; candidate discovery remains denied. |
| `OtzariaPrebuiltSearchAcceptanceRunner` | Unchanged normal policy call; candidate runtime acceptance remains denied. |
| `ActionLiveReadinessProof.otzaria` in `ActionLiveBackendBridge.swift` | Unchanged. Its identity check passes no trusted manifest and therefore remains default-deny for a cross-revision producer. Any later integration must validate the managed manifest before supplying producer proof, without invoking recovery as an availability side effect. |
| External/custom indexes | No cross-revision exception added. Existing exact fingerprint/commit/resource requirements remain. |
| Writer identity, partial-build resume and final-index seeding | `makeIdentity`, `prepareOrResumeBuildingIndex`, and `canSeedBuildingIndex` are byte-identical to the base. They continue using exact writer identities, never a READ contract. |

The custom-database action readiness path's existing `count > 0` with no expected total is not a full-universe occurrence proof. This tranche neither changes that behavior nor uses it to advertise exact occurrence availability.

## Actual portable results

Executed on the configured Windows host with Swift 6.3.3, compiling actual current and baseline Swift policy and exact original control-flow methods:

| Run | Result | Meaning |
|---|---|---|
| Final baseline flow control at the exact base | **87 / 92 PASS, 5 FAIL, 0 SKIP** | Under an explicitly controlled candidate policy authority, the original two installers and three recovery scenarios expose producer restamping. |
| Final candidate | **92 / 92 PASS, 0 FAIL, 0 SKIP** | Producer preservation, normal default-deny, full candidate metadata policy, relevant negative inputs, rollback metadata, recovery/cancellation/failed promotion, engine lifetime, and exact-writer controls. |
| Original `tools/hq-search-tests.py` | **191 search assertions + 14 cached-readiness assertions PASS** | Existing public policy call sites and existing portable search behavior retain their assertions. FFI and Combine remain explicit doubles in that existing harness. |

The final baseline failures are:

1. `install_bulk_preserves_producer_and_old_reader_rollback`
2. `install_stream_preserves_producer_and_old_reader_rollback`
3. `recovery_preserves_original_producer_across_path_change`
4. `recovery_existing_correct_producer_does_not_rewrite_identity`
5. `recovery_repairs_consumer_restamp_from_original_manifest`

These are latent control-flow failures under the test's explicit candidate authority. They do not claim that the previously shipping exact-only policy already admitted d5, or that actual user data was restamped.

The fixture compiles the complete actual policy (only type names are changed to coexist with the baseline). The flow fixture extracts original installer, promotion, trusted-manifest, recovery, readiness, writer, checkpoint and seeding method bodies. Filesystem operations and Swift Codable/cancellation behavior are real. Provider/profile authority, engine compatibility/count/open, raw data extraction, storage locking/capacity and backup metadata are named test boundaries. The extractor does not decompress Zstd, and the engine boundary does not open Tantivy. The fixture-only policy authority calls the candidate qualification probe; it does not alter the production registry. The baseline and candidate use the same fixture source.

The actual original miniTest10-v6 and production-v32 manifest files are used for policy metadata probes. Flow tests use a separate tiny controlled database/payload and manifest projection. They cannot establish real old-index compatibility, actual query parity, archive integrity, real engine counts, rollback execution or app readiness.

Reproduction:

```text
python tools/hq-otzaria-read-compatibility.py --baseline-flows --artifacts-dir build/read-compatibility/red
python tools/hq-otzaria-read-compatibility.py --artifacts-dir build/read-compatibility/green
python tools/hq-search-tests.py
```

`--swiftc` accepts an explicit installed compiler path. JSON reports include source, generated Swift, fixture, runner and original manifest hashes, named outcomes, exact unchanged-writer comparisons and compiler version. Both expected red and actual green logs are retained as lossless `.log.gz` files; `RAW_LOG_DIGESTS.json` records their original and compressed SHA-256 digests. The final combined Sentinel job was `job_6dcf286b0cc5` (2026-11-20 02:15:39–02:17:10 UTC). Earlier 84-case runs are retained as preparation evidence; the final 92-case source is authoritative.

## Immutable engine source evidence

`ENGINE_SOURCE_PARITY.json` records checks against the exact committed Git objects, not a dirty working checkout. Producer tree: `6bb0edcf848608ec9b577d678f12b2c4b162a3d8`; consumer tree: `c3b420c312480437ae4194be0dd554a07d58bbb5`.

The producer is an ancestor of the consumer. `rust/src/api/search_engine.rs` has one 42-line addition; removing that exact added span from d5 reproduces the complete original 265 file byte-for-byte. Existing schema, tokenizer, index-write, query and metadata methods in that file are unchanged. `rust/Cargo.toml` and `rust/Cargo.lock` are byte-identical. Other changed engine paths are listed, including additive module registration and the diagnostic/benchmark fixture hygiene changes. This is precise source evidence, not a claim that every changed file is identical or that an old index was opened.

Consumer Tantivy version is not exposed by the existing Swift build-info model. The unchanged immutable dependency lock is part of the candidate's source evidence; actual built-library provenance and old-artifact runtime tests remain prerequisites to qualification.

## Remaining qualification gates — NOT RUN by this tranche

Before any production enable, use owned copies of the original producer's published artifacts with verified manifests and archive digests. Ensure their original metadata and segments already exist before opening either engine. Compare original265 and actual d5 legacy exact/fuzzy/filter/page/ranking/locator results, actual document counts and new occurrence results against independent source data. Compare original payload/metadata hashes before and after, with any transient lock files reported separately. Opening a fresh index or rebuilding from the database is not old-index compatibility evidence.

Then verify actual app discovery, download/resume (including the existing strict 1,048,576-byte gate), installation, failure/rollback, existing installed-index reuse, cancellation, cold relaunch and full-v32 acceptance under the real candidate binary. Producer identity must remain original while consumer build information remains truthful. Malformed/tampered identity, resource, manifest and payload cases must preserve the committed index. The normal action readiness caller needs its separately reviewed producer-proof ordering before it can use a future qualified contract.

The production set remains empty pending that evidence and review. This commit does not change an engine pin, build script, workflow, manifest selection, production feature availability, Core package, upstream UI or user index. No Apple SDK, Native, physical-device or real old-index execution is claimed here.

## Ownership and rollback

All three production files are in the existing downstream `Source/Otzaria/Search` namespace. No upstream Maktabah-owned source, vendored engine source, Xcode target registration or package interface changes are required. The existing portable search fixture gains one nil-returning dependency stub because it compiles the actual index-validation method independently. New portable fixtures and their runner are downstream test infrastructure.

Reverting this tranche restores the old strict policy and old identity constructors. Because this tranche never enables a READ contract and preserves the old producer identity/JSON shape, it does not require a data migration, index rebuild, new download or producer restamping for rollback.

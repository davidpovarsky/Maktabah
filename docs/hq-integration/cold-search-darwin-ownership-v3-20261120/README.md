# Cold search ownership v3: missing-input fixture correction

## Actual v2 result retained

Run `44770208643`, attempt 1, executed commit `96f2b8a34259032c9328d972b8eacbdc94121e81` on `codex/otzaria-cold-search-ownership-v2-20261120`. Job `136405525120` ran from 16:08:00 to 16:09:58 UTC on 20 November 2026. Both Swift compilations succeeded. The pre-guard case produced its exact expected `stale_constructor_performed_more_native_work` failure and **qualified as the intended RED**. The candidate completed all 32 cases: **31 PASS, 1 FAIL**, zero skips. The workflow correctly failed.

The sole candidate failure was `missing_index_is_not_created`, with `wrong_or_missing_refusal`. Its actual observed refusal was `source_changed`; the unchanged expected set was `filesystem_or_boundary_error,unavailable`. Its compatibility, constructor, configuration, count and close counters were all zero. No native engine handle was opened.

The v2 run also directly observed the original URL setup problem: the URL made before the directory existed lacked a directory hint, while the same manager returned the existing directory URL with a trailing slash. The exact equality was false. The deterministic cache barrier passed and recorded attempt 2 with all three original outer storage owners free. Those observations do not authorize relaxing the product's exact URL, source, lock or deadline guards.

The complete authenticated v2 artifact is retained as `raw/artifact-14645498790.zip`: 1,221,829 bytes, SHA-256 `749005417942333ac26205ed58ed7dc7dc943157dd8adfb775dfab664a6a95a6`, all 253 ZIP members CRC-verified. Root independently bound all 16 source inputs to tree `57f85214a2ec1fc3591eae58c7a750900c680047`, verified unchanged before/after source and replayed the original qualifier. `ROOT_REVIEW.json`, `SOURCE_GIT_PROOF.json`, `ROOT_REPLAY.py`, the compressed complete Git tree, raw job log, run/job/artifact metadata, results and case logs are retained. No signed artifact download URL is included.

The earlier failed v1 evidence remains in the v2 commit ancestry. Neither failed run is rewritten or upgraded to a PASS.

## Why the missing case needs a different captured input

The fixture first created an index and captured the manager's existing-directory URL. It then deleted the index but continued to supply that old URL. On Darwin, the manager recomputed a URL without the directory hint. The original repository checks exact manager URL identity before reading required metadata; it therefore correctly rejected this call as a source change. The old case tested deletion after an existing-source capture, rather than the intended missing-path refusal.

The v3 change is limited to that one fixture case. After deletion it captures the actual manager URL for the absent path, asserts actual absence and the same normalized path, records both observed URL forms, and creates an explicit `OwnershipSource` value using that URL. Profile, repository revision, fingerprint, expected sidecar, resource hashes, bridge and generation remain the original immutable test inputs. The repository will encounter the missing required `meta.json` before comparing the retained fingerprint or invoking native compatibility/construction. This is a repository missing-input test, **not** a claim that an absent index can be admitted as a ready production host source.

The original expected refusal set, default 1,500 ms deadline, no-directory-creation assertion and no-native-open/cache-publication assertion remain unchanged. The other source-generation and repository-ABA refusal cases remain unchanged. The test does not accept `source_changed` as an additional successful result.

## Preserved scope

Only three existing files change from exact `96f2b8a`:

1. `OwnershipCases.swift`: the missing case setup above; all 32 case IDs and every original assertion remain.
2. `OWNERSHIP_INPUTS.json`: that fixture's exact hash/blob and its base commit.
3. The existing ownership workflow: the new immutable v3 branch name and updated manifest SHA only.

All product source, locks, bridge implementation, deadlines, native constructor double, metadata boundary, pre-guard source archive, evidence qualifier, driver, toolchain selector, compile/runtime limits and all other fixture code are byte-identical. The fixture-only inverse restores the original whole case file. C's independent source review found no concrete blocker, with no execution claim.

## Verification and next actual gate

The local Python verifier rechecked the complete v2 archive, all 16 Git-bound source inputs, exact observed failure, original qualifier results, all candidate input hashes, 32 unchanged IDs, complete case inverse and workflow inverse. This is **retained-evidence/source verification only**. No v3 Swift, Darwin, real C/Rust engine or Native UI has run locally.

Root alone may publish the reviewed successor on `codex/otzaria-cold-search-ownership-v3-20261120`. The unchanged driver must execute the exact pre-guard case and all 32 candidate cases; no arbitrary nonzero exit, setup failure or missing result qualifies as RED or GREEN.

```sh
python3 docs/hq-integration/cold-search-darwin-ownership-v3-20261120/VERIFY.py --repo .
python3 tools/hq-cold-search-ownership.py --repo . --output build/cold-search-ownership --expected-inputs-sha256 b04dc2b518fa552934920a2c0a39043c1b5ad85eb55583e822ede6c95eca42ba
```

The second command is the future Apple execution command, not a local result. Real-engine construction, full app integration and original Native UI acceptance remain separate gates even if the Foundation ownership cases pass.

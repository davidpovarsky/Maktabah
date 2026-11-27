# Original SDK next-run and continuation contract

## Conclusion and scope

This is a read-only review of the original SDK source at `1be970356c655bcef3688ddf1d129d5029bbc533`, prompted by the actual `PasteboardHelper.swift` compiler failure. It does not execute a retry, change an admission policy, repin a continuation, bless a partial cache, or amend original evidence.

For a committed application-source correction, the existing entry points require a **new genuine local execution identity and fresh evidence/work roots**. The existing continuation is specific to an older successful framework build followed by a postbuild dependency-metadata failure. It cannot resume this failed compile across changed product source.

The original driver does support two narrowly admitted cache-seed routes inside a new full execution. That is different from continuing this failed work or carrying forward its qualification. All current-source compilation and postbuild acceptance gates still execute.

## Source-bound identity and fresh output

`Tools/OriginalEditor/prepare_local_execution.py`, function `prepare` (lines 28–58), requires evidence and work to be absent, disjoint and under the owned source's `build`. It requires a clean allowed branch, actual Apple silicon/Python 3.12+, and exact Xcode 27.0 build 27A266a. It generates a new real `local-UUID`, then records the actual source commit/tree, branch, host, root and original runner digest. It creates evidence/preflight but does not precreate work.

`Tools/OriginalEditor/local_execution.py`, `validate_record` / `read_identity` (lines 42–83), verifies the same current commit/tree/branch, actual machine/root, descriptor digest and runner digest. An old descriptor cannot be reused after the source correction.

`Tools/OriginalEditor/run_framework_acceptance.py` (lines 231–265) verifies current source observation against an existing source-before record; a mismatch fails. Source-only admission returns before work creation. The full run explicitly rejects any existing work directory and creates its fresh work itself. Actual preflight and qualified ABI evidence must bind to the new source/execution.

Therefore preserving or renaming the previous work does not make it an authorized new full-run input. A new source checkout is not intrinsically required by these functions if the owner commits the exact correction in the existing clean owned checkout, but a fresh source-bound execution descriptor and fresh output paths are mandatory. Existing failure evidence must remain immutable.

## Why the existing continuation cannot handle this case

`Tools/OriginalEditor/continue_verified_framework.py` is pinned to compiled source `e79192e5ad2b879ca4a45e46a3f6b504a1094155` (line 23). Lines 61–68 require that exact clean compiled checkout and a small allowed control-only delta that cannot change compiled inputs.

Lines 86–109 require the original execution descriptor, unchanged original driver/source closure, and the exact reviewed prior failure: the framework build already passed, external consumer has not run, strict dependency resolution passed, and the error concerns `SourcePackages/checkouts/abseil-cpp-binary`. Lines 146–153 independently require original framework return code zero, no timeout, unchanged full logs, and actual `** BUILD SUCCEEDED **`.

The current execution has source `1be97035` and compiler return code 65. It fails both the source and successful-build prerequisites. The original docs `VERIFIED_FRAMEWORK_CONTINUATION.md` describe that older postbuild boundary; they do not grant a generic source-changing retry.

The compiler-graph refresh path also retains the same compiled source bytes. Successful refresh reuse requires its exact original evidence, source-before/after equality, successful command/output, unchanged source bytes and restored original mtime (lines 111–143). `--use-original-work` additionally requires that successful refresh record and an exact three-member prior-work layout (lines 75–80). None authorizes a product-source correction or an unsuccessful framework build.

Changing the source constant, broadening the allowed delta, rewriting the old descriptor, setting the old framework field to PASS, or describing the current partial work as qualified would not follow this existing contract.

## What the original cache-seed interface actually permits

`run_framework_acceptance.py` lines 282–305 permits an inactive seed only after the new full run has created its own work and before its `producer-derived` exists. It uses an APFS clone, so writes are isolated from the retained seed. The receipt explicitly sets `grants_product_acceptance: false`.

| Existing route | Exact admission | Consequence for this failed run |
| --- | --- | --- |
| Original ABI donor cache | Seed must be the independently verified installation ABI donor's exact `build/SDK-Work/producer-derived-preserved` directory; no active compiler use | The current failed `...FreshAfterFiveScopes...-Work/producer-derived` is not that input. Moving it under the allowed name would not establish original donor provenance. |
| Qualified released cache | `--qualified-cache-seed` invokes the complete pinned `qualified_cache_seed.verify` policy | The current partial build is not a complete qualified released producer. The policy is also scoped to an exact historical reviewed source delta. |

For the qualified route, `qualified_cache_seed.py` requires a frozen donor, exact qualification/source/execution/distribution/descriptor digests, full framework+external-consumer PASS, observed single shared runtime implementations and the exact retained producer binary (lines 66–112, 137–149).

Its `verify_facade_records` requires identical original application/generated/resource trees (lines 34–63), unchanged facade membership and only three exact reviewed facade file changes. Lines 113–136 additionally bind both facade trees, original project and lock bytes, ABI identity, Hanlin revisions and exact shared-file changes. The policy file is `Tools/OriginalEditor/MiniApps/qualified_cache_seed.json`; it is not a generic permission for a newer source correction. A change to application `PasteboardHelper.swift` is outside the identical-application-tree requirement.

The permitted historical donor/cache directories may be retained or recoverable elsewhere, but this review does not claim current presence or authorize restoration. No broad filesystem search or cache recreation was performed for this decision.

## Required next execution, after the source owner delivers the correction

The documented sequence remains: exact clean committed source; new original local identity and actual OS27 preflight; original source-only admission; qualified ABI receipt bound to the new execution; original reviewed macro preparation; original full framework/consumer acceptance and shared-runtime gates; original macro restoration even after failure. Exact source-after, package locks, API/symbol, binary/resource and external-consumer proofs must come from that execution.

A diagnostic incremental compiler invocation, if separately authorized, would only be diagnostic evidence. It would not substitute for the original full acceptance path described here. No such diagnostic or retry is executed by this packet.

A newly designed reusable-failed-cache contract would be a separate reviewed control change with its own source/provenance and negative controls; it is not supplied or implicitly authorized here. The present conclusion preserves the unmodified original admission boundaries.

## Captured source records

`SOURCE_BOUNDARIES.json.gz` contains the exact read-only Git-source observations used for this review. It retains full preparer/identity sources, selected numbered original-driver/continuation/cache/doc boundaries, complete source lengths and SHA-256 digests. Numbered excerpts are identified as excerpts; their source-file digests bind the full original files at the fixed commit.

`SOURCE_BOUNDARIES_BINDING.json` records the uncompressed observation bytes and compressed-byte digest. This capture is source analysis, not an executed acceptance result.

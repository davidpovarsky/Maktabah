# Native execution gate — source availability and owner constraints

This is a read-only gate check, not a native test result.

**Current source checkpoint:** final correction `977a02a1…` is independently source-approved by committed review `401a96ee…` and locally merged at `4671b0c91354a19d3f1c981e6ebf9c25209a8d01`. Its real source-only preflight and 53 focused portable tests PASS on the merged branch. GitHub lookup of this exact merged SHA also returned HTTP 422. The source-pin/scoped-review blockers are cleared locally; native/product/owner gates below are not.

- The active repository already provides `.github/workflows/sefaria-embedded-validation.yml`.
- Its `runtime27` job runs on `xcode-27`, requires an exact 40-character `hq_stage2_expected_sha`, rejects nonempty `source_ref` and diagnostic-case overrides, and checks out that exact SHA (`:100-116`).
- The owner requires local-only work/no push and forbids manually launching paid CI. No workflow, trigger, checkout guard, or publishing route was changed to bypass those constraints.

## Executed source-availability check

After local O2-A integration at `9c4842691ecd86087867698fc2eeb9a374d05b7f`:

`gh api repos/davidpovarsky/Maktabah/commits/9c4842691ecd86087867698fc2eeb9a374d05b7f --jq '.sha'`

returned **HTTP 422: “No commit found for SHA”**. The repository is public, but the local repaired commit is not currently retrievable there. This does not establish the cost or availability of the custom `xcode-27` runner. It establishes that the existing immutable-checkout workflow cannot presently validate this local source through that checkout path.

The later O2-B candidate is not yet integrated at this checkpoint. This document must not be read as verification of a final combined SHA.

## Consequence

Keep native execution **BLOCKED_EXTERNAL / NOT_RUN** until the exact permitted source is available to an authorized native execution path. Do not push, upload a source workaround, change the workflow/manifest, substitute an old SHA, or use the SDK-query toolkit in place of the repository's own app workflow merely to obtain a green result.

The two successful public `apple-devtools` SDK-information/API lookup runs (`44085783929`, `44085790390`) establish SDK-query evidence only. They did not build or execute the Maktabah app and cannot satisfy AX, paging, History receipts, POSIX cleanup, reader6, phone/window, or the coherent 27-case gate.

Phase 1 remains **NOT READY**. Existing `4065feef…` run results are historical source-qualified evidence, not acceptance of local repairs.

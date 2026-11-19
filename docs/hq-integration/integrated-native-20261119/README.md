# Coherent Native and original Hanlin consumer integration

The primary Native75 repair/evidence branch and the existing original Hanlin consumer, including its cold-restoration binding repair, are integrated with both Git parents preserved. This is source integration and declaration verification, not native acceptance.

## Preserved sources

- First parent: `5a40fe9c25e8dd6cfaef71c2f51e34d0adbd796e`, original Hanlin consumer; application repair `868a94c0e4bfb8171cc910dc432710651054aa5d`.
- Second parent: `60cd079199d999d9c4b3c458e892a341ae9cd6ac`, exact Native75 Swift6 repair and preserved SDK upload-failure evidence.
- Merge base: `e215f277afc913cd2fbd8e9b9b21619c9faf2091`.
- `Source`, `Vendor` and `Maktabah.xcodeproj` are byte-identical Git trees to the first parent. No application, package pin, upstream hook, model or data change was introduced by this merge.
- The host still consumes original SDK `6d62957852ffcb428810b065b4252e5384f1374b`. The separately verified SDK navigation transition at `e00498e33` is not silently substituted or claimed as consumed.

## Three reviewed conflicts

| File | Resolution and invariant |
|---|---|
| FaithfulReaderUIAcceptanceTests.swift | Both parents already capture the same MainActor-owned element. Retain the explanatory primary comment. Exact full text, Unicode normalization, fixture and timeout oracles remain intact. |
| hq-hanlin-navigation-transition.py | Retain the explanation and explicit original minimum platforms iOS27/macOS26. Original package sources and proof assertions stay intact. |
| R27_CASES.json | Restore the parent75 selection and device/HID groups; add the two existing Hanlin consumer methods in their own fresh iPad11 group. Keep all original catalog rows and historical source records. |

## Exact scope

The original parent catalog had77 declarations but selected75; two historical GlobalHistorySubmit cases were already unselected. The consumer added two catalog entries, giving79 declarations. This integration selects77 actual cases: original75 plus2 Hanlin,63iPad11 and14iPhone. The two unchanged historical unselected entries are listed explicitly in the manifest. They are not reported as executed. All27 required Phase1 methods are included.

The original runtime27 execution-group validator and exact Swift XCTest declaration verifier accept the combined77 selection. Raw structured review is in MERGE_REVIEW.json. This is a preflight, with0 runtime passes.

## Acceptance still required

Native75 run44559352638 and focused consumer run44571075774 remain bound to their own immutable parents. Their outcomes are not automatically credited to the integrated candidate. Full app/native, original source-opening/provider journeys, physical iPad, accessibility/system surfaces and release acceptance stay open. Release remains NO_GO.

## Source freeze

Both application and test provenance now point to merged source `3db5f13cd6e36c5ff32d11e6f5f4672b120cb493`. The original exact-tree/dependency preflight passed; its raw result is FREEZE_PREFLIGHT.json. This is a declaration/source preflight with no new runtime acceptance.

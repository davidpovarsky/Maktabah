# Actual SDK compiler failure — 2026-11-27

## Outcome

The one authorized fresh original SDK attempt on clean source `1be970356c655bcef3688ddf1d129d5029bbc533` **ran the original framework compiler and failed with exit 65**. It did not stop for the reserve or timeout. No corrected-source retry was launched.

The actual xcresult contains one Swift compiler error and 83 warnings. The first compiler error is:

```text
Anytype/Sources/ServiceLayer/Block/Pastboard/PasteboardHelper.swift:88:88:
error: missing argument for parameter 'options' in call
```

The original source expression is `PropertyListSerialization.propertyList(from: data, format: nil)`. The source owner was asked to review supplying the missing `options: []` argument. This evidence packet makes no source edit and does not claim that candidate correction compiled.

## Exact execution

| Item | Observed value |
| --- | --- |
| Genuine execution ID | `local-ad6e0a4b-ca9a-4d64-91ea-8d1c1c843ee7` |
| SDK source | `1be970356c655bcef3688ddf1d129d5029bbc533` |
| Actual framework command | `xcodebuild build`, original `AnytypeOriginalEditor`, `Debug-Anytype`, arm64 iPadOS 27 simulator |
| Framework command interval | 2026-11-27 10:39:57–10:45:07 UTC |
| Framework exit / timeout | `65` / `false` |
| Supervisor result | `ORIGINAL_FRESH_RUN_NOT_ACCEPTED`, exit `1` |
| Original macro restoration | Exit `0`, `PREEXISTING_APPROVAL_NOT_CHANGED_BY_THIS_JOB`; trust store not written |
| Source-before and source-after | Byte-identical, 329,539 bytes each |
| Source observation SHA-256 | `1ce89f67d515fcb4745ce29e65e59452cb379797673e59523ed51f39883700d2` |
| Original guarded inputs | All 17 rechecked against exact clean source |
| External consumer / runtime | Not run after the framework failure |
| Maktabah app / native UI / physical QA | Not run by this attempt |

The original `execution.json` still contains its initialized scalar `original_framework_build: "NOT_RUN"`: that field is only promoted on success. It does **not** override the real compiler command, raw output and xcresult proving that the framework build ran and failed. All original fields are preserved unchanged.

## Evidence and verification

`original-sdk-compiler-failure.tar.gz` is the complete compact packet: **963,787 bytes**, SHA-256 **`6acd6fa09f46c4b3037c84654266618be5605137eea0ad3fa3158453039993c5`**. Its 48 regular members were independently read and verified against the included manifest on Windows. `FAILURE_PACKET_RECEIPT.json` preserves that actual verification receipt. `FILE_MANIFEST.json` is an exact copy of the archive manifest, SHA-256 `f57f9302e8ad2c9cbbe1b9f65b66eda088627015411cb37c6b9663df31675f92`.

The archive retains the original source error file, all 17 guard records, complete source observations, genuine descriptor, actual command and full logs, execution/ABI/Hanlin records, actual launcher/supervisor/watcher sources and receipts, proposal/recipe, macro restoration and xcresult export. The 13,323,297-byte framework stdout is losslessly compressed; its original SHA-256 is `9a26edcdca67317a1b721b901b522e4b95d492e4c328d8307ee6da5eb178af6e`. No warning or failure was filtered out. The exact raw xcresult remains on Mac; the archive includes every member's digest in `XCRESULT_MEMBERS.json`.

Original controller sources and raw execution outputs inside the archive are immutable. Additional Windows bridge sources are stored losslessly compressed, with original and compressed hashes in `BRIDGE_SOURCE_BINDINGS.json`. The earlier local preparation failure, before any Mac execution, is retained separately; it was not another SDK attempt.

This packet grants no SDK, cache, app, editor, native, release or distribution acceptance. The old failed work, ABI inputs, original receipts, xcresult, source and trust state remain in place. There was no deletion, retry or product/gate change while packaging.

## Retained locations

- SDK source: `/Users/m1/builds/otzaria-wave1-sdk-20261127/source`
- Original evidence: `/Users/m1/builds/otzaria-wave1-sdk-20261127/source/build/SDK-Wave3-1be97035-Debug-FreshAfterFiveScopes-20261127-Evidence`
- Original work: `/Users/m1/builds/otzaria-wave1-sdk-20261127/source/build/SDK-Wave3-1be97035-Debug-FreshAfterFiveScopes-20261127-Work`
- Controller: `/Users/m1/builds/otzaria-wave3-sdk-fresh-after-five-launch-20261127.4pw02_zj`
- Supervisor output: `/Users/m1/builds/otzaria-root-actions-acceptance-20261126.wjQnLNJl/wave3-sdk-fresh-after-five-scopes-20261127.degtfvn6`
- Independently verified Windows packet: `C:\Users\DAVID\.codex\artifacts\otzaria-wave3-sdk-fresh-after-five-launch-20261127\compiler-failure-packet`

Root assigned the original source correction to its owner in Asana SDK task `1220941959967667`, comment `1220950845038770`. The terminal evidence update is comment `1220951183323444`.

## Permissible next-run contract

See `ORIGINAL_NEXT_RUN_CONTRACT.md` and the captured original source boundaries. The current continuation entry point cannot admit this failed compile or changed application source. A corrected source requires a new genuine source-bound execution and fresh evidence/work, followed by all original acceptance gates. Only the pre-existing narrowly admitted cache-seed routes can populate that fresh work; the failed current producer directory is not an eligible seed. No next run is authorized by this report.

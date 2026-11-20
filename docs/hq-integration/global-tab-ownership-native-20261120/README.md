# Global tab ownership: source candidate and four original Native executions

Source M is `cb252c143955d037ab0cef4df556b1e8fcd4c334`, one isolated iPadLayout change on exact parent `1146a249fdd94c345371c67a8d763f16223017ee`. No integration ref or executable branch was changed when M was created. Root owns review, publication and activation of this new route.

## Actual preceding result

Native6 run [44796704535](https://github.com/davidpovarsky/Maktabah/actions/runs/44796704535), F `bce0fee51c813fe2b830d87d61b1c7943f0344f4`, M `40c1eaa6bb0092336f1ee687ad1ce1425eaf4223`, completed **2 PASS / 4 FAIL / 0 skip / 0 unverified**. Both iPad jobs and aggregate failed. The raw six leaves match the original per-configuration summaries and runtime records; before/after execution-source observations match. Five complete original artifacts were authenticated (330,190,019 bytes, 3,166 ZIP CRC entries).

| Configuration | Landscape Global | Portrait Global | Other selected cases |
|---|---|---|---|
| iPad11 | FAIL: original nav minY106, candidate86 | PASS:86 and86 | Pointer Escape and R27 keyboard calibration FAIL |
| iPad13 | PASS:106 and106 | FAIL: original106, candidate86 | None |

Each comparison used equal physical window bounds within its OFF/ON pair. Both devices executed landscape then portrait. The opposite failing orientations and the86 baseline on iPad11 portrait mean this is not demonstrated to be a portrait-only defect. No fixed expected y-coordinate or offset is introduced. Complete raw capture ZIPs remain at the authenticated local paths and their original GitHub artifacts; this small CI packet carries raw source/result/API observations and the capture mapping, not hundreds of MB of duplicate capture data.

## Production change and limits

The selected Reader now alone emits its existing visible/hidden tab-bar preference. The four unrelated global tabs no longer emit `.automatic`. Reader content remains at one unconditional structural position; only a noninteractive, accessibility-hidden `Color.clear` background conditionally publishes that preference. The complete one-file inverse preserves all original Reader state, scroll, selection, navigation and feature-off content bodies. All other Git leaves and modes are unchanged.

Apple documents toolbar visibility as a preference propagated to a bar-rendering container, with final visibility determined by that container: https://developer.apple.com/documentation/swiftui/view/toolbarvisibility(_:for:) . That contract supports investigating preference ownership; it does not prove the observed SwiftUI20pt cause. Actual background propagation/precedence against the unchanged original iPad `.visible` declaration, and Reader collapse/reveal behavior, remain runtime questions. No Swift parse, Apple typecheck or candidate Native result is claimed here.

## Exact route

`codex/otzaria-global-tab-ownership-native-20261120` is an **unactivated proposed branch**. Its new workflow derives from the actual Native6 workflow. It independently builds on the original two iPad configurations and runs the same landscape and portrait methods on each: **four executions of two existing methods**. Original whole-method geometry comparisons,±1 tolerance,20s capture and600s per-case limits are unchanged. Each proposed configuration retains all116 original catalog rows plus the two original Global diagnostic rows; the complete Native116 catalog and Release114+2 manifest are unchanged. The existing original Swift declaration parser remains mandatory in actual CI.

The prior two keyboard methods are unselected and earn no pass. Only their keyboard-log-specific qualification was omitted from this Global route. The unchanged workflow still collects original app logs. Source/hash guards, actual full-app build,55 Apple Foundation transport controls, raw XCTest leaves, zero skip/unverified checks, before/after receipts and both-configuration aggregate remain mandatory. Aggregate receipt filenames match the actual producer and the tested case-sensitive consumer. No historical pass is transferred.

## Verification already executed

All36 adapted original Python boundary/receipt controls passed. The separate79 source-preservation assertions passed, including complete driver function preservation, whole workflow inverse, actual receipt names, canonical inputs, unchanged methods/capture/oracle and the original full catalogs/budgets. These are CI and source controls, not app execution. The local full Git source gate and original Swift declaration parser are NOT_RUN on this authenticated projection; both execute first on the actual immutable CI checkout. Two local setup transport failures are retained in `SETUP_ATTEMPTS` and did not execute Swift or modify product sources.

The four Global results will qualify only this narrow source change. Reader scroll-collapse and repeated cross-tab lifetime tests, full Native116, Release114+2 and physical-device acceptance remain separately required.

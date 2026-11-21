# Native6 actual terminal evidence — run44796704535

The exact frozen checkout `bce0fee51c813fe2b830d87d61b1c7943f0344f4`, application/tests `40c1eaa6bb0092336f1ee687ad1ce1425eaf4223`, ran once and completed **FAILURE:2 PASS,4 FAIL,0 skipped,0 unverified** across six executions of four distinct original methods. No result is transferred to a later source. This is not full Native116 or Release114+2 acceptance.

## Verified outcomes

| Device | Original method | Actual outcome |
|---|---|---|
| iPad11 | Global Search landscape parity | FAIL: both actual navigation bars minY106→86, unchanged±1 oracle |
| iPad11 | Global Search portrait parity | PASS:86→86 |
| iPad11 | Pointer hover/click and hardware-keyboard dismissal | FAIL: original15s Escape dismissal |
| iPad11 | R27 keyboard dispatch calibration | FAIL: original15s Escape input removal |
| iPad13 | Global Search landscape parity | PASS:106→106 |
| iPad13 | Global Search portrait parity | FAIL: both actual navigation bars106→86 |

The six raw XCTest case leaves, raw summaries and original runtime result rows agree exactly. Both complete full-app/test builds reached real UI execution. The two source-before/source-after execution closures match. Both matrix jobs and aggregate fail; aggregate preserves partial observations as unqualified rather than reporting a pass. Full build/compiler logs remain inside the original evidence ZIPs. No zero-compiler-warning claim is made.

## Execution time and layout observations

iPad13 job136497998833 ended19:43:19UTC, iPad11 job136497998236 ended20:05:05UTC, and aggregate136537298877 ended20:05:39UTC on2026-11-20. Workflow updated_at is20:05:39UTC; readback/collection time is a separate observation and does not redefine execution finish.

Both jobs executed landscape before portrait; within each method the original feature-off app launched before the enabled candidate. Every OFF/ON pair has equal physical window bounds. iPad13 portrait is1032×1376; landscape1376×1032. iPad11 portrait834×1210; landscape1210×834. Failed pairs shift both navigation bars and the original query field20pt upward; bar sizes stay the same. Because iPad11 portrait passes at86 and iPad13 landscape passes at106, the evidence does not establish a single required absolute y-coordinate or a portrait-only defect. The exact paired AX and original PNGs are retained.

The source ownership candidate later published as `cb252c143955d037ab0cef4df556b1e8fcd4c334` removes unnecessary unrelated-tab preference publishers and keeps Reader structurally unconditional. It has **zero Native execution** in this packet; actual SwiftUI preference propagation, geometry and Reader behavior remain to be qualified. The prior source M40 and current pre-candidate409/1146 have identical application Source trees, so the failed product state has not been silently attributed to a newer unrelated fix.

## Keyboard boundary

Original app trace proves real palette opening, owner/focus callback, first responder and key window. Calibration logs original Close and reopen, plus Down/Up input before the XCTest Escape synthesized event. No corresponding Escape handler/close trace was observed. This does not identify whether event delivery, platform keyboard state or product handling caused the missing dismissal. Root owns that diagnosis separately. Exact trace lines, event/AX/PNG IDs and source timestamps remain in ESCAPE_HANDOFF.

## Authentication and preservation

All five original ZIPs are preserved and match the canonical GitHub artifact byte sizes and SHA256 values. All3,166 ZIP entries passed CRC verification. Total original archive bytes:330,190,019. This packet includes the two complete evidence ZIPs and complete aggregate ZIP, all three full job logs, terminal run/jobs/artifacts API records, raw source/result observations, full visual-capture manifests, eight matched Global AX/PNG pairs and selected Escape evidence.

The two complete capture ZIPs (93,782,761 and221,407,962bytes) remain intact at the recorded local paths and original GitHub artifact IDs. They are not duplicated into this Git documentation packet; selected entries and their manifest mapping are included. Signed download URLs and secret transport receipts are excluded. Existing archive/source records are preserved unchanged. No test rerun, workflow cancellation or dispatch was performed to assemble this packet.

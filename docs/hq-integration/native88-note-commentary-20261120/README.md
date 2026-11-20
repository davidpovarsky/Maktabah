# Native88 note and commentary investigation — 2026-11-20

The actual Native88 run [44657116407](https://github.com/davidpovarsky/Maktabah/actions/runs/44657116407) failed on checkout `fe4df7c39aec242d00046bc454c81963ba4285a0` / app `7e777509d486a17bec5b4bd437a9ac7f51d3a43a`. The full verified evidence ZIP is 87,098,508 bytes with SHA-256 `ced48935baf6c27a7df229b1e438ae30113fcad7939ccfa5783ad4262723872c`. The independent overall audit records **46 passed / 24 failed / 0 skipped / 18 not run**; partial phone log observations are not counted as completed xcresult leaves.

## Commentary: actual setup refusal, one-argument correction

The Pad case stops at its independent base-source TextKit/locator assertion before writing the Core commentary trigger. The original bootstrap owns book 3891/line 523. The setup asks for book 28/line 2 via `readerURL` with its default current-tab mode. At 02:49:53.332Z the app reports `current_reader_target_unavailable`; the final AX retains book3891 and shows the original refusal alert.

The unchanged `MaktabahNativeReaderBinding` correctly requires the same original book/backend owner for same-tab navigation. The existing explicit new-tab reservation is the correct operation when the setup needs a different book. The patch adds only `newTab: true` to that setup call, and retains the baseline capture after the real book28 TextKit/locator gate. It preserves the original commentary action, exact base and commentary SQL text/locators, one additional commentary tab, workspace/profile retention, original tab return, process identity and receipt assertions. Both Pad and Phone use this helper.

The byte-inverse proof restores every original file byte by removing that one argument. Swift 6.3.3 syntax parsing completed in 0.906 seconds with exit0 and no diagnostics. This is not an Apple SDK typecheck or Native pass. The candidate has not run on Simulator. No product same-tab ownership guard changed.

## Notes: actual editor present, acceptance remains failed

The exact notes result records `cancelled` / `deadline_exceeded`, while `originalUnsavedEditor`, `originalEditorOwnsProposal` and `originalStoreUnchanged` are all true. The original draft locator is book3891/line523. The actual final PNG and AX show the original Edit Annotation sheet, correct proposal, and original Save/Cancel controls.

The retained log shows underlying Reader/Library surfaces becoming hidden by a modal at 02:50:59, then the existing native acknowledgement deadline at 02:51:04. It contains no `native.reader.noteDraft` marker diagnostics. The Workspace sheet and routing-surface source is byte-identical between tested app7e and candidate basef064. This narrows the investigation to the note-surface witness/qualification seam; it does not yet establish which conditional or SwiftUI lifecycle step prevented it. No note product fix or Native success is claimed here. Existing source, editor, glyph, ownership and5s deadline gates remain intact.

## Integrity and scope

The 2.17GB captures archive was not downloaded or fully hashed. Five relevant members were retrieved by the original authenticated HTTP206 reader; their exact CRC and SHA-256 were independently rechecked and are retained here. The advertised whole-archive digest is labeled as advertised only. The full text-evidence archive was already authenticated by the owning auditor; the exact reader-log entry was rehashed against its collection receipt here.

This source tranche modifies only the downstream NativeRouting acceptance setup. Original app, Core, SDK, engines, data, feature flags, CI branches and timeouts are unchanged. All raw evidence retains exact original bytes in gzip or original PNG form.

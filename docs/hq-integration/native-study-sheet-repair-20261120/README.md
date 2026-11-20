# Native Study Sheet: evidence-bound source repair

This isolated candidate addresses observations from run **44811999303**, attempt 1, on application source **353888ed645c135da9cb229713d17a4594d1edb6**. Its original iPad 11 result remains **2 passed, 9 failed, 0 skipped**. This candidate has **no Swift typecheck or Native result**.

## What changes

Three files change. The original Foundation presentation state and all twelve Native case identities remain.

| Boundary | Actual evidence | Source correction |
| --- | --- | --- |
| Nested note dismissal | The close/TOC command reached the actual-child guard; the note and observation vanished while an empty system parent remained and its callbacks did not complete. | A stable, noninteractive native-only carrier owns the existing nested note sheet and marker while the original Inspector retains its own visibility policy. |
| UIKit sheet observation | Real geometry and native grabber values changed, but five tests received a nil selected-detent string. The original walk accepted an inherited presenting controller. | Require reciprocal UIKit presentation before accessing the presentation controller, plus the original marker/window ancestry. Record the actual owner types and detent list without manufacturing an identifier. |
| Reopen during dismissal | The original command observed a live sheet, lost its marker during dismissal, then later received the actual onDismiss. | Cache only the weak exact UIKit sheet, scoped to owner/presentation/source. The original pending guard still requires real isBeingDismissed and a live window. |
| Notes editing | The actual saved row rendered the added text as a prefix; tapping the editor center did not establish an end caret. | Use the existing suite's real Command-A text-entry pattern and the complete intended text, followed by an immediate exact-value assertion. All original Save/Cancel/Delete and final-text assertions remain. |

The Inspector host itself is unchanged. The native carrier does not bypass the original close action or hold the original content visible after the view model closes it. It keeps the real child presenter mounted so the existing child-before-parent callback sequence can finish.

The observed UIKit cache is DEBUG-only, weak, and identified by Reader owner, presentation UUID and source token. Discovery first establishes that the actual presenter's presentedViewController is exactly the current ancestor. Access to presentationController happens only afterward. A cached owner is usable only while its real view is in a window and it is reciprocally presented or actually being dismissed. A matching onDismiss clears it; a stale callback cannot clear a new presentation's cache. Fresh command admission still requires the original observed context, foreground scene, appeared marker and nontransitioning controller.

## Evidence and limits

The original Native run is [44811999303](https://github.com/davidpovarsky/Maktabah/actions/runs/44811999303). Its source evidence artifact 14672003494 has 6,665,924 bytes and SHA256 `26666f593c4d51916361164e6b82faf7f0a2e075a4bb8b17da628926b64dbf77`; Root completed its 151 CRC checks.

The read-only capture processor [44825211647](https://github.com/davidpovarsky/Maktabah/actions/runs/44825211647) produced artifact 14672793992: 35,680,623 bytes, SHA256 `96e01a40a98aadae8ffc3f31dd9bc4c979bd65bd773cac918f254fa8b38d7864`. Root completed the outer 132 CRC checks. Actual CI recorded full SHA/size and all 1,954 CRC checks on the original 576,476,315-byte archive, then selected the fixed 119 members. The processor ran no app or Native test.

Root's independent replay of all 119 selected byte hashes and source bindings **did not complete** after the local execution runtime became unavailable. It must not be reported as PASS. The selected JSON, AX and PNG observations used here were read directly before that outage. CAPTURE_FINDINGS.json preserves the exact case/member mapping, completed proof scopes and outstanding limit.

The reciprocal-owner correction is supported by the source contract, but the old receipt did not identify the selected UIKit controller. Apple also documents that a nil selectedDetentIdentifier can mean the default smallest detent. The original strict detent assertion is retained; the next actual run must decide whether the corrected observation satisfies it. There is no inferred detent string or timing relaxation.

The empty parent and missing callbacks support the native presentation-carrier correction. The candidate still needs actual UIKit execution to show those callbacks complete. The old failure is not converted to a pass by this source review.

## Source preservation

PROPOSED.patch is the exact three-file change. SOURCE_EDITS.json contains the reversible replacements. SOURCE_PROOF.json records the complete canonical M353888 tree read, eight exact source/fixture bindings, the unchanged package lock, whole-file inverses, exact patch replay and sixteen source invariants.

All 104 original assertion lines remain; two immediate exact editor-value assertions are added. All original twelve case names and budget/wait lines remain. The original Foundation state and four fixture/driver files are byte-identical. TorahInspectorKit remains pinned to **19d1b35397af4f10ae70cfb3f444c9de87383b53**. The original phone/older-system branches, project membership, note store/editor implementation, reader selection and callbacks are unchanged.

These sixteen checks are in-memory JavaScript source inspections, not Swift controls. The local runtime outage prevented a new local compiler or Python run. The prior source-diff helper's metadata-container error is recorded in SOURCE_PROOF.json; correcting that helper changed no candidate source bytes.

Root and C read the complete candidate source and found no concrete source blocker. This authorizes the isolated source checkpoint only. The later reviewed route must run the unchanged original Foundation baseline five/candidate twenty-five and all twelve Native cases, with the original full-app, Sefaria, per-case deadlines and collection gates. It does not replace the full Native116 or Release114 acceptance.

## Primary UIKit contracts

- [presentingViewController](https://developer.apple.com/documentation/uikit/uiviewcontroller/presentingviewcontroller)
- [presentationController](https://developer.apple.com/documentation/uikit/uiviewcontroller/presentationcontroller)
- [selectedDetentIdentifier](https://developer.apple.com/documentation/uikit/uisheetpresentationcontroller/selecteddetentidentifier)
- [isBeingDismissed](https://developer.apple.com/documentation/uikit/uiviewcontroller/isbeingdismissed)

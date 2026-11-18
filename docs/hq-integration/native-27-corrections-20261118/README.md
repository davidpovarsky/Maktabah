# Native 27 continuation corrections — 18 November 2026

## Actual first result

[Run 44185317875](https://github.com/davidpovarsky/Maktabah/actions/runs/44185317875), checkout `72b0da73a5a910fdee9e8f8792091494fd42b6b5`, application `d956894fd3deb348ed1c432ae53079a4991a9a13`, executed all 27 required cases on real iPad/iPhone simulators, iOS 27.2. **23 passed, 4 failed, 0 skipped.** This is not acceptance of the later continuation candidate. Native xcresult, case leaves, JUnit, application logs, screenshots and hierarchy are preserved in the canonical continuation evidence directory. No historical pass is substituted for a new run.

Failed cases:

- `Sidebar11201AcceptanceTests/testSidebarBodyPagingLTR`
- `Sidebar11201AcceptanceTests/testSidebarBodyPagingRTL`
- `GlobalSearchNativeAcceptanceTests/testHeaderAndHistoryNativeAccessibilityAudit`
- `NativeRoutingAcceptanceTests/testWrongBackendURLCannotNavigateOrIssueNativeReceipt`

## Sidebar evidence and correction

The actual app log records Library-to-TOC horizontal recognition and a page change for both languages. On the return gesture the native recognizer admits the correct horizontal velocity, then delivers `began` and `ended` together with `dx=0 dy=0`; the unchanged distance policy therefore rejects the transition. This occurs over the native TOC collection row. The correction retains the eligible original touch-down in window coordinates and compares the real final gesture position in the same window. It still requires a recognized ended gesture, the existing horizontal-direction and 44-point distance policy, one touch, the actual sidebar body, and an unchanged owning window. Cancellation and host teardown discard the stored origin. Native list scroll/pan recognizers remain enabled. No private UIKit class names determine behavior.

The existing portable test passes **55 policy assertions**; that does not verify the UIKit gesture. Both original native cases, including all 20 body and 20 page-dot transitions per language and reader identity/source/offset/search/vertical-scroll oracles, remain unchanged and require execution.

## Dynamic Type

The unfiltered system audit reports `Dynamic Type font sizes are partially unsupported` on a UILabel; its transient AX element is unavailable. The specific UILabel cannot be conclusively identified from that attachment. The native search field now updates its editable and placeholder body font from its current UIKit content-size trait, observes later trait changes, and includes font line height in intrinsic sizing. This addresses the owned field's scaling/layout boundary using public APIs; **it is a candidate correction, not a demonstrated audit pass**. No audit issue is ignored, no Dynamic Type category is capped, and the original accessibility audit is unchanged.

Apple API references: [scaling fonts](https://developer.apple.com/documentation/uikit/scaling-fonts-automatically), [font adjustment](https://developer.apple.com/documentation/uikit/uicontentsizecategoryadjusting/adjustsfontforcontentsizecategory), [gesture position](https://developer.apple.com/documentation/uikit/uigesturerecognizer/location(in:)).

## URL transport failure

The host evidence for the final wrong-backend request explicitly says `delivered=false` and `System URL transport failed`. The actual application log has no corresponding URL-entry event. The native test correctly fails before asserting backend refusal. There is insufficient evidence to distinguish the original timeout from a nonzero process exit. The transport now emits only sanitized failure categories (timeout / could not start / numeric process exit), never argv, URL, token or stderr. There is no retry after uncertain delivery and no synthetic success ACK. The existing request/schema/credential/nonce/target/time bounds and 12-second transport deadline remain. All **10 portable transport security checks** pass. Backend-refusal acceptance still needs a fresh genuine system delivery and app receipt checks.

## Honest execution budget and source coverage

The next existing workflow executes 41 cases: all original 27 plus 11 real search/reader and 3 phone-routing cases. Successful sidebar tests must continue through loops that the failed first run never reached. Increase only the complete matrix wall-clock budget from 90 to 150 minutes and its existing job ceiling from 180 to 240 minutes, retaining the original per-case assertions, timeouts, zero-skip gate and fixture checks. The SDK-only check now compiles the actual self-contained native search field alongside existing actual app components, with no app/model stand-ins.

The separately completed [SDK/macOS run 44204579139](https://github.com/davidpovarsky/Maktabah/actions/runs/44204579139) at `d00da988c936f4436dcb764db6f086a8619a411b` passed iOS 27 compilation and all **61 actual workspace contracts**. Its UI-source warning count is 2298. It executed no native UI methods and predates these corrections.

## Remaining gates

No phase is declared complete by these corrections. The new 41-case runtime run, full production corpus/native performance, manual accessibility/device coverage, complete ActionCore-to-app routing/authority integration, compatible update provider and accepted Hanlin SDK consumer/app registration still have independent acceptance requirements. TestFlight authorization exists, but release checks are not bypassed.

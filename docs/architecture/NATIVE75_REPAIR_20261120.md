# Native75 repair evidence — 2026-11-20

## Source and observed failure

Base: `508d15149b5c1ba0d9949279755ba286fd57a138`.
Observed run: https://github.com/davidpovarsky/Maktabah/actions/runs/44559352638
Observed source: `ef449e640c3fd538b52627a48ea09846a785c52e`.
This repair has not yet passed Native acceptance.

The original xcresult summaries recorded 73 cases: 52 passed, 21 failed,
zero skipped. Two window cases did not run because fixture download failed.
Search: 17/21 passed; Reader: 25/34; Sidebar: 2/4; Phone: 8/14.
Textual runner restarts reported partial totals (Reader max 16), so they were
not a reliable source for the matrix execution count.

## Narrow harness repairs

- Allow the existing public-v2 `native.reader.inspector` system URL envelope.
  Preserve credential, target UUID, nonce, request age, query and endpoint
  restrictions; the actual app parser/Core/receipt ledger remains authoritative.
- Report recorded/executed/passed/failed/skipped counts from actual xcresult
  summary fields. Missing or inconsistent counts fail closed. A diagnostic
  failed-summary count cannot produce an acceptance status.
- Permit one repeat of the same miniTest10 installer after the exact native
  DNS failure observed in window provisioning. Retain the first failed report;
  a second failure, hash/data failure, other profile or later phase still fails.
- Query the exact `global-search-history` identifier as the actual native
  CollectionView in three focus/refusal cases. Keyboard, receipt, query and
  non-submission assertions remain intact.
- When normal phone bootstrap restores a durable Reader, prepare the Library
  using that Reader's unique native Back button before sending the tested
  route. Verify the selected Reader owner/tabs survive. Post-route refusal and
  navigation assertions do not invoke this preparation helper.

## Executed validation

On the Windows worktree:

- `test-runtime27-url-delivery.py`: 16 passed.
- `test-runtime27-fixture-recovery.py`: 6 passed.
- `test_verify_xcresult_zero_skips.py`: 12 passed, including contradictory,
  missing, failed and skipped result rejection.
- `test-verify-faithful-xctest.py`: 8 passed.
- Python byte compilation of the matrix driver: passed.
- Swift 6.3.3 frontend parsing of NativeRoutingAcceptanceTests.swift: passed.
- `git diff --check`: passed.

These are 42 portable contract tests and syntax checks, not iOS SDK compilation
or Native UI acceptance. Logs are in `build/native-repair-20261120/`.

## Native regression still required

Retain every original Native75 case, including the two previously unrun window
cases. Specifically inspect public-v2 Inspector on iPad/phone, unknown Inspector
refusal, public/system search first responder and unknown-component refusal,
phone warm/cold History and wrong-backend refusal, and actual xcresult totals.
No source-level Search/Sidebar/Intent failure is waived by this harness repair.
No Native run was dispatched from this branch during this change.

## Upstream integrity

Read AGENTS.md, PROJECT_AGENT_GUIDANCE.md and UPSTREAM_INTEGRITY_POLICY.md.
The live upstream HEAD examined was `d46af139b3a265399c16d87f5923acd8e3444024`;
its tree has no Scripts/CI or Maktabah-iOSUITests paths. These repairs are in
existing downstream tests/orchestration and do not change production app logic.

## Source and Sidebar repair follow-up

Native75 showed Zayit result 6201403 requesting book103/line1175 while the
existing Reader remained at book103/line138. The two exact-source line tests
rendered the right text but zero search highlights. The Zayit adapter supplied
a raw line index as the Reader content ID and omitted explicit matched terms.
New Reader loads mapped that index to a canonical surrogate, so the old search
event no longer matched. Existing Reader loads used legacy SQL only.

The Zayit adapter now registers the original qualified book/line locator and
passes the provider's matched terms verbatim through OpenBookOptions. Display
search text retains search provenance; no synthetic legacy FTS event is made.
The downstream destination resolver verifies the current backend/work before
a small fetchContentById hook calls the existing asynchronous backend loader.
Unknown or foreign registered IDs refuse; old nonnegative Otzaria line callers
and original legacy SQL behavior remain supported.

The original upstream fetchContentById method at d46af139b3a265399c16d87f5923acd8e3444024
was read and compared. Its original legacy SQL body is unchanged; the only
upstream-file addition is the eight-line canonical-backend dispatch hook.
Policy/owner authorization covers this proven integration defect. No Core,
Hanlin, provider engine or database schema is changed.

Sidebar LTR/RTL both completed twenty actual body transitions before failing
after the final filter clear. The helper inferred collapse from an absent
virtualized child. It now observes the actual row's chevron.down/chevron.forward
image identifiers, which appear in both retained native AX captures, and taps
only a collapsed category. It retains all physical swipe directions, exact
occurrence IDs, final clear/reveal and Reader/viewport preservation assertions.

Executed follow-up validation: 37 portable assertions compiled with Swift6
strict concurrency against the actual adapter, registry, destination resolver,
OpenBookOptions and fetchContentById body. Native dependencies are explicit
boundary fixtures and grant no Native acceptance. The old adapter at 9bd061ab
compiled and failed specifically because a raw SQL line was not a qualified
Reader content ID. Current Swift parsing and git diff --check passed.

Required fresh native regression includes both canonical Zayit source-line
cases, its three-page case, the parallel Otzaria multi-page case, both Sidebar
body-paging locales, normal Reader same-book routing and original legacy paths.

## Book-history scope registration

The original prepared case `Tests/HQ/sidebar/BookHistoryScopeAcceptanceTests.swift`
(blob `7c4310aecf51fc5f8a763a22f423a96ef790cf90`) is now registered under the
existing Maktabah-iOSUITests synchronized source group. The Xcode group has no
membership exceptions; no target/project rewrite was needed. The existing SDK
typecheck preflight includes the registered source.

Its setup uses the current original `global-search-query` control and native
Return, waits for the submitted search to complete, relaunches, and requires
one visible/hittable original history row containing the unique real query.
It does not seed history. Original book-search acceptance still requires all
four modes, help, the Near-distance field, and absence of that actual persisted
global query. iPad is required rather than a skip; normal bootstrap remains.

The exact selected scope is now 78 = all previous 77 plus this one case.
The catalog has 80 cases. The two historical unselected GlobalHistorySubmit
cases (R27NativePadTests and R27NativePhoneTests) remain explicitly unselected;
none of the original 77 cases was replaced. Final integrated source pins must
be updated by the manager before dispatch.

Executed validation on Windows: execution_groups exact partition (21 Search,
34 Reader, 5 Sidebar, 2 Window, 2 Hanlin, 14 Phone), set equality against the
previous 77, uniqueness and unchanged two exclusions; actual Swift compiler
declarations for all 78; Swift frontend parse of the new file; Python byte
compilation; git diff --check. All passed. This is syntax/declaration evidence,
not iOS SDK typechecking or Native execution. Native cases executed here: zero;
BookHistoryScope remains NOT_RUN until the integrated native run passes.

## History heading native accessibility bounds

Original Native75 Search audit failed for the Hebrew recent-history heading:
`testHeaderAndHistoryNativeAccessibilityAudit-BD640D20-2CBB-4F2D-94B8-E74B415FB43D.txt`.
Its actual StaticText AX frame was `{{0,360},{834,40.5}}`; its immediate
rendered-header ancestors were `{{0,360},{514,40.5}}`. The original Search
field frame was `{{86,227},{412,44}}` and options button `{{16,220},{58,58}}`.
The outer Search container/header also used the full window width, so that
outer accessibility container is not a valid detail-column bounds oracle.

The retained native issue crop visibly includes the black heading on the
sepia Search background and unrelated book-sidebar icons/text. Both the crop
and full screenshot were inspected:

- `19DC393A-8C23-473F-87DF-0869CF6D2125.png`, SHA256
  `eba380f3e627a272381412f77d1f56e4c7ec61614245788dc9f8ade54581814e`.
- `33E55320-1BEB-4E78-AF11-BB766EB47D0D.png`, SHA256
  `a2a13e156eb3aa29432ee94baff0f268f3d4314ed43019beacacc0c400179dfc`.
- Full native AX attachment:
  `testHeaderAndHistoryNativeAccessibilityAudit-16251DA5-D73F-44D4-AC1C-82DC23F40160.txt`.

These are original entries from Native75 artifact 14566591261, selectively
read by HTTP Range with ZIP CRC verification. The entire 1.81GB artifact SHA
was not verified; individual PNG SHA256 values above were measured on the
extracted bytes. The files are retained under `build/native75-captures/`.

The production section header now contains its actual accessible Text and
Clear button as separate children. The Text explicitly keeps the header trait;
its existing dynamic system label color and Dynamic Type remain unchanged.
Apple's documented contain behavior groups the original child elements:
https://developer.apple.com/documentation/swiftui/accessibilitychildbehavior/contain
The test additionally requires the heading's actual horizontal bounds to fit
within the original native query/options controls' combined bounds (one point
rounding tolerance). The unchanged system accessibility audit then runs with
all issue kinds/trait changes and returns false for every reported issue.
No contrast threshold, failure filter, hidden element or synthetic replacement
is introduced. The original oversized frame is confirmed; resolution of the
native contrast failure still requires a fresh actual Native audit.

Both edited paths are downstream-only (absent from the reviewed upstream
HEAD d46af139b3a265399c16d87f5923acd8e3444024). Validation: Swift frontend parses
both actual edited files, actual selected declarations remain 78, and git diff
--check passes. iOS SDK compilation and Native audit have not run on Windows.

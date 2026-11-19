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

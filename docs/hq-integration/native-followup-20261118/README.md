# Native follow-up after run44207959071

Reviewed CI candidatef2f27e92/sourcea686e1fd failed at its150-minute matrix ceiling.
Actual xcresult-verified subset:35 cases,28PASS/7FAIL/0SKIP. Phone logs show six
executed cases (one textualPASS/five textualFAIL), but the interruption prevented
phone xcresult verification; none is promoted to verified acceptance.

## Concrete corrections

- Original Reader initial-content branch now marks an explicit Otzaria line as
  explicit. Source line0 previously entered work-root resolution and opened
  line1 instead. The unchanged original LibraryReadingUnitPolicy already
  distinguishes an explicit line0 from an unspecified root.
- Global Search feedback owns an accessibility container, so the dirty/error
  wrapper no longer overwrites its actual child action identifiers.
- The lazily created native UISearchTextField placeholder UILabel opts into
  Dynamic Type and retains the actual body font metadata.
- Both enabled native Reader hosts leave UITextView's actual book text available
  to VoiceOver. Phone previously replaced it with JSON; the existing diagnostics
  child remains unchanged and flags-off baseline behavior is retained.
- Original catalog cells expose complete occurrence paths. The Sidebar helper
  selects the exact fixture hierarchy, validates its real title/visibility and
  performs the original native expansion, instead of the first same-named
  category from another branch. Every paging/filter/viewport assertion remains.
- Original Inspector close callback gains DEBUG before/after evidence only.
  Its intermittent native failure remains unresolved until actual execution.

## Stronger source oracle

Read-only dictionary decoding of the sealed miniTest10 DB proves:
row1/book1/index0=<h1>בראשית</h1>; row2/index1=<h2>פרק א</h2>.
The old generic31-character paragraph heuristic cannot validate a six-letter
title. The Zayit line-zero case now compares the complete native TextKit value
to sealed independent SQL text, plus its exact locator and real highlight.
A second case preserves the paragraph heuristic AND exact source comparison for
row2634912/book3764/index252. Original metadata349131bytes remains unchanged.
New installed-test resource canonical-miniTest10-reader-lines.json:
SHA2569a623ea8805cc9a3c945c3ba05e48842a63b06805599ddc5e6ba18f599284b17.
Only bidi presentation controls and outer whitespace are removed for comparison.

## CI scope and limits

All54 cases are partitioned exactly once among fresh owned simulators:
Search19, Reader/navigation20, Sidebar4, window2, phone9.
Native assertions and their existing wait budgets remain.
Enable Apple's standard600-second individual-test limit to retain a timeout
as a FAILURE and continue to later cases. The prior RTL test ran4086.583seconds.
No retries, skips or shorter acceptance scope. The overall9000-second matrix
budget and existing240-minute job remain. Apple reference:
https://developer.apple.com/documentation/xctest/xctestcase/executiontimeallowance

Existing release/evidence controls17PASS and fixture-oracle controls7PASS.
These are local controls, not Native UI acceptance. App compile, actual UI and
device results must be recorded separately. TestFlight remains gated.

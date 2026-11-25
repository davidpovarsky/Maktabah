# Ordinary note empty-input and window ownership correction

Base: 08f50a5646b7669d15f8c53cb13c84ac504a02bd.
Branch: codex/otzaria-editor-empty-note-20261125.

## Problem and narrow change

The ordinary note sheet selected the first nonempty value from process-global cached text,
the process-global active text view, accessibility text, and its own binding. An intentionally
empty note could therefore recover old text or another window's text. Its UIKit accessibility
getter also substituted the last global nonempty value. The SwiftUI wrapper wrote old native
text back into an empty binding.

The sheet now saves its own native text (or its own binding if the field has not mounted),
including empty text. Accessibility reports the actual field text, and the wrapper accepts
an empty binding. Debug smoke input also uses this sheet's field. No annotation repository,
SQLite transaction, native draft session, SDK, CloudKit or exchange transport was changed.

The existing real production-editor UI journey now clears a saved note with native
Select All/Delete, saves and reopens it, verifies the original UUID and empty preview,
and restores text before continuing the unchanged native rich edit/save/discard/cold reopen journey.

## Actual verification and limits

- Git diff whitespace check: passed.
- Exact original UITextView subclass compiled/linked for arm64 iOS Simulator with Xcode27.0,
  both baseline and candidate: passed. Sentinel job job_477cfbd202e7.
- Complete changed sheet and acceptance test Swift syntax parse: passed.
- Actual native UI execution: NOT_RUN here. The final app runner owns the existing
  ProductionAnnotationEditorAcceptanceTests/testOrdinaryEditorSavesSameAnnotationDiscardsDraftAndRecoversAfterTermination case.
- The preliminary Mac Catalyst probe did not compile in either baseline or candidate because
  an existing accessibility selector conflicts with AppKit NSObject. Preserved in UIKIT_PROBE.json;
  it is not a product failure or a runtime pass.
- Original atomic43/cold2 and Native66 evidence remain reusable: their production sources,
  harnesses, dependencies and execution configuration were not changed by this patch.
- This correction does not complete cross-app stages C–F, account/Space exchange, rich-body
  CloudKit transport, mapping/ACK, native taxonomy, migration or 5000-object acceptance.

No simulator was booted or modified for this lane. The UIKit compile products remain on Mac at
/Users/m1/builds/otzaria-editor-empty-note-20261125; compilation receipts include source hashes
and commands. Shared Mac free disk dropped below50GB during concurrent work; root was informed,
and this lane started no further disk-heavy work.

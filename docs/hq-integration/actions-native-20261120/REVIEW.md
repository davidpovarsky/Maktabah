# Typed actions: focused original Native acceptance

## Exact scope and state

Base: `0bc6be41f03855412d7dd24ee72608a7824fb5a7`.
Branch: `codex/otzaria-actions-native-20261120`.
This follow-up adds six Native XCTest cases and explicit DEBUG request triggers
for the existing production `notes.prepareDraft`, `search.openResults`, and `reader.openCommentary` entry points. It changes no Core package, resolver, search engine,
annotation persistence, production capability grant, or original rendering.

**Native execution and Apple SDK typecheck are NOT_RUN for this follow-up.**
The four changed Swift files passed Swift frontend syntax parsing with the iOS
target and DEBUG enabled on the Windows host. The recorded Windows-sysroot
warnings are retained. Parsing is not Apple compilation or runtime evidence.
The prior 324/324 portable notes checks belong to the production notes commit;
they are not counted as execution of these six UI cases.

A separate source review identified a possible late original-editor callback
race in production (stable owner ID across presentations). The integration owner
is coordinating a separate presentation/instance identity fix before the next
Native freeze. This DEBUG-only follow-up does not claim that fix or its tests.

## What the six tests require

All cases use the existing `NativeRoutingAcceptanceTests` helpers and the
normal verified miniTest10 bootstrap. Their iPad and iPhone variants require the
declared actual form factor; neither variant skips its acceptance conditions.

| Action | Original behavior required | Evidence |
| --- | --- | --- |
| notes.prepareDraft | Exact source-owned selected passage opens the original editable unsaved sheet; original Cancel dismisses it | Core completed result; exact request-linked native receipt; actual hittable UITextView with proposal; id=nil and saved=false; unchanged original AnnotationRepository contents before/after opening and after Cancel; original onDismiss readiness; source, tab, profile, group and process preserved |
| search.openResults | Existing controller completes one real engine submission and shows an original result row | Core completed result; exact `native.search.results` receipt; actual submissionRevision increments once; query/options remain current; no loading/dirty/error state; a hittable original stable row matches that completed controller result and an independent canonical SQL locator; original workspace and process preserved |
| reader.openCommentary | Original source-classified relation resolves and opens the actual commentary in a new original tab | Core completed result; exact newTab receipt; source SQL text and locator in original reader; independently known commentary target; every original tab preserved; return through original tab control restores the base text and selection |

Each receipt must be the single new original log line, match the Core request UUID,
name the actual workspace scene, keep the backend and monotonic revisions, and
follow the original visible UI. The file trigger and a controller query echo do
not count as receipts or results.

Selectors:

- NativeRoutingAcceptanceTests/testCoreNoteDraftUsesOriginalUnsavedEditorAndCancelOnPad
- NativeRoutingAcceptanceTests/testCoreNoteDraftUsesOriginalUnsavedEditorAndCancelOnPhone
- NativeRoutingAcceptanceTests/testCoreSearchOpenResultsUsesOriginalCompletedEngineOnPad
- NativeRoutingAcceptanceTests/testCoreSearchOpenResultsUsesOriginalCompletedEngineOnPhone
- NativeRoutingAcceptanceTests/testCoreCommentaryOpensVerifiedSourceLinkAndPreservesBaseOnPad
- NativeRoutingAcceptanceTests/testCoreCommentaryOpensVerifiedSourceLinkAndPreservesBaseOnPhone

The parent integration owns catalog/selection changes and Native dispatch.
Search still requires `GLOBAL_SEARCH_TEST_QUERY` from the existing independent
fixture oracle; the case pins its known miniTest10 query and validates actual
returned rows separately.

## DEBUG trigger and ownership

The shared helper exists only in DEBUG. It requires the active miniTest10
profile, a UUID study-workspace namespace, an explicit action kind and a UUID
nonce supplied at launch. It consumes only a 36-byte exact nonce file under the
actual app Documents directory. Result and closed files are atomic and written
once. Newly mounted reader views stop when the original result exists; they
cannot overwrite it.

Tiny view tasks call the existing process composition. They never supply source
answers, change a grant, draw text, save/cancel a draft, or manufacture a native
surface witness. Notes and search read the same original view/controller state
that production owns. Commentary's request task is retained across the source
view disappearing during its real new-tab transition; Core retains its normal
bounded request lifetime.

No file is used as a production transport. Release builds omit the helper and
tasks. No new Xcode file membership or parallel test harness is introduced.

## Independently verified commentary source

One exact small miniTest10 v6 release archive was restored to an owned ignored
build directory. The compressed file is 7,774,478 bytes with SHA256
`e9e6dedd2ceaadbe46234612c359e5bd8add00c348be8eaeba85cf029fa5c4d3`.
The database is 15,470,592 bytes with SHA256
`d3d9bfcc2320a987a0391ad23fa72abcf6fd1fa0f3cba95adc05096e05a9edef`.
The original profile verifier passed its integrity, schema, book, line, link,
coverage, suppression and dictionary checks. No full database was copied.

The independent read-only SQL query includes forward/inverse links, coverage
and per-side suppression. It found these two raw relations to the commentary work:

| Link | Side | Raw type | Result |
| --- | --- | --- | --- |
| 6529212 | 0 | COMMENTARY | Base book28 line2 (row6188105) -> book3276 line4 (row6609893), eligible unique commentary |
| 6528846 | 1 | REFERENCE | Original classifier explicitly categorizes this as a general link; excluded from commentary resolution |

The first forward-only inspection found the correct commentary. An expanded
oracle initially asserted that all raw relations to the work were unique and
failed. The preserved failure records that assumption; the corrected oracle
retains both rows and distinguishes the original COMMENTARY versus REFERENCE
classification. It does not suppress the second relation to force a pass.
A prior 30-second subprocess attempt timed out; it is not success evidence.

The two exact source text rows were decoded with the database's real zstd
dictionary, with plain-text SHA256 recorded. Read-only mode and final database
hash prove unchanged source bytes. The Native test itself still calls the
original provider, classifier, catalog resolver and reader; the SQL evidence
does not stand in for those runtime operations. The old generic
DeepLinkedCommentary test is not counted as this action's proof.

Evidence: `commentary-source-evidence.json`, `source-inspection-run.json`, `source-inspection-initial-assumption-failure.json`, `original-profile-verifier.json`, `swift-parse-result.json`. The reproducible read-only script is
`verify-commentary-fixture.py`.

## Upstream boundary and exact exception

Live original upstream HEAD was verified again during this follow-up:
`d46af139b3a265399c16d87f5923acd8e3444024`.

Composition, the downstream reader workspace and the new test extension are
downstream-owned. The only additional upstream-owned hunk is five DEBUG lines in
`Source/Features/Search/iOS/SearchModeView.swift`, after the existing real
search-results witness modifier. It calls the downstream acceptance entry; all
original submit/state/presentation guard code remains intact. A detached trigger
without this actual mounted view would not establish the original UI owner.
A parallel view, fake callback or synthetic receipt was rejected.

The current explicit owner instruction authorizes necessary implementation,
integrations, tests, commits, pushes and merges without another confirmation.
This is standing task authorization, not a claim of unseen exact-diff review.

The exact baseline-relative hunk is archived in
`ORIGINAL_SEARCH_DEBUG.diff.gz`; uncompressed SHA256:
`2bdc60f62488ee84cb746e745a433b1c06bb213436b491a50a0dcb3f7a5f280f`.
The exception register records the same narrow hunk. Rollback removes the DEBUG
helper/tasks and these six cases together. Re-review on original Search/reader
lifecycle changes or the next upstream sync.

Independent review checked source/scene ownership, exact result-to-receipt
identity, unsaved persistence, normal bootstrap and both source text fixtures.
It found one stale expected search destination after integration; the assertion
was corrected from the public focus root to the actual semantic results
destination. It found no further demonstrated harness bypass. That review is
not an Apple SDK or Native PASS.

# Existing live Reader-tab selection — source packet

## Delivery and limits

Source commit: **1d6a8e00a8f9f073f69cd5b53a34ccde6c3eca5d**, based on **15d283aa0ccbbfe6966f26a2c182810cb39fdafa**.

This packet adds a typed `OpenReaderTabIntent` for an already loaded original Reader tab in the current original scene, study profile, group and backend. Duplicate copies of the same book remain separate tab identities. A tab UUID is qualified by the actual scene/profile/group/backend; display titles and array indices never identify a tab.

The app continues to use the unchanged original `iOSNavigationManager.selectTab(id:)` action and original `StudyWorkspaceNavigationAdapter.persistProjection` transaction. No new Reader, substitute view, hidden profile/group switch, content resolver, backend switch or fabricated acknowledgement is introduced.

The scene must already be the original Viewer root. A background mounted window may be resolved, but execution retains its actual source before the bounded original foreground wait. The same request and original five-second deadline remain in force. Only current-backend, loaded live tabs are exposed; unloaded documents, inactive groups, other profiles/backends, replacement readers and a phone's already active tab whose original Reader is not presented remain unavailable. These limits are part of this first slice, not closed acceptance for all profile/group/tab journeys.

**Apple app compilation, AppIntents metadata extraction, Siri, Shortcuts execution, iPad/iPhone UI acceptance, Native116, Release114+2 and physical tests are NOT_RUN for this packet.** This packet must not be counted as a native pass.

## Required integration

Root is the sole writer of shared Composition, app project membership and String Catalog. The exact proposals are in `proposals/`. Decompress the gzip transport before applying; its original patch bytes and hashes are preserved:

- `PROPOSED_COMPOSITION.patch.gz`: one private destination, one typed original canonical entry, one AppDependency registration. It is deliberately not applied to the isolated source tree.
- `PROPOSED_SHORTCUT.patch.gz`: one new fixed Reader-tab AppShortcut. The existing three shortcut entries and phrases stay unchanged.
- `PROPOSED_SESSION.patch.gz`: the source commit contains this change, but root must merge its narrow hunks into the newer History-aware Session, never replace the whole file.

At handoff, root's current integration is `2acdeb502e58ac56d8eb6e171a9d6d53a7bd8745` / Source `858fed1752ee58b8402cdb4b1a6a2d8b90c1b41a`. Preserve the published History record retention, report, completion and cleanup hooks. Its Session is `5370b00c8dac540518920b365635f04eea7d0e327142a69c2809d14806438d9a`; its Composition is `50b30773af0328903bef75960eb124f610b3d4689bd9369d3173a70c9057b968`.

`MEMBERSHIP_AND_TRANSLATIONS.json` lists the two app target additions, automatic SwiftPM files and exact new literals. No PBX, catalog, verifier, source admission, SDK pin, owner signature or owner registry is changed here. Root must regenerate final admission and the authentic applicable owner approvals after integration.

## Original ownership and completion

The original native mapping producer owns the one selection reservation. It retains the exact manager, real per-scene Store mapping source, profile, group, tab, Book and ReaderViewModel. Reservation happens before Core admission. The original setter's willSet consumes the one allowed selection publication before mutation; reentrancy, a second/equal setter, tab-array publication, source replacement and ABA invalidate it.

The actual original Store transaction may publish only the matching planned selection checkpoint. Its changing/available phases and next Store epoch are checked against the exact retained source. Mapping is unavailable during partial native or Store publication. The original source epoch is never mirrored or rearmed. Existing new-reader reservations cannot coexist with this selection.

The app binding retains original root/Settings/mode/book publication counters, target load token and destination, the original backend publisher and a one-shot source observation. Original foreign modal/editor state and actual scene ownership remain blockers. Root selection, Settings and mode stay unchanged; the original selectedBook setter is allowed exactly zero or one publication according to the unchanged original selectTab action.

The proposed Composition enters the existing context, directory, Core preparation and NativeSceneNavigationOrchestrator once. The private destination has no public URL or publicV2 form. The existing original Reader marker is projected only after the actual selected original tab and persisted group are validated. The independent same-scene UIKit witness and real TextKit content/viewport checks remain mandatory. The retained source survives through canonical completion and a final original `validateCompletedJourneySurface` check. Cancellation after an observed ACK preserves that actual receipt as an uncertain effect.

## Source controls and retained failures

| Boundary | Exact result | Meaning |
|---|---:|---|
| Original Store, isolated real persistence, actual adapter producer/selection/checkpoint and verbatim original selectTab body | 40 passed, 0 failed | Explicit Apple Book/Reader/manager shells; no UIKit or device claim |
| Actual original 15d selection hooks with the new retained consumer | 27 passed, 3 failed | Preserved pre-existing owner-contract gap |
| Deliberately reusable setter allowance | 37 passed, 3 failed | Same original assertions detect reentrant/second use |
| Final new service with unchanged actual Core/UIRouting modules and original resources | 38 passed, 0 failed | Explicit native callback boundary |
| Exact prior service with the new post-ACK cancellation control | 37 passed, 1 failed | Actual loss-of-receipt boundary preserved |
| Six final product files plus separately proposed shared files | syntax parse passed | Linux Swift frontend targeting iOS27; not Apple SDK typechecking |

The initial service attempt compiled/linked but failed at the original SwiftPM Bundle.module lookup because the standalone executable was outside the original product directory. That failure remains preserved. Attempt2 used the original DEBUG resource accessor's `PACKAGE_RESOURCE_BUNDLE_PATH`, the actual unchanged resource bundles, and source/hash verification. It passed 37 controls. The final 38-control source run additionally covers the receipt-retaining cancellation guard. Earlier counts are not additive native acceptance.

Every attempt has its unchanged RESULT, raw logs, exact source inputs and command receipt in `validation/`. Large text is stored as deterministic gzip; `EVIDENCE_MANIFEST.json` records compressed and original hashes. Original executables remain in the isolated build directories and are hash-recorded, not represented as app products.

## Remaining work

Root must merge the proposals, add exact membership/translations, preserve all History/other lane changes, obtain authentic current source admission/owner evidence and build the full original app. The next separate packet will add original system-AppIntents native selectors; it will not execute them without the coordinated qualified app.

`NEXT_PROFILE_GROUP_CONTRACT.md` describes the separate genuine async profile/group selection boundary. Existing Workspace parent/component routes are already different features; they do not make typed profile/group selection complete.

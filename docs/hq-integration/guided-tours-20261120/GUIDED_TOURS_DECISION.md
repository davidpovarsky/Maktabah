# Guided tours and automation through the existing action engine

**Research decision — 2026-11-19 UTC; completion batch 2026-11-20.**

Asana: [1219614468074332 — interactive guidance and multistep automation](https://app.asana.com/1/1219597879016953/project/1219602719070493/task/1219614468074332).

Reviewed application baseline: `3f085091edbf86117e1ce9b1d10d2f2b87bfbc4d`. Exact reviewed file hashes and external revisions are in [SOURCES.json](SOURCES.json).

## Decision

Use the existing **ActionCore + UIDestinationRegistry + native scene composition** for every action and navigation. Add only a bounded, scene-owned guide coordinator and declarative scenario data when implementation begins. Reuse native SwiftUI presentations for the explicit tutorial; use TipKit separately for contextual feature hints. Do not introduce another action executor, navigation stack, chat system, or general automation framework.

Do **not add a third-party tour dependency in the first implementation**. The closest spotlight library, Beacon, has concrete scene and completion mismatches in the inspected source. Keep it as an upstream collaboration candidate for a later spotlight renderer. Popovers is a possible presentation substitute if a demonstrated native presentation limitation appears; Instructions is not recommended for new integration. These are implementation decisions, not claims that a tour has been built or tested.

Apple distinguishes contextual tips from tutorials for complex tasks. TipKit's own guidance advises against using tips to guide people through an app; its ordered groups are useful for progressive feature discovery. A user-requested, replayable tutorial therefore needs its own small application coordinator, while its visible controls can reuse system presentations. [A1], [A2][A3], [A5]

## Existing SDKs and libraries

| Option | What the original source provides | Fit and decision |
|---|---|---|
| **Apple TipKit** | Inline/popover tips, rules, events, persistent eligibility, action handlers, ordered or first-available groups. | Use for occasional feature hints. Tip eligibility or dismissal is not an ActionCore receipt. Do not use the shared TipKit datastore as a replay/back cursor. [A1], [A2][A3] |
| **Native SwiftUI presentations** | A data-driven popover attached to a view; standard system presentation behavior. | Preferred explicit tutorial surface: existing app chrome plus accessible Start, Stop, Back, Next and mode controls. Dismiss the coaching presentation before a step that requires the underlying app to navigate. No custom full-screen cutout engine in the first implementation. [A5] |
| **mmellau/swift-beacon** | Spotlight targets, overlays above sheets, step navigation, asynchronous interactions and VoiceOver support; MIT, Swift 6.2/iOS 18.4 requirements in its package/README. | Closest visual feature match, but **reject as-is** for this app. Its public API uses global state, its live window chooses the first connected scene, and missing targets may be skipped. See the source findings below. [G1], [G2], [G3], [G4] |
| **aheze/Popovers** | SwiftUI/UIKit popovers, source-view attachment, iPad multitasking support, background interaction controls and VoiceOver focus/escape options; MIT. | Reusable presentation fallback, not an action or scenario engine. No need to add it while native popovers meet the requirement. Its README's accessibility claim does not replace an app-level VoiceOver/RTL test. [G5] |
| **ephread/Instructions** | UIKit coach marks, programmatic advancement, stopping, cross-controller flow and documented RTL support; MIT. | Maintainer explicitly marks it deprecated with maintenance only. Avoid a new dependency and UIKit adaptation for this SwiftUI integration. [G6] |

### Why Beacon cannot own the production tour

Reviewed revision: `a177c6fa243e7f6f9c250bbe4197ed011b09d689`.

- `Beacon.swift` keeps a static coordinator and static sequence runner. Cancellation targets that shared runner rather than an application scene/run token. This conflicts with independently owned native scene lifetimes. [G2]
- `BeaconWindowManager.showIfNeeded` selects `UIApplication.shared.connectedScenes.first` and creates an overlay above alert level. It does not receive the exact foreground scene authorized by the application. This is a source-proven integration mismatch; no runtime exploit or device behavior is claimed. [G3]
- `BeaconSequenceRunner.waitForTargets` tries five times with 100 ms waits and accepts any available target. A step with no target advances automatically. That behavior cannot establish successful completion of a mandatory application step. [G4]
- The library's asynchronous completion returns without an ActionCore result or native receipt. An overlay dismissal, a skipped target and an actual action completion must remain different outcomes in the app. [G2], [G4]

A later adoption gate would require an upstream-supported, injectable scene/instance API, owned cancellation/cleanup, and explicit missing-target failure. The app would still retain semantic step execution and receipt validation. Merely prefixing target strings with a scene ID does not fix window selection or shared cancellation. No vendor source was patched and no library was installed for this research.

## Fit to the frozen baseline and reviewed current delta

| Existing boundary at the reviewed application SHA | Consequence for a guide |
|---|---|
| `ActionOrigin` already includes `.guide`; `ActionExecutionContext` is trusted and intentionally not Codable. | The application issues the guide's context. A scenario file supplies neither scopes nor content rights, subjects, scene identity or authority. `.guide` is provenance, not extra permission. [R1], [R10] |
| `ActionRequest` is one strict, typed request; `ActionExecutor` owns policy, deadlines, deduplication, backend freshness and budgets. | Sequence existing calls; do not create a parallel semantic executor or add an arbitrary script interpreter. Count discovery calls in the guide's bounded run budget too. [R2], [R3] |
| The catalog has 29 descriptors, but the baseline implementation set is **five**: `system.listBackends`, `catalog.resolveWork`, `catalog.resolveReference`, `search.query`, `reader.open`. | Do not advertise all catalog names as runnable. `reader.openCommentary`, `search.openResults` and `notes.prepareDraft` are not implemented in this frozen baseline. Independently landed changes must be rediscovered and validated before a later guide uses them. [R4] |
| `UIDestinationDescriptor` already separates destination IDs, component anchors, implementation status and required Core actions. | Reuse these IDs for semantic identity. The descriptor's anchor list is not a live view/frame or proof of visibility. Add only a scene-local view-anchor observation adapter. [R5] |
| `discoverPublicV2` assesses exact presentation/component variants; `bindPublicV2` issues a local plan with original binding guards. | Recheck current eligibility, then bind the exact variant. Cached discovery is not an execution grant. Public V2 is deliberately read/navigation only. [R6] |
| Public intents exclude imported scene, tab, restoration and authority IDs; local binding checks workspace/profile/tab, mapping revision and backend. | Store portable intent data, then bind actual local ownership at execution. Never serialize a prepared command for later replay. [R7] |
| `MaktabahNativeRoutingComposition.open(public:manager:origin:until:)` already reaches the one registry/Core/native path; content uses `executeReaderPlan` and the original reader sink. | A `.guide` caller should use this seam, rather than opening a bespoke URL or mutating the reader model. The full Core reader result and native receipt remain required. [R8], [R9] |

### Reviewed current delta — `5d8ef991`

The five-action set above is retained as the exact `3f085091` research baseline, not the current implementation count. Source was additionally reviewed at `5d8ef991554b01ba6bf3d39222c5ef6cc00a264b`: `reader.openCommentary` was added by `f17d06856fbe2258d17cd6db20052af4801e4486`, making **six implemented actions**. Its original Core path requires the commentary resolver and prepared UI sink, validates the selected destination, and performs the existing reader authorization/receipt flow. Advertisement still depends on the installed ports and current backend availability; its presence in the implementation set alone is not a native acceptance result. [R11], [R12]

`search.openResults` and `notes.prepareDraft` remain pending at this reviewed current SHA. A guide may use commentary only after live discovery and the same original native completion checks. No tests were rerun for this documentation update; the baseline source hashes remain unchanged and the delta is recorded separately in `SOURCES.json`.

At the frozen baseline, registered native surfaces include Library, TOC, History, Search, Annotations, Settings, Reader and Inspector; Search exposes `native.search.query` as a component. Registration is not proof that every surface is currently available on every backend. The host's current live assessment remains authoritative. [R8]

## Proposed implementation contract

This section describes future work. The names `GuideDefinition`, `GuideRun` and `GuideAnchorObservation` below are design labels, not existing exported APIs.

### Scenario data, without one new deep link per scenario

A versioned `GuideDefinition` contains a bounded list of typed steps. A step can describe a public navigation intent, one existing semantic action with typed parameter bindings, a required postcondition, and localized coaching content. Use a restricted allowlist and bounded data sizes; no executable closures, JavaScript, arbitrary key paths, SQL, filesystem paths, raw view selectors or injected permission state in imported data.

Runtime request IDs, deadlines and trusted scene/backend state are issued afresh by the host. Result bindings can consume documented typed fields from an earlier successful action, such as a resolved locator. They cannot import a prior receipt as present authority. Keep the existing wire schemas unchanged.

Example scenario, expressed as data rather than a new URL handler:

| Step | Existing operation | Required evidence before proceeding |
|---|---|---|
| Discover the library | Public V2 `native.library`, current tab | Exact native acknowledgement, then a live anchor in the same scene. |
| Try the search field | Public V2 `native.search`, component `native.search.query` | Current component eligibility and actual mounted query control. In manual mode, wait for the user's real application action. |
| Resolve a passage | `catalog.resolveReference` with a declared user/demo parameter | `completed` and a validated backend-qualified locator. An ambiguous result pauses for an actual choice. |
| Open the resolved passage | Public V2 `native.reader` with that typed content | Original reader reservation, full canonical `reader.open` completion, and exact visible receipt. |
| Explain study tools | Public V2 `native.reader.inspector` | Exact Inspector witness and a live scene-owned coaching anchor. |

A search-result or notes scenario is a later capability-dependent variant. `search.query` returning data does not itself prove the original search-results UI opened; a draft action does not prove a note was saved. [R2], [R4][R6], [R8]

### One scene-owned run, explicit phases

The coordinator retains one active run token per exact scene lifetime. Each step moves through **preflight → execute or await user → validate outcome → observe target → show coaching**. A failed or noncompleted outcome blocks the step; it does not advance the cursor. `completed` for a semantic operation and `.acknowledged` for navigation are necessary at their own boundaries. An action that changes visible UI also needs the real native postcondition. [R2], [R9]

Use a bounded run deadline, step deadline and total action/step budget in addition to existing Core limits. Keep the same run identity across its steps; do not rotate identities to bypass budgets. The existing navigation host may create per-call authority, so the coordinator must also enforce a total run budget rather than assuming a per-call Core budget bounds the whole scenario. [R1], [R3][R8]

An anchor observation is transient presentation data: existing semantic component ID, owning scene/lifetime, current layout revision, visibility, enabled state, accessibility element and local attachment point. It grants no navigation or content access. Reject duplicate IDs within one owner, a target from another window, an empty/occluded frame or an unmounted target. Observe layout/owner changes; do not infer readiness from a delay, cached coordinates or a library's `next()` callback. Coordinate with the existing presentation observer rather than scraping the accessibility tree to invoke controls. [R5], [R6], [R7], [R8], [R9]

### Modes and controls

| Control or mode | Required behavior |
|---|---|
| **Automatic** | After the user starts the scenario, execute only the approved, currently available action steps through existing seams. Pause on ambiguity, foreground/backend change, unavailable capability, rights loss or any required confirmation. |
| **Manual practice** | Present guidance and wait for a matching application-owned action result/postcondition. A coach-mark tap alone does not complete an action step. Existing UI actions that do not yet publish such evidence need a narrow observation hook before they can participate. |
| **Free exploration** | Release exclusive coaching interaction and allow normal app use. Retain only a nonauthoritative checkpoint. Resume after fresh discovery and binding; do not restore a cached grant. |
| **Stop / escape** | Cancel the run's child work, join cleanup, dismiss only its presentation and release only its reservations/observers. No later callback may advance or close a replacement run. Already dispatched native effects remain reported as such. |
| **Back** | Move the explanation cursor. If returning to an earlier screen is needed, perform a new validated navigation. Back is not a generic undo of data changes, saved notes or closed tabs. |
| **Replay** | Begin a new explicit run after the previous run has ended and its effects are known. Re-resolve portable references and live capabilities. Do not automatically retry an uncertain action, silently recreate a lost scene or reuse earlier request/receipt authority. |

TipKit state remains separate. `resetDatastore` removes tip/event/parameter records and is intended mainly for first-launch testing; it must not implement the user's Replay control. [A4]

## Readiness, cancellation, accessibility and recording

**Readiness and failure:** the exact backend, generation/RPC epoch, scene lifetime, selected profile/workspace/tab and mapping authority must remain current across awaits. Preserve `ui_queued`, `requires_foreground`, `requires_backend_switch`, `needs_disambiguation`, `unavailable`, `stale_state`, `cancelled` and uncertain-effect failures as separate states. Reconcile an uncertain original request before offering a new execution. No automatic selection of the first candidate, first window, alternate backend or substitute book. [R2], [R6], [R7], [R8], [R9]

**RTL and accessibility:** use leading/trailing and semantic navigation symbols, localized Hebrew copy and mixed Hebrew/Latin content. Apple distinguishes directional navigation that should mirror from actual spatial directions that should not. Test keyboard/pointer access, VoiceOver reading and focus restoration, large Dynamic Type, contrast, Reduce Motion and Reduce Transparency. A spotlight must have a text/control equivalent. Keep Stop accessible in every phase and avoid timed automatic advancement of instructions while assistive technology is reading. Native accessibility focus APIs and Reduce Motion values are available building blocks; no claim of app-level accessibility acceptance is made here. [A6], [A7], [A8], [A9]

**Future recording:** record opt-in, app-owned semantic events, not raw taps, screenshots, passwords, note bodies, selected text or SDK prompts. A recording may retain scenario/version, action or destination ID, explicit nonsensitive parameters and typed reference placeholders, plus completion classification. Runtime scene IDs, credentials, grants, receipts and backend epochs are not replay payloads. Private content parameters require a separately designed storage/rights policy and user review. Record only actions that actually traverse the common engine; do not promise universal recording of legacy UI gestures. Replay reauthorizes every step. [R1], [R2], [R3], [R4], [R5], [R6], [R7], [R8], [R9]

## Implementation acceptance plan

All rows below are **NOT_RUN for guided tours**. They are acceptance work for a future implementation, not passes inferred from this research or unrelated native tests.

| ID | Scenario | Required result/evidence |
|---|---|---|
| GT-01 | Valid and invalid manifest; unknown action/component/version; oversized or cyclic result bindings | Deterministic validation; no effect for invalid data; bounded execution. |
| GT-02 | Automatic reference → Reader → Inspector journey | One original Core action per step; exact source/scene receipt; actual visible original Reader and Inspector, with native screenshots/logs. |
| GT-03 | Manual practice and free exploration | Only matching real postconditions advance; arbitrary Next/tap or another window's action does not; normal app behavior remains usable. |
| GT-04 | Stop before dispatch, during backend wait, after dispatch and during target observation | No orphan task/observer; no duplicate effect; post-dispatch uncertainty retained; old cleanup cannot affect replacement run. |
| GT-05 | Back and replay after success, failure, cancellation and uncertain effect | Fresh authorization, correct cursor, no generic data rollback and no automatic replay of uncertain work. |
| GT-06 | Two windows with the same component IDs; background/foreground and close/remount | Exact authorized scene only; no global-first-window fallback or reuse of old scene lifetime. |
| GT-07 | Backend switch, generation/RPC reset, profile/tab/selection/permission change, ABA | Current authority rejects the stale step; no privilege or content-rights transfer. |
| GT-08 | Missing, duplicate, delayed, hidden and partially clipped target; sheet, Inspector, keyboard, rotation and multitasking | Wait for actual readiness within a deadline or block explicitly; no silent skipped mandatory step. |
| GT-09 | Hebrew/English, mixed script, Dynamic Type, VoiceOver, keyboard, pointer, reduced motion/transparency | Readable, correctly directed controls; usable Stop; correct focus and layout; actual iPad/device evidence where required. |
| GT-10 | Capability unavailable or not implemented; catalog-only action; ambiguous locator | Honest status and user resolution; no fake success or silent action substitution. |
| GT-11 | App background, process termination and relaunch | At most a nonauthoritative checkpoint restores; no automatic effect replay; existing reader/tabs/drafts/data restoration preserved. |
| GT-12 | Opt-in recorded scenario exported/imported under different profile/backend | Sensitive state excluded; schema migration and access checks pass; references re-resolve or explicitly block. |

Start with portable coordinator tests over the **real existing Core/Registry contracts** and explicit host doubles. Then use existing Apple tools to typecheck the narrow adapter and run a focused native pilot through original screens. Run affected reader/search/notes/restoration regressions before enabling a guide. Record immutable source SHA, SDK/device, expected and actual outcomes and raw receipts. Synthetic driver, compilation and visual overlay success remain different from native feature acceptance.

## Remaining implementation gates and handoff

1. **Guide context and app-event adapter:** `.guide` exists, but the frozen baseline has no guide coordinator or complete trusted guide-context/event publisher. Reuse existing authority and content-rights owners; do not infer rights from the origin or scenario. Search/content practice remains unavailable until its genuine context can be issued. [R1], [R8]
2. **Live component anchors:** existing IDs and eligibility need a minimal scene-owned anchor observation bridge. This must not turn metadata or an accessibility identifier into a mutation capability. [R5], [R6], [R7], [R8]
3. **Optional spotlight:** Beacon's current global scene selection and skip semantics block direct adoption. Native coaching remains the initial path. A changed Beacon version would need source re-review and GT-04/06/08/09 before selection. [G2], [G3], [G4]
4. **Capabilities beyond the reviewed current six:** `reader.openCommentary` is now implemented in the explicitly reviewed delta; `search.openResults` and `notes.prepareDraft` remain pending. Use live discovery after further semantic-action work lands; no native acceptance is inferred from an implementation flag or inventory descriptor. [R3], [R4], [R11], [R12]
5. **Native/device verification and recording:** the guide pilot, accessibility/RTL matrix, checkpoint behavior and private-parameter recording policy are not implemented or executed by this research.

Research scope is complete: original task requirements, reusable options, exact source mismatches, contract reuse, execution/control semantics and implementation acceptance are documented. There is no product implementation or new dependency in this change. No Swift/Apple/UI test was run for this document; only source/document review and document/provenance checks were performed. The old Asana pause is superseded by the owner's explicit current resume instruction; this research does not expand its scope into implementation.

## Sources

All external sources are Apple documentation or the original library repositories; retrieved 2026-11-19 UTC. Repository links below are immutable where code details support the decision. `SOURCES.json` records the exact snapshots.

[A1]: https://developer.apple.com/documentation/tipkit/
[A2]: https://developer.apple.com/documentation/tipkit/tipgroup.md
[A3]: https://developer.apple.com/design/human-interface-guidelines/offering-help.md
[A4]: https://developer.apple.com/documentation/tipkit/tips/resetdatastore().md
[A5]: https://developer.apple.com/documentation/swiftui/view/popover(item:attachmentanchor:arrowedge:content:).md
[A6]: https://developer.apple.com/design/human-interface-guidelines/right-to-left.md
[A7]: https://developer.apple.com/design/human-interface-guidelines/accessibility.md
[A8]: https://developer.apple.com/documentation/swiftui/accessibilityfocusstate.md
[A9]: https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion.md
[G1]: https://github.com/mmellau/swift-beacon/blob/a177c6fa243e7f6f9c250bbe4197ed011b09d689/README.md
[G2]: https://github.com/mmellau/swift-beacon/blob/a177c6fa243e7f6f9c250bbe4197ed011b09d689/Sources/Beacon/Beacon.swift
[G3]: https://github.com/mmellau/swift-beacon/blob/a177c6fa243e7f6f9c250bbe4197ed011b09d689/Sources/Beacon/Core/BeaconWindowManager.swift
[G4]: https://github.com/mmellau/swift-beacon/blob/a177c6fa243e7f6f9c250bbe4197ed011b09d689/Sources/Beacon/Sequence/BeaconSequenceRunner.swift
[G5]: https://github.com/aheze/Popovers/blob/576b4d3eacd9c6e4101519d803726e44bb2a3c45/README.md
[G6]: https://github.com/ephread/Instructions/blob/0f3efa77e781ffd4c1441e580d398e3d60ff3bfe/README.md
[R1]: https://github.com/davidpovarsky/Maktabah/blob/3f085091edbf86117e1ce9b1d10d2f2b87bfbc4d/Source/Otzaria/Actions/Sources/OtzariaActionCore/Policy/ActionExecutionContext.swift
[R2]: https://github.com/davidpovarsky/Maktabah/blob/3f085091edbf86117e1ce9b1d10d2f2b87bfbc4d/Source/Otzaria/Actions/Sources/OtzariaActionCore/Contracts/ActionRequest.swift
[R3]: https://github.com/davidpovarsky/Maktabah/blob/3f085091edbf86117e1ce9b1d10d2f2b87bfbc4d/Source/Otzaria/Actions/Sources/OtzariaActionCore/Engine/ActionExecutor.swift
[R4]: https://github.com/davidpovarsky/Maktabah/blob/3f085091edbf86117e1ce9b1d10d2f2b87bfbc4d/Source/Otzaria/Actions/Sources/OtzariaActionCore/Registry/ActionRegistry.swift
[R5]: https://github.com/davidpovarsky/Maktabah/blob/3f085091edbf86117e1ce9b1d10d2f2b87bfbc4d/Source/Otzaria/UIRouting/Sources/OtzariaUIRouting/Registry/UIDestinationDescriptor.swift
[R6]: https://github.com/davidpovarsky/Maktabah/blob/3f085091edbf86117e1ce9b1d10d2f2b87bfbc4d/Source/Otzaria/UIRouting/Sources/OtzariaUIRouting/Registry/UIDestinationPublicNavigationV2.swift
[R7]: https://github.com/davidpovarsky/Maktabah/blob/3f085091edbf86117e1ce9b1d10d2f2b87bfbc4d/Source/Otzaria/UIRouting/Sources/OtzariaUIRouting/Ports/PublicNavigationLocalBinding.swift
[R8]: https://github.com/davidpovarsky/Maktabah/blob/3f085091edbf86117e1ce9b1d10d2f2b87bfbc4d/Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeRoutingComposition.swift
[R9]: https://github.com/davidpovarsky/Maktabah/blob/3f085091edbf86117e1ce9b1d10d2f2b87bfbc4d/Source/Otzaria/UIRouting/Sources/OtzariaUIRouting/Ports/SceneNavigationPort.swift
[R10]: https://github.com/davidpovarsky/Maktabah/blob/3f085091edbf86117e1ce9b1d10d2f2b87bfbc4d/Source/Otzaria/Actions/Sources/OtzariaActionCore/Policy/ActionPolicy.swift
[R11]: https://github.com/davidpovarsky/Maktabah/blob/5d8ef991554b01ba6bf3d39222c5ef6cc00a264b/Source/Otzaria/Actions/Sources/OtzariaActionCore/Registry/ActionRegistry.swift
[R12]: https://github.com/davidpovarsky/Maktabah/blob/5d8ef991554b01ba6bf3d39222c5ef6cc00a264b/Source/Otzaria/Actions/Sources/OtzariaActionCore/Engine/ActionExecutor.swift

# MiniApps original rich editor integration — source checkpoint

This checkpoint is implementation work, not native or release acceptance.

## Current implementation

The MiniApps adapter uses the actual AnytypeOriginalEditor local annotation session. Before opening another app, it captures the complete native draft, commits the canonical row through the original SQLite revision CAS, reopens the saved row and restores the exact native selection witness. The shared Picker then sends source context; execution stays in the standalone MiniApps application.

A successful return applies through the original native services, captures the full native archive and commits that archive, original revision history, original sync queue and exact MiniApps result receipt on the same original SQLite handle. Transport acknowledgement follows the durable receipt. Already committed returns are acknowledged without editing the native draft again.

A pre-dispatch context conflict uses the SDK's canContinueEditing state and a fresh canonical-row check. When both remain valid, the same newer unsaved draft stays editable. A terminal capture or uncertain native mutation still retires that draft and retains original recovery evidence. No distributed atomicity is claimed across the native engine and SQLite.

The original Settings screen embeds MiniAppPreferencesView from the one shared Picker package. Source consumers do not embed execution engines.

## Ownership and authorization

The user's explicit project instruction of 25 November and standing repository authorization of 19 November authorize these focused integration changes. The original upstream interface and SDK ownership remain intact.

| Files | Ownership | Change and boundary |
| --- | --- | --- |
| Source/ChavrusaText/Annotations/LocalEditor/AnnotationLocalEditorSession.swift | Downstream host | Additional result receipt on the same original local persistence transaction. |
| Source/ChavrusaText/Annotations/LocalEditor/AnnotationOriginalEditorMount.swift | Downstream SDK adapter | Calls public original facade; canonical source and ownership checks retained. |
| Source/ChavrusaText/Annotations/LocalEditor/AnnotationOriginalEditorProductionUI.swift | Downstream composition | Existing editor presentation owns launch, receive, reopen and conflict recovery. |
| Source/ChavrusaText/MiniApps/OtzariaMiniAppsCoordinator.swift | Downstream bridge adapter | Shared picker/settings, exact scene owner, pending callbacks and native receipt acknowledgement. |
| Source/ChavrusaText/MiniApps/OtzariaMiniAppsPersistence.swift | Downstream storage adapter | Exact return receipt and rich-body commit on original captured SQLite handle. |
| Source/Features/Setting/SettingsView.swift | Upstream UI integration seam | One navigation section to downstream preferences. The private original form cannot receive that registration from an extension; all feature logic stays downstream. |
| Scripts/CI/otzaria-miniapps-native.py | Downstream native acceptance | Requires authentic original-editor routes for a real app build and records their identity. |

## Actual checks and remaining work

Six changed Swift files parsed successfully with the actual Scaleway Mac Apple Swift 6.4 and iPhoneSimulator27.0 SDK, targeting arm64 iOS Simulator. Exact hashes and command are in APPLE_SYNTAX_PREMERGE.json. Python driver syntax and git diff whitespace check passed. Syntax does not establish API compatibility, native runtime behavior or TestFlight readiness.

The facade implementation is maintained separately in the Anytype repository (d9453b59171d1192c7bccbbdf65e5b2932f50de2 plus later warm-context correction). Qualified SDK binaries have not yet been produced for these APIs. The shared final Hanlin source and authentic MiniApps producer remain pending. runtime27-original-editor-routes.inputs.json is still UNFINALIZED. Consumer source pins must be renewed after the frozen final source merge; the historical source-pin correction is not acceptance for this code.

Fresh parallel Maktabah final-delivery source 7028e8cbceed9914c51c526c680026aecbc137ca adds native receive/revision/backfill, identity and complete-note preservation. It is being integrated next with explicit conflict review, preserving both feature sets. Full original-app warm/cold/reader/rich-editor acceptance, signing and TestFlight remain NOT_RUN here.

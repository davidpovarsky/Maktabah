# Wave 3 — original Settings component navigation

Base: `b10032f32f83b83e61e5c68dc41d10f33fbe7e8e`. The user-facing UI remains the original `Source/Features/Setting/SettingsView.swift`, with its original Form, Picker, Toggle, NavigationLink, Button actions, data bindings, labels, and section conditions. The owner’s current OS requirement is iOS/iPadOS 27.0 only (the original 17 November override is retained in the earlier crosswalk).

## What this change implements

The existing public-v2 `component` field and `FocusSpec(kind: .component, anchor: ...)` now describe 15 exact original Settings controls. The parent remains `native.settings`, presentation remains `sheet`, and the original Core/orchestrator performs one guarded synchronous commit. The commit publishes both the existing sheet flag and the exact reveal target; first mount and scrolling render that same committed UI state within its original deadline. No new preparation, admission, authorization, or substitute receipt is created by the render callback.

A component receipt means that the fixed original target was revealed in the correct foreground key window and actual clipped scroll viewport. It does not mean that a Toggle changed, a Picker selected another value, a link was activated, a command button ran, a keyboard became first responder, or VoiceOver speech was verified.

| Component suffix after `native.settings.` | Original target | Original availability retained |
| --- | --- | --- |
| backend | Library source Picker | Source not transitioning |
| offline | Manage Offline Library NavigationLink | Offline capability and provider |
| databaseMode | Database mode Toggle | Native Maktabah data path |
| history | Reading history Toggle | Original Settings |
| storage | Choose Library Folder Button | Native Maktabah data path |
| annotations | Hide missing-book annotations Toggle | Original Settings |
| cloud | CloudKit Toggle | Original Settings |
| appearance | Use system theme Toggle | Original Settings |
| searchData | Search Data NavigationLink | Original Settings |
| searchCredits | Zayit Search Credits NavigationLink | Original Settings |
| searchIndex | Original migration/optimization prompt row | Native path and migration needed |
| optimization | Original vacuum/optimization Button | Native path, bundle mode, pending/running vacuum |
| updates | Original library update Toggle | Native path and bundle mode |
| downloads | Original full-library download Button | Native Maktabah data path |
| miniApps | Original Mini Apps preferences NavigationLink | Original Settings |

A collision alert, original FTS overlay, unavailable source/control, replaced original view, wrong scene, background window, expired/revoked original admission, source generation change, or offscreen/covered control cannot produce a successful component facet. A pushed Settings child is not treated as the original Form; an already-true sheet flag cannot pretend to pop that original NavigationStack.

The registry still limits public components to fixed declared anchors, and its original 16-components-per-rule bound remains. No public URL carries setting values or private selection identity. No test criteria, original selectors, timeouts, or original Native116/Release114 manifest counts changed.

## Reusable source/lifecycle contract

The actual portable owner is `NativeComponentRevealOwner` in the existing `ChavrusaUIRoutingHost` package. The app integration file retains the names `MaktabahNativeComponentOwner` and `MaktabahNativeComponentDescriptor` as aliases.

A feature factory supplies:

```swift
MaktabahNativeComponentOwner(
    destination: fixedDestination,
    presentation: originalPresentation,
    descriptors: fixedDescriptors,
    available: { anchor in /* read the original feature capability/state */ },
    captureSource: { anchor in
        // Retain original model/tab/node/structure identity once.
        return { /* throw if that exact original source changed */ }
    }
)
```

Composition calls `retainSource` before the first public-binding/directory/Core await. The original public binding revalidates the same capture; begin, render, geometry completion, and later visible-source checks retain it. A feature must not recapture a newer model merely because it still has a similarly named control.

Session APIs are `componentOwner(for:)`, `attachComponentOwner(_:)`, `detachComponentOwner(_:)`, and `componentStateDidChange(_:)`. Only the main integration writer registers factories/descriptors. The original view renders with:

```swift
ScrollViewReader { proxy in
    originalForm
        .modifier(MaktabahNativeComponentContainer(
            owner: session.componentOwner(for: fixedDestination),
            blocked: { originalOverlayIsBlocking },
            reveal: { anchor in proxy.scrollTo(anchor.rawValue, anchor: .center) }
        ))
}
```

The exact existing row/control receives its fixed `.id(anchor.rawValue)` and passive `MaktabahNativeComponentWitness(anchor:owner:)` background. The witness is non-interactive and inaccessible; the original control keeps its actual label, value, action, and accessibility semantics. It checks real UIKit key-window/scene ownership, ancestor visibility/alpha/clipping, scroll adjusted content insets, dragging/deceleration, and modal/transition coverage. The parent’s original `NativeSurfaceWitness` must also complete its real native appearance.

No expanded/current-selection TOC phase is claimed by this initial Settings change. A later original feature may need a source-bound, bounded render phase after its actual expansion publishes; merely changing a model or calling scrollTo is not successful visible evidence.

## Query and system behavior

The genuine system entity service still resolves identifiers and executes against fresh foreground discovery. Exact feature-name text queries now take precedence over substring matches, while preserving every matching window identity. This prevents new “Search Data” controls from making the original exact “Search” root query ambiguous. The added English/Hebrew tests preserve identifier, backend, duplicate-catalog, foreground, source freshness, cancellation, and capacity behavior.

Background identity resolution may describe an existing component in its original mounted scene before the system activates that scene. It grants no execution authority; execution must rediscover and validate the component after activation.

## Actual verification

- Actual portable owner + existing intent service: **36 tests PASS, 0 failures**, 0.031 seconds test time; incremental build 11.72 seconds. Exact command, log hash and full output are in `validation/component-owner-and-intent-result.json` and its paired log.
- Initial owner-only control run: 10 PASS; two test-fixture capture warnings were removed using explicit source objects. Its original log is preserved losslessly as validation/component-owner-tests.log.gz and in the original Oracle diagnostics directory.
- iOS 27 active conditional-branch syntax parsing: passed for the six changed/new app source files and the appended native test file. This is parsing, not Apple SDK typechecking.
- The complete previous `NativeRoutingAcceptanceTests.swift` at base b100 remains an exact byte prefix. New native cases and the shared component helper are appended.
- The prior `native.annotations` reobservation change remains present. This change does not claim to fix that separate runtime failure.
- `git diff --check` passes.

### New native cases — authored, not compiled or run here

- `NativeRoutingAcceptanceTests/testSystemAppIntentSettingsAppearanceFromHistoryDoesNotMutateValue`
- `NativeRoutingAcceptanceTests/testSystemAppIntentSettingsSearchDataRevealsOriginalLink`
- `NativeRoutingPhoneAcceptanceTests/testPhoneSystemAppIntentSettingsAppearanceFromBackgroundDoesNotMutateValue`
- `NativeRoutingPhoneAcceptanceTests/testPhoneSystemAppIntentSettingsSearchDataRevealsOriginalLink`

These use the real App Intents system API, start from the original History page, require the original target to exist and be hittable, correlate its exact component with the original canonical receipt, preserve the Reader workspace, and verify that the appearance value is unchanged. They are separate focused cases, not substitutions for the historical acceptance suites.

The reusable helper is `runOriginalComponentSystemIntent(expectedPad:destination:title:anchor:identifier:presentation:fromBackground:launchArgs:expectedValue:)`, appended in the original test class’s source file. Downstream features can call it from separate test extensions with their exact original control IDs.

## Integration and remaining gates

The app uses a regular PBXGroup for Source. Root must register these two app-target files in the existing Native Routing Host group and app Sources phase:

- `Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeComponentBinding.swift`
- `Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSettingsComponents.swift`

The portable owner file is automatically discovered by its existing Swift package and must not be duplicated into the app target. Root coordinates TOC/library adapter registration and source pins in the same final project edit.

The original Settings file changed and needs an authentic source-bound owner-gate delta through the existing workflow. Existing signatures remain historical evidence. No signature, approval, owner count, gate, or provenance record was fabricated or weakened.

Still required: Apple SDK Debug/Release typecheck and build, actual iPad/iPhone focused runs, accessibility/VoiceOver evidence, final production-v40 acceptance, full final suites, authentic applicable owner attestation, and release/signing validation. Revealing Search Data/Offline/Mini Apps links does not claim navigation inside those child screens. Historical inventory rows for language/accessibility/data-profile/detail controls remain open until actual original controls and exact acceptance are established.

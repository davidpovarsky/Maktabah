# Typed TOC and Library component bindings

Base: 9aa3becfadffc652b8fcd0340cc1f21db676abb4.
Live upstream checked before edits: 4203de5fd77beb119e5826e039be1a61325f7be0.
Merge base: a0ed0df908a6cb38bc459d4baaeb400f447b2fc4.
Root reserved this isolated tree and the original hooks. No shared routing,
project file, dependency, source admission or signing file is edited here.

## Ownership and narrow hooks

| File | Ownership | Necessary change | Downstream behavior |
| --- | --- | --- | --- |
| Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift | Upstream-owned; exact upstream/base blobs in OWNERSHIP_PRE_EDIT.json | Attach presentation lifecycle and passive witnesses to original ThemeList and structure Picker | MaktabahNativeTOCComponents.swift owns catalog, availability and retained source validation |
| Source/Features/Library/iOS/iOSLibraryView.swift | Upstream-owned; exact upstream/base blobs recorded | Attach lifecycle/witnesses to original collection wrapper and original controls | MaktabahNativeLibraryComponents.swift owns catalog and retained source validation |
| Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeTOCComponents.swift | New downstream file | Typed TOC component adapter | Existing reader/tab/model/structure ownership is revalidated; no node selection, loading or query changes |
| Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeLibraryComponents.swift | New downstream file | Typed Library component adapter | Existing model/backend/list generation and private filters remain read-only |

Original TOCNodeRow.swift and LibraryViewControllerWrapper.swift are reserved for
a later necessary selected-row hook; they remain unchanged in the initial scope.
A wrapper outside the original controls cannot prove the exact control is on
screen, which is why the narrow passive original-view hooks are needed.

Task scope: Wave 3 UI-03, original Asana UI Automation 1220542361135050 and root
integration ownership 1220939535420506. The standing owner policy authorizes the
necessary upstream hooks; release signatures must later match final source.

## Fixed public catalog

TOC: native.reader.toc.contents and native.reader.toc.structure.
Library: native.library.contents, native.library.grouping,
native.library.downloadedFilter and native.library.options.

The original controls keep their action handlers, labels, native presentation
and data owners. Navigation never executes a Menu, changes its selected value,
runs a download/import/delete, clears a search, or enters bulk selection.
Cold parent presentation goes through the existing canonical route. The passive
witness independently proves visibility of the original component.

A private current TOC node cannot be encoded in a public component token.
Current-selected-row reveal remains gated until a bounded original expansion/
render phase and exact model/node/structure retention are implemented and tested.

## Dependencies and verification

This source depends on ui_acceptance's canonical ComponentOwner/Container/
Witness API, including captureSource captured before the first Core suspension,
and session.componentOwner(for:). Root owns the minimal Xcode project source
membership for all new integration files; Source is not a synchronized group.

No native acceptance is claimed by this report. Apple compile, real native
routing, wrong-source/detach/late-callback controls, Hebrew/English, VoiceOver,
keyboard and physical-device acceptance remain pending until their actual
receipts are recorded. Existing original tests and runtime gates are preserved.

## Native selectors and catalog intake

NATIVE_SELECTORS.json lists five additional original system-intent selectors,
three for iPad and two for iPhone. The source helper belongs to the shared UI
lane and retains the original Reader workspace and exact canonical receipts.
These selectors are prepared, not executed. They do not alter the historical
Native116/Release114 selectors or convert syntax checks into native passes.

LOCALIZATION_INTAKE.json contains the two distinct English/Hebrew component
titles for root's shared catalog integration. These entries are not yet applied
in this branch. No localization file is edited here.

## Preserved attempt evidence

The first syntax attempt and its exact four source inputs are retained under
validation/attempt-1. The original TOC snapshot has four pre-existing blank
lines with trailing spaces. A whole staged-tree whitespace check reports those
four evidence lines; they are preserved to keep the recorded source hashes
valid. The live product diff and new adapter/test files pass the whitespace
check. No product behavior or acceptance gate was changed for this finding.

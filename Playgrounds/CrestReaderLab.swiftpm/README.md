# Crest Reader Lab — Swift Playgrounds iPad experiment

This is an experimental App Playground built from ORIGINAL source files, not a visual imitation.

## Current implementation and exact scope

- Crest: the ORIGINAL BrowserSidebarPageLayout, BrowserRootSidebarLayoutReservation, BrowserRootSidebarSurfaceLayer, BrowserFloatingSidebarCardBackground, BrowserSidebarPresentation, BrowserSidebarToggleAction and their support code. These original layout and card source files are unchanged. The left-hand list of tabs/books and Space titles is a Playground-only data fixture, NOT Crest's production sidebar list. The functional Crest C# backend is NOT embedded.
- Maktabah: the ORIGINAL ArabicTextRenderer, iOSCustomIbarotTextView class (unchanged excerpt of the class defined in iOSIbarotTextView.swift), CachedArabicLayoutFragment, TextKit NSRange layout extension, EnhancedUnderlineRenderer, TextViewState, string cleaning, font models and four original font files. These original source excerpts/files are unchanged, rendered with Hebrew and Arabic sample text through a small UIViewRepresentable host.
- Original entire iOSReaderView and entire iOSIbarotTextView wrapper are NOT included yet. The Playground host supplies a small demo toolbar and sample text; it is NOT the production full Maktabah reading screen.
- The included UI is built from actual original code where labeled; no database, server, CloudKit, account or search layer is required.
- All support models in Sources/Support are deliberately mock data shims, separate from Original folders. Nothing in upstream Maktabah was edited.

## Usage on iPad

1. In Files, download and unzip the experiment archive if received as ZIP.
2. Open the CrestReaderLab.swiftpm folder in Swift Playgrounds (App Playground).
3. Run on an iPad using iPadOS 26.0 or later. The project expects only one App entry point: Sources/App.swift. Do not add a second MyApp.swift with @main.

## Limits and verification

- Swift grammar parse on Windows Swift 6.3.3 passed.
- SwiftPM manifest dump on Windows Swift 6.3.3 passed.
- This is NOT proof of iPad compilation. The GitHub Actions XcodeGen workflow on macos-26 is the Apple SDK gate.
- The actual full Crest sidebar list and complete Maktabah iOSReaderView have deeper dependencies. They cannot be asserted present in this Playground.
- Original Crest distribution requires MPL-2.0 notices. Maktabah original GPL-3.0 terms apply. See Licenses directory.

## Provenance

- Crest source: pauljoda/Crest, checkout 74b3c75.
- Maktabah source: bismillah-100/Maktabah, commit 46e893c65139fbb1e582d6595b0d220ea912324a.
- Copied source files in Original folders were imported unchanged, except iOSCustomIbarotTextView.swift, which is the verbatim single-class excerpt from the upstream full iOSIbarotTextView.swift. Byte-for-byte source can be verified against original files.

## iPad Swift Playgrounds compatibility fix
- App Playground deployment target is now iOS 26.0, compatible with a 26.0 SDK.
- Font registration no longer references Bundle.module; it uses discovered resource bundles and Bundle.main.

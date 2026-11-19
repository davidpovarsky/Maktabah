# Native Sheet Lab — iPadOS 27 IPA

This standalone demo targets the Apple system SwiftUI sheet with presentationDetents, presentationBackgroundInteraction, presentationContentInteraction and iPadOS 27 presentationPlacement. No FloatingPanel or third-party view libraries.

## Build
Open the dedicated Actions workflow "Native Sheet Lab iPadOS 27 IPA" on branch demo/native-sheet-lab-ipa-20261119. The workflow compiles using Xcode 27 device SDK with CODE_SIGNING_ALLOWED=NO, and packages a Payload/NativeSheetLab.app IPA.

## Install with SideStore
Download a successful workflow artifact, extract its ZIP, and import NativeSheetLab-iPadOS27-unsigned.ipa into SideStore. SideStore signs the app using your own Apple ID. iPadOS 27 or newer required. No credentials are stored in GitHub.

## Scope
Demo only: mock text reader and mock chat. No Hanlin, production Otzaria code, network calls or third-party window library. Isolated demo source in NativeSheetLab-iOS; existing Maktabah production files untouched.

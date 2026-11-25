# Native Sheet Lab — iPadOS 27 IPA (1.1.0)

Standalone Apple SwiftUI demonstration, no third-party window library. The same mock chat and reader state are shared across three presentation modes: native Sheet, native Inspector, and NavigationSplitView.

Sheet appearance choices: system default, regular material, ultra-thin material, regular Liquid Glass, clear Liquid Glass, fully transparent background (without a glass effect), solid background. The glass choices use the public glassEffect modifier inside a native presentationBackground, rather than reimplementing the presentation controller or gestures. Actual appearance and inspector placement are subject to system behavior and accessibility settings.

Open the Hanlin menu in the reader or the sidebar icon in the chat header to switch modes. The sheet's native dismissal finishes before the docked presentation opens.

## Build
Requires Xcode 27, iOS 27 SDK and XcodeGen. Generate the project with xcodegen generate --spec project.yml. Build Release for generic/platform=iOS, CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO, then zip Payload/NativeSheetLab.app into an IPA. The existing GitHub Actions workflow performs the same build.

## Install
Import the unsigned IPA into SideStore to sign with your account. Requires iPadOS 27 or later. This is a local demo, not an integrated Hanlin or Maktabah release. No credentials, network requests, or changes to production Maktabah.

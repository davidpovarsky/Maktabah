# Search empty-history description contrast

## Observed original failure

Native repair12 run 44673191816, checkout6030087e27f75b26d9a9bb144ba9ba71eaddadc5 / app461de9aaee620d4275a1676ce8e1c230eb8e27ad, failed the complete unfiltered GlobalSearchNativeAcceptanceTests/testHeaderAndHistoryNativeAccessibilityAudit. The actual issue identifies the description text "הקלידו מילים ולחצו על חיפוש." at (137.8,524.5,238.5,24.0). Its original element crop shows gray description text on the app's cream background. This is distinct from the history heading.

Exact issue/crop and their CRC/SHA proofs are retained in ../native-repair12-44673191816-20261120/captures/entries/visual-11-search:
- C24BB6B9-8611-4C30-89A7-722CB2E5524E.txt
- 6B2DD8DE-8113-4229-BCA2-223CCF6E4D5F.png, SHA256 9473b490c83d8e3942708448943632eff3023f3f67fde890c76f4dd904c41081.

The complete GlobalSearchHistoryContent file was identical in the tested app, c61213d9 and current integration2997c7c5. Its baseline SHA256 is3c591f21c7b545a0d612f01f9cdd86bef543503ad1f7d91be71dc24cb8235b14.

## Narrow production change

The existing ContentUnavailableView receives the same description Text with explicit foregroundStyle(Color.primary). Color.primary selects the semantic adaptive primary color directly rather than leaving the description to the container's relative secondary styling. No fixed light/dark color, opacity, typography, string, history operation, layout, identifier or audit exclusion is introduced.

The exact inverse of this one modifier restores the entire original source bytes. The complete unfiltered audit file remains byte-identical to the original run, SHA256 fdcf38a22fa039bbd4a8f8183c1e3d6a93ceca889af6cc0ee6e0e7146e2c42b1.

## Type and validation boundary

The [official Apple Text.foregroundStyle documentation](https://developer.apple.com/documentation/swiftui/text/foregroundstyle(_:).md), read2026-11-20, declares a nonisolated generic method returning Text, with iOS/iPadOS availability17+. Thus the description expression retains the Text type required by the unchanged initializer; the existing ContentUnavailableView already has that platform floor. This is an API-contract review, not an Apple compiler execution.

The exact changed file passed Swift6.3.3 syntax parse on Windows with zero diagnostics. An independent source review found no concrete type/style blocker and confirmed that only the description Text is affected. VALIDATION.json preserves the command, source hashes and exact inverse check.

Apple SwiftUI typecheck and the original unfiltered Native accessibility audit have NOT_RUN on this change. Native success is not claimed. The unchanged original audit must pass on the next actual source-bound Apple run before this acceptance condition can close.

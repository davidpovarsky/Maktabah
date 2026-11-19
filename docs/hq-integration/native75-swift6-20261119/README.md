# Swift 6 XCTest isolation repair — 2026-11-19

The previous SDK and Native70 builds stopped before UI execution because the NSPredicate Any? callback parameter was transferred into MainActor.assumeIsolated. The exact reader assertion now captures the existing actor-owned XCUIElement, matching the adjacent native layout predicate. It still reads the actual native value on MainActor and compares all source text after the same bidi/outer-whitespace normalization. No assertion, fixture, timeout, selection or product code changed.

Ownership: the XCTest file was added by fork commit 2a46d52c and is absent from live upstream d46af139. No upstream application file is touched. The sole continuation developer performed the change.

Local verification: Swift syntax and diff checks passed. All 75 selected Native declarations remain present and unique, preserving the original 27-case requirements. These checks execute no UI; Apple SDK compilation and Native acceptance remain pending until their run evidence is recorded.

Rollback: revert the dedicated test repair commit; no user database or state changes are involved.

## First real Apple result

Run 44558147540 compiled the repaired XCTest sources successfully with Xcode 27.2/Swift 6.4.2 and verified all 75 selected declarations. Exact Git-blob repaired-source hash matched the artifact (Windows worktree CRLF is not the checkout byte format). The overall job failed later because the standalone Hanlin navigation proof omitted package platforms and therefore targeted macOS 12. Both original pinned SDK manifests specify iOS 27/macOS 26. The generated proof manifest now uses those same platforms; original SDK sources, all eight assertions, product deployment targets and safety checks are unchanged. Full rerun and Native evidence are still required. See SDK_44558147540.json.

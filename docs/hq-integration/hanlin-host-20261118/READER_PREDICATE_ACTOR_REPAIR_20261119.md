# Original reader predicate actor correction

The SDK/navigation-only native run 44452119143 at b5c7a72ed604f9a7845294dac552538a51efd764 failed during the existing iPad SDK typecheck at FaithfulReaderUIAcceptanceTests.swift:373. Swift rejected sending the NSPredicate callback's untyped element into MainActor.assumeIsolated. This is a compile failure, not a runtime/navigation acceptance result.

The predicate now captures the original reader-text XCUIElement already selected immediately above. The preceding native-frame predicate uses this same actor-bound access pattern. The exact source-text normalization, equality, timeout, original TextKit assertions and remaining assertions are unchanged. The NSPredicate callback still evaluates the same reader element.

The full authenticated failed log is retained externally with SHA256 2ee2fe0aba5c43cf003603c980212941dc1a1cd9aae3955a2c75017091e5a841. Official run/artifact metadata is retained alongside it. The previous generated manifest platform correction remains in place; the complete original eight navigation proof methods remain unchanged. No runtime/source-opening/whole-app acceptance is inferred from a compiler check.

Local Swift 6.3.3 grammar parsing and git diff whitespace checks pass. Apple compiler verification is the replacement native run. Unfinished scene chat/history composition remains a separate unpublished worktree change and is not part of this correction.

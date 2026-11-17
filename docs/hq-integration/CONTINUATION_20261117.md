# Otzaria continuation — 2026-11-17

Owner authorization in the current conversation covers all three phases, ordinary push of the continuation branch, existing macOS/Xcode/iOS 27 CI, Asana updates, and TestFlight only after actual acceptance gates. No additional agents, account/plan/permission changes, or quota purchases. Prior work and user databases remain preserved.

Base: 94564afb043134170f27ca72f8b320c6e8a7b150. Branch: codex/otzaria-complete-phases-20261117. The three existing uncommitted iOS 27 target files were copied after exact base-blob and target-only diff verification. The original worktree and backups remain untouched.

Application target commit: d956894fd3deb348ed1c432ae53079a4991a9a13. The CI input manifest pins its actual Source/Vendor/project trees without weakening drift checks. No workflow trigger or existing native test oracle was changed. The required phase-1 selection remains all 27 cases; older native passes are historical, not acceptance of this candidate.

Canonical phase reports and preservation evidence: C:/Users/DAVID/Code/Codex-Agent-HQ/docs/otzaria/single-agent-three-phases-20261116. Current invocation evidence is under CONTINUATION_20261117_EVIDENCE.


## Phase 2 candidate changes

Commit cf1c756c1b71681800095641f4798ae4a85df575 carries the three real Zayit metadata acceptance tests and canonical 349131-byte resource, SHA256 c6ca39044f6a62728f8f7e40e86d4080c89dc8927ced5ae6d724079efb5f896b. Pre-build and built-xctest verification fail closed on missing/corrupt resources. No native resource-consumption PASS is claimed before the test-process attachment exists.

Reader preprocessing review is in reader-offmain-20261117/REVIEW.json. The real Windows Swift corpus test passed; native and physical acceptance remain separate gates.

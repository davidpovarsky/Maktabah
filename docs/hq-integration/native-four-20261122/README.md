# Four focused Native cases — frozen source and real execution pending

Application source: 385ee84a8acb3fbc3c013c0977417b61fd3d8a17.
Canonical metadata parent: 46a185242b28b71d4b6d253747f2b8d46e4189a0.
True wrapper merge: 93fc2d54af882d323989f97b8ab5d5415103f2fd.
Immutable workflow checkout: c107c8ac600de6bbe6d92571fbbbdc6349cd143a.
Actual push-triggered run: https://github.com/davidpovarsky/Maktabah/actions/runs/44980625976.
Single observer: SentinelX job_d3c08232bc6c.

## Scope

The original run44969361774 completed with 3 PASS / 3 FAIL / 0 SKIP / 0 NOT_RUN. Its source and raw failure evidence remain in docs/hq-integration/native-followup-20261122. The three PASS cases are excluded from this execution.

Exactly four original XCTest methods are selected:
- HanlinReaderConsumerAcceptanceTests/testOriginalIPadCurrentWorkConsentToggleWithoutConnection
- FaithfulReaderUIAcceptanceTests/testCandidateGlobalSearchLandscapeMatchesOriginalNavigation
- FaithfulReaderUIAcceptanceTests/testCandidateGlobalSearchPortraitMatchesOriginalNavigation
- R27NativePadTests/testNormalBootstrapPaletteKeyboardDispatchCalibration

The two Global Search cases test the reviewed initial-navigation restoration repair. The calibration case tests exact original row identity after Down/Up, repairing the duplicate-label oracle without changing keyboard dispatch. The new consent diagnostic performs the actual OFF-to-ON-to-OFF switch interaction on the original iPad reader without provider credentials, connection, or send.

## Source and preflight evidence

The four Source, Vendor, Xcode project, and original UITest trees match application385ee exactly. Only the two reviewed focused-wrapper paths differ from canonical46a. The canonical ordinary-HQ pins remain unchanged and point to application385ee.

The original focused prepare/declaration validator, ordinary HQ source preflight, and Host48 reuse verifier all exited0 at checkoutc107. The complete execution closure includes275 files. Host48 verifies the real historical48/48 result and its original35 local plus29 SDK inputs; it executes zero new tests. The generated selection has four exact declarations and preserves the full Native116/Release114 contracts as unaccepted.

Windows checkout LF materialization preserved the exact Git blobs. The unchanged index tree and clean final worktree are documented in the Sentinel receipts. The first local prepare invocation failed while decoding the existing Hebrew catalog with Windows cp1252, before any native build/test; its raw failure is retained. The necessary invocation used process-only PYTHONUTF8=1, matching CI's UTF-8 environment, with no source or contract change.

## Acceptance boundary

This package proves source binding, declarations, original build-input closure, historical Host48 reuse, and one real workflow dispatch. It does not claim a successful native build, four executed UI passes, full Native116, full Release114, Live provider success, StageB original editor acceptance, TestFlight delivery, or upstream owner approval. Those require their actual independent receipts. A successful observer means only that terminal GitHub metadata was observed; the actual workflow conclusion must be read separately.

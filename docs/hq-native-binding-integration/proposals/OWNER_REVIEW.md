# Exact protected hooks — unapplied

These two proposals are separate from the committed downstream composition. Both pass exact applicability checks against the current protected source; neither file has been edited in this manager branch.

1. `NativeManager_UNAPPLIED.diff`, SHA256 `3ec16b615de1600c4870613ac3bc85b037809251f826711ad711bd21e4e900f2`, adds synchronous mapping notifications to `openTabs` and `activeTabId`, records completion of native owner initialization, and retires observation in isolated deinit. Existing navigation and observer cleanup remain. Its intentional zero-context format requires `git apply --check --unidiff-zero`.
2. `ReaderWitness_UNAPPLIED.diff`, SHA256 `8695e10c4cea62a391bc4f54412eea1d0988490dd95039a1cd9f3abe555860a8`, adds one passive `MaktabahNativeRoutingSurface(kind: .reader)` modifier after the existing reader-detail accessibility identifier. It does not replace the reader or toolbar.

The repository's existing upstream integrity gate requires explicit owner approval for the exact protected file/hunk, including a small hook. Portable verification exercised the producer and consumer through explicitly declared native boundary doubles. It does not prove installation of these hooks or a native UI pass. Missing installation remains unavailable; no hook is bypassed by the inactive factory.

Approval of these proposals would permit only their exact source application and ordinary focused validation. It would not approve public-v2 activation, release, TestFlight or live-user data changes. Current native run43752226209 and frozen checkout043 remain unrelated and unchanged. Further SDK/native acceptance and any necessary source fixes must retain truthful individual results.

`EXACT_PROTECTED_HOOKS.json` records the original blobs, source receipts and applicability checks, including the first non-zero-context invocation that was corrected without changing either proposal.

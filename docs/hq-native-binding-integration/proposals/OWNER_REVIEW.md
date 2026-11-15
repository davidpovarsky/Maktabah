# Exact protected hooks — approved and applied

The owner explicitly approved these two exact proposals in the primary chat on 15 November 2026. Both were applied without alteration in the separate manager integration branch. The original proposal filenames and hashes are preserved; `APPROVED_HOOK_APPLICATION.json` records the authorization and exact application. The frozen native043 branch remains unchanged.

1. `NativeManager_UNAPPLIED.diff`, SHA256 `3ec16b615de1600c4870613ac3bc85b037809251f826711ad711bd21e4e900f2`, adds synchronous mapping notifications to `openTabs` and `activeTabId`, records completion of native owner initialization, and retires observation in isolated deinit. Existing navigation and observer cleanup remain. Its intentional zero-context format requires `git apply --check --unidiff-zero`.
2. `ReaderWitness_UNAPPLIED.diff`, SHA256 `8695e10c4cea62a391bc4f54412eea1d0988490dd95039a1cd9f3abe555860a8`, adds one passive `MaktabahNativeRoutingSurface(kind: .reader)` modifier after the existing reader-detail accessibility identifier. It does not replace the reader or toolbar.

The repository's existing upstream integrity gate requires explicit owner approval for the exact protected file/hunk, including a small hook. Portable verification exercised the producer and consumer through explicitly declared native boundary doubles. It does not prove installation of these hooks or a native UI pass. Missing installation remains unavailable; no hook is bypassed by the inactive factory.

Approval permits only their exact source application and ordinary focused validation. Public-v2 activation, release, TestFlight and live-user data changes remain outside this approval. Native run43752226209 completed with an unrelated cancellation-closure compiler error and 18 UI cases NOT_RUN; its original evidence is unchanged. Further SDK/native acceptance and any necessary source fixes must retain truthful individual results.

`EXACT_PROTECTED_HOOKS.json` records the original blobs, source receipts and applicability checks, including the first non-zero-context invocation that was corrected without changing either proposal.

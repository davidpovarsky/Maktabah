# Integration status — work in progress

Worktree: integration/sefaria-otzaria-20261108. Base: 59b01fa2d604facbcc3b3b1075a6283e7f1115db.

The user explicitly authorized implementation, CI, synchronization and TestFlight in the current chat. The original execution-package release restrictions are superseded by that authorization. No other working tree is modified.

Implemented: embedded inspector identity and real related content, Hebrew navigation preserving canonical references, normalized search languages/book identities, edition-aware preview requests, pinned Rust 7.0.1/schema10 with real SQLite indexing through a thin C ABI, paired cumulative search records, canonical lineIndex resolution, optional schema-aware versions/topics/metadata/alternative navigation/reference/anchor/decoration repositories. App target membership is explicit and additive.

In progress: Apple SDK validation of the expanded implementation, native interactive tests, optional version selection presentation, schema7 rendering/protection integration, compatible production/mini artifacts and final combined-branch validation. No release readiness is claimed by this checkpoint.

## Synchronization

Merged committed UI work through 661d53e0541779ae6c9ed7526cae5b1f273c708d from experiment/ipad-ui-faithful-from-9401 into this isolated branch. The other checkout is unchanged. Its coherent reader host, source-port memberships and TorahInspectorKit 19d1b35397af4f10ae70cfb3f444c9de87383b53 presentation options replace the older parallel downstream host. Existing semantic navigation helpers and the stronger embedded-source tests are retained. Superseded downstream model/view source files are retired only in this branch.

The known baseline workspace schema is imported once without modifying the original bytes; unknown formats remain opaque and archived. Actual persistence/scene/migration/rollback contracts pass 66 checks. New source memberships and both framework resources pass the repository's project-membership verifier (107 Otzaria Swift sources).

The first schema10 CI built all three Apple Rust slices successfully. Its fixture harness lacked ZSTDContextWrapper.swift and stopped before app/UI validation; that harness input is corrected for the next run.

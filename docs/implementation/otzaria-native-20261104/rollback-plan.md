# Rollback

Changes are isolated on integration/sefaria-otzaria-20261108. Revert integration commits on that branch or choose the prior production build in TestFlight; never reset another agent's worktree. No annotation/history/bookmark migration or database writes are introduced by the new optional repositories.

Schema10 indices must retain their own engine/data identity. An older schema4 index is incompatible and must remain marked incompatible, never relabeled. Managed index promotion keeps existing atomic .building/.previous recovery. Restore a matching old app+index pair if rolling back the Rust engine. Reading must remain available when an index is unavailable.

CI deletes only the simulator whose UUID/name/run identity match its receipt. Credential cleanup remains in the established signing workflow. No unrelated simulator, process, user database or other worktree may be removed.

Workspace import is an explicit one-time conversion of the recognized legacy schema to the synchronized native UI model. Original bytes are archived and untouched; unknown schemas are not interpreted. Restore the original snapshot using its existing backup path when rolling back that UI integration. This is separate from the read-only content repositories and never migrates personal notes/CloudKit records.

MiniTest10 v7 retains its immutable v36-derived identity. Do not relabel a v6 miniature, engine 7.0.0 official index, or schema4 artifact as the new profile. Production rollback must choose matching application/database/index identities. A missing compatible index leaves reading available.

The cancellation registry has independent Arc ownership. Closing the engine waits for its serial operations, while a retained cancellation closure can finish safely against its own registry. Never free an opaque pointer manually from a UI cancellation path.

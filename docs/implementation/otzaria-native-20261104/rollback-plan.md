# Rollback

Changes are isolated on integration/sefaria-otzaria-20261108. Revert integration commits on that branch or choose the prior production build in TestFlight; never reset another agent's worktree. No annotation/history/bookmark migration or database writes are introduced by the new optional repositories.

Schema10 indices must retain their own engine/data identity. An older schema4 index is incompatible and must remain marked incompatible, never relabeled. Managed index promotion keeps existing atomic .building/.previous recovery. Restore a matching old app+index pair if rolling back the Rust engine. Reading must remain available when an index is unavailable.

CI deletes only the simulator whose UUID/name/run identity match its receipt. Credential cleanup remains in the established signing workflow. No unrelated simulator, process, user database or other worktree may be removed.

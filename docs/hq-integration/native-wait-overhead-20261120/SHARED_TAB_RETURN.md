# Reuse the original iPad tab return in System Book Intent acceptance

The existing new-tab acceptance path already reveals an offscreen original tab through the real native scroll view. This change extracts that exact bounded gesture body into one helper and calls it from the System Book Intent same-book new-tab return. Both callers retain their original pre-navigation UUID.

The helper performs at most eight real scroll gestures, uses the same viewport geometry and nonmaterialized-cell two-direction search, and still requires the original tab to exist and be hittable. Visible-but-occluded controls still fail. No model selection, debug navigation or replacement receipt was added. Phone overview navigation is unchanged. All source text, locator, ownership, preserved tab and receipt assertions remain unchanged.

Actual verification: Windows Swift 6.3.3 parse exited 0. This is syntax parsing, not Apple type checking or Native execution. SHARED_TAB_RETURN.json records the exact inverse proof; removing the helper and restoring the two original call sites reconstructs the whole prior source. An independent read-only review reproduced that inverse and found no blocker.

This source needs a new exact Native freeze. The historical Native78 failures and active older-source CI results are not changed by this code review. Native executed for this change: 0.

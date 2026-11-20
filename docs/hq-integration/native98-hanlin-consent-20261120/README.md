# Native98 Hanlin consent child accessibility identity

## Actual failure and scope

Native run 44723902453, attempt 1, immutable F 60a57972acb28739ec738565083bf17fb7503028 / M 87b783ac3f0257e8461762e0ea9dfa5248dd06e8 completed cancelled after partial real UI execution. The original iPad current-work consent case actually failed waiting for `otzaria-hanlin-allow-current-book`. This document does not reinterpret the workflow cancellation or credit its other selected cases.

The selected original final AX proves the real consent Switch is visible with value 0 and the original title is present. Both have the Section identifier `otzaria-hanlin-current-book-consent`, as do its other rows. The explicit original child identifiers are absent. Source at the current 0f25 base is byte-identical to failed F60: a Section-level accessibilityIdentifier follows the title and Toggle identifiers. The original screenshot confirms that the actual permission control is displayed, without a grant being enabled.

## Narrow correction

Keep the same Section, localized Book access heading, all body words, title, Toggle, binding, disabled condition and privacy text. Attach the existing Section identifier to its explicit original header Text, so it identifies that header rather than overriding the children. No permission, provider, connection, source, persistence or SDK code changes. No Native test, timeout or expected identifier changes. Exact two-replacement inverse reconstructs the entire original file; both canonical Git hashes are in SOURCE_PROOF.json.

## Executed validation and limits

Windows Swift 6.3.3 frontend syntax parse completed 14:05:52 UTC, exit 0, zero stdout/stderr, unchanged source hash. This is syntax only: Apple SDK typecheck and corrected Native execution are NOT_RUN. The real consent flow still must pass all original child identity, default-off, draft, reopen, source and revocation assertions in a future immutable Apple run.

## Evidence

ARTIFACTS.json authenticates all gzip payloads and their uncompressed bytes. The original small runtime evidence archive was fully SHA-verified. The capture artifact 14632274701 was read only through exact HTTP 206 ranges; selected PNG/AX ZIP CRCs passed. Its advertised full-archive SHA is recorded, but the complete 775 MB archive was not downloaded and its full hash is not claimed. The source-derived explanation is limited to observed AX identifier propagation; it is not proof of corrected runtime behavior.

Independent source-only review by the Hanlin integration owner found no blocker in the exact Section-to-header delta. It confirms unchanged localized header, content, child IDs, default-off scope, grants and callbacks; it does not add an Apple execution claim.

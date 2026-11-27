# Original Annotation caller: exact escaping validation signature

This one-file correction follows source `56a6ff0c4d9437924479444660b51ce62e59db7e` and evidence `2914be3e5ad4c2d857a962d526b5e2c6ec8dde32`. Those commits, their original callback failures, and their helper-only controls remain unchanged. The correction adds only `@escaping` to the existing `nativeRoutingReveal` validation parameter.

## Actual failure and correction

The original caller declares `validate` as nonescaping. Its local `requireCurrent` function captures that parameter, and the optional expansion helper validator retains a closure calling `requireCurrent`. Compiling this complete original caller and helper produces the actual Swift diagnostic `escaping closure captures non-escaping parameter 'validate'`. The earlier helper-only compilation and whole-file frontend syntax check did not compile this complete capture chain.

The corrected signature accurately declares the existing retained validation callback. No validator body, controller effect, caller order, request, deadline, or source lifetime changes. In particular, the actual selection binding's weak-self/weak-Pending callback remains byte-identical. A held animation callback rechecks the same pending phase/source and cannot continue after apply, completion/release, or unmount. No replacement source, new request, new effect grant, or `withoutActuallyEscaping` is introduced.

Removing the one exact signature edit reconstructs all 32,313 bytes of the prior file (SHA `e38eafa86b8aebdf34166da0d9fe3b182ac44fdcdf5c2549fea8f0d9026a14cd`). The corrected file is 32,323 bytes, SHA `a6577cf5d2060b3849ab06634c9e52915e9048260feda7814c02cf926965bd1c`. The original source header and provenance remain intact.

## Preserved attempts and verification boundary

The first full-chain attempt used `-typecheck`. Swift returned exit 0 at that stage; the harness expected the escaping diagnostic and stopped with a genuine harness-stage failure. Its result `fe6561af4aa6b00f6070bbb1f279253fbd79e1e646607aacce40cc0ccf661e22`, inputs and output remain preserved. This attempt is not represented as a successful diagnostic reproduction.

The second attempt performed a complete compilation, including SIL capture checking. Oracle job `job_a98ea4fd42c2` ran on 2026-11-27 from 19:06:16 to 19:06:50 UTC. It compiled the actual complete binding, `nativeRoutingReveal` and expansion helper against the explicitly declared UIKit/Combine/Store/backend/workspace fixtures and the retained original Core/UI/Host value contracts.

| Evidence | Actual result |
|---|---|
| Sealed original caller, full compile | Exit 1; actual escaping-capture diagnostic |
| Corrected caller and unchanged actual binding, full compile | Exit 0 |
| Current full-call-chain ownership controls | 6 passed, 0 failed |
| Eight complete candidate Swift files, iOS frontend syntax | Exit 0 |
| Exact one-edit whole-file inverse | Passed |
| Apple SDK typecheck, application build, UIKit/native execution | Not run |

The six controls cover a valid original binding/caller selection, retirement from diffable publication, source release inside application, and retained animation callbacks after the applied phase, finish/release, and unmount. UIKit behavior and actual geometry are explicit test boundaries; these are source controls, not an application acceptance receipt. The controls do not execute Core navigation authority.

Final result SHA: `63415a94517b961fea07adc7688dc68a21a1d29b548feaf3f8b9e4c893b9c1fe`. The complete two-attempt raw archive has 122,373 bytes, SHA `481e1c7926199616845d2379f7258ad039b2a73c595fc6261bb6dd8d438dd432`, with 18 raw files plus its separately verified manifest. Actual compiler argv, PID, start/end times, capacity checks, source joins, failed output, candidate output and original product reuse hashes are retained.

## Integration and outstanding acceptance

Apply the source commit after the two retained expansion commits; the documentation commit is separate. Only the original controller signature changes. There are no new product files, project memberships, localization keys, shortcut entries, shared integration hunks, dependency updates, owner signatures or gate changes.

The original warm-list system-Intent/selected-cell native selectors remain separate and unrun until the qualified application is available. Editing, filters, body, tags, style, per-book Annotation behavior, production corpus and physical-device acceptance are not closed by this correction.

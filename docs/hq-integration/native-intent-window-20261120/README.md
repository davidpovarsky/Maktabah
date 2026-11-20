# Reader-window identity before foreground activation

This file preserves the baseline RED investigation. The implemented candidate
39ba and actual **15/15 fixture +135/135 Host** results are recorded in
[GREEN_EVIDENCE.md](GREEN_EVIDENCE.md), with Apple/Native gates still pending.

## Source and observed baseline

The application baseline is `d0c649794e4262ffdea0e13635d5c8237668bd6e`.
The Native78 run used application source
`5d8ef991554b01ba6bf3d39222c5ef6cc00a264b` (checkout
`7d05dd0bb25a7df307b35174e49e18d0f22eecee`). The four relevant complete
Composition methods are byte-identical between those sources; the accompanying
`source-comparison.json` records their hashes.

The original `NativeReaderWindowEntityQuery` and `openReaderIntent` use
`intentEntities()`. That method first builds mounted root identities, then awaits
`destinations()` for optional live Search controls and the Inspector. Live
discovery issues a scene context and revalidates the live scene, even when the
caller only needs the identity of an existing Library window. An unrelated
current UI reservation can therefore prevent resolution of that window.

Native78's iPad background-book test failed after Home, before any logged
`await-mount`, with a bridged `UIRouteError Code=1`. The phone's same
`runSystemBookIntent(namedChapter: false)` helper passed in 59.825 seconds and
recorded an actual original Reader receipt. **The internal code of the iPad
failure was not logged. It is not attributed to either reproduced condition.**
The original test oracles remain unchanged.

## Executed discrimination

| Attempt | Exact source | Executed | Observed result |
|---|---|---:|---|
| baseline-attempt01, `job_b56d810f1781` | d0c64979 | 0 of 12 | Fixture setup failed: immutable AppIntents DTO boundary lacked `Sendable`. Original package compilation completed; no production test result. |
| baseline-attempt02, `job_3f4d8ed958e3` | d0c64979 | 15 of 15 | **9 PASS / 6 FAIL**, no compiler warnings; complete package inputs unchanged. |

The second attempt includes three additional current-context cases and fixes
only the DTO boundary. For each original backend (Otzaria, Sefaria, Embedded):

- Running the original `setForeground(false, session:)` at the explicit async
  backend-port boundary produces `stale_state / scene_changed_during_observation`.
  The window remains mounted, and neither foreground preparation nor navigation
  is called.
- Holding an unrelated context through the original `issue` method produces
  `unavailable / native_scene_busy` during metadata resolution. The existing
  context is preserved. This case requires no scheduler assumption.
- Stable foreground and background identities still resolve.

The other controls pass: backend generation change is refused, pre-cancellation
is refused, and two background windows retain distinct exact selected identities.
These are desired behavior assertions; the six failures are retained as RED,
not counted as successful tests.

## Reproduction and boundary

```powershell
python tools/hq-native-intent-metadata.py `
  --artifacts-dir build/intent-background-20261120/new-baseline-attempt `
  --source-ref d0c649794e4262ffdea0e13635d5c8237668bd6e `
  --timeout 600
```

The driver compiles whole unchanged Core, UIRouting and Host packages with
Swift 6.3.3, one compiler job and complete strict concurrency checking. It inserts
the complete original Composition discovery, identity, foreground, authority,
registry initialization, mount validator and dependency installation code, plus
the three complete Reader-window query method bodies. The actual
`NativeIntentService`, `NativeSceneDirectory`, `NativeNavigationAuthority`,
Registry and Core execute. The per-attempt report records every source/package,
fixture and generated Swift input hash and checks exact case identities.

Explicit boundaries replace UIKit scene observations, localization, AppIntents
DTO/dependency storage and backend timing. Native execution methods trap if used.
The actual production Facade can return synchronously from `snapshot()` when
`currentEpoch` is present; the controlled async-boundary transition is therefore
an interface lifetime test, not proof of Apple's scheduling or the exact Native78
failure. The busy-context result does not depend on that timing assumption.

No native window is rendered, no system intent executes, no content is read,
and no native navigation receipt is fabricated. Apple compilation and the
original iPad/phone Native cases remain **NOT_RUN for the forthcoming change**.

## Narrow intended correction

Keep mounted Reader-window metadata independent of optional live control
discovery. Preserve general Search/Inspector discovery, cancellation, source
generation checks, exact window selection, the original foreground wait, fresh
post-wait discovery and the original Core/scene/receipt path. Add bounded
DEBUG-only error-code diagnostics at the existing dependency closure boundaries;
never log content, query text, identifiers, tokens or raw NSError descriptions.

This initial commit preserves the source-bound RED and contains no production
change. Subsequent GREEN evidence must identify its exact candidate source.

Raw attempt reports, invocations and logs are retained losslessly as gzip files.
`RAW_SHA256SUMS.json` records the original bytes and the compressed digests.

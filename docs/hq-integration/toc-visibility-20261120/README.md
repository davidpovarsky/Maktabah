# TOC / Library request-scoped visibility observation

## Outcome

The production change adds only `native.library` and `native.reader.toc` to
the existing request-scoped observer in
`MaktabahNativeSceneSession.waitUntilVisible`. It preserves the original
33-ms interval, same-submission and mounted guards, exact UIKit witness,
original `observe` method, `NativePresentationObserver`, deadline, cancellation,
route comparison and final receipt path. No UI, Composite, XCTest, Core,
routing package, manifest or occurrence-count source is changed.

**Actual Windows portable evidence:** 28 executed: 26 PASS / 2 FAIL → 28 executed: 28 PASS / 0 FAIL.
The exact case inventory and all source hashes are recorded in
`VERIFICATION.json` and the retained raw execution archive.

**Native outcome of this candidate: NOT_RUN.** The historical Native78 TOC case
remains FAIL. This component regression is not an Apple SDK, rendered UIKit,
real app receipt, accessibility, physical iPad or performance PASS.

## What the actual Native78 evidence establishes

The original run is
[44633736259](https://github.com/davidpovarsky/Maktabah/actions/runs/44633736259),
checkout `7d05dd0bb25a7df307b35174e49e18d0f22eecee`, application source
`5d8ef991554b01ba6bf3d39222c5ef6cc00a264b`.

For
`NativeRoutingAcceptanceTests/testPublicV2TOCPreservesPrivateFilterAndOriginalReader`:

| UTC event | Observed result |
|---|---|
| 00:56:38.786 | The original TOC navigation produced its canonical receipt. |
| 00:57:10.227 | The original pager changed from contents to Library. |
| 00:57:10.615 | Library marker: appeared=true, contained=false, visible=false. |
| 00:57:15.252 | Original deadline expired; no intervening Library witness sample appears in the retained log. |
| 00:57:15.467 | Library was contained=true under modal=true, after the deadline and failure alert. |

The retained screenshot shows the Library behind the failure alert. Neither it
nor the later contained=true sample proves that the marker met the 98% condition
before the deadline. The evidence supports a missing-observation interval; it
does not by itself establish that this change fixes the historical Native case.

At Native78 the existing periodic observation was reader-only. At this task's
base `d0c649794e4262ffdea0e13635d5c8237668bd6e`, it also covers note drafts,
but not Library/TOC. The complete original `currentEvidence()` geometry
predicate is identical between Native78 and the new base (LF SHA256
`3f26498646f9b5bb02739fa7c43e1841d87db819d03dc590197d70e0642f49ae`).

`NATIVE78_PROVENANCE.json` and `native78-log-excerpt.txt` retain the exact raw
log hash, excerpt hash and line bounds. Selected capture provenance is also
retained: authenticated HTTP206 ranges, selected ZIP CRC validation and entry
hashes. The full 1.9 GB captures archive was **not** hashed in that range retrieval;
its advertised full digest is not relabeled as a verified full archive.

## Why this is a narrow correction

`NativeSurfaceWitness.updateUIViewController` already registers a closure that
reads the actual marker's `currentEvidence()`. A layout callback can occur while
the marker is still outside the required window geometry. If geometry later
settles without another callback, the presentation observer has no new evidence
to consume.

The existing reader/note mechanism periodically invokes that same live closure
only while the exact request remains pending. Extending its explicit destination
list lets Library and TOC obtain a new observation. The timer cannot manufacture
success: the original witness must still report actual visibility, and the
original observer must match scene, request and full observed route.

The production diff consists of one destination-list change and a three-line
comment update. The 98% intersection threshold, 95% effective alpha, actual
appearance, scene activation, modal blocking and native source ownership remain
unchanged. Polling stops on completion, deadline, cancellation, unmount or request
replacement. Other destinations keep their callback-only behavior.

## Discriminating regression

The fixture compiles the complete original Core/UIRouting/Host packages. It
extracts and compiles these complete production declarations/methods, using the
existing Inspector driver's exact extraction utility:

- Scene `waitUntilVisible`, `observe`, `observeVisibility`, `endObservation`.
- Witness `Evidence`, `currentEvidence`, `diagnostic`.
- The actual package `NativePresentationObserver`,
  `NativeObservationDeadline`, `NativeSurfaceState`, registry validation and DTOs.

The UIKit view/window/controller geometry and lifecycle objects are explicit
doubles. Reader rendered-state and note-owner projections are also boundary
doubles. They do not replace the visibility predicate, observer loop, deadline
or route/request comparisons. This fixture does not claim Core permission
admission or the full Directory/orchestrator final receipt gate.

The two discriminating cases deliver one early appeared-but-clipped callback,
change only the boundary's window geometry, and deliver **no later callback**.
The original method reaches its original deadline; the repaired method observes
the unchanged live predicate and returns the independently projected surface.

The other 26 cases retain successful actual callbacks, existing Reader/note
observation, exact 98% acceptance and below 98% refusal; reject missing appearance,
inactive scene, hidden ancestors, low alpha, foreign modal, detached window,
empty bounds, wrong scene, old request and wrong surface state; preserve
deadline/cancellation/replacement/unmount cleanup; and ensure Search,
Search-results, Inspector and Settings are not newly polled. Reader and note
owner refusal gates remain active.

The first attempt is retained separately as a fixture setup failure:
`FixtureMarker` lacked the original enclosing `Evidence` name.
**0 cases executed.** A boundary-only typealias restored the original namespace;
no production method was edited for that repair. The real RED and GREEN use
the same repaired fixture, exact ordered inventory of 28 cases and one reused build
cache.

Run the candidate fixture in a new owned output directory:

```text
python tools/hq-native-surface-polling.py --artifacts-dir build/toc-visibility-20261120/new-attempt
```

Use `--source-ref d0c649794e4262ffdea0e13635d5c8237668bd6e` for the immutable
baseline. The driver retains failed attempts, complete generated inputs, source
snapshots, original package fingerprints, commands, compiler output, executable
hash and actual per-case results. It reuses the existing local path dependencies
and one local scratch cache, runs one compiler job, and does not access a DB,
engine or user index.

## Ownership and remaining gate

The sole production file is downstream-owned integration code, introduced in
`d337c60896c6ef24af277697e6012ae1595c0335`. The original UIKit witness source,
upstream views, search, data files, existing Native methods/oracles and package
sources are untouched. The standing owner authorization and root's explicit
SceneSession assignment cover this narrow integration change.

A focused original Native rerun must still prove the actual TOC → Library
transition, private-filter preservation, original reader state and canonical
receipt on the new immutable source. Root owns integration and dispatch.
Reverting this commit's destination-list change restores the prior observation
scope; there is no persistence or data migration.

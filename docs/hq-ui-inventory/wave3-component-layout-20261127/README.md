# Bounded original-component layout continuation

This packet extends the existing retained component reveal owner so an original view can expand or change its original navigation page, wait for a later real layout, and reveal the exact control under the same command. It does not create a second admission or treat a scroll request as visible evidence.

## Source contract

The public portable phase is `NativeComponentRenderPhase.initial` or `.afterOriginalLayout`; the result is `NativeComponentRenderResult.awaitingOriginalLayout` or `.rendered`. Every continuation requires a strictly newer original layout revision, the same original view ID, request, retained source and admission validator. A continuation can wait again for another actual layout. A repeated body evaluation, old view callback, elapsed timer or reentrant callback cannot advance the request. The source and admission are revalidated after the synchronous original UI callback.

The app container accepts `(owner:blocked:viewID:layoutRevision:componentAvailable:revealPhase:)`. `componentAvailable` is optional and defaults to true; the existing one-stage `reveal:` initializer remains source-compatible. The caller owns the stable view ID and the real passive layout publisher, including invalidation of detached publisher tokens. The generic owner does not manufacture a layout revision.

Mounted per-anchor availability complements the feature factory's source availability. It lets an actual filtered TOC hide only its current-selection anchor while retaining access to other original controls. A mounted closure must read the live original Binding/Observable owner. Original local state mutations must synchronously retire a pending presentation where Observation cannot cover that state.

The native component test helper accepts an optional `originalTarget:` closure for a typed lookup of an existing dynamic original element. Its default identifier lookup is unchanged. This permits a selected TOC row to retain its original accessibility identifier rather than adding a fake interactive marker.

## Actual verification

The final immutable file snapshot passed **27 portable tests, 0 failures, 0 skips**: 18 reveal-owner controls and 9 true Observation invalidation controls. The final log records 0.017 seconds of test execution and 16.36 seconds of build work; total command time was 23.464 seconds. All recorded source hashes remained unchanged throughout the run and were rechecked before this packet was committed.

Seven added reveal-owner controls cover deferred layout, original deadlines/source, replaced mounts, strictly newer revisions and repeated continuation, mutation during the original callback, reentrancy, and per-anchor mounted availability. Existing exact visible-target checks remain mandatory after the render phase reports completion.

An earlier 26-test iteration is preserved separately with its exact source snapshot. It predates the mounted-availability control and is not summed into the final result. Both raw logs are stored as lossless gzip with the original raw-log hashes. The original raw diagnostics remain at the paths recorded in VALIDATION.json.

Two changed Apple-only files pass Swift frontend syntax parsing for arm64-apple-ios27.0. This is not an Apple SDK typecheck. The first 170,801 bytes of the original native test file are byte-identical to source 64c1e74a; only its later downstream helper changes. Original Native116 and Release114 selectors, counts and timeouts remain intact.

## Pending native evidence

Actual UIKit mount/layout, offscreen original List scrolling, cold and warm system delivery, iPad/iPhone behavior, VoiceOver and production-v40 acceptance require the source-bound Apple build and native runs. This packet does not report those unexecuted checks as passing. Peer TOC and Workspace adapters must provide their real original layout publishers; the generic portable controls prove only the bounded ownership protocol.

The integration branch already contains the separate two-line Observation test fixture visibility correction (809e35f); this branch's equivalent parent is 8466190c. Intake only this packet's narrow commit after that correction. No project membership, original feature view, catalog, signing material, dependency pin or owner signature changes are included.

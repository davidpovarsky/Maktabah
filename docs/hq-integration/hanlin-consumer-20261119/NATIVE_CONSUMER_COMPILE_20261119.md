# Native consumer compilation and journeys — 2026-11-19

## Actual compiler result

Original application run [44468055042](https://github.com/davidpovarsky/Maktabah/actions/runs/44468055042)
at source 963842a7396a98e3614efe65fd6f24f357232db5 failed during the actual Maktabah-iOS Swift compilation,
after the exact dependency, macro authorization and host SDK selection gates passed.
Xcode 27.1 (27A9275), Swift 6.4 and the iOS 27.1 Simulator SDK reported one compiler diagnostic:
OtzariaHanlinChatSession's computed id witness was main actor isolated, while Identifiable requires
a nonisolated witness. No runtime or UI test ran in this application-only route.

Artifact 14504632923 contains the authenticated raw log (18,823,304 bytes,
SHA256 ed7b05749025e1320dbdb863e2cce4cb20a22c29da46027dad9de09293d7fe64).
Official archive: 39,303,759 bytes, SHA256
a6359edde054646ef158b296cd4e9a67555e7996ba9fdd223528b8b4d80b2cc5.
Ranged members have verified CRCs and exact raw hashes.
The full archive digest and all ZIP member CRCs have also been verified.

## Focused source correction

Only the computed identity witness is marked nonisolated. It reads the immutable original
HanlinHostSession value, whose original SDK declaration is Sendable and has a let UUID id.
All mutable presentation, history, credential, engine and navigation state remains on MainActor.
No preconcurrency annotation, unchecked conformance, duplicated identifier or changed owner is added.

A limited source-extracted identity-conformance probe typechecked with Swift 6.3.3 against the
actual unchanged compiled SDK contract module. This checks only the identity declaration and its
nonisolated generic Identifiable use. It is not a full app, Apple SDK or native runtime test.
The initial direct frontend invocation could not load the installed Windows standard library;
the normal Swift compiler driver then completed the bounded check with exit 0.

## Required actual native journeys

The existing global draft/history/process-restart test is preserved byte for byte.
An additional reader-context case uses the existing R27 real bootstrap and independently chosen
Otzaria fixture. It opens the actual reader toolbar chat, observes one scene-owned presentation
and its explicit model/content boundary, closes through the native button, then requires the exact
original source text bytes, title, locator, scene, profile, group, selected tab and all document identities.

The next source-frozen runtime27 scope selects these two complete journeys. All 77 original catalog
rows and the previous full-phase requirements remain preserved; selected success cannot close that
full phase. The original build-for-testing gate must compile the complete app and UI runner before
either test starts. No test-side modal dismissal, timeout increase, provider request or synthetic
navigation acknowledgement is used. Source/model opening, physical protection and distribution
acceptance remain separate.

Hanlin SDK pin remains 873607e45e021b40fe5b940c836d398c329f95c8.
Dependency locks, upstream components, native routing, real bootstrap and release/signing gates are unchanged.

## Native full-build result at 373c9dbf

The original runtime27 UI route 44474935357 executed at checkout
373c9dbf68e3e06a667fee902c52540e71596ed8, application source
3609903e1b56ae877bf39049f2f9178f23a3b8eb, and original SDK gitlink
873607e45e021b40fe5b940c836d398c329f95c8. Xcode 27.2 (27B52), Apple Swift
6.4.2 and iOS Simulator SDK 27.2 reached the complete app/test build-for-testing
gate, which failed. Both selected UI journeys are NOT_RUN (zero executed pass
and zero executed fail); the earlier immutable identity diagnostic is absent
from this log, but that is not a complete build pass.

The exact errors at OtzariaHanlinChatView.swift:315 report an immutable caught
Error and assigning String to Error. Swift's implicit catch variable shadows
the existing presentation error property. The downstream-only correction
qualifies self.error; it does not change persistence, the message, the error
policy, the test selection, or the native assertions. The same file's open
and delete error handlers already use this qualification.

Original failure: https://github.com/davidpovarsky/Maktabah/actions/runs/44474935357

Artifact 14506784693 is 39,609,786 bytes, authenticated against GitHub's full
SHA-256 ef8fd6b6b2e32c26c301d0cff9d15e92d4bcee7b6b85283fb450876900ac0a81.
Every ZIP member CRC passed. The complete compiler log and both original
runtime27 and focused-build result documents are retained. The external
VERIFIED_NATIVE_BUILD_FAILURE.json records their exact source and hashes.
A subsequent complete Apple build and both original consumer UI journeys
remain required; local Swift parsing is not product acceptance.

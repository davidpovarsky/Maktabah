# Explicit original Anytype receive — 2026-11-25

This checkpoint implements an explicit Receive path for a saved original rich note in the ordinary Maktabah annotation sheet. It uses the actual selected original Anytype account/Space and the SDK’s nonconstructible original read receipt. It stages the full received native body together with the full prior local payload, requires explicit user choice, and saves through the existing atomic local editor transaction. The existing note UUID, source anchor, tags and local permissions remain owned by that transaction. Native formatting and complete object/file data are never flattened into the preview.

Historical import mappings are data, not account authority or write permits. The reader checks their receipt status, response checksum, exact note identity and actual native root assignment, supports the previous flat layout, and writes new histories under per-note directories. Every selected mapping is independently read using the live original account and selected Space; no decoded file can construct an SDK receipt. Missing history offers no guessed destination. Both prior and received complete versions remain recoverable before a conflict can be presented. A failed/retired local source never triggers an automatic overwrite.

## Verification actually performed

* Four changed Swift source/test files passed the real Apple iOS parser, including the new Receive model and production view (`SWIFT_PARSE.json`).
* Exact extracted production historical mapping decoder/file checks compiled and executed with Apple Swift on the real Mac. `job_8496483b7a9f` passed 19/19 controls, including source/namespace/receipt checksum validation, refusal of a claimed remote acknowledgement, symlink refusal, legacy layout retention and missing-history read-only behavior.
* A single-note lookup with 5,000 unrelated note directories took 0.015887708 seconds and did not decode those unrelated note archives. This is a focused history-index check using synthetic historical records, not the project’s 5,000-real-note native performance gate.
* All touched ordinary UI strings have Hebrew and English translations. `SOURCE_MANIFEST.json` binds the source files and test result.

The prepared real UI acceptance case exercises the ordinary Receive button without an existing native mapping and checks that the canonical saved body/UUID/revision remain unchanged. That UI test has **not** been run at this checkpoint. No integrated-app build, positive UI receive journey, physical-device or native atomic-update acceptance is claimed here.

## Integration

The base is `1295fb8996aa7686a837728ca6a44ee6a38fdaf7` with the explicit legacy exchange-identity dependency `d0bc03f9a3767e4c14e50324a29ceb3cff38a874`. Root owns registration of `Source/ChavrusaText/Annotations/LocalEditor/AnnotationOriginalEditorReceive.swift` in the iOS target and the integrated build. The current SDK dependency for this checkpoint is `c50838b26f52bb2c6c464db9ed09526352300053` or its descendants. Existing local transaction/identity controls are owned by the library lane; they are not duplicated here.

Safe updates of an existing remote native object require the separately implemented original locked revision protocol. Ordinary ObjectListExport heads are not treated as an atomic token. Receive itself makes no remote write and grants no remote-device acknowledgement.

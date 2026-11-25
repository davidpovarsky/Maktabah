# Production annotation host — working source

Status: **DRAFT; no Apple compilation or native acceptance yet.**

Base: 443b7b6945fba5f49a42d223fdda6dc0db622c4f.
This branch adds the ordinary annotation UI composition required beyond the
existing dedicated Debug/simulator qualification. It does not enable cross-app
exchange or change the original Native66/ABI proof.

## Product boundary

The original Anytype editor is hosted in-process. A new public SDK lifecycle,
being implemented separately, supplies an owned local-only draft runtime.
Canonical rich bytes are read from the original saved Otzaria annotation row.
The native editor capture and original write barrier precede the existing
SQLite revision/source CAS. The same saved UUID is preserved. A native draft
or an RPC return never grants a cross-app destination mapping or acknowledgement.

The ordinary sheet inspects a saved row before permitting plain editing. An
opaque rich body cannot be overwritten by its text preview. Expansion requires
unchanged live text/style/tags and a current reader workspace. It uses the
original view controller, source context and native sheet/navigation controls.
Closing the expanded editor also closes the stale quick-note sheet.

The native lifetime is synchronously linked to the original local editor owner,
captured database lifetime, source/scene observation and presentation lifetime.
Retirement must perform no I/O or synchronous callbacks while a Host mutex is
held. The production capture returns original opaque bytes plus a preview
derived from the same flushed original primary-object snapshot, bounded by the
existing preview limit. The Host does not parse native block payloads.

## Ownership and source changes

| Surface | Ownership and change |
|---|---|
| Source/ChavrusaText/Annotations/LocalEditor/ | Downstream; public iOS lifetime guards, source retirement binding, shared native Mount/CAS, new ordinary UI and isolated EN/HE catalog |
| Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift | Existing shared upstream seam; narrow entry composition and plain-edit/Save protection only |
| Maktabah.xcodeproj/project.pbxproj | Shared integration seam; one iOS source and one isolated string catalog membership only |
| Existing qualification implementation and XCTest | Unchanged; explicit Debug/simulator scope retained |
| Heart, protobuf, original editor services and Vendor | Not changed by this Host branch |

The current owner request and standing project authorization cover implementation.
This document is not an owner cryptographic approval and grants no distribution
exception. The final protected-source review packet and authentic release gate
remain mandatory.

## Pending acceptance

- Genuine public SDK local-only lifecycle and complete declared API inventory.
- Exact-source Apple compilation, native owner/DB/profile retirement review.
- Normal-entry real UI: save a plain note, expand, edit mixed original blocks,
  save, inspect original-derived preview, reopen, force quit/relaunch, reopen.
- Original qualification test retained separately without weakened assertions.
- Cancellation/uncertain commit and canonical recovery; no remote unsaved writes.
- Release variants, final source-bound Native116/Release114+2, signing gate,
  physical iPad and TestFlight.

The broader AnyTapy classification/promotion/backfill, real transport/ACK and
bidirectional two-device requirements remain separate. A private local draft
is not a remotely synchronized AnyTapy document.

# Native action and link-error localization

The original native destination titles omitted Hebrew entries for Study Tools, Search results and Note Draft. Library, Book Information and Inspector proposals also carried original translations that had not reached the current app catalog. Public navigation failure alerts used hard-coded English for their title and final fallback.

This intake adds exactly15 entries to the existing779-entry catalog and localizes those two alert strings through Foundation. The10 Library/Book/Inspector entries reuse their original proposal values. The3 short destination titles use terminology already present in existing Hebrew action descriptions. Every existing catalog entry and original byte remains intact. The error-handler change reverses exactly to its original2150-byte source after removal of only the twoNSLocalizedString wrappers.

## Actual validation

The complete794-entry candidate was compiled on the existing Scaleway Mac with Apple's xcstringstool. Job7073fc2cc135 completed successfully on2026-11-28 at09:47:49UTC. All15new keys were read from the actual English and Hebrew compiled output and matched their expected values. All previous compiled EN/HE values were unchanged. Arabic and Indonesian output remained byte-identical.

APPLE_CATALOG_RAW.zip contains the exact input catalog, expected values, compiler stdout/stderr, all4actual compiled language files and the actual result. ROOT_APPLE_READBACK.json records the complete archive/member readback performed from Oracle. COMPOSITION_PROOF.json and CATALOG_PROVENANCE.json preserve the source chain; PRODUCT.patch records the complete two-file change.

This validation qualifies catalog compilation and source-preserving localization only. It does not claim application integration compilation, system Intent delivery, Native116, Release114+2, production runtime, signing or physical-device acceptance. Adding labels does not expose unintegrated routes. The authentic owner-signature registry and final acceptance gates remain unchanged.

## Product boundaries

- Source/Localizable.xcstrings: exactly15new keys, existing779unchanged.
- Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeURLHandler.swift: localized existing alert title/fallback; original scheme checks, public-v2 conversion, navigation calls, visible-ack requirement and fixed-category-only logging retained.

# Exact selected Sefaria edition and full search context

## Product finding and repair

The original expanded search preview passed only the canonical locator to the backend. A row's selected version title/language was therefore lost, and the default source/translation response could be displayed beneath a different selected edition title. The original presentation also forced every non-Hebrew search result to translation even when the user chose Source or Both.

This change adds an optional LibraryVersionedTextProviding request to the existing text provider. BackendCoordinator preserves its existing backend/generation fences. Only the legacy Sefaria preview asks for a version tuple; ordinary default sections and all other backends keep their existing calls. SefariaRemoteStore resolves the exact title plus legacy language against actual /api/texts/versions/{work} metadata, uses the returned languageFamilyName in v3 (French is in the legacy en bucket), and requests the selected edition with its actual source/translation counterpart. Missing segments are not filled from another edition. The returned source and exact edition tuple are verified before display/cache. Edition caches use a SHA-256 of reference/title/language, separate from default-section caches. Hybrid reads never put a selected edition in the default locator-only memory cache.

The preview honors the original explicit Source/Translation/Both preference with the existing missing-language fallback. Its original Otzaria unit preference now invalidates the full-context request when changed through Reader controls; starting that request clears obsolete segments. Canonical TextLocator identity is unchanged. Nonbehavioral IDs identify the original edition picker, each complete text segment, original book selector/sort controls, Reader unit menu and Reader language picker.

## Actual Apple source controls

Baseline product: 4449813af3db0cc43d2802c30b9d73ce0459d26d.

- Same controls: baseline **12 passed / 12 failed**, candidate **24 passed / 0 failed**.
- Both Swift6 Apple compilations exited0. Candidate has one harness-only unused-local warning.
- Full original LibraryBackendModels, Sefaria domain mapper, disk cache and URL configuration compile with verbatim extracted original section methods and the actual changed visibility expressions.
- The test transport decodes captured real Sefaria responses. It is deliberately a component control; it does not claim live network, full app compilation, native UI, physical offline, or UI acceptance.
- Real same-reference bodies cover Hebrew plain text versus Nikkud, English JPS1917 and French. All retain genuine Hebrew/source and translation slots, while source identity remains unchanged.
- Controls also cover default-request preservation, edition switching, exact cold cache, unknown/ambiguous edition, successful HTTP payload without requested edition, absent language family, and Source/Translation/Both on an English result.
- Existing work-root navigation, Coordinator stale cancellation and Hybrid integration await the original app build/native run; the harness does not exercise those routes.

Apple evidence directory:
/Users/m1/builds/otzaria-wave2-search-20261127/selected-version-controls-20261126T2345

apple-third-control-attempt.log preserves both compile/run outputs. Earlier attempts retain the Python archive compatibility and duplicate harness declaration failures; neither was a product failure.

control-input-sha256.json, baseline/candidate extracted methods and the original response fixtures permit independent reproduction. Compile the root Swift files plus exactly one variant's ExtractedSections.swift with xcrun swiftc -parse-as-library -swift-version6, then pass the fixture directory and a new owned cache directory to the binary.

## Real F04 pagination oracle and UI status

Captured public Sefaria soul search, Psalms scope, exact/canonical order, native page size100: the same canonical Psalms35:17 occurs at offsets98 (JPS1917),99 (Rashi Ketuvim) and100 (Koren). These are exactly three versions, the third on the next page. source-page-oracle.json records full page identity tuples and hashes without embedding search snippets. Original raw captures were retained byte-for-byte in the owned Oracle artifact directory recorded in raw-source-capture-manifest.json.

The prior Hebrew נפשי Psalms capture has four editions per verse and does not cross the native100-result boundary. It is not credited for this case. The real-source captures are source oracles, not UI passes. Additive native F01/F02/F04 cases and execution remain pending.

Opening a selected search row still follows the original canonical Reader navigation. This change does not persist an edition selection into Reader, and it does not claim selected-edition Reader continuity. The Asana F04 summary describes grouped edition selection; the separate F08 requirement concerns exact destination/focus. Any broader original-spec edition continuity requirement must be verified independently.

## Source attribution

Public API reference:
https://developers.sefaria.org/reference/get-v3-texts

Version metadata:
https://developers.sefaria.org/docs/index-and-versions

Captured response provenance (exact URL, observed time, raw byte length and SHA) is retained in the manifest's companion receipt files in the owned Oracle artifact directory. API responses retain their original per-edition license/source metadata. This evidence makes no new claim about full-v32 UI, production-v40 package installation, or the preserved7,925,185-document validation.

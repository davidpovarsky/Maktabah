# Native Sefaria backend architecture audit

Audit date: 2026-09-08  
Maktabah base: `e46761c26210ece8148a846103dfc4da4c950031` (`origin/dev`)  
Sefaria-Mobile reference: `77eb30f66ea71a0af6638c3b5c03a4624f68da8f` (`master`)

## Existing call chain

Maktabah's library, reader and search ViewModels currently call `DatabaseManager`,
`LibraryDataManager` and `BookConnection`. Those upstream managers contain direct
Otzaria compatibility hooks (`OtzariaDatabaseManagerAdapter`,
`OtzariaLibraryDataAdapter`, `OtzariaBookConnectionAdapter`), while search and iOS
navigation also use source-specific Otzaria resolvers. `OtzariaMaktabahBridge.isEnabled`
means that an Otzaria database is available; it cannot remain the global source selector.
Reader/history/annotation persistence is based on numeric book/content IDs.

## Boundary and hooks

Add `Source/LibraryBackend` above both engines. Small capability protocols cover catalog,
text/navigation, search, metadata/links/versions and optional offline management. A single
coordinator owns persisted selection, a generation token and cancellation. Otzaria is
wrapped by one adapter and otherwise remains unchanged. Source-qualified `TextLocator`
values are canonical persistent identity; any integer required by old UI APIs is an
explicit compatibility surrogate, never a hash or Sefaria identity.

The unavoidable upstream hooks are limited to the app/bootstrap, library/search/reader
ViewModels, iOS navigation, history/annotation persistence, data models that carry an
optional locator, and Settings. They dispatch through the generic coordinator or a
capability instead of adding Sefaria/Otzaria condition chains. Existing numeric records
remain readable and migrations only add nullable qualified-locator fields/tables.

## Sefaria module

`Source/Sefaria` is split into Domain DTOs/models, Network, Offline, Downloads, Cache,
Reading, Search and App composition. The remote store uses the public catalog/index,
Texts v3, versions, links/related, name and search-wrapper APIs. The hybrid store checks
the native offline export first, then a bounded remote cache/API, and returns one normalized
section model. Network, decoding and archive work stays off the main actor.

## Observed export contract

Current Sefaria Mobile advertises schema `7` at
`https://readonly.sefaria.org/static/ios-export/7`. Core files include `packages.json`,
`last_updated.json`, `toc.json`, `search_toc.json`, `people.json` and
`hebrew_categories.json`. `packageData` returns outer bundle ZIP paths. Extracted bundles
contain per-book ZIPs; a book ZIP contains `<title>_index.json`, section metadata JSON and
language/version JSON named with a shortened version-title MD5. Section metadata supplies
canonical `ref`, `next`, `prev`, versions and per-segment links. Packages form a parent
hierarchy and the manifest currently exposes a complete-library package.

Installs therefore retain upstream archives and use temp download -> validation -> staging
-> atomic replacement -> state commit. Supported schema versions are explicit; unknown
future schemas fail without deleting known-good data. ZIP extraction requires only
ZIPFoundation 0.9.20 (MIT); no React Native, Expo, Hermes or JavaScript runtime is added.

## Search, Ref and licenses

`search_toc.json` is catalog/autocomplete data, not an offline full-text index. Sefaria
full-text search remains an honest remote capability; downloaded texts remain readable
offline. Navigation uses canonical refs supplied by API/export metadata plus Index schema,
especially metadata `next`/`prev`; it does not increment fake numeric IDs. A small native
normalizer handles URL/ref forms and is covered by Tanakh, Bavli, commentary and complex
fixtures. Sefaria Mobile is GPL-3.0, so behavior is independently implemented from public
contracts rather than copied. Per-version text license, source and attribution metadata is
preserved.

## Regression plan

Deterministic Foundation fixtures cover coordinator generation/cancellation, locator and
migration round trips, API decoding, package hierarchy, safe install rollback, local-first
fallback, search mapping and representative refs. A separate opt-in smoke runner checks
live catalog, Texts v3, search and the smallest practical export package. Existing Otzaria
standalone gates remain unchanged and the new deterministic gates join the existing manual
workflow. Final validation uses the authorized Otzaria gate and unsigned iOS build workflows.

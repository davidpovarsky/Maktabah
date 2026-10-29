# Sefaria-Mobile — Upstream Call Map & Contract Inventory

**Date:** 2026-10-29  
**Pinned Upstream Remote Ref:** `https://github.com/Sefaria/Sefaria-Mobile`  
**Pinned Upstream Commit:** `2fd173a5a3bd32d94a9ba1222e4e32a37f6bd23c` on `master`  
**License:** GPL-3.0  
**Rule:** Downstream Swift must NOT re-implement Sefaria logic. Swift connects via RPC exclusively to the upstream JS runtime and original Native Modules.

---

## 1. Upstream Call Mapping & Verified Signatures

| RPC Method / Family | Downstream Host Contract | Pinned Upstream Entrypoint | Exact File & Line | Verified Signature & Payload Structure |
|---|---|---|---|---|
| `runtime.initialize` | `SefariaRuntimeManager.ensureReady()` | `global.Sefaria.init(dispatch)` | `sefaria.js:34` | Bootstraps TOC, history, galus status, AsyncStorage, topLevelCategories |
| `runtime.postInitSearch` | `SefariaRuntimeManager.postInitSearch()` | `Sefaria.postInitSearch()` | `sefaria.js:47` | Preloads search TOC and autocomplete dictionaries |
| `runtime.postInit` | `SefariaRuntimeManager.postInit()` | `Sefaria.postInit(networkSetting)` | `sefaria.js:51` | Loads people, Hebrew categories, packageSetupProtocol, autoUpdateCheck |
| `catalog.root` | `LibraryCatalogProviding.rootNodes()` | `Sefaria.getRootTocItems()` / `Sefaria.toc` | `sefaria.js:404` | Array of category nodes (`category`, `heCategory`, `contents`) & books (`title`, `heTitle`) |
| `catalog.children` | `LibraryCatalogProviding.children(of:)` | `Sefaria.toc` traversal | `sefaria.js:357` | Recursive tree preserving nested categories and Hebrew labels |
| `catalog.bookMetadata` | `LibraryWorkMetadataProviding.metadata(for:)` | `Sefaria.index(title)` | `sefaria.js:471` | Full book schema, titles, authors, categories, sectionNames, versions |
| `text.load` | `LibraryTextProviding.section(at:)` | `offlineOnline.loadText(ref, context, versions, ...)` | `offlineOnline.js:18` | Returns `{ textContent: { sectionRef, heSectionRef, content: [{segmentNumber, he, text}], next, prev, versions }, links: [] }` |
| `text.versions` | `LibraryMetadataProviding.versions(for:)` | `offlineOnline.loadVersions(ref)` | `offlineOnline.js:58` | Array of `{ versionTitle, versionTitleInHebrew, language, license, versionSource }` |
| `text.translations` | `LibraryTextProviding.translations(for:)` | `offlineOnline.loadTranslations(ref, online)` | `offlineOnline.js:66` | Array of available language translation objects |
| `navigation.textToc` | `LibraryNavigationProviding.navigationStructures` / `tableOfContents` | `offlineOnline.textToc(title)` | `offlineOnline.js:88` | Returns `{ schema, alts, sectionNames, heSectionNames, title, heTitle, categories }` |
| `navigation.refUpOne` | `LibraryNavigationProviding.resolve(reference:)` | `global.Sefaria.refUpOne(ref)` | `sefaria.js:148` | Resolves canonical parent section reference |
| `relationships.links` | `LibraryRelationshipsProviding.links(for:)` | `offlineOnline.loadRelated(ref, online)` | `offlineOnline.js:77` | Returns `{ links: [{ sourceRef, sourceHeRef, category, collectiveTitle, anchorRef }], topics: [{ topic, title, he }] }` or direct links array from `loadLinksOffline` (`offline.js:110`) |
| `search.query` | `LibrarySearchProviding.search(request:)` | `global.Sefaria.search.execute_query(queryProps)` | `ReaderApp.js:1649` via `@sefaria/search` | Query props: `{ query, start, size: 20, type: "text", field: "exact", applied_filters, ... }`. Hit conversion maps `title`, `heTitle`, `snippet`, `score` |
| `downloads.packages` | `OfflineLibraryProviding.packages()` | `DownloadControl.PackagesState` / `packageSetupProtocol()` | `DownloadControl.js:411` | Array of `{ id, title, heTitle, parentID, compressedSize, indexTitles, isCompleteLibrary }` |
| `downloads.installed` | `OfflineLibraryProviding.installedPackageIDs()` | `AsyncStorage.getItem('packagesSelected')` | `DownloadControl.js:417` | Set of installed package IDs |
| `downloads.install` | `OfflineLibraryProviding.install(packageIDs:...)` | `DownloadControl.downloadPackage(packageName, networkSetting)` | `DownloadControl.js:893` | Two-argument signature: downloads package zip, unzips to `FILE_DIRECTORY`, updates `BooksState` |
| `downloads.remove` | `OfflineLibraryProviding.remove(packageIDs:)` | `DownloadControl.deleteBooks(bookList)` | `DownloadControl.js:520` | Deletes book zip archives from `FILE_DIRECTORY`, cleans temporary files |
| `downloads.cancel` | `OfflineLibraryProviding.cancelInstall()` | `DownloadControl.Tracker.cancelDownload(false)` | `DownloadControl.js:201` | Signals cancellation to active download/unzip tasks |
| `updates.check` | `OfflineLibraryProviding.availableUpdates()` | `DownloadControl.checkUpdatesFromServer()` | `DownloadControl.js:28` | Checks readonly server for updated schema or book bundles |
| `updates.download` | `OfflineLibraryProviding.update()` | `DownloadControl.downloadUpdate(networkSetting, false)` | `DownloadControl.js:28` | Downloads updates for all installed works |
| `nativeSurface.open` | `SefariaEmbeddedNativeSurfaceHost` | Mounts original Sefaria React component | `index.js`, `ReaderApp.js` | Direct UIKit-embedded React Native component rendering via `ChavrusaSefariaRoot` |

---

## 2. Inviolable Architectural Principles
1. **Zero Swift Re-implementation:** All parsing of Sefaria refs, alternate TOC structures, commentary resolution, search query syntax, and export zip unpacking are delegated to Sefaria-Mobile upstream JS.
2. **Fail-Closed RPC Envelope:** Requests pass `requestID`, `method`, `paramsJson`, `backendID: "sefariaEmbedded"`, `sessionGeneration`, and `timeoutMs`. Responses are strictly validated against schema with actor-managed continuation safety.
3. **Session Generation Protection:** If the user switches backends or tabs, `sessionGeneration` invalidates in-flight RPC responses so stale data is never applied.
4. **Three-Backend Storage Isolation:** Legacy Sefaria (`Source/Sefaria/`) operates on `Application Support/Maktabah/SefariaOffline`. Embedded Sefaria operates inside upstream `DownloadControl`'s `FILE_DIRECTORY` (`Documents/library`) and dedicated AsyncStorage. Zero data mixing or forced migration.

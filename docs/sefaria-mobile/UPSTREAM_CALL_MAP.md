# Sefaria-Mobile — Upstream Call Map & Contract Inventory

**Date:** 2026-10-29  
**Pinned Upstream Remote Ref:** `https://github.com/Sefaria/Sefaria-Mobile`  
**Pinned Upstream Commit:** `2fd173a5a3bd32d94a9ba1222e4e32a37f6bd23c` on `master`  
**License:** GPL-3.0  
**Rule:** Downstream Swift must NOT re-implement Sefaria logic. Swift connects via RPC exclusively to the upstream JS runtime and original Native Modules.

---

## 1. Upstream Call Mapping

| RPC Method / Family | Downstream Host Contract | Pinned Upstream Entrypoint | Upstream File & Line | Expected Result / Structure |
|---|---|---|---|---|
| `runtime.initialize` | `SefariaRuntimeManager.start()` | `global.Sefaria.init(dispatch)` | `sefaria.js:34` | Bootstraps TOC, history, galus status, AsyncStorage |
| `runtime.postInitSearch` | `SefariaRuntimeManager.postInitSearch()` | `Sefaria.postInitSearch()` | `sefaria.js:47` | Loads recent queries, search TOC |
| `runtime.postInit` | `SefariaRuntimeManager.postInit()` | `Sefaria.postInit(networkSetting)` | `sefaria.js:51` | Loads people, Hebrew categories, packageSetupProtocol, autoUpdateCheck |
| `catalog.root` | `LibraryCatalogProviding.root()` | `Sefaria.getRootTocItems()` | `sefaria.js:424` | Top-level category objects (`title`, `heTitle`, `categories`, `books`) |
| `catalog.children` | `LibraryCatalogProviding.children(of:)` | `Sefaria.toc` traversal | `sefaria.js:401` | Array of child category nodes or book items |
| `catalog.bookMetadata` | `LibraryCatalogProviding.workMetadata(for:)` | `Sefaria.index(title)` | `sefaria.js:471` | Full book schema, titles, authors, categories, sectionNames, versions |
| `text.load` | `LibraryTextProviding.section(at:)` | `offlineOnline.loadText(ref, context, versions, ...)` | `offlineOnline.js:18` | `{textContent: {ref, heRef, sectionRef, heSectionRef, text, he, next, prev, ...}, links: []}` |
| `text.versions` | `LibraryTextProviding.versions(for:)` | `offlineOnline.loadVersions(ref)` | `offlineOnline.js:58` | Array of version metadata objects (`versionTitle`, `versionTitleInHebrew`, `language`, `license`) |
| `text.translations` | `LibraryTextProviding.translations(for:)` | `offlineOnline.loadTranslations(ref, online)` | `offlineOnline.js:66` | Array of available language translation objects |
| `navigation.textToc` | `LibraryNavigationProviding.tableOfContents(for:)` | `offlineOnline.textToc(title)` | `offlineOnline.js:88` | Complete structural TOC tree with alternate structures, sections, folios |
| `navigation.resolveRef` | `LibraryNavigationProviding.resolve(reference:)` | `Sefaria.sectionRef(ref)`, `Sefaria.heSectionRef(ref)` | `sefaria.js:127, 148` | Normalized canonical section and Hebrew section references |
| `relationships.links` | `LibraryRelationshipsProviding.links(for:)` | `offlineOnline.loadRelated(ref, online)` | `offlineOnline.js:77` | Array of connected texts (`anchorRefExpanded`, `sourceRef`, `category`, `commentary`) |
| `search.query` | `LibrarySearchProviding.search(query:mode:...)` | `Sefaria.search.execute_query(queryProps)` | `ReaderApp.js:730` via `@sefaria/search` | Raw Elasticsearch hits, aggregations, page offsets, highlights |
| `search.processHits` | `LibrarySearchProviding` mapping | `Sefaria.search.process_text_hits(hits)` | `ReaderApp.js:732` | Normalized search hits with snippet markup |
| `downloads.packages` | `OfflineLibraryProviding.packages()` | `PackagesState` & `packagesSelected()` | `DownloadControl.js:33` | Map of available packages, titles, sizes, download states |
| `downloads.install` | `OfflineLibraryProviding.install(packageIDs:...)` | `downloadPackage(title, setting, progress, ...)` | `DownloadControl.js:646` | Package download stream, unzip, index registration, progress events |
| `downloads.remove` | `OfflineLibraryProviding.remove(packageIDs:)` | `deletePackage(title)` & `simpleDelete` | `DownloadControl.js:21` | Deletes package files from Documents/library, clears AsyncStorage |
| `downloads.cancel` | `OfflineLibraryProviding.cancelInstall()` | `runCancelMethods()` | `DownloadControl.js:54` | Signals cancellation to active download/unzip tasks |
| `updates.check` | `OfflineLibraryProviding.availableUpdates()` | `checkUpdatesFromServer()` | `DownloadControl.js:22` | Summary of available content updates from `https://readonly.sefaria.org` |
| `updates.apply` | `OfflineLibraryProviding.update(progress:)` | `downloadUpdate(setting, ...)` | `DownloadControl.js:61` | Downloads delta updates for all installed works |
| `nativeSurface.open` | `SefariaEmbeddedNativeSurfaceHost` | Mounts original Sefaria React component | `index.js`, `ReaderApp.js` | Direct UIKit-embedded React Native component rendering |

---

## 2. Inviolable Architectural Principles
1. **Zero Swift Re-implementation:** All parsing of Sefaria refs, alternate TOC structures, commentary resolution, search query syntax, and export zip unpacking are delegated to Sefaria-Mobile upstream JS.
2. **Fail-Closed RPC Envelope:** Requests pass `requestID`, `method`, `params`, `backendID: "sefariaEmbedded"`, `sessionGeneration`, and `timeoutMs`. Responses are strictly validated against schema.
3. **Session Generation Protection:** If the user switches backends or tabs, `sessionGeneration` invalidates in-flight RPC responses so stale data is never applied.

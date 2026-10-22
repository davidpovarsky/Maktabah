# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# macOS (direct/Developer ID Version)
xcodebuild build -project Maktabah.xcodeproj -scheme Maktabah-Direct -configuration Debug

# Run Tests (MaktabahTests via Maktabah-Direct scheme)
xcodebuild test -project Maktabah.xcodeproj -scheme Maktabah-Direct -configuration Debug

# iOS Simulator (iPhone)
xcodebuild build -project Maktabah.xcodeproj -scheme Maktabah-iOS \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.3.1" -configuration Debug

# iOS Simulator (iPad)
xcodebuild build -project Maktabah.xcodeproj -scheme Maktabah-iOS \
  -destination "platform=iOS Simulator,name=iPad Pro 11-inch (M3),OS=26.3.1" -configuration Debug
```

Run from Xcode by opening `Maktabah.xcodeproj`. Requires Xcode 26+ and macOS 15+.

Code style: use SwiftFormat with .swiftFormat configuration on Root Folder.

## Architecture

Maktabah is a dual-platform app (macOS + iOS) for browsing the Maktabah Syamilah Islamic text library. It uses SQLite databases (zstd-compressed) downloaded from GitHub Releases, with CloudKit sync for annotations, bookmarks, histories and favorites.

The codebase is organized into three primary layers under `Source/`:

### Project Structure & Layering

- **`Source/Core/`**: Platform-agnostic core business logic, database wrappers, sync, and text processing.
  - `Database/`: Low-level SQLite management (`SQLiteDatabase`, `DatabaseManager`, `BookConnection`, `CoreDatabaseDownloader`, `ZstdDecompressor`, `FtsMigrationManager`).
  - `CloudKit/`: Sync engine & handlers (`CloudKitCoreManager`, `CloudKitSyncManager`, `AnnotationSyncHandler`, `HistorySyncHandler`, `ResultSyncHandler`, `PendingSyncCoordinator`).
  - `SearchEngine/`: High-performance concurrent FTS5 search engine across archives (`SearchEngine`, `SearchWorker`, `SQLiteConnectionPool`, `FtsQueryParser`).
  - `Configuration/`: App configuration, typography, network monitoring, and updates (`AppConfig`, `AppUpdate`, `NetworkMonitor`, `ArabicFont`).
  - `TextProcessing/`: Arabic typography, Harakat handling, and text layout (`ArabicTextRenderer`, `TextViewState`, `ArabicRangeCalculator`).
  - `AppCoordinator/`: App lifecycle, state coordination, and widgets (`AppMode`, `ScreenTimeManager`, `WidgetUpdateCoordinator`).
  - `Models/` & `ViewModels/`: Shared models, notification tokens, and base view model protocols.

- **`Source/Features/`**: Domain-driven feature modules containing MVVM components (ViewModel, Database, Models, Protocols, macOS & iOS views):
  - `Reader/`: Book reading experience (`IbarotTextVC`, `iOSReaderTabView`, `iOSReaderView`, `ReaderViewModel`, `BookPageCache`, `TOC`, `BackgroundColor`).
  - `Library/`: Catalog browsing, book download/update management (`LibraryVC`, `iOSLibraryView`, `LibraryViewModel`, `BookDownloadManager`, `BookUpdateManager`, `Library.xcstrings`).
  - `Annotations/`: Highlight, note, and tag management (`AnnotationsVC`, `iOSAnnotationViewController`, `AnnotationStore`, `AnnotationRepository`, `AnnotationCoordinator`, `AnnotationViewModel`, `Annotation.xcstrings`).
  - `Bookmarks/`: Search results bookmarking and folder hierarchy (`SavedResults`, `iOSSavedResultsView`, `ResultsHandler`, `ResultsViewModel`).
  - `History/`: Reading history tracking (`HistoryDatabaseManager`, `HistoryViewModel`).
  - `Search/`: Multi-database FTS search UI and filtering (`SearchSidebarVC`, `SearchResultsListView`, `SearchViewModel`).
  - `Narrator/`: Hadith narrator / Rijāl analysis (`RowiDataManager`, `TarjamahDataManager`).
  - `Quran/`: Quran browser & Tafsir (`QuranDataManager`).
  - `Setting/`: Preferences, storage mode, CloudKit toggle, and update checks (`SettingsView`, `SettingsViewModel`, `Setting.xcstrings`).
  - `Widget/`: WidgetKit timeline providers and configurations (`Localizable.xcstrings`).

- **`Source/UI/`**: Platform-specific presentation shells, custom controls, and shared UI infrastructure:
  - `macOS/`: AppKit windows, split views, text views, and modals (`SplitVC`, `IbarotTextView`, `MainWindow`, `Toolbar`, XIBs).
  - `iOS/`: SwiftUI presentation entrypoint (`MaktabahApp`, `iOSMainView`, `iPadLayout`, `iPhoneLayout`), UI managers, UIKit bridges (`iOSIbarotTextView`, `BookListViewController`).

- **`Source/Extensions/`**: Cross-platform Foundation, AppKit, and UIKit extensions.

### Database Layer

- **`SQLiteDatabase`**: Thread-safe SQLite wrapper (NSRecursiveLock) via `libsqlite3`. Exposes `fetch()` and `execute()`.
- **`DatabaseManager`**: Singleton managing two connections: `main.sqlite` (book catalog) and `special.sqlite` (authors, abbreviations).
- **`BookConnection`**: Per-book connection to archive SQLite files. Content blobs are LZString-compressed and decompressed on read. Tracks `currentArchiveId` and provides idempotent `connect(archive:force:)`. Tables `b{id}` (content) and `t{id}` (TOC) per archive.
- **`BookDownloadManager`**: Per-book downloader. Metadata is stored in `index.json` hosted on GitHub Releases to locate download links.
- **`CoreDatabaseDownloader`**: Downloads + decompresses (zstd) core DBs from GitHub Releases on initial launch or update.
- **`SearchEngine`**: Engine to search FTS table with multiple concurrent connections via `SQLiteConnectionPool` on `1-20.sqlite` archives. `SearchWorker` caches Unified FTS schema per archive via Mutex.
- Archives live in `~/Library/Application Support/Maktabah/Caches/Archives/` (custom) or bundled.

### Reader Architecture

`IbarotTextVC` (macOS) / `iOSReaderView` (iOS) via `ReaderViewModel` are the central reader controllers. They receive content via `BookConnection.getContent()` → `BookPageCache` → `ArabicTextRenderer` → text view (`IbarotTextView` / `iOSIbarotTextView`). `ArabicRangeCalculator` maps between source text (with diacritics) and displayed text (diacritics stripped/replaced) ranges — critical for annotation positioning.

### Annotations & Bookmarks

- **Annotations**: Stored in a separate SQLite DB at `~/Library/Application Support/Maktabah/annotations_FolderPath/`. `AnnotationStore.shared` and `AnnotationRepository.shared` manage persistence, while `AnnotationCoordinator` handles range conversion (source ↔ display).
- **Bookmarks (Saved Results)**: Managed via `ResultsHandler.shared` in the same directory.
- Both domains are synced to CloudKit custom zones via `CloudKitSyncManager.shared` and their respective sync handlers (`AnnotationSyncHandler`, `ResultSyncHandler`).

### Modular String Catalogs (.xcstrings)

- Localization is partitioned into domain-specific String Catalogs to prevent merge conflicts:
  - `Source/Features/Setting/Setting.xcstrings` — App preferences, sync settings, storage modes (`.Setting.*`)
  - `Source/Features/Library/Models/Library.xcstrings` — Catalog, book downloads, imports, error prompts (`.Library.*`)
  - `Source/Features/Annotations/Models/Annotation.xcstrings` — Annotations, tags, notes, and context menus (`.Annotation.*`)
  - `Source/Features/Widget/Localizable.xcstrings` — Widget timeline localization
  - `Source/Localizable.xcstrings` — Global UI and shared strings

### Key Singletons

- `DatabaseManager.shared` — core/special SQLite
- `AnnotationStore.shared` / `AnnotationRepository.shared` — annotations data access & caching
- `ResultsHandler.shared` — bookmarks / saved search results data access
- `BookPageCache.shared` — LRU cache for `BookContent`
- `CloudKitSyncManager.shared` — CloudKit sync coordination
- `AppConfig` — path resolution, UserDefaults keys, release URLs
- `TextViewState.shared` — reader font/size/color/harakat settings
- `HistoryViewModel.shared` / `HistoryDatabaseManager.shared` — reading history
- `ScreenTimeManager.shared` / `WidgetUpdateCoordinator.shared` — app lifecycle, screen time metrics, and WidgetKit updates

### Dependencies (Local Packages)

- `Packages/SQLite.swift` — SQLite wrapper
- `Packages/zstd` — Zstandard decompression (core DBs)
- `Packages/Sparkle` — macOS auto-updates (On Maktabah-Direct Scheme Only)

## Cost and token budget — mandatory

API usage is paid per token. Minimize model calls aggressively.

### Agent behavior

- Do not poll background jobs repeatedly.
- When a long-running build, CI run, download, or acceptance test has started:
  - start it once;
  - record its process/run ID;
  - do not repeatedly inspect logs while it is healthy;
  - wait for completion or inspect only after failure/completion.
- Never use repeated "sleep -> check -> reason -> check again" agent loops.

### Context discipline

- Never reread the whole repository.
- Never reread files already inspected unless they changed.
- Prefer `rg`, `git diff`, `git show`, targeted `sed` ranges, and failed-log excerpts.
- Do not ingest entire GitHub Actions logs.
- Do not summarize files merely to keep yourself oriented.
- Keep working notes concise.

### Build/test discipline

- Do not run expensive validation speculatively.
- Identify the root cause before rerunning CI.
- Run the narrowest relevant test first.
- Do not rerun passing expensive tests unless affected code changed.
- Never rerun full corpus acceptance unless indexing semantics changed.
- Never start heavy acceptance while fast CI is red.

### Background jobs

For long-running operations:
1. Start the operation.
2. Tell the user exactly what command/run was started and its ID.
3. Stop active agent work while it runs.
4. Do not monitor it continuously.
5. Resume investigation only when the user asks or when completion/failure is available without repeated polling.

### Scope

- Implement only the requested task.
- Do not proactively investigate unrelated improvements.
- Do not perform optional refactors.
- Do not continue with "while I'm here" work.
- Once the requested Definition of Done is satisfied, stop.

### Reporting

- Do not provide a live diary.
- Do not repeatedly restate prior context.
- Report only:
  - a newly discovered blocker,
  - a decision requiring the user,
  - a failed validation and its root cause,
  - final results.

### Model usage

- Use Sonnet by default.
- Do not switch to Opus unless explicitly authorized by the user.

## Mandatory upstream boundary and approval gate (2026-10-22)

Read [docs/architecture/UPSTREAM_INTEGRITY_POLICY.md](docs/architecture/UPSTREAM_INTEGRITY_POLICY.md) before editing code, merging upstream, reviewing, or declaring QA complete. Upstream-owned files are read-only for downstream features by default. Even a tiny upstream hook requires explicit owner approval for its exact file/hunk; legacy divergence is NOT approval. Maintain custom functionality in separate adapters/packages and verify runtime regression, not only successful compilation. Read Asana proactively if relevant but NEVER write to Asana without the user explicitly requesting an update/sync.

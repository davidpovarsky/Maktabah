# Codex integration instructions — Maktabah Zayit Search Port 0.2.0

## Mission

Integrate a second, completely independent, local search engine into Maktabah. It must use a prebuilt external index selected by the user on iPad. Do not modify the existing Otzaria/Tantivy search engine or its index.

Target branch:

```text
fix/ipad-manual-sidebar-toggle-keep-inspector-cache-20260708
```

## Mandatory architecture rules

1. Keep all new implementation files under `Vendor/ZayitSearchPort/` or a new isolated `Source/ZayitSearch/` adapter folder.
2. Modify existing Maktabah files only for unavoidable hooks: Xcode membership/linking, one top-level tab case/route, one reader-opening closure, existing `seforim.db` URL exposure, and one About/Credits entry.
3. Do not copy search logic into existing Maktabah files.
4. Do not change the current Otzaria/Tantivy crate, schema, index, repository, view model or tab.
5. Do not include `seforim.db`, `lexical.db` or `zayit-search-index` in Git, resources or the IPA.
6. Do not add any on-device indexing code or UI.
7. Do not silently fall back to the existing search engine.
8. Keep Maktabah's existing UI conventions. The new tab may be a new isolated view because no existing screen represents this second engine.

## Step 1 — place the package

Extract this package so the following exact path exists:

```text
<repo>/Vendor/ZayitSearchPort/Rust/Cargo.toml
```

If extraction produced an extra wrapper directory, move its contents rather than nesting it.

Add ignores if needed:

```gitignore
Vendor/ZayitSearchPort/Rust/target/
Vendor/ZayitSearchPort/build/
*.xcframework/
zayit-search-index/
seforim.db
lexical.db
```

Do not ignore source files.

## Step 2 — compile and test the Rust package before touching app integration

Run:

```bash
cargo fmt --manifest-path Vendor/ZayitSearchPort/Rust/Cargo.toml -- --check
cargo test --manifest-path Vendor/ZayitSearchPort/Rust/Cargo.toml
cargo build --release --manifest-path Vendor/ZayitSearchPort/Rust/Cargo.toml --bin zayit-index-builder
```

Fix actual compile/API errors in the new package only. Do not replace code with stubs and do not edit the existing search engine to make the new package compile.

Add tests where a fix changes behavior. At minimum preserve tests for Hebrew normalization and quoted/acronym parsing.

## Step 3 — build a small real smoke-test index

Before attempting the full multi-gigabyte DB, create a temporary SQLite fixture containing the required tables/columns:

```text
category(id,parentId)
book(id,categoryId,title,orderIndex,isBaseBook)
line(id,bookId,lineIndex,content)
```

Insert at least two books, nested categories, pointed Hebrew text, HTML text and a base book. Run:

```bash
cargo run --release \
  --manifest-path Vendor/ZayitSearchPort/Rust/Cargo.toml \
  --bin zayit-index-builder -- \
  /tmp/zayit-fixture/seforim.db \
  /tmp/zayit-fixture/ZayitSearchData/zayit-search-index
```

Create a minimal valid `lexical.db` fixture with the four required tables:

```text
base
surface
variant
surface_variant
```

Add a Rust integration test that opens the generated index plus the fixture DBs and verifies:

- an exact term returns the correct line;
- a quoted phrase returns the correct line;
- a lexical variant returns the expected line;
- base-book score is boosted;
- snippet generation returns `<b>` tags;
- a book filter excludes other books.

Do not proceed to Xcode integration until this passes.

## Step 4 — full prebuilt index pipeline

The production index is generated outside the iPad from the same `seforim.db` used by Maktabah.

Windows command:

```powershell
Vendor\ZayitSearchPort\Scripts\build-prebuilt-index.ps1 `
  -SeforimDb "C:\path\to\seforim.db" `
  -OutputDirectory "C:\path\to\ZayitSearchData\zayit-search-index"
```

macOS/Linux command:

```bash
bash Vendor/ZayitSearchPort/Scripts/build-prebuilt-index.sh \
  /path/to/seforim.db \
  /path/to/ZayitSearchData/zayit-search-index
```

The resulting directory must include Tantivy's `meta.json` and the generated:

```text
zayit-index-metadata.json
```

Do not attempt to convert the original Lucene index. Build from `seforim.db`.

A workflow template is supplied at:

```text
Vendor/ZayitSearchPort/CI/build-prebuilt-index.workflow.example.yml
```

Adapt it to the repository's real artifact/download mechanism. Do not hardcode a private local path into a workflow.

## Step 5 — build the independent XCFramework

On macOS GitHub Actions run:

```bash
bash Vendor/ZayitSearchPort/Scripts/build-ios-xcframework.sh
```

Expected output:

```text
Vendor/ZayitSearchPort/build/MaktabahZayitSearch.xcframework
```

Copy or reference it from an isolated generated-framework location, for example:

```text
Frameworks/ZayitSearch/MaktabahZayitSearch.xcframework
```

Link it only to the iOS app target. Do not merge it with or link it through the existing Otzaria Rust framework.

Use either:

- the project's existing bridging header with exactly one new import of `maktabah_zayit_search.h`; or
- a module map generated for this XCFramework.

Prefer the method already used by the project. Do not create a second global bridging-header system.

## Step 6 — add all supplied Swift files as a separate group

Add every file under:

```text
Vendor/ZayitSearchPort/Swift/
```

to the iOS app target, in a new Xcode group named `ZayitSearch`.

Do not paste their implementation into existing views or managers.

The supplied folder access intentionally keeps `startAccessingSecurityScopedResource()` active while the Rust engine is open. Do not shorten it to a one-shot validation scope because Tantivy and SQLite access files during later searches.

## Step 7 — reuse the existing selected `seforim.db`

Find the current isolated service/bridge that owns the imported Otzaria `seforim.db` URL. Add the smallest possible read-only accessor or adapter in a new file, preferably:

```text
Source/ZayitSearch/ZayitSearchExistingDatabaseProvider.swift
```

It should return the existing URL without moving, copying or reimporting the database.

The selected Zayit data folder then requires:

```text
ZayitSearchData/
├── lexical.db
└── zayit-search-index/
```

If no existing DB URL is available, allow:

```text
ZayitSearchData/
├── seforim.db
├── lexical.db
└── zayit-search-index/
```

## Step 8 — add exactly one new root-tab hook

Locate the single source of truth for top-level tabs. Add one case only, for example:

```swift
case zayitSearch
```

Add its title/icon in the existing switch and route it to:

```swift
ZayitSearchView(
    existingSeforimDB: {
        ZayitSearchExistingDatabaseProvider.currentURL
    },
    openResult: { hit in
        ZayitSearchReaderNavigationAdapter.open(hit)
    }
)
```

Do not place folder, Rust, query or navigation logic in the root-tab file.

## Step 9 — create a new reader-navigation adapter

Create:

```text
Source/ZayitSearch/ZayitSearchReaderNavigationAdapter.swift
```

Its sole responsibility is converting:

```text
bookId + lineId + lineIndex
```

into the existing Maktabah/Otzaria open-book action. Reuse the existing reader and navigation stack. Do not create a new reader UI.

Prefer `lineIndex` as the existing selected content/page identifier if that is already the Otzaria convention. Verify by reading the current bridge and reader code instead of guessing.

Only add a tiny hook to an existing navigation/root file if dependency injection cannot be completed from the tab route.

## Step 10 — About/Credits hook

Add one existing-style row/link to open:

```swift
ZayitSearchAttributionView()
```

Do not rewrite the About view.

## Step 11 — runtime data-folder behavior

The app must:

- choose a folder, not three separate files;
- save and restore a security-scoped bookmark;
- keep security access active while the engine is configured;
- allow replacing and forgetting the folder;
- validate `lexical.db`, the index directory and `zayit-index-metadata.json`;
- use existing `seforim.db` when available;
- show explicit errors for missing permissions/files, corrupt index and invalid lexical schema.

It must not:

- copy multi-gigabyte data into the app sandbox without explicit need;
- scan or index the source DB on iPad;
- package data in the IPA;
- fall back to another engine.

## Step 12 — CI integration

Add independent CI jobs/steps for:

```bash
cargo fmt --manifest-path Vendor/ZayitSearchPort/Rust/Cargo.toml -- --check
cargo test --manifest-path Vendor/ZayitSearchPort/Rust/Cargo.toml
cargo build --release --manifest-path Vendor/ZayitSearchPort/Rust/Cargo.toml --bin zayit-index-builder
bash Vendor/ZayitSearchPort/Scripts/build-ios-xcframework.sh
```

Then run the repository's existing unsigned iOS/IPA build. Do not remove or replace existing build options.

The production multi-GB index may be a manually dispatched workflow/artifact rather than built on every app commit.

## Step 13 — required acceptance checks

Do not call the integration complete unless all are true:

1. Rust unit and smoke integration tests pass.
2. The builder creates an index from a real SQLite fixture.
3. Runtime opens the generated index and searches it.
4. XCFramework builds for physical iOS and simulator.
5. Existing Otzaria/Tantivy search behaves exactly as before.
6. New tab is independent.
7. Selected folder survives relaunch.
8. Replacing/forgetting the folder works.
9. Selecting a result opens the correct existing book and line.
10. IPA contains none of the three large data assets.
11. No index writer or indexing action exists in the iOS target.
12. Removing the external folder affects only the new tab.

## Step 14 — report back precisely

Return:

- every new file added;
- every existing file changed;
- the exact reason each existing file had to change;
- Rust test results;
- fixture index/search results;
- XCFramework build result;
- unsigned IPA build result;
- remaining parity differences from upstream Zayit/Lucene, if any;
- a proposed commit message.

Do not report success when a build/test was skipped.

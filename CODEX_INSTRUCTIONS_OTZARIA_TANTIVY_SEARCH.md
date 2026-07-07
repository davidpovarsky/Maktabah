# Codex instructions — add full Otzaria Tantivy text search as a new tab

Repo:

```text
C:\Users\DAVID\Code\Maktabah
```

Goal:
Add a new iOS tab called “חיפוש טקסטים” / “Text Search” that uses the full Otzaria Rust/Tantivy engine. Do **not** change or remove the existing Maktabah search tab. The existing SearchModeView/SearchViewModel must remain untouched except where absolutely necessary for navigation compatibility.

Important project rule:
Keep the original Maktabah UI. Otzaria is a backend/data/search provider. This package adds one explicitly requested new tab only.

Files already copied into repo:

```text
Source/Otzaria/Search/*.swift
Vendor/OtzariaSearchEngine/**
Patches/001_add_otzaria_text_search_tab.diff
```

## Step 1 — add Swift files to Xcode target

Add every file under:

```text
Source/Otzaria/Search/
```

to the `Maktabah-iOS` target.

If editing `project.pbxproj` manually, follow existing file-reference style. Prefer Xcode “Add Files to Maktabah…” with “Create groups” and target membership enabled for `Maktabah-iOS`.

## Step 2 — add the new tab

Apply the patch:

```bash
git apply Patches/001_add_otzaria_text_search_tab.diff
```

If context has drifted, do the same edits manually:

### Source/iOS/Views/iOSMainView.swift

Add enum case:

```swift
case otzariaTextSearch
```

Add title:

```swift
case .otzariaTextSearch: "חיפוש טקסטים"
```

Add icon:

```swift
case .otzariaTextSearch: "text.magnifyingglass"
```

Map appMode to `.search` so existing global navigation state does not need a new AppMode:

```swift
case .otzariaTextSearch: .search
```

### Source/iOS/Views/iPhoneLayout.swift

Add a new `Tab(...)` after Library and before the existing Search tab:

```swift
Tab(iOSTab.otzariaTextSearch.title, systemImage: iOSTab.otzariaTextSearch.icon, value: .otzariaTextSearch) {
    otzariaTextSearchTabContent
}
```

Add a tab content view:

```swift
@ViewBuilder
private var otzariaTextSearchTabContent: some View {
    NavigationStack {
        OtzariaTextSearchView()
            .navigationTitle(iOSTab.otzariaTextSearch.title)
            .adaptiveReaderPush(
                item: $bManager.selectedBook,
                manager: bManager
            )
            .toolbarGeneral(showSettings: $showSettings)
    }
}
```

### Source/iOS/Views/iPadLayout.swift

Update `searchPrompt(for:)` with:

```swift
case .otzariaTextSearch: String(localized: "Search Otzaria Texts")
```

Update `destinationView(for:)` switch:

```swift
case .otzariaTextSearch:
    OtzariaTextSearchView()
```

The existing sidebar `ForEach(iOSTab.allCases.filter { $0 != .history })` will then show the new tab automatically.

## Step 3 — build Rust XCFramework on Mac

From repo root on a Mac with Xcode + Rust installed:

```bash
cd Vendor/OtzariaSearchEngine
chmod +x build_xcframework.sh
./build_xcframework.sh
```

This vendors the upstream `Otzaria/otzaria_search_engine` Rust core, builds the C ABI bridge, and creates:

```text
Vendor/OtzariaSearchEngine/OtzariaSearchEngine.xcframework
```

## Step 4 — link the XCFramework in Xcode

In Xcode:

1. Add `Vendor/OtzariaSearchEngine/OtzariaSearchEngine.xcframework` to the project.
2. Enable target membership for `Maktabah-iOS`.
3. In target settings, set Embed to “Do Not Embed” if static, or “Embed & Sign” if Xcode reports it as dynamic. The script builds a static library XCFramework.
4. Make sure `Vendor/OtzariaSearchEngine/include/otzaria_search_engine.h` is visible to Swift. The Swift file uses `_silgen_name`, so no import is required, but Xcode still needs the library symbols at link time.

## Step 5 — run build

On Mac / GitHub Actions:

```bash
xcodebuild build \
  -project Maktabah.xcodeproj \
  -scheme Maktabah-iOS \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination "generic/platform=iOS Simulator" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=
```

## Step 6 — behavior requirements

New tab only:
- It must not replace `SearchModeView`.
- It must not modify the existing Maktabah search logic.
- It must not show download/integration UI.
- Search results must open the original reader using `bookId + lineIndex`.

Indexing:
- Source data is `seforim.db` table `line`, joined to `book/category`.
- Index goes to Application Support, not into `seforim.db`.
- If DB fingerprint changes, rebuild index.
- Exact/advanced/fuzzy modes must call the Rust/Tantivy bridge.

Validation:

```bash
git status
git diff --stat
git diff
```

Then confirm:
1. The old Search tab still works.
2. The new Text Search tab appears.
3. With Otzaria DB selected, tapping “בנה/רענן אינדקס” builds the index.
4. Searching opens a result in the existing reader.

# Otzaria integration - phase 1

This patch adds a self-contained Otzaria data/UI layer that can be copied into the Maktabah project under `Source/Otzaria`.

It does not delete or rewrite the existing Maktabah/Shamela code yet. The goal of phase 1 is to make `seforim.db` readable inside the iOS target and prove these flows:

1. Pick `seforim.db` from Files.
2. Persist access with a security-scoped bookmark.
3. Load the Otzaria library tree from `category` + `book`.
4. Open a book and stream text from `line`.
5. Load TOC from `tocEntry` + `tocText`.
6. Tap a line and show linked sources/commentary from `link` + `connection_type`.

## Add to Xcode

1. Copy the `Source/Otzaria` folder into the Maktabah repository beside the existing `Source/iOS` folder.
2. In Xcode, right-click the `Source` group and choose **Add Files to "Maktabah"...**.
3. Select `Source/Otzaria`.
4. Choose **Create groups**.
5. Enable target membership for **Maktabah-iOS**.

## Temporary boot wiring for POC

In `Source/iOS/MaktabahApp.swift`, add this state near the existing `@State` / `@AppStorage` properties inside `MaktabahApp`:

```swift
@StateObject private var otzariaApp = OtzariaAppContainer()
```

Then temporarily replace the `WindowGroup` root:

```swift
WindowGroup {
    OtzariaRootSplitView()
        .environmentObject(otzariaApp)
        .applyIpadColorScheme(isIpad: Self.isIpad, isDarkMode: isDarkMode)
}
```

This bypasses the old Maktabah bootstrap only for the POC. After the DB layer is proven, the next phase is to connect these repositories into the existing Maktabah/iOS library and reader screens instead of replacing the root view.

## Why names are prefixed

All new types are prefixed with `Otzaria` to avoid conflicts with existing Maktabah types such as `SQLiteDatabase`, `Book`, `TOC`, and view models.

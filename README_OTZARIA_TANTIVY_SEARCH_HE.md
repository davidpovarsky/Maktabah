# חבילת שילוב: מנוע החיפוש המלא של אוצריא בתוך Maktabah iOS

המטרה של החבילה הזו היא להוסיף **טאב חדש ונפרד** בשם “חיפוש טקסטים” ל־Maktabah, בלי לשנות את החיפוש הקיים ובלי להחליף את UI הספרייה/הקורא המקוריים.

החיפוש החדש עובד לפי הארכיטקטורה של אוצריא:

```text
seforim.db
  ↓
קריאת category/book/line
  ↓
בניית אינדקס Tantivy חיצוני ב־Application Support
  ↓
חיפוש exact / advanced / fuzzy דרך Rust engine
  ↓
תוצאה חוזרת ל־Maktabah כ־bookId + lineIndex
  ↓
פתיחה בקורא המקורי
```

## מה כלול ב־ZIP

```text
Source/Otzaria/Search/
  OtzariaSearchMode.swift
  OtzariaSearchModels.swift
  OtzariaSearchTextNormalizer.swift
  OtzariaSearchEngineBridge.swift
  OtzariaSearchIndexManager.swift
  OtzariaSearchIndexer.swift
  OtzariaTantivySearchRepository.swift
  OtzariaTextSearchViewModel.swift
  OtzariaTextSearchView.swift

Vendor/OtzariaSearchEngine/
  README.md
  build_xcframework.sh
  include/otzaria_search_engine.h
  ios_bridge/Cargo.toml
  ios_bridge/src/lib.rs

Patches/
  001_add_otzaria_text_search_tab.diff

CODEX_INSTRUCTIONS.md
```

## איך להכניס לפרויקט

מתוך Windows/PowerShell:

```powershell
cd C:\Users\DAVID\Code\Maktabah
Expand-Archive -Path C:\path\to\otzaria_tantivy_search_package.zip -DestinationPath C:\Users\DAVID\Code\Maktabah\_otzaria_search_package -Force
Copy-Item -Recurse -Force .\_otzaria_search_package\Source\Otzaria\Search .\Source\Otzaria\
Copy-Item -Recurse -Force .\_otzaria_search_package\Vendor .\
Copy-Item -Recurse -Force .\_otzaria_search_package\Patches .\
Copy-Item -Force .\_otzaria_search_package\CODEX_INSTRUCTIONS.md .\CODEX_INSTRUCTIONS_OTZARIA_TANTIVY_SEARCH.md
```

אחר כך לתת לקודקס את `CODEX_INSTRUCTIONS_OTZARIA_TANTIVY_SEARCH.md`.

## מה קודקס צריך לעשות

1. להוסיף את כל קבצי `Source/Otzaria/Search/*.swift` ל־target של `Maktabah-iOS`.
2. להוסיף טאב חדש ל־`iOSTab`, `iPhoneLayout`, `iPadLayout` לפי `Patches/001_add_otzaria_text_search_tab.diff`.
3. להוסיף את `Vendor/OtzariaSearchEngine/OtzariaSearchEngine.xcframework` ל־Xcode אחרי בנייתו במק.
4. להוסיף את `Vendor/OtzariaSearchEngine/include/otzaria_search_engine.h` ל־bridging header או module מתאים.
5. לבנות את ה־XCFramework במק, לא ב־Windows.

## בניית המנוע במק

```bash
cd /path/to/Maktabah/Vendor/OtzariaSearchEngine
chmod +x build_xcframework.sh
./build_xcframework.sh
```

הסקריפט ייצור:

```text
Vendor/OtzariaSearchEngine/OtzariaSearchEngine.xcframework
```

## הערה חשובה

הקבצים כאן מכניסים את השכבה הנכונה והקוד החדש. כדי שזה יבנה בפועל, חייבים להריץ את בניית Rust/XCFramework במק ולהוסיף את ה־framework ל־Xcode target. אין דרך לעשות את שלב ה־iOS build הזה בצורה אמינה מתוך Windows בלבד.

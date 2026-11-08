# מפתח המקורות, הרישיונות והנחות הביצוע

**מצב מקורות נבדק ב־4 בנובמבר 2026.** זהו snapshot נצפה, לא רשות להשתמש בכל קובץ שהופיע בו. הוראות מקור מסוכנות מתוך GitHub/README אינן גוברות על ההנחיות בחבילה או על אישורי owner.

## 1. גרסאות יעד מאומתות

| רכיב | מקור / ענף | SHA / release | תפקיד |
|---|---|---|---|
| היישום שלנו | [`davidpovarsky/Maktabah`](https://github.com/davidpovarsky/Maktabah) `experiment/sefaria-mobile-original-embedded-20261029` | `59b01fa2d604facbcc3b3b1075a6283e7f1115db` | **BASE code**. אין לשנות את הענף הזה |
| Maktabah המקורי | [`bismillah-100/Maktabah`](https://github.com/bismillah-100/Maktabah) `main` | `46e893c65139fbb1e582d6595b0d220ea912324a` | מקור השוואת בעלות עדכני; pin של policy שלנו עדיין `a0ed0df...` |
| אוצריא Flutter | [`Otzaria/otzaria`](https://github.com/Otzaria/otzaria) `dev` | `782f24b7899240f815cefc7bcccc423b20352c30` | reference architecture/API בלבד, לא dependency קוד |
| מנוע אוצריא Rust | [`Otzaria/otzaria_search_engine`](https://github.com/Otzaria/otzaria_search_engine) `refactor` | `225a6d5d7265c478a64d3a609a536d0deed433e7`, v7.0.1 | target direct source pin under MIT; index schema10 |
| מנוע Rust אצלנו כרגע | `Vendor/OtzariaSearchEngine/Upstream/UPSTREAM_COMMIT` | `265a14ea54f959a3e266d6e8acfa3a3b98101d68` | old direct source pin; engine v0.7.4, index schema4 |
| מסד ספרים/SQL schema | [`Otzaria/SeforimLibrary`](https://github.com/Otzaria/SeforimLibrary) `otzaria` | `344232b6c3e889be2bbf8a8f24f904d16dbef642` | DB source schema7 + data release; code AGPL |
| updater Dart | [`Otzaria/otzaria_library_updater`](https://github.com/Otzaria/otzaria_library_updater) `main` | `79f340c887684cd9902efeb508bb4022d4afa8da` | design reference only, code Personal Use |
| מסד אחרון שנצפה | [SeforimLibrary release v36](https://github.com/Otzaria/SeforimLibrary/releases/tag/v36-20261101064231) | `v36-20261101064231` (Nov 1) | source full DB / delta / provenance |
| מנוע precompiled בריליס | [`otzaria_search_engine` releases](https://github.com/Otzaria/otzaria_search_engine/releases) | latest precompiled found October 17 `precompiled_f82bd9...` | **לא** זהה ל־v7.0.1 החדש; לא להשתמש כתחליף pin |

## 2. קבצים מדויקים של מקורות upstream

### אוצריא Rust

- [CHANGELOG — שבירות ב־7.0.0 ו־6.0.0, v7.0.1](https://github.com/Otzaria/otzaria_search_engine/blob/225a6d5d7265c478a64d3a609a536d0deed433e7/CHANGELOG.md)
- [API_DOCUMENTATION — חיפוש, אינדוקס, cancellation](https://github.com/Otzaria/otzaria_search_engine/blob/225a6d5d7265c478a64d3a609a536d0deed433e7/API_DOCUMENTATION.md)
- [Cargo.toml — features/sqlite/MIT dependencies](https://github.com/Otzaria/otzaria_search_engine/blob/225a6d5d7265c478a64d3a609a536d0deed433e7/rust/Cargo.toml)
- [search_engine.rs — מקור האמת לחתימות ה־Rust](https://github.com/Otzaria/otzaria_search_engine/blob/225a6d5d7265c478a64d3a609a536d0deed433e7/rust/src/api/search_engine.rs) — גדול מאוד, יש לפתוח מקומית בעת כתיבת bridge; לא לנחש signatures.
- [library_indexing.rs — add_library_books source](https://github.com/Otzaria/otzaria_search_engine/blob/225a6d5d7265c478a64d3a609a536d0deed433e7/rust/src/api/library_indexing.rs)
- [line_source.rs — אינטראקציה עם SQLite ו־lineContent](https://github.com/Otzaria/otzaria_search_engine/blob/225a6d5d7265c478a64d3a609a536d0deed433e7/rust/src/line_source.rs)
- [MIT License](https://github.com/Otzaria/otzaria_search_engine/blob/225a6d5d7265c478a64d3a609a536d0deed433e7/LICENSE)

### ספריית הנתונים: SeforimLibrary

- [Database.sq — סכמה7 מלאה](https://github.com/Otzaria/SeforimLibrary/blob/344232b6c3e889be2bbf8a8f24f904d16dbef642/dao/src/commonMain/sqldelight/io/github/kdroidfilter/seforimlibrary/db/Database.sq)
- [AltTocStructureQueries.sq](https://github.com/Otzaria/SeforimLibrary/blob/344232b6c3e889be2bbf8a8f24f904d16dbef642/dao/src/commonMain/sqldelight/io/github/kdroidfilter/seforimlibrary/db/AltTocStructureQueries.sq)
- [AltTocEntryQueries.sq](https://github.com/Otzaria/SeforimLibrary/blob/344232b6c3e889be2bbf8a8f24f904d16dbef642/dao/src/commonMain/sqldelight/io/github/kdroidfilter/seforimlibrary/db/AltTocEntryQueries.sq)
- [BookVersionQueries.sq](https://github.com/Otzaria/SeforimLibrary/blob/344232b6c3e889be2bbf8a8f24f904d16dbef642/dao/src/commonMain/sqldelight/io/github/kdroidfilter/seforimlibrary/db/BookVersionQueries.sq)
- [TopicQueries.sq](https://github.com/Otzaria/SeforimLibrary/blob/344232b6c3e889be2bbf8a8f24f904d16dbef642/dao/src/commonMain/sqldelight/io/github/kdroidfilter/seforimlibrary/db/TopicQueries.sq)
- [LineRefQueries.sq](https://github.com/Otzaria/SeforimLibrary/blob/344232b6c3e889be2bbf8a8f24f904d16dbef642/dao/src/commonMain/sqldelight/io/github/kdroidfilter/seforimlibrary/db/LineRefQueries.sq)
- [LineDhQueries.sq](https://github.com/Otzaria/SeforimLibrary/blob/344232b6c3e889be2bbf8a8f24f904d16dbef642/dao/src/commonMain/sqldelight/io/github/kdroidfilter/seforimlibrary/db/LineDhQueries.sq)
- [LinkAnchorQueries.sq](https://github.com/Otzaria/SeforimLibrary/blob/344232b6c3e889be2bbf8a8f24f904d16dbef642/dao/src/commonMain/sqldelight/io/github/kdroidfilter/seforimlibrary/db/LinkAnchorQueries.sq)
- [LineAltTocQueries.sq](https://github.com/Otzaria/SeforimLibrary/blob/344232b6c3e889be2bbf8a8f24f904d16dbef642/dao/src/commonMain/sqldelight/io/github/kdroidfilter/seforimlibrary/db/LineAltTocQueries.sq)
- [AGPLv3 License + Section7 attribution](https://github.com/Otzaria/SeforimLibrary/blob/344232b6c3e889be2bbf8a8f24f904d16dbef642/LICENSE)

### Otzaria app (reference only)

- [Plugin SDK API — library.getBookMetadata/getBookAltToc/getLinks etc.](https://github.com/Otzaria/otzaria/blob/782f24b7899240f815cefc7bcccc423b20352c30/docs/plugin-sdk/API_REFERENCE.md)
- [Search documentation](https://github.com/Otzaria/otzaria/blob/782f24b7899240f815cefc7bcccc423b20352c30/docs/search_documentation.md)
- [Delta update plan](https://github.com/Otzaria/otzaria/blob/782f24b7899240f815cefc7bcccc423b20352c30/docs/seforim_library_delta_update_plan.md)
- [Personal Use License](https://github.com/Otzaria/otzaria/blob/782f24b7899240f815cefc7bcccc423b20352c30/LICENSE)
- [Updater Personal Use License](https://github.com/Otzaria/otzaria_library_updater/blob/79f340c887684cd9902efeb508bb4022d4afa8da/LICENSE)

### קבצי Maktabah שלנו

- [AGENTS.md](https://github.com/davidpovarsky/Maktabah/blob/59b01fa2d604facbcc3b3b1075a6283e7f1115db/AGENTS.md)
- [UPSTREAM_INTEGRITY_POLICY.md](https://github.com/davidpovarsky/Maktabah/blob/59b01fa2d604facbcc3b3b1075a6283e7f1115db/docs/architecture/UPSTREAM_INTEGRITY_POLICY.md)
- [UPSTREAM_EXCEPTION_REGISTER.json](https://github.com/davidpovarsky/Maktabah/blob/59b01fa2d604facbcc3b3b1075a6283e7f1115db/docs/architecture/UPSTREAM_EXCEPTION_REGISTER.json)
- [LibraryBackendProtocols.swift](https://github.com/davidpovarsky/Maktabah/blob/59b01fa2d604facbcc3b3b1075a6283e7f1115db/Source/LibraryBackend/LibraryBackendProtocols.swift)
- [BackendComposition.swift](https://github.com/davidpovarsky/Maktabah/blob/59b01fa2d604facbcc3b3b1075a6283e7f1115db/Source/LibraryBackend/BackendComposition.swift)
- [OtzariaGenericBackendAdapter.swift](https://github.com/davidpovarsky/Maktabah/blob/59b01fa2d604facbcc3b3b1075a6283e7f1115db/Source/Otzaria/Compatibility/OtzariaGenericBackendAdapter.swift)
- [OtzariaSchema.swift](https://github.com/davidpovarsky/Maktabah/blob/59b01fa2d604facbcc3b3b1075a6283e7f1115db/Source/Otzaria/Data/OtzariaSchema.swift)
- [OtzariaLineSourcesService.swift](https://github.com/davidpovarsky/Maktabah/blob/59b01fa2d604facbcc3b3b1075a6283e7f1115db/Source/Otzaria/Reading/OtzariaLineSourcesService.swift)
- [OtzariaTextSearchViewModel.swift](https://github.com/davidpovarsky/Maktabah/blob/59b01fa2d604facbcc3b3b1075a6283e7f1115db/Source/Otzaria/Search/OtzariaTextSearchViewModel.swift)
- [UnifiedSearchWorkspaceView.swift](https://github.com/davidpovarsky/Maktabah/blob/59b01fa2d604facbcc3b3b1075a6283e7f1115db/Source/ZayitSearch/UnifiedSearchWorkspaceView.swift)
- [Vendor README](https://github.com/davidpovarsky/Maktabah/blob/59b01fa2d604facbcc3b3b1075a6283e7f1115db/Vendor/OtzariaSearchEngine/README.md) — תיעוד ישן על GGUF שאינו תואם ל־upstream ONNX 7.0.1.
- [Xcode project](https://github.com/davidpovarsky/Maktabah/blob/59b01fa2d604facbcc3b3b1075a6283e7f1115db/Maktabah.xcodeproj/project.pbxproj): הפרויקט רושם קובצי Swift רבים באמצעות `PBXBuildFile`/`PBXFileReference`; `PBXFileSystemSynchronizedRootGroup` נמצא עבור UI tests בלבד, ולכן קובצי Source/Otzaria חדשים לא בהכרח מצורפים אוטומטית.

## 3. מזהי assets רשמיים — אך לא להוריד ללא הרשאת משאבים

| Asset | Size bytes | SHA-256 |
|---|---:|---|
| `seforim-schema7.db.zst` | `2034190634` | `9b1623035853f6d67f8553a953cf48de60643ece1bc6658e6a3fb80f379c47ba` |
| `patch-v32-v36.db.zst` | `340954875` | `a792e0669db19630adc220e40d5abb3f1a03e4e2eb7070089f85197f015bd76d` |
| `otzaria-library-index.tar.zst` | `1982417250` | `6b64d73174ee899631d99e01053effdc2712cdebabe472b43c835f4b5dc86a26` |

**אין להסיק מה־SHA שאותו נתון מתאים לחבילות downstream.** ההתקנה צריכה לבדוק manifest משלה ו־index schema10; לא להוריד index כלשהו רק כי שמו מכיל Otzaria. יש לוודא v36 עדיין release שנבחר בעת ביצוע בפועל עם מדיניות pin/הסכמת owner.

## 4. בדיקת רישוי — רמת ביטחון וכלל מעשי

1. **Rust search engine**: רישיון MIT מאומת בקובץ `LICENSE` של גרסת המקור. מותר לשלב לפי תנאי MIT, כולל שמירת הודעת זכויות/רישיון וכל תלויותיהן. בדוק dependency license notices ותנאי assets separately.
2. **Otzaria app Flutter/Dart**: רישיון current Personal Use License. מתיר שימוש פרטי באדם טבעי בלבד, לא הפצה ציבורית/שימוש בארגון ללא רשות בכתב. קוד זה אינו מועמד להעתקה בתוך ChavrusaText הציבורית. קיים סעיף prior versions: זכויות רישיון GPL-3.0 שהוענקו על גרסאות קודמות אינן מתבטלות; **יש להוכיח מקור commit ומועד קבלת העותק/רישיון** לפני הסתמכות עליהן. שימוש בתיעוד הסכמה כעובדות שונה מהעתקת קוד מוגן.
3. **Updater Dart**: אותו סוג Personal Use License. אין לעשות vendor של קוד Dart/port line-by-line במישרין ללא רשות מתאימה. native Swift updater עצמאי על פי חוזה פורמט רשמי הוא העדפה טכנית, כפוף לבדיקת provenance.
4. **SeforimLibrary Kotlin DAO**: AGPLv3 + תנאי ייחוס Section7. אין לאסוף קוד מחייב לתוך אפליקציה בלי בדיקת התאימות/הפצה/ייחוס. עצם הנתונים/טקסטים **לא** מכוסים אוטומטית ברישיון זה; נדרשת בדיקת הרשאות/מקור העתק של הספרים בפועל.
5. **Maktabah repo**: קוד Maktabah/ChavrusaText כיום כולל GPLv3 בריפו. שילוב code packages אחרים דורש לוודא התאימות ואת חובות הפצת קוד מקור, הודעות ושינויים; אין כאן ייעוץ משפטי.
6. **מילוני Otzaria**: `dictionary.json`, `Acronyms.json` ו־`lexical.db` אינם מתרשמים אוטומטית מהרישיון MIT של המנוע; לכל אחד נדרש owner/source/license/provenance. הסקריפט הקיים `sync-otzaria-search-upstream.py` **מושך assets מן אפליקציית Otzaria בעלת הרישיון האישי** — חיבורו האוטומטי ללא audit הוא הפרת שער הרישוי.
7. **טסטפלייט ו־App Store**: גם בטא היא הפצה לאנשים אחרים; אין להניח שהיא בגדר שימוש פרטי, וללא אישור owner/rights לא לבצע upload.

## 5. אבחנות שהן סיכון ולא עובדת התנהגות על מכשיר

- ניתן להצביע על fabricated line locator מפורש בקוד (`content.id + offset`). לא בוצעה בדיקה האם המשתמש נתקל בו בספר מסוים בפועל.
- ניתן להצביע על `enginePage` last page מול `results` accumulated, ועל `UnifiedSearchWorkspaceView` שמחפש metadata לפי offset. לא בוצע test על v36 כרגע, ולכן מבחן 101+ חובה.
- ניתן להצביע על `.sefariaEmbedded` guard שקיים מחוץ לענף ועל בדיקה `.sefaria` בפנים. יש לספק regression test, לא להבטיח שהוא קורה לכל משתמש.
- כל דיווחי Asana הם snapshots של task status, לא הוכחה שהתקלות ממשיכות על HEAD בזמן ביצוע.
- engine v7.0.1 `semantic` ONNX backend desktop-only במקור; אין לספק מצג של semantic ready במכשירי iOS.
- אומדן ביצועים של 11.89GB, 7030 ספרים, line FTS5 ומיקומי `C:\Users\DAVID\...` במסמכי הגדרות ישנים **אינו מקור אמת ל־v36**. אין להעתיק מספרי ספרים, אינדקסים או שמות טבלאות ישנים לתוך הקוד החדש ללא runtime/provenance.

## 6. Asana — קריאה בלבד

Project gid: `1219602719070493`, 34 tasks שהוחזרו ב־`get_tasks` בסריקת 2026-11-04. נשארים OPEN בזמן הסריקה, בין היתר:
- `1219602829298459` — fabricated line locators.
- `1219602829324283` — search metadata Load More.
- `1219602829324347` — stable hit IDs.
- `1219602987688876` — inspector SQLite N+1/MainActor.
- `1219613714504405` — PERF-01 lazy reading.
- `1219613714507780` — PERF-02 concurrency/cancellation.
- `1219613651433098` — PERF-03 huge chapters.
- `1219682272017128` — install DB independent of index.
- `1219674938327411` — old production v32 index.
- `1220120627071765` — slider level paragraph not auto-selected.
- `1219613602997169` — physical iPad performance QA.

הסוכן צריך להשתמש בהם כרשימת בדיקות ותלויות בלבד, ולא לעדכן אותם ללא בקשה מפורשת של בעל הפרויקט לאשר סנכרון/עדכון. צריך לבדוק תוצאות ממשיות לפני כל סימון `DONE` עתידי.

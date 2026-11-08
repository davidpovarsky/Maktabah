# מפרט טכני מחייב — הרחבת אוצריא ב־ChavrusaText

**Source baseline:** `Maktabah@59b01fa2d604facbcc3b3b1075a6283e7f1115db`  
**Otzaria DB reference:** `SeforimLibrary@344232b6c3e889be2bbf8a8f24f904d16dbef642`, release v36 schema7.  
**Otzaria engine reference:** `otzaria_search_engine@225a6d5d7265c478a64d3a609a536d0deed433e7`, v7.0.1 schema10.

## A. הארכיטקטורה המדויקת שיש לשמר

```text
Existing Maktabah / ChavrusaText Native SwiftUI & UIKit screens
    Library, Reader, Search, TOC, Authors, History, Book Info, Inspector, Notes
           |
           v
   BackendCoordinator (single authority; generation, switching, cancellation)
           |
           +---- LibraryCatalogProviding / LibraryTextProviding
           +---- LibraryNavigationProviding / LibraryMetadataProviding
           +---- LibrarySearchProviding / LibraryRelationshipsProviding
           +---- LibraryWorkMetadataProviding / optional native extensions
           |
       +---+-----------------------------+------------------------------+
       |                                 |                              |
       v                                 v                              v
 Otzaria backend                  Sefaria legacy                 Sefaria Embedded
 existing Maktabah data path      Swift hybrid                   original RN/Hermes
 native Swift SQLite             offline/remote                 headless data RPC
       |                                                               |
       +-- Extended downstream Swift SQLite providers                         |
       +-- Existing OtzariaMaktabahBridge and ReadingUnitService              |
       +-- Rust 7.0.1 Tantivy pinned via downstream thin C ABI                |
       +-- Managed DB installer + independently versioned search artifacts    |
       |                                                               |
       +------------------------- Neutral TextLocator and Library models ------+
```

### נתיב פרויקט Xcode וסיכון Target Membership

נבדק `Maktabah.xcodeproj/project.pbxproj` ב־HEAD הנוכחי: לקובצי ה־Swift קיימים `PBXBuildFile` ו־`PBXFileReference` מפורשים. `PBXFileSystemSynchronizedRootGroup` הקיים שייך ל־`Maktabah-iOSUITests`; אין ראיה ש־`Source/Otzaria` מתווספת אוטומטית ל־Compile Sources. **לכן** כל repository Swift חדש מחייב בדיקת membership, הצעת patch מוגדר ל־project.pbxproj ואישור בעלים על אותו hunk לפי מדיניות upstream. אי־אפשר לקרוא לתוצאה build complete עד שהקבצים משולבים במטרה ונבדקו. אין לשנות את Xcode project באופן מוסווה או להכניס קוד לפאץ' protected ישן כדי לעקוף את החובה.

### חוזים שמוחזרים — מה לא לשבור

1. `TextLocator(backend: BackendID, workKey: String, position: TextPosition)` נשאר המזהה הרשמי לשמירה. מבנה `persistenceKey` נשאר `backend|workKey|position`; `.legacyLine(lineIndex)` לאוצריא, `.canonicalRef(...)` לספריא. לעולם אין המרה אוטומטית של content PK ל־lineIndex.
2. `LibraryReaderDestination(sectionLocator,focusLocator)` מבדיל בין יחידת תצוגה לבין שורת הדגשה. חייב לשמור זאת ב־TOC ובחיפוש.
3. `LibraryTextSection(locator,displayRef,heRef,segments,previous,next,versions,links,origin)` הוא מודל תצוגה, לא כלי להחלפת גרסה שקטה.
4. `BackendCoordinator` הוא owner של backend generation, cancellations, transition prepare/publish. לא לשמור cache בסינגלטון שלא קשור ל־generation או ל־`OtzariaDatabaseAccessController`.
5. `MaktabahBackendAdapter.usesGenericModels` מבוסס `!usesNativeMaktabahDataPath`. האמת לגבי אוצריא כיום: `true` למסלול המקורי. שינוי ל־false עלול לשכתב ספרייה/כרטיסיות; אסור ללא החלטת owner נפרדת.
6. `SefariaBackend` ו־`SefariaMobileEmbeddedBackend` רשומים שניהם; הישארו כאמצעי חיפוש/קריאה שונים ולא merge ביניהם. `SefariaEmbeddedNativeSurfaceHost.renderFullUI` אינו רכיב להצגה שגרתית בממשק Swift-only — לבדוק call sites.

## B. אילו רכיבים ממש מתאימים להטמעה ישירה

| מקור | דרך אינטגרציה | למה לא דרך אחרת |
|---|---|---|
| `Otzaria/otzaria_search_engine` (Rust/Tantivy, MIT) | **כן: לקמפל מקור pinned ל־staticlib/ XCFramework, לקרוא דרך Swift C ABI** | משמר אלגוריתם חיפוש ואינדוקס מקוריים, בלי לשכפל עברית ב־Swift |
| `SeforimLibrary` data artifacts + מתווה DB/SQL schema | **כן: לקרוא DB רשמי ב־Swift SQLite וללמוד schema/queries מתועדים** | Kotlin DAO כרגע Android/JVM, והעתקתו חוסמת Swift runtime ומעלה ענייני AGPL |
| `Otzaria/otzaria_library_updater` Dart code | **לא להטמיע ללא רישיון וללא החלטת runtime**; בונים Swift Native updater עצמאי אם מאושר | Personal Use License, לא מתאים ל־Swift-only |
| `Otzaria/otzaria` Flutter UI/providers/plugin host | **לא**. Reference ל־API semantics, לא source-code dependency | אישור שימוש חסר, runtime/UI כפולים, ומנוגד לדרישת UI מקורי |
| Sefaria Mobile original JS | **להשאיר** את ההטמעה הקיימת headless לנתונים | אל תחליף ל־Swift custom engine, תחזוקה עתידית נשמרת |
| Otzaria repo `dictionary.json/Acronyms.json` | **רק אם זכות שימוש נבדקה**. לא למשוך sync חופשי מקוד Personal Use | כל asset עם תנאי הפצה עצמאיים; שחזור hash אינו רישיון |

## C. Backwards-compatible SQLite data layer

### C1. קובצי בסיס

- Existing: `Source/Otzaria/Core/OtzariaSQLiteConnection.swift`, `OtzariaDatabaseAccessController.swift`, `Source/Otzaria/Data/OtzariaSchema.swift`, `OtzariaBookSchemaCompatibility.swift`, `OtzariaSQLiteBookTextRepository.swift`, `OtzariaSQLiteLibraryRepository.swift`.
- New recommended: `Source/Otzaria/Data/OtzariaSchemaAwareReadContext.swift`; repository-ים קטנים עצמאיים לפי תחום: versions, topics, metadata enrichment, alt TOC, RefKey, link anchor, inline decorations.
- `OtzariaDatabaseCapabilities` הוא source-of-truth ב־runtime, **לא** המספר `db_schema_version` לבדו; עבור DB חיצוני/מיני עשויים להיות טבלאות חלקיות.

**הנחיות ביצוע SQL**: השתמש רק ב־prepared statements ו־`?` עבור ערכי משתמש; dynamic SQL רק עבור identifiers קבועים אחרי capability probe. SELECT read-only, transaction snapshot קצרת־טווח, `Task.checkCancellation()` בין batch-ים, bounded `LIMIT` או iteration lazy, אין קבצי DB מלאים בזיכרון. הימנע מ־`SELECT *` במודלים שאין להם schema stable, השתמש בפרויקציה עם optional columns. Cache לפי `dbIdentity + schemaMetadata + generation`, וביטול cache במעבר DB/switch.

### C2. זיהוי ו־SQL עצמאי (צורות שאילתה, לא העתקת קוד)

**ספר, מחברים, מקור:** `book JOIN source LEFT`, `book_author JOIN author`, `category` עם `parentId` היררכי. `book.id` נשמר מאותו DB; מזהי קטלוג Sefaria נשארים namespace אחר.

**נושאים לפי ספר — לא לפי שורה:**

```sql
SELECT t.id, t.name
FROM book_topic AS bt
JOIN topic AS t ON t.id = bt.topicId
WHERE bt.bookId = ?
ORDER BY t.name, t.id;
```

ייצוג: `LibraryRelatedTopic(slug: "otzaria-topic:<id>", titleHe: name, titleEn: nil)` בהעדר תרגום רשמי. כשמבקשים נושאים על locator של שורה, פענח workKey ל־bookId ואז החזר נושאי הספר; אל תנסה להמציא topic עוגן לפי lineIndex. ה־Swift coordinator כבר מאפשר `topics(for:)`.

**מקומות/תאריכי פרסום:**

```sql
SELECT p.name FROM book_pub_place bp
JOIN pub_place p ON p.id = bp.pubPlaceId
WHERE bp.bookId = ? ORDER BY p.name;
SELECT d.date FROM book_pub_date bd
JOIN pub_date d ON d.id = bd.pubDateId
WHERE bd.bookId = ? ORDER BY d.date;
```

**ספר בסיס/תלוי:**

```sql
SELECT b.id, b.title FROM book_base_text r
JOIN book b ON b.id = r.baseBookId
WHERE r.bookId = ? ORDER BY b.orderIndex, b.title;
```

לספרים התלויים בבסיס: `WHERE r.baseBookId = ?` וחיבור ל־`r.bookId`. להחזיר `TextLocator` נפרד לכל ספר ולא לזהות על סמך כותרת בלבד.

**מפרשים ותרגומים ברירת מחדל:** `default_commentator` לפי `bookId` ו־`position`, `commentatorBookId` בשימוש ID; `default_targum` באותה לוגיקה. הגדרות display order מקוריות, ללא סידור אלפביתי במקום position.

**ראשי תיבות של כותרת:** `book_acronym(bookId,term)`. בצע enrichment של book search filters; אל תיצור זהות ספר מזהה של ראשי תיבות, כדי לא לקשור ספרים בעלי שם דומה.

**מטא־דאטה**: `LibraryWorkMetadata.factualFields`: הוסף `publicationPlaces`,`publicationDates`,`baseTexts`,`dependentBooks`,`collectiveTitle`,`dependenceType`, בשפה אמיתית בלבד. ספר עם metadata ישן מציג את השדות שכבר זמינים. אין `nil`-stripping שגורם להחלפת הכותרת/מחבר.

### C3. TOC רגיל וחלופי

`LibraryNavigationProviding.navigationStructures(for:)` כבר קיים; `BookTOCViewModel.loadTOC` כבר משתמש ב־`BackendCoordinator.navigationStructures`, `selectStructure(id:)` לא דורש חידוש UI.

1. `default` ימשיך להשתמש ב־`getTOCEntries(for:)` וב־`line` המקוריים. תן `id="default"`, כותרת עברית לפי `LibraryPresentationPolicy`.
2. אם `hasAlternateTOC`, query:

```sql
SELECT id, key, title, heTitle
FROM alt_toc_structure
WHERE bookId = ? ORDER BY key;
```

3. עבור כל structure נטען `alt_toc_entry` + `tocText` + `LEFT JOIN line l ON l.id = e.lineId AND l.bookId = ?`, כך ש־locator = **`l.lineIndex`**. ודא ש־`structureId` שייך לספר לפני שאילתת children:

```sql
SELECT e.id, e.parentId, tt.text, e.level, e.lineId, l.lineIndex
FROM alt_toc_entry e
JOIN tocText tt ON tt.id = e.textId
LEFT JOIN line l ON l.id = e.lineId AND l.bookId = ?
WHERE e.structureId = ?;
```

4. ילד מצביע להורה דרך `parentId`. בנה Tree O(n) (`Dictionary<Int, [Row]>`), סנן cycles, orphan heads מפורשים ומקם headers עם no direct line באמצעות anchor ראשון של descendant אמיתי **רק אם מוכח אותו ספר ומבנה**.
5. `line_alt_toc(lineId,structureId,altTocEntryId)` הוא index לשיוך נוכחי. להשתמש בו כדי להדגיש current node במבנה נבחר; אין לייחס `altTocEntryID` לערך `lineIndex`.
6. להגן מפני עץ גדול ו־O(n²) string concatenation, לבצע טעינה lazy וביטול async.

### C4. הפניות ודיבורי המתחיל

- `line_ref(bookId,refKeyHash,lineIndex)` (לרוב WITHOUT ROWID) הוא index למראה מקום תקני. `refKeyHash` = FNV-1a 64 של normalized RefKey, **לא** פשוט hash של הקלט העברי: צריך תאימות מלאה ל־`core/src/commonMain/kotlin/.../refs/RefKey.kt` כאשר הרישיון מאפשר שימוש בידע/המימוש העצמאי, בדיקת fixtures זהות; אחרת להשאיר fallback TOC ולא להפעיל קפיצות לא מבוססות.
- `line_dh(bookId,dhText,lineIndex,dhDisplay)` מאפשר autocomplete בדיבורי המתחיל. התאמת normalized prefix בעזרת `dhText >= ? AND dhText < ?` על index, לא `LIKE '%x%'` לאינדקס כולו, עם cap לרשימת תוצאות. `dhDisplay` בלבד לתצוגה, `lineIndex` בלבד לניווט.
- טיפול `line.heRef` הוא תצוגה של מקור, לא מזהה אחד־לאחד בהכרח. בחר stable lineIndex after DB verification.

### C5. גרסאות טקסט ודקדוק חוסר נתונים

```sql
SELECT id, versionTitle, heVersionTitle, versionSource,
       priority, license, versionNotes, heVersionNotes, hasContent
FROM book_version
WHERE bookId = ?
ORDER BY priority DESC, versionTitle, id;
```

מפה למטא־דאטה הקיים; אם `TextVersionMetadata` אינו מכיל `id`, הצע `OtzariaVersionIdentity` ייעודי במודול downstream, ולא לשנות persisted `TextLocator`. לצורך טעינת מהדורה:

```sql
SELECT l.id, l.lineIndex, l.heRef, v.content, v.charCount
FROM line l
LEFT JOIN version_line v
  ON v.lineId = l.id AND v.versionId = ?
WHERE l.bookId = ? AND l.lineIndex BETWEEN ? AND ?
ORDER BY l.lineIndex;
```

- כניסה `versionId` חייבת להימצא ב־`book_version` עם `bookId=?`, לפני קריאה.
- **LEFT JOIN v.content=NULL איננו fallback**: פירושו שאין שורה במהדורה; להחזיר segment חסר או omission שניתן להבחין בו, לעולם לא `line.content` באותו segment כטקסט גרסה.
- אל תציג את `OtzariaInspectorDocumentMapper` עם "Otzaria local library" כגרסה עובדת; metadata אמיתי נשלף מה־provider. אל תגרום להחלפת default merged reader בלי המשתמש.
- עבור heading lines התנהגות נפרדת לפי design, כי `version_line` כולל רק שורות גוף.
- `versionSource` מותנה במקור URL תקין, לא כל מחרוזת היא URL.

### C6. קשרים ו־anchors במרחב תווים

ה־canonical implementation הוא `Source/Otzaria/Reading/OtzariaLineSourcesService.swift` המכיר source/target, `link_coverage`, `link_suppressed_side` ו־`link_range`. אל תחליף אותו במסלול `OtzariaSQLiteSourceRepository.swift` פשוט יותר. בדוק parity של SQL הנוכחי ל־schema7 באמצעות fixtures.

`link_anchor(linkId,side,charStart,charEnd,label)` אומר:
- side 0 = source side; side 1 = target side; `charStart` ו־`charEnd` ב־visible-character offsets של הטקסט המקורי, לא בהכרח `String.Index`/NSRange.
- `link_anchor` של link ranged שייך ל־anchor FIRST line, לא לכל שורת coverage. יש ל־join ל־matched source/target anchor line only.
- Schema7 `line_note(charPos,body)` שומר offset של גוף הערה גם כאשר גוף ההערה הוצא מטקסט השורה — אי אפשר להציג highlight במיקום `charStart` ישירות על attributed HTML אחרי footnote extraction.
- צור `OtzariaSourceToDisplayRangeMap` שמקבל `lineId`, מקור raw/rendered, `HTML` transformations, footnote presence, Unicode codepoints / composed chars / RTL; מחזיר valid UTF16 NSRange (source-index->display) או `unmapped`.
- במצב `unmapped` מציגים connection בלי צבע על מילה. עדיף עוגן כללי עובד על highlight שגוי.
- `LibraryRelatedSource` מכיל `anchorRefs: [String]` ולא typed range. אין להדביק char offsets לתוך `anchorRefs` בתור מראה מקום. השתמש ב־downstream sidecar `OtzariaLinkedAnchorSpan` לתצוגה; upstream view hook only after approval.

### C7. שאר סכמה 7

טבלאות ב־SeforimLibrary: `line_note`, `line_divine_name`, `line_note_divine_name`, `book_banner`, `banner`, `book_protection`, `line_content/zstd_dict` כאשר מסד נושא מבנה דחוס; `schema_meta(db_version/db_schema_version/content_hash)`.

- `line_note` הערת שוליים של המהדורה, שונה לגמרי מ־Maktabah personal annotations.
- `line_divine_name` ו־`line_note_divine_name` מייצגות מקומות שמות קודש במרחב של הטקסט המאוחסן; שדה packed `span` נושא סוג/מקור/אורך. רינדור שגוי אסור; קודם test fixture מאומת.
- `book_protection` חייב להתפרש לפי חוזה הזכויות, אין לעשות export/copy/print בניגוד להרשאות. עד הבהרת סמל semantics, `unsupported` ב־UI/יצוא ולא שבר מודל הקריאה.
- אחסן queries כ־read-only bounded; לא להעביר מעל MainActor פענוח zstd, JSON/HTML או טבלאות שלמות.

## D. מנוע החיפוש Rust — תכנון ABI ושמירת parity

### D1. source & build

Current: pinned old upstream `265a14ea54f959a3e266d6e8acfa3a3b98101d68` in `Vendor/OtzariaSearchEngine/Upstream/UPSTREAM_COMMIT`; `ios_bridge/Cargo.toml`, `ios_bridge/src/lib.rs`, `include/*.h`, `OtzariaSearchEngineBridge.swift`. These are a C/JSON adapter around native Rust — **this is already direct code reuse**.

Target: exact pinned `225a6d5d7265c478a64d3a609a536d0deed433e7` engine 7.0.1; upstream `rust/Cargo.toml` feature model `sqlite-bundled` or `sqlite-host` exactly one. Swift app no Dart SQLite host ⇒ choose `sqlite-bundled` in downstream bridge, verify only one SQLite instance used by engine; app Swift SQLite remains distinct read-only connection layer (separate library handles okay only with proper locking). Compiler/Cargo.lock resolves from exact sources.

### D2. ABI contract for bridge upgrade

**Existing symbols** from `include/otzaria_search_engine.h` to preserve when their semantics still apply:
`_new`, `_new_with_error`, `_last_init_error`, `_free`, `_search_json`, `_book_counts_json`, `_facet_counts_json`, `_add_text_book_json`, `_add_pdf_book_json`, `_set_bulk_indexing`, `_clear`, `_commit`, `_rollback`, `_optimize`, `_document_count`, `_indexed_file_paths`, `_book_fingerprints`, `_delete_file_paths_json`, `_check_compatibility`, `_build_info`, `_set_dictionaries_json`, `_helper_json`, `_semantic_json`, `_free_string`.

**New optional bridge symbols (only after upstream Rust API compiles and tests):**
- `otzaria_search_engine_configure_library_source_json`: hand database path/read policy to upstream `library_line_source` API, if supported.
- `otzaria_search_engine_add_library_books_json`: feed `LibraryBookInput` batches to `SearchEngine::add_library_books` using canonical `filePath` `id:<bookId>`, transaction checkpoints and cancellation.
- `otzaria_search_engine_cancel_lexical_request`: id-tagged cancel handle that bypasses engine queue, if equivalent Rust callable available safely.
- `otzaria_search_engine_search_snapshot_json`, `otzaria_search_engine_release_memory`.

**Important**: these names are *proposed downstream C ABI names*, **not** claims that upstream publishes such C functions. Implement only with verified upstream exact Rust functions, and document any feature that is not exported. Do not fabricate `SemanticSearch` availability. No source patch to upstream Rust.

V7 Rust `API_DOCUMENTATION.md` exposes `searchAndCount`, `searchAdvanced`, `searchFuzzy`, `searchExact`, `searchStream`, `addLibraryBooks` and line-source registration, cancellation/snapshot/memory. The bridge must map its internal Rust `SearchPageResult` to existing `OtzariaSearchPage` with stable result id/path/reference, truncated/total. `SearchResultItem` mapper must not use `bookId=0` when filePath missing: fail/missing source signal and source fallback only if validated against book identity.

### D3. ABI and life-cycle tests

- C header vs Swift declarations vs Rust exports: `python3 Vendor/OtzariaSearchEngine/Scripts/verify-api-parity.py`.
- Rust `cargo check --locked`, `cargo test --locked`, `cargo build --release --locked` in bridge, plus actual Apple slice builds only with separate build authorization/macOS. If external dependency compilation breaks, record exact function/feature and adapt *downstream bridge*, not modify pristine Rust checkout.
- Panic boundary/error JSON, Unicode Hebrew, quotes, malformed JSON, null pointer, double-free prevention, concurrent search/cancel, dictionary absence/rights, mismatched index schema4→v10, snapshot invalidated by DB replace, stale search result after switch.
- Search parity fixture: exact / fuzzy / advanced / proximity/word order / negative / category facets / ordering / per-book counts / stable IDs / highlight HTML boundaries / >100 hits / no stale loaded index.

### D4. Search index & data files alignment

**Index identity** = engine commit+engine version+index schema+data release identity + database version and content hash + resources hashes + corpus/catalogue hash + profile ID/version + index composition + runtime tests. File size/time alone is *not enough* for correctness when contents change in place (may remain auxiliary quick check). Existing canonical manifest already stores much of this.

Use existing `OtzariaSearchIndexManager` for atomic `.building`/`.previous` promotion, `OtzariaSearchArtifactPolicy` for SHA and manifest, `OtzariaSearchArtifactReleaseClient` for pinned downstream release discovery. Each search index must be built with same engine schema v10; don't use v32 index against v36 DB. If official v36 release includes `otzaria-library-index.tar.zst`, **do not assume** it equals the format or artifact contract our Swift installer supports; content trust and schema compatibility require separate test.

**Profile parity**: test miniTest10 should exercise identical native SQL+Rust code, only replace corpus size and artifact identity. Index rebuild on device for all ~large corpus is performance-expensive: prefer signed/pinned prebuilt if CI and owner allow. Until then reading stays available with search status `notInstalled / incompatible / installing`, without lying about download being complete.

## E. Database release bootstrap/update with no data loss

### E1. Release v36 actual asset names

At 2026-11-04 latest release `Otzaria/SeforimLibrary/releases/tag/v36-20261101064231` contains:
- `seforim-schema7.db.zst`, compressed size **2,034,190,634 bytes**, SHA-256 `9b1623035853f6d67f8553a953cf48de60643ece1bc6658e6a3fb80f379c47ba`.
- `patch-v32-v36.db.zst`, compressed size **340,954,875 bytes**, SHA-256 `a792e0669db19630adc220e40d5abb3f1a03e4e2eb7070089f85197f015bd76d`.
- `otzaria-library-index.tar.zst`, compressed size **1,982,417,250 bytes**, SHA-256 `6b64d73174ee899631d99e01053effdc2712cdebabe472b43c835f4b5dc86a26`.
- Release assets include manifests/provenance, versions and hashes; re-verify latest release at actual build time (pins in this plan are reference snapshot, not moving build dependencies).

Current `OtzariaLibraryRelease.isProductionDatabaseAssetName` recognizes `seforim-schemaN.db.zst` already. Do not hardcode `seforim.db.zst` as sole filename. Make release selection exact and reject assets not described in manifest or with wrong compressed digest.

### E2. Managed bootstrap independent of search

- Keep `OtzariaDatabaseBootstrapService`, `OtzariaDatabaseDownloader`, `OtzariaDatabaseInstaller`, `OtzariaDatabaseDownloadPolicy`, `OtzariaDatabaseAccessController`, `OtzariaSearchArtifactService` intact. DB success must be independent from index status.
- Resume requires stable URL/release asset id/content length/digest/ETag; incorrect Range response starts clean, no append garbage.
- Validate compressed sha, zstd frame, decompressed SQLite quick/integrity check, required tables, schema_meta; install via staging and atomic swap; retain previous DB until validation + release of old connections; rollback on crash/power outage.
- A selected external DB must not be moved, rewritten or substituted behind user bookmark. No full scan on MainActor.

### E3. Optional future native delta updater — **not required for first implementation without owner approval**

If specifically enabled later, implement Swift `Source/Otzaria/Updates/*`:
1. Discovery GitHub asset and paired `patch-vX-vY.db.zst.manifest.json`, direct edge or chain graph; reject no path. Pin exact source/target version/schema.
2. Check compressed asset digest, manifest typed fields, boundaries, expected amount, free space, patch SQLite `integrity_check` and table whitelist. Reject malformed/null/missing/huge/partial patches.
3. Read `schema_meta.db_version`,`db_schema_version`; compute **identical logical content hash** from official contract, compare `fromContentHash`; if no verified cross-language implementation = fail closed to full DB download, not pretend `file SHA` equivalent.
4. Create `staging` DB copy at secure path, exclusive updater lock, cancellation checkpoints and interruption marker; apply `DELETE`/`UPSERT` in approved order and transaction. **Never `INSERT OR REPLACE`** on cascading FKs.
5. Validate `toContentHash`, target schema and `PRAGMA foreign_key_check/integrity_check`, then swap atomically, keeping rollback; bump database generation, close/refetch caches.
6. Search index lives in separate versioned namespace and must be refreshed independently; never claim indexed until new compatible asset ready.
7. If precondition invalid — show full DB fallback, don't corrupt existing library.

## F. Coverage map — מודול/טבלה/מצב

| Capability | Existing support | Addition / acceptance |
|---|---|---|
| Categories / books / authors | native SQLite bridge, strong | enrich metadata + source identity, no duplicate tree |
| Line content | native reading-unit service | exact anchors, bounded lazy, HTML/source range mapping |
| TOC normal | existing | stable actual lineIndex, no fake content id |
| Alternate TOC | generic API already; Otzaria missing | alt structure / entries / line_alt_toc |
| Topics | protocol exists; Otzaria returns [] | book_topic + topic under book scope |
| Versions metadata | protocol exists, Otzaria `metadata:nil` | `book_version`, no dummy editions |
| Version text | generic models don't select editions | optional versioned provider, no merged fallback, UI hook gated |
| Publication | limited | pub_place/pub_date joins with safe missing table handling |
| Base/dependence | partial classification | book_base_text, defaults, collective title |
| Dibbur hamatchil | missing | optional index-based search under real line locators |
| Canonical refs | partial | RefKey/index fixture-based, no guessed hash |
| Links | rich native service | char anchors after Unicode/note mapping, preserve visibility |
| Inline footnotes | schema7 missing | read-only, decode, no personal note coupling |
| Divine names | schema7 missing | no guessed substitution; licensed/tested exact display rules |
| Book protections | schema7 missing | fail closed on restricted output/actions |
| Full-text | pinned older Rust direct | Rust v7 pinned, C ABI compile parity, schema10 index |
| Hebrew morphology | upstream Rust old | use upstream v7 implementations, NO Swift rewrite |
| Semantic search | old wrapper placeholders | mobile inference unsupported upstream; mark unavailable |
| Offline DB | managed installer present | v36 asset selection, integrity, independent search index |
| Delta update | not first-class native | separate optional Swift updater with logical hash and rollback |
| User books / attached DB | upstream Otzaria offers | deferred: distinct identity `uid:`/`db:` + permission/security review; no silent data mixing |
| PDF, DOCX, EPUB, plugin SDK | upstream Otzaria offers | out of current parity phase; separate access/UX/legal and file readers required |

## G. Integration policy and protected hooks

The plan does **not** authorize modifications to Maktabah source. If user-visible version-selection, inline anchoring, note rendering, or navigational auto-follow **cannot** be achieved using a fork-owned provider/host and an existing injection point, the coding agent must:

1. Complete functional provider in `Source/Otzaria` and optional capabilities in `Source/LibraryBackend` where downstream lineage confirmed.
2. Write a single minimal proposed patch for exact protected source file and hunk; identify two rejected alternative call sites, proof of necessity, Git SHA, test scope and rollback.
3. Set `BLOCKED_OWNER_APPROVAL`, leave original source untouched. Never mark UI-visible capability DONE when the hook is absent.
4. Keep existing Reader and the two Sefaria paths fully working with no regressions.

Do not fix historical upstream-divergent code in passing. Source provenance and owner authorization are part of technical correctness.

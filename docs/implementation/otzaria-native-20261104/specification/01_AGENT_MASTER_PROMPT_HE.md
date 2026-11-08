# משימת ביצוע מחייבת לסוכן קוד — ChavrusaText/Otzaria Direct Integration

> **הוראת ביצוע**: אתה סוכן קוד שעובד בריפו `davidpovarsky/Maktabah`. עליך ליישם את ההרחבה הנקובה כאן **באותו ענף פיתוח חדש מבודד**, מתוך ענף הבסיס המאומת; להשתמש בכל קובצי החבילה כמפרט מחייב, ולהחזיר קוד, בדיקות ודו"ח אמת. אינך נדרש לבצע מחקר פתוח/לתכנן ארכיטקטורה חלופית: ההחלטות המהותיות, סדר העבודה ותנאי העצירה נקבעו כאן. זיהוי חתימות מדויקות של API בעת קומפילציה ובדיקת סביבת העבודה הם *בדיקות מימוש הכרחיות*, לא אישור לשנות את התכנון.

## 1. חותמות מקור, בסיס וקווי סמכות

- ריפו: `https://github.com/davidpovarsky/Maktabah`.
- **BASE**: `experiment/sefaria-mobile-original-embedded-20261029` ב־SHA `59b01fa2d604facbcc3b3b1075a6283e7f1115db` שנבדק ב־2026-11-04.
- צור ענף חדש מ־BASE בלבד: `feature/otzaria-native-capability-parity-20261104` (אם קיים, suffix ממוספר; **לא** force-reset). לא לכתוב לענף BASE, ל־`dev` או ל־`main`.
- Maktabah upstream ברגע הבדיקה: `bismillah-100/Maktabah/main@46e893c65139fbb1e582d6595b0d220ea912324a`. הפרויקט מחזיק pin קודם `a0ed0df908a6cb38bc459d4baaeb400f447b2fc4`. אלה אינם אותו commit; עקוב אחר provenance משניהם. **אין למזג upstream כחלק מהמשימה**.
- Otzaria app reference `Otzaria/otzaria/dev@782f24b7899240f815cefc7bcccc423b20352c30`.
- Otzaria Rust MIT `Otzaria/otzaria_search_engine/refactor@225a6d5d7265c478a64d3a609a536d0deed433e7` v7.0.1, schema 10.
- SeforimLibrary schema `Otzaria/SeforimLibrary/otzaria@344232b6c3e889be2bbf8a8f24f904d16dbef642` (release v36, schema7).
- Otzaria updater Dart reference `Otzaria/otzaria_library_updater/main@79f340c887684cd9902efeb508bb4022d4afa8da` **reference only, do not copy its code**.
- הגבלות סמכות: עבודת קוד downstream וקובצי בדיקות מקומיים יבוצעו; **לא** להריץ workflow ב־GitHub Actions, build/archive/IPA/TestFlight, פרסום release, מיזוג, push ציבורי/PR פרסומי, עריכת רשומות Asana או דליקה של assets עצומים ללא הרשאה ספציפית. תחום הפיתוח כרגע branch/commits local/בענף ניסוי המוגן כפי שהמערכת מאפשרת; דווח אם יש צורך בהרשאה נפרדת לפרסום ענף.

## 2. מסמכים שחובה לטעון לפני שינוי

קרא ופעל לפי `AGENTS.md`, `PROJECT_AGENT_GUIDANCE.md`, `docs/architecture/UPSTREAM_INTEGRITY_POLICY.md`, `docs/architecture/UPSTREAM_EXCEPTION_REGISTER.md` ו־`.json`, `docs/architecture/UPSTREAM_LEGACY_DEBT.md`, `docs/ai-team/TEAM.md`, `docs/ai-team/PROJECT_ASSIGNMENTS.md`, `docs/ai-team/ASANA_POLICY.md`, `docs/architecture/CHAVRUSATEXT_INTEGRATION_SEAMS.md`, `PROJECT_BOARD.md` ויתר קובצי חבילה זו. הכלל המחמיר של 2026-10-22 קודם להמלצות ישנות ל־"hook קטן" ללא אישור.

**טופולוגיה מחייבת**:
- UI: כל מסכי הספרייה, הקריאה, החיפוש, היסטוריה/מועדפים/הערות/Inspector נשארים ב־Maktabah SwiftUI/UIKit. לא ליצור אפליקציית Otzaria Flutter פנימית.
- חיבור: `Source/LibraryBackend/{BackendCoordinator,BackendComposition,LibraryBackendProtocols,LibraryBackendModels,MaktabahBackendAdapter}.swift` נשאר authority יחיד. **אין backend manager נוסף**.
- אוצריא: `Source/Otzaria/*` Native Swift SQLite, `Vendor/OtzariaSearchEngine/*` Rust MIT ב־pin + thin C ABI, `Source/Otzaria/Search/*` מופע יחיד של מנוע; אין מנוע חיפוש עברי חלופי. חובה להישאר במסלול `usesNativeMaktabahDataPath:true` בלי להפסיק את השימוש ב־`OtzariaMaktabahBridge`.
- Sefaria: `Source/Sefaria/*` + `Source/SefariaEmbedded/*` כולל Hermes ראשי בלבד לנתונים, ה־adapters ממשיכים לספק אותם מודלים. אין לגעת ב־`Vendor/SefariaMobile/Upstream`.
- Zayit / TorahInspectorKit: שומרים על hooks הנוכחיים, pins, search modes וזרימת הערות.

## 3. איסורי סיכון בלתי־מתפשרים

1. `Source/Core/*`, `Source/Features/*`, `Source/UI/*`, `Source/Extensions/*`, הקבצים המקוריים וה־`Maktabah.xcodeproj/project.pbxproj` — **READ-ONLY ברירת מחדל**. אפילו שורת שינוי אחת מחייבת **היתר בעלים ייעודי path+hunk**, שנרשם בפועל כמורשה (`owner_attestation`, `approval_ref`) במנגנון הפרויקט. אישורי Batch B היסטוריים שבסטטוס `OWNER_APPROVAL_REQUIRED` אינם אישור.
2. לכל קובץ ערוך: ציין provenance בעלות (`UPSTREAM_OWNED / DOWNSTREAM_OWNED / VENDORED_UPSTREAM / SHARED_SEAM / UNKNOWN`). `UNKNOWN` פירושו חסימה עד בדיקה; אין לנחש.
3. אל תערוך את מקור אוצריא המיובא ב־`Checkout`; שמור pin; גשר Rust ו־Swift הם downstream בלבד. אל תעתיק Flutter, Dart, Kodi/SQLDelight/AGPL Kotlin או assets שלא אושרה זכות השימוש שלהם.
4. אין החלפה/מחיקה של אוצריא production DB הקיים, אינדקסים, annotations, CloudKit, היסטוריה ומועדפים. אין מיגרציה הרסנית; כל החלפת קובץ כתוצאה מגרסה חדשה חייבת staging, validation, backup/rollback.
5. אין fallback שמציג מיקום מומצא, גרסת טקסט שלא קיימת, תוכן שהוחלף בטקסט של מהדורה אחרת, תוצאת חיפוש של ספר אחר, או רכיב "עובד" שלא אומת.
6. אסור להכפיל חיבורים/Mmap/index writers, לכבות cancellation או להסיר בדיקות כדי להשיג "ירוק".
7. לא לשנות `BackendID`, `TextLocator.persistenceKey` או מזהי workKey persistently בלי אסטרטגיית תאימות לאחור שנבדקה; לא לשנות נתיב Sefaria or Zayit שלא לצורך.
8. אין להריץ `sync-otzaria-search-upstream.py --latest` באופן עיוור; הגרסה חייבת להיות SHA מדויק ורישיונות assets נבדקים בנפרד.
9. אל תחשוף "semantic ONNX iOS ready" — במנוע הרשמי החדש inference backend מותקן ל־desktop בלבד; לא נדרש להביא GGUF/llama.cpp.
10. אין לסמן task ב־Asana כהושלם — ללא הוראה מפורשת ממני אין שום כתיבה לשם.

## 4. שער ביצוע 0 — קיבוע ואימות ללא מוטציה

- ודא `git status --porcelain` וריפו/ענף/HEAD; אם שינויים של משתמש אינם משויכים אליך, **אל תדרוס**. צור worktree/branch נפרד במיקום מאושר.
- שמור דו"ח baseline כולל remotes, מקורות upstream וה־merge base, submodules, `git diff --stat`, Xcode target membership, xcodebuild policies וה־CI triggers הקיימים. שימור מפתחות וסודות.
- בצע file provenance ואפיין שינויים לפי `03_FILE_OWNERSHIP_AND_CHANGE_MATRIX.csv`, `UPSTREAM_EXCEPTION_REGISTER.json` (הצעות ≠ אישורים). אם חייבים hook ב־upstream, הכן **patch proposal בלבד** + חלופה שבדקת + SHA + rollback, השאר BLOCKED_OWNER; המשך בכל downstream שאינו תלוי.
- **בדוק Target Membership לפני יצירת קובץ חדש:** ב־`Maktabah.xcodeproj/project.pbxproj` קיים רישום מפורש של קובצי `Source/Otzaria`, `Source/LibraryBackend`, `Source/SefariaEmbedded` ב־`PBXBuildFile`/`PBXFileReference`; `PBXFileSystemSynchronizedRootGroup` שזוהה בבדיקה משמש את `Maktabah-iOSUITests` בלבד. קבצים חדשים אינם נכללים אוטומטית במטרה הראשית. הכנס אותם ל־Compile Sources **רק עם אישור owner מדויק ל־project.pbxproj hunk**; אם אין אישור, הכנס קוד שניתן לבדוק בנפרד אך ציין `BLOCKED_PBX_MEMBERSHIP` ואל תצהיר שהשילוב מתקמפל. אל תעקוף זאת ב־build script חשאי.
- בצע audit `LICENSE` לכל מקור ו־asset; אל תחבר assets מה־Flutter או קוד updater Personal Use בלי זכויות מאומתות. אם distribution לא הותר, ניתן לממש רק ממקורות מורשים באופן שאינו מפיץ קוד מוגבל, ולסמן `BLOCKED_LEGAL_RELEASE`.
- בדוק שהסכמות הן read-only introspection ושקובצי testData מלאים אינם נדרסים; בצע smoke ב־miniTest10 עם DB fixture ו־SQLite mock במידת האפשר. אין להוריד 2+GB בהיעדר הרשאה.

תוצר gate0: `docs/implementation/otzaria-native-20261104/00-baseline-and-ownership.md` ו־`file-provenance.csv`. אם HEAD בסיס השתנה — השתמש בענף שנוצר מה־SHA המוגדר, או דווח חסימה; **לא** לסטות בדממה לגרסה אחרת.

## 5. שלב 1 — ייצוב מזהים, חיפוש ו־Inspector (P0)

### 1A. מזהי שורה קנוניים
- מקור: `Source/Otzaria/Compatibility/OtzariaGenericBackendAdapter.swift`, מתודה `section(at:)` fallback; אסור `content.id + offset` אם מפצלים טקסט לפי `\n`.
- הוסף `Source/Otzaria/Reading/OtzariaCanonicalLineLocatorResolver.swift` המבצע `bookId + lineIndex -> TextLocator(.otzaria, workKey:"book:<id>", .legacyLine(realLineIndex))` אחרי אימות `line` מול SQLite. `line.id` (PK) **אינו** `line.lineIndex`; אסור להחליף ביניהם.
- ב־`section(at:)` השתמש תחילה ב־`OtzariaReadingUnitService` עם `lineAnchors` אמיתיים, כפי שהקוד כבר מנסה. בנתיב fallback אם אין עוגני שורות אמיתיים: הצג כקטע בודד עם locator של השורה האמיתית, **או** חזור עם `invalidLocator` מנומק; אל תסנתז מיקום עבור כל פסקה. כתיבת מודל segment חייבת להיות id ייחודי לכל שורה, לא שני segments עם אותו locator.
- בדיקות: `line.id != lineIndex`, פסקאות מרובות בשורה אחת, רווחי שורות, כותרות בלי תוכן, forward/back, restoration, annotations, TOC clicks.

### 1B. תוצאות חיפוש ומטא־דאטה >100
- מקור: `Source/Otzaria/Search/OtzariaTextSearchViewModel.swift`: `.results` מצטבר אבל `.enginePage` משקף עמוד אחרון. `Source/ZayitSearch/UnifiedSearchWorkspaceView.swift` מפיק metadata לפי offset בין מערכי אורך שונה.
- במודול downstream `Source/Otzaria/Search/OtzariaSearchResultIdentityStore.swift` שמור **raw engine hit + display result + stable hit key** באותה רשומה לאורך כל pagination, לפי `(engine source identity,filePath,segment/lineIndex,hit identity,version if supplied)`; לא להסתמך על row index או title+page. הקפד על Swift Sendable/MVVM ותאימות לצרכנים הקיימים.
- `enginePage` יכול להישאר metadata של הדף האחרון, אך אל תתאים אותו מול כל `.results`. הוסף accessor של `allSearchHits` בקואורדינטור/VM והעבר meta לפי stable ID. ב־`UnifiedSearchWorkspaceView` (downstream!) השתמש באוסף הזוגות. בדוק גם `UnifiedSearchSessionController.swift:openResult` למסלול Zayit — ללא fallback עמום; אל תערוך Zayit אם מחייב אישור לא קשור אלא הצע patch ממוקד, וסמן regression פתוח.
- בדיקות: 0, 1, 100, 101, 210 hits; כותרות זהות; החלפת backend בזמן pagination; cancellation; חיפוש/קיבוץ/פילטרים; double tap results.

### 1C. Inspector multi-backend
- `Source/Otzaria/Reading/MaktabahTorahInspectorAdapter.swift:73-93` בודק שני סוגי Sefaria חיצונית, אבל בענף בחירת segment משתמש בבדיקה `.sefaria` יחידה. תקן רק את הבחנת הזהות כך שתכלול `.sefariaEmbedded` ללא המרת locator של אחד לשני.
- שמור `BackendCoordinator.generation`, per-backend caches, line-based selection, related links, notes and snippet fetcher off MainActor. לעולם לא לשייך `sefariaEmbedded` ל־`.sefaria` באופן שידרוס מפתחות persisted.

## 6. שלב 2 — יכולות DB עדכניות: feature detection והנחות אמת

- הרחב רק את `Source/Otzaria/Data/OtzariaSchema.swift` (downstream) באמצעות `OtzariaDatabaseCapabilities`: זיהוי טבלאות/עמודות נתמכות ללא כפיית schema7 לכל DB, כולל `line_note`, `line_note_divine_name`, `line_divine_name`, `book_banner`, `banner`, `book_protection`. `SQLite sqlite_master` + `PRAGMA table_info` עם read-only transaction; נתון שלא קיים מוצג unsupported, לא נשאבים null/עמודות לא קיימות.
- צור `Source/Otzaria/Data/OtzariaSchemaAwareReadContext.swift` סביב חיבורי SQLite הקיימים, ללא pool חדש: cache schema per `(database identity,generation)`, cancellation-safe, split `line_content`/`zstd_dict` backwards compatibility, bounded queries, author aggregation.
- שמור בחירה בין managed database ו־external security-scoped URL. למשתמש חיצוני אסור updater/index installer להחליף קובץ ללא הרשאה נפרדת.
- צור unit fixture DB עם **schema מינימלי וסכמה 7** וגירסת baseline עבור feature gating.

## 7. שלב 3 — TOC רגיל, TOC חלופי וניווט מקומי

- הוסף `Source/Otzaria/Navigation/OtzariaAlternativeTOCRepository.swift`: הרץ query על `alt_toc_structure WHERE bookId=? ORDER BY key`, ו־`alt_toc_entry JOIN tocText` לפי `structureId`, יחד עם `line.id/line.lineIndex` כמיקום אמיתי. בנה עץ לפי `parentId`, עם cycle/missing-parent guard; שמור רק nodes whose `lineId` maps to valid book line. אם קיים entry ללא line anchor ובעל children, היררכיה קיימת אבל node לא ניווטי, חפש descendant real first line; **אל תשתמש ב־alt_toc_entry.id כמיקום**.
- הוסף `Source/Otzaria/Navigation/OtzariaReferenceResolutionRepository.swift` לצורך `line_ref` (FNV1a+RefKey normalized לפי codec הבדוק); לא לנחש normalization ממילים, אם אין התאמה ל־test fixtures אל תפעיל חיפוש reference חדש. `line_dh` היא אינדקס חיפוש **דיבורי המתחיל**, לא TOC פיזי; display virtual nodes רק כאשר קיימת כתובת שורה מקורית.
- `OtzariaGenericBackendAdapter` יעקוף `navigationStructures(for:)` ויספק `[default, alternatives...]`. `BookTOCViewModel` כבר קורא ל־`BackendCoordinator.navigationStructures` ובוחר `selectedStructureID`: אין שינוי UI upstream נדרש.
- ודא ש־`line_alt_toc` משמש למעקב current-location בעץ הספציפי ושקליק על alt אינו קופץ לתחילת הספר. אם requires upstream hook ל־auto-follow, הגש proposal חסום ללא עריכה.
- tests ל־Genesis/פרשה, nested items, empty/missing schema, orphan parent, same-named entries, lineIndex gaps, TOC active following, Hebrew labels, slider unit choice.

## 8. שלב 4 — Metadata, Authors, Topics, Links

- הוסף `Source/Otzaria/Data/OtzariaWorkMetadataEnricher.swift`: הרחב את רשומת `LibraryWorkMetadata.factualFields` הקיימת בשדות *אמיתיים בלבד* (תאריך/מקום פרסום, מקורות, מחברים, `dependenceType`, `collectiveTitleHe`, `book_base_text`, `default_commentator`, `default_targum`, ראשי תיבות, הגדרות זכויות/הגנה). אל תמציא תרגום אנגלי; אפשרי שדות לפי schema.
- צור `Source/Otzaria/Data/OtzariaTopicsRepository.swift`: `topic JOIN book_topic` לפי work bookId; `LibraryRelatedTopic.slug="otzaria-topic:<id>"`, `titleHe=name`, `titleEn=nil` בהיעדר מקור אנגלי. `OtzariaInspectorRelationshipsProvider.topics` יחזיר זאת; אין עמדה ש־`book_topic` הוא יחס פר־שורה.
- הקשרים ממשיכים *להישען על `OtzariaLineSourcesService` הקיים* (כבר מכסה כיוונים, range, suppression), עם `OtzariaLinkAnchorRepository.swift` שמוסיף offsets רק לשורת ההתחלה ולצד הרלוונטי. אל תכניס anchors ל־coverage lines. הפוך positions של visible character space לטווחי UIKit UTF16 בעזרת מיפוי מקור→תצוגה, ומטא־דאטה של inline notes; אם יש חוסר מיפוי אמין הצג קשר בלי הדגשת מילה, לא מיקום שגוי. `OtzariaSQLiteSourceRepository` הוא מסלול אחר קטן יותר — אל תייצר duplicate link behavior.
- `related(to:)` דרך `LibraryMetadataProviding` יכול להיות mapped ל־`links` בלי העתקה, תוך שמירת התאימות ל־Sefaria.
- tests: commentary vs quotation vs lateral, duplicate links, 2,000 linked sources paged/async, line ranges, hidden sides, author title collisions, two sources same title, MainActor responsiveness.

## 9. שלב 5 — גרסאות טקסט (Versions) בלי פגיעה בנתיב הקריאה

- הוסף `Source/Otzaria/Data/OtzariaVersionsRepository.swift` מממש `LibraryMetadataProviding`: `versions(for workKey:)` על `book_version WHERE bookId=? ORDER BY priority DESC, versionTitle`, mapping ל־`TextVersionMetadata`. `sourceURL` רק אם URL תקין ומותר; הצג רישיון מהטבלה. `related(to:)` ממפה את provider הקיים.
- רשום ב־`BackendComposition.swift` `metadata:OtzariaVersionsRepository` + capability `.versions` **רק לאחר** אימות schema ו־queries. `versions` כשהטבלה נעדרת ⇒ `[]` + structured capability unavailable, לא "גרסה אחת" מומצאת.
- `OtzariaVersionedContentRepository.swift` קורא `version_line` באמצעות JOIN ל־`line` בהינתן versionId מתוך `book_version` *של אותו book*. אם שורת version חסרה = קטע חסר; אל תיפול לטקסט המאוחד. שורת heading מטופלת בנפרד בהתאם לסכמה. default reader **תמיד** הטקסט המאוחד עד בחירה מפורשת ומחייבת מזהה גרסה.
- בנה extension protocol חדש `LibraryVersionedTextProviding` / `BackendVersionSelectionCoordinator` תחת `Source/LibraryBackend` או `Source/Otzaria` עם default behavior מסודר שלא שובֵר existing `LibraryTextProviding`. שמור `versionId` בצד state scoped by backend+work+tab, בלי לשנות persistenceKey של `TextLocator`. הצגת בורר גרסה בתוך UI המקורי מותרת רק דרך hook מאושר או extension קיים; בהיעדר אישור הספק מוכן וה־UI gate נשאר BLOCKED_OWNER. אל תיצור UI חלופי.
- מבחני version: שתי גרסאות, version title same across two books, חסר segment, priority, rollback selection, notes tied to original source, backward-compatible serialization.

## 10. שלב 6 — Inline footnotes, Divine Names ושאר סכמה 7

- תקן מפת גילוי סכמת `line_note`, `line_note_divine_name`, `line_divine_name`, `book_protection` והוסף `Source/Otzaria/Data/OtzariaLineDecorationRepository.swift` read-only; אל תערוך הערות אישיות של Maktabah או CloudKit. `line_note` = גוף הערת שוליים של הספר, *לא* user annotation; מצא את `charPos/noteIndex/hasMarker`, פענח BLOB zstd אם נדרש בדקדוק ההרחבה הקיימת, שמור HTML בטוח והסרת JS.
- מיפוי שם הקודש `span` הוא packed bit-code upstream schema7, אין לבצע substitution או render חדש על בסיס ניחוש; קבע converter רק לאחר fixture מול ערכי מקור מאומתים. אם מידע מסוים לא נגיש/מאושר, הצג טקסט מקור קיים בצורה בטוחה ותעד `NOT_SUPPORTED_YET`, ללא שינוי רינדור דתי שגוי.
- `book_protection` הוא נתון הגנה/רישוי — אין לפתוח, לייצא או לשכפל קטעים שמוגנים לפי מדיניות התוכן; fail closed עד לבדיקה.

## 11. שלב 7 — עדכון מנוע Rust במקור במקום העתקת אלגוריתם

**זוהי תת־משימה מבודדת ומחייבת QA לפני promotion**:
- לא למחוק את מנוע ה־Rust שכבר פועל ולא לגעת ב־`Source/Core/SearchEngine/*` המקורי. העבודה ב־`Vendor/OtzariaSearchEngine/*` וב־`Source/Otzaria/Search/*`.
- קבע pin **EXACT** `225a6d5d7265c478a64d3a609a536d0deed433e7` ורק אותו; אחזר checkout נקי של `Otzaria/otzaria_search_engine`; אל תבצע `--latest` או sync assets לא מורשים.
- `rust/Cargo.toml` v7.0.1 מחייב בדיוק אחת מ־`sqlite-bundled`,`sqlite-host`. עבור הגשר Swift אין Dart sqlite3_host: ב־`ios_bridge/Cargo.toml` הגדר `search_engine` עם `default-features=false, features=["sqlite-bundled"]`, בכפוף לאימות link/concurrency של SQLite bundled מול מערכת SQLite. אל תאפשר גם וגם; בדוק Cargo.lock ושתי תכונות חד־משמעיות.
- `Vendor/OtzariaSearchEngine/ios_bridge/src/lib.rs`: התאם את wrapper ל־API v7 (`search_and_count_exact/fuzzy/advanced`, `add_library_books` או indexing API הרשמי התקין, dictionaries async, cancel handles, path/source registration, compatibility, book fingerprints, snapshot, memory release), תוך שימור **C symbol contract** העדכני מול Swift ככל האפשר. רק C ABI חדש כשהנדרש; `catch_unwind` לכל גבול Rust/FFI, שחרור C string, no panic/threads crossing invalid, handle lifetime. `rust/src/api/search_engine.rs` הוא מקור החתימות; בדוק אותו *באופן מקומי בזמן קומפילציה* ולא תניח שה־old API נותר.
- עדכן `Vendor/OtzariaSearchEngine/include/otzaria_search_engine.h`, `Source/Otzaria/Search/OtzariaSearchEngineBridge.swift`, `OtzariaSearchModels.swift`, `OtzariaTantivySearchRepository.swift`, `OtzariaSearchIndexer.swift` רק במידה הנדרשת; השתמש ב־`verify-api-parity.py`, Rust ABI tests, and Swift checks. API v7 מבטל/מיישן תהליכים מסוימים; **אין** לבצע מימוש Rust חדש של ניתוח עברית, regex, ranking או highlighting.
- `semantic`: upstream ONNX inference desktop-only; ב־iOS הצג unavailable, disable UI/feature gates; אל תכלול mock בפרודקשן, GGUF, vectors/model לא מבוססים. תקן תיעוד ישן `Vendor/OtzariaSearchEngine/README.md`, `PARITY.md`, `docs/otzaria-search-artifacts.md` downstream.
- עבור מילוני `dictionary.json`, `Acronyms.json`: שמור גרסאות חוקיות שהן כבר בפרויקט בכפוף לבירור מקור/רישיון; **אל תוריד גרסאות חדשות מ־Otzaria/otzaria ללא הרשאה**, גם אם sync-script עושה זאת. אם נדרשים מילונים חדשים ולא הותר שימוש — תעד `BLOCKED_LEGAL_RESOURCES`, אין release ולא "תיקון" שקט בהורדת מילון ממקור אחר.
- בדוק device/simulator `aarch64-apple-ios`, `aarch64-apple-ios-sim`,`x86_64-apple-ios` **רק בסביבת Xcode ובתוך הרשאת build מתאימה**. Windows Swift אינו הוכחה לקומפילציית SwiftUI/UIKit. עד אז `NOT_RUN_APPLE_SDK`.

## 12. שלב 8 — אינדקסים וחבילות נתונים; ללא ערבוב סכמה

- אינדקס מנוע schema10 אינו יכול לפתוח index schema4 קיים. **אין לשנות manifest כדי לעקוף בדיקה**. הקוד יזהה `rebuild_required`, ישאיר את המסד נגיש ללא חיפוש אם צריך, ויציע התקנת index תואם בלבד.
- נצל `OtzariaSearchIndexManager` (directories `final`, `building`, `previous`), `OtzariaSearchArtifactPolicy`, `OtzariaSearchArtifactReleaseClient` שמקבל **חבילות downstream בלבד** מאותו engine, אותו DB source release, אותו corpus identity, same resource sha. אין להשתמש אוטומטית ב־`otzaria-library-index.tar.zst` הרשמי עד שיוכח שעבר compatibility ומבנה manifests תואם.
- ב־`Source/Otzaria/Bootstrap` יש כבר downloader מתקדם: SHA/resume, SQLite validation, atomic promotion. release `v36-20261101064231` נושא `seforim-schema7.db.zst`; `OtzariaLibraryRelease.isProductionDatabaseAssetName` כבר יודע לזהות `seforim-schema<N>.db.zst`. ודא policy, size, sha ו־schema; **אל תחליף למחרוזת קבועה `seforim.db.zst`**.
- מסד מותקן צריך לאפשר קריאה ו־TOC ללא נוכחות אינדקס החיפוש; זהו P0 ידוע ב־Asana. התקנת אינדקס נפרדת עם סטטוסים ברורים `missing / installing / compatible / incompatible / repairable`; לא prompt להוריד מחדש כשאינדקס תקין כבר קיים.
- `Source/Otzaria/DataProfiles/*` miniTest10 חייב לשמור parity לאותו קוד; production/index only dataset difference. DB v32 old releases נשארים readable אם schema supported; v36 new feature gating.
- delta updater: אין להטמיע `otzaria_library_updater` Dart (רישיון אישי וruntime לא מתאים). אם המשתמש מאשר שלב עדכון DB delta נפרד, בנה Swift native updater לפי החוזה המפורט ב־`02_IMPLEMENTATION_BLUEPRINT_HE.md` עם `schema_meta`, manifest SHA, logical hashes, staging, rollback. כברירת מחדל **אין** עדכון DB אוטומטי הרסני כחלק מהמשימה.

## 13. שלב 9 — ביצועים, ניהול זיכרון ו־Concurrency

- פתח `OtzariaReadingUnitService`/`OtzariaMaktabahBridge+ReadingUnits`: שמור lazy paging/יחידות קטנות; אל תבנה יחידת root ענקית, דוגמת "דרשות הר״ן", למחרוזת ענק במעבר ראשון. בצע query chunking מבוקר, שחרר lock מוקדם ומדוד `fetch / decode / render` בנפרד.
- **אל תמציא benchmark PASS**; הוסף telemetry מובנה (timestamp, DB bytes, book ID hashed/redacted if needed, lines count, elapsed, memory high-water), ללא נתוני משתמש רגישים.
- בקשרי מפרשים השתמש ב־metadata-only first, fetch full text רק לפי פתיחת card; עבור 2,000 links חובה pagination / bounded display; אין N+1 SELECT לכל שורה; אין main thread disk work.
- על background/foreground/DB swap backend switch: writer cancellation, search request cancellation, stale generation discard, SQLite connection reopen, profile switch invalidates schema/index caches, but keeps last-good data.
- Memory pressure: Rust `releaseMemory()` אם export תקין; אין לשחרר פתאום EngineHandle שפעולת חיפוש עדיין רצה עליו.

## 14. שלב 10 — בדיקות ודיווח מדויק

- יצור test fixtures מקומיים עם SQLite in-memory/temp files וטבלאות מינימליות/סכמה7; בלי תלות להורדת ספרייה מלאה.
- בדוק `LibraryBackend` + three backend registrations; Otzaria real line locators; alt TOC; version missing-content; topics/metadata; links/anchors; full text Hebrew; cancellation; search 101+; external db protection; DB v32/36; index schema4/10 incompatible; show no false ready; Sefaria RPC without UI drift.
- הדו"ח `04_QA_ACCEPTANCE_AND_ROLLBACK_HE.md` הוא המטריצה המחייבת. סמנו כל case `EXECUTED_PASS/FAIL/NOT_RUN/BLOCKED` עם מצע ותוצאת צפויה מול תוצאה בפועל. בדיקות iPad physical **לא** עוברות רק בגלל Unit או CI.
- הקפד על tests local/portable ללא workflow לא מורשה. **CI, full Xcode builds, App Store, TestFlight, costly indexing יש לבצע רק אם המשתמש אישר אותם בנפרד; אל תפעיל אוטומטית**.
- הצג מצבי UI feature capability רק לפי אמת: mixed edition data missing, search backend not installed, optional relations missing = capability graceful unavailable, not fabricated data.

## 15. שערים שאסור לסוכן לעקוף

| שער | תנאי פתיחה | מה לעשות כשהוא סגור |
|---|---|---|
| `G-OWN` | אישור מפורש *לכל קובץ/hunk* upstream מוגן | הצע diff בנפרד. אל תערוך. המשך downstream. |
| `G-LICENSE` | רישוי קוד/מילונים/נתוני ספרים והפצה הותר | אל תעתיק קוד או asset אסור; סמן release חסום. |
| `G-SDK` | גישה ל־Xcode/SDK וסמכות build | בצע static/portable בלבד; `NOT_RUN`, אל תמציא הצלחה. |
| `G-INDEX` | manifest תואם engine+schema+DB+resources + actual QA | אל תתקין index פגום ואל תעבור validation. |
| `G-RELEASE` | הרשאה מפורשת TestFlight / IPA / publish | אל תפרסם, אל תשלח לאפל. |
| `G-ASANA` | המשתמש ביקש מפורשות לעדכן/לסנכרן Asana | קריאה בלבד. |
| `G-HARDWARE` | בדיקה אמיתית על iPad + ראיות | לא מסמנים production QA כ־PASS. |

## 16. מבנה מסירת העבודה המחייב

בתום כל שלב שמור בתוך **ענף הפיתוח בלבד**:
- `docs/implementation/otzaria-native-20261104/implementation-status.md`: source HEAD/pins, כל הקבצים ששונו והאם downstream/upstream, תיאור API וקשרי תלות.
- `docs/implementation/otzaria-native-20261104/qa-results.md`: test name, PASS/FAIL/NOT_RUN, command, platform, SHA, time, logs/evidence.
- `docs/implementation/otzaria-native-20261104/licensing-audit.md`: all vendored code/assets, license/provenance, potential blockers.
- `docs/implementation/otzaria-native-20261104/owner-approval-proposals.md`: **רק** protected hunks שנדרשים, alternative tried and rejected, exact diff, risk, rollback; לא להכריז על אישור.
- `docs/implementation/otzaria-native-20261104/rollback-plan.md`: DB, index, pins, user data, feature flags, recovery.
- `docs/implementation/otzaria-native-20261104/unimplemented-parity-gaps.md`: כל פיצ'ר שממתין לעוד אישור/בדיקה.

**כלל הצלחה:** אין סיום "מושלם" בלי קוד תקין, בדיקות בפועל, תאימות 3 backends, חבילות תואמות וזכויות שימוש; בקבלת חסימה אמיתית מסור את כל התוצר downstream שהושלם ואת החסימה המדויקת, ואל תחזיק את כל התוכנית כבת ערובה. אין שאלות מיותרות בזמן הביצוע; שאל רק כשנדרשת *סמכות שאינה קיימת* (בעלים, רישיון, build/release) או עובדה שחובה למדוד בפועל.

**נקודת עצירה בטוחה לפני release:** הראה diff + file matrix + בדיקות + open blockers; אל תמזג upstream/main/feature ואל תיצור IPA/TestFlight בעצמך ללא הוראה מפורשת.

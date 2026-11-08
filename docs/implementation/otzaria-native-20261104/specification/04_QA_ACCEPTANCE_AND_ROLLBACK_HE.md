# מטריצת QA וקבלה מחייבת — ChavrusaText + Otzaria + Sefaria

**תוקף:** הדרישות במסמך זה הן תרחישי קבלה, **לא** טענה שבוצעו בפועל. הסוכן חייב להזין תוצאות אמת בכל שלב. 

## 1. כללים לרישום תוצאות

לכל Case יש ארבעה סטטוסים בלבד: `EXECUTED_PASS`, `EXECUTED_FAIL`, `NOT_RUN`, `BLOCKED`.

כל `EXECUTED_PASS` מחייב: `git HEAD SHA`, platform, database profile and `schema_meta`, engine SHA/schema, data artifact manifest hash, command/script, timestamp, actual assertion, log/artifact path. בדיקות UI/ביצועים פיזיות על iPad דורשות פרטי מכשיר וגרסת אפליקציה ולא מקבלות PASS מ־CI בלבד. בדיקות אשר זקוקות ל־CI/Archive/TestFlight/הורדת dataset מלא או protected hook אינן מורשות לריצה אוטומטית בלי אישור נפרד.

### עדויות לדוגמה (מבנה המחייב את הסוכן)

```json
{
  "caseId": "SEARCH-07",
  "result": "NOT_RUN",
  "reason": "Actual iOS simulator test environment not authorized/available",
  "gitSha": "<work-branch-head>",
  "sourceDatabase": "miniTest10|v36|external-fixture",
  "dbSchema": "<observed>",
  "engineSha": "<pinned>",
  "indexSchema": "<observed>",
  "platform": "<macOS|iOS Simulator|physical iPad|static fixture>",
  "command": "<exact command if executed>",
  "timestampUtc": "<time if executed>",
  "evidence": [],
  "expected": "result metadata and visible item match at offset 101",
  "actual": null
}
```

## 2. בדיקות תחומיות — תנאי קבלה

| Case ID | תרחיש מדויק | Expected / הוכחה נדרשת |
|---|---|---|
| GIT-01 | Git worktree נקי לפני עבודה | שינויים אישיים קיימים לא נדרסו; SHA בסיס זהה `59b01fa2...` |
| GIT-02 | branch נוצר מאותו SHA | אין commit ל־dev/main, ואין force-reset/rebase של עבודה חיצונית |
| GIT-03 | `git diff --name-status` מול base | כל קובץ עם provenance, אין diff לא מורשה ב־upstream protected |
| GIT-04 | `Scripts/CI/verify-upstream-boundary.py` תחת תרחיש מאושר | הגנה אינה עוקפת אישורי Ed25519; כשל בכל protected hunk לא מאושר |
| GIT-05 | קובצי Swift חדשים ב־target | בדיקת PBX membership: אין סימון PASS אם קובץ אינו חלק מ־Compile Sources; בלי אישור שינוי project file = `BLOCKED_OWNER` |
| GIT-06 | אין שינויים ב־Asana | רישום read-only בלבד; אף task לא עודכן, לא נסגר ולא הוכפל |
| GIT-07 | תלות upstream ומילונים pinned | שום `--latest`/remote moving branch; hash-lock נשמר; resource license מאומת |
| GIT-08 | Swift UI מקורי | Source/Core, Features, UI, Extensions נשארים ללא שינוי חדש ללא אישור פרטני |
| DB-01 | SQLite בסיסי schema מינימלי | ספרייה, מחברים, טקסט ו־TOC רגיל נטענים; optional tables לא מפילות app |
| DB-02 | schema7 מלא סינתטי | capability flags מזהים line_note, book_version, alt_toc וכו' במדויק |
| DB-03 | `line.id != lineIndex` | Locator מחזיר `lineIndex`, אף פעם לא משתמש ב־rowId כ־lineIndex |
| DB-04 | lineIndex חסר/חור בין שורות | next/prev משתמשים בשורה קיימת; לא +1 עיוור שיוצר תוכן לא אמיתי |
| DB-05 | `line_content` דחוס ו־zstd_dict | פענוח בדיוק פעם אחת, אין בלבול UTF8/HTML, אין crash על frame מושחת |
| DB-06 | tiny DB ללא `book_version` | הצגת ספר תקינה; versions unavailable במפורש ולא גרסה מומצאת |
| DB-07 | hash/schema/size mismatches | DB invalid fail-closed, last good file לא מוחלף |
| DB-08 | DB external עם security-scoped URL | נתונים read-only, לא הופך managed, לא מוחק/משכתב |
| DB-09 | מעבר פרופיל miniTest10→production→external | caches schema ו־DB identity מתאפסים נכון ואין נתוני ספרים מעורבים |
| DB-10 | מספרים וכותרות כפולים | מזהים מוגדרים לפי מקור, bookId ולא title matching עמום |
| TOC-01 | TOC רגיל ועמוד ראשון | heading→real line; לא מציג תחילת ספר אם נבחר פרק |
| TOC-02 | alt_toc_structure קיים | רואים default + named alt structures באותו `navigationStructures` |
| TOC-03 | alt_toc_entry parent/child | עומק היררכי נשמר, מיון וקישור TOC text תקינים |
| TOC-04 | alt entry ללא line anchor + descendant | first valid child target בלבד; לא entry.id או line PK |
| TOC-05 | parent cycle / orphan / missing text | אין אינסוף recursion/קריסה; diagnostic + graceful skip |
| TOC-06 | `line_alt_toc` matching active entry | מעקב highlight לאותו structure על בסיס lineID→entryID, בלי out-of-scope lookup |
| TOC-07 | שני entries עם אותו title | ניווט לפי IDs ו־lineIndex אמיתי, לא title equality |
| TOC-08 | ספר ללא alt TOC | default בלבד, פאנל תוכן עניינים ממשיך להתנהג כרגיל |
| TOC-09 | `line_ref` normalized FNV hash | matches golden fixture from official RefKey exactly; if unavailable feature off |
| TOC-10 | `line_dh` prefix query | bounded indexed results + correct `lineIndex`, `dhDisplay` for text |
| TOC-11 | iPad slider level paragraph | לא קופץ לרמת פסקה ללא בחירה מפורשת (Asana `1220120627071765`) |
| TOC-12 | reader previous/next book edge | אין first-page wrapping ואין legacy fallback אם reached boundary |
| VERS-01 | `book_version` metadata | title/he title/source/license/notes/priority mapped without fake default |
| VERS-02 | version ID belongs to another book | בקשה נדחית, אין קריאת תוכן זר |
| VERS-03 | missing `version_line` row | חסר במהדורה נשאר חסר; **אין** טקסט merged fallback |
| VERS-04 | book without versions | default merged text unchanged, no artificial version label |
| VERS-05 | two versions same book | content differs correctly, selected edition scoped properly |
| VERS-06 | two books same edition title | version ID remains scoped by book identity |
| VERS-07 | headings absent in version lines | כותרות מטופלות לפי חוזה מסד, לא מוצגות כטקסט מהדורה משוכפל |
| VERS-08 | multi-tab per-version choice | tab scoped, switch backend does not leak selected edition |
| VERS-09 | old saved locator decode | persists/restores unchanged; version field does not mutate TextLocator |
| VERS-10 | version picker native UI unavailable | provider exists but feature explicitly `BLOCKED_OWNER`; no new Otzaria UI |
| META-01 | `book_topic` | returning actual book topics, stable deterministic slug, Hebrew name, no invented English |
| META-02 | pub dates and places | actual SQLite joins; absent optional tables yield empty fields |
| META-03 | base text and dependents | correct direction and stable linked book ids |
| META-04 | default_commentator/default_targum | order by numeric position, not alphabetical |
| META-05 | book acronyms / collective title | metadata intact without duplicating books or falsely merging same title |
| META-06 | inaccessible/protected book | no leaking restricted content into copy/export/preview/search suggestion |
| LINK-01 | forward commentary | actual linked book and line id; body loaded lazily on selection |
| LINK-02 | inverse commentary | reverse orientation correct; distinction commentary vs quotation preserved |
| LINK-03 | `link_range` with coverage | every covered line shows related link without duplicate source, as per existing logic |
| LINK-04 | `link_suppressed_side` side0/side1 | hidden side not shown even from reverse lookup |
| LINK-05 | `link_anchor` charStart/End | anchors only on original first side line, not range coverage line |
| LINK-06 | HTML inline formatting and niqqud | visible char positions map to valid UTF16 NSRange; no offsets inside tag |
| LINK-07 | schema7 `line_note` body before anchor | source→display map adjusts for extracted note body; if unable to map, no word highlight |
| LINK-08 | corrupt/missing anchor | link still visible if allowed; never highlight unrelated text |
| LINK-09 | same text, different books | navigation chooses `bookId + lineIndex`, not title |
| LINK-10 | 2k+ related sources | bounded SQL/window/pagination and list virtualization; no N+1 main thread |
| LINK-11 | Inspector selection embedded Sefaria | `.sefariaEmbedded` remains same backend id, no silently demoted `.sefaria` |
| LINK-12 | user comments unrelated to original footnotes | personal notes stay persisted, no table writes caused by reading source footnotes |
| TEXT-01 | `line_note` with/without sup marker | noteIndex/charPos/hasMarker mapped without user annotations collision |
| TEXT-02 | zstd note body | decode with existing dictionary codec if needed; invalid blob safe |
| TEXT-03 | divine name spans | exact spec and accepted fixture before apply; no guessed text substitution |
| TEXT-04 | book protection flag unknown | fail closed for restricted actions until semantics established |
| TEXT-05 | Hebrew RTL, HTML, cantillation | copy and selection ranges not corrupted by rendering transformations |
| SEARCH-01 | Rust engine version build-info | exact pinned commit, version7.0.1, schema10 returned by compiled bridge |
| SEARCH-02 | feature flags SQLite | exactly one of `sqlite-bundled`/`sqlite-host`, valid on Apple targets |
| SEARCH-03 | C/Swift/Rust ABI parity | `verify-api-parity.py` passes with all exported symbols matched |
| SEARCH-04 | cargo lock / pristine checkout | reproducible --locked; upstream source unchanged |
| SEARCH-05 | old schema4 index | `rebuild_required` or incompatible; cannot open by forged manifest |
| SEARCH-06 | v7 index rebuilt for fixture | stable book counts, paths, canonical references and query results |
| SEARCH-07 | 101st hit after load more | raw hit metadata and UI result match at offset 100+, same source/work and line |
| SEARCH-08 | 200+ hits and duplicate titles | stable unique identities independent of array offset |
| SEARCH-09 | exact vs fuzzy vs advanced Hebrew | matches engine official v7 expected fixture and highlight behavior |
| SEARCH-10 | Hebrew niqqud and quote variants | original Rust lexical semantics preserved, no Swift custom post-tokenizer |
| SEARCH-11 | proximity / word match / negative query | options are not silently dropped across C JSON or Swift encoders |
| SEARCH-12 | filtered category / book IDs | facet and scope match corpus, no `bookId=0` fallthrough |
| SEARCH-13 | cancel while search thread busy | no UI freeze/invalid pointer/stale result after cancel |
| SEARCH-14 | backend switch while search active | generation guard discards stale work and restores per-source search state |
| SEARCH-15 | index and DB mismatched version | no false status ready and no reused corrupted index |
| SEARCH-16 | engine memory pressure / foreground | memory releases with safe handle lifetime; subsequent query correct |
| SEARCH-17 | semantic in iOS | reports unsupported/unavailable; never claims model loaded or mock semantics |
| SEARCH-18 | resource hash mismatch | incompatible/controlled fallback, never sync from unlicensed origin |
| BOOT-01 | v36 asset name `seforim-schema7.db.zst` | selected correctly by release parser; expected digest verified |
| BOOT-02 | interrupted transfer and HTTP Range | resume only on same digest/etag/identity; bad range restarts clean |
| BOOT-03 | corrupt archive or out of space | last valid DB preserved, structured error and no fake download status |
| BOOT-04 | atomic DB promote rollback | interrupted swap recovered using `.previous`/staging state |
| BOOT-05 | install DB without index | reader/TOC/library usable even when search artifact absent |
| BOOT-06 | index artifact from old engine/schema | rejected without crashing or forcing DB redownload |
| BOOT-07 | full DB vs miniTest10 | same implementation, profile only changes paths and manifest identities |
| BOOT-08 | external DB with managed search | never mutate external path; index under separate namespace |
| BOOT-09 | corrupt downstream release manifest | reject digest mismatch/zip slip/oversized parts; staging wiped safely |
| DELTA-01 | optional future: patch chain selection | only known edges/versions/manifest, no unverified path |
| DELTA-02 | optional future: logical hash before/after | same as official contract; if not proven, reject + full DB fallback |
| DELTA-03 | optional future: SQLite FK with DELETE/UPSERT | no `INSERT OR REPLACE`, no unintended cascade |
| DELTA-04 | optional future: power cut during apply | old DB opens after recovery; index unaffected |
| UI-01 | existing Maktabah iPad three-column library | no new Flutter UI, same navigation placement/presentation |
| UI-02 | iPhone shell, iPad toolbar, themes | no changed UI components, no scroll reset on switch |
| UI-03 | session tabs during Otzaria↔Sefaria↔Embedded | prepare/publish preserved, no destructive state |
| UI-04 | Reader highlight after search | selected segment actually rendered, no removed context |
| UI-05 | result → Rashi/Talmud section | load full right unit then focus selected line, not just isolated hit |
| UI-06 | TOC current-node follow after swipe/reader scroll | correct active item, no jump to first heading |
| UI-07 | embedded Sefaria selection and footnote | correct `.sefariaEmbedded` key, works without visible RN components |
| UI-08 | Sefaria Hebrew labels for references | Hebrew TOC when source supplies, no false translation, not touched by Otzaria edits |
| UI-09 | search clear X / reader search history | no regression against previous bugs, in-book search history distinct from main |
| UI-10 | annotation, favorites and history roundtrip | source-qualified locators persist across relaunch/backend change |
| PERF-01 | large library first opening | no full-corpus allocation to display one book; responsive cancel |
| PERF-02 | "דרשות הר\"ן" large unit | bounded reading, no UI freeze or worst-case unbounded HTML |
| PERF-03 | high-frequency scroll/reader paging | UI thread disk work measured; no sustained stalls or screen jumping |
| PERF-04 | 2k links metadata/preview | metadata-first, progressive content fetch, no N+1 per line |
| PERF-05 | 30 backend switches/read cancels | no stale read after generation change, no memory leak/cross source |
| PERF-06 | physical iPad full corpus vs mini | measure p50/p95 load, memory, frame drops, app crashes; label actual not presumed |
| LEGAL-01 | license source map | Rust MIT notices; SeforimLibrary AGPL notices; Flutter Personal Use not copied |
| LEGAL-02 | dictionary/resources provenance | only files whose redistribution terms allow intended use shipped |
| LEGAL-03 | book texts/data rights | verify separate permissions; code license cannot grant data rights |
| RELEASE-01 | CI/Archive/IPA/TestFlight | `NOT_RUN` without separate owner action; do not upload while open gates |
| RELEASE-02 | report all owners and blockers | no hidden patch; missing tests remain `NOT_RUN/BLOCKED` |

## 3. סקריפטים ובדיקות קיימים — מה להריץ רק לאחר הרשאה מתאימה

**מותר לתכנן ולבצע בדיקות סטטיות/fixtures מקומיות בבעלות downstream**; בדיקות build/CI ו־full-corps מוגבלות לפי ההרשאות והכללים.

```bash
# בדיקת מצב קוד על ענף עבודה
 git status --porcelain
 git rev-parse HEAD
 git diff --name-status <BASE_SHA>...HEAD

# שלמות גשר ה-Rust / Swift / C
 python3 Vendor/OtzariaSearchEngine/Scripts/verify-api-parity.py

# מדיניות מקור / Tests, בלי לשנות את policy או להוסיף חתימה פיקטיבית
 python3 Scripts/CI/verify-upstream-boundary.py --help

# בדיקות portable שכבר קיימות, כפוף לסביבת הפרויקט
 python3 Scripts/verify-otzaria-mini-parity.py --help
 python3 Scripts/build-otzaria-data-profile.py --help

# בדיקות ריצה אופציונליות לפי סביבת macOS/Xcode והרשאת build:
 # Vendor/OtzariaSearchEngine/build_xcframework.sh
 # xcodebuild test ... (derive exact scheme and destination from project)
 # bash Scripts/run-otzaria-corpus-acceptance.sh /absolute/path/to/seforim.db 7030
```

אין להריץ `xcodebuild` על Windows, אין להריץ corpus acceptance בלי source data מותר והרשאת משאבים, ו־`cargo build` מקומי ללא target iOS אינו מעיד על חתימה/Apple integration.

## 4. סטנדרט ביצועים (תנאי קבלה מוצעים, לא נתונים שנמדדו)

המדדים ייקבעו מול baseline הנוכחי מאותה חומרה ואותם נתונים; אין להניח על בסיס הבדיקות שהריצה "מהירה". בגירסת שחרור כוונו לכך שלא יהיו תקיעות MainActor גלויות מעל 100ms בפעולת ניווט רגילה ולא תהיה עלייה עקבית במדד p95 ביחס ל־baseline. עבור ספר ענק/חיפוש ואינדקס יש למדוד בנפרד cold/warm, רמת RAM, free disk; חריגת זיכרון, timeout, crash או selected segment wrong = FAIL גם אם build מצליח. אם baseline קיים עצמו נכשל, דווח שניהם ולא תציג PASS.

מדדי telemetry: schema/db generation, file-size MB, cold/warm, `load unit lines/time`, `SQLite queries/time`, `decode/render time`, peak RSS, p50/p95, frame stalls, cancel latency, memory after backend switch, disk usage during DB/index promotion. פרופילים: miniTest10, real v36, old v32-if-available, external URL, install missing-index.

## 5. כללי rollback מפורטים

### Code

- Feature branch מבודד עם commits נפרדים לפי שלב. להחזיק SHA baseline וסקריפט diff נקי. Fail/build break ⇒ revert commit downstream של אותו שלב, לא להפעיל `git reset --hard` על ענף/עץ עם עבודת משתמש.
- שינויים בקובצי protected מקוריים לא קיימים ללא אישור פרטני; הצעת patch שנסגרה אינה מצריכה rollback.
- Pin Rust `UPSTREAM_COMMIT` הישן נשמר כתיעוד שחזור וה־Cargo.lock/manifest הקודם משוחזרים *יחד*, לא משחזרים רק git SHA.

### Search index

- `.building` נכתב בנפרד, `.previous` הוא עותק מוצלח קודם, `.final` נפתח רק אחרי `checkCompatibility` ו־manifest אמת. כשל rebuild אינו מוחק אינדקס טוב קודם או את מסד הנתונים. אם אין אינדקס תואם — חיפוש חסום בצורה מפורשת; פתיחת ספרים תקינה.
- schema4 איננו valid עם engine schema10 גם אחרי rollback ל־DB v32. בדיקת המנוע + index היא זוג — downgrade רק כזוג מאומת.

### DB

- managed DB staging וה־previous לא מוחלפים עד אימות SQLite/content hash. כתיבה/החלפה במסד חיצוני אסורות. כשל או זיכרון חסר מחזיר DB קודם. אובדן חיבור mmap/SQLite מחייב invalidate cache generation בלי לאבד annotations במערכת אחרת.
- לא לדרוס `QualifiedLocatorStore`, רשומות legacy negative IDs, annotations, tabs, history, favorite snapshots או CloudKit metadata כדי "לרענן" ספרייה.

### External release

- Build signed/TestFlight הוא פעולה נפרדת לפי רצון הבעלים. אין `force` ללינק release או overwrite של tag קיים. כל asset חדש חייב manifest+SHA ותאימות למנוע והרשאות data.

## 6. קבלה סופית — תנאי PASS אמיתי

הפרויקט ניתן למסירה לבדיקת בעלים רק כאשר: (א) אין diff מוגן לא מאושר, (ב) קובצי Swift החדשים כלולים בפועל ב־Compile Sources, (ג) כל יכולת שהופעלה קיבלה unit/integration PASS של אותה סכמה, (ד) חיפוש Rust 7 בפועל תואם לאינדקס schema10, (ה) שלושת ה־backends נבדקו ללא cross-source, (ו) DB v36 ו־mini profile נבחנו לפחות בתרחישים המתאימים לסביבת הבדיקה, (ז) תיקוני P0 ללא test failure פתוח, (ח) QA פיזי נשאר במפורש `NOT_RUN` עד לביצוע אמיתי, (ט) זכויות שימוש להפצה נבדקו, ו־(י) לא בוצעה הפצה בלי אישור.

כל חריגה מתועדת ב־`unimplemented-parity-gaps.md` וב־`owner-approval-proposals.md` ולא מוסווית כ־DONE.

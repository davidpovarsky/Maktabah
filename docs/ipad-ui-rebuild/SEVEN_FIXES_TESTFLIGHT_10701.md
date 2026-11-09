# מסירת שבעת התיקונים — TestFlight 10701, 9 בנובמבר 2026

`[נועם | DEV] [MAIN_SESSION]`, מצב NORMAL. העבודה והבדיקות בוצעו בסשן הראשי בלבד; אין סקירת סוכן עצמאי ואין שינוי Asana.

**המסירה הניסיונית הצליחה:** ChavrusaText **1.0.0 (10701)**, פרופיל **production**, עיבוד Apple **VALID**, `expired=false`. זמן התצפית: 9 בנובמבר 2026, **17:11:26 Asia/Hebron** (`15:11:26 UTC`). הצלחת ההפצה אינה קבלת ממשק. BUG03 ו־BUG04 נשארים **PARTIAL**; אין טענה שכל שבע התקלות נפתרו במכשיר.

[ריצת ההפצה — SUCCESS](https://github.com/davidpovarsky/Maktabah/actions/runs/42628632080) · [TestFlight](https://appstoreconnect.apple.com/apps/6809559414/testflight) · [Artifact חתום](https://github.com/davidpovarsky/Maktabah/actions/runs/42628632080/artifacts/13685562167).

## Git ומקור הבנייה

- ריפו: `https://github.com/davidpovarsky/Maktabah`.
- Worktree: `C:/Users/DAVID/Code/Maktabah-ipad-ui-faithful-rebuild`.
- ענף: `experiment/ipad-ui-faithful-from-9401`.
- HEAD בתחילת ההמשך: `cd5e8fef38ea2f8cfc9e3f27fbc995ade94934ec`; כל השינויים שנמסרו בסשן הקודם נשמרו ונסקרו.
- Commit המקור שנדחף, נבנה ונחתם: **`1b0641a7e9c1a743f05f46aa06c74e7658642265`**. ריצת ההפצה אימתה `expected_sha` זה בדיוק.
- מקור Build10601 הקודם: `70810eec46ad1fec6f30d983bf31e5f922dacb61`; `Source/` ב־HEAD ההתחלתי היה זהה לו.
- upstream HEAD אומת ללא fetch/merge: `46e893c65139fbb1e582d6595b0d220ea912324a`.
- העץ היה נקי לאחר commit/push המקור. מסמך זה ועדכון STATUS מתווספים אחריו כתיעוד בלבד; הם אינם משנים את היישום שנמסר.
- לא בוצעו merge ל־main, sync, reset, force-push, שינוי checkout אחר, שינוי פורמט שמירה, מחיקת נתוני משתמש או שינוי זהות חתימה. ה־worktree של אינטגרציית Sefaria/Otzaria לא נערך.

## מטריצת שבע התקלות

| תקלה | סיבה מאומתת לעומת השערה | תיקון וקבצים/מתודות | ראיות ומצב |
|---|---|---|---|
| BUG01 — Inspector | `shouldPresentPanelInContent` החזיר true ללא תלות ברוחב. | `iOSReaderWorkspaceView.swift`: מדידת עמודת הפרטים, מינימום קורא 430 עם ScaledMetric, פאנל 300 וידית 18; שימוש באותו `ChavrusaReaderWorkspaceLayout` ואותו קורא; guard במעבר לעגינה ובסגירת sheet. | **IMPLEMENTED**; diff מאושר, סקירת state/layout ובניית מכשיר עברו. מעברי רוחב ו־hidden callback על מכשיר אינם מוכחים. |
| BUG02 — Search | ל־List ולשלוש משפחות השורות לא הייתה מדיניות רקע תואמת theme. | `SearchResultsListView.swift.body`: AppStorage של Default, רקע מותנה לכל משפחת שורות, scrollContentBackground ורקע מלא דינמי. | **IMPLEMENTED**; סקירת כל השורות ובנייה עברו. Default שומר row backing מקורי; שלוש התמות במכשיר ממתינות. מנוע, query, הדגשות ו־pagination לא נערכו. |
| BUG03 — רווח עליון | מצב title אוטומטי בספרייה לעומת inline בקורא מאומת. הסבר לכל הרווח הפיקסלי נשאר השערה. | `iPadLayout.swift`: inline רק במסלול הספרייה המופעל. נסקרה שרשרת root TabView → viewer NavigationSplitView → ספרייה/TOC וקורא → toolbar/strip. | **PARTIAL**; הבנייה עברה. לא נוספו padding שלילי, offset או תרגום של הקורא. חסרים נתוני frame וקבלת גובה/יישור במכשיר. |
| BUG04 — strip | כפתורי המקור הושבתו והועברו לשורת Safari; רקע active/inactive היה זהה. יחס strip/toolbar שונה מהמקור. | `DocumentTabsHost.make/update` ו־`ChavrusaReaderHost.safariToolbar`: כפתורי UIKit המקוריים עם callbacks אמיתיים ו־IDs קיימים, ללא כפילות בקבוצה מאוכלסת; fallback יחיד בקבוצה ריקה; מישור inactive נפרד מ־flare/קורא. | **PARTIAL**; מקור/פרובננס ובנייה עברו, controller/layout/accordion/flare/pointer/drag נשמרו. הסרגל עדיין מתחת ל־toolbar המערכתי ומעל הקורא. נאמנות לתמונת הייחוס וליחס עם omnibar תחתון אינה מאומתת. |
| BUG05 — overview | הבחירה נשענה על activeTabID של הקבוצה במקום scene; title ורקעים הותאמו. | `StudyGroupsOverview.selectedDocumentID/openDocument/body`, הזרקת צבעים ב־`TabSwitcherPagePort`: נשמרו Grid/List וה־overCurrentContext של 10601. כרטיס פעיל באמת נסגר ללא ניווט; אין תמונות תצוגה מומצאות. | **IMPLEMENTED**; diff ו־SDK/בנייה עברו. אין שינוי ל־ReaderOverviewPresentation או rehosting של הקורא. החזרה הפיזית, portrait ו־scroll ממתינים. |
| BUG06 — glass | SafariGlass לא היה interactive; כפתורי המקור היו מחוץ ל־strip. | `DocumentTabsHost`: UIButton.Configuration.glass לכפתורים האמיתיים; `SafariToolbarSourcePort.SafariGlass`: regular.interactive. principal מסתיר shared backing כי SafariGlass מצייר אותו. | **IMPLEMENTED**; קומפילציית SDK אמיתית וארכיון עברו. שמירת targets/geometry נסקרה. מראה, לחיצה ומיקוד במכשיר ממתינים. |
| BUG07 — מקורות וקבוצות | hydrate לפני preflight של היעד; numeric-ID lookup קיבל ספק זר; nil locator הוגדר Otzaria; cleanup גורף עלול לבטל בקשות של היעד. הטריגר המדויק לצילום השגיאה אינו מוכח. | `BackendCoordinator.stageCatalog/performTwoPhaseSwitchAsync`: אינדקס יעד מבודד, prepare→commit→publish המקוריים ו־cleanup רק ליוצא. `TargetBackendBookResolver`/`TargetBackendBookIdentity.matches`: backend+work+ID, קטלוג שהושלם גובר על cache/registry ישן. `StudyWorkspaceNavigationAdapter.switchGroup/matches/hydrate`: guards של generation וקבוצה, החזקת reader instances, persistence transaction, חזרה סינכרונית ושחזור transient state. הודעת mismatch מדויקת ב־StudyWorkspaceModels. | **IMPLEMENTED**; 57 assertions מול helper/coordinator/store האמיתיים, 379 רכיבים, 61 workspace ובניית היישום עברו. אין בדיקת UIKit מלאה של switchGroup/rollback; races מרובי־כשלים והשעיית cleanup נשארים פתוחים. |

תיקון ההמשך הנוסף ב־BUG07 מונע גם מספר אותנטי שנשאר בזיכרון לעקוף קטלוג יעד מוצלח שכבר מחק את הספר. נוספו שתי בדיקות retained missing/present metadata; לא הוחלפו מזהי ספרים או UUIDs.

## בעלות, אישור ופרובננס

שלושת הקבצים המוגנים היחידים ששונו מאז הבסיס:

1. `Source/Features/Reader/iOS/iOSReaderWorkspaceView.swift` — אך ורק רוחב/ScaledMetric והחלטת presentation/סגירה המאושרים.
2. `Source/Features/Search/iOS/SearchResultsListView.swift` — אך ורק מדיניות הרקע המותנית המאושרת.
3. `Source/UI/iOS/Views/iPadLayout.swift` — שורת inline אחת במסלול המופעל.

ההשוואה לתוכן ההצעה המקורית עברה: **“מאשר את ה־diff המדויק בשלושת הקבצים”**. האישור והחלופות מופיעים ב־[OWNERSHIP_AND_AUTHORIZATION](OWNERSHIP_AND_AUTHORIZATION.md), ב־[SEVEN_FIXES_APPROVED_HOOKS.diff](SEVEN_FIXES_APPROVED_HOOKS.diff), וב־[UPSTREAM_EXCEPTION_REGISTER](../architecture/UPSTREAM_EXCEPTION_REGISTER.md). לא הורחב hunk מוגן ולא נערך checker או gate. Rollback הוא היפוך מבוקר של commit התיקון ושל חיבוריו יחד; אין צורך למחוק נתונים או להתקין מחדש. לא בוצע rollback בפועל.

יתר קובצי הייצור ששונו נמצאים ב־`Source/ChavrusaText` וב־`Source/LibraryBackend`, שכבות downstream שתועדו במטריצת הבעלות. שינוי source-port ב־TabSwitcherPagePort מוגבל להזרקת surface/card colors; שינוי SafariGlass בן שורה אחת מתועד מול אב־הטיפוס. לא נוספו Swift production חדשים; נוסף רק `tools/test_seven_fixes.swift` מחוץ ליעד iOS. תיקוני source-diffs הם תיעוד בלבד.

ה־DuckDuckGo checkout אומת בפין `f1d574485cf2f0586bcb284e8b3ca8c2f6ff7f32`. כל **32** hash המקור והיעד נבדקו מחדש. **13/32** ports זהים לאחר נרמול; הספירה ההיסטורית 14 כללה רשומת Inspector נפרדת בתוך 33 records. דגלי identical של 32 ה־ports לא השתנו. ה־Inspector לא נבדק מחדש כאודיט מקור בהמשך זה, ולא השתנו הפין `19d1b35397af4f10ae70cfb3f444c9de87383b53` או מקורות החבילה. זהו domain port עם הבדלים מתועדים, לא מסך דפדפן זהה למקור.

סיכון merge נותר בשלושת החיבורים המוגנים ובהבדלי source-port המתועדים; אין אישור גורף להרחבתם בעתיד.

## בדיקות שבוצעו

| בדיקה | תוצאה אמיתית |
|---|---|
| Windows Swift 6.3.3, רכיבים מהמקור הנוכחי | **EXECUTED_PASS — 379/379 assertions** |
| Windows Swift, persistence/migration/rollback/scenes/semantic locations | **EXECUTED_PASS — 61/61 checks** |
| Windows Swift, identity/catalog/transition/persistence כולל התוספות | **EXECUTED_PASS — 57/57 assertions** |
| Swift frontend parse | **EXECUTED_PASS — 12 קובצי ייצור ששונו + קובץ הבדיקות** |
| חברות ביעד | **EXECUTED_PASS — verifier קיים: 91 Otzaria Swift, frameworks/resources; בנוסף כל 12 הקבצים ששונו ב־Maktabah-iOS Sources** |
| מקור/אישור/whitespace | **EXECUTED_PASS — 32 hash checks, השוואת diff מוגן מדויקת, git diff --check לפני ואחרי staging/commit** |
| CI — stabilization/storage | **EXECUTED_PASS — 17 stabilization tests ובדיקות bootstrap policy הקיימות** |
| CI — backend/Sefaria/unified search contracts | **EXECUTED_PASS — executable המקור הקיים** |
| generic iOS device, SDK, archive/sign/export | **EXECUTED_PASS — היישום האמיתי, ללא Simulator** |
| IPA, entitlements, Sefaria assets, App Store validation/upload/processing | **EXECUTED_PASS** |
| בדיקה מקומית נפרדת ל־IPA שהורד | **EXECUTED_PASS — SHA256/ZIP/Info.plist מול CI; סמכות codesign היא macOS CI** |
| Simulator, native UI runtime, physical iPad | **NOT_RUN — physical-iPad owner review requested** |

לא שונו assertions או gates. workflows, project.pbxproj, זהויות חתימה ופיני dependencies לא נערכו במשימה זו. בדיקות UI היסטוריות של 10601 אינן PASS עבור 10701.

## חתימה ו־artifact שנבדקו בפועל

| שדה | ערך מאומת |
|---|---|
| שם / גרסה / build | ChavrusaText / 1.0.0 / **10701** |
| Bundle / Team | `com.davidpovarsky.chavrusatext` / `NA6HPWARQ2` |
| Data profile | `production` |
| חתימה | Apple Distribution; בדיקת macOS codesign strict עברה |
| App Groups | `group.com.davidpovarsky.chavrusatext`, `group.com.davidpovarsky.itorah` |
| iCloud | `iCloud.com.davidpovarsky.chavrusatext`; CloudDocuments + CloudKit |
| Push / debug | production APNs; get-task-allow=false |
| Extensions ב־IPA | אין |
| Apple App / Build ID | `6809559414` / `00ce1524-94dd-4fe2-bcaa-750ae1d3a5fe` |
| Apple processing | **VALID**, expired=false |
| IPA SHA256 | `08486ada7122062f5709934edee94139507f177b8d4ac1e8effe406c79cea8ea` |
| Artifact | `ChavrusaText-production-signed-ipa-10701`, ID `13685562167` |
| זמינות לבודק | **NOT_VERIFIED** — אין הוכחת שיוך לקבוצת בודקים או התקנה |

שלבי `Validate exported IPA`, `Validate with App Store Connect`, `Upload to App Store Connect and TestFlight`, `Wait for Apple TestFlight processing` הסתיימו כולם SUCCESS. בוצע dispatch אחד בלבד ל־SHA המקור המדויק, והמעקב היה watcher אחד. אין App Store Review או פרסום ציבורי.

הראיות המקומיות נמצאות ב־`C:/Users/DAVID/Code/ChavrusaText-rebuild-package-20261104/evidence/seven-fixes-20261109/`: לוגי שלוש הסדרות, `continuation-static-verification.json`, `source-dispatch-receipt.json`, metadata ולוג מלא של ריצה 42628632080, `local-artifact-verification.json`, ו־`testflight-42628632080/logs/testflight-processing.json`. ה־IPA שהורד נמצא ב־`testflight-42628632080/export/ChavrusaText-production-10701.ipa`. סקריפטי ההמשך משתמשים במקורות האמיתיים; generators ישנים לא הוחלו מחדש.

## בדיקות בעלים במכשיר — כולן OWNER_ACCEPTANCE_PENDING

1. Inspector לצד הטקסט בחלון רחב; שינוי רוחב, close/reopen, סיבוב, צמצום והרחבה, עם שמירת בחירה ו־study tool.
2. Search ללא query, עם תוצאות, expanded result ופתיחת ספר: Sepia, Default, Dark, ללא רצועה לבנה.
3. גבול עליון ויישור ספרייה/קורא: sidebar פתוח/סגור, חיפוש ספרייה נפתח/נסגר, מסמך אחד ורבים, ללא חפיפת status bar.
4. DuckDuckGo strip עם 1, 3 ו־10 כרטיסיות: flare, active/inactive, שמות עבריים ארוכים, close, reorder, overflow וחלונות צרים; השוואה ישירה לתמונת הייחוס.
5. Overview מלא: Grid/List, Done, כרטיס פעיל/אחר, שינוי קבוצה ופתיחה חוזרת; אותו קורא ואותה נקודת קריאה, ללא sheet או קפיצה.
6. Glass: plus, overview, חיפוש, פרופיל ו־sidebar; לחיצה, focus, Escape, hit targets וללא רקע כפול.
7. Otzaria ↔ Sefaria ↔ Embedded: קבוצות מעורבות, ID מספרי זהה, פתיחה חדשה/שחזור, קטלוג קר/חסר, ספר שנמחק, רשת שנכשלת וקבוצה ריקה. כישלון אינו פוגע במצב; אין הוראת מעבר מקור שגויה.
8. רגרסיות: ניקוד/RTL, TOC ו־Pull-to-Navigate, ניווט תחתון, הערות והדגשות, חיפוש בתוך ספר, שחזור מיקום בין כרטיסיות/קבוצות/רילאנץ׳, ספריות מותקנות ומסמכים offline.

Portrait, multitasking, Dynamic Type, races במעבר presentation/backend וחזרה מכשלים מרובים אינם מאומתים. אין מחיקה/איפוס/התקנה מחדש לצורך הבדיקות. לאחר משוב הבעלים יש לצרף build10701, רצף שחזור וצילום כדי לבודד את יתרת BUG03/04 או רגרסיה ממשית.

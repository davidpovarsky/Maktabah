# תיקון הסרגל ו־TOC של 11001 — שער אישור מדויק

עדכון: האישור המדויק התקבל בהמשך השיחה והוחל ב־`dcc405d1d82c7dc70118c7e02bdc827dee5c58a7`. זהו תיעוד הסקירה המקורית לפני האישור; מצב המימוש העדכני מופיע ב־`IMPLEMENTATION_SCOPE.md`, ברשומת האישור ובסעיף העדכון ב־`9401_restoration_change_ledger.md`. הצהרות PENDING להלן מתארות את שלב הסקירה ההיסטורי; בדיקות מכשיר פיזי עדיין PENDING.

2026-11-10. מצב: **PENDING_OWNER_EXACT_HUNK_APPROVAL**. סקירה ובדיקות בסשן הראשי בלבד.

העבודה טרם הושלמה. לא שונה קוד יישום, לא נוצר מועמד מתוקן ולא נשלח build חדש ל־TestFlight. מסמך הביצוע עצמו מחייב לעצור לפני החלת hunk מוגן חדש. חבילת הראיות הזאת מציגה את שינוי החיבור ההכרחי הראשון, ואינה מציגה אותו כתיקון מלא או כאישור חדש.

## מאגר, בסיס ובידוד

- מאגר: `https://github.com/davidpovarsky/Maktabah`.
- worktree חדש: `C:/Users/DAVID/Code/Maktabah-9401-native-sidebar-toc-fix`.
- ענף מקומי חדש: `experiment/ipad-ui-9401-native-sidebar-toc-fix`.
- נקודת התחלה ומקור היישום שנבדק כאן: `8632dd3165c9dabdee62931f0e011f542b4bc815`.
- `git ls-remote origin refs/heads/experiment/ipad-ui-exact-9401-restore` החזיר אותו SHA; גם ה־worktree המקורי היה נקי באותו tip. לא ערכתי או איפסתי אותו.
- מקור build ‏11001: `0d2ac9c46fe33d5a650fcf9ee7e66b2aa8bd2a73`. ההפרש ממנו עד נקודת ההתחלה כולל רק `PROJECT_BOARD.md` וקובצי תיעוד/ראיות תחת `docs/ipad-ui-rebuild`; כל 780 פריטי חוזה המקור תואמים.
- מקור 9401: `f243d06603cbe506de8f27ea8b9a479af4415e2e`.
- upstream נבדק מרחוק: `46e893c65139fbb1e582d6595b0d220ea912324a`; merge base עם הענף: `a0ed0df908a6cb38bc459d4baaeb400f447b2fc4`.
- אין SHA למסירת תיקון, קישור לענף מרוחק חדש, מספר build חדש או ריצת TestFlight חדשה. הענף החדש לא נדחף.

## ממצאי קוד, ללא טענת QA פיזית

המסלול הפעיל הוא `iOSMainView → iPadLayout.viewerTabContent → NavigationSplitView`. ב־sidebar נמצא `ReaderSidebarPager`; ב־detail מופע יחיד של `iOSReaderTabView → iOSReaderWorkspaceView → iOSReaderView`. ה־workspace שומר את הקורא המקורי ואת אזור כלי הלימוד; `ReaderTabsView` המקורי מגיע מתוך `iOSReaderTabView`. אין במסלול זה יצירה של `DocumentTabsHost`,‏ `TabsBarViewController`,‏ `StudyGroupsOverview` או `ChavrusaReaderHost`.

ה־pager מחזיק את שתי התצוגות בתוך `ZStack` ומחליף שקיפות. דף הספרייה מחזיק `NavigationStack`; ה־TOC הפעיל מקבל `embedsNavigationStack: false`. כך רכיב ה־TOC המקורי מפרסם את ה־searchable ואת פריטי הכותרת שלו ללא בעל הניווט המפורש שהיה לו, בעוד שני ענפי הניווט נותרים בהרכבה. נוסף לכך שני ה־closures מפעילים `toolbarVisibility` לפי בחירה. זאת עובדת הרכבה סטטית; לא נמדדו מיקומי שדות/כפתורים על iPad.

ה־TOC המקורי מחיל `.searchable` רק בענף הרשימה הטעונה. החיפוש, הכותרת, פעולת הסגירה, העץ והגלילה קיימים בקובץ המקורי ולא יוחלפו ב־TextField או ברכיב חדש. ההצעה מפעילה את ה־NavigationStack שכבר קיים בו; אין להוסיף מעליו stack מתחרה.

ה־call site הנוכחי מסיר `.sidebarToggle` גם ב־TOC טעון וגם במצב ללא ספר. `shouldShowPrimarySidebarButton` ב־`iOSReaderView` מחזיר `false` ב־iPadOS 27 לפני בדיקת ה־binding. ההיסטוריה מאשרת שהכפתור הידני הוסף ב־`9e8ae9c7`, וההנחה על הכפתור האוטומטי נוספה ב־`47edc4f2`. אין כאן ראיה שהמערכת מציגה בפועל כפתור בתצורת ה־pager הנוכחית.

`presentContents()` במסלול המשותף משנה את אותו coordinator לדף TOC, את `preferredCompactColumn` ל־sidebar ואת visibility ל־`.all`, ואז חוזר לפני מסלול ה־TOC הישן. סגירה משנה ל־detail ול־`.detailOnly`. בחירת עוגן מועברת ל־`tab.viewModel.didSelectTOCNode`. לא נמצא כאן מצב visibility ייעודי שמכריח overlay. לעומת זאת, drag של ה־pager מותקן על כל המשטח, ולכן התנגשות עם מחוות הסרגל היא סיכון פתוח.

הסגנון `.balanced` כבר קיים. הוא אינו מדידה של חפיפת המלבן של sidebar עם reader. לא נקבע סף רוחב חדש ולא נמדדה הקצאת רוחב בפועל. תיעוד Apple מתאר [התאמה של NavigationSplitView](https://developer.apple.com/documentation/swiftui/navigationsplitview) ו־[מצב tile של UISplitViewController](https://developer.apple.com/documentation/uikit/uisplitviewcontroller/splitbehavior-swift.enum/tile). שאילתת SDK לקריאה בלבד באמצעות apple-devtools אישרה את קיום הסמל `preferredSplitBehavior`; היא לא בנתה את האפליקציה ולא אישרה חיבור UIKit חדש. אין הצדקה להכריז שהעגינה תוקנה.

## בעלות וה־diff שממתין לאישור

| קובץ | מקור/בעלות | שינוי מוצע או תפקיד | אישור חדש |
|---|---|---|---|
| `Source/UI/iOS/Views/iPadLayout.swift` | UPSTREAM_OWNED; upstream ‏`46e893c6`; שושלת מקור `449e6b61`, כולל הנתיב ההיסטורי `Source/iOS/Views/iPadLayout.swift` | חמישה שינויי שורה ממוקדים: להפעיל stack מקורי אחד ב־TOC, להסיר שתי הסתרות navigationBar ושתי הסרות sidebarToggle | **PENDING**, לא הוחל |
| `Source/ChavrusaText/ReaderHost/ReaderSidebarPager.swift` | DOWNSTREAM_OWNED; נוסף ב־`2a46d52c` | בהמשך: לבודד את בעל הניווט הפעיל ולמנוע דליפת toolbar/search ומחוות; שימור state דורש בדיקה | לא שונה |
| `Source/ChavrusaText/ReaderHost/ReaderSidebarPageCoordinator.swift` | DOWNSTREAM_OWNED; נוסף ב־`2a46d52c` | coordinator וסרגל החיפוש/פרופילים הקיימים נשמרים | לא שונה |
| `Source/Features/Reader/iOS/iOSReaderView.swift` | UPSTREAM_OWNED; שושלת `449e6b61` | נשאר בקוד 11001, כולל החריג המאושר בן ארבע השורות בלבד; שינוי נוסף בכפתור/תנאי מחייב diff ואישור נפרדים | לא התבקש ולא הוחל שינוי נוסף |
| `iOSTOCView.swift`,‏ `TOCNodeRow.swift` וכל 80 פריטי EXACT_9401_BLOB | קוד/נכסים מוקפאים לפי manifest | שימור blob מדויק | ללא שינוי |

ההצעה הניתנת להחלה נמצאת ב־[PENDING_OWNER_iPadLayout.diff](PENDING_OWNER_iPadLayout.diff). פרטי ה־blob לפני/אחרי, SHA256 של ה־patch, חלופות שנפסלו, טווח הרגרסיה ודרך הנסיגה נמצאים ב־[pending-approval.json](pending-approval.json). `git apply --check` עבר ללא החלת ה־patch.

עטיפת ה־TOC מתוך downstream בלבד לא מסירה את הוראות ההסתרה והסרת הכפתור שבקובץ המוגן. שינוי הרכיב המקורי, העתקתו או הוספת שדה חיפוש מחקים את ה־UI ומפרים את ההקפאה. האישור הקודם אינו מכסה hunks אלה. לא שונו רישום החריגים, manifest או הגנות כדי לעקוף את השער.

**האישור המתבקש הוא רק ל־diff המדויק בקובץ הזה.** ההצעה לבדה אינה תיקון בר־הפצה: לפני הפצה צריך להשלים את שינוי ה־pager, לפתור שימור מצב חיפוש/הרחבה, לאמת כפתור יחיד גם במערכות קודמות, ולהשלים את עגינת הסרגל. אם יידרש hunk מוגן נוסף, תוצג בקשת אישור מדויקת נוספת לפני החלתו.

## מקור היסטורי וזהות Git

`git show 5d789e5f:Source/iOS/Views/iPadLayout.swift` מציג sidebar ספרייה בתוך `NavigationStack` ו־detail יחיד מסוג `iOSReaderTabView`. ה־reader ההיסטורי מציג TOC בתוך sheet; אין כוונה להחזיר sheet. השינויים ב־`516e1011` וב־`4f2b7e11` מאשרים את היציאה מה־sheet ואת מעבר ה־TOC לעמודת content. `git log --follow` מאשר שהנתיבים העכשוויים הם המשך של הקבצים ההיסטוריים.

| קובץ | blob ב־9401, ב־11001 וב־worktree הנוכחי |
|---|---|
| `iOSTOCView.swift` | `18a663aec7a3e11396a0ef3fddf51b833310f42c` |
| `TOCNodeRow.swift` | `9b924357f80454eac037f8ab48454dd07ce69a66` |

[provenance-before.json](provenance-before.json) ו־[provenance-after.json](provenance-after.json) ממפים את כל 780 פריטי ה־manifest: upstream, מקור 9401, מקור 11001, tip נוכחי, blob ב־worktree, סיווג קודם, diff מלא מול 9401 והפניה לאישור קיים כאשר קיים. כל 80 פריטי EXACT נשארו זהים. ה־gitlink הלא מאותחל של SefariaMobile מתועד כ־gitlink מתוך index, ללא טענה לבדיקת תוכן worktree שאינו מאותחל. לא שונה backend, חוזה persistence, vendor pin, יעד, signing, workflow או מקור toolbar החיפוש/הפרופילים.

## אימות שבוצע ומגבלות

כל התוצאות להלן מתייחסות לקוד הבלתי־שונה ב־`8632dd3165c9dabdee62931f0e011f542b4bc815`:

ריכוז תוצאות קריא למכונה: [preflight.json](preflight.json). נוספו רק ששת קובצי חבילת הסקירה: מסמך זה, preflight, שני snapshots של provenance, ה־diff הלא־מוחל ורשומת pending-approval. כל מקור היישום והגדרות הבנייה נותרו ללא שינוי.

- `verify-9401-exact-source.py`: PASS, ‏780 פריטי מקור, 80 EXACT ו־9 חריגים קיימים.
- `test-9401-exact-source.py`: ‏20/20 PASS, כולל דחיית זיוף אישור, שינוי TOC, קורא נוסף וסטיית backend.
- `test-faithful-workspace.py`: ‏61/61 PASS; קומפילציה מקומית אמיתית של Swift נייד והרצה של persistence/migration/rollback/scene/semantic-location.
- `Scripts/run-chavrusa-component-tests.sh`: ‏379/379 PASS עם Windows Swift ‏6.3.3, כולל isolation, session, anchors, search routing ו־RPC.
- `verify-otzaria-xcode-project.py`: PASS; ‏91 קובצי Otzaria, שני מנועי החיפוש והמילונים.
- `git diff --check`: PASS; `git apply --check` להצעה: PASS.
- [שאילתת SDK לקריאה בלבד](https://github.com/davidpovarsky/apple-devtools/actions/runs/42729995234): הצליחה; אינה קומפילציית היישום. Windows אינו סמכות לאימות SwiftUI/UIKit.

לא בוצעו שינוי או הרחבה של guard, mutation tests חדשים להרכבה המתוקנת, בדיקות state machine חדשות לסרגל, או קומפילציית מקור מתוקן. אלה תלויים באישור ובמימוש. guard הקיים עובר גם כאשר תקלות ההרכבה המתוארות עדיין קיימות; לכן PASS שלו אינו ראיה לחיפוש, לכפתור או לגאומטריה תקינים.

לא הופעלו simulator,‏ UI tests, קומפילציית generic iOS device של תיקון, archive, signing/export, upload, Apple processing או בדיקת זמינות לבודקים. ריצת 11001 ההיסטורית אינה ריצת תיקון זה. לא נשלח דבר ל־Asana, לא בוצע merge ולא שונה מידע משתמש.

## קבלה במכשיר — הכול PENDING

- **PENDING:** כפתור יחיד נראה, סוגר ופותח; במסך רחב ה־sidebar נמצא לצד הקורא ומקטין את רוחבו בלי לכסות טקסט.
- **PENDING:** ספרייה ↔ TOC באותו sidebar, עם חיפוש/כותרת מקוריים לכל דף, hierarchy, הרחבות, בחירה וניווט לעוגן נכון; ללא sheet או עמודה שלישית.
- **PENDING:** פתיחה/סגירה, מעבר דפים וספרים, rotation ושחזור session משמרים TextKit, בחירה וגלילה.
- **PENDING:** tabs,‏ Info,‏ Study Tools, הסרגל התחתון, inspector/resizer, ערכות נושא, Command Palette ופרופילים נשארים פעילים ובמקומם.
- **PENDING:** חלון קומפקטי, portrait/landscape, עברית RTL,‏ Dynamic Type ומקלדת ללא תחרות מחוות, שדות לא נגישים או navigation bars כפולים.
- **PENDING:** Otzaria ↔ Sefaria מקוון/מוטמע, פתיחה ושחזור, הערות וקישורי מקורות משמרים זהויות ונתונים.

הסיבה לעצירה היא סעיף 4.4 ותנאי העצירה במסמך הביצוע, יחד עם `UPSTREAM_INTEGRITY_POLICY.md` §1: אישור בעלים מפורש לכל file/hunk מוגן, לפני עריכה. אין כאן דחייה אוטומטית של כלי; מדובר בגבול ההרשאה שהמשתמש דרש לשמר.

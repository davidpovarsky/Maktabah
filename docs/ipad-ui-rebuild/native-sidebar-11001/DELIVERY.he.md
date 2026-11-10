# תיקון sidebar ו־TOC המקורי — דוח מסירה

2026-11-10. מצב: **SIGNED_PRODUCTION_TESTFLIGHT_VALID_DEVICE_ACCEPTANCE_PENDING**. הועלה בהצלחה build ‏**1.0.0 (11201)** בפרופיל **production**, ועיבוד Apple הוא **VALID**. כל בדיקות המכשיר הפיזי הן **OWNER_DEVICE_ACCEPTANCE_PENDING**. סקירה, מימוש ובדיקות בסשן הראשי; ללא סוכני משנה.

## מקור, ענף ואישור

המאגר הוא [davidpovarsky/Maktabah](https://github.com/davidpovarsky/Maktabah). ענף הניסוי החדש הוא `experiment/ipad-ui-9401-native-sidebar-toc-fix`, ב־worktree נפרד `C:/Users/DAVID/Code/Maktabah-9401-native-sidebar-toc-fix`. הבסיס המרוחק אומת: `8632dd3165c9dabdee62931f0e011f542b4bc815`. מקור 11001 בפועל הוא `0d2ac9c46fe33d5a650fcf9ee7e66b2aa8bd2a73`; מקור 9401 הוא `f243d06603cbe506de8f27ea8b9a479af4415e2e`; upstream הנוכחי אומת ב־`46e893c65139fbb1e582d6595b0d220ea912324a`.

מקור התיקון הראשוני נרשם ב־`dcc405d1d82c7dc70118c7e02bdc827dee5c58a7`. מקור היישום הסופי, כולל זהות TOC לפי UUID של לשונית הספר, הוא `8ea4f57806b9f1f6766bfda0a0828cdc07cf6645`. הרחבת guard והראיות נמצאת ב־commits נפרדים. SHA ההפצה המדויק הוא **`8420392303f3a31535c11020282d3e11dbc4dd26`**: [המקור שנבנה](https://github.com/davidpovarsky/Maktabah/commit/8420392303f3a31535c11020282d3e11dbc4dd26), [ענף הניסוי](https://github.com/davidpovarsky/Maktabah/tree/experiment/ipad-ui-9401-native-sidebar-toc-fix). עדכוני התיעוד לאחר ההפצה אינם משנים את קוד היישום שנבנה.

[ריצת TestFlight ‏42736585184](https://github.com/davidpovarsky/Maktabah/actions/runs/42736585184) הסתיימה בהצלחה. [תוצר ה־IPA החתום והלוגים](https://github.com/davidpovarsky/Maktabah/actions/runs/42736585184/artifacts/13730522249), SHA256 של ה־IPA: `b64cc534c16a3089ea5294740eb2dc412d3a822cee58bd1713d9bdab41f10803`. נתוני המסירה המדויקים נמצאים ב־[delivery.json](delivery.json); תשובת Apple נמצאת ב־[testflight-processing.json](testflight-processing.json). זמינות לקבוצות בודקים והתקנה במכשיר לא אומתו.

החריג החדש היחיד בקובץ upstream הוא ה־[diff המדויק ב־iPadLayout.swift](PENDING_OWNER_iPadLayout.diff), שאושר במפורש בהודעת המשתמש: “מאשר את ה־diff המדויק ב־iPadLayout.swift. המשך לביצוע מלא לפי המסמך, כולל הבדיקות והעלאת build production ל־TestFlight לאחר שכל השערים עוברים.” רישום האישור, ה־blob וה־SHA256 נמצאים ב־[pending-approval.json](pending-approval.json) וב־[רישום החריגים](../../architecture/UPSTREAM_EXCEPTION_REGISTER.md). ה־blob שהתקבל הוא בדיוק `e541d660cdeae48d5f378e1ee198147e6c7f8d85`.

## התיקון ומה הוא מוכיח

ב־11001 שני דפי ה־sidebar נשארו בהרכבה בתוך ZStack עם שקיפות. רק הספרייה החזיקה NavigationStack מפורש; ה־TOC קיבל `false`. ה־call site גם הסתיר navigation bars והסיר sidebarToggle. רכיב ה־TOC המקורי כולל searchable מקורי, אך בעלות החיפוש/כותרת אבדה בתצורה הזאת. כעת רק הדף הנבחר מורכב, ול־TOC יש את ה־NavigationStack המקורי שלו. לא נוצר TOC חלופי או שדה חיפוש מותאם.

כפתור הקורא הידני המקורי עדיין מושבת ב־iPadOS 27 כפי שהיה במקור המוקפא. כדי לא להסתמך על ההנחה שהכפתור המובנה יופיע, חיבור downstream זעיר מבקש באופן מפורש `displayModeButtonVisibility = .always` מבקר הפיצול המקורי. לא נוספו ToolbarItem, קורא או בקר פיצול נוספים. במערכות קודמות נשמר מנגנון הכפתור המקורי. ה־binding המקורי נשאר בעל מצב הפתיחה/סגירה; החיבור אינו משנה `preferredDisplayMode`, ילדים או delegate.

בחלון שמספיק רחב, אותו חיבור מבקש `.tile` מה־UISplitViewController הקיים. הסף משתמש ברוחב safe area בפועל, ברוחב/מגבלות העמודה הראשית, במינימום קורא 430pt וברווח מפריד 1pt, עם הגדלת מרווח הקריאה לפי Dynamic Type. עם sidebar של 320pt ובגודל טקסט רגיל, גבול המדיניות הוא 751pt. זהו חישוב eligibility ולא מדידת overlap במכשיר. בחלון compact או צר נשמרת הסתגלות המערכת. אין HStack חלופי, offset, overlay לקורא, מסך קבוע או עמודת TOC שלישית. מחוות דפדוף הדפים הוגבלה לפס בקרת הדפים הקיים כדי להשאיר את מחוות הקצה ורשימות התוכן למערכת.

תיעוד Apple: [balanced](https://developer.apple.com/documentation/swiftui/balancednavigationsplitviewstyle), [tile](https://developer.apple.com/documentation/uikit/uisplitviewcontroller/splitbehavior-swift.enum/tile), [כפתור מצב always](https://developer.apple.com/documentation/uikit/uisplitviewcontroller/displaymodebuttonvisibility-swift.enum/always). סמכות SDK לקריאה בלבד אישרה את displayModeButtonVisibility ואת זמינותו מ־iOS 14.5 ב־[ריצה 42733665190](https://github.com/davidpovarsky/apple-devtools/actions/runs/42733665190). אין בכך טענת QA על מיקום כפתור או אי־חפיפה בפועל.

## קבצים שהשתנו ותפקידם

| קובץ / קבוצת ראיות | שינוי |
|---|---|
| `Source/UI/iOS/Views/iPadLayout.swift` | UPSTREAM_OWNED: רק חמשת שינויי השורה שאושרו — stack מקורי ב־TOC והסרת ארבע הוראות הסתרה/הסרת כפתור |
| `Source/ChavrusaText/ReaderHost/ReaderSidebarPager.swift` | DOWNSTREAM_OWNED: בעל ניווט נבחר אחד, מחוות בפס הדפים, מדיניות רוחב/RTL ניידת וחיבור ציבורי אל אותו split; הקובץ כבר כלול ביעד iOS |
| `Scripts/CI/test-native-sidebar-policy.py`,‏ `tools/test_native_sidebar_policy.swift` | קומפילציה והרצה של מדיניות ה־pager האמיתית, ללא UIKit וללא סימולטור |
| `Scripts/CI/verify-9401-exact-source.py`,‏ `Scripts/CI/test-9401-exact-source.py` | הרחבת ראיות נפרדת: pin מדויק לאישור ולמקור ה־pager, שימור 11001, ובדיקות שליליות להרכבת החיפוש/כפתור/עגינה |
| `docs/architecture/UPSTREAM_EXCEPTION_REGISTER.md` | תיעוד האישור האמיתי לפני עריכת המקור |
| `docs/ipad-ui-rebuild/9401_exact_source_manifest.json`,‏ `9401_restoration_change_ledger.md`,‏ `PROJECT_BOARD.md` | עדכון inventory, ledger ותגלית על גבולות guard סטטי |
| קובצי `native-sidebar-11001/` | סקירה, מטריצה לפני העריכה, diff מוקפא, אישור, provenance לפני/אחרי, מעבר guard, פלט בדיקות ודוח זה; כל שם קובץ ותפקידו מפורטים ב־[changed-files.json](changed-files.json) |

כל שאר חוזי היישום, הספקים, הנתונים, ה־vendor והפרויקט/חתימה/workflows תואמים ל־11001. החריג הקודם בן ארבע השורות ב־iOSReaderView נשמר ללא שינוי; אין אישור חדש או שינוי ב־toolbar שלו. סיכון מיזוג upstream חדש מוגבל ל־hunk המאושר ב־iPadLayout; הלוגיקה הנוספת מבודדת בקובץ downstream קיים.

## זהות מקור ומלאי toolbar

כל 80 פריטי EXACT_9401_BLOB נשארו זהים. בפרט:

| רכיב | blob המקור ב־9401 ובמועמד |
|---|---|
| `iOSTOCView.swift` | `18a663aec7a3e11396a0ef3fddf51b833310f42c` |
| `TOCNodeRow.swift` | `9b924357f80454eac037f8ab48454dd07ce69a66` |

[provenance-before.json](provenance-before.json) ו־[provenance-after.json](provenance-after.json) מכסים את 780 פריטי המקור, כולל כל blob מקורי/current/candidate, סיווג, diff מלא והפניית אישור. `iPadLayout` ו־pager אינם מסווגים כ־EXACT. הקוד המקורי של reader,‏ tabs,‏ TOC,‏ theme וה־inspector נשאר במסלול הפעיל. אין mount של `DocumentTabsHost`,‏ `TabsBarViewController`,‏ `StudyGroupsOverview` או `ChavrusaReaderHost` במסלול הצופה המשוחזר.

| אזור | בעלים ופריטים נשמרים |
|---|---|
| מערכת | כפתור sidebar המקורי ב־split; ב־27 בקשת visibility מפורשת, ללא כפתור ידני נוסף |
| ספרייה | NavigationStack המקורי, native library search וה־toolbar המקורי של iOSLibraryView; Settings דרך toolbarGeneral |
| TOC טעון | iOSTOCView: native searchable, Close TOC ב־topBarLeading וכותרת/שם ספר ב־principal; hierarchy וגלילה מקוריים |
| קורא עליון | iOSReaderTabView: ReaderTabsView המקורי לפי regular/compact; readerSurface: כותרת/locator ו־Study Tools; iOSReaderView: Info ובורר הספרים המקוריים |
| תוספות מאושרות | Exact9401ViewerToolbar: magnifyingglass יחיד ל־Command Palette ותפריט StudyProfileMenu; אותה management view ואותו coordinator של הסצנה |
| קורא תחתון | iOSReaderBottomToolbarView המקורי: עמוד קודם/הבא, navigation label/בחירה, חיפוש, More עם Text Options/TOC/Annotations ו־Display by כאשר זמין |

מצבי loading/error/empty, סינון, בחירת עוגן, expansion ו־scroll-to-selected נשארים בקוד המקורי. ל־TOC יש חיפוש בענף הרשימה הטעונה בלבד, כפי שהיה ב־9401. מעבר דף מרכיב מחדש את state החיפוש/ההרחבה המקומי של רכיב ה־TOC; ה־view model, הספר והעוגן הנבחר נשארים באותם בעלים, והמקור מחשב שוב את מסלול ההרחבה והגלילה לעוגן. דף ה־TOC מזוהה לפי UUID של לשונית הספר הפעילה בפועל, כדי שמזהי סעיפים חופפים בשני ספרים לא ישאירו state וגלילה מהספר הקודם. לא נטענת מופע קורא חדש עקב החלפת דף sidebar או שינוי רוחב.

## בדיקות והפצה

[final-preflight.json](final-preflight.json) ופלטי `final-*` מתעדים את ה־SHA שנבדק ואת ה־hash של כל פלט:

- guard המקור: PASS, ‏780 פריטים, 80 EXACT ו־9 חריגים מתועדים.
- בדיקות מקור שליליות: 36/36 PASS, כולל כל 20 הבדיקות הקודמות ושתי בדיקות לזהות ספר/לשונית.
- מדיניות ה־pager האמיתית: 27/27 PASS — גבולות רוחב, divider, Dynamic Type, compact, RTL, כיווני מחווה, כיוון אלכסוני ושינויי חלון.
- suites קיימים שהורצו מחדש לאחר שינוי המקור: 61/61 workspace ו־379/379 component/backend/RPC.
- בדיקת membership: PASS; אין שינוי ביעדים או פרויקט. parsing של המקורות ששונו ו־`git diff --check`: PASS. parsing ב־Windows אינו typecheck של SwiftUI/UIKit.
- ה־guard הישן דחה את שני blobs ששונו. ההרחבה הנפרדת לא ביטלה את הכשל: היא מאמתת את האישור האמיתי, מקבעת את שני המקורות המצומצמים ומוסיפה בדיקות. [תיעוד מעבר ה־pin](legacy-guard-transition.json).
- Device build ל־`generic/platform=iOS`, archive, חתימה והרשאות, export, בדיקות IPA, אימות והעלאה ל־App Store Connect: **SUCCESS**. עיבוד Apple: **VALID**, ‏1.0.0 (11201), ‏`expired=false`. פרופיל `production` אומת מתוך ה־Info.plist של ה־IPA עצמו; אותו bundle ID ותמיכה ב־iPhone/iPad נשמרו. ה־SDK שנבנה בפועל: `iphoneos27.2`, ‏Xcode ‏27.2. ה־workflow הקיים נשמר ללא שינוי וננעל ל־expected_sha המלא.
- לוג ה־archive המלא מאשר קומפילציה בפועל של `ReaderSidebarPager.swift` ו־`iPadLayout.swift` ביעד האפליקציה. לוג ה־run המשולב ב־GitHub השמיט חלק מבאצ׳י הקומפילציה, ולכן ראיית המקורות וה־warnings נלקחה מתוצר `logs/archive.log` המלא. [build-warning-review.json](build-warning-review.json) כולל hash של הלוג; לא נמצאו warnings בשני המקורות ששונו. אין כאן החלפת ראיות ב־Windows parse.
- [source-gate-delivery.json](source-gate-delivery.json) מאמת שוב PASS מול אובייקטי Git של SHA ההפצה המדויק `8420392303f3a31535c11020282d3e11dbc4dd26`.
- ריצה ראשונה `42734945451` בוטלה במהלך בניית Otzaria כדי לכלול את תיקון זהות הספר. לפי metadata סופי, archive/upload/processing לא בוצעו; ראו [cancelled-before-upload.json](cancelled-before-upload.json). אין build TestFlight מריצה זו. המועמד המעודכן מיועד להעלאה סופית יחידה.
- לא הופעלו סימולטור, UI tests או matrix רב־פלטפורמי; לא בוצעו merge, Asana update או שינוי נתוני משתמש.

## בדיקת בעלים במכשיר פיזי — הכול PENDING

- **PENDING:** בחלון iPad רחב כפתור יחיד נראה, סוגר ופותח; הספר מצטמצם לצד הסרגל ואינו מכוסה.
- **PENDING:** ספרייה ↔ TOC באותו sidebar, לחצני דפים והחלקה בפס הבקרה; ללא sheet ועמודה שלישית.
- **PENDING:** חיפוש native מקורי בכל דף; ב־TOC טעון: כותרת/ספר, הרחבה, בחירה, גלילה וניווט לעוגן נכון.
- **PENDING:** פתיחה/סגירה, מעבר ספרים ודפים, rotation, background/restore משמרים את הקורא, TextKit, selection והגלילה.
- **PENDING:** tabs,‏ Info,‏ Study Tools, סרגל תחתון, inspector/resizer, themes,‏ Command Palette ופרופילים נשארים במקומם ופעילים.
- **PENDING:** compact,‏ portrait/landscape,‏ RTL,‏ Dynamic Type ומקלדת ללא navigation bars כפולים, blank strip או חיפוש לא נגיש.
- **PENDING:** Otzaria ↔ Sefaria מקוון/מוטמע, שחזור ספרים, זהויות, הערות וקישורי מקורות נשמרים.

קומפילציה, חתימה ו־Apple VALID אינם תחליף לבדיקות אלו.

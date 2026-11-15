# חברותאטקסט / Maktabah — מפרט יישום: חיפוש גלובלי Native + Liquid Glass

**תאריך:** 15.11.2026
**סטטוס:** SPEC / READY_FOR_MANAGER_REVIEW — תכנון מאושר עקרונית, לא בוצע מימוש, QA או Build.
**תיעוד קנוני:** docs/features/search/GLOBAL_SEARCH_NATIVE_LIQUID_GLASS_IMPLEMENTATION_PLAN_2026-11-15.md
**ממשק יעד:** טאב החיפוש הגלובלי בטקסט הספרים SearchModeView; לא חיפוש קטלוג הספרים ולא חיפוש בתוך ספר.
**מערכת יעד:** iPadOS/iOS 26–27; Native SwiftUI/UIKit בלבד. לא נדרשת תאימות למערכות ישנות.
**מטרה:** להחליף את הפריסה העמוסה בפריסה שאושרה בהדמיה, תוך שימור כל פונקציה קיימת, מנועי החיפוש, ה־Sidebar ועיצוב המקור של Maktabah.

## 0. החלטות מחייבות

1. **שדה חיפוש אחד** גדול בראש התוכן, ובצד שמאל שלו כפתור מחוונים עגול. השדה יישאר גלוי בזמן חיפוש, לא יתפצל לשדה Toolbar נוסף ולא יתפוס מקום של העץ.
2. **מתחת לשדה** בשורה קטנה ועדינה בלבד: מימין כפתור טקסט עם סמל ספר: "כל הספרים" או "N ספרים נבחרו"; משמאל כפתור טקסט "מדויק ⌄" (או מתקדם/מקורב/זית). אין שורת צ'יפים / SegmentedControl מלאה.
3. **סיידבאר הספרים המקורי נשאר סיידבאר אמיתי** של NavigationSplitView ב־iPad, ניתן להציג/להסתיר. הוא מציג את העץ, חיפוש שם ספר, סימון ספרים וקטגוריות, בחירה חלקית, ופעולות איפוס. לחיצה על "כל הספרים" או "N ספרים נבחרו" פותחת את העץ. סגירה אינה מוחקת בחירה.
4. **מעל התוצאות בלבד:** שורת "תוצאות חיפוש" + מונה אמיתי, בצד השני magnifyingglass לפתיחת שדה Inline לסינון תוצאות לפי שם ספר, ולצידו מיון. השדה מתרחב מתחת לכותרת התוצאות; לא משנה את השאילתה הראשית ולא את ה־Sidebar.
5. **היסטוריית חיפוש** בתוך שטח התוכן של טאב החיפוש לפני ביצוע שאילתה. לא Floating overlay שמסתיר את המסך. היסטוריה זו אינה שייכת לחיפוש בתוך ספר.
6. **מצבי חיפוש** ב־Menu מערכתי עם Checkmark; האפשרויות המתקדמות ב־Popover מערכתית שעוגנה לכפתור המחוונים. הצג רק פרמטרים שה־Backend הפעיל תומך בהם.
7. **Liquid Glass מקורי של Apple** משמש כפתורי בקרה מתאימים (מחוונים, סינון תוצאות, מיון, Toolbar), לא תוצאות, עץ ספרים, רקעים או כיתובי טקסט עדינים. אין חיקוי/blur ידני. הכפתורים הקיימים שלא צריכים Glass שומרים על שפת המקור.
8. **העיצוב המקורי נשמר:** טיפוגרפיה, צבעים ורקעים, גופני הספרים, RTL, מרווחים, גרסאות, highlight ונראות הקורא כפי שמפורטים ב־DESIGN_LANGUAGE.md. אין להעתיק את הלבן/כחול של הדמיית HTML לתוך המוצר.
9. **מנועים ודאטה לא מוחלפים:** Otzaria, Zayit, Sefaria legacy/embedded, locators, עימוד, status, היסטוריה, תוצאות שמורות, Reader ומנגנוני התקנת האינדקסים נשמרים. כל פעולת UI היא אמיתית — אין דמו ב־production.
10. **גבולות עבודה:** לא להפעיל CI/IPA/TestFlight, לא לשנות מסדי משתמש, לא למזג לענף ראשי ולא לשכתב מקור upstream עקב יצירת מסמך או משימת Asana זו. ההפעלה תיעשה ע"י מנהל הסוכנים לאחר הקצאה.

## 1. פריסת הממשק המלאה

### סרגל עליון
- כותרת "חיפוש" ב־NavigationStack/Toolbar המקורי, ללא שכבת Toolbar כפולה.
- כפתור סימנייה לפתיחת תוצאות שמורות רק כאשר הפעולה קיימת ומתאימה ל־Backend הפעיל. אין להבטיח שמירת תוצאות שאינה נתמכת.
- תפריט ellipsis: שמור תוצאות (אם נתמך), תוצאות שמורות, נתוני חיפוש/אינדקסים למנועים מקומיים, עזרה, איפוס שאילתה/תוצאות. אין לשכפל כאן את המיון או סינון ספרים שכבר מוצגים במיקום ייעודי.

### שדה מרכזי והפקדים שמתחתיו
- שדה Native עם search icon, clear, keyboard Search/Enter, פוקוס נגיש ו־RTL. הצעה טכנית: UISearchTextField עטוף ב־UIViewRepresentable; להשוות קודם מול SwiftUI native equivalent ב־SDK המותקן, ולבחור את הפתרון הנייטיבי המתאים ביותר לדרישת המיקום.
- כפתור slider.horizontal.3 באותו קו, משמאל לשדה. ב־iPad יפתח Popover מעוגן, בחלון קומפקטי Sheet מותאם.
- מתחת מימין: Label של היקף החיפוש; אם selectedBookIds ריק → "כל הספרים", אחרת "N ספרים נבחרו"; לחיצה משנה רק Sidebar visibility.
- מתחת משמאל: Menu מצבים: מדויק, מתקדם, מקורב, זית באוצריא; אפשרויות ספריא לפי API ה־Backend. העברה בין מצבים אינה מוחקת Query אך מונעת stale results תחת סטטוס אחר.
- Enter/Search יפעיל קריאה יחידה ל־UnifiedSearchSessionController.runSearch. לא לבצע חיפוש בכל הקשה.

### תוכן לפני חיפוש
- רשימת "חיפושים אחרונים" Native List / ScrollView תחת השדה; ההיסטוריה קיימת ב־SearchViewModel.searchHistory ונטענת מ־UserDefaults.
- לחיצה על רשומת היסטוריה: מעדכנת query, מבצעת חיפוש אחד, משמרת היסטוריה קנונית ומסירה כפילויות.
- "נקה הכול" ופעולת ניקוי רשומה אם נתמכת; Empty state עדין כאשר אין היסטוריה, ללא פופובר צף.
- כשהמקלדת פתוחה ההיסטוריה גוללת ואינה מכסה קלט, ואת שאר בקרי הממשק לא מזיזים בפתאומיות.

### בזמן חיפוש
- ProgressView + statusText קומפקטיים וללא כמה שכבות Banner נפרדות.
- Stop/Cancel אמיתי למנוע הפעיל: ביטול Task/engine ולא רק השמת isSearching=false.
- priorities למצבים: Loading, Error, Missing Index, Empty, Results, Pagination Error. לעולם לא לפרש שגיאת מנוע כאפס תוצאות.
- חיווי שמרני וללא false Ready / הורדה חוזרת של index שמותקן ותקין.

### לאחר חיפוש
- שורת תוצאות עם count אמיתי; distinguish loaded/total/filtered כשיש pagination.
- משמאל לשורת התוצאות: Button Glass קטן magnifyingglass, Button Glass קטן arrow.up.arrow.down; מיון מתוך Menu ב־Backend האקטיבי.
- magnifyingglass פותח TextField נייטיבי Inline מתחת לכותרת "סינון תוצאות לפי שם הספר…". ניקוי וסיום מחזירים את כלל התוצאות שנטענו. אין שינוי query/selectedBookIds ואין search engine rerun כדי לסנן מקומית.
- מסנן התוצאות המקומי הוא session.resultKitabFilter הקיים (normalized bookTitle), לא SearchViewModel.filterText של העץ ולא LibraryViewModel.searchQuery.
- אם הסינון פועל רק על תוצאות שנטענו, הכיתוב חייב לומר זאת; אל להציג טענה שהסינון מכסה את כל אינדקס הספרים. תמיכה בסינון גלובלי ממש דורשת API נפרד ובדיקת מנוע.
- התוצאות נשארות SearchResultsListView המקורי: bookTitle, reference, attributed snippet עם highlight, grouping/version selector, expand preview, reader navigation, contextMenu, Copy / Copy with source / Search in book, Load More.
- מקרים: אפס תוצאות כלליות, אפס תוצאות לסינון הנוכחי, שגיאה, חסר אינדקס, עימוד נוסף, Retry — כל אחד מקבל הודעה מדויקת.

## 2. הבחנה בין שלושת סוגי החיפוש

| שם | בעלות ו־State | משמעות |
| --- | --- | --- |
| חיפוש גלובלי בטקסט הספרים | SearchModeView / UnifiedSearchSessionController.query | השאילתה שבמסך החדש; כל המנועים |
| חיפוש קטלוג ספרים / CommandPalette | LibraryViewModel.searchQuery | איתור ספר או קטגוריה בקטלוג; משימה אחרת GID 1220036884173010 |
| חיפוש בתוך הספר | iOSBookSearchView והקשר Reader | חיפוש בטקסט של הספר הנוכחי; לא להציג בו היסטוריה גלובלית, GID 1220120889353811 |
| חיפוש שם ספר בעץ סינון | SearchViewModel.filterText / displayedCategories | מציאת ספר לצורך סימון ב־Sidebar; לא חיפוש טקסט |
| סינון תוצאות לפי שם ספר | session.resultKitabFilter | סינון תוצאות שכבר התקבלו; לא שאילתת מנוע |

אין להחזיר היסטוריה גלובלית ל־Book Search, ואין ליצור query או search history store חדשים.


## 3. מפת רכיבים נוכחיים -> המלצה מפורטת

| אזור | קוד קיים | החלטה | רכיב/מכל יעד |
|---|---|---|---|
| Layout ב־iPad | Source/UI/iOS/Views/iPadLayout.swift: searchTabContent + searchSidebarContent | **שמר** | NavigationSplitView + NavigationStack; binding עצמאי של visibility עבור Search, ללא הזזה ל־HStack |
| Layout קומפקטי | Source/UI/iOS/Views/iPhoneLayout.swift: searchTabContent + searchable | **התאם נקודת חיבור צרה** | אותו SearchHeader; בחירת ספרים ב־navigation/sheet מותאם, לא רינדור העץ במקום היסטוריית התוכן |
| מכל global Search | Source/Features/Search/iOS/SearchModeView.swift | **שמור session/routes, ארגן composition** | header + content-state + result-header + native navigation; הימנע משכתוב קובץ upstream |
| שדה ראשי | SearchComponents.swift: SearchInputBar | **החלף תצוגת החיפוש הגלובלי בלבד** | UISearchTextField עטוף SwiftUI או equivalent שנבדק מול SDK, onSubmit אחד, clear/focus/RTL |
| שורת מצבים | SearchComponents.swift: UnifiedSearchInputControls | **החלף מצבים גלובליים** | Menu עם Checkmark מתחת לשדה משמאל, ללא segmented row |
| מחוונים | UnifiedSearchAdvancedOptionsButton + UnifiedSearchToolbar | **העבר** | Button + Native Glass לצד השדה; Popover/Sheet options; הוצא כפילות מ־toolbar |
| כיתוב היקף | UnifiedSearchToolbar book-filter button, selectedBookIds | **העבר והפוך לעדין** | Button(Label book + computed count), מחובר ל־NavigationSplitViewVisibility |
| עץ הספרים | iOSSearchFilterViewController + iOSHierarchicalCollectionViewController | **שמר** | UICollectionView compositional list + diffable data + expanded categories |
| תאי ספר/קטגוריה | UI/iOS/Views/Common/ListContentView.swift, ListContentConfiguration, CheckboxState | **שמר פריסה/tri-state, בדוק שדרוג accessory** | UIKit native accessories אם תומכים באמת ב־checked/unchecked/partial; אחרת שמור UIButton קיים |
| חיפוש בתוך עץ | SearchViewModel.filterText / .searchable על Sidebar | **שמר** | חיפוש ספר/קטגוריה בסיידבאר בלבד |
| היסטוריה גלובלית | SearchHistoryOverlay + SearchViewModel.searchHistory | **העבר מתוך overlay** | GlobalSearchHistoryContent בתוכן מסך החיפוש; UserDefaults והיסטוריה קיימת נשארים |
| History מתוך ספר | iOSBookSearchView + SearchHistoryOverlay | **אל תשנה דרך המשימה הזו** | לשמר כפתורי mode/near/help; משימה נפרדת שמונעת היסטוריה גלובלית בתוך ספר |
| רשימת תוצאות | SearchResultsListView/SearchResultGroup/SearchResultRow | **שמר** | List, row typography original, version-grouping, sort, prefetch/pagination |
| תצוגה מורחבת | SearchResultContextPreview | **שמר** | SwiftUI expanding content, BackendCoordinator.section(at:), error/retry, text selection |
| חיפוש לפי שם ספר בתוך התוצאות | SearchModeView.searchResultsView + searchable(session.resultKitabFilter) | **החלף מיקום ותצוגה** | GlobalSearchResultsHeader: magnifyingglass Glass → inline TextField בחלק העליון של התוצאות |
| מיון | UnifiedSearchToolbar.sortMenu | **העבר** | Menu צמוד ל־inline result filter; מיון לפי המנוע הפעיל |
| פעולות בסרגל | UnifiedSearchToolbar | **צמצם** | Native Toolbar bookmark/ellipsis/actions בלבד; לא לשכפל options/mode/sort |
| Form מתקדם | SearchAdvancedOptionsView ב־SearchComponents.swift | **שמר ופרט** | Native Form עם Sections/Picker/Toggle/Stepper/TextField מותאמי Backend |
| התקדמות | UnifiedSearchProgressView | **שמר שירות, צמצם View** | ProgressView/status אחד; stop cancel אמיתי |
| Empty/Error/Index | UnifiedSearchFeedbackView + UnifiedSearchPagingFeedbackView (בענפי העבודה), ContentUnavailableView | **שמר/אחד** | first-class state במקום empty fallback שקט |
| נתוני חיפוש | Source/ZayitSearch/UnifiedSearchWorkspaceView.swift: SearchDataView + SearchDiagnosticsView | **שמר** | NavigationStack/Sheet מתוך More, הורדת רכיב חסר בלבד, לא תקלה שגויה |
| שמירת תוצאות | Source/Features/Bookmarks/iOS/iOSResultWriterView.swift | **שמר זמנית עם capability gate** | Sheet הקיים; הרחבת אחסון backend רק כמשימה קשורה נפרדת ומאומתת |
| תוצאות שמורות | Source/Features/Bookmarks/iOS/iOSSavedResultsView.swift | **שמר** | NavigationStack + searchable הקיים; לא לדרוס ניהול תיקיות |
| שפת עיצוב | Source/UI/iOS/Theme/ThemeComponents.swift + DESIGN_LANGUAGE.md | **שמר** | ThemeForm, ThemeList, themeTint, appBackground, appCellBackground, typography originals |
| מנועים/נתונים | UnifiedSearchSessionController, SearchViewModel, OtzariaTextSearchViewModel, ZayitSearchSessionController, BackendCoordinator | **לא להחליף** | שינויי adapter/cancellation מצומצמים בלבד אם מוכחים כנדרשים |

**פער מוכר ב־2026-11-15:** המצב המקומי של SearchModeView מציג SearchHistoryOverlay צף, .searchable לתוצאות, וכאשר התצוגה compact הוא עשוי להציג עץ סינון במכל המרכזי. התכנון מאחד את שלושת המקרים מבלי לשכתב search engine.

## 4. חלונית אפשרויות — רשימת בקרי המקור לפי מנוע

### 4.1 Otzaria — מצב מתקדם
טווח חיובי: otzariaScope (מרחק מילים, אותה פסקה, אותו סעיף); התאמת מילים: otzariaWordMatchMode (כולן, אחת, רוב, לפחות), otzariaWordMatchCount מותנה; otzariaDistance; מילים שליליות otzariaNegativeQuery + otzariaNegativeScope + otzariaNegativeDistance; מורפולוגיה: otzariaEnablesPrefixes, otzariaEnablesSuffixes, otzariaEnablesSpellingVariants, otzariaEnablesAramaic, otzariaIgnoresQuotes; ניקוד וטעמים: otzariaMatchNikud, otzariaMatchTaamim; ביטויים: otzariaCustomSpacingText + otzariaAlternativeWordsText; קיבוץ: otzariaGrouping (ללא, אותו סעיף, טקסט זהה). מיון: otzariaOrder מוצג מעל התוצאות; אם מופיע גם בחלונית מתקדמת, חייב להיות אותו Binding בדיוק ולא מצב כפול.

**פער נדרש להשלמה:** קיימים כבר שדות scope, negativeScope, negativeDistance, grouping במצב/מודל, אך SearchAdvancedOptionsView כיום אינו מציג את כולם. ליצור בקרי SwiftUI למשתנים הקיימים, עם validation ופענוח ללא אובדן מידע. אין לכתוב מנוע חיפוש נוסף.

### 4.2 מדויק, מקורב וזית
- במצב "מדויק" אין להציג Toggle מתקדם שלא משפיע על התוצאות; אם יש צורך, הצג הסבר מעבר למתקדם.
- במצב "מקורב" הצג אפשרויות שרלוונטיות למנוע fuzzy בפועל; אין להבטיח false morphology.
- במצב "זית" אין להציג תפריט התאמות לשוניות של Otzaria. היקף ספרים, מצב אינדקס, חיפוש סמנטי ותוצאה לפי היכולות האמיתיות בלבד.

### 4.3 Sefaria legacy / Sefaria Embedded
- בדוק BackendCoordinator.activeCapabilities ואת ההבדלים בין שני המנועים; הם אינם שקולים. חיפוש text, sorting, exact/lemmatized/word distance/chronological/reverse הם *מותני תמיכה*, לא הבטחה כללית.
- השתמש בהגדרות session.sefariaMatchMode, sefariaWordDistance, sefariaSortOrder, sefariaReverseSort רק אם ה־backend אכן מכבד אותן.
- אין מעבר backend אוטומטי בשינוי שיטת חיפוש; חיווי ברור כאשר תכונה אינה נתמכת או דורשת מקור אחר.
- במיוחד עבור Embedded: ה־JS bridge הנוכחי אינו בהכרח מכבד את כל שדות SearchOptions — לא לשלוח ערכים שנזרקים בשקט.

### 4.4 מבנה חלונית Native
- קבוצות Form: "התאמת מילים וטווח", "מילים להחרגה", "אפשרויות לשוניות", "ניקוד וטעמים", "ביטויים מיוחדים", "קיבוץ תוצאות". אמצעים: Picker, Toggle, Stepper, TextField, Section.
- Form ראשון פתוח באופן שימושי, קבוצות נוספות נגישות בגלילה או disclosure sections לפי UX. שדות שלילה מותנים במילות ההחרגה.
- iPad: Popover מעוגן ללחצן גלס. iPhone/size compact: Sheet מערכתית. לספק dismiss ע"י Done / tap-outside כשמתאים וללא איבוד state.
- ערכי mode ומיון ייגזרו מה־session, לא יישמרו עותק ב־View מקומי.

## 5. Liquid Glass ואחידות טיפוגרפית

| רכיב | החלטה ויישום |
|---|---|
| מחוונים לצד שדה החיפוש | Native Button עם .buttonStyle(.glass) ו־.buttonBorderShape(.circle); SF Symbol slider.horizontal.3, icon-only עם accessibilityLabel |
| magnifyingglass + sort מעל תוצאות | כפתורי Glass קומפקטיים ממדים תואמים; לתאם Glass container רק אם Apple API דורש לצימוד/אנימציה |
| bookmark ו־ellipsis ב־Toolbar | ToolbarItem/ToolbarItemGroup מערכתיים; להימנע מ־.glassEffect נוסף כאשר המערכת כבר מחילה תצוגת זכוכית |
| "כל הספרים" ו־"מדויק" | כפתורי טקסט Label/Menu עדינים, ללא רקע זכוכית קבוע |
| שדה החיפוש הראשי | Native search input עם surface לפי המערכת וה־theme; אין לכפות Glass גדול על ערך הקלט |
| היסטוריה/תוצאות/ספרים | צבעים/טיפוגרפיה מקוריים, שורות List, ללא Glass |
| Popover/Menu/Sheet | Native system presentation עם adaptive behavior |
| Empty/Progress/Error | ContentUnavailableView / ProgressView במראה מערכת + theme |

**מקור אמת חזותי:** DESIGN_LANGUAGE.md: צבעי Color.appBackground, Color.appCellBackground, Color.appSecondaryBackground, .themeTint(), iosTint. ההיסטוריה של Maktabah כוללת surfaces warm sepia/black/white, טקסט סמנטי Apple, טקסט ספרי Arabic והדגשת Hebrew/Arabic לפי backend. אין Hex קבוע ואין שינוי פונט כללי. יש לשמור גם system theme עם useDefaultTheme=true, dark appearance, Reduce Transparency, Reduce Motion, Dynamic Type, VoiceOver/Contrast/Bold Text. אין להחיל Liquid Glass על תוכן הספר, highlight המילים או תאי עץ הספרים.

## 6. מקור אמת, UX state ומקרי קצה

1. **State יחיד לחיפוש:** UnifiedSearchSessionController.query, scope, selectedBookIds, resultKitabFilter, status/results/pagination; אין SearchViewModel כפול.
2. **בחירת ספרים:** SearchViewModel.displayedCategories/filterText וקישור selectedBookIds הדו־כיווני הקיים. סגירת Sidebar לא משנה selection. Category partial/checked/unchecked נשמר.
3. **History:** SearchViewModel.searchHistory נשמר ב־UserDefaults; אין history store חדש, ואין להחזיר history ל־Book-local Search; מעקב GID 1220120889353811.
4. **Stale results:** שינוי mode/ספרים/הגדרות לאחר חיפוש לא יכול להציג תוצאות ישנות כאילו חושבו בשיטה החדשה. מדיניות מומלצת: explicit rerun אחד או state "יש להפעיל חיפוש מחדש" — לבחור/לתעד באופן עקבי ולעגן בדיקות.
5. **Default mode:** קוד session יכול להתחיל במתקדם. ההדמיה מציגה "מדויק". **הצעה:** בהפעלה ראשונה Exact ושימור הבחירה האחרונה, אבל רק לאחר בדיקת השלכות השינוי ואישור החלטת behavior; אין להחליף default backend.
6. **Paging + results filter:** session.resultKitabFilter מסנן רק את session.results שנטענו. להראות "N מתוך M תוצאות שנטענו" כשצריך. Loading more ממשיך אף אם filter המקומי כרגע מסתיר את כל התוצאות; אין false "No Results".
7. **Cancellation:** ה־Toolbar המקורי יכול להציב isSearching=false בלי לעצור את Task במנוע לא־ספריא. פעולה חדשה חייבת להפעיל cancellation אמיתי או לציין חסימה ממוקדת; לא להשאיר חיפוש בלתי נשלט.
8. **Saved results:** canSaveResults המקורי מוגבל לחלק ממקורות Maktabah. לפני הרחבת כפתור הסימנייה לאוצריא/ספריא יש לאמת schema, durable IDs, serializer, open/reopen; לא לשנות DB במסגרת UI רק כדי להציג כפתור פעיל.
9. **Result navigation:** מתן backendLocator/canonicalBookId/section, highlighting, version identity ו־SearchResultContextPreview ללא שינויים סמנטיים. Search in Book מתייחס לבחירת הספר לפי engine, לא לטקסט שם דומה.
10. **Index safety:** SearchDataView לא ישלח download/repair אם index usable, לא יסיר נתוני משתמש. בעיות status קיימות ב־BUILD 11201 הן משימה נפרדת; UI מציג הודעת מצב אמינה.
11. **Multiwindow/RTL:** Layout משנה רוחב דרך split view, keyboard לא מכסה History או Inline Filter, placement anchor תקין ב־right-to-left, VoiceOver labels על כפתורי icon.
12. **Deep links/App Intents:** אין לפתוח surface חיפוש נוסף; אם API action פותח טאב/תוצאה, עליו להשתמש ב־unified navigation/session ובחווית ה־UI החדשה.

## 7. תוכנית קבצים ומדיניות Upstream

**הצעת תיקיית downstream ייעודית:** Source/ChavrusaText/Search/UI/ (לבדוק בפועל root ownership ו־Xcode membership; אפשר להשתמש באחסון downstream אחר של האפליקציה אם מתאים יותר).

קבצים קטנים מומלצים:
- GlobalSearchHeader.swift — שדה, כפתור מחוונים, טקסט scope/mode.
- NativeGlobalSearchField.swift — UIText/Search field native bridging, binding/focus/onSubmit/clear/keyboard.
- GlobalSearchResultsHeader.swift — counter, sort menu, magnifyingglass inline filter.
- GlobalSearchHistoryContent.swift — תוכן היסטוריה קנוני ללא overlay.
- GlobalSearchAdvancedOptionsContent.swift — Form/Section/conditional options bindings.
- GlobalSearchPresentationCoordinator.swift — sidebar visibility, filter visibility ו־popover state; **לא** engine state כפול.

**קובצי Mount קיימים:** SearchModeView.swift, SearchComponents.swift, iPadLayout.swift, iPhoneLayout.swift, iOSSearchFilterViewController.swift. לרובם שושלת upstream או shared seam. לא להעביר קוד מקור שלם ל־downstream ולא לעשות reformats גורפים. לכל שינוי protected חובה מדיניות docs/architecture/UPSTREAM_INTEGRITY_POLICY.md + UPSTREAM_EXCEPTION_REGISTER.md: pin upstream/current SHA, הוכחת אי־יכולת להשיג באמצעות extension/adapters, exact diff/hunk, rollback, פלט בדיקות. רק hooks קטנים הכרחיים מותרים ללא בקשת אישור per-hunk נפרדת.

תאימות מול עבודה מקבילה:
- חפ״ק: C:\Users\DAVID\Code\Codex-Agent-HQ\docs\otzaria\leases-20261115.json + THREADS.md + wave1 handoffs — לבדוק לייב בעת שיבוץ; לא לשנות שום worktree פעיל.
- בזמן תיעוד המסמך ה־cwd במחשב הוא experiment/sefaria-mobile-original-embedded-20261029, HEAD 59b01fa2, **dirty**; אין לבצע על הענף הזה מימוש משמעותי. בשישה worktrees נפרדים בוצעו עבודות שונות של Wave 1, בסיס df2a2194, ללא מיזוג לראשי וללא QA מכשיר מאומת.
- משימה קיימת GID 1220036884173010 היא Library catalog Safari Toolbar + CommandPalette — **לא אותו Search tab**; לא לשנות אותה ולא ליישם animation/CommandPalette ב־global search.
- משימה קיימת GID 1220120889353811 מתייחסת להפרדת היסטוריה מ־Book-local Search; לעמוד בתוצאה שלה, לא להכפיל אותה.
- GID 1220539630830553 עוקבת אחרי רגרסיות BUILD 11201 ב־Sidebar/Search/Zayit/Index; לשמר תיקונים ולעקוף רגרסיות, לא להשתלט על ה־scope.
- GID 1220541059190159 בחפ״ק מסדירה פעולות הנתונים/מנועים; יש לתאם מול בעלות file leases ומצב האיחוד.
- סוכן מנהל מחלק למבצע ב־Codex Desktop TOP-LEVEL עצמאי (לא child) עם worktree/branch משלו; QA עצמאי בשיחה נפרדת אם נדרש. דיווח רק במיילסטונים משמעותיים וחסימות אמיתיות. לא לעדכן שאר Asana ללא בקשה מפורשת נפרדת.

## 8. שלבי ביצוע — בסדר תלות ולא בפריסה כפולה

**A. Baseline + ownership:** אימות branch/SHA/active leases, audit מקור, 3 מנועי חיפוש ותכונות, רכיבים, סטטי diff, נתוני תצוגה, צילומי baseline. יצירת ownership matrix.
**B. Header Native:** search field, Options Glass, Bottom Scope label Right, Bottom Mode menu Left, Sidebar binding, אין duplicated Toolbars. מימוש ברכיבי downstream ומינימום hooks.
**C. Advanced:** Form sections, bindings החסרים של Otzaria, backend capability filtering לספריא/embedded/זית, validation.
**D. History:** היסטוריה גלובלית inline בחיפוש הראשי, ללא פגיעה ב־Book-local overlay/העדכונים העכשוויים.
**E. Results:** ResultsHeader, filter by book title, sorting, count and pagination semantics, row/preview/context menu.
**F. Feedback + safety:** loading, error, missing index, cancel/retry אמיתיים, no duplicate requests, lazy performance.
**G. QA + handoff:** syntax/typecheck/build/simulator/hardware לפי אישור/זמינות; exact evidence; review עיצוב מול DESIGN_LANGUAGE והדמיה שאושרה; commit+SHA ו־rollback כאשר יש הרשאה. אין להפוך בבטא/למזג ל־main בלי החלטת בעלים.

## 9. מטריצת קבלה מחייבת (PASS / FAIL / NOT_RUN / BLOCKED עם SHA)

- [ ] בטאב החיפוש הגלובלי בדיוק שדה קלט אחד, כפתור מסננים משמאלו; מתחת "כל הספרים"/"N ספרים נבחרו" מימין ו־Mode Menu משמאל; אין segmented row/chips נוספים.
- [ ] Sidebar נייטיבי ב־iPad נפתח ונסגר מכל מצב ללא איבוד בחירה, query, results, reader tabs; עץ קטגוריות, tri-state ו־Search Book עובדים ב־RTL.
- [ ] Glass מקורי על בקרי הפעולה המתאימים בלבד; Toolbar לא glass כפול, אין Glass על קריאת ספרים; צבעים ופונטים מקוריים בכל theme + dark.
- [ ] Popover עם Form/Sections מקוריים נפתח ליד כפתור המחוונים; הצגה מותנית של options לכל backend/מצב; קומפקט: Sheet/Adaptive.
- [ ] כל פרמטרי Otzaria (כולל scope/negativeScope/negativeDistance/grouping) מוצגים ונשמרים, ב־Sefaria/Embedded/Zayit אין no-op options שקטים.
- [ ] History גלובלית היא תוכן במסך החיפוש לפני שאילתה; חיפוש מקומי בתוך ספר אינו מציג אותה, ושומר mode/near/help.
- [ ] לאחר חיפוש כותרת תוצאות, מניין נכון, magnifyingglass ומיון; זכוכית מגדלת פותחת inline search by bookTitle בלבד. ניקוי/סגירה מחזירים הכל בלי לשנות query או scope.
- [ ] Zero results, filter zero, missing index, error, search in progress ו־Load More error מובחנים חזותית ותפקודית.
- [ ] תוצאות אינן stale אחרי שינוי mode/backend/books, stop cancels actual work; Search submit אינו מוכפל, אין deadlock או race.
- [ ] Snippets עם highlight, references, version selector, context menu, copy with source, expand preview, search in book, reader navigation and stable locators נשמרים.
- [ ] Paging מעל 50/100, מסנן תוצאות מקומי עם paging, all results counts תואמים למודל; אין אובדן results שהגיעו מאוחר יותר.
- [ ] Saved results מוצגות רק כשהן נתמכות; אין stale/broken data; שמירה וטעינה מחדש מאומתות לכל backend הנתמך.
- [ ] iPad 11-inch, portrait+landscape, Stage Manager narrow, iPhone compact, external/soft keyboard, RTL, Dynamic Type, VoiceOver, Reduce Motion/Transparency.
- [ ] Regression: Otzaria, Zayit, Sefaria legacy/embedded, Reader, TOC, inspector, bookmarks, annotations, history, library navigation, installed indices/offline.
- [ ] Upstream protection: קובץ/מחבר/בעלות, diffs, registration ו־rollback מתועדים; לא שונו DB/תלויות/פרופילי נתונים.
- [ ] Git SHA זהה ל־build/tests/screenshots; מקור מדויק של ריצות; Simulator PASS אינו Physical iPad PASS. אין לסמן DONE אם device acceptance לא בוצע.
- [ ] לא בוצעו merge, release, CI יקר, IPA/TestFlight/App Store או פעולות נתונים ללא הרשאת הבעלים הנדרשת.

## 10. מה יידרש כדי לסמן DONE

- Source changes מוגבלים ומשוחזרים, רכיבי UI ונקודות חיבור נקיות + ownership ledger.
- Screenshots/videos משלושת מצבי screen + sidebar open/close + advanced popover + inline result filter בשפות/רוחבים רלוונטיים.
- תוצאות בדיקות פרטניות וצילומי QA עם Git SHA/Xcode/iPadOS, failure/NOT_RUN/BLOCKED אמיתיים.
- אישור QA נפרד בעת הצורך ובדיקות iPad פיזיות למקרים המחייבים; לא מסמנים "הושלם" לפי docs, build, syntax או CI בלבד.
- אין התחייבות שהמסמך עצמו הועלה לענף Git מרוחק או מוזג. זהו מסמך Markdown **במחשב** בפרויקט; יש לבצע Git add/commit/push רק בהוראת מנהל, בהתאם להרשאות, branch safety ו־no merge.

## 11. הפניות וקריאה חובה למבצע

- DESIGN_LANGUAGE.md — צבעים, טיפוגרפיה, תבנית רכיבים מקורית.
- AGENTS.md; PROJECT_AGENT_GUIDANCE.md — גבולות שינוי.
- docs/architecture/UPSTREAM_INTEGRITY_POLICY.md; UPSTREAM_EXCEPTION_REGISTER.md.
- docs/ai-team/ASANA_POLICY.md — עדכון Asana רק בעקבות הרשאה מפורשת.
- docs/features/search/ios.md, index.md; Source/Features/Search/iOS/*; Source/ZayitSearch/UnifiedSearch*.
- משימת היסטוריה: https://app.asana.com/1/1219597879016953/task/1220120889353811
- משימת Library CommandPalette (שונה): https://app.asana.com/1/1219597879016953/task/1220036884173010
- רגרסיות 11201: https://app.asana.com/1/1219597879016953/task/1220539630830553
- חפ״ק Search: https://app.asana.com/1/1219597879016953/task/1220541059190159
- Apple SDK בזמן מימוש: NavigationSplitViewVisibility, UISearchTextField, UIViewRepresentable, Button glass, ToolbarItemGroup, Menu, popover/sheet, SwiftUI Form, ContentUnavailableView, SF Symbols.

## 12. מסירה למנהל — ההנחיה המדויקת

קרא מסמך זה במלואו ואת משימת Asana המקושרת. מדובר ב־**Global Search Tab** (טקסט הספרים), לא Library Search/CommandPalette/Book Search. בדוק את מצבו העדכני של גל העבודה, את worktree/branch/SHA, leases ובעלות קבצים. בחר implementer עצמאי עם scope מבודד, והפעל QA לפי מדיניות הצוות. בנה את הממשק שהבעלים אישר: קלט יחיד עם Filters Glass משמאל, שורה עדינה 'כל הספרים' מימין ו־Mode משמאל, Sidebar נייטיבי, ResultsHeader עם חיפוש־לפי־ספר ומיון, History בתוך התוכן, Form מתקדם, Glass רק לפקדי בקרה ושפת העיצוב המקורית לשאר. שמור על כל היכולות וה־upstream, בדוק על SDK ומכשירים/סימולטור עם הוכחות. אל תדווח יותר מדי; דווח במיילסטונים מהותיים בלבד. המשימה נשארת OPEN עד QA אמיתי, ואין לבצע CI/IPA/TestFlight/merge ללא הרשאה מתאימה.


## 13. משימת המימוש ב־Asana

- משימת מקור קנונית חדשה (נוצרה ב־15.11.2026, OPEN/PLANNED): https://app.asana.com/1/1219597879016953/project/1219602719070493/task/1220546245946205
- המשתמש ביקש לשמור את המפרט כאן ולמסור למנהל הסוכנים; המימוש לא הוקצה ולא הושלם במסגרת כתיבת המסמך.

# אוצריא — נקודת עבודה פעילה, 20.11.2026

Status: IN_PROGRESS. המשך הביצוע מאושר; אין לבקש אישור חוזר. תנאי הקבלה המקוריים נשמרים. דוח OWNER_HANDOFF_20261119.md נשאר היסטורי ולא נערך.

## המקור וההרצה שנשלחו

- מקור האפליקציה והבדיקות: c61213d9fcc8b80a8606ba00a1562215312ca2ed.
- הקפאה מלאה: 0ade6b47708c47cc26932105eb6de7743539b3bc, בענף codex/otzaria-occurrence-app-20261120.
- Native13: checkout d8cc18f80e905c66d73963951efac53b43a12080, ענף קפוא codex/otzaria-native88-repair13-20261120.
- GitHub run44692780853: https://github.com/davidpovarsky/Maktabah/actions/runs/44692780853 ; בבדיקה הראשונית QUEUED. watcher יחיד job_ddc544e0318b, החל07:12:33 UTC, מוגבל3380 שניות, בבעלות asana_audit.
- נבחרו13 בדיקות מקוריות:8 iPad/5 iPhone, כולל Notes/Search/Commentary/Count בשני המכשירים, History, Profile Color ו־Window/HID. כל92 declarations/oracles נשארו במניפסט; diagnostic_only=true.
- בענף המלא נשמרו92 Native (72/20), וכל96 UI+2 oracles של Release. אין להעביר קבלת שלב מלא מתוצאת subset.
- Source closure וה־oracle המלא, declarations92/13 ו־Release96+2 עברו בפועל. Windows parse של הקובץ המשולב עבר; Apple/Native על המקור החדש עדיין דורשים תוצאה.

## תיקונים שנשמרו במקור המשולב

269d0216: שאילתות המקור הועברו גם לקבוצות Core Search; בדיקת הקלטים בפועל2/4→4/4 ושבע בדיקות oracle מקוריות PASS. אותה SQLite מקורית נשארה ללא שינוי. פעולת עריכת הפרופיל נבחרת בתפריט המקורי לפי hierarchy/pencil/label; AX המקורי הבחין בין2 כפתורים. כל שאר assertions נשמרו.

d05fbdd1: Study Tools נפתח דרך overflow מקורי בחלון צר, תוך שמירת HID/locator/panel/restoration.

944031be: History readiness דורש את השאילתה המקורית ב־plist של ההתקנה המקורית לפני terminate ובאותו90s.12 בקרות Foundation עברו לאחר RED9/12 ותיקון השוואת נתיב. אין שינוי production; סיבת כשל Native88 עדיין לא הוכחה.

83c1198b: Commentary setup פותח ספר שונה ב־newTab לפי חוזה הבעלים המקורי. fa32d4d3: אבחנות DEBUG בלבד של Note witness לפני cleanup. Notes עדיין FAILED ב־Native88; אין תיקון מוצר מוכח.

58b32dc2: מינימום iOS13 ב־Core Package, בעקבות כשל device בפועל ב־iOS12. Original SDK e00498e33f106cc43be0476ffa2e09329c8ca300 נשמר.

9a1c0112/7021f220: R27 hash53f9…9de9b נשמר; סיווג full-phase כולל9+83 רק אחרי כל guards, ו־diagnostic נשאר subset. ארבע בקרות classification עברו, Native0.

## הרצות וראיות נפרדות

Native88 run44657116407:70 עלי iPad מאומתים,46PASS/24FAIL.18 תוצאות iPhone סופיות לא אומתו עקב cutoff; partial log7pass/8fail אינו מועבר ל־PASS. ראיות982793cb.

b07 Native92 run44684611471 ו־Release96 run44684629656 בוטלו לפני ביצוע, כשה־runtime jobs היוQUEUED. אין watcher פעיל שלהם ואין לחדש או לשנות את ענפיהם.

SDK b07 run44684593065 SUCCESS: ראיות359524dc,112 source bindings ו־424 Hanlin blobs. אין מכך Native PASS.

Full-v32 d5 run44684680952, exactb07: queued בבדיקה האחרונה. watcher יחיד job_de4613c9787d התחיל06:58:44 UTC,3380s, בבעלות hanlin_api_integration. אין dispatch נוסף. Original265 full-v32 run44663283836 כבר עבר בפועל; אין להעביר את הוכחת265 לבדיקותd5 שטרם בוצעו.

Repair12 הישן run44673191816, checkout6030087e/app461: watcher job_0f3f80b10d8c בבעלות asana_audit; עדיין אין תוצאה סופית בזמן כתיבת העדכון.

Release הישן run44665679661, checkout9cc34660/app7e: FAILED. watcher Root job_f7f46372f694 הסתיים07:04:28, אין לחדש. asana_audit אוסף artifact14608089579 (69,365,070B, SHA9cbc4b9b7a3fa7195430bbeb987094ac1fbc6398805641fd79981cd8f4953e63) ותוצאות96+2. Captures14608653727 הוא3.11GB ויש לקרוא ranges בלבד לפי צורך.

## עבודה ממשיכה

2f74d05b1cf75597b3a38fa64d0939b45caa44c2 מוכן לשילוב: תיקון fixture של Inspector standalone בלבד. התשובה המלאה הידועה3 מסומנת eq, לצד10 assertions על lower-bound/empty/exact. המקור הישן נתקע120s, traced102 assertions לפני scoped fallback; לאחר התיקון controlled448 assertions+6 stages PASS3.516s ו־current6 stages PASS3.390s. Source/SDK לא נערכו; macOS עדיין נדרש. יש לשלב עם58b ואז normal iOS run יחיד על source מעודכן.

github_native_audit מממש Release orchestration בשלושה jobs: build/prototype → original Debug matrix → original production Release/final strict gate. הבינארי ו־xctestrun המקוריים יעברו עם אימות hash/source/run/attempt/Xcode. ה־runner הוא GitHub-hosted ולכן מוגבל6h/job. אין שינוי96+2/600s/oracles.

לאחר Native13 יש לקרוא קודם Notes witness ו־History metadata/persistence diagnostics, לתקן רק סיבה שהוכחה ולהמשיך לבדיקות המקור החדשות. יש להשלים full92/Release96+2, normal iOS וה־full-v32 הרלוונטיים לפני קבלת התנאים ומיזוג סופי.

הענף הראשי של ההמשך codex/otzaria-completion-20261120 נשאר5c108887; יעד המיזוג המקורי fix/maktabah-search-detail-unification. אין לאפס או למזג main זר ללא בחינת היסטוריה.

## Asana וחסמים קיימים

האודיט האחרון:81 משימות,61OPEN/20DONE; אין לסגור משימה לפני כל תנאי הקבלה. Root עדכן7 משימות רלוונטיות07:13 UTC עם Native13 והמקורות, כולןOPEN. המשך append בטוח עם fresh get; Core קרוב למגבלת טקסט ולכן לשמור עדכונים קצרים ולהפנות ל־API/R05.

בדיקות מכשירים פיזיים/Stage Manager/VoiceOver/Siri/Shortcuts/ביצועים פיזיים ובטא דורשות סביבה שאינה זמינה כאן. Books Updates חסר manifest ספק של מקור/יעד/מיגרציה; CrossApp חסר transport/editor/שני מכשירים. לשמור blockers מדויקים ללא PASS.

יש לנטר רק watcher יחיד לכלrun. WATCH_TIMEOUT אינו תוצאתworkflow. לפני חידוש finite watcher לוודא שהקודם הסתיים, שאין PID/gh watcher תואם, ושה־head נשאר מדויק. אין להוריד captures מרוביGB לדיסק Windows. אין לשנות DB/index/SDK מקוריים.

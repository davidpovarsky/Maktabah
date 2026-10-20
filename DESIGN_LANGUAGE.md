# Maktabah — Original Visual Design Language and Typography Specification

**Reference catalog | iOS / iPadOS | 20 October 2026**  
**Document type:** a reusable, descriptive design-language specification, **not** a redesign brief, agent prompt, implementation plan, task list, or request to change code.  
**Coverage:** original app palette, backgrounds, typography, font resources, styles, manual visual treatments, component-level appearance measurements, and the interface between the host app and shared `TorahInspectorKit` UI.  
**Structural scope:** existing ChavrusaText/Maktabah/Otzaria screen composition, tabs, sheets, split views, inspector, gestures, placement, and behavior are independent of this specification and remain the project's chosen interface.

## 0. Source provenance and how to use this catalog

| Evidence | Repository / immutable revision | Interpretation |
| --- | --- | --- |
| **U — Original app** | [`bismillah-100/Maktabah`](https://github.com/bismillah-100/Maktabah), `main` at [`a0ed0df908a6cb38bc459d4baaeb400f447b2fc4`](https://github.com/bismillah-100/Maktabah/commit/a0ed0df908a6cb38bc459d4baaeb400f447b2fc4) | Canonical original look-and-feel reference; the actual upstream parent of our GitHub fork |
| **H — Our host app** | [`davidpovarsky/Maktabah`](https://github.com/davidpovarsky/Maktabah), `fix/maktabah-search-detail-unification` at `abbaab54b49fb4f577638bc16712be542295b672` | Our distinct implementation and the place where application-specific visual decisions belong |
| **K — Shared UI package** | [`davidpovarsky/TorahInspectorKit`](https://github.com/davidpovarsky/TorahInspectorKit), commit `157676f511990756fa4cd8337c744903d4dc9ef6` | Revision found in the *current observed host project file*; inspect the actual pin again if the host branch changes |

**Source links:** original source files below are relative to [`bismillah-100/Maktabah` at the pinned SHA](https://github.com/bismillah-100/Maktabah/tree/a0ed0df908a6cb38bc459d4baaeb400f447b2fc4). The `Source/Features` and `Source/UI` hierarchy described here belongs to **upstream**; our fork reorganized much of that source into `Source/iOS`, `Source/Managers`, `Source/Otzaria`, and `Source/ZayitSearch`.

**Evidence vocabulary:** **Exact** = declaration or asset read from source. **Nominal** = hex representation of source P3 byte components; not a measured screen sRGB color. **System-derived** = platform dynamic color, appearance, text style or material, without one immutable RGB/point size. **Observed host** = verified in the fork source, not necessarily tested visually. **Unspecified** = source does not define a global answer; do not invent a value.

This is a code-source catalog, **not a pixel or screenshot audit**. It does not assert visual verification on an iPhone or iPad and does not define a new universal Hebrew font, a new global type scale, or a new design-token package that does not exist.

## 1. Visual identity: description of the existing original language

The original Maktabah is a native, text-centered reading application. Its distinctive appearance comes from (a) warm paper/sepia surfaces as an optional customized app appearance; (b) native system controls, semantic Apple text colors, SF Symbols and material; (c) separate reader-paper themes; (d) Arabic book typography separate from the interface chrome; and (e) selectively hand-styled rounded cards, input bars, state chips and thin strokes. It is **not** a single consolidated `DesignKit` with a universal `ButtonStyle`, typography scale and corner-radius token set.

A particular radius, shadow, text size, inset or SF Symbol in a component is an **original component measurement**, not necessarily a global design token. Original design elements may be used as reference for new UI while the host retains its own existing component structure.

## 2. Global application color system

### 2.1 Theme switch and semantic roles — exact source definitions

Source: [`Source/UI/iOS/MaktabahApp.swift`](https://github.com/bismillah-100/Maktabah/blob/a0ed0df908a6cb38bc459d4baaeb400f447b2fc4/Source/UI/iOS/MaktabahApp.swift), including `@AppStorage("useDefaultTheme")` (original view defaults to `false`), `setupGlobalAppearances()`, `extension UIColor`, `extension Color`.

| Semantic API | Custom light | Custom dark | `useDefaultTheme = true` | Use in original |
| --- | --- | --- | --- | --- |
| `Color.appBackground`, `UIColor.appBackground` | **RGB(237,217,184) / `#EDD9B8`** (Exact sRGB-style initializer) | `UIColor.bgSepiaDark.adjustBrightness(to: 0.60)` | `UIColor.systemGroupedBackground` | Principal app canvas, full-background containers |
| `Color.appCellBackground`, `UIColor.appCellBackground` | `BgSepia` asset, **nominal Display P3 RGB(239,227,204)** / `#EFE3CC` | `bgSepiaDark.adjustBrightness(to: 0.80)` | `UIColor.secondarySystemGroupedBackground` | Grouped cell/card surfaces |
| `Color.appSecondaryBackground`, `UIColor.appSecondaryBackground` | **RGB(229,217,194) / `#E5D9C2`** | `bgSepiaDark.adjustBrightness(to: 0.85)` | `UIColor.secondarySystemBackground` | Headers and toolbars, secondary chrome |
| `Color.iosTint` asset | **sRGB(0.612,0.478,0.306)** ≈ `#9C7A4E` | **sRGB(0.913,0.756,0.603)** ≈ `#E9C19A` | `.themeTint()` chooses `nil` instead of custom color | Custom-theme control tint |
| `.primary` / UIKit `.label` | Platform dynamic primary | Platform dynamic primary | Platform dynamic primary | General readable labels/body text |
| `.secondary` / `.secondaryLabel` | Platform dynamic secondary | Platform dynamic secondary | Platform dynamic secondary | Metadata, hints, subdued titles |
| `Color.accentColor` | Not defined by an explicit fixed `AccentColor` value in checked asset | Same caveat | Depends on system/app environment | Used by selected states in certain components; **do not assume it always equals `iosTint`** |

**Critical color semantics:** `.iosTint`, `.accentColor`, `HeaderColor`, and a reader-highlight color are **different source concepts**. The source occasionally uses hard-coded system colors for specific states (e.g., green active-tab dot, red destructive action, blue swatch selection). They are *local component styling*, not global brand tokens.

`UIColor.adjustBrightness(to:)` scales HSV brightness by the supplied ratio after `getHue`; it falls back to scaling grayscale white when necessary. **The dark theme values are expressions, not hard-coded hex swatches**: evaluating them as fixed hex is an approximation and should not replace the source semantic colors.

### 2.2 Full source color-asset inventory

Actual files: `Source/Assets.xcassets/<name>.colorset/Contents.json`. The table records the asset's declared color space and components; do not conflate Display P3 nominal RGB with a color-managed screenshot conversion.

| Asset | Light/universal declaration | Dark declaration | Role/observation |
| --- | --- | --- | --- |
| `AccentColor` | Contains an idiom entry but **no declared RGB color** | No explicit dark value | No source-defined fixed accent hex |
| `BgDark` | sRGB byte components **(24,24,24)**; `#181818` | Same | Dark reader-paper preset |
| `BgGray` | sRGB byte components **(90,90,90)**; `#5A5A5A` | Same | Gray reader-paper preset |
| `BgSepia` | **Display P3** bytes **(239,227,204)**; nominal `#EFE3CC` | Same asset | Warm cell/reader preset |
| `BgSepiaDark` | **Display P3** bytes **(64,59,49)**; nominal `#403B31` | Same asset | Base for custom dark app surface calculations |
| `FontResize` | sRGB `(0.820,0.524,0.179)` ≈ `#D1862E` | sRGB white | Specific font-resize/icon treatment |
| `HeaderColor` | sRGB `(0.711,0.373,0.021)` ≈ `#B55F05` | sRGB `(0,0.576,1)` ≈ `#0093FF` | Emphasized reader headings via `TextViewState.boldAttributes` |
| `HighlightBlue` | sRGB byte `(0,188,255)` = `#00BCFF` | Same | Blue user highlight choice |
| `HighlightText` | sRGB `(0,1,0)` = `#00FF00` | sRGB `(0.596,0.309,0.071)` ≈ `#984F12` | Named highlight/selection resource; **its light value is green** in source, not blue despite other highlight asset names |
| `iosTint` | sRGB `(0.612,0.478,0.306)` ≈ `#9C7A4E` | sRGB `(0.913,0.756,0.603)` ≈ `#E9C19A` | Custom application tint |

The `BgDark`, `BgGray` and nominal P3 entries above use the same component order as the asset's `red`, `green`, `blue` keys. If the asset is replaced in the future, the asset itself is authoritative over this dated table.

### 2.3 Native chrome and theme behavior

- `ThemeTintModifier`: `.tint(useDefaultTheme ? nil : Color.iosTint)`.
- `ThemeScrollContentBackgroundModifier`: `.scrollContentBackground(useDefaultTheme ? .visible : .hidden)`.
- `UINavigationBar.appearance().tintColor`: custom `.iosTint` vs system (`nil`); legacy navigation appearance customization is guarded to **before iOS 26**.
- `UITabBarAppearance`: original custom surface uses `appSecondaryBackground`; system theme retains native bar background.
- On an iPad the reader's chosen dark/light reading context can influence `preferredColorScheme`; the reading-background setting is not identical to the global custom/system app-theme switch.
- Specific iOS 26+ prominent controls may use `.glassProminent`; a fallback branch uses `.borderedProminent`. This is a **specific implementation**, not a global glass-card style.

## 3. Original theme components and styling helpers

Primary source: [`Source/UI/iOS/Theme/ThemeComponents.swift`](https://github.com/bismillah-100/Maktabah/blob/a0ed0df908a6cb38bc459d4baaeb400f447b2fc4/Source/UI/iOS/Theme/ThemeComponents.swift).

| Source component/modifier | Styling semantics observed in source |
| --- | --- |
| `ThemeList(isGrouped: false)` | Native SwiftUI `List`, `.plain`, themed row backgrounds, theme tint and scroll-background handling |
| `ThemeList(isGrouped: true)` | Native `List`, `.insetGrouped`, themed cell-row surface |
| `ThemeForm` | Native `Form` with `.themeTint()`, controlled scroll content background, main app background |
| `ThemeSection` | Native `Section` with row fill `appCellBackground` in grouped mode or `appBackground` otherwise |
| `ThemeView` | `ZStack` with `Color.appBackground.ignoresSafeArea()` plus content and theme tint |
| `ThemeVStack` / `ThemeHStack` | Regular SwiftUI stacks with app-background and tint |
| `ThemeScrollView` | Regular scroll view with themed background and tint |
| `.themeTint()` | Dynamic custom/source theme tint, or system default |
| `.themeScrollContentBackground()` | Hide system scroll surface only in custom theme |
| `.themeBackground()` | Apply `appBackground` |
| `.themeListRowBackground()` | Apply `appCellBackground` to list rows |
| `.themeListBackground()` | Apply `appBackground` to list rows |

**Important ontology:** These are concrete wrappers and modifiers in upstream, *not* evidence of a complete standalone button/icon/typography design system. Other original components often specify their own padding, shadows, font roles and backgrounds directly.

## 4. Typography — two distinct systems

### 4.1 Native application UI typography

Menus, navigation, preferences, annotations metadata, status and many button labels use **Apple semantic text styles** rather than a proprietary sans-serif typeface: `.title3`, `.headline`, `.subheadline`, `.body`, `.footnote`, `.caption`, `.caption2`, sometimes `.fontWeight(.semibold)` or `.bold()`. UIKit views also use `UIFont.preferredFont(forTextStyle: .body)` and semantic foregrounds.

These are **semantic platform font styles**, which dynamically resolve to actual point sizes according to the user's accessibility and system configuration. Source does **not** support declaring a single fixed, app-wide `title = 24 / body = 17 / caption = 12` pixel system. `Font.system` also appears in individual bespoke components.

### 4.2 Arabic literary / book-content typography (original only)

| Usage in original | Code source | Exact source declaration |
| --- | --- | --- |
| Default main reader face | `Source/Core/TextProcessing/TextViewState.swift`, `Source/Core/Configuration/UserDefaults.swift` | `"KFGQPC Uthman Taha Naskh"` |
| New reader font size with no saved positive value | `TextViewState.init()` | **19pt** |
| Search excerpts/compact content | `ReaderViewModel.kfgqpc` | `Font.custom(KFGQPC..., size: 16)` |
| Search result / TOC titles | `ReaderViewModel.kfgqpcTitle` | `Font.custom(KFGQPC..., size: 18)` |
| Library/history book label | `ReaderViewModel.kfgqpcList` | `Font.custom(KFGQPC..., size: 20)` |
| UIKit book-list label | `ListContentConfiguration.font` | `UIFont.arabicFont(size: 20)` fallback to preferred `.body` |
| Book-info text UIKit view | `iOSBookInfoView.swift` | `UIFont.arabicFont(size: 22)` |
| Reader paragraph style | `TextViewState.paragraphStyle` | Paragraph-before spacing **2pt**; right alignment; RTL base writing direction; `lineHeightMultiple = lineHeight` |
| Reader normal text color | `TextViewState.defaultAttributes` | UIKit `.label` or AppKit `.labelColor` |
| Emphasized reader-heading text | `TextViewState.boldAttributes` | `HeaderColor` asset |
| Annotation editor multiline input | `iOSAutoDirectionTextView` | `UIFont.preferredFont(forTextStyle: .body)`, `.label` text, clear background |

Source paths: [`ArabicFont.swift`](https://github.com/bismillah-100/Maktabah/blob/a0ed0df908a6cb38bc459d4baaeb400f447b2fc4/Source/Core/Configuration/Typhography/ArabicFont.swift), [`ReaderViewModel.swift`](https://github.com/bismillah-100/Maktabah/blob/a0ed0df908a6cb38bc459d4baaeb400f447b2fc4/Source/Features/Reader/ViewModel/ReaderViewModel.swift), [`TextViewState.swift`](https://github.com/bismillah-100/Maktabah/blob/a0ed0df908a6cb38bc459d4baaeb400f447b2fc4/Source/Core/TextProcessing/TextViewState.swift), [`iOSBookInfoView.swift`](https://github.com/bismillah-100/Maktabah/blob/a0ed0df908a6cb38bc459d4baaeb400f447b2fc4/Source/Features/Reader/iOS/iOSBookInfoView.swift).

**Do not confuse original `KFGQPC...` with a Hebrew typography standard.** The original Maktabah source does not establish an approved Hebrew body font, Hebrew heading face, Hebrew-specific scale, or niqqud rules. Those are **host project design decisions still to be documented from the host itself**; the original source only supplies hierarchy, color, relative sizes and how text roles are separated.

### 4.3 Bundled and available Arabic font families

Original `ArabicFont` enumeration contains:

- `KFGQPC Uthman Taha Naskh`
- `Scheherazade New`
- `Lateef`
- `Lateef Bold`
- `Geeza Pro`
- `Damascus`
- `Al Bayan Plain`
- `Baghdad`
- `Nadeem`

Files in `Source/Core/Configuration/Typhography/Fonts/` include `UthmanTN1-Ver10.otf`, `Lateef-Regular.ttf`, `Lateef-Bold.ttf`, and `ScheherazadeNew-Regular.ttf`. Font registration attempts also include `NotoNaskhArabic-Medium.ttf` (availability must be checked in the relevant build/bundle; do **not** infer every enum case is shipped as a bundled font). `UserFontManager` can import `.ttf`/`.otf` user fonts and register them from a `CustomFonts` documents directory.

**Font-identifier discrepancy in original:** `UIFont.arabicFont(size:)` in `ListLayoutMetrics.swift` calls `UIFont(name: "kfgqpcUthmanTahaNaskh", ...)` (lowercase identifier), while `ArabicFont.kfgqpcUthmanTahaNaskh.rawValue` is `"KFGQPC Uthman Taha Naskh"`. The helper has a preferred-body fallback, so the actual runtime typeface must not be inferred solely from its lowercase string.

### 4.4 Reader typography preferences and controls

Source: [`ViewOptionsView.swift`](https://github.com/bismillah-100/Maktabah/blob/a0ed0df908a6cb38bc459d4baaeb400f447b2fc4/Source/Features/Reader/iOS/ViewOptionsView.swift).

| Visual element or value | Original value |
| --- | --- |
| Typeface selection | Native `Picker` using `ArabicFont.allCases` plus imported user font names |
| Size slider visual range | **12–48pt, step 2pt** |
| `TextViewState.changeFontSize(by:)` clamping | **14–48pt**; does **not** perfectly match slider's lower bound |
| `A` examples flanking size slider | **12pt** and **24pt** system font |
| Line-height choices | **1.0 / 1.1 / 1.2 / 1.3 / 1.4 / 1.5** (`lineHeightMultiple`) |
| Reader color-choice circles | **30×30pt**, horizontal gap **20pt**, **8pt** vertical inset |
| Selected color-choice stroke | **3pt blue**; unselected **1pt secondary** |
| Reader display toggles | Harakat, clickable annotations, enhanced underlining |
| Text type selector interface | `ThemeForm` + `ThemeSection` and native controls |

The source exposes a user-configurable `lineHeight`, not one immutable global reader line-height value. Where the preference is unset, runtime defaults/registration must be inspected before declaring a fixed default.

## 5. Reader-paper palettes and highlight colors

### 5.1 Independent reader background presets

Source: [`BackgroundColor.swift`](https://github.com/bismillah-100/Maktabah/blob/a0ed0df908a6cb38bc459d4baaeb400f447b2fc4/Source/Features/Reader/Models/BackgroundColor.swift). Reader theme presets are **independent from** `appBackground` and `useDefaultTheme`.

| Enum case / raw order | Color role | `BackgroundColor.isDark` |
| --- | --- | --- |
| `white` / 0 | `.white` | `false` |
| `sepia` / 1 | `.bgSepia` | `false` |
| `gray` / 2 | `.bgGray` | `true` |
| `darkSepia` / 3 | `.bgSepiaDark` | `true` |
| `black` / 4 | `.bgDark` | `true` |

### 5.2 User highlights, underlining and source-specific emphasis

Source: `Source/Core/Configuration/UserDefaults.swift`, `Source/Core/TextProcessing/TextViewState.swift`, `Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift`.

- Original initial highlight palette, in order: **system yellow**, **system green**, `HighlightBlue`, **system pink**, **system purple**.
- Original initial underline palette, in order: **label color**, **system red**, **system blue**, **system green**, **system orange**.
- Recent highlight and underline colors are persisted separately, normalized/de-duplicated and capped at **5**.
- For an underline, stored black or empty color is semantically mapped to **primary/label**, not blindly rendered as fixed black (`Color.effectiveAnnotationColor`).
- Editor swatches are **28×28pt** circles, spacing **8pt**, 1pt secondary stroke plus **2pt** selection ring in app accent around a 2pt gap.
- Heading emphasis uses `HeaderColor`, separate from custom action tint and underline/highlight user palettes.
- Text selection and highlighted excerpts involve precise range mappings; their *visible treatment* is a style item while their text indices are implementation state, not part of this design catalog.

## 6. Reusable original visual motifs and manual components

This is the principal **hand-styled component inventory**: what was manually styled, with source-authoritative details. Measurements refer to the **specific source component**, not a universal token collection or an instruction to reproduce its screen layout.

### 6.1 Hierarchical library rows and source list treatment

Sources: `Source/UI/iOS/Views/Common/{ListLayoutMetrics,ListContentView,BaseHierarchicalListViewController}.swift`; `Source/Features/Library/iOS/iOSLibraryView.swift`.

| Style attribute | Original implementation |
| --- | --- |
| Base cell inset | **16pt** |
| Hierarchy indentation step | **32pt** |
| Book/accessory image slot | **30pt** width |
| Image/accessory gap | **8pt** |
| Chevron slot | **16pt** width |
| Minimum row height | **50pt**, minimum constraint (not fixed exact height) |
| Book-label source font | **20pt** Arabic helper, fallback preferred body |
| Title text color | `.label` or `.secondaryLabel` according to source content/download state |
| Expand chevron | `chevron.left` source symbol configured at **13pt bold** and transformed on expand |
| Selected/focused row | UIKit list background configuration with dynamic theme roles |
| Separators | Native/compositional UIKit separators; insets derived from `ListLayoutMetrics`, not a single literal everywhere |

The original cell forces `.forceLeftToRight` for some UIKit stacks while right-aligning Arabic titles. That is a **specific historical layout solution**, not a visual-style or Hebrew font token.

### 6.2 Table of contents / nested text rows

Sources: `Source/Features/Reader/iOS/Toolbar/{iOSTOCView,TOCNodeRow}.swift`.

- Text title: source content-specific `kfgqpcTitle`, **18pt**; selected row foreground `.accentColor`, other rows `.primary`.
- Nested TOC indentation: **24pt** per level (separate from library list's 32pt).
- Expand button: **32×32pt** hit area, internal chevron image **16×16pt**, SF Symbol **14pt semibold**, secondary color.
- Lists use `ThemeList(isGrouped: true)` and native searchable style; the font and selected color are the transferable visual facts.

### 6.3 Rounded paper cards: history, favorites, donation, open reader tabs

Sources: `Source/Features/History/iOS/{HistoryComponents,HistoryFavoriteSections}.swift`, `Source/Features/Reader/iOS/Toolbar/iOSReaderTabsPopoverView.swift`.

| Visual detail | Verified source |
| --- | --- |
| Card fill | `Color.appCellBackground` |
| Card corner radius | **30pt** in these particular cards |
| Card shadow | Black at **0.03 opacity**, blur radius **4**, x **0**, y **2** |
| Fine outline | `.secondarySystemFill`, stroke **0.3pt** |
| History book title | `ReaderViewModel.kfgqpcList`, **20pt** |
| Individual history card | Height **50pt**; horizontal padding **12pt**, vertical **10pt** in `BookCard` |
| Horizontal history layout spacing | **10pt** card gap; 1, 2 or 3 rows based on book count |
| Favorites/donation card | Same family of paper card, with `.headline` action text and a `heart.fill` symbol |
| Reader-tabs popover row | Height **50pt**, horizontal padding **12pt**, paper card fill/stroke/shadow |
| Reader-tabs popover selected indicator | `systemGreen` brightness **0.75**, dot **10×10pt** |

These are *observed manually styled card families*, not a rule that all new cards use radius 30.

### 6.4 Compact inline reader-tab strip

Source: `Source/Features/Reader/iOS/Toolbar/ReaderTabItemView.swift`.

- Strip is a horizontally scrollable source component with **4pt** gap between tabs.
- Outer strip corner radius **30pt**; active tab pill radius **20pt**, fill `.tertiarySystemFill`.
- Title is native-weight `.medium` for active and `.regular` for inactive; active foreground `.accentColor`, inactive `.primary`; source title maximum width **250pt**.
- Close icon is `xmark`, originally about **9–10pt** depending on compact height, with a small filled circular backing.
- The source intentionally differs from the larger 30pt paper cards in 6.3.

### 6.5 Custom global-search input bar

Source: `Source/Features/Search/iOS/SearchComponents.swift`, `SearchInputBar`.

| Part | Exact original styling |
| --- | --- |
| Field surface | `Color.appCellBackground` |
| Height | **40pt** |
| Shape | Rounded rectangle radius **20pt** (pill) |
| Stroke | `.secondary`, **0.3pt** |
| Text content insets | Leading **20pt**, trailing **44pt** |
| Action icon | SF Symbol `play.fill`, with trailing **20pt** inset |
| Prompt icon/text tint | Custom `iosTint` or system secondary depending on mode |
| Shadow | Black opacity **0.15 focused / 0.10 unfocused**; blur **8 focused / 15 unfocused**; y **2** |
| Container padding | Horizontal **20pt**, system `.vertical` padding |

Other `SearchModeView` `.searchable` system search controls **do not automatically share this handmade bar geometry**.

### 6.6 Search overlays, results and progress

Sources: `Source/Features/Search/iOS/{SearchComponents,SearchModeView,SearchResultsListView}.swift`; `Source/Features/Reader/iOS/Toolbar/iOSBookSearchView.swift`.

- Search history floating overlay: `appBackground`, radius **12pt**, shadow radius **10pt**, maximum height **260pt**; its header uses `appSecondaryBackground`, native `.caption`/secondary text styles.
- Search result titles: original content font `kfgqpcTitle` (**18pt**); excerpts/snippets `kfgqpc` (**16pt**); metadata `.caption` and `.secondary`.
- General progress banner: `.ultraThinMaterial` in one `SearchProgressView` treatment.
- Migration/status card in `SearchModeView`: `appBackground`, rounded rectangle **32pt**; content can use `.subheadline`, `.caption`, yellow status symbol, green action tint.
- Search-within-book migration notification: system secondary background, corner radius **10pt**, small shadow blur **2pt**, blue action tint in this local context.
- A dedicated `ProminentButtonStyle` uses `.glassProminent` on supported iOS26+ and `.borderedProminent` otherwise.

### 6.7 Reader canvas, selectable text and tool popovers

Sources: `Source/Features/Reader/iOS/iOSReaderView.swift`, `Source/UI/iOS/Wrappers/iOSIbarotTextView.swift`, `Source/Features/Reader/iOS/Toolbar/{iOSReaderBottomToolbarView,iOSReaderNavigationPopoverView}.swift`.

- Reader body background is controlled by its **own** `BackgroundColor` preset, not the app's main grouped-list surface.
- The original text view is a read-only but selectable UIKit `UITextView`, clear text-view background over reader paper, with original **10pt** top/left/bottom/right text-container insets; original content is TextKit 2-backed.
- Normal text is `.label`; reader heading accent uses `HeaderColor`; annotations can use user highlight/underline palettes.
- Reader toolbar controls use system symbols and native toolbar placement. Examples: `magnifyingglass`, `ellipsis`, `chevron.left`, `chevron.right`, `info.circle`.
- Navigation popover source width **300pt**, `presentationBackground(Color.appBackground)`, native `.headline`/`.caption`/`.caption2` type roles.
- Text options popover source frame **300×500pt**. Its visual settings are listed in 4.4.
- The reader's book title often uses native navigation typography (`.inline`), not the custom Arabic book-body font everywhere.

### 6.8 Annotation views and manual filter chips

Sources: `Source/Features/Annotations/iOS/iOSTagFilterHeaderView.swift`, `Source/Features/Reader/iOS/{iOSAnnotationEditorSheet,iOSBookInfoView}.swift`, `Source/Features/Reader/iOS/Toolbar/iOSBookAnnotationsView.swift`.

- Annotation-editor palette: circular swatches **28×28pt**, custom selection outline, separate recent highlight/underline colors; body entry uses native preferred font.
- Annotation list: original text context uses 18pt content font; supplementary labels `.caption`/`.caption2` secondary, small colored annotation badge/dot (source example **12×12pt**).
- Tag-filter chip row: `chipsStackView.spacing = 6`; header's root horizontal stack spacing **8**; source UIKit row height **32pt**; each chip uses `UIButton.Configuration.bordered()` with `.cornerStyle = .capsule`, `.buttonSize = .medium`.
- Selected tag chip shows SF Symbol `circle.fill` (symbol configuration **6pt semibold**) with image/text spacing **4pt**; the filter mode button uses `.filled()` vs `.plain()` with a capsule corner style.
- Information sheet (`iOSBookInfoView`): `appBackground`, native `.subheadline` secondary labels; text presentation uses custom Arabic helper at **22pt** with semantic `.label` color.

### 6.9 Lightweight status surfaces, overlays, and widgets

Sources: `Source/UI/iOS/Views/Common/ActiveIntegrationStatesView.swift`, `Source/UI/iOS/Views/Bootstrap/BootstrapView.swift`, `Source/Features/Widget/Common/Components.swift`.

- Active integration states strip: `.ultraThinMaterial` with subtle slide/opacity motion in its *existing* host; style classification is a material status strip, not a paper card.
- Bootstrap full-screen surface: `appBackground` with source darkened transient modal overlay (`Color.black.opacity(0.45)`).
- Widget header: `.caption.bold()` on small family; `.headline` otherwise; `.primary` title and separately colored system symbol.
- Widget card: slim colored `Capsule` bar **3.5pt** width, **4.5pt** content gap, background `barColor.opacity(0.12)` with radius **7pt**.
- Widget Arabic content uses `NotoNaskhArabic-Medium` with source fallback; original iOS widget-family-specific sizes **14pt small / 15.5pt larger**; secondary captions about **9–10pt** based on family.
- Widget padding: **10pt** small family; **12pt** others (source `WidgetContainerView`).

### 6.10 macOS original manual controls — separate platform context

Original macOS is not the primary host being catalogued here. However the parent repository contains hand-built AppKit presentation outside the iOS theme:

| AppKit component | Source styling fact |
| --- | --- |
| `BundledArabicButton`, `BundledArabicTextField` | Use a bundled Arabic font helper, preserving existing control font size or falling back to a source default |
| `DSFSearchField`, `ClearSearchFieldCell` | Custom RTL search-recents popup and visual field cell; source uses a subtle gray alpha **0.15** fill in the clear field cell |
| `BackgroundOptions` (reader color circles) | AppKit-drawn **28×28pt** oval selection component with subtle outline and tick shape |
| `IbarotTextView`, `CachedArabicLayoutFragment` | Special-purpose text drawing and caching for literary Arabic; typography behavior differs from normal form controls |

These are separate **AppKit reference elements**, not an iOS implementation inventory. Their source files live in `Source/UI/macOS/` and `Source/Features/Reader/Models/BackgroundOptions.swift`.

## 7. Original visual-state vocabulary

| State | Examples of original appearance treatment |
| --- | --- |
| Normal textual content | Platform `.primary`/`.label`; paper surface as appropriate to component |
| Metadata/disabled emphasis | `.secondary`/`.secondaryLabel`; reduced visual weight, not a global invented opacity token |
| Selected reader TOC or tab | Source component's `.accentColor`, and optional `.tertiarySystemFill` tab backing |
| Selected annotation swatch | 2pt accent selection ring beyond 1pt outline and swatch |
| Selected book tab in popover | Small system-green dot plus accent title |
| Destructive action | Native destructive role / `.red` in local menus |
| Search field focus | Source custom shadow opacity and blur change (section 6.5) |
| Expanded source/row | Chevron transformation, selection-specific background or accent; component-local definition |
| Loading and progress | Native `ProgressView`, material strip, secondary status text; no single bespoke spinner defined by upstream |
| Theme change | Re-evaluates custom-vs-system semantic backgrounds and tint; reader-paper choices are separate |

## 8. Source identities and practical lookup by style question

| Question | Original source of truth |
| --- | --- |
| What is the warm background, paper cell or toolbar color? | `Source/UI/iOS/MaktabahApp.swift` → `UIColor.appBackground`, `.appCellBackground`, `.appSecondaryBackground` |
| What exact asset colors exist? | `Source/Assets.xcassets/*.colorset/Contents.json` |
| How is application tint resolved by theme? | `Source/UI/iOS/Theme/ThemeComponents.swift` → `.themeTint()`; `Source/UI/iOS/MaktabahApp.swift` |
| Which theme wrappers exist? | `Source/UI/iOS/Theme/ThemeComponents.swift` |
| What text style does the main UI use? | Per-feature SwiftUI view (`.headline`, `.body`, etc.); there is no single global mapping |
| What text style does literary content use? | `Source/Core/TextProcessing/TextViewState.swift`; `Source/Features/Reader/ViewModel/ReaderViewModel.swift` |
| Where do original literary fonts come from? | `Source/Core/Configuration/Typhography/ArabicFont.swift`; `.../Fonts/`; `Source/UI/iOS/Managers/UserFontManager.swift` |
| What are reader background choices? | `Source/Features/Reader/Models/BackgroundColor.swift` |
| How are highlight and underline colors selected? | `Source/Core/Configuration/UserDefaults.swift`; `Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift` |
| How are book-list cells visually laid out? | `Source/UI/iOS/Views/Common/ListLayoutMetrics.swift`, `ListContentView.swift` |
| How are rounded book cards styled? | `Source/Features/History/iOS/HistoryComponents.swift` and `HistoryFavoriteSections.swift` |
| How are reader tabs styled? | `Source/Features/Reader/iOS/Toolbar/ReaderTabItemView.swift`, `iOSReaderTabsPopoverView.swift` |
| Where is the custom search pill? | `Source/Features/Search/iOS/SearchComponents.swift` → `SearchInputBar` |
| Where are result title/metadata styles? | `Source/Features/Search/iOS/SearchResultsListView.swift` |
| Where is TOC typography and selection? | `Source/Features/Reader/iOS/Toolbar/TOCNodeRow.swift` |
| Where are annotation chips and swatches? | `Source/Features/Annotations/iOS/iOSTagFilterHeaderView.swift`, `iOSAnnotationEditorSheet.swift` |
| Where are original widget style specifics? | `Source/Features/Widget/Common/Components.swift` |

For the precise pinned upstream source, prefix these paths with:

`https://github.com/bismillah-100/Maktabah/blob/a0ed0df908a6cb38bc459d4baaeb400f447b2fc4/`

## 9. Relationship to our current host app (a reference map, not instructions)

The host fork reorganized the original source and added Otzaria, Sefaria, Zayit and Torah study UI. The examples below identify *where* original visual tokens still exist; they are not parity demands for screen type, layout or behavior.

| Design concern | Original upstream | Observed current host equivalent |
| --- | --- | --- |
| App semantic palette | `Source/UI/iOS/MaktabahApp.swift` | `Source/iOS/MaktabahApp.swift` — retains `appBackground`, `appCellBackground`, `appSecondaryBackground` semantic mapping |
| Theme helpers | `Source/UI/iOS/Theme/ThemeComponents.swift` | `Source/iOS/Theme/ThemeComponents.swift` — **same Git blob SHA** in compared commits |
| Asset palette | `Source/Assets.xcassets` | Same path; inspected `iosTint`, `BgSepia`, `BgSepiaDark`, `HeaderColor`, `HighlightText` assets have **matching blob SHA** |
| Original reading state | `Source/Core/TextProcessing/TextViewState.swift` | `Source/Managers/TextView/TextViewState.swift` — **changed** for our app, so current behavior should be read rather than assumed identical |
| Library styles | `Source/Features/Library/iOS`, `Source/UI/iOS/Views/Common` | `Source/iOS/Views` and `Source/iOS/Views/Common`; source-derived list metrics preserved in checked code |
| Main iOS UI | `Source/UI/iOS/Views/{iOSMainView,iPadLayout,iPhoneLayout}.swift` | `Source/iOS/Views/...` — intentionally different component organization and screen system |
| Reader/hosted study panels | Upstream `Source/Features/Reader/iOS/...` | `Source/iOS/Views/Reader/iOSReaderView.swift` and `iOSReaderWorkspaceView.swift` plus Kit import |
| Search appearance | Upstream `SearchComponents.swift`, `SearchResultsListView.swift` | `Source/iOS/Views/Search/...`, `Source/ZayitSearch/UnifiedSearchWorkspaceView.swift` — includes new host-specific styles |
| Otzaria-specific views | No counterpart in this upstream | `Source/Otzaria/Features/...`, `Source/Otzaria/Reading/...` — **host additions**, not original-source design tokens |

The fact that a fork component differs in structure or dimensions from the original **does not itself mean it is visually inconsistent**. Visual identity, hierarchy and colors can be evaluated independently of the host's intentional panel/tab/window system.

## 10. TorahInspectorKit appearance ownership and integration boundary

This section is a **cross-package style inventory and architectural reference**. It is **not** part of the original Maktabah visual language, nor a task to redesign either app or Kit.

### 10.1 What is actually imported in our app?

Host: `Source/Otzaria/Reading/OtzariaReaderSourcesInspectorHost.swift` imports `TorahInspectorCore` and `TorahInspectorUI` and presents `TorahInspectorUI.TorahInspectorView(...)`. `Source/iOS/Views/Reader/iOSReaderWorkspaceView.swift` embeds that host in the currently implemented study-panel/sheet arrangement. The host project file `Maktabah.xcodeproj/project.pbxproj` was observed pinning Kit to **`157676f511990756fa4cd8337c744903d4dc9ef6`** at the checked host revision.

`TorahInspectorCore` is data/models/service concern; `TorahInspectorUI` renders SwiftUI components with their own `.font`, `.background`, `.foregroundStyle`, `.tint`, border and material declarations.

### 10.2 Verified existing Kit styling (at host-pinned revision)

| Kit element | Observed in pinned Kit source | Relation to host style |
| --- | --- | --- |
| Inspector title | `.title3.weight(.semibold)` | Explicit internal SwiftUI font |
| Inspector source reference | `.caption2`, `.secondary` | Explicit internal style |
| Selected text card | `.subheadline`; `Color.accentColor.opacity(0.06)`; radius **12pt** | Accent may respond to host tint environment; type/background have internal declarations |
| Inspector floating panel | `.regularMaterial`, radius **22pt**, 1pt border `Color.primary.opacity(0.07)`, shadow black **0.035** blur **7**, y **2** | Internal surface specification, **not** `Color.appBackground` |
| Inspector main item cards | `Color.torahSecondarySystemBackground`, radius **14pt** | Kit maps this color to UIKit `.secondarySystemBackground` (AppKit `.controlBackgroundColor`) |
| Expanded source cards | `Color.accentColor.opacity(0.08)` | Uses Kit-local visual state definition |
| Commentary text | `.system(size: 15)` when commentary, often `.body`/`.caption` otherwise | Explicit fixed font inside Kit, not controlled by changing the parent `.font` alone |
| Note body | `.system(size: 18)` | Explicit internal font |
| Metadata, badges and chips | `.caption`, `.caption2`, `.subheadline`, system capsule/card visuals | Mixture of semantic and explicit per-view styles |
| UI symbols | `TorahInspectorAppearance.referenceSymbol = "book.closed"`, `.topicSymbol = "tag"` | Kit names UI symbols, **not** application palette tokens |

Source: [`TorahSegmentDetailView.swift`](https://github.com/davidpovarsky/TorahInspectorKit/blob/157676f511990756fa4cd8337c744903d4dc9ef6/Sources/TorahInspectorUI/TorahSegmentDetailView.swift), [`TorahPlatformSupport.swift`](https://github.com/davidpovarsky/TorahInspectorKit/blob/157676f511990756fa4cd8337c744903d4dc9ef6/Sources/TorahInspectorUI/TorahPlatformSupport.swift), [`TorahInspectorAppearance.swift`](https://github.com/davidpovarsky/TorahInspectorKit/blob/157676f511990756fa4cd8337c744903d4dc9ef6/Sources/TorahInspectorUI/TorahInspectorAppearance.swift).

**Current limitation identified in code:** the checked Kit has **no public comprehensive `TorahInspectorTheme` / typography-style input**. Root `.tint(...)` can influence inherited accents, and environment semantic settings can influence some native styles, **but these do not reliably override nested explicit `.font(.system(size: 15))`, `.background(.regularMaterial)` or `Color.torahSecondarySystemBackground`**. Therefore external host decoration alone cannot promise full Kit typography/background parity.

### 10.3 Appearance responsibility model (future integration reference, not an implementation order)

| Layer | Ownership of visual decisions | Kind of information it may exchange |
| --- | --- | --- |
| **Maktabah / ChavrusaText host** | Owns its actual palette, paper backgrounds, reader-font choices, Hebrew typefaces, type hierarchy, dark/system theme resolution and approved visual variant | Resolved `Color`/`Font` values or semantic host style roles |
| **TorahInspectorKit shared UI** | Owns *generic component roles* (e.g. panel surface, commentary title/body, reference text, metadata, selected card, notes body) and fallback styles that remain independent of any one app | An optional neutral style input/environment, consuming rather than inventing the host's appearance |
| **Kit core** | Owns data/selection/relationships, not app branding | No dependency on Maktabah fonts, color resources or the host's design system |
| **Other host applications (e.g. Pinkha)** | Own their *own* palette and typography | May supply different style values for the same Kit's generic roles |

**Design boundary:** the *names of semantic roles or the mechanism for passing styles* can live at the Kit API boundary; **the actual Maktabah-specific values remain entirely in Maktabah**. An API named, for example, `TorahInspectorStyle` or an environment-based style injection point would be a **neutral interface**, not a definition of Maktabah's global styles inside the shared package. The checked source does not yet implement such a full contract. The exact interface should be decided in a separate, explicitly requested design/implementation task, preserving existing Kit default appearance and other clients.

The reader's Hebrew font choice and the app's global chrome font are not identical roles. Even if a host appearance adapter is later introduced, the host must distinguish **UI labels**, **Torah quotation/primary text**, **commentary bodies**, **references**, and **notes**, rather than applying the literary body face indiscriminately to all controls.

## 11. What this original source does *not* specify

1. **No complete universal typography token map** for every UI title, body, annotation, tooltip and dialog; most UI uses Apple semantic font styles.
2. **No approved Hebrew body font name** or Hebrew/niqqud scale in the original Arabic Maktabah. Hebrew defaults must come from a separately verified host decision, not invented by this file.
3. **No universal fixed corner radius/shadow/inset**: `30`, `20`, `14`, `12`, `10`, `8`, `7` are **component-specific** original measures.
4. **No single global accent-color hex** for every use: `iosTint`, `.accentColor`, heading and annotation/highlight colors differ in source.
5. **No comprehensive built-in Kit style injection API** in the checked pinned `TorahInspectorUI` source.
6. **No runtime comparison** of actual screenshots, Dynamic Type scaling, color-managed Display P3 rendering, UIKit fallback fonts or physical iPad output in this document.
7. **No design instruction to restore upstream tab/window/inspector layouts**. The original screen arrangements are not the design tokens and do not replace the current host's intentional architecture.

## 12. Compact reference for future agents

When consulting this catalog for a newly added component, relevant style evidence consists of:

- **Main/cell/chrome surfaces:** dynamic semantic roles in §2; distinguish native-system theme and custom light/dark theme.
- **Text foreground and hierarchy:** `primary`/`secondary`, reader heading accent, native UI text styles and content-specific literary font roles (§§3–5).
- **Custom visual motifs:** particular original source components and their fills, borders, corner radii, strokes and shadows (§6); **not** a single global radius scale.
- **States:** selection, active tab, highlight, focus, destructive action, material progress and disabled/metadata (§7).
- **Our existing visual host:** checked source map (§9), including UI imported from `TorahInspectorKit` (§10).
- **Unknowns:** consult source and record gaps rather than inventing a Hebrew font or assuming inherited styles override internal Kit declarations (§11).

**Identity of the document:** a durable **source-based design and typography reference**. Specific redesign requests, agent assignments, rollout steps, implementation prompts, test plans and task status belong in separate documents.

import SwiftUI

// Native Sheet Lab — Apple SwiftUI only. No third-party dependencies.
// The iPadOS 27 presentationPlacement API is availability-gated below.

@main
struct NativeSheetLabApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

private enum SheetPlacementChoice: String, CaseIterable, Identifiable {
    case automatic, leading, center, trailing
    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: return "אוטומטי"
        case .leading: return "Leading (ימין ב־RTL)"
        case .center: return "מרכז"
        case .trailing: return "Trailing (שמאל ב־RTL)"
        }
    }
}

private enum BackgroundTouchChoice: String, CaseIterable, Identifiable {
    case throughMedium, always, disabled
    var id: String { rawValue }

    var title: String {
        switch self {
        case .throughMedium: return "עד גובה בינוני"
        case .always: return "אפשר תמיד"
        case .disabled: return "חסום מאחור"
        }
    }

    var systemValue: PresentationBackgroundInteraction {
        switch self {
        case .throughMedium: return .enabled(upThrough: .medium)
        case .always: return .enabled
        case .disabled: return .disabled
        }
    }
}

private enum SheetSwipeChoice: String, CaseIterable, Identifiable {
    case scrolls, resizes
    var id: String { rawValue }

    var title: String {
        switch self {
        case .scrolls: return "גלילה תחילה"
        case .resizes: return "הרחבה תחילה"
        }
    }

    var systemValue: PresentationContentInteraction {
        switch self {
        case .scrolls: return .scrolls
        case .resizes: return .resizes
        }
    }
}

private enum PanelMode: String, CaseIterable, Identifiable {
    case sheet, inspector, split
    var id: String { rawValue }

    var title: String {
        switch self {
        case .sheet: return "Sheet מערכתי"
        case .inspector: return "Inspector מערכתי"
        case .split: return "שתי עמודות"
        }
    }

    var symbol: String {
        switch self {
        case .sheet: return "rectangle.bottomthird.inset.filled"
        case .inspector: return "sidebar.right"
        case .split: return "rectangle.split.2x1"
        }
    }

    var hint: String {
        switch self {
        case .sheet:
            return "גרור את ידית המערכת ושנה את המיקום, הגובה והרקע. כאשר מותר, אפשר להשתמש גם בספר שמאחור."
        case .inspector:
            return "Inspector של SwiftUI: חלונית צד מקורית שהמערכת מתאימה לרוחב החלון. שנה את רוחבה באמצעות קו ההפרדה כשהמערכת מאפשרת זאת."
        case .split:
            return "NavigationSplitView המקורי של Apple: הספר והשיחה מוצגים יחד בשתי עמודות. בחר מצב אחר בלי למחוק הודעות."
        }
    }
}

private enum SheetBackgroundStyle: String, CaseIterable, Identifiable {
    case system, material, ultraThin, regularGlass, clearGlass, transparent, solid
    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "ברירת מחדל של המערכת"
        case .material: return "Regular Material"
        case .ultraThin: return "Ultra Thin Material"
        case .regularGlass: return "Liquid Glass רגילה"
        case .clearGlass: return "Liquid Glass שקופה"
        case .transparent: return "שקיפות מלאה (ללא זכוכית)"
        case .solid: return "רקע אטום"
        }
    }

    var showsReaderThrough: Bool {
        switch self {
        case .ultraThin, .regularGlass, .clearGlass, .transparent: return true
        default: return false
        }
    }
}

private struct DemoChatMessage: Identifiable {
    let id = UUID()
    let isUser: Bool
    let text: String
}

struct ContentView: View {
    @State private var showStudySheet = false
    @State private var dockedMode: PanelMode?
    @State private var showInspector = false
    @State private var pendingModeAfterSheetDismissal: PanelMode?
    @State private var transitionID = UUID()
    @State private var isTransitioning = false
    @State private var inspectorIdealWidth: CGFloat = 420

    private var isDocked: Bool { dockedMode == .split }
    private var hasDockedPanel: Bool { dockedMode != nil }
    @State private var splitVisibility: NavigationSplitViewVisibility = .all
    @State private var compactColumn: NavigationSplitViewColumn = .detail
    @State private var readerScrollPosition = ScrollPosition()
    @State private var placement: SheetPlacementChoice = .leading
    @State private var detent: PresentationDetent = .medium
    @State private var backgroundTouches: BackgroundTouchChoice = .throughMedium
    @State private var swipePriority: SheetSwipeChoice = .scrolls
    @State private var sheetBackground: SheetBackgroundStyle = .system

    @State private var readerCount = 0
    @State private var chapter = 0
    @State private var fontSize = 20.0
    @State private var bookmarked = false
    @State private var draft = ""
    @State private var messages: [DemoChatMessage] = [
        .init(isUser: false, text: "שלום! אני הדגמת שיחה מקומית. פתח את הגדרות החלונית כדי לבדוק את אפשרויות ה־Sheet של Apple."),
        .init(isUser: true, text: "אפשר לקרוא בספר כשהחלונית פתוחה?"),
        .init(isUser: false, text: "כן — כאשר Background Interaction מופעל ובאזור המסך שהחלונית לא מכסה. נסה ללחוץ על כפתור 'דפדף פרק' בספר.")
    ]

    var body: some View {
        Group {
            if isDocked {
                NavigationSplitView(
                    columnVisibility: $splitVisibility,
                    preferredCompactColumn: $compactColumn
                ) {
                    chatPanel(mode: .split)
                        .navigationSplitViewColumnWidth(min: 320, ideal: 420, max: 600)
                } detail: {
                    readerWorkspace
                }
                .navigationSplitViewStyle(.balanced)
            } else {
                readerWorkspace
                    .inspector(isPresented: $showInspector) {
                        chatPanel(mode: .inspector)
                            .inspectorColumnWidth(min: 300, ideal: inspectorIdealWidth, max: 650)
                    }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .onChange(of: showInspector) { _, visible in
            // The system can dismiss an inspector in a compact window.
            if !visible && dockedMode == .inspector {
                dockedMode = nil
            }
        }
        .sheet(isPresented: $showStudySheet, onDismiss: sheetDidDismiss) {
            chatPanel(mode: .sheet)
                .presentationDetents([.height(180), .medium, .large], selection: $detent)
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(backgroundTouches.systemValue)
                .presentationContentInteraction(swipePriority.systemValue)
                .modifier(NativeSheetPlacement(placement: placement))
                .modifier(NativeSheetSurface(style: sheetBackground))
        }
    }

    private var readerWorkspace: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if hasDockedPanel {
                            // In docked study mode, reserve the detail column for
                            // the book itself, not the Sheet experimentation UI.
                            readingCard
                        } else {
                            hero
                            if geometry.size.width >= 850 {
                                HStack(alignment: .top, spacing: 18) {
                                    readingCard
                                        .frame(maxWidth: .infinity)
                                    settingsCard
                                        .frame(width: 310)
                                }
                            } else {
                                settingsCard
                                readingCard
                            }
                        }
                        footer
                    }
                    .padding(20)
                    .frame(maxWidth: 1400)
                    .frame(maxWidth: .infinity)
                }
                .scrollPosition($readerScrollPosition)
                .background(Color(uiColor: .systemGroupedBackground))
            }
            .navigationTitle(hasDockedPanel ? "אוצריא · ספר לימוד" : "אוצריא · Native Sheet Lab")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(PanelMode.allCases) { mode in
                            Button {
                                selectMode(mode)
                            } label: {
                                Label(mode.title, systemImage: mode.symbol)
                            }
                        }
                        if hasDockedPanel {
                            Button("סגור שיחה", systemImage: "xmark", action: closePanel)
                        }
                    } label: {
                        Label("Hanlin", systemImage: hasDockedPanel ? "sidebar.right" : "bubble.left.and.bubble.right")
                    }
                    .buttonStyle(.glass)
                    .disabled(isTransitioning)
                    .accessibilityIdentifier("hanlin-reader-mode-menu")
                }
            }
        }
    }

    private func chatPanel(mode: PanelMode) -> some View {
        NativeStudyChatPanel(
            mode: mode,
            onChooseMode: selectMode,
            onClose: closePanel,
            placement: $placement,
            detent: $detent,
            backgroundTouches: $backgroundTouches,
            swipePriority: $swipePriority,
            sheetBackground: $sheetBackground,
            inspectorIdealWidth: $inspectorIdealWidth,
            messages: $messages,
            draft: $draft
        )
    }

    // A single presentation owns the conversation at any moment. A modal
    // sheet finishes its native dismissal before a docked surface mounts.
    private func selectMode(_ target: PanelMode) {
        guard !isTransitioning else { return }

        if showStudySheet {
            guard target != .sheet else { return }
            pendingModeAfterSheetDismissal = target
            isTransitioning = true
            showStudySheet = false
            return
        }

        if dockedMode == target { return }
        if target == .sheet {
            let hadDockedPanel = hasDockedPanel
            let ticket = UUID()
            transitionID = ticket

            if !hadDockedPanel {
                showStudySheet = true
                return
            }

            isTransitioning = true
            // Let the native inspector/split surface finish closing before
            // asking SwiftUI to present a sheet from the stable root.
            withAnimation(.default, completionCriteria: .removed) {
                showInspector = false
                dockedMode = nil
            } completion: {
                Task { @MainActor in
                    await Task.yield()
                    guard transitionID == ticket, dockedMode == nil else { return }
                    showStudySheet = true
                    isTransitioning = false
                }
            }
        } else {
            activateDockedMode(target)
        }
    }

    private func activateDockedMode(_ mode: PanelMode) {
        guard mode != .sheet else { return }
        showStudySheet = false
        splitVisibility = .all
        compactColumn = .detail
        dockedMode = mode
        showInspector = mode == .inspector
    }

    private func sheetDidDismiss() {
        guard let mode = pendingModeAfterSheetDismissal else { return }
        pendingModeAfterSheetDismissal = nil
        activateDockedMode(mode)
        isTransitioning = false
    }

    private func closePanel() {
        transitionID = UUID()
        pendingModeAfterSheetDismissal = nil
        isTransitioning = false
        showStudySheet = false
        showInspector = false
        dockedMode = nil
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "square.on.square.angled")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Native Sheet Lab")
                        .font(.title2.bold())
                    Text("חלונית מערכת אמיתית · SwiftUI · iPadOS 27")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    detent = .medium
                    selectMode(.sheet)
                } label: {
                    Label("פתח חלונית", systemImage: "rectangle.bottomthird.inset.filled")
                }
                .buttonStyle(.borderedProminent)
            }
            Text("בחר Sheet, Inspector או תצוגת שתי עמודות מקורית. ב־Sheet אפשר להשוות בין רקע המערכת, חומרים וזכוכית נוזלית שקופה. אותה שיחה ואותו ספר נשמרים במעבר.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
    }

    private var readingCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("ספר לימוד לדוגמה", systemImage: "book.closed")
                    .font(.headline)
                Spacer()
                Button {
                    bookmarked.toggle()
                    readerCount += 1
                } label: {
                    Image(systemName: bookmarked ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel("סימון הספר")
                Button {
                    fontSize = min(fontSize + 2, 30)
                    readerCount += 1
                } label: {
                    Image(systemName: "textformat.size.larger")
                }
                .accessibilityLabel("הגדלת גופן")
            }
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("שער \(chapter + 1) · עיון ולימוד")
                        .font(.title2.bold())
                    Text("תוכן מקורי שנכתב עבור הדגמת הממשק")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "text.book.closed")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
            }
            Group {
                Text("כשאדם לומד סוגיה, הוא מתחיל לעיתים בשאלה קטנה. קריאת המקור מולידה הבחנה, וההבחנה מעוררת רצון לעיין בדעות נוספות.")
                Text("במסך הזה הספר נשאר חלק פעיל מסביבת הלימוד. אפשר לדפדף, לשנות גודל כתב ולשמור סימנייה — אפילו כאשר חלונית השיחה פתוחה ומאפשרת אינטראקציה עם הרקע.")
                Text("החלונית עצמה אינה רכיב שכתבנו. SwiftUI מבקשת ממערכת ההפעלה להציג Sheet, והמערכת אחראית לגובה, לגרירה, להנפשות ולהתאמות למסך.")
                Text("שאלת המחקר: האם עדיף שהשיחה תיפתח בצד המוביל של המסך, או שמקומה ייקבע אוטומטית? בדוק את שתי האפשרויות ונסה להמשיך לעיין בספר.")
                Text("גם כאשר גובה החלונית משתנה, מצב הקריאה נשמר באותו View. הפעולה הזו מאפשרת לבחון את חוויית הלימוד לפני שמחברים את Hanlin האמיתי.")
            }
            .font(.system(size: fontSize))
            .lineSpacing(9)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            Divider()
            HStack(spacing: 12) {
                Button {
                    chapter = (chapter + 1) % 5
                    readerCount += 1
                } label: {
                    Label("דפדף פרק", systemImage: "arrow.left")
                }
                .buttonStyle(.borderedProminent)
                Text("פעולות שבוצעו ברקע: \(readerCount)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
        .padding(24)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("לוח ניסויים", systemImage: "slider.horizontal.3")
                .font(.headline)
            Text("אפשר לשנות את ההגדרות גם מתוך חלונית השיחה, כשהיא פתוחה.")
                .font(.caption)
                .foregroundStyle(.secondary)
            SheetExperimentControls(
                placement: $placement,
                detent: $detent,
                backgroundTouches: $backgroundTouches,
                swipePriority: $swipePriority,
                sheetBackground: $sheetBackground
            )
            VStack(spacing: 8) {
                ForEach(PanelMode.allCases) { mode in
                    Button {
                        selectMode(mode)
                    } label: {
                        Label(mode.title, systemImage: mode.symbol)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                }
            }
            .disabled(isTransitioning)
            Button("אפס לברירות מחדל") {
                placement = .leading
                detent = .medium
                backgroundTouches = .throughMedium
                swipePriority = .scrolls
                sheetBackground = .system
            }
            .font(.footnote)
        }
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.shield")
            Text("100% רכיבי SwiftUI מקוריים של Apple · שיחת AI מדומה, ללא רשת או מפתחות API")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)
    }
}

// This modifier changes the REAL SwiftUI sheet placement on iPadOS 27.
// On earlier iPadOS releases it gracefully keeps the system's automatic placement.
private struct NativeSheetPlacement: ViewModifier {
    let placement: SheetPlacementChoice

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 27.0, *) {
            switch placement {
            case .automatic: content.presentationPlacement(.automatic)
            case .leading: content.presentationPlacement(.leading)
            case .center: content.presentationPlacement(.center)
            case .trailing: content.presentationPlacement(.trailing)
            }
        } else {
            content
        }
    }
}

private struct NativeSheetSurface: ViewModifier {
    let style: SheetBackgroundStyle

    @ViewBuilder
    func body(content: Content) -> some View {
        switch style {
        case .system:
            content
        case .material:
            content.presentationBackground(.regularMaterial)
        case .ultraThin:
            content.presentationBackground(.ultraThinMaterial)
        case .regularGlass:
            content.presentationBackground {
                Color.clear
                    .glassEffect(.regular, in: .rect(cornerRadius: 30))
                    .ignoresSafeArea()
            }
        case .clearGlass:
            content.presentationBackground {
                Color.clear
                    .glassEffect(.clear, in: .rect(cornerRadius: 30))
                    .ignoresSafeArea()
            }
        case .transparent:
            content.presentationBackground(Color.clear)
        case .solid:
            content.presentationBackground(Color(uiColor: .systemBackground))
        }
    }
}

private struct SheetExperimentControls: View {
    @Binding var placement: SheetPlacementChoice
    @Binding var detent: PresentationDetent
    @Binding var backgroundTouches: BackgroundTouchChoice
    @Binding var swipePriority: SheetSwipeChoice
    @Binding var sheetBackground: SheetBackgroundStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("מיקום החלונית").font(.subheadline.weight(.semibold))
                Picker("מיקום", selection: $placement) {
                    ForEach(SheetPlacementChoice.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.menu)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text("גובה עגינה").font(.subheadline.weight(.semibold))
                Picker("גובה", selection: $detent) {
                    Text("קטן").tag(PresentationDetent.height(180))
                    Text("בינוני").tag(PresentationDetent.medium)
                    Text("מלא").tag(PresentationDetent.large)
                }
                .pickerStyle(.segmented)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text("לחיצות מאחורי החלונית").font(.subheadline.weight(.semibold))
                Picker("רקע", selection: $backgroundTouches) {
                    ForEach(BackgroundTouchChoice.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.menu)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text("התנהגות מחוות בתוך החלונית").font(.subheadline.weight(.semibold))
                Picker("מחוות", selection: $swipePriority) {
                    ForEach(SheetSwipeChoice.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text("רקע חלונית").font(.subheadline.weight(.semibold))
                Picker("חומר", selection: $sheetBackground) {
                    ForEach(SheetBackgroundStyle.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("sheet-background-picker")
            }
        }
        .controlSize(.regular)
    }
}

private struct NativeStudyChatPanel: View {
    let mode: PanelMode
    let onChooseMode: (PanelMode) -> Void
    let onClose: () -> Void
    @Binding var placement: SheetPlacementChoice
    @Binding var detent: PresentationDetent
    @Binding var backgroundTouches: BackgroundTouchChoice
    @Binding var swipePriority: SheetSwipeChoice
    @Binding var sheetBackground: SheetBackgroundStyle
    @Binding var inspectorIdealWidth: CGFloat
    @Binding var messages: [DemoChatMessage]
    @Binding var draft: String
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.title3)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Hanlin · " + mode.title)
                        .lineLimit(1)
                        .font(.headline)
                    Text("שיחה מקומית להדגמת התצוגה")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Menu {
                    ForEach(PanelMode.allCases) { target in
                        Button {
                            inputFocused = false
                            onChooseMode(target)
                        } label: {
                            Label(target.title, systemImage: target == mode ? "checkmark" : target.symbol)
                        }
                        .disabled(target == mode)
                    }
                } label: {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("בחר צורת הצגת השיחה")
                .accessibilityIdentifier("hanlin-layout-toggle")

                if mode == .sheet {
                    Menu {
                        Button("מזער", systemImage: "arrow.down.to.line") { detent = .height(180) }
                        Button("בינוני", systemImage: "rectangle.center.inset.filled") { detent = .medium }
                        Button("הרחב", systemImage: "arrow.up.left.and.arrow.down.right") { detent = .large }
                        Divider()
                        ForEach(SheetBackgroundStyle.allCases) { style in
                            Button {
                                sheetBackground = style
                            } label: {
                                Label(style.title, systemImage: sheetBackground == style ? "checkmark" : "circle.lefthalf.filled")
                            }
                        }
                    } label: {
                        Image(systemName: "circle.lefthalf.filled")
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("גובה ורקע חלונית")
                    .accessibilityIdentifier("hanlin-sheet-appearance")
                }
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("סגור חלונית")
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(mode.hint)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(messages) { message in
                        HStack {
                            if !message.isUser { Spacer(minLength: 24) }
                            Text(message.text)
                                .font(.body)
                                .padding(12)
                                .background(
                                    message.isUser ? Color.accentColor.opacity(0.15) :
                                        (mode == .sheet && sheetBackground.showsReaderThrough ?
                                            Color.secondary.opacity(0.10) : Color(uiColor: .secondarySystemBackground)),
                                    in: RoundedRectangle(cornerRadius: 16)
                                )
                                .frame(maxWidth: 480, alignment: .leading)
                            if message.isUser { Spacer(minLength: 24) }
                        }
                    }
                    if mode == .sheet {
                        DisclosureGroup {
                            SheetExperimentControls(
                            placement: $placement,
                            detent: $detent,
                            backgroundTouches: $backgroundTouches,
                            swipePriority: $swipePriority,
                            sheetBackground: $sheetBackground
                        )
                        .padding(.vertical, 10)
                    } label: {
                        Label("שנה הגדרות בזמן שהחלונית פתוחה", systemImage: "slider.horizontal.3")
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(12)
                        .background(sheetBackground.showsReaderThrough ? Color.secondary.opacity(0.10) : Color(uiColor: .tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                    }
                    if mode == .inspector {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("רוחב Inspector מבוקש", systemImage: "sidebar.right")
                                .font(.subheadline.weight(.semibold))
                            Picker("רוחב", selection: $inspectorIdealWidth) {
                                Text("צר").tag(CGFloat(340))
                                Text("רגיל").tag(CGFloat(420))
                                Text("רחב").tag(CGFloat(560))
                            }
                            .pickerStyle(.segmented)
                            Text("זהו רוחב מועדף; המערכת קובעת את הרוחב בפועל לפי גודל החלון.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()
            HStack(alignment: .bottom, spacing: 12) {
                TextField("שאל שאלה לדוגמה…", text: $draft, axis: .vertical)
                    .lineLimit(1...3)
                    .textFieldStyle(.roundedBorder)
                    .focused($inputFocused)
                    .onSubmit(sendDemoMessage)
                Button(action: sendDemoMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("שלח הודעת הדגמה")
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func sendDemoMessage() {
        let value = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        messages.append(DemoChatMessage(isUser: true, text: value))
        messages.append(DemoChatMessage(isUser: false,
            text: "זוהי תשובה מדומה. החלונית והמחוות מקוריות של Apple; מנוע Hanlin אינו מחובר בהדגמה הזו."))
        draft = ""
        inputFocused = false
    }
}


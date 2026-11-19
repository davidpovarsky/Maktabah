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

private enum SheetBackgroundStyle: String, CaseIterable, Identifiable {
    case material, solid
    var id: String { rawValue }

    var title: String {
        switch self {
        case .material: return "חומר מערכתי"
        case .solid: return "רקע אטום"
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
    @State private var isDocked = false
    @State private var dockAfterSheetDismissal = false
    @State private var splitVisibility: NavigationSplitViewVisibility = .all
    @State private var compactColumn: NavigationSplitViewColumn = .detail
    @State private var readerScrollPosition = ScrollPosition()
    @State private var placement: SheetPlacementChoice = .leading
    @State private var detent: PresentationDetent = .medium
    @State private var backgroundTouches: BackgroundTouchChoice = .throughMedium
    @State private var swipePriority: SheetSwipeChoice = .scrolls
    @State private var sheetBackground: SheetBackgroundStyle = .material

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
                    chatPanel(isDocked: true)
                        .navigationSplitViewColumnWidth(min: 340, ideal: 420, max: 560)
                } detail: {
                    readerWorkspace
                }
                .navigationSplitViewStyle(.balanced)
            } else {
                readerWorkspace
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        // The sheet is owned by the same stable root in both layouts. Never
        // present a sheet and mount the docked chat at the same time.
        .sheet(isPresented: $showStudySheet, onDismiss: sheetDidDismiss) {
            chatPanel(isDocked: false)
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
                        if isDocked {
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
            .navigationTitle(isDocked ? "אוצריא · ספר לימוד" : "אוצריא · Native Sheet Lab")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if isDocked {
                        Button(action: restoreSheet) {
                            Label("החזר את Hanlin לחלונית", systemImage: "rectangle.bottomthird.inset.filled")
                        }
                        .buttonStyle(.glass)
                        .accessibilityIdentifier("hanlin-reader-undock")
                    } else {
                        Button {
                            showStudySheet = true
                        } label: {
                            Label("פתח Hanlin", systemImage: "bubble.left.and.bubble.right")
                        }
                    }
                }
            }
        }
    }

    // Both branches use the same panel component and bindings. Messages, draft,
    // reader chapter, bookmark, typography and scroll position are not duplicated.
    private func chatPanel(isDocked: Bool) -> some View {
        NativeStudyChatPanel(
            isDocked: isDocked,
            onToggleLayout: isDocked ? restoreSheet : requestDock,
            onClose: isDocked ? closeDockedChat : closeSheet,
            placement: $placement,
            detent: $detent,
            backgroundTouches: $backgroundTouches,
            swipePriority: $swipePriority,
            sheetBackground: $sheetBackground,
            messages: $messages,
            draft: $draft
        )
    }

    private func requestDock() {
        guard !isDocked, showStudySheet else { return }
        dockAfterSheetDismissal = true
        showStudySheet = false
    }

    private func sheetDidDismiss() {
        guard dockAfterSheetDismissal else { return }
        dockAfterSheetDismissal = false
        splitVisibility = .all
        compactColumn = .detail
        isDocked = true
    }

    private func restoreSheet() {
        guard isDocked else { return }
        isDocked = false
        // Wait for the native split view to unmount before presenting the sheet.
        Task { @MainActor in
            await Task.yield()
            if !isDocked { showStudySheet = true }
        }
    }

    private func closeDockedChat() {
        isDocked = false
        showStudySheet = false
    }

    private func closeSheet() {
        dockAfterSheetDismissal = false
        showStudySheet = false
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
                    showStudySheet = true
                } label: {
                    Label("פתח חלונית", systemImage: "rectangle.bottomthird.inset.filled")
                }
                .buttonStyle(.borderedProminent)
            }
            Text("בדוק את הגרירה והמיקום של ה־Sheet, והעבר את אותה שיחה לעמודת צד מערכתית בלחיצה על כפתור הזכוכית. הספר נשאר פעיל בשני המצבים.")
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
            Button {
                showStudySheet = true
            } label: {
                Label("בדוק את החלונית", systemImage: "rectangle.stack.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            Button("אפס לברירות מחדל") {
                placement = .leading
                detent = .medium
                backgroundTouches = .throughMedium
                swipePriority = .scrolls
                sheetBackground = .material
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
        case .material:
            content.presentationBackground(.regularMaterial)
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
                .pickerStyle(.segmented)
            }
        }
        .controlSize(.regular)
    }
}

private struct NativeStudyChatPanel: View {
    let isDocked: Bool
    let onToggleLayout: () -> Void
    let onClose: () -> Void
    @Binding var placement: SheetPlacementChoice
    @Binding var detent: PresentationDetent
    @Binding var backgroundTouches: BackgroundTouchChoice
    @Binding var swipePriority: SheetSwipeChoice
    @Binding var sheetBackground: SheetBackgroundStyle
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
                    Text(isDocked ? "Hanlin · Split View" : "Hanlin · Native Sheet")
                        .font(.headline)
                    Text("שיחה מקומית להדגמת התצוגה")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Button(action: onToggleLayout) {
                    Image(systemName: isDocked ? "rectangle.bottomthird.inset.filled" : "sidebar.right")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.glass)
                .help(isDocked ? "חזור ל־Sheet" : "הצג את Hanlin בעמודה לצד הספר")
                .accessibilityLabel(isDocked ? "החזר את השיחה לחלונית המערכת" : "הצג את השיחה בשתי עמודות")
                .accessibilityIdentifier("hanlin-layout-toggle")
                if !isDocked {
                    Menu {
                    Button("מזער", systemImage: "arrow.down.to.line") { detent = .height(180) }
                    Button("בינוני", systemImage: "rectangle.center.inset.filled") { detent = .medium }
                    Button("הרחב", systemImage: "arrow.up.left.and.arrow.down.right") { detent = .large }
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .frame(width: 36, height: 36)
                }
                    .accessibilityLabel("שנה גובה חלונית")
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
                    Text(isDocked
                         ? "מצב שתי עמודות: הספר והשיחה מוצגים יחד ב־NavigationSplitView המקורי של Apple. כפתור סרגל הצד מחזיר ל־Sheet, בלי למחוק את ההודעות."
                         : "גרור את ידית המערכת כדי לשנות גובה. בזמן שהחלונית בגובה קטן או בינוני, נסה ללחוץ על הספר שמאחוריה.")
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
                                    message.isUser ? Color.accentColor.opacity(0.14) : Color(uiColor: .secondarySystemBackground),
                                    in: RoundedRectangle(cornerRadius: 16)
                                )
                                .frame(maxWidth: 480, alignment: .leading)
                            if message.isUser { Spacer(minLength: 24) }
                        }
                    }
                    if !isDocked {
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
                        .background(Color(uiColor: .tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
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

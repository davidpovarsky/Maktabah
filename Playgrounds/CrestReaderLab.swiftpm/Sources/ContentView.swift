import SwiftUI
import UIKit

// Playground-only demo document. It does not pretend to be a Maktabah DB page.
struct ReaderDemoBook: Identifiable, Hashable {
    let id: String
    let title: String
    let section: String
    let text: String
    let isArabic: Bool
    let symbol: String

    static let samples: [ReaderDemoBook] = [
        ReaderDemoBook(
            id: "genesis",
            title: "בראשית",
            section: "פרק א",
            text: """
            בראשית — פרק א

            בְּרֵאשִׁית בָּרָא אֱלֹהִים אֵת הַשָּׁמַיִם וְאֵת הָאָרֶץ.

            וְהָאָרֶץ הָיְתָה תֹהוּ וָבֹהוּ וְחֹשֶׁךְ עַל־פְּנֵי תְהוֹם וְרוּחַ אֱלֹהִים מְרַחֶפֶת עַל־פְּנֵי הַמָּיִם.

            וַיֹּאמֶר אֱלֹהִים יְהִי אוֹר וַיְהִי־אוֹר.

            וַיַּרְא אֱלֹהִים אֶת־הָאוֹר כִּי־טוֹב וַיַּבְדֵּל אֱלֹהִים בֵּין הָאוֹר וּבֵין הַחֹשֶׁךְ.

            וַיִּקְרָא אֱלֹהִים לָאוֹר יוֹם וְלַחֹשֶׁךְ קָרָא לָיְלָה וַיְהִי־עֶרֶב וַיְהִי־בֹקֶר יוֹם אֶחָד.

            וַיֹּאמֶר אֱלֹהִים יְהִי רָקִיעַ בְּתוֹךְ הַמָּיִם וִיהִי מַבְדִּיל בֵּין מַיִם לָמָיִם.
            """,
            isArabic: false,
            symbol: "book.closed"
        ),
        ReaderDemoBook(
            id: "psalms",
            title: "תהילים",
            section: "מזמור כג",
            text: """
            מִזְמוֹר לְדָוִד: יְהוָה רֹעִי לֹא אֶחְסָר.

            בִּנְאוֹת דֶּשֶׁא יַרְבִּיצֵנִי עַל־מֵי מְנֻחוֹת יְנַהֲלֵנִי.

            נַפְשִׁי יְשׁוֹבֵב יַנְחֵנִי בְמַעְגְּלֵי־צֶדֶק לְמַעַן שְׁמוֹ.

            גַּם כִּי־אֵלֵךְ בְּגֵיא צַלְמָוֶת לֹא־אִירָא רָע כִּי־אַתָּה עִמָּדִי שִׁבְטְךָ וּמִשְׁעַנְתֶּךָ הֵמָּה יְנַחֲמֻנִי.

            תַּעֲרֹךְ לְפָנַי שֻׁלְחָן נֶגֶד צֹרְרָי דִּשַּׁנְתָּ בַשֶּׁמֶן רֹאשִׁי כּוֹסִי רְוָיָה.

            אַךְ טוֹב וָחֶסֶד יִרְדְּפוּנִי כָּל־יְמֵי חַיָּי וְשַׁבְתִּי בְּבֵית־יְהוָה לְאֹרֶךְ יָמִים.
            """,
            isArabic: false,
            symbol: "text.book.closed"
        ),
        ReaderDemoBook(
            id: "avot",
            title: "פרקי אבות",
            section: "פרק א — משנה א",
            text: """
            מֹשֶׁה קִבֵּל תּוֹרָה מִסִּינַי, וּמְסָרָהּ לִיהוֹשֻׁעַ, וִיהוֹשֻׁעַ לִזְקֵנִים, וּזְקֵנִים לִנְבִיאִים, וּנְבִיאִים מְסָרוּהָ לְאַנְשֵׁי כְנֶסֶת הַגְּדוֹלָה.

            הֵם אָמְרוּ שְׁלֹשָׁה דְבָרִים: הֱווּ מְתוּנִים בַּדִּין, וְהַעֲמִידוּ תַלְמִידִים הַרְבֵּה, וַעֲשׂוּ סְיָג לַתּוֹרָה.

            שִׁמְעוֹן הַצַּדִּיק הָיָה מִשְּׁיָרֵי כְנֶסֶת הַגְּדוֹלָה. הוּא הָיָה אוֹמֵר: עַל שְׁלֹשָׁה דְבָרִים הָעוֹלָם עוֹמֵד, עַל הַתּוֹרָה וְעַל הָעֲבוֹדָה וְעַל גְּמִילוּת חֲסָדִים.
            """,
            isArabic: false,
            symbol: "books.vertical"
        ),
        ReaderDemoBook(
            id: "arabic",
            title: "نص عربي",
            section: "اختبار الخط الأصلي",
            text: """
            بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ

            هذا النص العربي جزء من بيئة تجربة لعرض محرك القراءة الأصلي، وليس من قاعدة بيانات المكتبة.

            محرك Maktabah يعالج الحركات والاتجاه من اليمين إلى اليسار، ويمكن مقارنة العرض مع النص العبري.

            مثال للأرقام: 12345.
            """,
            isArabic: true,
            symbol: "character.book.closed"
        )
    ]
}

struct ReaderDemoTab: Identifiable {
    let id: UUID
    let book: ReaderDemoBook
    var title: String { book.title }
}

struct ContentView: View {
    @State private var spaces: [SpaceModel] = [
        SpaceModel(id: UUID(), name: "ספרייה", accent: Color(red: 0.36, green: 0.51, blue: 0.68)),
        SpaceModel(id: UUID(), name: "לימוד", accent: Color(red: 0.35, green: 0.41, blue: 0.52))
    ]
    @State private var spaceIndex = 0
    @State private var tabs: [ReaderDemoTab] = [
        ReaderDemoTab(id: UUID(), book: ReaderDemoBook.samples[0]),
        ReaderDemoTab(id: UUID(), book: ReaderDemoBook.samples[1])
    ]
    @State private var activeTabIndex = 0
    @State private var presentation: BrowserSidebarPresentation = .docked
    @State private var sidebarWidth: CGFloat = 286
    @State private var fontSize: Double = 24
    @State private var lineHeight: Double = 1.24
    @State private var revision = 0
    @State private var showSamples = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var currentTab: ReaderDemoTab? {
        tabs.indices.contains(activeTabIndex) ? tabs[activeTabIndex] : nil
    }
    private var currentSpace: SpaceModel {
        spaces[spaceIndex]
    }
    private var isSidebarVisible: Bool { presentation != .collapsed }

    var body: some View {
        GeometryReader { geometry in
            BrowserSidebarPageLayout(
                presentation: presentation,
                width: sidebarWidth,
                edge: .leading
            ) {
                readerSurface
            } sidebar: {
                BrowserRootSidebarSurfaceLayer(
                    presentation: presentation,
                    width: sidebarWidth,
                    edge: .leading,
                    space: currentSpace,
                    reduceTransparency: false,
                    spaces: spaces,
                    hoverChanged: { _ in }
                ) {
                    sidebarContents
                }
            } controls: {
                if !isSidebarVisible {
                    HStack {
                        Button {
                            withAnimation(.easeInOut(duration: 0.24)) { presentation = .floating }
                        } label: {
                            Image(systemName: "sidebar.left")
                                .font(.title3)
                                .padding(12)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 13))
                        }
                        .buttonStyle(.plain)
                        .padding(12)
                        Spacer()
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                }
            }
            .background(Color(uiColor: .systemBackground))
            .animation(.easeInOut(duration: 0.28), value: presentation)
            .onChange(of: geometry.size.width) { _, width in
                if width < 700 && presentation == .docked { presentation = .floating }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .preferredColorScheme(.light)
    }

    private var sidebarContents: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "books.vertical.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Text("Reader Lab")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    withAnimation { presentation = .collapsed }
                } label: {
                    Image(systemName: "sidebar.left")
                        .foregroundStyle(.white.opacity(0.78))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 25)

            HStack {
                Text(currentSpace.name)
                    .font(.headline)
                Spacer()
                Menu {
                    ForEach(spaces.indices, id: \.self) { idx in
                        Button(spaces[idx].name) { spaceIndex = idx }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.bottom, 14)

            Divider().overlay(.white.opacity(0.15))
                .padding(.horizontal, 14)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(Array(tabs.enumerated()), id: \.element.id) { idx, tab in
                        HStack(spacing: 4) {
                            Button {
                                activeTabIndex = idx
                                if presentation == .floating { presentation = .collapsed }
                            } label: {
                                HStack(spacing: 11) {
                                    Image(systemName: tab.book.symbol)
                                        .frame(width: 20)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(tab.title).font(.system(size: 16, weight: .medium))
                                        Text(tab.book.section).font(.caption2).opacity(0.65)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .foregroundStyle(.white)
                                .padding(.vertical, 10)
                                .padding(.leading, 13)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Button {
                                close(tab.id)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption)
                                    .padding(10)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                        .background(
                            idx == activeTabIndex ? Color.white.opacity(0.17) : .clear,
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                    }
                    Button {
                        showSamples = true
                    } label: {
                        Label("פתח ספר", systemImage: "plus")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.top, 12)
            }

            Spacer(minLength: 0)

            HStack {
                Button {
                    presentation = .collapsed
                } label: {
                    Image(systemName: "sidebar.left")
                }
                Spacer()
                Button {
                    showSamples = true
                } label: {
                    Image(systemName: "plus.square.on.square")
                }
                Spacer()
                Image(systemName: "slider.horizontal.3")
            }
            .font(.title3)
            .foregroundStyle(.white.opacity(0.85))
            .padding(18)
        }
        .background(
            BrowserSpaceBannerBackground(branding: currentSpace.settings.look.shown)
        )
        .sheet(isPresented: $showSamples) {
            NavigationStack {
                List(ReaderDemoBook.samples) { book in
                    Button {
                        tabs.append(ReaderDemoTab(id: UUID(), book: book))
                        activeTabIndex = tabs.count - 1
                        showSamples = false
                        if presentation == .floating { presentation = .collapsed }
                    } label: {
                        Label(book.title, systemImage: book.symbol)
                    }
                }
                .navigationTitle("בחר טקסט לדוגמה")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("סגור") { showSamples = false }
                    }
                }
            }
        }
    }

    private var readerSurface: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if isSidebarVisible {
                    Button {
                        withAnimation { presentation = .collapsed }
                    } label: {
                        Image(systemName: "sidebar.left")
                    }
                }
                Spacer(minLength: 4)
                VStack(spacing: 2) {
                    Text(currentTab?.title ?? "קורא")
                        .font(.headline)
                    if let section = currentTab?.book.section {
                        Text(section)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 4)
                Button {
                    fontSize = max(16, fontSize - 2)
                    applyAppearance()
                } label: { Image(systemName: "textformat.size.smaller") }
                Button {
                    fontSize = min(44, fontSize + 2)
                    applyAppearance()
                } label: { Image(systemName: "textformat.size.larger") }
                Menu {
                    Button("לבן") { setBackground(.white) }
                    Button("ספר") { setBackground(.sepia) }
                    Button("אפור") { setBackground(.gray) }
                    Button("Arial Hebrew") { TextViewState.shared.setFont("Arial Hebrew"); revision += 1 }
                    Button("Geeza Pro") { TextViewState.shared.setFont("Geeza Pro"); revision += 1 }
                    Button("Damascus") { TextViewState.shared.setFont("Damascus"); revision += 1 }
                } label: {
                    Image(systemName: "textformat")
                }
            }
            .font(.title3)
            .foregroundStyle(.primary)
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .frame(height: 64)
            .background(.regularMaterial)

            Divider()

            if let tab = currentTab {
                MaktabahOriginalReaderSurface(
                    text: tab.book.text,
                    isArabic: tab.book.isArabic,
                    renderRevision: revision
                )
                .id(tab.id)
                .environment(\.layoutDirection, .rightToLeft)
                .background(TextViewState.shared.backgroundColor.color)
            } else {
                ContentUnavailableView(
                    "לא נפתח ספר",
                    systemImage: "books.vertical",
                    description: Text("פתח ספר לדוגמה מסרגל הצד")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }

    private func setBackground(_ color: BackgroundColor) {
        TextViewState.shared.setBackgroundColor(color)
        revision += 1
    }

    private func applyAppearance() {
        let state = TextViewState.shared
        state.changeFontSize(by: CGFloat(fontSize) - state.fontSize)
        state.setLineHeight(lineHeight)
        revision += 1
    }

    private func close(_ id: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs.remove(at: idx)
        activeTabIndex = min(activeTabIndex, max(0, tabs.count - 1))
    }
}

/// The class instantiated below is UNCHANGED code extracted from the original
/// Maktabah iOSIbarotTextView.swift. The host only supplies offline data.
struct MaktabahOriginalReaderSurface: UIViewRepresentable {
    let text: String
    let isArabic: Bool
    let renderRevision: Int

    final class Coordinator {
        var signature: String?
    }
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> iOSCustomIbarotTextView {
        let view = iOSCustomIbarotTextView(frame: .zero, textContainer: nil)
        view.accessibilityIdentifier = "maktabah-original-text-view"
        view.isEditable = false
        view.isSelectable = true
        view.alwaysBounceVertical = true
        view.contentInsetAdjustmentBehavior = .never
        view.textContainerInset = UIEdgeInsets(top: 30, left: 38, bottom: 48, right: 38)
        return view
    }

    func updateUIView(_ view: iOSCustomIbarotTextView, context: Context) {
        let state = TextViewState.shared
        let signature = "\(text.hashValue)|\(isArabic)|\(renderRevision)|\(state.fontSize)|\(state.lineHeight)|\(state.fontName)"
        guard context.coordinator.signature != signature else { return }
        let result = ArabicTextRenderer().render(
            text: text,
            showHarakat: state.showHarakat,
            isMultiLanguage: !isArabic,
            isImported: false
        )
        view.currentRenderResult = result
        view.attributedText = result.attributedString
        view.textAlignment = .right
        view.semanticContentAttribute = .forceRightToLeft
        view.backgroundColor = state.backgroundColor.nsColor
        context.coordinator.signature = signature
    }
}

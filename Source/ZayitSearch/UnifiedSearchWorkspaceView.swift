import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum UnifiedSearchScope: String, CaseIterable, Identifiable, Sendable {
    case exact
    case advanced
    case fuzzy
    case zayit

    var id: Self { self }
    var title: String {
        switch self {
        case .exact: "מדויק"
        case .advanced: "מתקדם"
        case .fuzzy: "מקורב"
        case .zayit: "זית"
        }
    }
}

struct HighlightDescriptor: Equatable, Sendable {
    enum Engine: String, Sendable { case otzaria, zayit }
    let literalTerms: [String]
    let matchedTerms: [String]
    let upstreamPattern: String?
    let engine: Engine
    let fallbackQuery: String

    var readerFallback: String {
        let terms = matchedTerms.isEmpty ? literalTerms : matchedTerms
        return terms.isEmpty ? fallbackQuery : terms.joined(separator: ",")
    }
}

struct UnifiedSearchResult: Identifiable {
    enum Payload {
        case otzaria(SearchResultItem, OtzariaEngineSearchResult?)
        case zayit(ZayitSearchHit)
    }

    let id: String
    let engine: HighlightDescriptor.Engine
    let stableBookIdentity: String
    let title: String
    let reference: String
    let snippet: [SearchInlineSegment]
    let highlight: HighlightDescriptor
    let payload: Payload

    var plainText: String { snippet.map(\.text).joined() }
    var copyWithSource: String {
        [plainText, [title, reference].filter { !$0.isEmpty }.joined(separator: " — ")]
            .filter { !$0.isEmpty }.joined(separator: "\n")
    }
}

struct UnifiedSearchWorkspaceView: View {
    @StateObject private var otzaria = OtzariaTextSearchViewModel()
    @EnvironmentObject private var zayitSession: ZayitSearchSessionController
    @State private var scope: UnifiedSearchScope = .advanced
    @State private var query = ""
    @State private var showsAdvanced = false
    @State private var showsSearchData = false
    @State private var hasSubmitted = false
    @State private var customSpacingText = ""
    @State private var alternativeWordsText = ""
    @State private var enablesPrefixes = false
    @State private var enablesSuffixes = false
    @State private var enablesSpellingVariants = false
    @State private var enablesAramaic = false
    @State private var ignoresQuotes = false

    let openOtzaria: (SearchResultItem, HighlightDescriptor) -> Void
    let openZayit: (ZayitSearchHit, HighlightDescriptor) -> Void

    var body: some View {
        Group {
            switch contentState {
            case .results:
                List(results) { result in resultButton(result) }
                    .listStyle(.plain)
            case .loading:
                VStack(spacing: 12) {
                    ProgressView()
                    Text("מחפש…").foregroundStyle(.secondary)
                }
            case .error(let message):
                ContentUnavailableView(
                    "החיפוש נכשל",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            case .missingIndex:
                ContentUnavailableView {
                    Label("נתוני החיפוש אינם מותקנים", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text("ניתן להתקין או לתקן את רכיב החיפוש במסך נתוני החיפוש.")
                } actions: {
                    Button("פתח נתוני חיפוש") { showsSearchData = true }
                        .buttonStyle(.borderedProminent)
                }
            case .empty:
                ContentUnavailableView(
                    "לא נמצאו תוצאות",
                    systemImage: "magnifyingglass",
                    description: Text("נסו לשנות את מילות החיפוש או את האפשרויות.")
                )
            case .notSearched:
                ContentUnavailableView(
                    "חיפוש בספרייה",
                    systemImage: "text.magnifyingglass",
                    description: Text("הקלידו שאילתה ולחצו חיפוש.")
                )
            }
        }
        .navigationTitle("חיפוש")
        .searchable(
            text: $query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "חיפוש בכל הספרים"
        )
        .searchScopes($scope) {
            ForEach(UnifiedSearchScope.allCases) { item in Text(item.title).tag(item) }
        }
        .onSubmit(of: .search, runSearch)
        .safeAreaInset(edge: .top) {
            VStack(spacing: 8) {
                if scope == .advanced {
                    DisclosureGroup("אפשרויות חיפוש מתקדם", isExpanded: $showsAdvanced) {
                        advancedControls
                    }
                }
                HStack {
                    Text(statusText).font(.footnote).foregroundStyle(.secondary)
                    Spacer()
                    if isLoading { ProgressView().controlSize(.small) }
                    if !results.isEmpty { Text("\(results.count)").font(.footnote).foregroundStyle(.secondary) }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .sheet(isPresented: $showsSearchData) {
            NavigationStack { SearchDataView() }
        }
        .task {
            otzaria.refreshStatus()
            await zayitSession.restoreIfNeeded(existingSeforimDB: ZayitSearchExistingDatabaseProvider.currentURL)
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private var advancedControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("סדר תוצאות", selection: $otzaria.order) {
                Text("סדר הספרים").tag(OtzariaSearchOrder.catalogue)
                Text("רלוונטיות").tag(OtzariaSearchOrder.relevance)
            }
            TextField("שאילתה שלילית", text: $otzaria.negativeQuery)
                .textFieldStyle(.roundedBorder)
            HStack {
                Picker("תחום חיובי", selection: $otzaria.scope) {
                    Text("מרחק מילים").tag(OtzariaSearchScope.wordDistance)
                    Text("אותה פסקה").tag(OtzariaSearchScope.sameParagraph)
                    Text("אותו סעיף").tag(OtzariaSearchScope.sameSection)
                }
                Picker("מילים נדרשות", selection: $otzaria.wordMatchMode) {
                    Text("כולן").tag(OtzariaWordMatchMode.all)
                    Text("מילה כלשהי").tag(OtzariaWordMatchMode.anyWord)
                    Text("רוב המילים").tag(OtzariaWordMatchMode.mostWords)
                    Text("לפחות…").tag(OtzariaWordMatchMode.atLeast)
                }
            }
            if otzaria.wordMatchMode == .atLeast {
                Stepper("לפחות \(otzaria.wordMatchCount) מילים", value: $otzaria.wordMatchCount, in: 1...100)
            }
            Stepper("מרחק חיובי: \(otzaria.distance)", value: $otzaria.distance, in: 0...20)
            if !otzaria.negativeQuery.isEmpty {
                Picker("תחום השאילתה השלילית", selection: $otzaria.negativeScope) {
                    Text("מרחק מילים").tag(OtzariaSearchScope.wordDistance)
                    Text("אותה פסקה").tag(OtzariaSearchScope.sameParagraph)
                    Text("אותו סעיף").tag(OtzariaSearchScope.sameSection)
                }
                Stepper("מרחק שלילי: \(otzaria.negativeDistance)", value: $otzaria.negativeDistance, in: 0...20)
            }
            Picker("קיבוץ", selection: $otzaria.grouping) {
                Text("ללא").tag(nil as OtzariaResultGrouping?)
                Text("אותו סעיף").tag(OtzariaResultGrouping.sameSection as OtzariaResultGrouping?)
                Text("טקסט זהה").tag(OtzariaResultGrouping.identicalText as OtzariaResultGrouping?)
            }
            HStack {
                Toggle("ניקוד", isOn: $otzaria.matchNikud)
                Toggle("טעמים", isOn: $otzaria.matchTaamim)
            }
            HStack {
                Toggle("קידומות", isOn: $enablesPrefixes)
                Toggle("סיומות", isOn: $enablesSuffixes)
                Toggle("כתיב מלא/חסר", isOn: $enablesSpellingVariants)
            }
            HStack {
                Toggle("ארמית", isOn: $enablesAramaic)
                Toggle("התעלם מגרשיים", isOn: $ignoresQuotes)
            }
            TextField("מרווחים מותאמים (למשל 0,2,1)", text: $customSpacingText)
                .textFieldStyle(.roundedBorder)
            TextField("מילים חלופיות לפי מיקום; פסיק בין מילים ונקודה־פסיק בין מיקומים", text: $alternativeWordsText)
                .textFieldStyle(.roundedBorder)
        }
        .pickerStyle(.menu)
        .padding(.top, 6)
    }

    private var results: [UnifiedSearchResult] {
        if scope == .zayit {
            return zayitSession.model.hits.map { hit in
                let descriptor = HighlightDescriptor(
                    literalTerms: query.split(whereSeparator: \.isWhitespace).map(String.init),
                    matchedTerms: hit.matchedTerms,
                    upstreamPattern: nil,
                    engine: .zayit,
                    fallbackQuery: query
                )
                return UnifiedSearchResult(
                    id: "zayit:\(hit.lineId)", engine: .zayit,
                    stableBookIdentity: hit.stableBookKey, title: hit.bookTitle,
                    reference: hit.reference,
                    snippet: SearchInlineMarkupSanitizer.segments(from: hit.snippetHtml),
                    highlight: descriptor, payload: .zayit(hit)
                )
            }
        }
        let engineResults = otzaria.enginePage?.results ?? []
        return otzaria.results.enumerated().map { offset, item in
            let engine = engineResults.indices.contains(offset) ? engineResults[offset] : nil
            let descriptor = HighlightDescriptor(
                literalTerms: (try? OtzariaSearchEngineBridge.splitQueryWords(query)) ?? [query],
                matchedTerms: [], upstreamPattern: highlightPattern,
                engine: .otzaria, fallbackQuery: query
            )
            let plain = item.attributedText.string
            return UnifiedSearchResult(
                id: "otzaria:\(item.bookId):\(item.page):\(offset)", engine: .otzaria,
                stableBookIdentity: engine?.filePath ?? "book:\(item.bookId)",
                title: item.bookTitle, reference: engine?.reference ?? "",
                snippet: [.init(text: plain, highlighted: false)],
                highlight: descriptor, payload: .otzaria(item, engine)
            )
        }
    }

    private var highlightPattern: String? {
        let request = OtzariaSearchRequest(
            query: query, mode: otzaria.mode, distance: otzaria.distance,
            scope: otzaria.scope, wordMatchMode: otzaria.wordMatchMode,
            customSpacing: otzaria.customSpacing, alternativeWords: otzaria.alternativeWords,
            searchOptions: otzaria.searchOptions
        )
        return try? OtzariaSearchEngineBridge.highlightPattern(for: request)?.combinedPattern
    }

    private var packageMissing: Bool {
        if scope == .zayit { return zayitSession.state != .ready }
        return switch otzaria.status {
        case .ready: false
        case .checkingPackage, .building, .finalizing, .downloadingPackage, .installingPackage: false
        default: true
        }
    }

    private var contentState: UnifiedSearchPresentationState {
        UnifiedSearchPresentationPolicy.resolve(
            resultCount: results.count,
            isLoading: isLoading,
            errorMessage: scope == .zayit ? zayitSession.model.errorMessage : otzaria.errorMessage,
            hasSubmitted: hasSubmitted,
            indexReady: !packageMissing
        )
    }

    private var isLoading: Bool { scope == .zayit ? zayitSession.model.isLoading : otzaria.isSearching }
    private var statusText: String {
        if scope == .zayit {
            if let error = zayitSession.model.errorMessage { return error }
            return zayitSession.model.hits.isEmpty ? "זית" : "תוצאות זית"
        }
        return otzaria.status.label
    }

    private func runSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        hasSubmitted = true
        if scope == .zayit {
            zayitSession.model.query = trimmed
            zayitSession.model.runSearch()
        } else {
            otzaria.query = trimmed
            otzaria.mode = {
                switch scope {
                case .exact: .exact
                case .advanced: .advanced
                case .fuzzy: .fuzzy
                case .zayit: .advanced
                }
            }()
            if scope == .advanced { applyAdvancedWordOptions(to: trimmed) }
            otzaria.search()
        }
    }

    private func applyAdvancedWordOptions(to text: String) {
        let words = (try? OtzariaSearchEngineBridge.splitQueryWords(text))
            ?? text.split(whereSeparator: \.isWhitespace).map(String.init)
        var options: [String: [String: Bool]] = [:]
        for (index, word) in words.enumerated() {
            options["\(word)_\(index)"] = [
                "קידומות": enablesPrefixes,
                "סיומות": enablesSuffixes,
                "קידומות דקדוקיות": enablesPrefixes,
                "סיומות דקדוקיות": enablesSuffixes,
                "כתיב מלא/חסר": enablesSpellingVariants,
                "קידומות ארמיות": enablesAramaic,
                "סיומות ארמיות": enablesAramaic,
                "תרגום ארמי": enablesAramaic,
                "ראשי תיבות": ignoresQuotes,
                "התעלם מגרשיים": ignoresQuotes,
            ]
        }
        otzaria.searchOptions = options
        otzaria.customSpacing = Dictionary(uniqueKeysWithValues: customSpacingText
            .split(separator: ",", omittingEmptySubsequences: false)
            .enumerated()
            .map { ("\($0.offset)-\($0.offset + 1)", String($0.element).trimmingCharacters(in: .whitespaces)) })
        otzaria.alternativeWords = Dictionary(uniqueKeysWithValues: alternativeWordsText
            .split(separator: ";", omittingEmptySubsequences: false)
            .enumerated()
            .map {
                (String($0.offset), $0.element.split(separator: ",")
                    .map { String($0).trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty })
            })
    }

    private func resultButton(_ result: UnifiedSearchResult) -> some View {
        Button { open(result) } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text(result.title).font(.headline)
                if !result.reference.isEmpty {
                    Text(result.reference).font(.caption).foregroundStyle(.secondary)
                }
                highlightedText(result.snippet).lineLimit(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Open", systemImage: "book") { open(result) }
            Button("Copy", systemImage: "doc.on.doc") { copy(result.plainText) }
            Button("Copy with source", systemImage: "text.quote") { copy(result.copyWithSource) }
            ShareLink(item: result.copyWithSource)
            Button("Search in book", systemImage: "magnifyingglass") { open(result) }
        } preview: {
            VStack(alignment: .leading, spacing: 10) {
                Text(result.title).font(.headline)
                if !result.reference.isEmpty { Text(result.reference).font(.caption).foregroundStyle(.secondary) }
                highlightedText(result.snippet)
            }
            .padding().frame(width: 360)
        }
    }

    private func open(_ result: UnifiedSearchResult) {
        switch result.payload {
        case .otzaria(let item, _): openOtzaria(item, result.highlight)
        case .zayit(let hit): openZayit(hit, result.highlight)
        }
    }

    private func highlightedText(_ segments: [SearchInlineSegment]) -> Text {
        segments.reduce(Text("")) { partial, segment in
            partial + (segment.highlighted ? Text(segment.text).bold() : Text(segment.text))
        }
    }

    private func copy(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
    }
}

struct SearchDataView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var otzaria = OtzariaTextSearchViewModel()
    @StateObject private var zayit = ZayitSearchDataController.shared
    @State private var isInstallingAll = false
    @State private var installMessage: String?

    var body: some View {
        List {
            Section("ספרייה") {
                componentRow(
                    title: "מסד ספרים", role: "חובה",
                    status: OtzariaMaktabahBridge.shared.databaseURL == nil ? "לא מותקן" : "מוכן"
                )
                componentRow(
                    title: "מילון לשוני משותף", role: "מומלץ",
                    status: OtzariaMagicDictionaryManager.shared.validatedDatabaseURL == nil ? "לא מותקן" : "מוכן"
                )
            }
            Section("אינדקסים לחיפוש") {
                componentRow(title: "אינדקס אוצריא", role: "מומלץ", status: otzaria.status.label)
                componentRow(title: "אינדקס זית", role: "מומלץ", status: zayitLabel)
            }
            Section {
                Button("הורד והתקן רכיבים חסרים") {
                    isInstallingAll = true
                    Task {
                        installMessage = nil
                        do {
                            if OtzariaMaktabahBridge.shared.databaseURL == nil {
                                try await OtzariaBootstrapAdapter.downloadAndInstallManagedDatabase { _ in }
                            }
                            if OtzariaMagicDictionaryManager.shared.validatedDatabaseURL == nil {
                                _ = try await OtzariaMagicDictionaryManager.shared.refreshIfNeeded(force: false)
                            }
                            otzaria.refreshStatus()
                            if !otzaria.isReady, !(await otzaria.installManagedArtifactAndWait()) {
                                throw SearchDataInstallError.component("אינדקס אוצריא", otzaria.errorMessage)
                            }
                            await zayit.refresh(discover: true)
                            if !zayit.state.isReady {
                                await zayit.install()
                                guard zayit.state.isReady else {
                                    throw SearchDataInstallError.component("אינדקס זית", zayitLabel)
                                }
                            }
                            installMessage = "כל הרכיבים שנבחרו מוכנים."
                        } catch {
                            installMessage = error.localizedDescription
                        }
                        isInstallingAll = false
                    }
                }
                .disabled(isInstallingAll)
                Button("המשך עם הספרייה בלבד") { dismiss() }
                    .foregroundStyle(.secondary)
                if let installMessage {
                    Text(installMessage)
                        .font(.footnote)
                        .foregroundStyle(installMessage.contains("מוכנים") ? .secondary : .red)
                }
            } footer: {
                Text("Components are downloaded and installed sequentially to reduce peak storage. Each component keeps its own version and identity.")
            }
            Section("מתקדם") {
                NavigationLink("אבחון") { SearchDiagnosticsView() }
                NavigationLink("ייבוא ידני של תיקיית זית") {
                    ZayitSearchView(
                        existingSeforimDB: { ZayitSearchExistingDatabaseProvider.currentURL },
                        openResult: { _ in }
                    )
                }
                Button("תקן את זית") { Task { await zayit.refresh(discover: true); await zayit.install() } }
                Button("הסר את זית", role: .destructive) { zayit.remove() }
                Button("תקן אינדקס אוצריא") { Task { _ = await otzaria.installManagedArtifactAndWait() } }
                Button("הסר אינדקס אוצריא", role: .destructive) { otzaria.removeManagedIndex() }
            }
        }
        .navigationTitle("נתוני חיפוש")
        .task {
            otzaria.refreshStatus()
            await zayit.refresh(discover: true)
        }
    }

    private func componentRow(title: String, role: String, status: String) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                Text(role).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(status).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
        }
    }

    private var zayitLabel: String {
        switch zayit.state {
        case .notInstalled: "לא מותקן"
        case .discovering: "בודק זמינות…"
        case .available(let download, let installed): "זמין · הורדה \(ByteCountFormatter.string(fromByteCount: download, countStyle: .file)) · מותקן \(ByteCountFormatter.string(fromByteCount: installed, countStyle: .file))"
        case .downloading(let completed, let total): "מוריד \(completed)/\(total)"
        case .installing(let completed, let total): "מתקין \(completed)/\(total)"
        case .ready(let manifest): "מוכן · \(manifest.version)"
        case .updateAvailable: "קיים עדכון"
        case .repairRequired(let detail): "נדרש תיקון · \(detail)"
        case .incompatible(let detail): "אינו תואם · \(detail)"
        case .failed(let detail): "נכשל · \(detail)"
        }
    }
}

private enum SearchDataInstallError: LocalizedError {
    case component(String, String?)
    var errorDescription: String? {
        switch self {
        case .component(let name, let detail):
            return "התקנת \(name) נכשלה. \(detail ?? "ניתן לנסות שוב מהמסך הזה.")"
        }
    }
}

struct SearchDiagnosticsView: View {
    @State private var report = "Loading…"

    var body: some View {
        List {
            Section {
                Text(report)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }
            Section {
                Button("Copy diagnostics", systemImage: "doc.on.doc") {
                    #if canImport(UIKit)
                    UIPasteboard.general.string = report
                    #endif
                }
            }
        }
        .navigationTitle("Search Diagnostics")
        .task { report = buildReport() }
    }

    private func buildReport() -> String {
        let bundle = Bundle.main
        var values: [(String, String)] = [
            ("app.version", bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"),
            ("app.build", bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"),
        ]
        if let storage = try? OtzariaDatabaseStorage(),
           let data = try? Data(contentsOf: storage.installationManifestURL),
           let manifest = try? JSONDecoder().decode(OtzariaDatabaseInstallationManifest.self, from: data) {
            values += [
                ("database.release", manifest.releaseTag),
                ("database.assetDigest", manifest.digest ?? "unknown"),
                ("database.bytes", String(manifest.databaseFileSize)),
            ]
        }
        if let build = try? OtzariaSearchEngineBridge.buildInfo() {
            values += [
                ("otzaria.engineCommit", build.upstreamCommit),
                ("otzaria.schema", String(build.indexSchemaVersion)),
                ("semantic.compiled", String(build.semanticEnabled)),
            ]
            let path = OtzariaMaktabahBridge.shared.databasePath
            let semanticInstalled = path.map {
                FileManager.default.fileExists(atPath: OtzariaSearchIndexManager.shared.semanticArtifactURL(for: $0).path)
            } ?? false
            values += [
                ("semantic.artifactInstalled", String(semanticInstalled)),
                ("semantic.inferenceReady", "false"),
                ("hybrid.available", "false"),
            ]
        }
        if let storage = try? ZayitSearchArtifactStorage(),
           let data = try? Data(contentsOf: storage.installedManifest),
           let manifest = try? JSONDecoder().decode(ZayitSearchArtifactManifest.self, from: data) {
            values += [
                ("zayit.schema", String(manifest.engine.indexSchemaVersion)),
                ("zayit.builder", "\(manifest.engine.builderVersion)@\(manifest.engine.builderCommit)"),
                ("zayit.upstream", manifest.engine.upstreamCommit),
                ("zayit.artifactIdentity", manifest.artifactIdentity),
            ]
        }
        if let lexical = OtzariaMagicDictionaryManager.shared.validatedDatabaseURL,
           let attributes = try? FileManager.default.attributesOfItem(atPath: lexical.path) {
            values.append(("lexical.bytes", String((attributes[.size] as? NSNumber)?.int64Value ?? 0)))
            values.append(("lexical.ready", "true"))
        } else {
            values.append(("lexical.ready", "false"))
        }
        values += [
            ("otzaria.log", OtzariaIndexFileLogger.logFileURL()?.path ?? "unavailable"),
            ("privacy", "No query text, document content, bookmarks, or user paths are included beyond managed log locations."),
        ]
        return values.map { "\($0.0)=\($0.1)" }.joined(separator: "\n")
    }
}

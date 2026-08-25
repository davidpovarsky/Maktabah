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

    let openOtzaria: (SearchResultItem, HighlightDescriptor) -> Void
    let openZayit: (ZayitSearchHit, HighlightDescriptor) -> Void

    var body: some View {
        Group {
            if packageMissing {
                ContentUnavailableView {
                    Label("Search data is not ready", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text("Install or repair the selected search component in Search Data.")
                } actions: {
                    Button("Open Search Data") { showsSearchData = true }
                        .buttonStyle(.borderedProminent)
                }
            } else if results.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                List(results) { result in
                    resultButton(result)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Search")
        .searchable(
            text: $query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search all texts"
        )
        .searchScopes($scope) {
            ForEach(UnifiedSearchScope.allCases) { item in Text(item.title).tag(item) }
        }
        .onSubmit(of: .search, runSearch)
        .safeAreaInset(edge: .top) {
            VStack(spacing: 8) {
                if scope == .advanced {
                    DisclosureGroup("Advanced options", isExpanded: $showsAdvanced) {
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
        VStack(spacing: 8) {
            HStack {
                Picker("Words", selection: $otzaria.wordMatchMode) {
                    Text("All").tag(OtzariaWordMatchMode.all)
                    Text("Any").tag(OtzariaWordMatchMode.anyWord)
                    Text("Most").tag(OtzariaWordMatchMode.mostWords)
                    Text("At least").tag(OtzariaWordMatchMode.atLeast)
                }
                Stepper("Distance \(otzaria.distance)", value: $otzaria.distance, in: 0...20)
            }
            Toggle("Same section", isOn: Binding(
                get: { otzaria.scope == .sameSection },
                set: { otzaria.scope = $0 ? .sameSection : .wordDistance }
            ))
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

    private var isLoading: Bool { scope == .zayit ? zayitSession.model.isLoading : otzaria.isSearching }
    private var statusText: String {
        if scope == .zayit {
            if let error = zayitSession.model.errorMessage { return error }
            return zayitSession.model.hits.isEmpty ? "Zayit" : "Zayit results"
        }
        return otzaria.status.label
    }

    private func runSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
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
            otzaria.search()
        }
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
    @StateObject private var otzaria = OtzariaTextSearchViewModel()
    @StateObject private var zayit = ZayitSearchDataController.shared
    @State private var isInstallingAll = false

    var body: some View {
        List {
            Section("Library") {
                componentRow(
                    title: "Seforim DB", role: "Required",
                    status: OtzariaMaktabahBridge.shared.databaseURL == nil ? "Not installed" : "Ready"
                )
                componentRow(
                    title: "Shared lexical.db", role: "Recommended",
                    status: OtzariaMagicDictionaryManager.shared.validatedDatabaseURL == nil ? "Not installed" : "Ready"
                )
            }
            Section("Search indexes") {
                componentRow(title: "Otzaria lexical index", role: "Recommended", status: otzaria.status.label)
                componentRow(title: "Zayit index", role: "Recommended", status: zayitLabel)
            }
            Section {
                Button("Download and install all") {
                    isInstallingAll = true
                    Task {
                        _ = try? await OtzariaMagicDictionaryManager.shared.refreshIfNeeded(force: true)
                        await zayit.refresh(discover: true)
                        await zayit.install()
                        otzaria.rebuildIndex()
                        isInstallingAll = false
                    }
                }
                .disabled(isInstallingAll)
                Button("Continue with library only") { }
                    .foregroundStyle(.secondary)
            } footer: {
                Text("Components are downloaded and installed sequentially to reduce peak storage. Each component keeps its own version and identity.")
            }
            Section("Advanced") {
                NavigationLink("Diagnostics") { SearchDiagnosticsView() }
                NavigationLink("Manual Zayit folder import") {
                    ZayitSearchView(
                        existingSeforimDB: { ZayitSearchExistingDatabaseProvider.currentURL },
                        openResult: { _ in }
                    )
                }
                Button("Repair Zayit") { Task { await zayit.refresh(discover: true); await zayit.install() } }
                Button("Remove Zayit", role: .destructive) { zayit.remove() }
            }
        }
        .navigationTitle("Search Data")
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
        case .notInstalled: "Not installed"
        case .discovering: "Checking…"
        case .available(let download, let installed): "Available · \(ByteCountFormatter.string(fromByteCount: download, countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: installed, countStyle: .file))"
        case .downloading(let completed, let total): "Downloading \(completed)/\(total)"
        case .installing(let completed, let total): "Installing \(completed)/\(total)"
        case .ready(let manifest): "Ready · \(manifest.version)"
        case .updateAvailable: "Update available"
        case .repairRequired(let detail): "Repair required · \(detail)"
        case .incompatible(let detail): "Incompatible · \(detail)"
        case .failed(let detail): "Failed · \(detail)"
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

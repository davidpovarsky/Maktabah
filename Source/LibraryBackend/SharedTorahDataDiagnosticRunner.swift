#if os(iOS)
import Foundation

/// Opt-in simulator diagnostic for the complete shared Reader/Inspector/Search
/// data path. Normal application launches never enter this path.
@MainActor
enum SharedTorahDataDiagnosticRunner {
    private static let backendKey = "SHARED_TORAH_DIAGNOSTIC"
    private static let resultKey = "SHARED_TORAH_DIAGNOSTIC_RESULT"

    static var isRequested: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment[backendKey] != nil
        #else
        false
        #endif
    }

    struct Row: Codable {
        let backend: String
        let locale: String
        let component: String
        let input: String
        let expected: String
        let actual: String
        let passed: Bool
        let error: String?
    }

    struct Report: Codable {
        let backend: String
        let locale: String
        var rows: [Row]
        var passed: Bool { rows.allSatisfy(\.passed) }
    }

    private struct Scenario {
        let sectionLocator: TextLocator
        let searchQuery: String
    }

    static func runIfRequested() async {
        let environment = ProcessInfo.processInfo.environment
        guard let backendValue = environment[backendKey],
              let backend = BackendID(rawValue: backendValue),
              let resultPath = environment[resultKey] else { return }

        let requestedLocale = environment["SHARED_TORAH_DIAGNOSTIC_LOCALE"]
            ?? Locale.preferredLanguages.first
            ?? Locale.current.identifier
        var report = Report(backend: backend.rawValue, locale: requestedLocale, rows: [])

        // Every locale launch starts without a persisted Reader override. This
        // verifies the locale default while preserving normal explicit choices.
        UserDefaults.standard.removeObject(forKey: "libraryReaderTextMode.v1")

        do {
            BackendComposition.registerAll()
            if backend == .otzaria {
                guard try OtzariaMaktabahBridge.shared.restoreDatabaseIfPossible() else {
                    throw LibraryBackendError.invalidResponse("installed Otzaria database was not restored")
                }
            }
            BackendCoordinator.shared.select(backend)
            let scenario = try await scenario(for: backend, locale: requestedLocale)
            await diagnoseReader(scenario, backend: backend, locale: requestedLocale, report: &report)
            await diagnoseInspector(scenario, backend: backend, locale: requestedLocale, report: &report)
            await diagnoseSearch(scenario, backend: backend, locale: requestedLocale, report: &report)
        } catch {
            append(
                component: "setup",
                input: backend.rawValue,
                expected: "active backend with real data",
                actual: "setup failed",
                error: error,
                backend: backend,
                locale: requestedLocale,
                report: &report
            )
        }

        do {
            let data = try JSONEncoder.pretty.encode(report)
            try data.write(to: URL(fileURLWithPath: resultPath), options: .atomic)
        } catch {
            print("[SharedTorahDiagnostic] unable to write report: \(error)")
        }
    }

    private static func scenario(for backend: BackendID, locale: String) async throws -> Scenario {
        switch backend {
        case .sefaria:
            return Scenario(
                sectionLocator: TextLocator(
                    backend: .sefaria,
                    workKey: "Genesis",
                    position: .canonicalRef("Genesis 1:1")
                ),
                searchQuery: isHebrew(locale) ? "בראשית" : "beginning"
            )
        case .otzaria:
            let catalog = try await BackendCoordinator.shared.catalog(forceRefresh: true)
            let works = catalog.flatMap(works(in:))
            guard let firstWork = works.first else {
                throw LibraryBackendError.invalidResponse("empty Otzaria catalog")
            }
            let linkedLocator = try linkedOtzariaLocator()
            return Scenario(
                sectionLocator: linkedLocator ?? firstWork.locator,
                searchQuery: "בראשית"
            )
        }
    }

    private static func diagnoseReader(
        _ scenario: Scenario,
        backend: BackendID,
        locale: String,
        report: inout Report
    ) async {
        do {
            let section = try await BackendCoordinator.shared.section(at: scenario.sectionLocator)
            let preferredMode = UserDefaults.standard.libraryReaderTextMode
            let render = LibraryReaderRenderModel(section: section, preferredMode: preferredMode)
            let exact = section.segments.first { $0.locator == scenario.sectionLocator }
                ?? section.segments.first
            let wantsHebrew = isHebrew(locale)
            let translationExists = section.segments.contains { !($0.translation?.readerPlainText ?? "").isEmpty }
            let expectedMode: LibraryReaderTextMode = wantsHebrew || !translationExists ? .source : .translation
            let languagePassed = wantsHebrew || !translationExists
                ? containsHebrew(render.text)
                : !containsHebrew(render.text)
            let passed = !section.segments.isEmpty
                && exact != nil
                && !render.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && render.mode == expectedMode
                && languagePassed
                && section.locator.backend == backend

            append(
                component: "Reader",
                input: scenario.sectionLocator.persistenceKey,
                expected: "nonblank exact segment; mode=\(expectedMode.rawValue); backend=\(backend.rawValue)",
                actual: "ref=\(section.displayRef); segments=\(section.segments.count); mode=\(render.mode.rawValue); chars=\(render.text.count)",
                passed: passed,
                backend: backend,
                locale: locale,
                report: &report
            )

            if let next = section.next {
                let nextSection = try await BackendCoordinator.shared.section(at: next)
                append(
                    component: "Reader navigation",
                    input: next.persistenceKey,
                    expected: "next section from same backend with text",
                    actual: "backend=\(nextSection.locator.backend.rawValue); segments=\(nextSection.segments.count)",
                    passed: nextSection.locator.backend == backend && !nextSection.segments.isEmpty,
                    backend: backend,
                    locale: locale,
                    report: &report
                )
            }
        } catch {
            append(component: "Reader", input: scenario.sectionLocator.persistenceKey,
                expected: "section and segments", actual: "request failed", error: error,
                backend: backend, locale: locale, report: &report)
        }
    }

    private static func diagnoseInspector(
        _ scenario: Scenario,
        backend: BackendID,
        locale: String,
        report: inout Report
    ) async {
        do {
            let reference = inspectorReference(for: scenario.sectionLocator)
            let session = MaktabahTorahInspectorSession()
            let document = try await session.repository.document(
                for: reference,
                providerID: backend.rawValue
            )
            let links = try await session.repository.links(for: reference, providerID: backend.rawValue)
            let topics = try await session.repository.topics(for: reference, providerID: backend.rawValue)
            let selected = document.segments.first { $0.canonicalRef == reference }
                ?? document.segments.first
            let wantsHebrew = isHebrew(locale)
            let selectedText = selected?.text ?? ""
            let languagePassed = backend == .otzaria || wantsHebrew
                ? containsHebrew(selectedText)
                : !containsHebrew(selectedText)
            let refPassed = wantsHebrew
                ? !(selected?.hebrewRef ?? document.hebrewRef ?? "").isEmpty
                : !(selected?.canonicalRef ?? "").isEmpty
            let snippetCount = links.filter {
                let preferred = wantsHebrew ? $0.hebrewText : $0.englishText
                let fallback = wantsHebrew ? $0.englishText : $0.hebrewText
                return !((preferred ?? fallback) ?? "").readerPlainText.isEmpty
            }.count
            let snippetsPassed = snippetCount > 0
            let passed = document.providerID == backend.rawValue
                && selected != nil
                && !selectedText.readerPlainText.isEmpty
                && languagePassed
                && refPassed
                && !links.isEmpty
                && snippetsPassed

            append(
                component: "Inspector",
                input: reference,
                expected: "selected text/ref, relationships/snippets, stable backend",
                actual: "provider=\(document.providerID); selected=\(selected?.canonicalRef ?? "nil"); links=\(links.count); snippets=\(snippetCount); topics=\(topics.count)",
                passed: passed,
                backend: backend,
                locale: locale,
                report: &report
            )

            if let linked = links.first {
                let linkedDocument = try await session.repository.document(
                    for: linked.sourceRef,
                    providerID: backend.rawValue
                )
                let openedExact = linkedDocument.segments.contains { $0.canonicalRef == linked.sourceRef }
                    || linkedDocument.canonicalRef == linked.sourceRef
                append(
                    component: "Inspector linked source",
                    input: linked.sourceRef,
                    expected: "exact linked source on \(backend.rawValue)",
                    actual: "provider=\(linkedDocument.providerID); ref=\(linkedDocument.canonicalRef)",
                    passed: linkedDocument.providerID == backend.rawValue && openedExact,
                    backend: backend,
                    locale: locale,
                    report: &report
                )
            }
        } catch {
            append(component: "Inspector", input: scenario.sectionLocator.persistenceKey,
                expected: "document, links, topics and linked source", actual: "request failed", error: error,
                backend: backend, locale: locale, report: &report)
        }
    }

    private static func diagnoseSearch(
        _ scenario: Scenario,
        backend: BackendID,
        locale: String,
        report: inout Report
    ) async {
        do {
            let page = try await BackendCoordinator.shared.search(.init(
                query: scenario.searchQuery,
                offset: 0,
                limit: 25
            ))
            guard let hit = page.hits.first else {
                throw LibraryBackendError.invalidResponse("search returned no hits")
            }
            let opened = try await BackendCoordinator.shared.section(at: hit.locator)
            let exact = opened.segments.first { $0.locator == hit.locator }
            let session = MaktabahTorahInspectorSession()
            let reference = inspectorReference(for: hit.locator)
            let inspected = try await session.repository.document(for: reference, providerID: backend.rawValue)
            let inspectorExact = inspected.segments.contains { $0.canonicalRef == reference }
                || inspected.canonicalRef == reference
            let wantsHebrew = isHebrew(locale) || backend == .otzaria
            let languagePassed = wantsHebrew ? containsHebrew(hit.snippet) : !containsHebrew(hit.snippet)
            let passed = hit.locator.backend == backend
                && !hit.displayRef.isEmpty
                && !hit.snippet.readerPlainText.isEmpty
                && languagePassed
                && exact != nil
                && inspectorExact
                && inspected.providerID == backend.rawValue

            append(
                component: "Search",
                input: scenario.searchQuery,
                expected: "localized result opens exact segment and same Inspector backend",
                actual: "total=\(page.total); ref=\(hit.displayRef); target=\(hit.locator.persistenceKey); exact=\(exact != nil)",
                passed: passed,
                backend: backend,
                locale: locale,
                report: &report
            )
        } catch {
            append(component: "Search", input: scenario.searchQuery,
                expected: "results and exact Reader/Inspector target", actual: "request failed", error: error,
                backend: backend, locale: locale, report: &report)
        }
    }

    private static func linkedOtzariaLocator() throws -> TextLocator? {
        try OtzariaMaktabahBridge.shared.withDatabase { database in
            try database.fetch(query: """
                SELECT l.sourceBookId, sourceLine.lineIndex
                FROM link l
                JOIN line sourceLine ON sourceLine.id = l.sourceLineId
                ORDER BY l.id
                LIMIT 1
            """) { row in
                TextLocator(
                    backend: .otzaria,
                    workKey: "book:\(row.int(at: 0))",
                    position: .legacyLine(row.int(at: 1))
                )
            }.first
        }
    }

    private static func works(in node: LibraryCatalogNode) -> [LibraryWork] {
        (node.work.map { [$0] } ?? []) + node.children.flatMap(works(in:))
    }

    private static func inspectorReference(for locator: TextLocator) -> String {
        switch (locator.backend, locator.position) {
        case (.sefaria, .canonicalRef(let reference)):
            return reference
        case (.otzaria, .legacyLine(let lineIndex)):
            let bookID = locator.workKey.replacingOccurrences(of: "book:", with: "")
            return "otzaria:v1:\(bookID):\(lineIndex)"
        default:
            return locator.persistenceKey
        }
    }

    private static func isHebrew(_ locale: String) -> Bool {
        locale.lowercased().hasPrefix("he") || locale.lowercased().hasPrefix("iw")
    }

    private static func containsHebrew(_ value: String) -> Bool {
        value.unicodeScalars.contains { (0x0590...0x05FF).contains(Int($0.value)) }
    }

    private static func append(
        component: String,
        input: String,
        expected: String,
        actual: String,
        passed: Bool = false,
        error: Error? = nil,
        backend: BackendID,
        locale: String,
        report: inout Report
    ) {
        report.rows.append(Row(
            backend: backend.rawValue,
            locale: locale,
            component: component,
            input: input,
            expected: expected,
            actual: actual,
            passed: passed,
            error: error?.localizedDescription
        ))
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
#endif

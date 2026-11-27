import Foundation
import TorahInspectorCore

@main struct InspectorGenerationControls {
    @MainActor static func main() async throws {
        var results: [[String: Any]] = []
        func record(_ name: String, _ passed: Bool, _ witness: [String: Any] = [:]) {
            results.append(["name": name, "passed": passed, "witness": witness])
        }
        let locator = TextLocator(backend: .sefaria, workKey: "Fixture", position: .canonicalRef("Fixture 1"))
        let selection = TorahInspectorSelection(providerID: "sefaria", canonicalRef: "Fixture 1", scope: .section)

        do {
            let coordinator = BackendCoordinator()
            let session = MaktabahTorahInspectorSession(coordinator: coordinator, preferredMode: .source)
            let first = session.repository
            _ = try await first.document(for: "Fixture 1", providerID: "sefaria")
            _ = try await session.repository.document(for: "Fixture 1", providerID: "sefaria")
            record("same-generation-reuses-original-Kit-cache", first === session.repository && coordinator.sectionCalls == 1,
                   ["providerCalls": coordinator.sectionCalls])
            coordinator.payload = "generation-B"; coordinator.generation += 1
            let current = session.repository
            let document = try await current.document(for: "Fixture 1", providerID: "sefaria")
            record("hidden-session-reopens-current-document", current !== first && document.segments.first?.text == "generation-B",
                   ["text": document.segments.first?.text ?? "", "providerCalls": coordinator.sectionCalls])
        }
        for kind in ["links", "topics"] {
            let coordinator = BackendCoordinator()
            let session = MaktabahTorahInspectorSession(coordinator: coordinator, preferredMode: .source)
            if kind == "links" { _ = try await session.repository.links(for: "Fixture 1", providerID: "sefaria") }
            else { _ = try await session.repository.topics(for: "Fixture 1", providerID: "sefaria") }
            coordinator.payload = "generation-B"; coordinator.generation += 1
            let payload: String?
            if kind == "links" { payload = try await session.repository.links(for: "Fixture 1", providerID: "sefaria").first?.hebrewText }
            else { payload = try await session.repository.topics(for: "Fixture 1", providerID: "sefaria").first?.slug }
            record("hidden-session-reopens-current-" + kind, payload == "generation-B", ["payload": payload ?? ""])
        }
        do {
            let coordinator = BackendCoordinator()
            let reader = ReaderViewModel()
            reader.currentBook = .init(id: 1, book: "Fixture", backendLocator: locator)
            reader.backendSection = makeSection(locator, text: "source")
            reader.currentAnnotations = [.init(id: 1, bkId: 1, backendLocator: locator, note: "generation-A")]
            let session = MaktabahTorahInspectorSession(coordinator: coordinator, preferredMode: .source, viewModel: reader)
            _ = try await session.repository.notes(for: selection)
            reader.currentAnnotations[0].note = "generation-B"; coordinator.generation += 1
            let notes = try await session.repository.notes(for: selection)
            record("hidden-session-reopens-current-notes", notes.first?.note == "generation-B", ["note": notes.first?.note ?? ""])
        }
        do {
            let coordinator = BackendCoordinator(); coordinator.activeBackendID = .otzaria
            let bridge = OtzariaMaktabahBridge()
            let reader = ReaderViewModel(); reader.currentBook = .init(id: 1, book: "Fixture", backendLocator: nil)
            let session = MaktabahTorahInspectorSession(coordinator: coordinator, otzaria: bridge, preferredMode: .source, viewModel: reader)
            let oldSelection = session.selection(sefariaLocator: nil, otzariaLine: nil)!
            let first = try await session.repository.links(for: oldSelection.relationshipRef, providerID: "otzaria")
            bridge.payload = "generation-B"; coordinator.generation += 1
            reader.readerInspectorVisible = true
            let currentSelection = session.selection(sefariaLocator: nil, otzariaLine: nil)!
            let current = try await session.repository.links(for: currentSelection.relationshipRef, providerID: "otzaria")
            record("Otzaria-Kit-and-adapter-link-caches-retire-together",
                   oldSelection.relationshipRef == currentSelection.relationshipRef && first.first?.hebrewText == "generation-A"
                     && current.first?.hebrewText == "generation-B" && bridge.linkCalls == 2,
                   ["sameReference": oldSelection.relationshipRef == currentSelection.relationshipRef,
                    "before": first.first?.hebrewText ?? "", "after": current.first?.hebrewText ?? "", "providerCalls": bridge.linkCalls])
            record("initial-session-admission-preserves-user-open-action", reader.readerInspectorVisible)
            let source = TorahLinkedSource(sourceRef: "otzaria:v1:2:1", category: "Commentary", type: "commentary")
            let a = try await session.repository.fetchSnippets(for: [source])
            bridge.payload = "generation-C"; coordinator.generation += 1
            let b = try await session.repository.fetchSnippets(for: [source])
            record("hidden-session-reopens-current-snippets", a[source.id] == "generation-B" && b[source.id] == "generation-C",
                   ["before": a[source.id] ?? "", "after": b[source.id] ?? ""])
        }
        do {
            let coordinator = BackendCoordinator()
            let session = MaktabahTorahInspectorSession(coordinator: coordinator, preferredMode: .source)
            let retired = session.repository
            coordinator.generation += 1
            var cancelled = false
            do { _ = try await retired.document(for: "Uncached 2", providerID: "sefaria") }
            catch is CancellationError { cancelled = true }
            record("retired-repository-callback-cannot-read-new-generation", cancelled && coordinator.sectionCalls == 0,
                   ["cancelled": cancelled, "providerCalls": coordinator.sectionCalls])
        }
        for kind in ["document", "links", "topics"] {
            let coordinator = BackendCoordinator()
            let gate = ProviderGate(); coordinator.gate = gate; coordinator.gateKind = kind
            let session = MaktabahTorahInspectorSession(coordinator: coordinator, preferredMode: .source)
            let retired = session.repository
            let work = Task { @MainActor () -> Bool in
                do {
                    if kind == "document" { _ = try await retired.document(for: "Fixture 1", providerID: "sefaria") }
                    else if kind == "links" { _ = try await retired.links(for: "Fixture 1", providerID: "sefaria") }
                    else { _ = try await retired.topics(for: "Fixture 1", providerID: "sefaria") }
                    return false
                } catch is CancellationError { return true }
                catch { return false }
            }
            let deadline = Date().addingTimeInterval(5)
            while !gate.suspended && Date() < deadline { await Task.yield() }
            guard gate.suspended else { fatalError("Provider gate did not suspend") }
            coordinator.generation += 1; coordinator.payload = "generation-B"
            let current = session.repository
            gate.release()
            let cancelled = await work.value
            let cached: Bool
            if kind == "document" { cached = retired.cachedDocument(for: "Fixture 1", providerID: "sefaria") != nil }
            else if kind == "links" { cached = retired.cachedLinks(for: "Fixture 1", providerID: "sefaria") != nil }
            else { cached = retired.cachedTopics(for: "Fixture 1", providerID: "sefaria") != nil }
            record("generation-change-during-" + kind + "-cannot-publish", cancelled && !cached && current !== retired,
                   ["cancelled": cancelled, "retiredCachePopulated": cached, "newRepository": current !== retired])
        }
        let report: [String: Any] = ["scope": "actual unchanged adapter and pinned Kit, deterministic provider boundaries; not UI/corpus acceptance",
                                   "passed": results.filter { $0["passed"] as? Bool == true }.count,
                                   "total": results.count, "cases": results]
        let data = try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys, .prettyPrinted])
        try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
        print(String(decoding: data, as: UTF8.self))
    }
}

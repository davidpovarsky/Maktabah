import Foundation
import TorahInspectorCore

/// Runs the complete product Session and actual Kit caches against declared
/// provider/reader boundaries. This does not mount SwiftUI or prove app UI.
@main struct InspectorModeControls {
    @MainActor static func main() async throws {
        var results: [[String: Any]] = []
        func record(_ name: String, _ passed: Bool, _ witness: [String: Any] = [:]) {
            results.append(["name": name, "passed": passed, "witness": witness])
        }
        let locator = TextLocator(backend: .sefaria, workKey: "Fixture", position: .canonicalRef("Fixture 1"))
        let coordinator = BackendCoordinator()
        coordinator.payload = "source-A"
        let reader = ReaderViewModel()
        reader.currentBook = .init(id: 1, book: "Fixture", backendLocator: locator)
        reader.backendSection = makeSection(locator, text: "source-A")
        reader.selectedSegmentLocator = locator
        reader.selectedSegmentRange = .init(location: 2, length: 3)
        reader.readerInspectorVisible = true
        let original = MaktabahTorahInspectorSession(coordinator: coordinator, preferredMode: .source, viewModel: reader)
        let originalRepository = original.repository
        let originalDocument = try await originalRepository.document(for: "Fixture 1", providerID: "sefaria")

        record("matching-mode-keeps-session-cache-selection-and-open-state",
               original.replacementForTextMode(.source, viewModel: reader) == nil
                 && original.repository === originalRepository && coordinator.sectionCalls == 1
                 && reader.selectedSegmentLocator == locator
                 && reader.selectedSegmentRange == NSRange(location: 2, length: 3)
                 && reader.readerInspectorVisible,
               ["providerCalls": coordinator.sectionCalls, "source": originalDocument.segments.first?.text ?? ""])

        guard let translation = original.replacementForTextMode(.translation, viewModel: reader) else {
            fatalError("A changed mode must produce a distinct Session")
        }
        let translated = try await translation.repository.document(for: "Fixture 1", providerID: "sefaria")
        record("mode-admission-replaces-both-cache-owner-and-language-mapping",
               translation !== original && translation.repository !== originalRepository
                 && translated.segments.first?.text == "translation:source-A"
                 && translated.canonicalRef == originalDocument.canonicalRef
                 && translated.hebrewRef == nil && translated.segments.first?.hebrewRef == nil
                 && translated.version.language == "en",
               ["source": originalDocument.segments.first?.text ?? "", "translation": translated.segments.first?.text ?? "",
                "translationLanguage": translated.version.language, "sameReference": translated.canonicalRef == originalDocument.canonicalRef])

        let translatedRepository = translation.repository
        reader.readerInspectorVisible = false
        let hiddenAdmission = translation.replacementForTextMode(.translation, viewModel: reader)
        reader.readerInspectorVisible = true
        let reopenedAdmission = translation.replacementForTextMode(.translation, viewModel: reader)
        record("matching-mode-close-and-reopen-do-not-discard-current-cache",
               hiddenAdmission == nil && reopenedAdmission == nil && translation.repository === translatedRepository
                 && reader.readerInspectorVisible && reader.selectedSegmentLocator == locator,
               ["providerCalls": coordinator.sectionCalls])

        guard let both = translation.replacementForTextMode(.both, viewModel: reader),
              let sourceAgain = both.replacementForTextMode(.source, viewModel: reader) else {
            fatalError("Every actual mode change must replace the old Session")
        }
        let combined = try await both.repository.document(for: "Fixture 1", providerID: "sefaria")
        let source = try await sourceAgain.repository.document(for: "Fixture 1", providerID: "sefaria")
        record("translation-both-source-roundtrip-keeps-distinct-original-mappings",
               combined.segments.first?.text == "source-A\ntranslation:source-A"
                 && source.segments.first?.text == "source-A"
                 && source.version.language == "he" && source.hebrewRef == "Fixture Hebrew 1"
                 && both.repository !== translatedRepository && sourceAgain.repository !== both.repository,
               ["both": combined.segments.first?.text ?? "", "sourceAgain": source.segments.first?.text ?? ""])

        for generationFirst in [true, false] {
            let owner = BackendCoordinator()
            let retained = MaktabahTorahInspectorSession(coordinator: owner, preferredMode: .source, viewModel: reader)
            let oldRepository = retained.repository
            _ = try await oldRepository.document(for: "Fixture 1", providerID: "sefaria")
            owner.payload = "generation-B"; owner.generation += 1
            if generationFirst { retained.refreshForCurrentGeneration() }
            guard let current = retained.replacementForTextMode(.translation, viewModel: reader) else { fatalError("Missing replacement") }
            if !generationFirst { current.refreshForCurrentGeneration() }
            let document = try await current.repository.document(for: "Fixture 1", providerID: "sefaria")
            record("generation-plus-mode-" + (generationFirst ? "generation-first" : "mode-first"),
                   document.segments.first?.text == "translation:generation-B"
                     && current.repository !== oldRepository && current.replacementForTextMode(.translation, viewModel: reader) == nil,
                   ["text": document.segments.first?.text ?? "", "generation": owner.generation])
        }

        do {
            let owner = BackendCoordinator()
            owner.payload = "source-before-hide"
            let retained = MaktabahTorahInspectorSession(coordinator: owner, preferredMode: .source, viewModel: reader)
            _ = try await retained.repository.document(for: "Fixture 1", providerID: "sefaria")
            reader.readerInspectorVisible = false
            reader.currentReaderTextMode = .translation
            owner.payload = "source-after-hide"
            reader.readerInspectorVisible = true
            guard let current = retained.replacementForTextMode(reader.currentReaderTextMode, viewModel: reader) else { fatalError("Missing remount admission") }
            let document = try await current.repository.document(for: "Fixture 1", providerID: "sefaria")
            record("remount-admission-can-replace-retained-hidden-mode",
                   document.segments.first?.text == "translation:source-after-hide"
                     && reader.readerInspectorVisible && reader.selectedSegmentRange == NSRange(location: 2, length: 3),
                   ["text": document.segments.first?.text ?? "", "scope": "Calls the product admission API; SwiftUI mount scheduling remains an original UI gate"])
        }

        do {
            let owner = BackendCoordinator()
            owner.payload = "suspended-source"
            let gate = ProviderGate(); owner.gate = gate; owner.gateKind = "document"
            let old = MaktabahTorahInspectorSession(coordinator: owner, preferredMode: .source, viewModel: reader)
            let oldRepository = old.repository
            let oldFetch = Task { @MainActor in try await oldRepository.document(for: "Fixture 1", providerID: "sefaria") }
            let deadline = Date().addingTimeInterval(5)
            while !gate.suspended && Date() < deadline { await Task.yield() }
            guard gate.suspended else { fatalError("Provider did not suspend") }
            owner.gateKind = ""; owner.payload = "current-source"
            guard let current = old.replacementForTextMode(.translation, viewModel: reader) else { fatalError("Missing replacement") }
            let fresh = try await current.repository.document(for: "Fixture 1", providerID: "sefaria")
            gate.release()
            let retired = try await oldFetch.value
            let reread = try await current.repository.document(for: "Fixture 1", providerID: "sefaria")
            record("old-mode-completion-cannot-populate-the-new-repository",
                   retired.segments.first?.text == "suspended-source"
                     && fresh.segments.first?.text == "translation:current-source"
                     && reread.segments.first?.text == "translation:current-source"
                     && current.repository !== oldRepository,
                   ["retired": retired.segments.first?.text ?? "", "current": reread.segments.first?.text ?? "",
                    "scope": "Retired external Kit objects may retain their own snapshot; they are not the current Session"])
        }

        let report: [String: Any] = [
            "scope": "Whole original candidate Session plus actual pinned Kit caches; declared synthetic provider/reader boundaries; no SwiftUI, app, simulator or source-corpus acceptance",
            "passed": results.filter { $0["passed"] as? Bool == true }.count,
            "total": results.count, "cases": results
        ]
        let data = try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys, .prettyPrinted])
        try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
        print(String(decoding: data, as: UTF8.self))
    }
}

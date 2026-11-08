#if os(iOS)
import SwiftUI

/// Optional control inside the existing View Options sheet.
struct OtzariaVersionPicker: View {
    let reader: ReaderViewModel
    @State private var versions: [TextVersionMetadata] = []
    @State private var error: String?
    private var hebrew: Bool { LibraryPresentationPolicy.prefersHebrew() }

    var body: some View {
        Group {
            if let locator = reader.otzariaEditionLocator, locator.backend == .otzaria {
                Picker(hebrew ? "מהדורת טקסט" : "Text edition", selection: Binding<TextVersionMetadata?>(
                    get: { reader.selectedOtzariaVersion(for: locator) },
                    set: { reader.selectOtzariaVersion($0, for: locator) }
                )) {
                    Text(hebrew ? "נוסח משולב" : "Merged text").tag(Optional<TextVersionMetadata>.none)
                    ForEach(versions, id: \.self) { version in
                        Text(hebrew ? version.heTitle ?? version.title : version.title).tag(Optional(version))
                    }
                }
                // Keep a real Form row mounted while its task loads metadata.
                .disabled(versions.isEmpty)
                .accessibilityIdentifier("reader-otzaria-edition")
            }
            if let error { Text(error).foregroundStyle(.secondary) }
        }
        .task(id: [reader.otzariaEditionLocator?.backend.rawValue ?? "",
                   reader.otzariaEditionLocator?.workKey ?? "",
                   String(OtzariaMaktabahBridge.shared.generationSnapshot())]) {
            versions = []
            error = nil
            guard let locator = reader.otzariaEditionLocator, locator.backend == .otzaria else { return }
            do {
                let loaded = try await BackendCoordinator.shared.versions(for: locator.workKey)
                try Task.checkCancellation()
                versions = loaded
            } catch is CancellationError { return }
            catch { self.error = error.localizedDescription }
        }
    }
}

extension ReaderViewModel {
    /// The canonical destination also exists when legacy BooksData has no backend locator.
    var otzariaEditionLocator: TextLocator? {
        currentDestination?.sectionLocator ?? backendSection?.locator ?? currentBook?.backendLocator
    }

    func selectedOtzariaVersion(for locator: TextLocator) -> TextVersionMetadata? {
        guard locator.backend == .otzaria else { return nil }
        return otzariaVersionSelection.selection(workKey: locator.workKey,
            generation: OtzariaMaktabahBridge.shared.generationSnapshot())
    }

    func selectOtzariaVersion(_ version: TextVersionMetadata?, for locator: TextLocator) {
        guard locator.backend == .otzaria,
              otzariaEditionLocator?.backend == .otzaria,
              otzariaEditionLocator?.workKey == locator.workKey else { return }
        otzariaVersionSelection.select(version, workKey: locator.workKey,
            generation: OtzariaMaktabahBridge.shared.generationSnapshot())
        let destination = currentDestination ?? .init(sectionLocator: backendSection?.locator ?? locator, focusLocator: selectedSegmentLocator)
        backendSection = nil
        backendRenderModel = nil
        contentText = ""
        loadBackendContent(destination)
    }
}
#endif

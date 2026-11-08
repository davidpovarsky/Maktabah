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
            if !versions.isEmpty, let locator = reader.currentBook?.backendLocator {
                Picker(hebrew ? "מהדורת טקסט" : "Text edition", selection: Binding<TextVersionMetadata?>(
                    get: { reader.selectedOtzariaVersion(for: locator) },
                    set: { reader.selectOtzariaVersion($0, for: locator) }
                )) {
                    Text(hebrew ? "נוסח משולב" : "Merged text").tag(Optional<TextVersionMetadata>.none)
                    ForEach(versions, id: \.self) { version in
                        Text(hebrew ? version.heTitle ?? version.title : version.title).tag(Optional(version))
                    }
                }
                .accessibilityIdentifier("reader-otzaria-edition")
            }
            if let error { Text(error).foregroundStyle(.secondary) }
        }
        .task(id: reader.currentBook?.backendLocator?.workKey) {
            versions = []
            error = nil
            guard let locator = reader.currentBook?.backendLocator, locator.backend == .otzaria else { return }
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
    func selectedOtzariaVersion(for locator: TextLocator) -> TextVersionMetadata? {
        guard locator.backend == .otzaria else { return nil }
        return otzariaVersionSelection.selection(workKey: locator.workKey,
            generation: OtzariaMaktabahBridge.shared.generationSnapshot())
    }

    func selectOtzariaVersion(_ version: TextVersionMetadata?, for locator: TextLocator) {
        guard locator.backend == .otzaria, currentBook?.backendLocator?.workKey == locator.workKey else { return }
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

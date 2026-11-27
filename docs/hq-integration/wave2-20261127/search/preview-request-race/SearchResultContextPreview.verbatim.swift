import SwiftUI

struct SearchResultContextPreview: View {
    let item: SearchResultItem
    var onOpen: (() -> Void)? = nil
    @State private var fullSegments: [SearchPreviewSegment] = []
    @State private var previewError: String?
    @State private var isLoading = false
    @State private var retryToken = 0
    @State private var activePreviewRequestID: UUID?
    @AppStorage("otzaria_reader_unit_mode") private var otzariaUnitMode = "paragraph"

    private var isHebrewBackend: Bool {
        item.archive == "Otzaria" || item.archive == "Sefaria" || item.archive == "Zayit" || item.backendLocator != nil
    }

    private var readerMode: LibraryReaderTextMode {
        TextViewState.shared.readerTextMode
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if !fullSegments.isEmpty {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(fullSegments) { segment in
                            let hasTranslation = segment.translation?.isEmpty == false
                            let showPrimary = readerMode == .source || readerMode == .both
                                || (readerMode == .translation && !hasTranslation)
                            let showTranslation = hasTranslation
                                && (readerMode == .translation || readerMode == .both
                                    || (readerMode == .source && segment.primary.isEmpty))

                            VStack(alignment: .leading, spacing: 6) {
                                if showPrimary && !segment.primary.isEmpty {
                                    Text(segment.primary)
                                        .accessibilityIdentifier("search-preview-source-\(item.stableID)-\(segment.id)")
                                        .font(isHebrewBackend ? .body : ReaderViewModel.kfgqpc)
                                        .multilineTextAlignment(.leading)
                                        .environment(\.layoutDirection, segment.primary.isParagraphRTL ? .rightToLeft : .leftToRight)
                                }
                                if showTranslation, let translation = segment.translation, !translation.isEmpty {
                                    Text(translation)
                                        .accessibilityIdentifier("search-preview-translation-\(item.stableID)-\(segment.id)")
                                        .font(.body)
                                        .multilineTextAlignment(.leading)
                                        .environment(\.layoutDirection, translation.isParagraphRTL ? .rightToLeft : .leftToRight)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .textSelection(.enabled)
                } else if isLoading {
                    ProgressView(String(localized: "Loading full text…", defaultValue: "טוען טקסט מלא…"))
                        .accessibilityIdentifier("search-preview-loading-\(item.stableID)")
                        .frame(maxWidth: .infinity, minHeight: 160)
                } else if let previewError {
                    ContentUnavailableView {
                        Label(String(localized: "Full Text Unavailable", defaultValue: "הטקסט המלא אינו זמין"), systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(previewError)
                    } actions: {
                        Button(String(localized: "Retry", defaultValue: "נסה שוב")) { retryToken += 1 }
                            .accessibilityIdentifier("search-preview-retry-\(item.stableID)")
                    }
                    .accessibilityIdentifier("search-preview-error-\(item.stableID)")
                } else if !item.attributedText.string.isEmpty {
                    Text(AttributedString(item.attributedText))
                        .font(isHebrewBackend ? .body : ReaderViewModel.kfgqpc)
                        .multilineTextAlignment(.leading)
                } else {
                    ProgressView()
                }

                if let onOpen {
                    Button(action: onOpen) {
                        Label(String(localized: "Open", defaultValue: "פתח"), systemImage: "book")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("search-result-open-\(item.stableID)")
                    .padding(.top, 8)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
        .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .topLeading) {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: 1)
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("search-result-expanded-preview-\(item.stableID)")
                .accessibilityLabel(String(localized: "Expanded search preview", defaultValue: "תצוגה מקדימה מורחבת"))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("search-result-expanded-preview-\(item.stableID)")
        .task(id: "\(item.stableID):\(item.backendLocator?.backend == .otzaria ? otzariaUnitMode : ""):\(retryToken)") {
            // Superseded providers may throw an ordinary error after cancellation.
            // Only this still-current task may publish preview or loading state.
            guard !Task.isCancelled else { return }
            let requestID = UUID()
            activePreviewRequestID = requestID
            defer {
                if activePreviewRequestID == requestID, !Task.isCancelled {
                    isLoading = false
                }
            }
            guard let locator = item.backendLocator else {
                if item.attributedText.string.isEmpty {
                    previewError = String(localized: "The full text for this result is empty.", defaultValue: "הטקסט המלא עבור תוצאה זו ריק.")
                }
                return
            }
            isLoading = true
            previewError = nil
            fullSegments = []
            do {
                let section: LibraryTextSection
                if locator.backend == .sefaria, let language = item.resultLanguage,
                   let title = item.versionTitle, !title.isEmpty {
                    section = try await BackendCoordinator.shared.section(at: locator,
                        version: LibraryTextVersionSelection(title: title, language: language))
                } else {
                    section = try await BackendCoordinator.shared.section(at: locator)
                }
                try Task.checkCancellation()
                guard activePreviewRequestID == requestID else { return }
                fullSegments = section.segments.compactMap { segment in
                    let primary = segment.primaryText.readerPlainText
                    let translation = segment.translation?.readerPlainText
                    guard !primary.isEmpty || translation?.isEmpty == false else { return nil }
                    return SearchPreviewSegment(
                        id: segment.locator.persistenceKey,
                        primary: primary,
                        translation: translation
                    )
                }
                if fullSegments.isEmpty {
                    previewError = String(localized: "The full text for this result is empty.", defaultValue: "הטקסט המלא עבור תוצאה זו ריק.")
                }
            } catch is CancellationError {
                return
            } catch {
                guard activePreviewRequestID == requestID, !Task.isCancelled else { return }
                previewError = error.localizedDescription
            }
        }
    }
}

private struct SearchPreviewSegment: Identifiable {
    let id: String
    let primary: String
    let translation: String?
}

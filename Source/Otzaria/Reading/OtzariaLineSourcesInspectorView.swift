import SwiftUI

#if os(iOS)
struct OtzariaLineSourcesInspectorView: View {
    let selectedLine: OtzariaLineAnchor?
    let sources: [OtzariaLinkedSource]
    let isLoading: Bool
    let error: String?
    let onClose: () -> Void
    let onOpenSource: (OtzariaLinkedSource) -> Void

    @State private var expandedSourceIDs = Set<Int>()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("מקורות")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            onClose()
                        } label: {
                            Label("סגור", systemImage: "xmark")
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if selectedLine == nil {
            ContentUnavailableView("בחר שורה", systemImage: "link")
        } else if isLoading {
            ProgressView()
        } else if let error {
            Text(error)
        } else if sources.isEmpty {
            ContentUnavailableView("לא נמצאו קישורים", systemImage: "link.badge.plus")
        } else {
            List {
                if let selectedLine {
                    Section("השורה שנבחרה") {
                        LabeledContent {
                            Text(selectedLine.text)
                                .font(.callout)
                                .multilineTextAlignment(.trailing)
                                .textSelection(.enabled)
                        } label: {
                            if let heRef = selectedLine.heRef, !heRef.isEmpty {
                                Text(heRef)
                            } else {
                                Text("שורה")
                            }
                        }
                    }
                }

                ForEach(displaySections) { section in
                    Section(section.title) {
                        ForEach(section.sources) { source in
                            OtzariaExpandableLinkedSourceRow(
                                source: source,
                                isExpanded: expandedSourceIDs.contains(source.id),
                                onToggleExpanded: {
                                    if expandedSourceIDs.contains(source.id) {
                                        expandedSourceIDs.remove(source.id)
                                    } else {
                                        expandedSourceIDs.insert(source.id)
                                    }
                                },
                                onOpenSource: onOpenSource
                            )
                        }
                    }
                }
            }
        }
    }

    private var displaySections: [OtzariaLinkedSourceDisplaySection] {
        OtzariaLinkedSourceGrouping.displaySections(from: sources)
    }
}

private struct OtzariaExpandableLinkedSourceRow: View {
    let source: OtzariaLinkedSource
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
    let onOpenSource: (OtzariaLinkedSource) -> Void

    var body: some View {
        Group {
            LabeledContent {
                Text(isExpanded ? source.text : source.previewText)
                    .font(.body)
                    .lineLimit(isExpanded ? nil : 3)
                    .multilineTextAlignment(.trailing)
                    .textSelection(.enabled)
            } label: {
                sourceLabel
            }

            if source.hasLongText {
                Button {
                    onToggleExpanded()
                } label: {
                    Label(isExpanded ? "הצג פחות" : "הצג עוד", systemImage: isExpanded ? "chevron.up" : "chevron.down")
                }
            }

            Button {
                onOpenSource(source)
            } label: {
                Label("פתח בטאב חדש", systemImage: "plus.square.on.square")
            }
        }
    }

    @ViewBuilder
    private var sourceLabel: some View {
        if let heRef = source.heRef, !heRef.isEmpty {
            Text("\(source.bookTitle) · \(heRef)")
        } else {
            Text(source.bookTitle)
        }
    }
}
#endif

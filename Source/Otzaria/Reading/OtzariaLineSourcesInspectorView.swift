import SwiftUI

#if os(iOS)
struct OtzariaLineSourcesInspectorView: View {
    let selectedLine: OtzariaLineAnchor?
    let sources: [OtzariaLinkedSource]
    let isLoading: Bool
    let error: String?
    let onClose: () -> Void
    let onOpenSource: (OtzariaLinkedSource) -> Void

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

                ForEach(groupedSources) { connectionGroup in
                    Section(connectionGroup.title) {
                        ForEach(connectionGroup.categoryGroups) { categoryGroup in
                            DisclosureGroup(categoryGroup.title) {
                                ForEach(categoryGroup.bookGroups) { bookGroup in
                                    DisclosureGroup(bookGroup.title) {
                                        ForEach(bookGroup.sources) { source in
                                            OtzariaExpandableLinkedSourceRow(
                                                source: source,
                                                onOpenSource: onOpenSource
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var groupedSources: [OtzariaLinkedSourceConnectionGroup] {
        OtzariaLinkedSourceGrouping.groups(from: sources)
    }
}

private struct OtzariaExpandableLinkedSourceRow: View {
    let source: OtzariaLinkedSource
    let onOpenSource: (OtzariaLinkedSource) -> Void

    var body: some View {
        DisclosureGroup {
            LabeledContent {
                Text(source.text)
                    .font(.body)
                    .multilineTextAlignment(.trailing)
                    .textSelection(.enabled)
            } label: {
                if let heRef = source.heRef, !heRef.isEmpty {
                    Text(heRef)
                } else {
                    Text("מקור")
                }
            }

            Button {
                onOpenSource(source)
            } label: {
                Label("פתח בטאב חדש", systemImage: "plus.square.on.square")
            }
        } label: {
            LabeledContent {
                Text(source.previewText)
                    .font(.body)
                    .lineLimit(3)
                    .multilineTextAlignment(.trailing)
            } label: {
                if let heRef = source.heRef, !heRef.isEmpty {
                    Text(heRef)
                } else {
                    Text("מקור")
                }
            }
        }
    }
}
#endif

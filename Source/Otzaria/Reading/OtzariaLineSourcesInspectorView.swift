import SwiftUI

#if os(iOS)
struct OtzariaLineSourcesInspectorView: View {
    let selectedLine: OtzariaLineAnchor?
    let sources: [OtzariaLinkedSource]
    let isLoading: Bool
    let error: String?
    let onClose: () -> Void
    let onOpenSource: (OtzariaLinkedSource) -> Void

    @State private var path: [OtzariaSourcesRoute] = []
    @State private var expandedSourceIDs = Set<Int>()

    var body: some View {
        NavigationStack(path: $path) {
            rootContent
                .navigationTitle("מקורות")
                .navigationDestination(for: OtzariaSourcesRoute.self) { route in
                    switch route {
                    case .group(let groupId):
                        groupContent(groupId: groupId)
                    case .book(let groupId, let bookId):
                        bookContent(groupId: groupId, bookId: bookId)
                    }
                }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    onClose()
                } label: {
                    Label("סגור", systemImage: "xmark")
                }
            }
        }
        .onChange(of: sourceIDs) { _ in
            path.removeAll()
            expandedSourceIDs.removeAll()
        }
    }

    @ViewBuilder
    private var rootContent: some View {
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

                Section("מקורות") {
                    ForEach(indexGroups) { group in
                        NavigationLink(value: OtzariaSourcesRoute.group(group.id)) {
                            Label("\(group.title) (\(group.count))", systemImage: group.systemImage)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func groupContent(groupId: String) -> some View {
        if let group = indexGroups.first(where: { $0.id == groupId }) {
            List {
                Section(group.title) {
                    ForEach(OtzariaLinkedSourceGrouping.bookGroups(from: group.sources)) { bookGroup in
                        NavigationLink(value: OtzariaSourcesRoute.book(groupId: group.id, bookId: bookGroup.id)) {
                            Text("\(bookGroup.title) (\(bookGroup.count))")
                        }
                    }
                }
            }
            .navigationTitle(group.title)
        } else {
            ContentUnavailableView("לא נמצאה קבוצה", systemImage: "exclamationmark.triangle")
                .navigationTitle("מקורות")
        }
    }

    @ViewBuilder
    private func bookContent(groupId: String, bookId: String) -> some View {
        if let group = indexGroups.first(where: { $0.id == groupId }),
           let bookGroup = OtzariaLinkedSourceGrouping.bookGroups(from: group.sources).first(where: { $0.id == bookId }) {
            List {
                Section(bookGroup.title) {
                    ForEach(bookGroup.sources) { source in
                        OtzariaLinkedSourceSnippetRow(
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
            .navigationTitle(bookGroup.title)
        } else {
            ContentUnavailableView("לא נמצא ספר", systemImage: "exclamationmark.triangle")
                .navigationTitle("מקורות")
        }
    }

    private var indexGroups: [OtzariaSourceIndexGroup] {
        OtzariaLinkedSourceGrouping.indexGroups(from: sources)
    }

    private var sourceIDs: [Int] {
        sources.map(\.id)
    }
}

private enum OtzariaSourcesRoute: Hashable {
    case group(String)
    case book(groupId: String, bookId: String)
}

private struct OtzariaLinkedSourceSnippetRow: View {
    let source: OtzariaLinkedSource
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
    let onOpenSource: (OtzariaLinkedSource) -> Void

    var body: some View {
        Group {
            LabeledContent {
                Text(isExpanded ? source.text : source.previewText)
                    .font(.body)
                    .lineLimit(isExpanded ? nil : 4)
                    .multilineTextAlignment(.trailing)
                    .textSelection(.enabled)
            } label: {
                if let heRef = source.heRef, !heRef.isEmpty {
                    Text(heRef)
                } else {
                    Text(source.bookTitle)
                }
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
}
#endif

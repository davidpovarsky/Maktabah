import SwiftUI

#if os(iOS)
struct OtzariaLineSourcesInspectorView: View {
    let selectedLine: OtzariaLineAnchor?
    let sources: [OtzariaLinkedSource]
    let isLoading: Bool
    let error: String?
    let isPresented: Bool
    let onClose: () -> Void
    let onOpenSource: (OtzariaLinkedSource) -> Void

    @State private var path = NavigationPath()
    @State private var expandedSourceIDs = Set<Int>()

    var body: some View {
        NavigationStack(path: $path) {
            panelContent
                .navigationTitle("מקורות")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        if isPresented {
                            Button {
                                onClose()
                            } label: {
                                Image(systemName: "xmark")
                            }
                            .accessibilityLabel(Text("סגור"))
                        }
                    }
                }
                .navigationDestination(for: OtzariaSourcesRoute.self) { route in
                    destinationView(for: route)
                }
        }
    }

    @ViewBuilder
    private var panelContent: some View {
        if selectedLine == nil {
            ContentUnavailableView("בחר שורה", systemImage: "link")
        } else if isLoading {
            ProgressView()
        } else if let error {
            Text(error)
        } else if sources.isEmpty {
            ContentUnavailableView("לא נמצאו קישורים", systemImage: "link.badge.plus")
        } else {
            rootIndexContent
        }
    }

    @ViewBuilder
    private var rootIndexContent: some View {
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

    @ViewBuilder
    private func groupBooksContent(group: OtzariaSourceIndexGroup) -> some View {
        List {
            Section(group.title) {
                ForEach(OtzariaLinkedSourceGrouping.bookGroups(from: group.sources)) { bookGroup in
                    NavigationLink(value: OtzariaSourcesRoute.source(bookGroup.focus)) {
                        Text("\(bookGroup.title) (\(bookGroup.count))")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func bookSourcesContent(bookGroup: OtzariaSourceBookGroup) -> some View {
        List {
            ForEach(bookGroup.sources) { source in
                OtzariaLinkedSourceSnippetSection(
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

    @ViewBuilder
    private func destinationView(for route: OtzariaSourcesRoute) -> some View {
        switch route {
        case .group(let groupID):
            if let group = indexGroups.first(where: { $0.id == groupID }) {
                groupBooksContent(group: group)
                    .navigationTitle(group.title)
                    .navigationBarTitleDisplayMode(.inline)
            } else {
                ContentUnavailableView("אין מקורות מתאימים לשורה זו", systemImage: "link")
                    .navigationTitle("מקורות")
                    .navigationBarTitleDisplayMode(.inline)
            }
        case .source(let focus):
            sourceDetailView(for: focus)
                .navigationTitle(titleForFocus(focus))
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func sourceDetailView(for focus: OtzariaSourceFocus) -> some View {
        if isLoading {
            ProgressView()
        } else if let bookGroup = bookGroup(for: focus) {
            bookSourcesContent(bookGroup: bookGroup)
        } else {
            ContentUnavailableView("אין מקור מתאים לשורה זו", systemImage: "link")
        }
    }

    private func titleForFocus(_ focus: OtzariaSourceFocus) -> String {
        bookGroup(for: focus)?.title ?? focus.connectionType
    }

    private func bookGroup(for focus: OtzariaSourceFocus) -> OtzariaSourceBookGroup? {
        OtzariaLinkedSourceGrouping
            .bookGroups(from: sources.filter {
                $0.connectionType == focus.connectionType &&
                    $0.linkedBookId == focus.linkedBookId
            })
            .first
    }

    private var indexGroups: [OtzariaSourceIndexGroup] {
        OtzariaLinkedSourceGrouping.indexGroups(from: sources)
    }
}

struct OtzariaSourceFocus: Hashable {
    let connectionType: String
    let linkedBookId: Int
}

private enum OtzariaSourcesRoute: Hashable {
    case group(String)
    case source(OtzariaSourceFocus)
}

private extension OtzariaSourceBookGroup {
    var focus: OtzariaSourceFocus {
        guard let source = sources.first else {
            return OtzariaSourceFocus(connectionType: "", linkedBookId: Int(id) ?? 0)
        }
        return OtzariaSourceFocus(
            connectionType: source.connectionType,
            linkedBookId: source.linkedBookId
        )
    }
}

private struct OtzariaLinkedSourceSnippetSection: View {
    let source: OtzariaLinkedSource
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
    let onOpenSource: (OtzariaLinkedSource) -> Void

    var body: some View {
        Section {
            Text(isExpanded ? source.text : source.previewText)
                .font(.body)
                .lineLimit(isExpanded ? nil : 4)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
                .onTapGesture {
                    onToggleExpanded()
                }
                .contextMenu {
                    Button {
                        onOpenSource(source)
                    } label: {
                        Label("פתח בטאב חדש", systemImage: "plus.square.on.square")
                    }
                }
        } header: {
            LabeledContent {
                Button {
                    onOpenSource(source)
                } label: {
                    Label("פתח בטאב חדש", systemImage: "plus.square.on.square")
                        .labelStyle(.iconOnly)
                }
                .accessibilityLabel("פתח בטאב חדש")
            } label: {
                Label(sourceTitle, systemImage: isExpanded ? "chevron.down" : "chevron.left")
                    .onTapGesture(count: 2) {
                        onOpenSource(source)
                    }
            }
        }
    }

    private var sourceTitle: String {
        if let heRef = source.heRef, !heRef.isEmpty {
            return heRef
        }
        return source.bookTitle
    }
}
#endif

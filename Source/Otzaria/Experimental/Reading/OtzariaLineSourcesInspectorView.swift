import SwiftUI

#if os(iOS)
struct OtzariaLineSourcesInspectorView: View {
    let selectedLine: OtzariaLineAnchor?
    let sources: [OtzariaLinkedSource]
    let isLoading: Bool
    let error: String?
    let isPresented: Bool
    @Binding var selectedGroupID: String?
    @Binding var selectedBookID: String?
    @Binding var expandedSourceIDs: Set<Int>
    let onClose: () -> Void
    let onOpenSource: (OtzariaLinkedSource) -> Void

    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        NavigationStack {
            panelContent
                .contentShape(Rectangle())
                .simultaneousGesture(panelBackGesture)
                .navigationTitle(panelTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if canGoBack {
                            Button {
                                goBack()
                            } label: {
                                Label("חזרה", systemImage: "chevron.right")
                            }
                            .accessibilityLabel(Text("חזרה"))
                        }

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
        } else if selectedBookID != nil, selectedBookGroup == nil {
            ContentUnavailableView("אין מקור מתאים לשורה זו", systemImage: "link")
        } else if selectedGroupID != nil, selectedGroup == nil {
            ContentUnavailableView("אין מקורות מתאימים לשורה זו", systemImage: "link")
        } else if let selectedBookGroup {
            bookSourcesContent(bookGroup: selectedBookGroup)
        } else if let selectedGroup {
            groupBooksContent(group: selectedGroup)
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
                    Button {
                        selectedGroupID = group.id
                        selectedBookID = nil
                        expandedSourceIDs.removeAll()
                    } label: {
                        Label("\(group.title) (\(group.count))", systemImage: group.systemImage)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    @ViewBuilder
    private func groupBooksContent(group: OtzariaSourceIndexGroup) -> some View {
        List {
            Section(group.title) {
                ForEach(OtzariaLinkedSourceGrouping.bookGroups(from: group.sources)) { bookGroup in
                    Button {
                        selectedBookID = bookGroup.id
                        expandedSourceIDs.removeAll()
                    } label: {
                        Text("\(bookGroup.title) (\(bookGroup.count))")
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .multilineTextAlignment(.trailing)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
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
        .environment(\.layoutDirection, .rightToLeft)
    }

    private var selectedGroup: OtzariaSourceIndexGroup? {
        guard let selectedGroupID else { return nil }
        return indexGroups.first { $0.id == selectedGroupID }
    }

    private var selectedBookGroup: OtzariaSourceBookGroup? {
        guard let selectedGroup, let selectedBookID else { return nil }
        return OtzariaLinkedSourceGrouping
            .bookGroups(from: selectedGroup.sources)
            .first { $0.id == selectedBookID }
    }

    private var panelTitle: String {
        if let selectedBookGroup {
            return selectedBookGroup.title
        }
        if let selectedGroup {
            return selectedGroup.title
        }
        return "מקורות"
    }

    private var indexGroups: [OtzariaSourceIndexGroup] {
        OtzariaLinkedSourceGrouping.indexGroups(from: sources)
    }

    private var canGoBack: Bool {
        selectedBookID != nil || selectedGroupID != nil
    }

    private func goBack() {
        if selectedBookID != nil {
            selectedBookID = nil
            expandedSourceIDs.removeAll()
        } else if selectedGroupID != nil {
            selectedGroupID = nil
            selectedBookID = nil
            expandedSourceIDs.removeAll()
        }
    }

    private var panelBackGesture: some Gesture {
        DragGesture(minimumDistance: 40, coordinateSpace: .local)
            .onEnded { value in
                guard canGoBack else { return }

                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > 70 else { return }
                guard abs(horizontal) > abs(vertical) * 1.4 else { return }

                let isBackSwipe: Bool
                if layoutDirection == .rightToLeft {
                    isBackSwipe = horizontal < 0
                } else {
                    isBackSwipe = horizontal > 0
                }

                if isBackSwipe {
                    goBack()
                }
            }
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

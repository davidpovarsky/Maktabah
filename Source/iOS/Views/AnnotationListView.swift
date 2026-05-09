import SwiftUI

struct AnnotationListView: View {
    @Environment(iOSNavigationManager.self) private var navigationManager: iOSNavigationManager

    var body: some View {
        @Bindable var viewModel = navigationManager.annotationViewModel
        List(viewModel.rootNodes, children: \.children) { node in
            if node.kind == .annotation {
                Button(action: {
                    handleSelection(node)
                }) {
                    AnnotationNodeRow(node: node, viewModel: viewModel)
                }
                .buttonStyle(.plain)
            } else {
                AnnotationNodeRow(node: node, viewModel: viewModel)
                    .contentShape(Rectangle())
            }
        }
        .onAppear {
            viewModel.searchText = navigationManager.searchText
            viewModel.loadAnnotations()
        }
        .listStyle(.insetGrouped)
        .onChange(of: navigationManager.searchText) { _, newValue in
            viewModel.searchText = newValue
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Group By", selection: $viewModel.groupingMode) {
                        Text("Book").tag(AnnotationGroupingMode.book)
                        Text("Tag").tag(AnnotationGroupingMode.tag)
                    }

                    Divider()

                    Picker("Sort By", selection: $viewModel.sortField) {
                        Text("Date Created").tag(AnnotationSortField.createdAt)
                        Text("Context").tag(AnnotationSortField.context)
                        Text("Page").tag(AnnotationSortField.page)
                        Text("Part").tag(AnnotationSortField.part)
                    }

                    Picker("Order", selection: $viewModel.sortAscending) {
                        Text("Ascending").tag(true)
                        Text("Descending").tag(false)
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle")
                }
            }
        }
    }

    private func handleSelection(_ node: iOSAnnotationNode) {
        if node.kind == .annotation, let ann = node.annotation {
            if let book = LibraryDataManager.shared.getBook([ann.bkId]).first {
                navigationManager.openBook(book, initialContentId: Int(ann.contentId))
            }
        }
    }
}

struct AnnotationNodeRow: View {
    let node: iOSAnnotationNode
    var viewModel: iOSAnnotationViewModel

    var body: some View {
        HStack {
            if node.kind == .annotation, let ann = node.annotation {
                // Leaf Node: The actual annotation
                VStack(alignment: .leading, spacing: 4) {
                    Text(ann.context)
                        .font(iOSReaderViewModel.kfgqpc)
                        .lineLimit(3)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    if let note = ann.note, !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Circle()
                            .fill(Color(hex: ann.colorHex) ?? .yellow)
                            .frame(width: 12, height: 12)

                        Text(ann.type == .highlight ? "Highlight" : "Underline")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Spacer()

                        // Tampilkan Book Title jika di group by Tag, atau sebaliknya
                        if viewModel.groupingMode == .tag {
                            if let book = LibraryDataManager.shared.getBook([ann.bkId]).first {
                                Text(book.book)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .frame(maxWidth: 120, alignment: .trailing)
                            }
                        } else {
                            if !ann.tags.isEmpty {
                                Text(ann.tags.joined(separator: ", "))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .frame(maxWidth: 120, alignment: .trailing)
                            }
                        }

                        if let pgArb = ann.pageArb {
                            Text("Vol: \(ann.partArb ?? "") Page: \(pgArb)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .environment(\.layoutDirection, .leftToRight)
                        }
                    }
                }
                .padding(.vertical, 4)
                // Add swipe actions for deletion on iOS 15+
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        viewModel.deleteAnnotation(node: node)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            } else {
                // Group Node: Book, Tag, etc.
                Label {
                    Text(node.title)
                        .font(iOSReaderViewModel.kfgqpc)
                } icon: {
                    Image(systemName: iconForKind(node.kind))
                        .foregroundColor(.accentColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func iconForKind(_ kind: AnnotationNodeKind) -> String {
        switch kind {
        case .book: "book.closed.fill"
        case .tag: "tag.fill"
        case .untagged: "tag.slash.fill"
        default: "folder.fill"
        }
    }
}

/// Ensure the Color extension works in SwiftUI using the existing hex string format
extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let hexNum = UInt64(s, radix: 16) else { return nil }

        let r = Double((hexNum & 0xFF0000) >> 16) / 255.0
        let g = Double((hexNum & 0x00FF00) >> 8) / 255.0
        let b = Double(hexNum & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

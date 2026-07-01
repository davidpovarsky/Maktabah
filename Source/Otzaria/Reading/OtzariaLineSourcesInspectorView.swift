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
                        VStack(alignment: .trailing, spacing: 6) {
                            if let heRef = selectedLine.heRef, !heRef.isEmpty {
                                Text(heRef)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(selectedLine.text)
                                .font(.callout)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .textSelection(.enabled)
                        }
                    }
                }

                ForEach(sourceSections) { section in
                    Section(section.title) {
                        ForEach(section.items) { source in
                            Button {
                                onOpenSource(source)
                            } label: {
                                OtzariaLineSourceRow(source: source)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private var sourceSections: [OtzariaSourceSection] {
        let grouped = Dictionary(grouping: sources, by: \.connectionType)
        let order = ["COMMENTARY", "TARGUM", "REFERENCE", "SOURCE", "OTHER"]
        var sections: [OtzariaSourceSection] = []

        for key in order {
            if let items = grouped[key], !items.isEmpty {
                sections.append(OtzariaSourceSection(id: key, title: items[0].localizedConnectionType, items: items))
            }
        }

        let known = Set(order)
        for key in grouped.keys.filter({ !known.contains($0) }).sorted() {
            if let items = grouped[key], !items.isEmpty {
                sections.append(OtzariaSourceSection(id: key, title: key, items: items))
            }
        }

        return sections
    }
}

private struct OtzariaLineSourceRow: View {
    let source: OtzariaLinkedSource

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            HStack {
                Image(systemName: source.systemImage)
                Text(source.bookTitle)
                    .font(.headline)
                Spacer()
                if let heRef = source.heRef, !heRef.isEmpty {
                    Text(heRef)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(source.text)
                .font(.body)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .lineLimit(8)
                .textSelection(.enabled)
        }
        .padding(.vertical, 4)
    }
}
#endif

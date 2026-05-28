//
//  iOSBookAnnotationsView.swift
//  Maktabah
//
//  Created by Ghoys Mawahib on 28/05/26.
//

import SwiftUI

struct iOSBookAnnotationsView: View {
    let bookId: Int
    let annotations: [Annotation]
    let onSelect: (Annotation) -> Void
    @Environment(\.presentationMode) var presentationMode

    /// Load annotations specific to this book directly from the manager
    @State private var bookAnnotations: [Annotation] = []

    var body: some View {
        NavigationView {
            ThemeList(bookAnnotations, id: \.id, isGrouped: false) { ann in
                Button(action: {
                    onSelect(ann)
                }) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(ann.context)
                            .font(iOSReaderViewModel.kfgqpcTitle)
                            .lineLimit(3)
                            .truncationMode(.tail)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        if let note = ann.note, !note.isEmpty {
                            Text(note)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.trailing)
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: .trailing
                                )
                        }

                        HStack {
                            Circle()
                                .fill(Color(hex: ann.colorHex) ?? .yellow)
                                .frame(width: 12, height: 12)

                            Text(
                                ann.type == .highlight
                                    ? "Highlight" : "Underline"
                            )
                            .font(.caption2)
                            .foregroundColor(.secondary)

                            Spacer()

                            if let pgArb = ann.pageArb {
                                Text("Vol: \(ann.partArb ?? "") Page: \(pgArb)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .environment(
                                        \.layoutDirection,
                                        .leftToRight
                                    )
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Annotations")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button(action: {
                    CloudKitSyncManager.shared.resetChangeToken()
                }) {
                    Image(systemName: "arrow.counterclockwise.icloud")
                }
                .accessibilityLabel(String(localized: "Synchronize Data"))
                .help(String(localized: "Synchronize Data"))
            )
            .onAppear {
                loadBookAnnotations()
            }
        }
    }

    private func loadBookAnnotations() {
        if let bookNode = AnnotationManager.shared.rootNode?.children.first(
            where: {
                $0.kind == .book
                    && $0.children.first?.annotation?.bkId == bookId
            })
        {
            bookAnnotations = bookNode.children.compactMap(\.annotation)
        } else {
            let allAnns = AnnotationManager.shared.loadAnnotations(bkId: bookId)
            bookAnnotations = allAnns
        }
    }
}

#Preview {
    let mockAnn = Annotation(
        id: 1,
        bkId: 1,
        contentId: 1,
        range: NSRange(location: 0, length: 10),
        rangeDiacritics: NSRange(location: 0, length: 10),
        colorHex: "#FFFF00",
        type: .highlight,
        note: "Sample Note",
        createdAt: 0,
        context: "Sample context text here",
        page: 1,
        part: 1,
        pageArb: "١",
        partArb: "١",
        tags: []
    )
    return iOSBookAnnotationsView(
        bookId: 1,
        annotations: [mockAnn],
        onSelect: { _ in }
    )
}

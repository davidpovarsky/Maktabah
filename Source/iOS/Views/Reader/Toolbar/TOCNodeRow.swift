//
//  TOCNodeRow.swift
//  Maktabah
//
//  Created by Ghoys Mawahib on 28/05/26.
//

import SwiftUI

struct TOCNodeRow: View {
    let item: iOSIdentifiableTOCNode
    let selectedId: Int?
    let onSelect: (Int) -> Void
    @Binding var expandedPaths: Set<ObjectIdentifier>

    var isExpanded: Binding<Bool> {
        Binding(
            get: { expandedPaths.contains(item.id) },
            set: { isExpanding in
                if isExpanding {
                    expandedPaths.insert(item.id)
                } else {
                    expandedPaths.remove(item.id)
                }
            }
        )
    }

    var body: some View {
        Group {
            // Baris item saat ini
            HStack {
                // Teks bab di sebelah kanan (leading = kanan di RTL)
                nodeLabel
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Custom panah di sebelah kiri teks jika memiliki sub-bab
                if let children = item.children, !children.isEmpty {
                    Button(action: {
                        withAnimation {
                            if isExpanded.wrappedValue {
                                expandedPaths.remove(item.id)
                            } else {
                                expandedPaths.insert(item.id)
                            }
                        }
                    }) {
                        Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.left")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14, weight: .semibold))
                            // Berikan frame statis pada gambar agar ukurannya konsisten
                            .frame(width: 16, height: 16, alignment: .center)
                    }
                    .buttonStyle(.plain)
                    // Berikan frame statis pada area klik tombol
                    .frame(width: 32, height: 32)
                } else {
                    // Placeholder agar sejajar dengan yang memiliki panah (lebar sama dengan tombol = 32)
                    Spacer().frame(width: 32)
                }
            }
            // Berikan indentasi di sebelah kanan berdasarkan level (RTL: leading = kanan)
            .padding(.leading, CGFloat(max(0, item.node.level - 1)) * 24)
            .id(item.id)
            .environment(\.layoutDirection, .rightToLeft)
            
            // Rekursif untuk menampilkan sub-bab di bawahnya jika sedang diekspansi
            if isExpanded.wrappedValue, let children = item.children, !children.isEmpty {
                ForEach(children) { child in
                    TOCNodeRow(
                        item: child,
                        selectedId: selectedId,
                        onSelect: onSelect,
                        expandedPaths: $expandedPaths
                    )
                }
            }
        }
    }

    var nodeLabel: some View {
        Button(action: {
            onSelect(item.node.id)
        }) {
            Text(item.node.bab)
                .font(iOSReaderViewModel.kfgqpcTitle)
                .foregroundColor(
                    item.node.id == selectedId ? .accentColor : .primary
                )
        }
    }
}

#Preview {
    let mockNode = TOCNode(from: TOC(bab: "Chapter 1", level: 1, sub: 0, id: 1))
    let item = iOSIdentifiableTOCNode(mockNode)
    
    return TOCNodeRow(
        item: item,
        selectedId: 1,
        onSelect: { _ in },
        expandedPaths: .constant(Set([item.id]))
    )
    .padding()
}

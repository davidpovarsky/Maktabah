//
//  iOSTOCView.swift
//  Maktabah
//
//  Created by Ghoys Mawahib on 28/05/26.
//

import SwiftUI

struct iOSTOCView: View {
    @State private var viewModel: iOSTOCViewModel
    let onSelect: (Int) -> Void
    @Environment(\.presentationMode) var presentationMode

    init(nodes: [TOCNode], selectedId: Int?, onSelect: @escaping (Int) -> Void) {
        self._viewModel = State(initialValue: iOSTOCViewModel(nodes: nodes, selectedId: selectedId))
        self.onSelect = onSelect
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationView {
            ScrollViewReader { proxy in
                ThemeList(isGrouped: true) {
                    ForEach(viewModel.identifiableNodes) { item in
                        TOCNodeRow(
                            item: item,
                            selectedId: viewModel.selectedId,
                            onSelect: onSelect,
                            expandedPaths: $viewModel.expandedPaths
                        )
                    }
                }
                .searchable(text: $viewModel.searchText, prompt: "Search Contents")
                .navigationTitle("Table of Contents")
                .navigationBarItems(
                    leading: Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
                .onAppear {
                    viewModel.computeExpandedPaths()
                    if let selectedId = viewModel.selectedId {
                        Task {
                            try await Task.sleep(for: .seconds(0.5))
                            withAnimation {
                                proxy.scrollTo(selectedId, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    let node1 = TOCNode(from: TOC(bab: "المقدمة (Tanpa Sub)", level: 1, sub: 0, id: 1))
    let node2 = TOCNode(from: TOC(bab: "كتاب الطهارة (Dengan Sub)", level: 1, sub: 0, id: 2))
    let node2_1 = TOCNode(from: TOC(bab: "باب الوضوء", level: 2, sub: 1, id: 3))
    let node2_2 = TOCNode(from: TOC(bab: "باب الغسل (Dengan Sub)", level: 2, sub: 1, id: 4))
    let node2_2_1 = TOCNode(from: TOC(bab: "فصل في موجبات الغسل", level: 3, sub: 2, id: 5))
    
    node2_2.children = [node2_2_1]
    node2.children = [node2_1, node2_2]
    
    let node3 = TOCNode(from: TOC(bab: "كتاب الصلاة", level: 1, sub: 0, id: 6))
    
    let mockNodes = [node1, node2, node3]
    
    return iOSTOCView(
        nodes: mockNodes,
        selectedId: 3,
        onSelect: { selectedId in
            print("Selected ID: \(selectedId)")
        }
    )
}

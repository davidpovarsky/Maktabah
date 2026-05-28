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

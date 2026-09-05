import SwiftUI
import UIKit

struct iOSRowiSidebarView: UIViewControllerRepresentable {
    private let groups: () -> [TabaqaGroup]
    private let onSelectRowi: (Rowi) -> Void
    private let onLoadMore: (TabaqaGroup, @escaping () -> Void) -> Void
    @Environment(\.isSearching) private var isSearching
    let searchQuery: String

    init(viewModel: NarratorViewModel, searchQuery: String) {
        groups = { viewModel.tabaqaGroups }
        onSelectRowi = { viewModel.selectRowi($0) }
        onLoadMore = { group, completion in
            viewModel.loadMore(group: group) { _ in completion() }
        }
        self.searchQuery = searchQuery
    }

    init(
        groups: @escaping () -> [TabaqaGroup],
        searchQuery: String,
        onSelectRowi: @escaping (Rowi) -> Void,
        onLoadMore: @escaping (TabaqaGroup, @escaping () -> Void) -> Void
    ) {
        self.groups = groups
        self.searchQuery = searchQuery
        self.onSelectRowi = onSelectRowi
        self.onLoadMore = onLoadMore
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(groups: groups, onSelectRowi: onSelectRowi, onLoadMore: onLoadMore)
    }

    func makeUIViewController(context: Context) -> iOSRowiHierarchicalCollectionViewController {
        let vc = iOSRowiHierarchicalCollectionViewController()

        vc.onSelectRowi = { rowi in
            context.coordinator.onSelectRowi(rowi)
        }

        vc.onLoadMore = { group in
            context.coordinator.onLoadMore(group) {
                DispatchQueue.main.async {
                    vc.applyGroups(context.coordinator.groups(), isSearching: !context.coordinator.searchQuery.isEmpty)
                }
            }
        }

        return vc
    }

    func updateUIViewController(_ uiViewController: iOSRowiHierarchicalCollectionViewController, context: Context) {
        context.coordinator.searchQuery = searchQuery
        uiViewController.applyGroups(groups(), isSearching: !searchQuery.isEmpty)
    }

    class Coordinator {
        let groups: () -> [TabaqaGroup]
        let onSelectRowi: (Rowi) -> Void
        let onLoadMore: (TabaqaGroup, @escaping () -> Void) -> Void
        var searchQuery: String = ""

        init(
            groups: @escaping () -> [TabaqaGroup],
            onSelectRowi: @escaping (Rowi) -> Void,
            onLoadMore: @escaping (TabaqaGroup, @escaping () -> Void) -> Void
        ) {
            self.groups = groups
            self.onSelectRowi = onSelectRowi
            self.onLoadMore = onLoadMore
        }
    }
}

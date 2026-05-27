import SwiftUI
import UIKit

struct iOSRowiSidebarView: UIViewControllerRepresentable {
    var viewModel: iOSAuthorViewModel
    @Environment(\.isSearching) private var isSearching
    let searchQuery: String

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeUIViewController(context: Context) -> iOSRowiHierarchicalCollectionViewController {
        let vc = iOSRowiHierarchicalCollectionViewController()

        vc.onSelectRowi = { rowi in
            context.coordinator.viewModel.selectedRowi = rowi
        }

        vc.onLoadMore = { group in
            context.coordinator.viewModel.loadMore(group: group) { _ in
                DispatchQueue.main.async {
                    vc.applyGroups(context.coordinator.viewModel.tabaqaGroups, isSearching: !context.coordinator.searchQuery.isEmpty)
                }
            }
        }

        return vc
    }

    func updateUIViewController(_ uiViewController: iOSRowiHierarchicalCollectionViewController, context: Context) {
        context.coordinator.searchQuery = searchQuery
        uiViewController.applyGroups(viewModel.tabaqaGroups, isSearching: !searchQuery.isEmpty)
    }

    class Coordinator {
        let viewModel: iOSAuthorViewModel
        var searchQuery: String = ""

        init(viewModel: iOSAuthorViewModel) {
            self.viewModel = viewModel
        }
    }
}

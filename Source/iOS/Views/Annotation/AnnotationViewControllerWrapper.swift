//
//  AnnotationViewControllerWrapper.swift
//  Maktabah
//
//  Created by Ghoys Mawahib on 10/06/26.
//

import SwiftUI

struct AnnotationViewControllerWrapper: UIViewControllerRepresentable {
    let navigationManager: iOSNavigationManager
    @Bindable var viewModel: iOSAnnotationViewModel

    func makeUIViewController(context: Context) -> iOSAnnotationViewController {
        let vc = iOSAnnotationViewController()
        vc.additionalSafeAreaInsets.bottom = 15
        vc.onAnnotationSelected = { node in
            context.coordinator.handleSelection(node)
        }
        vc.onAnnotationDeleted = { node in
            viewModel.deleteAnnotation(node: node)
        }

        vc.onNeedFullReload = { [weak viewModel] in
            viewModel?.applyFilter()
        }
        viewModel.onIncrementalUpdate = { [weak vc] changeType, userInfo in
            vc?.handleIncrementalUpdate(changeType: changeType, userInfo: userInfo)
        }
        viewModel.onTreeUpdate = { [weak vc] nodes, mode in
            vc?.handleTreeUpdate(nodes: nodes, groupingMode: mode)
        }

        return vc
    }

    func updateUIViewController(_ uiViewController: iOSAnnotationViewController, context: Context) {
        // Only set initial data — incremental updates come from notifications via callback
        if !context.coordinator.hasAppliedOnce {
            context.coordinator.hasAppliedOnce = true
            uiViewController.applyNodes(
                viewModel.rootNodes,
                groupingMode: viewModel.groupingMode,
                animated: false
            )
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(navigationManager: navigationManager)
    }

    class Coordinator {
        let navigationManager: iOSNavigationManager
        var hasAppliedOnce = false
        init(navigationManager: iOSNavigationManager) {
            self.navigationManager = navigationManager
        }

        @MainActor
        func handleSelection(_ node: iOSAnnotationNode) {
            guard node.kind == .annotation, let ann = node.annotation else { return }
            if let book = LibraryDataManager.shared.getBook([ann.bkId]).first {
                navigationManager.openBook(book, initialContentId: Int(ann.contentId), targetAnnotation: ann)
            } else {
                NotificationCenter.default.post(
                    name: .annotationMissingBook,
                    object: ann.bkId
                )
            }
        }
    }
}

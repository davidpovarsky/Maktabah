//
//  ReaderDocumentTabsBarRepresentable.swift
//  Maktabah
//
//  Downstream-owned SwiftUI wrapper and adapter for ReaderDocumentTabsBarController (Plan C2).
//

#if os(iOS)
import SwiftUI
import UIKit

/// Projects `iOSNavigationManager.openTabs` and `StudyWorkspaceStore` into `ReaderTabStripItemModel` items
/// and handles user interactions from the DuckDuckGo-style document tab strip.
@MainActor
enum ReaderTabStripAdapter {
    static func buildStripItems(
        from navigationManager: iOSNavigationManager,
        workspaceStore: StudyWorkspaceStore? = nil,
        studyWorkspaceEnabled: Bool = ChavrusaTextFeatureFlags.shared.effectiveStudyWorkspaceEnabled
    ) -> [ReaderTabStripItemModel] {
        let activeTabID = navigationManager.activeTabId
        return navigationManager.openTabs.map { readerTab in
            let vm = readerTab.viewModel
            let docTab = studyWorkspaceEnabled ? workspaceStore?.tab(for: readerTab.id) : nil
            let subtitle = vm.otzariaCurrentReferencePage()
                ?? vm.backendSection?.heRef
                ?? vm.backendSection?.displayRef
            let backend = docTab?.backend
                ?? readerTab.book.backendLocator?.backend
                ?? BackendCoordinator.shared.activeBackendID

            return ReaderTabStripItemModel(
                id: readerTab.id,
                title: readerTab.book.title,
                subtitle: subtitle,
                backend: backend,
                isSelected: readerTab.id == activeTabID,
                isDormantUnavailable: docTab?.isDormantUnavailable ?? false
            )
        }
    }
}

/// SwiftUI `UIViewControllerRepresentable` hosting `ReaderDocumentTabsBarController` with a real layout height of `40pt`.
struct ReaderDocumentTabsBarRepresentable: UIViewControllerRepresentable {
    @Environment(iOSNavigationManager.self) private var navigationManager

    var sceneCoordinator: StudyWorkspaceSceneCoordinator? = nil
    var sidebarCoordinator: ReaderSidebarStateCoordinator?
    var workspaceStore: StudyWorkspaceStore? = nil

    func makeUIViewController(context: Context) -> ReaderDocumentTabsBarController {
        let controller = ReaderDocumentTabsBarController()
        configureCallbacks(for: controller)
        return controller
    }

    func updateUIViewController(_ uiViewController: ReaderDocumentTabsBarController, context: Context) {
        let isWorkspaceEnabled = ChavrusaTextFeatureFlags.shared.effectiveStudyWorkspaceEnabled && sceneCoordinator != nil
        configureCallbacks(for: uiViewController)
        let items = ReaderTabStripAdapter.buildStripItems(
            from: navigationManager,
            workspaceStore: workspaceStore,
            studyWorkspaceEnabled: isWorkspaceEnabled
        )
        let groups = isWorkspaceEnabled ? (sceneCoordinator?.groupsInActiveProfile ?? []) : []
        let activeGroupID = isWorkspaceEnabled ? sceneCoordinator?.activeGroup.id : nil
        uiViewController.apply(
            items: items,
            availableGroups: groups,
            activeGroupID: activeGroupID,
            animated: true
        )
    }

    private func configureCallbacks(for controller: ReaderDocumentTabsBarController) {
        controller.callbacks = ReaderTabStripCallbacks(
            onSelectTab: { tabID in
                guard navigationManager.activeTabId != tabID else { return }
                if let currentActive = navigationManager.activeTab {
                    currentActive.viewModel.saveCurrentState()
                }
                navigationManager.activeTabId = tabID
                if let targetTab = navigationManager.openTabs.first(where: { $0.id == tabID }) {
                    targetTab.viewModel.annotationEvent = nil
                    targetTab.viewModel.searchEvent = nil
                    targetTab.viewModel.needsScrollRestore = true
                    navigationManager.selectedBook = targetTab.book
                    navigationManager.selectedContentId = targetTab.viewModel.currentContentId
                }
                if ChavrusaTextFeatureFlags.shared.effectiveStudyWorkspaceEnabled, let sceneCoordinator {
                    sceneCoordinator.selectTab(tabID)
                }
                navigationManager.persistCurrentSession(immediate: false)
            },
            onCloseTab: { tabID in
                navigationManager.closeTab(id: tabID)
                if ChavrusaTextFeatureFlags.shared.effectiveStudyWorkspaceEnabled,
                   let sceneCoordinator,
                   let workspaceStore {
                    workspaceStore.closeTab(tabID, inGroup: sceneCoordinator.activeGroup.id)
                }
            },
            onCloseOtherTabs: { keepTabID in
                let idsToClose = navigationManager.openTabs.map(\.id).filter { $0 != keepTabID }
                for id in idsToClose {
                    navigationManager.closeTab(id: id)
                }
                if ChavrusaTextFeatureFlags.shared.effectiveStudyWorkspaceEnabled,
                   let sceneCoordinator,
                   let workspaceStore {
                    workspaceStore.closeOtherTabs(keeping: keepTabID, inGroup: sceneCoordinator.activeGroup.id)
                }
            },
            onDuplicateTab: { tabID in
                guard let sourceTab = navigationManager.openTabs.first(where: { $0.id == tabID }) else { return }
                let vm = sourceTab.viewModel
                vm.saveCurrentState()
                if ChavrusaTextFeatureFlags.shared.effectiveStudyWorkspaceEnabled,
                   let sceneCoordinator {
                    sceneCoordinator.navigationAdapter.captureLiveState(
                        from: navigationManager,
                        intoGroup: sceneCoordinator.activeGroup.id
                    )
                    sceneCoordinator.navigationAdapter.openIndependentTab(
                        for: sourceTab.book,
                        in: navigationManager,
                        groupID: sceneCoordinator.activeGroup.id,
                        contentId: vm.currentID ?? sourceTab.initialContentId ?? (vm.currentContentId > 0 ? vm.currentContentId : nil),
                        sectionLocator: vm.currentLocator ?? vm.readerState.currentLocator
                    )
                } else {
                    navigationManager.openTab(
                        book: sourceTab.book,
                        contentId: vm.currentID ?? sourceTab.initialContentId ?? (vm.currentContentId > 0 ? vm.currentContentId : nil)
                    )
                }
            },
            onMoveTabToGroup: { tabID, targetGroupID in
                guard ChavrusaTextFeatureFlags.shared.effectiveStudyWorkspaceEnabled,
                      let sceneCoordinator,
                      let workspaceStore else { return }
                sceneCoordinator.navigationAdapter.captureLiveState(
                    from: navigationManager,
                    intoGroup: sceneCoordinator.activeGroup.id
                )
                workspaceStore.moveTab(
                    tabID,
                    fromGroup: sceneCoordinator.activeGroup.id,
                    toGroup: targetGroupID,
                    activateInDestination: true
                )
                navigationManager.closeTab(id: tabID)
            },
            onCopyTabToGroup: { tabID, targetGroupID in
                guard ChavrusaTextFeatureFlags.shared.effectiveStudyWorkspaceEnabled,
                      let sceneCoordinator,
                      let workspaceStore else { return }
                sceneCoordinator.navigationAdapter.captureLiveState(
                    from: navigationManager,
                    intoGroup: sceneCoordinator.activeGroup.id
                )
                _ = workspaceStore.copyTab(
                    tabID,
                    toGroup: targetGroupID,
                    activateInDestination: true
                )
            },
            onReorderTab: { sourceIndex, destinationIndex in
                guard navigationManager.openTabs.indices.contains(sourceIndex),
                      destinationIndex >= 0,
                      destinationIndex < navigationManager.openTabs.count,
                      sourceIndex != destinationIndex else { return }
                let moved = navigationManager.openTabs.remove(at: sourceIndex)
                navigationManager.openTabs.insert(moved, at: destinationIndex)
                if ChavrusaTextFeatureFlags.shared.effectiveStudyWorkspaceEnabled,
                   let sceneCoordinator,
                   let workspaceStore {
                    workspaceStore.reorderTabs(
                        inGroup: sceneCoordinator.activeGroup.id,
                        from: sourceIndex,
                        to: destinationIndex
                    )
                }
                navigationManager.persistCurrentSession(immediate: false)
            },
            onNewTabRequested: {
                withAnimation(.snappy(duration: 0.25)) {
                    sidebarCoordinator?.showLibrary()
                }
            }
        )
    }
}
#endif

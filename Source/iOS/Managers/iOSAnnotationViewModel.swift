import Foundation
import SwiftUI
import Combine

struct iOSAnnotationNode: Identifiable {
    let id: String
    let title: String
    let kind: AnnotationNodeKind
    let annotation: Annotation?
    var children: [iOSAnnotationNode]?
    
    init(
        id: String,
        title: String,
        kind: AnnotationNodeKind,
        annotation: Annotation?,
        children: [iOSAnnotationNode]? = nil
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.annotation = annotation
        self.children = children
    }
    
    static func id(from node: AnnotationNode) -> String {
        if node.kind == .annotation, let ann = node.annotation, let annId = ann.id {
            return "ann-\(annId)"
        }
        return "group-\(node.kind)-\(node.title)"
    }
    
    /// Convert the core AppKit/Foundation AnnotationNode to SwiftUI identifiable node
    init(from node: AnnotationNode, parentId: String? = nil) {
        let baseId = iOSAnnotationNode.id(from: node)
        id = (parentId != nil && node.kind == .annotation) ? "\(parentId!)-\(baseId)" : baseId
        title = node.title
        kind = node.kind
        annotation = node.annotation
        let currentId = id
        children = node.children.isEmpty ? nil : node.children.map { iOSAnnotationNode(from: $0, parentId: currentId) }
    }
}


@MainActor
@Observable
class iOSAnnotationViewModel {
    var isLoading: Bool = true
    var rootNodes: [iOSAnnotationNode] = []
    var searchText: String = "" {
        didSet {
            if oldValue != searchText {
                searchSubject.send(searchText)
            }
        }
    }

    private var cancellables = Set<AnyCancellable>()
    private let searchSubject = PassthroughSubject<String, Never>()

    var groupingMode: AnnotationGroupingMode = UserDefaults.standard.selectedAnnGroupingMode {
        didSet {
            guard oldValue != groupingMode else { return }
            isLoading = true
            UserDefaults.standard.selectedAnnGroupingMode = groupingMode
            AnnotationManager.shared.updateGroupingMode(groupingMode)
        }
    }

    var sortField: AnnotationSortField = UserDefaults.standard.selectedAnnSortField {
        didSet {
            guard oldValue != sortField else { return }
            isLoading = true
            UserDefaults.standard.selectedAnnSortField = sortField
            AnnotationManager.shared.updateSorting(field: sortField, isAscending: sortAscending)
        }
    }

    var sortAscending: Bool = UserDefaults.standard.selectedAnnAscending {
        didSet {
            guard oldValue != sortAscending else { return }
            isLoading = true
            UserDefaults.standard.selectedAnnAscending = sortAscending
            AnnotationManager.shared.updateSorting(field: sortField, isAscending: sortAscending)
        }
    }

    // MARK: - Update Callbacks
    // Controller implements these to apply changes

    /// Called for incremental changes (add/update/delete)
    var onIncrementalUpdate: ((AnnotationChangeType, [AnyHashable: Any]) -> Void)? {
        didSet {
            // Flush any buffered notifications when callback is set
            flushBufferedNotifications()
        }
    }

    /// Called when tree needs full rebuild (grouping/sorting/search changes)
    var onTreeUpdate: (([iOSAnnotationNode], AnnotationGroupingMode) -> Void)?

    /// Buffer for notifications that arrive before callback is set
    private var bufferedNotifications: [(changeType: AnnotationChangeType, userInfo: [AnyHashable: Any])] = []

    init() {
        searchSubject
            .debounce(for: .seconds(0.3), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyFilter()
            }
            .store(in: &cancellables)

        // Only listen for tree updates (full reload needed for search/grouping changes)
        NotificationCenter.default.addObserver(
            forName: .annotationTreeDidUpdate,
            object: nil,
            queue: .current
        ) { _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                reloadFromManager()
                onTreeUpdate?(rootNodes, groupingMode)
                isLoading = false
            }
        }

        // Listen for granular changes - notify controller directly
        NotificationCenter.default.addObserver(
            forName: .annotationDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleAnnotationChange(notification)
            }
        }
    }

    private func handleAnnotationChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let rawType = userInfo[AnnotationNotificationKeys.changeType] as? String,
              let changeType = AnnotationChangeType(rawValue: rawType)
        else {
            return
        }

        // When searching, we need full reload - skip incremental
        if !searchText.isEmpty {
            return
        }

        // If callback is set, send immediately; otherwise buffer
        if let callback = onIncrementalUpdate {
            callback(changeType, userInfo)
        } else {
            bufferedNotifications.append((changeType, userInfo))
        }
    }

    private func flushBufferedNotifications() {
        guard let callback = onIncrementalUpdate else { return }
        for (changeType, userInfo) in bufferedNotifications {
            callback(changeType, userInfo)
        }
        bufferedNotifications.removeAll()
    }

    func loadAnnotations() async {
        Task.detached { [weak self] in
            guard let self else { return }
            // Sinkronisasi status dari UserDefaults ke AnnotationManager sebelum memuat data
            await AnnotationManager.shared.updateGroupingMode(groupingMode)
            await AnnotationManager.shared.updateSorting(field: sortField, isAscending: sortAscending)
            await reloadFromManager()
        }
    }

    private func reloadFromManager() {
        if let coreNodes = AnnotationManager.shared.rootNode?.children {
            let hideMissing = UserDefaults.standard.bool(forKey: "hideMissingBookAnnotations")

            var filteredCoreNodes = coreNodes
            if hideMissing {
                filteredCoreNodes = filterOutMissingBooks(from: coreNodes)
            }

            let mapped = filteredCoreNodes.map { iOSAnnotationNode(from: $0) }
            if searchText.isEmpty {
                rootNodes = mapped
            } else {
                rootNodes = filterNodes(mapped, with: searchText)
            }
        }
    }

    private func filterOutMissingBooks(from nodes: [AnnotationNode]) -> [AnnotationNode] {
        // Batch: collect unique bkIds, query once per unique book instead of per annotation
        var uniqueBkIds: Set<Int> = []
        gatherBkIds(from: nodes, into: &uniqueBkIds)
        let existingBkIds = uniqueBkIds.filter { !LibraryDataManager.shared.getBook([$0]).isEmpty }
        return applyBookFilter(from: nodes, existingBkIds: existingBkIds)
    }

    private func gatherBkIds(from nodes: [AnnotationNode], into set: inout Set<Int>) {
        for node in nodes {
            if node.kind == .annotation, let ann = node.annotation {
                set.insert(ann.bkId)
            } else {
                gatherBkIds(from: node.children, into: &set)
            }
        }
    }

    private func applyBookFilter(from nodes: [AnnotationNode], existingBkIds: Set<Int>) -> [AnnotationNode] {
        var result: [AnnotationNode] = []
        for node in nodes {
            if node.kind == .annotation, let ann = node.annotation {
                if existingBkIds.contains(ann.bkId) {
                    result.append(node)
                }
            } else {
                let filteredChildren = applyBookFilter(from: node.children, existingBkIds: existingBkIds)
                if !filteredChildren.isEmpty {
                    let copy = AnnotationNode(title: node.title, kind: node.kind, annotation: nil)
                    copy.children = filteredChildren
                    result.append(copy)
                }
            }
        }
        return result
    }

    func applyFilter() {
        reloadFromManager()
        onTreeUpdate?(rootNodes, groupingMode)
    }

    private func filterNodes(_ nodes: [iOSAnnotationNode], with query: String) -> [iOSAnnotationNode] {
        var result: [iOSAnnotationNode] = []
        let query = query.normalizeArabic(false)

        for node in nodes {
            var matchingChildren: [iOSAnnotationNode] = []
            if let children = node.children {
                matchingChildren = filterNodes(children, with: query)
            }

            let matchesSelf = node.title.normalizeArabic(false).localizedStandardContains(query) ||
                (node.annotation?.context.normalizeArabic(false).localizedStandardContains(query) == true)

            if matchesSelf || !matchingChildren.isEmpty {
                var copy = node
                copy.children = matchingChildren.isEmpty && node.children == nil ? nil : matchingChildren
                result.append(copy)
            }
        }
        return result
    }

    func deleteAnnotation(node: iOSAnnotationNode) {
        guard let id = node.annotation?.id else { return }
        do {
            try AnnotationManager.shared.deleteAnnotation(id: id)
            // The notification .annotationTreeDidUpdate will trigger a reload automatically
        } catch {
            print("Failed to delete annotation: \(error.localizedDescription)")
        }
    }
}

import Foundation
import SwiftUI

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

    /// Convert the core AppKit/Foundation AnnotationNode to SwiftUI identifiable node
    init(from node: AnnotationNode) {
        if node.kind == .annotation, let ann = node.annotation, let annId = ann.id {
            id = "ann-\(annId)"
        } else {
            id = "group-\(node.kind)-\(node.title)"
        }

        title = node.title
        kind = node.kind
        annotation = node.annotation

        if node.children.isEmpty {
            children = nil
        } else {
            children = node.children.map { iOSAnnotationNode(from: $0) }
        }
    }
}

@MainActor
@Observable
class iOSAnnotationViewModel {
    var rootNodes: [iOSAnnotationNode] = []
    var searchText: String = "" {
        didSet { applyFilter() }
    }

    var groupingMode: AnnotationGroupingMode {
        get { UserDefaults.standard.selectedAnnGroupingMode }
        set {
            UserDefaults.standard.selectedAnnGroupingMode = newValue
            AnnotationManager.shared.updateGroupingMode(newValue)
        }
    }

    var sortField: AnnotationSortField {
        get { UserDefaults.standard.selectedAnnSortField }
        set {
            UserDefaults.standard.selectedAnnSortField = newValue
            AnnotationManager.shared.updateSorting(field: newValue, isAscending: sortAscending)
        }
    }

    var sortAscending: Bool {
        get { UserDefaults.standard.selectedAnnAscending }
        set {
            UserDefaults.standard.selectedAnnAscending = newValue
            AnnotationManager.shared.updateSorting(field: sortField, isAscending: newValue)
        }
    }

    init() {
        NotificationCenter.default.addObserver(
            forName: .annotationTreeDidUpdate,
            object: nil,
            queue: .current
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reloadFromManager()
            }
        }

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

    func loadAnnotations() {
        // Sinkronisasi status dari UserDefaults ke AnnotationManager sebelum memuat data
        AnnotationManager.shared.updateGroupingMode(groupingMode)
        AnnotationManager.shared.updateSorting(field: sortField, isAscending: sortAscending)
        reloadFromManager()
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
                rootNodes = filterNodes(mapped, with: searchText.lowercased())
            }
        }
    }

    private func filterOutMissingBooks(from nodes: [AnnotationNode]) -> [AnnotationNode] {
        var result: [AnnotationNode] = []
        for node in nodes {
            if node.kind == .annotation, let ann = node.annotation {
                // If it's a leaf node, check if book exists
                if LibraryDataManager.shared.getBook([ann.bkId]).first != nil {
                    result.append(node)
                }
            } else {
                // If it's a group node, filter its children recursively
                let filteredChildren = filterOutMissingBooks(from: node.children)
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
    }

    private func filterNodes(_ nodes: [iOSAnnotationNode], with query: String) -> [iOSAnnotationNode] {
        var result: [iOSAnnotationNode] = []
        for node in nodes {
            var matchingChildren: [iOSAnnotationNode] = []
            if let children = node.children {
                matchingChildren = filterNodes(children, with: query)
            }

            let matchesSelf = node.title.lowercased().contains(query) || (node.annotation?.context.lowercased().contains(query) == true)

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

    private func handleAnnotationChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let rawType = userInfo[AnnotationNotificationKeys.changeType] as? String,
              let changeType = AnnotationChangeType(rawValue: rawType)
        else {
            reloadFromManager()
            return
        }

        if !searchText.isEmpty {
            reloadFromManager()
            return
        }

        switch groupingMode {
        case .book:
            applyBookChange(changeType, userInfo: userInfo)
        case .tag:
            applyTagChange(changeType, userInfo: userInfo)
        }
    }

    private func applyBookChange(_ changeType: AnnotationChangeType, userInfo: [AnyHashable: Any]) {
        switch changeType {
        case .added:
            guard let annotation = userInfo[AnnotationNotificationKeys.annotation] as? Annotation else {
                reloadFromManager()
                return
            }
            insertBookAnnotation(annotation)
        case .updated:
            guard let annotation = userInfo[AnnotationNotificationKeys.annotation] as? Annotation else {
                reloadFromManager()
                return
            }
            updateBookAnnotation(annotation)
        case .deleted:
            guard let annotationId = userInfo[AnnotationNotificationKeys.annotationId] as? Int64 else {
                reloadFromManager()
                return
            }
            removeBookAnnotation(id: annotationId)
        }
    }

    private func applyTagChange(_ changeType: AnnotationChangeType, userInfo: [AnyHashable: Any]) {
        guard let diff = userInfo[AnnotationNotificationKeys.tagDiff] as? TagUpdateDiff else {
            reloadFromManager()
            return
        }

        applyTagDiff(diff)

        switch changeType {
        case .added, .updated:
            if let annotation = userInfo[AnnotationNotificationKeys.annotation] as? Annotation {
                updateTagAnnotation(annotation)
            }
        case .deleted:
            break
        }
    }

    private func insertBookAnnotation(_ annotation: Annotation) {
        let newNode = makeAnnotationNode(annotation)
        let groupIndex = indexOfBookGroup(for: annotation.bkId) ?? createBookGroup(for: annotation.bkId)

        if rootNodes[groupIndex].children == nil {
            rootNodes[groupIndex].children = []
        }

        if rootNodes[groupIndex].children?.contains(where: { $0.annotation?.id == annotation.id }) == true {
            updateBookAnnotation(annotation)
            return
        }

        let insertIndex = rootNodes[groupIndex].children?.insertionIndex(for: newNode) {
            compareAnnotations($0.annotation, $1.annotation)
        } ?? 0
        rootNodes[groupIndex].children?.insert(newNode, at: insertIndex)
        resortBookGroupsIfNeeded()
    }

    private func updateBookAnnotation(_ annotation: Annotation) {
        guard let annotationId = annotation.id else {
            reloadFromManager()
            return
        }

        if let currentGroupIndex = indexOfAnnotation(id: annotationId)?.groupIndex {
            removeBookAnnotation(id: annotationId)
            if currentGroupIndex < rootNodes.count, rootNodes[currentGroupIndex].children?.isEmpty == true {
                rootNodes.remove(at: currentGroupIndex)
            }
        }

        insertBookAnnotation(annotation)
    }

    private func removeBookAnnotation(id: Int64) {
        guard let location = indexOfAnnotation(id: id) else { return }
        rootNodes[location.groupIndex].children?.remove(at: location.childIndex)
        if rootNodes[location.groupIndex].children?.isEmpty == true {
            rootNodes.remove(at: location.groupIndex)
        } else {
            resortBookGroupsIfNeeded()
        }
    }

    private func applyTagDiff(_ diff: TagUpdateDiff) {
        for removed in diff.removed {
            removeTagEntry(removed)
        }

        for updatedNode in diff.updated {
            guard let annotation = updatedNode.annotation else { continue }
            updateTagAnnotation(annotation)
        }

        for added in diff.added {
            insertTagEntry(added)
        }

        resortTagGroups()
    }

    private func removeTagEntry(_ entry: TagUpdateDiff.RemovedEntry) {
        if entry.annotationNode.kind == .tag || entry.annotationNode.kind == .untagged {
            rootNodes.removeAll {
                $0.kind == entry.annotationNode.kind && $0.title == entry.annotationNode.title
            }
            return
        }

        guard let parentIndex = indexOfTagGroup(title: entry.tagNode.title, kind: mapKind(entry.tagNode.kind)) else {
            return
        }

        if let annotationId = entry.annotationNode.annotation?.id,
           let childIndex = rootNodes[parentIndex].children?.firstIndex(where: { $0.annotation?.id == annotationId })
        {
            rootNodes[parentIndex].children?.remove(at: childIndex)
        }

        if entry.tagNodeBecomesEmpty || rootNodes[parentIndex].children?.isEmpty == true {
            rootNodes.remove(at: parentIndex)
        }
    }

    private func insertTagEntry(_ entry: TagUpdateDiff.AddedEntry) {
        let groupKind = mapKind(entry.tagNode.kind)
        let groupIndex: Int

        if let existingIndex = indexOfTagGroup(title: entry.tagNode.title, kind: groupKind) {
            groupIndex = existingIndex
        } else {
            let newGroup = iOSAnnotationNode(
                id: groupID(for: entry.tagNode.title, kind: groupKind),
                title: entry.tagNode.title,
                kind: groupKind,
                annotation: nil,
                children: []
            )
            groupIndex = rootNodes.insertionIndex(for: newGroup, using: compareTagGroups)
            rootNodes.insert(newGroup, at: groupIndex)
        }

        guard let annotation = entry.annotationNode.annotation else { return }
        let newNode = makeAnnotationNode(annotation)

        if rootNodes[groupIndex].children == nil {
            rootNodes[groupIndex].children = []
        }

        guard rootNodes[groupIndex].children?.contains(where: { $0.annotation?.id == annotation.id }) != true else {
            updateTagAnnotation(annotation)
            return
        }

        let insertIndex = rootNodes[groupIndex].children?.insertionIndex(for: newNode) {
            compareAnnotations($0.annotation, $1.annotation)
        } ?? 0
        rootNodes[groupIndex].children?.insert(newNode, at: insertIndex)
    }

    private func updateTagAnnotation(_ annotation: Annotation) {
        guard let annotationId = annotation.id else { return }
        for groupIndex in rootNodes.indices {
            guard let childIndex = rootNodes[groupIndex].children?.firstIndex(where: {
                $0.annotation?.id == annotationId
            }) else { continue }

            rootNodes[groupIndex].children?[childIndex] = makeAnnotationNode(annotation)
            if let updatedChildren = rootNodes[groupIndex].children {
                rootNodes[groupIndex].children = updatedChildren.sorted {
                    compareAnnotations($0.annotation, $1.annotation)
                }
            }
        }
    }

    private func resortBookGroupsIfNeeded() {
        guard sortField == .createdAt else { return }
        rootNodes.sort(by: compareBookGroups)
    }

    private func resortTagGroups() {
        rootNodes.sort(by: compareTagGroups)
        for index in rootNodes.indices {
            if let children = rootNodes[index].children {
                rootNodes[index].children = children.sorted {
                    compareAnnotations($0.annotation, $1.annotation)
                }
            }
        }
    }

    private func compareAnnotations(_ lhs: Annotation?, _ rhs: Annotation?) -> Bool {
        guard let lhs, let rhs else { return false }

        let orderedAscending: Bool
        switch sortField {
        case .createdAt:
            orderedAscending = lhs.createdAt == rhs.createdAt
                ? lhs.context.localizedCaseInsensitiveCompare(rhs.context) == .orderedAscending
                : lhs.createdAt < rhs.createdAt
        case .context:
            let contextOrder = lhs.context.localizedCaseInsensitiveCompare(rhs.context)
            orderedAscending = contextOrder == .orderedSame
                ? lhs.createdAt < rhs.createdAt
                : contextOrder == .orderedAscending
        case .page:
            orderedAscending = lhs.page == rhs.page
                ? lhs.createdAt < rhs.createdAt
                : lhs.page < rhs.page
        case .part:
            if lhs.part == rhs.part {
                orderedAscending = lhs.page == rhs.page
                    ? lhs.createdAt < rhs.createdAt
                    : lhs.page < rhs.page
            } else {
                orderedAscending = lhs.part < rhs.part
            }
        }

        return sortAscending ? orderedAscending : !orderedAscending
    }

    private func compareBookGroups(_ lhs: iOSAnnotationNode, _ rhs: iOSAnnotationNode) -> Bool {
        if sortField == .createdAt {
            let leftLatest = lhs.children?.compactMap { $0.annotation?.createdAt }.max() ?? 0
            let rightLatest = rhs.children?.compactMap { $0.annotation?.createdAt }.max() ?? 0
            if leftLatest != rightLatest {
                let orderedAscending = leftLatest < rightLatest
                return sortAscending ? orderedAscending : !orderedAscending
            }
        }

        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    private func compareTagGroups(_ lhs: iOSAnnotationNode, _ rhs: iOSAnnotationNode) -> Bool {
        if lhs.kind == .untagged { return false }
        if rhs.kind == .untagged { return true }
        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    private func makeAnnotationNode(_ annotation: Annotation) -> iOSAnnotationNode {
        iOSAnnotationNode(
            id: "ann-\(annotation.id ?? -1)",
            title: displayTitle(for: annotation),
            kind: .annotation,
            annotation: annotation,
            children: nil
        )
    }

    private func displayTitle(for annotation: Annotation) -> String {
        if let note = annotation.note, !note.isEmpty {
            return note
        }
        return annotation.context
    }

    private func indexOfAnnotation(id: Int64) -> (groupIndex: Int, childIndex: Int)? {
        for groupIndex in rootNodes.indices {
            guard let childIndex = rootNodes[groupIndex].children?.firstIndex(where: {
                $0.annotation?.id == id
            }) else { continue }
            return (groupIndex, childIndex)
        }
        return nil
    }

    private func indexOfBookGroup(for bkId: Int) -> Int? {
        rootNodes.firstIndex { node in
            node.children?.first?.annotation?.bkId == bkId
        }
    }

    private func createBookGroup(for bkId: Int) -> Int {
        let title = LibraryDataManager
            .shared.getBook([bkId]).first?.book ?? "Unknown Book" + " (\(bkId))"
        let newGroup = iOSAnnotationNode(
            id: groupID(for: title, kind: .book),
            title: title,
            kind: .book,
            annotation: nil,
            children: []
        )
        let insertIndex = rootNodes.insertionIndex(for: newGroup, using: compareBookGroups)
        rootNodes.insert(newGroup, at: insertIndex)
        return insertIndex
    }

    private func indexOfTagGroup(title: String, kind: AnnotationNodeKind) -> Int? {
        rootNodes.firstIndex { $0.kind == kind && $0.title == title }
    }

    private func mapKind(_ kind: AnnotationNodeKind) -> AnnotationNodeKind {
        switch kind {
        case .untagged:
            return .untagged
        case .tag:
            return .tag
        default:
            return .tag
        }
    }

    private func groupID(for title: String, kind: AnnotationNodeKind) -> String {
        "group-\(kind)-\(title)"
    }
}

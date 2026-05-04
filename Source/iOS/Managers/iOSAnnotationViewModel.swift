import Foundation
import SwiftUI

struct iOSAnnotationNode: Identifiable {
    let id: String
    let title: String
    let kind: AnnotationNodeKind
    let annotation: Annotation?
    var children: [iOSAnnotationNode]?

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
    }

    func loadAnnotations() {
        // Sinkronisasi status dari UserDefaults ke AnnotationManager sebelum memuat data
        AnnotationManager.shared.updateGroupingMode(groupingMode)
        AnnotationManager.shared.updateSorting(field: sortField, isAscending: sortAscending)
    }

    private func reloadFromManager() {
        if let coreNodes = AnnotationManager.shared.rootNode?.children {
            let mapped = coreNodes.map { iOSAnnotationNode(from: $0) }
            if searchText.isEmpty {
                rootNodes = mapped
            } else {
                rootNodes = filterNodes(mapped, with: searchText.lowercased())
            }
        }
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
}

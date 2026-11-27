#if os(iOS)
import Foundation
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

/// One immutable observation of the ORIGINAL published Saved Results tree.
/// Object identity is deliberate: FolderNode/ResultNode equality uses SQL IDs,
/// which can be reused by reloads. This proof neither loads nor edits the tree.
@MainActor final class MaktabahNativeSavedResultsSource {
    typealias Record = NativeSavedResultIntentService.Record
    enum Node {
        case folder(FolderNode)
        case result(ResultNode)
    }
    struct Entry {
        let record: Record
        let node: Node
        let path: [FolderNode]
    }
    private struct Folder {
        let node: FolderNode
        let id: Int64
        let name: [UInt8]
        let modified: Int64?
        let children: [FolderNode]
    }
    private struct Result {
        let node: ResultNode
        let id: Int64
        let parent: Int64?
        let name: [UInt8]
        let modified: Int64?
        let mode: Int
        let distance: Int
    }

    let model: ResultsViewModel
    let sceneID: UIStableID
    let entries: [Entry]
    private let revision: UInt64
    private let roots: [FolderNode]
    private let folders: [Int64: Folder]
    private let results: [Int64: Result]
    private let folderResults: [Int64?: [ResultNode]]
    private let parents: [Int64: Int64?]
    private let observation: MaktabahNativeComponentSourceObservation
    private var retired = false

    init(model: ResultsViewModel, sceneID: UIStableID) throws {
        guard let revision = model.nativeLoadLifetime.settledRevision,
              model.folderById.count <= 1_000, model.resultById.count <= 1_000,
              model.folderRoots.count <= 1_000, model.folderResults.count <= 1_001 else {
            throw UIRouteError(.unavailable, "saved_results_tree_not_settled")
        }
        var folders: [Int64: Folder] = [:]
        var paths: [Int64: [FolderNode]] = [:]
        var folderObjects: Set<ObjectIdentifier> = []
        func visit(_ node: FolderNode, parent: FolderNode?, path: [FolderNode]) throws {
            guard path.count < 32, folders.count < 1_000,
                  folders[node.id] == nil, folderObjects.insert(ObjectIdentifier(node)).inserted,
                  model.folderById[node.id] === node,
                  (model.parentById[node.id] ?? nil) == parent?.id else {
                throw UIRouteError(.staleState, "saved_results_tree_ambiguous")
            }
            folders[node.id] = Folder(node: node, id: node.id, name: Array(node.name.utf8),
                modified: node.lastModified, children: node.children)
            let next = path + [node]
            paths[node.id] = next
            for child in node.children { try visit(child, parent: node, path: next) }
        }
        for node in model.folderRoots { try visit(node, parent: nil, path: []) }
        guard folders.count == model.folderById.count else {
            throw UIRouteError(.staleState, "saved_results_unpublished_folder")
        }
        var results: [Int64: Result] = [:]
        var resultObjects: Set<ObjectIdentifier> = []
        for (parent, nodes) in model.folderResults {
            guard nodes.count <= 1_000, parent == nil || folders[parent!] != nil else {
                throw UIRouteError(.staleState, "saved_results_parent_missing")
            }
            for node in nodes {
                guard results.count < 1_000, results[node.id] == nil,
                      resultObjects.insert(ObjectIdentifier(node)).inserted,
                      node.parentId == parent, model.resultById[node.id] === node else {
                    throw UIRouteError(.staleState, "saved_results_record_ambiguous")
                }
                results[node.id] = Result(node: node, id: node.id, parent: parent,
                    name: Array(node.name.utf8), modified: node.lastModified,
                    mode: node.searchMode, distance: node.nearDistance)
            }
        }
        guard results.count == model.resultById.count else {
            throw UIRouteError(.staleState, "saved_results_unpublished_record")
        }
        var entries: [Entry] = []
        for value in folders.values.sorted(by: { $0.id < $1.id }) {
            guard let record = try? Record(reference: .init(backend: .otzaria, kind: .folder, token: UUID()),
                title: value.node.name, sceneID: sceneID), let path = paths[value.id] else { continue }
            entries.append(Entry(record: record, node: .folder(value.node), path: path))
        }
        for value in results.values.sorted(by: { $0.id < $1.id }) {
            guard let record = try? Record(reference: .init(backend: .otzaria, kind: .result, token: UUID()),
                title: value.node.name, sceneID: sceneID) else { continue }
            let path = value.parent.flatMap { paths[$0] } ?? []
            entries.append(Entry(record: record, node: .result(value.node), path: path))
        }
        guard entries.count <= 1_000 else { throw UIRouteError(.unavailable, "saved_results_catalog_limit") }
        self.model = model; self.sceneID = sceneID; self.revision = revision
        roots = model.folderRoots; folderResults = model.folderResults; parents = model.parentById
        self.folders = folders; self.results = results; self.entries = entries
        observation = MaktabahNativeComponentSourceObservation {
            _ = model.nativeLoadLifetime.settledRevision
            _ = model.folderRoots; _ = model.folderResults; _ = model.folderById
            _ = model.parentById; _ = model.resultById
            for value in folders.values {
                _ = value.node.name; _ = value.node.lastModified; _ = value.node.children
            }
            for value in results.values {
                _ = value.node.id; _ = value.node.parentId; _ = value.node.name
                _ = value.node.lastModified; _ = value.node.searchMode; _ = value.node.nearDistance
            }
        }
        try validate()
    }

    func retire() { retired = true }

    func validate() throws {
        try observation.validate()
        guard !retired, model.nativeLoadLifetime.isCurrent(revision),
              Self.identical(model.folderRoots, roots),
              model.folderById.count == folders.count, model.resultById.count == results.count,
              model.parentById == parents, Set(model.folderResults.keys) == Set(folderResults.keys) else {
            throw UIRouteError(.staleState, "saved_results_tree_changed")
        }
        for (id, value) in folders {
            guard model.folderById[id] === value.node, value.node.id == value.id,
                  value.node.name.utf8.elementsEqual(value.name), value.node.lastModified == value.modified,
                  Self.identical(value.node.children, value.children) else {
                throw UIRouteError(.staleState, "saved_results_folder_changed")
            }
        }
        for (parent, expected) in folderResults {
            guard let current = model.folderResults[parent], Self.identical(current, expected) else {
                throw UIRouteError(.staleState, "saved_results_records_changed")
            }
        }
        for (id, value) in results {
            guard model.resultById[id] === value.node, value.node.id == value.id,
                  value.node.parentId == value.parent, value.node.name.utf8.elementsEqual(value.name),
                  value.node.lastModified == value.modified, value.node.searchMode == value.mode,
                  value.node.nearDistance == value.distance else {
                throw UIRouteError(.staleState, "saved_results_record_changed")
            }
        }
        try observation.validate()
        guard !retired, model.nativeLoadLifetime.isCurrent(revision) else {
            throw UIRouteError(.staleState, "saved_results_source_retired")
        }
    }

    func entry(_ record: Record) throws -> Entry {
        try validate()
        let matches = entries.filter { $0.record == record }
        guard matches.count == 1, let entry = matches.first else {
            throw UIRouteError(.staleState, "saved_results_record_not_retained")
        }
        return entry
    }

    /// Match the ORIGINAL flattened-list predicate without changing or
    /// publishing the private filter. Names/queries remain local to the owner.
    func matchesOriginalFilter(_ entry: Entry, filter: String) -> Bool {
        guard !filter.isEmpty else { return true }
        switch entry.node {
        case .folder(let node): return node.name.localizedStandardContains(filter)
        case .result(let node):
            return node.name.localizedStandardContains(filter)
                || (node.items.first?.query ?? "").localizedStandardContains(filter)
        }
    }

    static func identical<T: AnyObject>(_ lhs: [T], _ rhs: [T]) -> Bool {
        lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { pair in pair.0 === pair.1 }
    }
}
#endif

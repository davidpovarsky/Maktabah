//
//  BookTOCViewModel.swift
//  Maktabah
//
//  Created by Ghoys Mawahib on 18/06/26.
//

import Foundation
import Observation
import OSLog
import SwiftUI

struct TOCRange {
    let start: Int
    let end: Int
    let node: TOCNode
}

@Observable @MainActor
class BookTOCViewModel {
    enum LoadFailure: Equatable {
        case unavailableOffline
        case corruptData
        case backend

        var message: String {
            switch self {
            case .unavailableOffline: String(localized: "The table of contents is unavailable offline.")
            case .corruptData: String(localized: "The downloaded table of contents is damaged.")
            case .backend: String(localized: "The table of contents could not be loaded.")
            }
        }
    }

    private let tocLoader: TOCLoaderRefCount

    enum TOCLoadingStatus: Equatable {
        case idle
        case loading
        case loaded
        case failed(LoadFailure)
    }

    // State
    var tocNodes: [TOCNode] = []
    var navigationStructures: [LibraryNavigationStructure] = []
    var selectedStructureID: String = ""
    var loadFailure: LoadFailure?
    var isLoading: Bool = false
    var loadingStatus: TOCLoadingStatus = .idle
    private(set) var tocRanges: [TOCRange] = []
    private var nodeIdCache: [Int: TOCNode] = [:]

    // Callbacks
    var onTOCLoadingStateChanged: ((Bool) -> Void)?
    var onTOCLoaded: (([TOCNode]) -> Void)?
    var onStructureChanged: (([LibraryNavigationItem]) -> Void)?

    private var loadingTask: Task<Void, Never>?

    init(connFactory: @escaping @Sendable () -> BookConnection) {
        tocLoader = TOCLoaderRefCount(connFactory: connFactory)
    }

    func loadTOC(book: BooksData) {
        loadingTask?.cancel()
        loadFailure = nil
        loadingStatus = .loading
        tocNodes = []
        navigationStructures = []
        selectedStructureID = ""

        if let locator = book.backendLocator {
            let expectedWorkKey = locator.workKey
            loadingTask = Task { @MainActor [weak self] in
                guard let self else { return }
                self.isLoading = true
                self.loadingStatus = .loading
                self.onTOCLoadingStateChanged?(true)
                defer {
                    self.isLoading = false
                    self.onTOCLoadingStateChanged?(false)
                }
                do {
                    let work = LibraryWork(
                        locator: locator,
                        title: locator.workKey,
                        heTitle: book.book,
                        categories: [],
                        description: nil
                    )
                    let structures = try await BackendCoordinator.shared.navigationStructures(for: work)
                    try Task.checkCancellation()
                    guard book.backendLocator?.workKey == expectedWorkKey else { return }
                    self.navigationStructures = structures
                    let activeStructure = structures.first
                    self.selectedStructureID = activeStructure?.id ?? ""
                    let nodes: [LibraryTOCNode]
                    if let activeNodes = activeStructure?.nodes {
                        nodes = activeNodes
                    } else {
                        nodes = try await BackendCoordinator.shared.tableOfContents(for: work)
                    }
                    try Task.checkCancellation()
                    guard book.backendLocator?.workKey == expectedWorkKey else { return }
                    func convert(_ item: LibraryTOCNode, level: Int) -> TOCNode {
                        let id = LegacyIdentityRegistry.shared.id(for: item.locator)
                        let node = TOCNode(backendTitle: item.title, level: level, sub: 0, id: id)
                        node.backendLocator = item.locator
                        node.children = item.children.map { convert($0, level: level + 1) }
                        return node
                    }
                    let tree = nodes.map { convert($0, level: 1) }
                    self.tocNodes = tree
                    self.loadingStatus = .loaded
                    let allNodes = Self.flattenNodes(tree)
                    self.tocRanges = allNodes.map { TOCRange(start: $0.id, end: $0.id, node: $0) }
                    self.nodeIdCache = Self.buildNodeIdCache(allNodes)
                    let items = self.flatNavigationItems(for: self.selectedStructureID)
                    if !items.isEmpty {
                        self.onStructureChanged?(items)
                    }
                    self.onTOCLoaded?(tree)
                } catch is CancellationError {
                    return
                } catch {
                    guard !Task.isCancelled, book.backendLocator?.workKey == expectedWorkKey else { return }
                    let failure: LoadFailure
                    if case LibraryBackendError.unavailableOffline = error {
                        failure = .unavailableOffline
                    } else if case LibraryBackendError.corruptData(_) = error {
                        failure = .corruptData
                    } else {
                        failure = .backend
                    }
                    self.loadFailure = failure
                    self.loadingStatus = .failed(failure)
                    Logger.reader.error("Failed to load backend TOC: \(error.localizedDescription, privacy: .public)")
                }
            }
            return
        }

        loadingTask = Task { [weak self] in
            guard let self else { return }
            self.onTOCLoadingStateChanged?(true)

            let taskHandle = await self.tocLoader.acquire(book: book)
            defer {
                Task { [weak self] in
                    await self?.tocLoader.release(bookId: book.id)
                }
            }

            do {
                let tree = try await taskHandle.value
                guard !Task.isCancelled else {
                    self.onTOCLoadingStateChanged?(false)
                    return
                }

                // Heavy calculation in background detached task
                let (ranges, cache) = await Task.detached {
                    let allNodes = Self.flattenNodes(tree)
                    Self.computeEndIDs(for: allNodes)
                    let ranges = Self.buildRanges(from: allNodes)
                    let cache = Self.buildNodeIdCache(allNodes)
                    return (ranges, cache)
                }.value

                guard !Task.isCancelled else {
                    self.onTOCLoadingStateChanged?(false)
                    return
                }

                // Update UI back on MainActor
                self.tocNodes = tree
                self.tocRanges = ranges
                self.nodeIdCache = cache
                self.onTOCLoaded?(tree)
                self.onTOCLoadingStateChanged?(false)
            } catch {
                self.onTOCLoadingStateChanged?(false)
                Logger.reader.error("Failed to load TOC: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func selectStructure(id: String) {
        guard selectedStructureID != id,
              let structure = navigationStructures.first(where: { $0.id == id }) else { return }
        selectedStructureID = id
        func convert(_ item: LibraryTOCNode, level: Int) -> TOCNode {
            let id = LegacyIdentityRegistry.shared.id(for: item.locator)
            let node = TOCNode(backendTitle: item.title, level: level, sub: 0, id: id)
            node.backendLocator = item.locator
            node.children = item.children.map { convert($0, level: level + 1) }
            return node
        }
        let tree = structure.nodes.map { convert($0, level: 1) }
        tocNodes = tree
        let allNodes = Self.flattenNodes(tree)
        tocRanges = allNodes.map { TOCRange(start: $0.id, end: $0.id, node: $0) }
        nodeIdCache = Self.buildNodeIdCache(allNodes)
        let items = flatNavigationItems(for: id)
        onStructureChanged?(items)
    }

    func flatNavigationItems(for structureID: String) -> [LibraryNavigationItem] {
        guard let structure = navigationStructures.first(where: { $0.id == structureID }) else { return [] }
        var items: [LibraryNavigationItem] = []
        func collectLeaves(_ nodes: [LibraryTOCNode]) {
            for node in nodes {
                if node.children.isEmpty {
                    items.append(LibraryNavigationItem(
                        locator: node.locator,
                        title: node.title,
                        index: items.count
                    ))
                } else {
                    collectLeaves(node.children)
                }
            }
        }
        collectLeaves(structure.nodes)
        return items
    }

    nonisolated private static func flattenNodes(_ roots: [TOCNode]) -> [TOCNode] {
        var result: [TOCNode] = []
        func traverse(_ node: TOCNode) {
            result.append(node)
            for child in node.children {
                traverse(child)
            }
        }
        for r in roots {
            traverse(r)
        }
        return result
    }

    nonisolated private static func computeEndIDs(for allNodes: [TOCNode]) {
        for (i, node) in allNodes.enumerated() {
            if let nextDiffNode = allNodes[(i + 1)...].first(where: { $0.id > node.id }) {
                node.endID = nextDiffNode.id - 1
            } else {
                node.endID = Int.max
            }
        }
    }

    nonisolated private static func buildRanges(from nodes: [TOCNode]) -> [TOCRange] {
        nodes.map { node in
            TOCRange(start: node.id, end: node.endID, node: node)
        }
    }

    // MARK: - Search / Find Path

    func findNode(forContentId contentId: Int) -> TOCNode? {
        let matches = tocRanges.filter { contentId >= $0.start && contentId <= $0.end }
        return matches.min(by: {
            let r0 = $0.end - $0.start
            let r1 = $1.end - $1.start
            if r0 != r1 {
                return r0 < r1
            }
            return $0.node.level > $1.node.level
        })?.node
    }

    func findNodeById(_ id: Int) -> TOCNode? {
        nodeIdCache[id]
    }

    func findNode(for locator: TextLocator) -> TOCNode? {
        let allNodes = Self.flattenNodes(tocNodes)
        return allNodes.first { $0.backendLocator == locator }
    }

    func findMatchingNode(for locator: TextLocator) -> TOCNode? {
        let allNodes = Self.flattenNodes(tocNodes)
        let flattened = allNodes.map { FlattenedTOCItem(id: $0.id, title: $0.bab, level: $0.level, locator: $0.backendLocator) }
        guard let matchingID = TOCReadingLocationTracker.findMatchingNodeID(for: locator, in: flattened) else {
            return nil
        }
        return findNodeById(matchingID)
    }

    /// Mencari path lengkap dari root ke node terdalam yang mencakup contentId.
    /// Menggunakan tocRanges (endID yang sudah benar) lalu pathToNode untuk full path.
    func deepestPath(forContentId contentId: Int) -> [TOCNode]? {
        guard let deepest = findNode(forContentId: contentId) else {
            return nil
        }
        return pathToNode(deepest)
    }

    func pathToNode(_ target: TOCNode) -> [TOCNode]? {
        for root in tocNodes {
            if let p = findPath(root, target) { return p }
        }
        return nil
    }

    private func findPath(_ current: TOCNode, _ target: TOCNode) -> [TOCNode]? {
        if current === target { return [current] }
        for child in current.children {
            if let p = findPath(child, target) {
                return [current] + p
            }
        }
        return nil
    }

    /// Build the id→node lookup safely. Two TOC nodes may legitimately share
    /// the same navigation-target locator (hence the same surrogate ID from
    /// LegacyIdentityRegistry). When duplicates exist, keep the deepest-level
    /// node so `findNodeById` returns the most specific entry.
    nonisolated private static func buildNodeIdCache(_ nodes: [TOCNode]) -> [Int: TOCNode] {
        var cache: [Int: TOCNode] = [:]
        cache.reserveCapacity(nodes.count)
        for node in nodes {
            if let existing = cache[node.id] {
                // Keep the deeper (more specific) node.
                if node.level > existing.level {
                    cache[node.id] = node
                }
            } else {
                cache[node.id] = node
            }
        }
        return cache
    }

    func setTOCData(nodes: [TOCNode], ranges: [TOCRange]? = nil) {
        self.tocNodes = nodes
        if let ranges {
            self.tocRanges = ranges
        } else {
            let allNodes = Self.flattenNodes(nodes)
            Self.computeEndIDs(for: allNodes)
            self.tocRanges = Self.buildRanges(from: allNodes)
        }
        self.nodeIdCache = Self.buildNodeIdCache(self.tocRanges.map { $0.node })
    }

    func cleanUp() {
        loadingTask?.cancel()
        loadingTask = nil
        tocNodes.removeAll()
        tocRanges.removeAll()
        nodeIdCache.removeAll()
    }

    deinit {
        MainActor.assumeIsolated {
            cleanUp()
        }
    }
}

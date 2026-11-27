struct TOCRange {
    let start: Int
    let end: Int
    let node: TOCNode
}
@MainActor final class BookTOCViewModel {

 var tocNodes: [TOCNode]
 var tocRanges: [TOCRange]
 private var nodeIdCache: [Int:TOCNode]
 init(nodes: [TOCNode]) {
   tocNodes = nodes
   let flattened = Self.flattenNodes(nodes)
   tocRanges = flattened.map { TOCRange(start: $0.id, end: $0.id, node: $0) }
   nodeIdCache = Self.buildNodeIdCache(flattened)
 }
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
}

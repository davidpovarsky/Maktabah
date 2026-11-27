import Foundation
import Foundation
enum BackendID: String, Codable, CaseIterable, Identifiable, Sendable {
    case otzaria
    case sefaria
    case sefariaEmbedded

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .otzaria: return "אוצריא"
        case .sefaria: return "ספריא (ישן)"
        case .sefariaEmbedded: return "ספריא"
        }
    }

    var englishDisplayName: String {
        switch self {
        case .otzaria: return "Otzaria"
        case .sefaria: return "Sefaria (Legacy)"
        case .sefariaEmbedded: return "Sefaria"
        }
    }
}

enum TextPosition: Codable, Hashable, Sendable, CustomStringConvertible {
    case legacyLine(Int)
    case canonicalRef(String)

    private enum CodingKeys: String, CodingKey { case kind, integer, string }
    private enum Kind: String, Codable { case legacyLine, canonicalRef }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        switch try values.decode(Kind.self, forKey: .kind) {
        case .legacyLine: self = .legacyLine(try values.decode(Int.self, forKey: .integer))
        case .canonicalRef: self = .canonicalRef(try values.decode(String.self, forKey: .string))
        }
    }

    var description: String {
        switch self {
        case .legacyLine(let value): return "line:\(value)"
        case .canonicalRef(let value): return value
        }
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .legacyLine(let value):
            try values.encode(Kind.legacyLine, forKey: .kind)
            try values.encode(value, forKey: .integer)
        case .canonicalRef(let value):
            try values.encode(Kind.canonicalRef, forKey: .kind)
            try values.encode(value, forKey: .string)
        }
    }
}

struct TextLocator: Codable, Hashable, Sendable {
    let backend: BackendID
    let workKey: String
    let position: TextPosition

    var persistenceKey: String {
        let positionKey: String
        switch position {
        case .legacyLine(let value): positionKey = "line:\(value)"
        case .canonicalRef(let value): positionKey = "ref:\(value)"
        }
        return "\(backend.rawValue)|\(workKey)|\(positionKey)"
    }
}
//
//  TOCReadingLocationTracker.swift
//  Maktabah
//
//  Downstream-owned TOC tracking coordinator that maps the current reading unit locator
//  to the deepest visible TOC leaf or ancestor, keeping the sidebar selection in sync.
//

import Foundation

struct FlattenedTOCItem: Identifiable, Sendable {
    let id: Int
    let title: String
    let level: Int
    let locator: TextLocator?

    init(id: Int, title: String, level: Int, locator: TextLocator?) {
        self.id = id
        self.title = title
        self.level = level
        self.locator = locator
    }
}

enum TOCReadingLocationTracker: Sendable {
    /// Finds the deepest matching TOC node for the given reading unit locator.
    static func findMatchingNodeID(
        for locator: TextLocator,
        in flattenedNodes: [FlattenedTOCItem]
    ) -> Int? {
        guard !flattenedNodes.isEmpty else { return nil }

        // 1. Direct exact match
        if let exact = flattenedNodes.first(where: { $0.locator == locator }) {
            return exact.id
        }

        switch locator.backend {
        case .otzaria:
            // In Otzaria, nodes are indexed by line anchors (.legacyLine)
            guard case .legacyLine(let currentLine) = locator.position else {
                return nil
            }
            // Find all nodes that start at or before currentLine within the same work
            let eligible = flattenedNodes.compactMap { item -> (line: Int, level: Int, id: Int)? in
                guard let nodeLoc = item.locator,
                      nodeLoc.backend == .otzaria,
                      nodeLoc.workKey == locator.workKey,
                      case .legacyLine(let nodeLine) = nodeLoc.position,
                      nodeLine <= currentLine else {
                    return nil
                }
                return (line: nodeLine, level: item.level, id: item.id)
            }
            // Sort by: largest line first (closest heading), then deepest level
            return eligible.max(by: {
                if $0.line != $1.line {
                    return $0.line < $1.line
                }
                return $0.level < $1.level
            })?.id

        case .sefaria, .sefariaEmbedded:
            // In Sefaria, nodes are canonical refs (.canonicalRef)
            guard case .canonicalRef(let currentRef) = locator.position else {
                return nil
            }
            let canonicalCurrent = SefariaRef.canonicalInput(currentRef)
            let ancestors = Set(SefariaRef.sectionAncestors(of: canonicalCurrent))

            // Find nodes whose locator ref structurally matches an ancestor
            // Eliminates unsafe loose prefix matching that conflates e.g. "Genesis 1" with "Genesis 10"
            let matchingAncestors = flattenedNodes.compactMap { item -> (level: Int, id: Int)? in
                guard let nodeLoc = item.locator,
                      nodeLoc.backend == locator.backend,
                      nodeLoc.workKey == locator.workKey,
                      case .canonicalRef(let nodeRef) = nodeLoc.position else {
                    return nil
                }
                let canonicalNode = SefariaRef.canonicalInput(nodeRef)
                let isStructuralMatch = ancestors.contains(canonicalNode)
                    || canonicalCurrent == canonicalNode
                    || canonicalCurrent.hasPrefix(canonicalNode + ":")
                    || canonicalCurrent.hasPrefix(canonicalNode + " ")
                if isStructuralMatch {
                    return (level: item.level, id: item.id)
                }
                return nil
            }
            // Return deepest matching ancestor
            return matchingAncestors.max(by: { $0.level < $1.level })?.id
        }
    }
}

import Foundation
enum SefariaRef {
    static func canonicalInput(_ input: String) -> String {
        var value = input.removingPercentEncoding ?? input
        value = value.replacingOccurrences(of: "_", with: " ")
        if let firstSectionDot = value.range(of: #"\.(?=\d)"#, options: .regularExpression) {
            value.replaceSubrange(firstSectionDot, with: " ")
            let suffix = firstSectionDot.lowerBound..<value.endIndex
            value = value.replacingOccurrences(of: ".", with: ":", options: [], range: suffix)
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    static func segmentRef(sectionRef: String, offset: Int) -> String {
        if sectionRef.range(of: #"\d[ab]$"#, options: .regularExpression) != nil {
            return "\(sectionRef):\(offset)"
        }
        return sectionRef.contains(":") ? "\(sectionRef):\(offset)" : "\(sectionRef):\(offset)"
    }

    static func workKey(from canonicalRef: String, knownTitles: [String]) -> String? {
        knownTitles.filter { canonicalRef == $0 || canonicalRef.hasPrefix($0 + " ") }
            .max(by: { $0.count < $1.count })
    }

    static func talmudAddress(offset: Int) -> String {
        "\(offset / 2 + 2)\(offset.isMultiple(of: 2) ? "a" : "b")"
    }

    static func sectionMatches(_ lhs: String, _ rhs: String) -> Bool {
        let lhs = canonicalInput(lhs)
        let rhs = canonicalInput(rhs)
        return lhs == rhs || lhs.hasPrefix(rhs + ":") || rhs.hasPrefix(lhs + ":")
    }

    static func sectionAncestors(of input: String) -> [String] {
        var current = canonicalInput(input)
        var result = [current]
        while let range = current.range(
            of: #":[0-9]+[ab]?(?:-[^:\s]+)?$"#,
            options: [.regularExpression, .caseInsensitive]
        ) {
            current.removeSubrange(range)
            result.append(current)
        }
        return result
    }

    static func inferredWorkKey(from input: String) -> String {
        let canonical = canonicalInput(input)
        guard let range = canonical.range(
            of: #"\s+[0-9]+[ab]?(?::[0-9]+[ab]?)*(?:-\S+)?$"#,
            options: [.regularExpression, .caseInsensitive]
        ) else { return canonical }
        return String(canonical[..<range.lowerBound])
    }

    static func segmentOffset(in input: String, relativeTo sectionRef: String) -> Int? {
        let input = canonicalInput(input)
        let section = canonicalInput(sectionRef)
        guard input.hasPrefix(section + ":") else { return nil }
        let suffix = input.dropFirst(section.count + 1)
        guard !suffix.contains(":"), let first = suffix.split(separator: "-").first else { return nil }
        return Int(first)
    }

    static func anchorReference(_ anchor: String, contains requestedRef: String) -> Bool {
        let anchor = canonicalInput(anchor)
        let requested = canonicalInput(requestedRef)
        if anchor == requested { return true }
        guard let dash = anchor.lastIndex(of: "-") else { return false }
        let startText = String(anchor[..<dash])
        let endText = String(anchor[anchor.index(after: dash)...])
        guard let start = finalNumericAddress(startText),
              let requestedAddress = finalNumericAddress(requested) else { return false }
        let end: (prefix: String, value: Int)
        if let value = Int(endText) {
            end = (start.prefix, value)
        } else if let fullEnd = finalNumericAddress(endText) {
            end = fullEnd
        } else {
            return false
        }
        guard start.prefix == requestedAddress.prefix,
              end.prefix == requestedAddress.prefix else { return false }
        return requestedAddress.value >= min(start.value, end.value)
            && requestedAddress.value <= max(start.value, end.value)
    }

    private static func finalNumericAddress(_ input: String) -> (prefix: String, value: Int)? {
        let canonical = canonicalInput(input)
        guard let range = canonical.range(of: #"[0-9]+$"#, options: .regularExpression),
              let value = Int(canonical[range]) else { return nil }
        return (String(canonical[..<range.lowerBound]), value)
    }
}
//
//  TOCNode.swift
//  Maktabah
//

import Foundation

final class TOCNode: Identifiable, @unchecked Sendable {
    let bab: String
    let level: Int
    let sub: Int
    let id: Int
    let entryId: Int
    let parentId: Int?
    var children: [TOCNode] = []
    /// Canonical locator for backend-originated nodes. When present,
    /// navigation should use this directly instead of the legacy integer ``id``.
    var backendLocator: TextLocator?

    var endID: Int = .max

    init(from toc: TOC) {
        bab = toc.bab.convertToArabicDigits()
        level = toc.level
        sub = toc.sub
        id = toc.id
        entryId = toc.entryId
        parentId = toc.parentId
    }

    /// Backend initializer — preserves title verbatim without Arabic digit conversion.
    /// Used for Sefaria/Otzaria TOC entries whose titles must remain as-is.
    init(backendTitle: String, level: Int, sub: Int, id: Int, parentId: Int? = nil, entryId: Int? = nil) {
        bab = backendTitle
        self.level = level
        self.sub = sub
        self.id = id
        self.entryId = entryId ?? id
        self.parentId = parentId
    }
}

import Foundation
final class LegacyIdentityRegistry: @unchecked Sendable {
    static let shared = LegacyIdentityRegistry()
    private let lock = NSLock()
    private let defaults: UserDefaults
    private let mapKey = "qualifiedLocatorSurrogates.v1"
    private let locatorKey = "qualifiedLocatorReverse.v1"
    private let titleKey = "qualifiedLocatorTitles.v1"
    private let persistenceQueue = DispatchQueue(label: "com.maktabah.legacy-identity.persistence", qos: .utility)
    private let persistenceDelay: TimeInterval
    private var map: [String: Int]
    private var reverse: [Int: TextLocator]
    private var titles: [String: String]
    private var nextID: Int
    private var mutationGeneration: UInt64 = 0
    private var persistedGeneration: UInt64 = 0
    private var persistenceScheduled = false
    private(set) var persistenceBatchCount = 0

    init(defaults: UserDefaults = .standard, persistenceDelay: TimeInterval = 0.25) {
        self.defaults = defaults
        self.persistenceDelay = persistenceDelay
        let storedMap = defaults.dictionary(forKey: mapKey) as? [String: Int] ?? [:]
        map = storedMap
        reverse = [:]
        titles = defaults.dictionary(forKey: titleKey) as? [String: String] ?? [:]
        if let data = defaults.data(forKey: locatorKey),
           let stored = try? JSONDecoder().decode([String: TextLocator].self, from: data) {
            reverse = Dictionary(uniqueKeysWithValues: stored.compactMap { key, value in Int(key).map { ($0, value) } })
        }
        nextID = (storedMap.values.min() ?? 0) - 1
    }

    func id(for locator: TextLocator) -> Int {
        id(for: locator, title: nil)
    }

    func id(for locator: TextLocator, title: String?) -> Int {
        lock.lock(); defer { lock.unlock() }
        if let title = title, titles[locator.persistenceKey] != title {
            titles[locator.persistenceKey] = title
            mutationGeneration &+= 1
            schedulePersistenceLocked()
        }
        if let existing = map[locator.persistenceKey] { return existing }
        let next = nextID
        nextID -= 1
        map[locator.persistenceKey] = next
        reverse[next] = locator
        mutationGeneration &+= 1
        schedulePersistenceLocked()
        return next
    }

    func register(title: String, for locator: TextLocator) {
        lock.lock(); defer { lock.unlock() }
        guard titles[locator.persistenceKey] != title else { return }
        titles[locator.persistenceKey] = title
        mutationGeneration &+= 1
        schedulePersistenceLocked()
    }

    func title(for locator: TextLocator) -> String? {
        lock.lock(); defer { lock.unlock() }
        return titles[locator.persistenceKey]
    }

    func title(for id: Int) -> String? {
        lock.lock(); defer { lock.unlock() }
        guard let locator = reverse[id] else { return nil }
        return titles[locator.persistenceKey]
    }

    func locator(for id: Int) -> TextLocator? {
        lock.lock(); defer { lock.unlock() }
        return reverse[id]
    }

    func flush() {
        let snapshot: ([String: Int], [Int: TextLocator], [String: String], UInt64)? = lock.synchronized {
            guard mutationGeneration > persistedGeneration else {
                persistenceScheduled = false
                return nil
            }
            return (map, reverse, titles, mutationGeneration)
        }
        guard let snapshot else { return }
        persist(snapshot)
        lock.synchronized {
            persistedGeneration = max(persistedGeneration, snapshot.3)
            persistenceScheduled = false
        }
    }

    private func schedulePersistenceLocked() {
        guard !persistenceScheduled else { return }
        persistenceScheduled = true
        persistenceQueue.asyncAfter(deadline: .now() + persistenceDelay) { [weak self] in
            self?.persistPendingChanges()
        }
    }

    private func persistPendingChanges() {
        let snapshot: ([String: Int], [Int: TextLocator], [String: String], UInt64)? = lock.synchronized {
            guard persistenceScheduled, mutationGeneration > persistedGeneration else { return nil }
            return (map, reverse, titles, mutationGeneration)
        }
        guard let snapshot else { return }
        persist(snapshot)
        lock.synchronized {
            persistedGeneration = max(persistedGeneration, snapshot.3)
            persistenceScheduled = false
            if mutationGeneration > persistedGeneration {
                schedulePersistenceLocked()
            }
        }
    }

    private func persist(_ snapshot: ([String: Int], [Int: TextLocator], [String: String], UInt64)) {
        defaults.set(snapshot.0, forKey: mapKey)
        defaults.set(snapshot.2, forKey: titleKey)
        let storedReverse = Dictionary(uniqueKeysWithValues: snapshot.1.map { (String($0.key), $0.value) })
        if let data = try? JSONEncoder().encode(storedReverse) {
            defaults.set(data, forKey: locatorKey)
        }
        lock.synchronized { persistenceBatchCount += 1 }
    }
}
private extension NSLock {
    func synchronized<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
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
@MainActor struct ActualIPadHost {
    private func selectedTOCNode(for viewModel: ReaderViewModel) -> TOCNode? {
        if let locator = viewModel.backendSection?.locator,
           let node = viewModel.tocViewModel.findNode(for: locator) {
            return node
        }
        return viewModel.tocViewModel.findNode(forContentId: viewModel.currentContentId)
    }
func select(_ reader: ReaderViewModel) -> TOCNode? { selectedTOCNode(for: reader) }
}
@MainActor struct LegacyIPadHost {
    private func selectedTOCNode(for viewModel: ReaderViewModel) -> TOCNode? {
        if let locator = viewModel.backendSection?.locator,
           let node = viewModel.tocViewModel.findNode(for: locator) {
            return node
        }
        return viewModel.tocViewModel.findNode(forContentId: viewModel.currentContentId)
    }
func select(_ reader: ReaderViewModel) -> TOCNode? { selectedTOCNode(for: reader) }
}

import Foundation
// Explicit boundaries only: original legacy initializer is not used.
struct TOC { let bab:String; let level:Int; let sub:Int; let id:Int; let entryId:Int; let parentId:Int? }
extension String { func convertToArabicDigits() -> String { self } }
struct Section { let locator: TextLocator }
@MainActor final class ReaderViewModel {
 let tocViewModel: BookTOCViewModel
 var backendSection: Section?
 var currentContentId: Int
 init(model:BookTOCViewModel,locator:TextLocator,id:Int) {
  tocViewModel=model;backendSection=Section(locator:locator);currentContentId=id
 }
}


struct SQLNode: Decodable {
 let id:Int; let parentId:Int?; let level:Int; let lineIndex:Int; let text:String
}
struct SQLSource: Decodable { let nodes:[SQLNode]; let path:[SQLNode] }
@main struct Controls {
 @MainActor static func main() throws {
  let sql = try JSONDecoder().decode(SQLSource.self,from:Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1])))
  let defaults = UserDefaults(suiteName:"toc-original-source-"+UUID().uuidString)!
  let registry = LegacyIdentityRegistry(defaults:defaults,persistenceDelay:60)
  let rows = Dictionary(uniqueKeysWithValues:sql.nodes.map { ($0.id,$0) })
  var actual:[Int:TOCNode] = [:]
  for row in sql.nodes {
   let locator = TextLocator(backend:.otzaria,workKey:"book:3891",position:.legacyLine(row.lineIndex))
   let node=TOCNode(backendTitle:row.text,level:row.level+1,sub:0,id:registry.id(for:locator),parentId:row.parentId,entryId:row.id)
   node.backendLocator=locator;actual[row.id]=node
  }
  var roots:[TOCNode]=[]
  for row in sql.nodes {
   let node=actual[row.id]!
   if let parent=row.parentId,let actualParent=actual[parent] {actualParent.children.append(node)}
   else {roots.append(node)}
  }
  let model=BookTOCViewModel(nodes:roots)
  let locator=TextLocator(backend:.otzaria,workKey:"book:3891",position:.legacyLine(523))
  let reader=ReaderViewModel(model:model,locator:locator,id:registry.id(for:locator))
  var failed=0,passed=0
  func check(_ name:String,_ value:@autoclosure()->Bool) {
   if value(){passed+=1;print("PASS "+name)}else{failed+=1;print("FAIL "+name)}
  }
  check("exact SQL bootstrap has no TOC heading",model.findNode(for:locator)==nil)
  check("original surrogate one-point ranges have no current-line heading",model.findNode(forContentId:reader.currentContentId)==nil)
  check("unchanged old iPad selector reproduces missing current row",LegacyIPadHost().select(reader)==nil)
  let selected=ActualIPadHost().select(reader)
  check("new iPad original matcher resolves independent SQL entry643037",selected === actual[sql.path.last!.id])
  let path=selected.flatMap { model.pathToNode($0) }
  check("original node object path equals independent SQL ancestry",path?.map(\.entryId)==sql.path.map(\.id))
  check("original selected title equals independent SQL heading",selected?.bab==sql.path.last?.text)
  check("exact heading remains selected",model.findMatchingNode(for:actual[643037]!.backendLocator!) === actual[643037])
  check("another work cannot match this tree",model.findMatchingNode(for:TextLocator(backend:.otzaria,workKey:"book:1",position:.legacyLine(523)))==nil)
  check("position before first heading is unavailable",model.findMatchingNode(for:TextLocator(backend:.otzaria,workKey:"book:3891",position:.legacyLine(-1)))==nil)
  check("next heading uses its original node",sql.nodes.filter{$0.lineIndex>523}.first.map{model.findMatchingNode(for:actual[$0.id]!.backendLocator!) === actual[$0.id]} == true)
  check("selection preserves original Reader locator and surrogate",reader.backendSection?.locator==locator && reader.currentContentId==registry.id(for:locator))
  check("actual registry reverse resolves exact selected heading",selected.map{registry.locator(for:$0.id)==actual[643037]!.backendLocator} == true)
  print("RESULT passed=\(passed) failed=\(failed) nodes=\(rows.count)")
  if failed>0 {exit(1)}
 }
}

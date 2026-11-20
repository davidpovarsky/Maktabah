//
//  BookPageCache.swift
//  maktab
//
//  Created by MacBook on 11/12/25.
//

import Foundation
import OSLog
import Synchronization
#if canImport(UIKit)
import UIKit
#endif

final class BookPageCache: @unchecked Sendable {
    static let shared = BookPageCache()

    // These are retained-payload estimates, not a process RSS limit. NSCache's
    // own cost limit is advisory, so the value-free ledger also enforces the
    // budget after every insertion. NSCache can still purge values at any time.
    private static let payloadBudget = 32 * 1024 * 1024
    private static let bookLimit = 200
    private static let entryLimit = 5000

    private struct BookCost: Sendable {
        var entries: [String: Int] = [:]
        var total = 0
    }

    private struct RetentionBudget: Sendable {
        var books: [Int: BookCost] = [:]
        var oldestFirst: [Int] = []
        var total = 0
        var entryCount = 0

        mutating func forget(_ bookId: Int) {
            if let book = books.removeValue(forKey: bookId) {
                total -= book.total
                entryCount -= book.entries.count
            }
            oldestFirst.removeAll { $0 == bookId }
        }

        mutating func touch(_ bookId: Int) {
            oldestFirst.removeAll { $0 == bookId }
            oldestFirst.append(bookId)
        }

        mutating func record(bookId: Int, entry: String, cost: Int) {
            let previous = books[bookId, default: BookCost()].entries.updateValue(cost, forKey: entry)
            if previous == nil { entryCount += 1 }
            let difference = cost - (previous ?? 0)
            books[bookId, default: BookCost()].total += difference
            total += difference
            touch(bookId)
        }
    }

    private struct State: Sendable {
        var raw = RetentionBudget()
        var processed = RetentionBudget()
    }

    // No ledger retains BookContent or ProcessedArabicContent. A stale ledger
    // after an autonomous NSCache eviction only reduces the usable budget.
    private let cache = NSCache<NSNumber, NSMutableDictionary>()
    private let processedCache = NSCache<NSNumber, NSMutableDictionary>()
    private let lock = Mutex(State())

    private init() {
        cache.countLimit = Self.bookLimit
        cache.totalCostLimit = Self.payloadBudget
        processedCache.countLimit = Self.bookLimit
        processedCache.totalCostLimit = Self.payloadBudget

        #if os(iOS)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.removeAll()
        }
        #endif
    }

    private func processedSubKey(
        contentId: Int,
        key: CleanedTextKey
    ) -> NSString {
        "\(contentId)_\(key.showHarakat)_\(key.isMultiLanguage)_\(key.isImported)_\(key.textHash)" as NSString
    }

    func get(bookId: Int, contentId: Int) -> BookContent? {
        lock.withLock { state in
            guard let pages = cache.object(forKey: bookId as NSNumber) else {
                state.raw.forget(bookId)
                return nil
            }
            let value = pages[String(contentId) as NSString] as? BookContent
            if value != nil { state.raw.touch(bookId) }
            return value
        }
    }

    func set(bookId: Int, content: BookContent) {
        let cost = Self.estimatedCost(content)
        lock.withLock { state in
            Self.store(
                content, bookId: bookId, entry: String(content.id), cost: cost,
                in: cache, budget: &state.raw
            )
        }
    }

    func getProcessed(bookId: Int, contentId: Int, key: CleanedTextKey) -> ProcessedArabicContent? {
        lock.withLock { state in
            guard let pages = processedCache.object(forKey: bookId as NSNumber) else {
                state.processed.forget(bookId)
                return nil
            }
            let subKey = processedSubKey(contentId: contentId, key: key)
            let value = pages[subKey] as? ProcessedArabicContent
            if value != nil { state.processed.touch(bookId) }
            return value
        }
    }

    func setProcessed(bookId: Int, contentId: Int, key: CleanedTextKey, content: ProcessedArabicContent) {
        let cost = Self.estimatedCost(content)
        let subKey = processedSubKey(contentId: contentId, key: key) as String
        lock.withLock { state in
            Self.store(
                content, bookId: bookId, entry: subKey, cost: cost,
                in: processedCache, budget: &state.processed
            )
        }
    }

    private static func store(
        _ value: Any, bookId: Int, entry: String, cost: Int,
        in cache: NSCache<NSNumber, NSMutableDictionary>,
        budget: inout RetentionBudget
    ) {
        let bookKey = bookId as NSNumber
        var pages = cache.object(forKey: bookKey)
        if pages == nil || budget.books[bookId] == nil {
            budget.forget(bookId)
            pages = NSMutableDictionary()
        }

        // Never leave an older value for this identity when a replacement is
        // too large to retain. Eviction affects only this disposable cache.
        guard cost <= payloadBudget else {
            cache.removeObject(forKey: bookKey)
            budget.forget(bookId)
            return
        }

        let previous = budget.books[bookId]?.entries[entry]
        let updatedBookCost = (budget.books[bookId]?.total ?? 0) - (previous ?? 0) + cost
        let updatedBookCount = (budget.books[bookId]?.entries.count ?? 0) + (previous == nil ? 1 : 0)
        if updatedBookCost > payloadBudget || updatedBookCount > entryLimit {
            cache.removeObject(forKey: bookKey)
            budget.forget(bookId)
            pages = NSMutableDictionary()
        }

        budget.record(bookId: bookId, entry: entry, cost: cost)
        while budget.total > payloadBudget
            || budget.entryCount > entryLimit
            || budget.books.count > bookLimit {
            guard let oldest = budget.oldestFirst.first else { break }
            cache.removeObject(forKey: oldest as NSNumber)
            budget.forget(oldest)
        }

        // The newest book fits individually, so the eviction loop retains it.
        guard let retained = budget.books[bookId], let pages else { return }
        pages[entry as NSString] = value
        cache.setObject(pages, forKey: bookKey, cost: retained.total)
    }

    private static func adding(_ lhs: Int, _ rhs: Int) -> Int {
        let result = lhs.addingReportingOverflow(rhs)
        return result.overflow ? Int.max : result.partialValue
    }

    private static func multiplying(_ lhs: Int, _ rhs: Int) -> Int {
        let result = lhs.multipliedReportingOverflow(by: rhs)
        return result.overflow ? Int.max : result.partialValue
    }

    private static func textCost(_ text: String) -> Int {
        // Account for UTF-8 storage plus a possible UTF-16 representation.
        multiplying(text.utf8.count, 3)
    }

    private static func arrayCost<Element>(_ elements: [Element]) -> Int {
        // Include growth allowance; retained Array capacity is not public.
        multiplying(multiplying(elements.count, MemoryLayout<Element>.stride), 2)
    }

    private static func estimatedCost(_ content: BookContent) -> Int {
        var cost = adding(1024, MemoryLayout<BookContent>.stride)
        cost = adding(cost, textCost(content.nash))
        if let reference = content.heRef { cost = adding(cost, textCost(reference)) }
        if let locator = content.backendLocator {
            cost = adding(cost, textCost(locator.workKey))
            if case let .canonicalRef(reference) = locator.position {
                cost = adding(cost, textCost(reference))
            }
        }
        return cost
    }

    private static func estimatedCost(_ content: ProcessedArabicContent) -> Int {
        var cost = adding(1024, textCost(content.sourceText))
        cost = adding(cost, textCost(content.displayText))
        cost = adding(cost, arrayCost(content.coloredRanges))
        cost = adding(cost, arrayCost(content.footnoteRanges))
        cost = adding(cost, arrayCost(content.replacementEvents))
        cost = adding(cost, arrayCost(content.importedHeaderRanges))
        cost = adding(cost, arrayCost(content.ligatureRanges))
        cost = adding(cost, arrayCost(content.harakatEvents))
        cost = adding(cost, arrayCost(content.cleaningEvents))
        return cost
    }

    func remove(bookId: Int) {
        lock.withLock { state in
            cache.removeObject(forKey: bookId as NSNumber)
            processedCache.removeObject(forKey: bookId as NSNumber)
            state.raw.forget(bookId)
            state.processed.forget(bookId)
            Logger.reader.debug("Cache REMOVED all content for bookId: \(bookId)")
        }
    }

    func removeAll() {
        lock.withLock { state in
            cache.removeAllObjects()
            processedCache.removeAllObjects()
            state.raw = RetentionBudget()
            state.processed = RetentionBudget()
        }
    }
}

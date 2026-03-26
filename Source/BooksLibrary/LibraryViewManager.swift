//
//  LibraryViewManager.swift
//  maktab
//
//  Created by MacBook on 03/12/25.
//

import Cocoa

class LibraryViewManager: NSObject {
    static let filterSegmentIndexKey = "LibraryFilterSegmentIndex"

    weak var outlineView: NSOutlineView!
    weak var delegate: LibraryViewDelegate?
    let data: LibraryDataManager = .shared

    var searchView: Bool = false
    var downloadView: Bool = false
    var showOnlyDownloaded: Bool = false

    var checkBoxToggle: (() -> Void)?

    var displayedCategories: [CategoryData] = []
    private var baseCategories: [CategoryData] = []

    weak var searchField: DSFSearchField!

    private var selectedBookName: String?
    private var bookLookup: [String: (category: CategoryData, book: BooksData)] = [:]

    init(outlineView: NSOutlineView,
         searchField: DSFSearchField,
         searchView: Bool = false,
         downloadView: Bool = false
    ) {
        self.outlineView = outlineView
        self.searchView = searchView || downloadView
        self.downloadView = downloadView
        self.searchField = searchField
        super.init()
        self.setupDSFSearchField()
        setupNotificationObservers()
    }

    func prepareData() {
        setBaseCategories(data.allRootCategories, reload: true)
    }

    /// Filter tampilan berdasarkan status download kitab.
    /// - Parameter onlyDownloaded:
    /// `true` = hanya kitab yang sudah didownload,
    /// `false` = semua kitab.
    func applyDownloadFilter(_ onlyDownloaded: Bool) {
        showOnlyDownloaded = onlyDownloaded
        let filtered =
            onlyDownloaded
            ? data.filterIntegrated()
            : data.allRootCategories
        setBaseCategories(filtered, reload: true)
    }

    func applyDownloadFilter(forSegmentIndex index: Int) {
        applyDownloadFilter(index == 1)
    }

    func buildBookLookup() {
        bookLookup.removeAll()

        func traverse(_ category: CategoryData) {
            for child in category.children {
                if let book = child as? BooksData {
                    bookLookup[book.book] = (category, book)
                } else if let subCategory = child as? CategoryData {
                    traverse(subCategory)
                }
            }
        }

        for category in displayedCategories {
            traverse(category)
        }
    }

    func setBaseCategories(_ categories: [CategoryData], reload: Bool) {
        baseCategories = categories
        displayedCategories = categories
        buildBookLookup()
        if reload {
            outlineView.reloadData()
        }
    }

    func setupDSFSearchField() {
        // Di dalam LibraryViewManager atau View Controller Anda:
        searchField.searchTermChangeCallback = { [weak self] query in
            // Panggil fungsi pencarian data yang sebenarnya di sini
            self?.startSearch(query)
        }
    }

    var searchWork: DispatchWorkItem?

    @objc func checkboxToggled(_ sender: NSButton) {
        // Ambil row dari button
        let row = outlineView.row(for: sender)
        guard row != -1, let item = outlineView.item(atRow: row) else { return }

        let newState = (sender.state == .on)

        if let category = item as? CategoryData {
            // Logic: Jika kategori dicentang, centang semua anak-anaknya (Cascade)
            setCategoryChecked(category, state: newState)
            // Reload item ini dan anak-anaknya agar visual update
            outlineView.reloadItem(category, reloadChildren: true)
        } else if let book = item as? BooksData {
            book.isChecked = newState
            ReusableFunc.updateBuiltInRecents(with: book.book, in: searchField)
        }

        checkBoxToggle?()
    }

    // Helper rekursif untuk mencentang category & children
    func setCategoryChecked(_ category: CategoryData, state: Bool) {
        category.isChecked = state
        for child in category.children {
            if let subCat = child as? CategoryData {
                setCategoryChecked(subCat, state: state)
            } else if let book = child as? BooksData {
                book.isChecked = state
            }
        }
    }
}

extension LibraryViewManager: NSOutlineViewDataSource {

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return displayedCategories.count
        }

        if let category = item as? CategoryData {
            return category.children.count
        }

        return 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return displayedCategories[index]
        }

        if let category = item as? CategoryData {
            return category.children[index]
        }

        return ""
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let category = item as? CategoryData {
            return !category.children.isEmpty
        }
        return false
    }
}

// MARK: - NSOutlineViewDelegate
extension LibraryViewManager: NSOutlineViewDelegate {

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let cellIdentifier = NSUserInterfaceItemIdentifier("DataCell")
        let headerIdentifier = NSUserInterfaceItemIdentifier("HeaderCell")

        if let category = item as? CategoryData {
            guard let cell = outlineView.makeView(withIdentifier: headerIdentifier, owner: self) as? NSTableCellView else { return nil }
            cell.textField?.stringValue = category.name
            if searchView,
               let checkbox = cell.subviews.first(where: { $0 is NSButton }) as? NSButton {
                checkbox.state = category.isChecked ? .on : .off
                checkbox.target = self
                checkbox.action = #selector(checkboxToggled(_:))
            }
            return cell
        } else if let book = item as? BooksData {
            guard let cell = outlineView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView else { return nil }
            cell.textField?.stringValue = book.book
            if searchView,
                let checkbox = cell.subviews.first(where: { $0 is NSButton }) as? NSButton {
                checkbox.state = book.isChecked ? .on : .off
                checkbox.target = self
                checkbox.action = #selector(checkboxToggled(_:))
            }
            return cell
        }

        return nil
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard let outlineView = notification.object as? NSOutlineView else {
            return
        }

        let selectedRow = outlineView.selectedRow
        Task {
            await delegate?.didSelectItem(selectedRow)
        }

        if let item = outlineView.item(atRow: selectedRow) as? BooksData {
            ReusableFunc.updateBuiltInRecents(with: item.book, in: searchField)
            selectedBookName = item.book // Simpan nama buku
        }

        if selectedRow == -1 {
            selectedBookName = nil
        }
    }

    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        26
    }
}

extension LibraryViewManager: NSSearchFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let searchField = obj.object as? NSSearchField else { return }
        let query = searchField.stringValue
        startSearch(query)
    }

    func startSearch(_ query: String) {
        searchWork?.cancel()

        let workItem = DispatchWorkItem { [weak self, query] in
            guard let self else { return }
            let base = baseCategories.isEmpty ? displayedCategories : baseCategories
            let foundData = data.filterContent(
                with: query,
                displayedCategories: &displayedCategories,
                baseCategories: base
            )

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                outlineView.reloadData()

                if foundData {
                    outlineView.expandItem(nil, expandChildren: true)
                }

                // Restore seleksi jika query kosong
                if query.isEmpty, let bookName = selectedBookName {
                    self.restoreSelection(byBookName: bookName)
                }
            }
        }

        searchWork = workItem
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

    // Helper function untuk restore seleksi berdasarkan nama buku
    func restoreSelection(byBookName bookName: String) {
        guard let (category, book) = bookLookup[bookName] else { return }

        outlineView.expandItem(category)
        let row = outlineView.row(forItem: book)

        if row >= 0 {
            outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            outlineView.scrollRowToVisible(row)
        }
    }
}

extension LibraryViewManager {

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .booksChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleBooksChanged(notification)
        }

        NotificationCenter.default.addObserver(
            forName: .bookIntegrated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let bookId = notification.object as? Int else { return }
            self?.reloadParentCategory(ofBookId: bookId)
        }
    }

    /// Dipanggil setelah kitab selesai diintegrasikan ke archive.
    /// - `downloadView` (BulkDownloadVC): hapus kitab dari tree karena sudah tidak
    ///   termasuk "belum didownload" lagi.
    /// - Library biasa: reload parent category agar status/icon ter-update.
    private func reloadParentCategory(ofBookId bookId: Int) {
        if !downloadView {
            handleIntegratedBookUpdate(bookId)
            return
        }

        func findParent(in categories: [CategoryData]) -> CategoryData? {
            for category in categories {
                for child in category.children {
                    if let b = child as? BooksData, b.id == bookId { return category }
                    if let sub = child as? CategoryData,
                       let found = findParent(in: [sub]) { return found }
                }
            }
            return nil
        }

        guard let parent = findParent(in: displayedCategories) else { return }

        // Hapus kitab dari children parent — kitab sudah terintegrasi,
        // tidak perlu tampil lagi di daftar "belum didownload".
        parent.children.removeAll { ($0 as? BooksData)?.id == bookId }

        if parent.children.isEmpty {
            // Parent kosong → hapus juga dari displayedCategories
            displayedCategories.removeAll { $0 === parent }
            baseCategories = displayedCategories
            outlineView.reloadData()
        } else {
            outlineView.reloadItem(parent, reloadChildren: true)
        }
    }

    private func handleIntegratedBookUpdate(_ bookId: Int) {
        guard let book = data.booksById[bookId] else { return }

        if !downloadView {
            guard BookArchiveIntegrator.shared.isBookIntegrated(book) else { return }
            insertIntegratedBookIntoDisplayed(book)
            return
        }

        let row = outlineView.row(forItem: book)
        if row >= 0 {
            outlineView.reloadItem(book)
            return
        }

        if let parent = findParentCategory(ofBookId: bookId, in: displayedCategories) {
            outlineView.reloadItem(parent, reloadChildren: true)
        }
    }

    private func handleBooksChanged(_ notification: Notification) {
        guard let payload = notification.object as? BooksChangedNotification else { return }

        // Handle inserted books
        for (categoryId, book) in payload.insertedBooks {
            handleBookInserted(categoryId: categoryId, book: book)
        }

        // Handle updated books
        if !payload.updatedBookIds.isEmpty {
            reloadUpdatedBooks(payload.updatedBookIds)
        }
    }

    private func findParentCategory(ofBookId bookId: Int, in categories: [CategoryData]) -> CategoryData? {
        for category in categories {
            for child in category.children {
                if let b = child as? BooksData, b.id == bookId { return category }
                if let sub = child as? CategoryData,
                   let found = findParentCategory(ofBookId: bookId, in: [sub]) { return found }
            }
        }
        return nil
    }

    private func findPathToBook(bookId: Int, in categories: [CategoryData]) -> [CategoryData]? {
        for category in categories {
            for child in category.children {
                if let b = child as? BooksData, b.id == bookId {
                    return [category]
                }
                if let sub = child as? CategoryData,
                   let path = findPathToBook(bookId: bookId, in: [sub]) {
                    return [category] + path
                }
            }
        }
        return nil
    }

    private func insertBook(
        _ book: BooksData,
        originalCategory: CategoryData,
        targetCategory: CategoryData
    ) {
        if targetCategory.children.contains(where: { ($0 as? BooksData)?.id == book.id }) {
            return
        }

        let originalIndex = originalCategory.children.firstIndex {
            ($0 as? BooksData)?.id == book.id
        } ?? originalCategory.children.count

        let existingBooks = targetCategory.children.compactMap { $0 as? BooksData }
        var insertBookIndex = 0
        for existingBook in existingBooks {
            let existingIndex = originalCategory.children.firstIndex {
                ($0 as? BooksData)?.id == existingBook.id
            } ?? originalCategory.children.count
            if existingIndex > originalIndex {
                break
            }
            insertBookIndex += 1
        }

        let firstBookIndex = targetCategory.children.firstIndex { $0 is BooksData } ?? targetCategory.children.count
        let insertIndex = firstBookIndex + insertBookIndex
        targetCategory.children.insert(book, at: insertIndex)
    }

    private func insertCategory(_ category: CategoryData, into list: inout [CategoryData]) {
        let insertIndex = list.firstIndex { $0.order > category.order } ?? list.count
        list.insert(category, at: insertIndex)
    }

    private func insertCategory(_ category: CategoryData, into children: inout [Any]) {
        let firstBookIndex = children.firstIndex { $0 is BooksData } ?? children.count
        let categoryIndex = children.enumerated().first { _, element in
            guard let existing = element as? CategoryData else { return false }
            return existing.order > category.order
        }?.offset ?? firstBookIndex
        let insertIndex = min(categoryIndex, firstBookIndex)
        children.insert(category, at: insertIndex)
    }

    private func insertIntegratedBookIntoDisplayed(_ book: BooksData) {
        guard let path = findPathToBook(bookId: book.id, in: data.allRootCategories),
              let originalLeaf = path.last
        else { return }

        let rootId = path[0].id
        let rootWasPresent = displayedCategories.contains { $0.id == rootId }

        var currentParent: CategoryData?
        for category in path {
            if let parent = currentParent {
                if let existing = parent.children.compactMap({ $0 as? CategoryData })
                    .first(where: { $0.id == category.id }) {
                    currentParent = existing
                } else {
                    let clone = category.copy() as! CategoryData
                    clone.children = []
                    insertCategory(clone, into: &parent.children)
                    currentParent = clone
                }
            } else {
                if let existing = displayedCategories.first(where: { $0.id == category.id }) {
                    currentParent = existing
                } else {
                    let clone = category.copy() as! CategoryData
                    clone.children = []
                    insertCategory(clone, into: &displayedCategories)
                    currentParent = clone
                }
            }
        }

        guard let leaf = currentParent else { return }
        insertBook(book, originalCategory: originalLeaf, targetCategory: leaf)

        if !rootWasPresent {
            outlineView.reloadData()
        } else if let root = displayedCategories.first(where: { $0.id == rootId }) {
            outlineView.reloadItem(root, reloadChildren: true)
        } else {
            outlineView.reloadData()
        }

        if let bookName = selectedBookName {
            restoreSelection(byBookName: bookName)
        }
    }

    private func handleBookInserted(categoryId: Int, book: BooksData) {
        // Update bookLookup
        if let category = findCategoryInDisplayed(categoryId) {
            bookLookup[book.book] = (category, book)

            if searchField.stringValue.isEmpty {
                // Expand category jika belum
                if !outlineView.isItemExpanded(category) {
                    outlineView.expandItem(category)
                }

                // Reload category dengan children
                outlineView.reloadItem(category, reloadChildren: true)

                // Optional: Scroll ke buku baru dan select
                let row = outlineView.row(forItem: book)
                if row >= 0 {
                    outlineView.scrollRowToVisible(row)
                }
            } else {
                // Re-apply filter
                let currentQuery = searchField.stringValue
                if !currentQuery.isEmpty {
                    let base = baseCategories.isEmpty ? displayedCategories : baseCategories
                    _ = data.filterContent(
                        with: currentQuery,
                        displayedCategories: &displayedCategories,
                        baseCategories: base
                    )
                    outlineView.reloadData()
                }
            }
        }
    }

    private func reloadUpdatedBooks(_ bookIds: Set<Int>) {
        for bookId in bookIds {
            guard let book = data.booksById[bookId] else { continue }

            // Update bookLookup jika nama buku berubah
            for (oldName, value) in bookLookup where value.book.id == bookId {
                bookLookup.removeValue(forKey: oldName)
                bookLookup[book.book] = (value.category, book)
                break
            }

            // Reload item di OutlineView
            let row = outlineView.row(forItem: book)
            if row >= 0 {
                outlineView.reloadItem(book)
            }
        }
    }

    private func findCategoryInDisplayed(_ categoryId: Int) -> CategoryData? {
        func search(_ category: CategoryData) -> CategoryData? {
            if category.id == categoryId {
                return category
            }
            for child in category.children {
                if let subCategory = child as? CategoryData,
                   let found = search(subCategory) {
                    return found
                }
            }
            return nil
        }

        for rootCategory in displayedCategories {
            if let found = search(rootCategory) {
                return found
            }
        }
        return nil
    }
}

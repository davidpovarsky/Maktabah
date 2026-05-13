import SwiftUI

@MainActor
@Observable
class iOSReaderViewModel {
    let book: BooksData
    private let bookConnection = BookConnection()
    static let kfgqpc = Font.custom(ArabicFont.kfgqpcUthmanTahaNaskh.rawValue, size: 16)
    static let kfgqpcTitle = Font.custom(ArabicFont.kfgqpcUthmanTahaNaskh.rawValue, size: 18)

    var contentText: String = ""
    var currentPart: Int?
    var currentPage: Int?
    var currentContentId: Int = 0
    var searchText: String = ""

    var searchViewModel = iOSSearchViewModel()

    var totalParts: Int = 0
    var minPageInPart: Int = 0
    var maxPageInPart: Int = 0

    var statusSubtitle: String {
        if let currentPage {
            let pageArb = String(currentPage).convertToArabicDigits()
            if let currentPart, currentPart != -1 {
                let partArb = String(currentPart).convertToArabicDigits()
                return "ص \(pageArb) ・ ج \(partArb)"
            } else {
                return "ص \(pageArb)"
            }
        } else {
            return "صفحة"
        }
    }

    var tocNodes: [TOCNode] = []
    var currentAnnotations: [Annotation] = []
    
    var state: ReaderState = ReaderState()
    
    var fetchScrollPosition: (() -> CGPoint?)?
    var fetchSelectedRange: (() -> NSRange?)?

    func saveCurrentState() {
        if let scroll = fetchScrollPosition?() {
            state.scrollPosition = scroll
        }
        if let range = fetchSelectedRange?() {
            state.selectedRange = range
        }
    }

    private var diacriticsText: String {
        BookPageCache.shared.get(
            bookId: book.id,
            contentId: currentContentId
        )?.nash ?? ""
    }

    private let annotationCoordinator = AnnotationCoordinator()

    init(book: BooksData) {
        self.book = book
        setupNotificationObservers()
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .annotationDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.loadAnnotations()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .annotationTreeDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.loadAnnotations()
            }
        }
    }

    func loadInitialContent(initialContentId: Int? = nil) {
        do {
            try bookConnection.connect(archive: book.archive)

            if let contentId = initialContentId {
                if let content = bookConnection.getContent(bkid: String(book.id), contentId: contentId, quran: false) {
                    updateContentState(with: content)
                } else {
                    contentText = "Content ID not found."
                }
            } else {
                if let content = bookConnection.getFirstContent(bkid: String(book.id)) {
                    updateContentState(with: content)
                } else {
                    contentText = "No content found for this book."
                }
            }

            // Fetch TOC
            Task {
                let tocEntries = await bookConnection.getTOCEntries(book)
                let nodes = tree(from: tocEntries)
                DispatchQueue.main.async {
                    self.tocNodes = nodes
                }
            }

        } catch {
            contentText = "Error loading book: \(error.localizedDescription)"
        }
    }

    func fetchContent(part: Int, page: Int) {
        if let content = bookConnection.getContent(bkid: String(book.id), part: part, page: page) {
            updateContentState(with: content)
        }
    }

    func fetchContentById(_ contentId: Int) {
        if let content = bookConnection.getContent(bkid: String(book.id), contentId: contentId, quran: false) {
            DispatchQueue.main.async {
                self.updateContentState(with: content)
            }
        }
    }

    func goToNextPage() {
        if let content = bookConnection.getNextPage(from: book, contentId: currentContentId, quran: false) {
            updateContentState(with: content)
        }
    }

    func goToPrevPage() {
        if let content = bookConnection.getPrevPage(from: book, contentId: currentContentId, quran: false) {
            updateContentState(with: content)
        }
    }

    private func updateContentState(with content: BookContent) {
        contentText = content.nash
        currentPart = content.part
        currentPage = content.page
        currentContentId = content.id
        iOSHistoryViewModel.shared.updateLastContentId(content.id, for: book.id)
        
        // Sync to state
        state.currentBook = book
        state.currentID = content.id
        state.currentPart = content.part
        state.currentPage = content.page
        
        loadAnnotations()
        updateNavigationLimits()
    }

    func updateNavigationLimits() {
        guard let part = currentPart else { return }
        let bkid = String(book.id)

        Task { [weak self] in
            guard let self else { return }
            let total = await Task.detached(priority: .userInitiated) {
                await self.bookConnection.getTotalParts(bkid: bkid)
            }.value

            let juz = part < 1 ? 1 : part
            let limits = await Task.detached(priority: .userInitiated) {
                let minPg = await self.bookConnection.getMinPagesInPart(bkid: bkid, part: juz)
                let maxPg = await self.bookConnection.getPagesInPart(bkid: bkid, part: juz)
                return (minPg, maxPg)
            }.value

            await MainActor.run {
                self.totalParts = total
                self.minPageInPart = limits.0
                self.maxPageInPart = limits.1
            }
        }
    }

    func jumpToPart(_ part: Int) {
        let bkid = String(book.id)
        Task { [weak self] in
            guard let self else { return }
            let result = await Task.detached(priority: .userInitiated) {
                let minPage = await self.bookConnection.getMinPagesInPart(bkid: bkid, part: part)
                return await self.bookConnection.getContent(bkid: bkid, part: part, page: minPage)
            }.value

            if let content = result {
                updateContentState(with: content)
            }
        }
    }

    func jumpToPage(_ page: Int) {
        let bkid = String(book.id)
        let part = currentPart ?? -1 <= 1 ? 1 : currentPart!
        Task { [weak self] in
            guard let self else { return }
            let result = await Task.detached(priority: .userInitiated) {
                await self.bookConnection.getContent(bkid: bkid, part: part, page: page)
            }.value

            if let content = result {
                updateContentState(with: content)
            }
        }
    }

    // MARK: - Annotations Methods

    func loadAnnotations() {
        currentAnnotations = AnnotationManager.shared
            .loadAnnotations(
                bkId: book.id,
                contentId: currentContentId
            )
    }

    func addAnnotation(
        in range: NSRange,
        mode: AnnotationMode,
        sourceText: String,
        color: UIColor
    ) {
        do {
            _ = try annotationCoordinator.saveHighlight(
                text: sourceText,
                range: range,
                color: color,
                bkId: book.id,
                contentId: currentContentId,
                page: currentPage ?? 0,
                part: currentPart ?? 0,
                diacriticsText: diacriticsText,
                showHarakat: TextViewState.shared.showHarakat,
                mode: mode
            )
            loadAnnotations()
            triggerHapticFeedback(.success)
        } catch {
            print("Failed to save annotation: \(error)")
            triggerHapticFeedback(.error)
        }
    }

    func deleteAnnotation(id: Int64) {
        do {
            try AnnotationManager.shared.deleteAnnotation(id: id)
            loadAnnotations()
            triggerHapticFeedback(.warning)
        } catch {
            print("Failed to delete annotation: \(error.localizedDescription)")
            triggerHapticFeedback(.error)
        }
    }

    func updateAnnotation(_ annotation: Annotation) {
        do {
            try AnnotationManager.shared.updateAnnotation(annotation)
            loadAnnotations()
            triggerHapticFeedback(.success)
        } catch {
            print("Failed to update annotation: \(error.localizedDescription)")
            triggerHapticFeedback(.error)
        }
    }

    private enum HapticType {
        case success, error, warning
    }

    private func triggerHapticFeedback(_ type: HapticType) {
        let generator = UINotificationFeedbackGenerator()
        switch type {
        case .success:
            generator.notificationOccurred(.success)
        case .error:
            generator.notificationOccurred(.error)
        case .warning:
            generator.notificationOccurred(.warning)
        }
    }

    /// Adapted from AppKit's tree building logic
    private func tree(from toc: [TOC]) -> [TOCNode] {
        var rootNodes = [TOCNode]()
        var nodeStack = [TOCNode]()
        var allNodes = [TOCNode]()

        for item in toc {
            let newNode = TOCNode(from: item)
            allNodes.append(newNode)

            while let last = nodeStack.last, last.level >= newNode.level {
                nodeStack.removeLast()
            }

            if let parent = nodeStack.last {
                parent.children.append(newNode)
            } else {
                rootNodes.append(newNode)
            }
            nodeStack.append(newNode)
        }

        for (i, node) in allNodes.enumerated() {
            if i < allNodes.count - 1 {
                node.endID = allNodes[i + 1].id - 1
            } else {
                node.endID = Int.max
            }
        }

        return rootNodes
    }

    func findNodeId(forContentId contentId: Int) -> Int? {
        func flatten(_ nodes: [TOCNode]) -> [TOCNode] {
            var flat = [TOCNode]()
            for node in nodes {
                flat.append(node)
                flat.append(contentsOf: flatten(node.children))
            }
            return flat
        }

        let allNodes = flatten(tocNodes)
        let matches = allNodes.filter { contentId >= $0.id && contentId <= $0.endID }
        return matches.min(by: { ($0.endID - $0.id) < ($1.endID - $1.id) })?.id
    }
}

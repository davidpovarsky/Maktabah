import SwiftUI
import UIKit

/// A customized UITextView designed specifically for Arabic text and annotations, mirroring AppKit's IbarotTextView behavior.
class iOSCustomIbarotTextView: UITextView {
    var onHighlight: ((NSRange, String) -> Void)?
    var onUnderline: ((NSRange, String) -> Void)?

    var currentRenderResult: ArabicRenderResult?

    private struct ViewportAnchor {
        let sourceCharacterIndex: Int
        let verticalOffset: CGFloat
    }

    private var pendingViewportAnchor: ViewportAnchor?

    override var bounds: CGRect {
        willSet {
            guard bounds.width > 0,
                  abs(newValue.width - bounds.width) > 0.5,
                  !isDragging,
                  !isDecelerating else { return }
            pendingViewportAnchor = captureViewportAnchor()
        }
    }

    let state = TextViewState.shared

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        isEditable = false
        isSelectable = true
        textAlignment = .natural
        semanticContentAttribute = .unspecified
        backgroundColor = .clear

        // Disable scrolling if we want SwiftUI ScrollView to handle it,
        // or enable it if this textView takes the whole screen.
        isScrollEnabled = true
        contentInsetAdjustmentBehavior = .always
        textContainerInset = UIEdgeInsets(
            top: 10, left: 10, bottom: 10, right: 10
        )
        linkTextAttributes = [:]

        // Font setup defaults
        font = state.currentFont
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        restorePendingViewportAnchor()
        if pendingRestoreOffset != nil {
            applyPendingScrollRestore()
        }
    }

    private func captureViewportAnchor() -> ViewportAnchor? {
        guard textStorage.length > 0 else { return nil }
        layoutManager.ensureLayout(for: textContainer)

        let point = CGPoint(
            x: textContainerInset.left + textContainer.lineFragmentPadding + 1,
            y: contentOffset.y + adjustedContentInset.top + 1
        )
        let containerPoint = CGPoint(
            x: point.x - textContainerInset.left,
            y: point.y - textContainerInset.top
        )
        let glyphIndex = min(
            layoutManager.glyphIndex(for: containerPoint, in: textContainer),
            max(0, layoutManager.numberOfGlyphs - 1)
        )
        let characterIndex = min(
            layoutManager.characterIndexForGlyph(at: glyphIndex),
            max(0, textStorage.length - 1)
        )
        let glyphRect = layoutManager.boundingRect(
            forGlyphRange: NSRange(location: glyphIndex, length: 1),
            in: textContainer
        )
        let verticalOffset = glyphRect.minY + textContainerInset.top - contentOffset.y
        let sourceIndex = currentRenderResult?
            .sourceCharacterIndex(forDisplayedIndex: characterIndex) ?? characterIndex
        return ViewportAnchor(sourceCharacterIndex: sourceIndex, verticalOffset: verticalOffset)
    }

    private func restorePendingViewportAnchor() {
        guard let anchor = pendingViewportAnchor, textStorage.length > 0 else { return }
        pendingViewportAnchor = nil
        layoutManager.ensureLayout(for: textContainer)

        let displayedRange = currentRenderResult?.displayedRange(
            forSourceRange: NSRange(location: anchor.sourceCharacterIndex, length: 1)
        ) ?? NSRange(location: anchor.sourceCharacterIndex, length: 1)
        guard displayedRange.location != NSNotFound,
              displayedRange.location < textStorage.length else { return }

        let glyphRange = layoutManager.glyphRange(
            forCharacterRange: NSRange(location: displayedRange.location, length: 1),
            actualCharacterRange: nil
        )
        guard glyphRange.location < layoutManager.numberOfGlyphs else { return }
        let glyphRect = layoutManager.boundingRect(
            forGlyphRange: NSRange(location: glyphRange.location, length: 1),
            in: textContainer
        )
        let proposedY = glyphRect.minY + textContainerInset.top - anchor.verticalOffset
        let minimumY = -adjustedContentInset.top
        let maximumY = max(
            minimumY,
            contentSize.height - bounds.height + adjustedContentInset.bottom
        )
        setContentOffset(
            CGPoint(x: contentOffset.x, y: min(max(proposedY, minimumY), maximumY)),
            animated: false
        )
        updateViewportAccessibilityMetadata()
    }

    func updateViewportAccessibilityMetadata() {
        #if DEBUG
        guard let anchor = captureViewportAnchor() else { return }
        accessibilityHint = "source=\(anchor.sourceCharacterIndex);offset=\(anchor.verticalOffset);object=\(ObjectIdentifier(self).hashValue)"
        writeAcceptanceViewportReport(anchor)
        #endif
    }

    #if DEBUG
    private func writeAcceptanceViewportReport(_ anchor: ViewportAnchor) {
        guard let readyPath = ProcessInfo.processInfo.environment["MAKTABAH_SMOKE_READY_FILE"],
              !readyPath.isEmpty else { return }
        let report: [String: Any] = [
            "source": anchor.sourceCharacterIndex,
            "offset": Double(anchor.verticalOffset),
            "object": ObjectIdentifier(self).hashValue,
            "capturedAt": Date().timeIntervalSince1970,
        ]
        do {
            let data = try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys])
            try data.write(to: URL(fileURLWithPath: readyPath + ".viewport.json"), options: .atomic)
        } catch {
            assertionFailure("Could not write viewport acceptance report: \(error)")
        }
    }
    #endif

    // MARK: - Actions for UIMenuController (Pre-iOS 16)

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(highlightSelection) || action == #selector(underlineSelection) {
            return selectedRange.length > 0
        }
        return super.canPerformAction(action, withSender: sender)
    }

    @objc func highlightSelection() {
        guard selectedRange.length > 0 else { return }
        let sourceRange = currentRenderResult?.remapSourceRange(selectedRange) ?? selectedRange
        let sourceText = currentRenderResult?.sourceText ?? text ?? ""
        onHighlight?(sourceRange, sourceText)
    }

    @objc func underlineSelection() {
        guard selectedRange.length > 0 else { return }
        let sourceRange = currentRenderResult?.remapSourceRange(selectedRange) ?? selectedRange
        let sourceText = currentRenderResult?.sourceText ?? text ?? ""
        onUnderline?(sourceRange, sourceText)
    }

    var pendingRestoreOffset: CGFloat?
    var isRestoringScroll: Bool = false



    @MainActor
    func applyPendingScrollRestore() {
        guard let targetDocY = pendingRestoreOffset, bounds.height > 0 else { return }
        pendingRestoreOffset = nil
        isRestoringScroll = true

        let effectiveTopInset = max(adjustedContentInset.top, safeAreaInsets.top)
        if targetDocY <= 0 {
            let topOffset = CGPoint(x: 0, y: -effectiveTopInset)
            setContentOffset(topOffset, animated: false)
            isRestoringScroll = false
            return
        }

        if let tlm = textLayoutManager {
            let viewportHeight = max(bounds.height, 400)
            let targetLayoutY = targetDocY + viewportHeight
            tlm.enumerateTextLayoutFragments(
                from: tlm.documentRange.location,
                options: [.ensuresLayout]
            ) { fragment in
                fragment.layoutFragmentFrame.maxY < targetLayoutY
            }

            let laidOutHeight = tlm.usageBoundsForTextContainer.height + textContainerInset.top + textContainerInset.bottom
            if laidOutHeight > contentSize.height {
                contentSize = CGSize(width: bounds.width, height: laidOutHeight)
            }
        }

        let targetOffsetY = targetDocY - effectiveTopInset
        setContentOffset(CGPoint(x: 0, y: targetOffsetY), animated: false)
        textLayoutManager?.textViewportLayoutController.layoutViewport()

        DispatchQueue.main.async { [weak self] in
            self?.isRestoringScroll = false
        }
    }

    @MainActor
    func highlighAndScrollToAnns(_ ann: Annotation) async {
        let range = displayedRange(for: ann)
        guard range.location >= 0, range.length > 0 else { return }
        textLayoutManager?.ensureLayout(for: range)
        scrollRangeToVisible(range)
        await popupText(for: [range])
    }

    @MainActor
    func popupText(for ranges: [NSRange]) async {
        textLayoutManager?.ensureLayout(for: ranges)

        try? await Task.sleep(for: .seconds(0.15))
        guard !Task.isCancelled else { return }

        let nsString = textStorage.string as NSString
        guard let firstRange = ranges.first,
              firstRange.location >= 0,
              firstRange.length > 0,
              firstRange.location + firstRange.length <= nsString.length else { return }

        let path = calculateHighlightPath(for: ranges)
        let totalRect = path.bounds
        guard !totalRect.isNull, totalRect.width > 0, totalRect.height > 0 else { return }

        let containerView = UIView(frame: totalRect)
        containerView.alpha = 0
        containerView.transform = CGAffineTransform(scaleX: 1.35, y: 1.4)

        let bgLayer = CAShapeLayer()
        let shiftedPath = UIBezierPath(cgPath: path.cgPath)
        shiftedPath.apply(CGAffineTransform(translationX: -totalRect.minX, y: -totalRect.minY))
        bgLayer.path = shiftedPath.cgPath
        bgLayer.fillColor = UIColor.systemYellow.cgColor
        containerView.layer.addSublayer(bgLayer)

        let textOverlay = createOverlayTextView(for: ranges, totalRect: totalRect)
        containerView.addSubview(textOverlay)
        addSubview(containerView)

        UIView.animate(
            withDuration: 0.25, delay: 0,
            usingSpringWithDamping: 0.45, initialSpringVelocity: 1.2,
            options: [],
            animations: {
                containerView.alpha = 1
                containerView.transform = .identity
            }
        ) { _ in
            UIView.animate(
                withDuration: 0.25, delay: 0,
                options: .curveEaseIn,
                animations: {
                    containerView.alpha = 0
                    containerView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
                }
            ) { _ in
                containerView.removeFromSuperview()
            }
        }
    }

    private func calculateHighlightPath(
        for ranges: [NSRange],
        in targetView: UITextView? = nil
    ) -> UIBezierPath {
        let tv = targetView ?? self
        let path = UIBezierPath()
        for range in ranges {
            guard let startPos = tv.position(from: tv.beginningOfDocument, offset: range.location),
                  let endPos = tv.position(from: startPos, offset: range.length),
                  let textRange = tv.textRange(from: startPos, to: endPos) else { continue }

            let rects = tv.selectionRects(for: textRange)
            for selectionRect in rects {
                let rect = selectionRect.rect
                guard rect.width > 0, rect.height > 0 else { continue }
                path.append(UIBezierPath(rect: rect.insetBy(dx: -2, dy: -2)))
            }
        }
        return path
    }

    private func createOverlayTextView(for ranges: [NSRange], totalRect: CGRect) -> UITextView {
        let fullText = textStorage.string as NSString
        let validRanges = ranges.filter {
            $0.location >= 0 && $0.length > 0 && $0.location + $0.length <= fullText.length
        }
        guard let first = validRanges.first else { return UITextView() }

        // 1. Ambil batas paragraf penuh yang menaungi ranges agar word-wrap & RTL identik
        let combinedRange = validRanges.dropFirst().reduce(first) { NSUnionRange($0, $1) }
        let paragraphRange = fullText.paragraphRange(for: combinedRange)

        // 2. Salin hanya attributed string untuk paragraf tersebut
        let attrText = NSMutableAttributedString(
            attributedString: textStorage.attributedSubstring(from: paragraphRange)
        )
        let fullRangeLocal = NSRange(location: 0, length: attrText.length)

        attrText.addAttribute(.foregroundColor, value: UIColor.clear, range: fullRangeLocal)
        attrText.removeAttribute(.link, range: fullRangeLocal)
        attrText.removeAttribute(.backgroundColor, range: fullRangeLocal)
        attrText.removeAttribute(.underlineStyle, range: fullRangeLocal)
        attrText.removeAttribute(.underlineColor, range: fullRangeLocal)

        let localRanges: [NSRange] = validRanges.map {
            NSRange(location: $0.location - paragraphRange.location, length: $0.length)
        }
        for rng in localRanges {
            guard rng.location >= 0, rng.location + rng.length <= attrText.length else { continue }
            attrText.addAttribute(.foregroundColor, value: UIColor.black, range: rng)
        }

        // 3. Konfigurasi properti UITextView SEBELUM mengisi attributedText
        // agar UIKit tidak menimpa NSParagraphStyle (lineHeight).
        let textOverlay = UITextView(
            frame: CGRect(x: 0, y: 0, width: bounds.width, height: max(bounds.height, totalRect.height * 2))
        )
        textOverlay.backgroundColor = .clear
        textOverlay.isScrollEnabled = false
        textOverlay.isEditable = false
        textOverlay.isSelectable = false
        textOverlay.textAlignment = textAlignment
        textOverlay.semanticContentAttribute = semanticContentAttribute
        textOverlay.textContainerInset = textContainerInset
        textOverlay.textContainer.lineFragmentPadding = textContainer.lineFragmentPadding
        textOverlay.clipsToBounds = false

        textOverlay.attributedText = attrText

        // 4. Pastikan TextKit 2 merampungkan layout untuk paragraf ini
        let fitSize = textOverlay.sizeThatFits(
            CGSize(width: bounds.width, height: .greatestFiniteMagnitude)
        )
        textOverlay.frame.size = CGSize(width: bounds.width, height: max(fitSize.height, totalRect.height))
        textOverlay.textLayoutManager?.ensureLayout(for: localRanges)
        textOverlay.layoutIfNeeded()

        // 5. Anchor langsung menggunakan koordinat selectionRects di dalam textOverlay sendiri
        let overlayRect = calculateHighlightPath(for: localRanges, in: textOverlay).bounds
        if !overlayRect.isNull, overlayRect.width > 0, overlayRect.height > 0 {
            textOverlay.frame.origin = CGPoint(x: -overlayRect.minX, y: -overlayRect.minY)
        } else {
            textOverlay.frame.origin = CGPoint(x: -totalRect.minX, y: -totalRect.minY)
        }

        return textOverlay
    }

    func displayedRange(for annotation: Annotation) -> NSRange {
        let state = TextViewState.shared
        let range = state.showHarakat ? annotation.rangeDiacritics : annotation.range
        return displayedRange(forStoredRange: range)
    }

    private func displayedRange(forStoredRange range: NSRange) -> NSRange {
        currentRenderResult?.displayedRange(forSourceRange: range) ?? range
    }
}

// MARK: - Pull Navigation Indicator

enum PullDirection {
    case prev, next
}

class PullNavigationIndicatorView: UIView {
    private let chevronView = UIImageView()
    private let label = UILabel()
    private let stackView = UIStackView()
    private let direction: PullDirection

    init(direction: PullDirection) {
        self.direction = direction
        super.init(frame: .zero)
        setupView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        let symbolName = direction == .prev ? "chevron.compact.up" : "chevron.compact.down"
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        chevronView.image = UIImage(systemName: symbolName, withConfiguration: config)
        chevronView.tintColor = .secondaryLabel
        chevronView.contentMode = .scaleAspectFit

        label.text = direction == .prev
            ? String(localized: "Previous Page")
            : String(localized: "Next Page")
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        label.textAlignment = .center

        if direction == .prev {
            stackView.addArrangedSubview(chevronView)
            stackView.addArrangedSubview(label)
        } else {
            stackView.addArrangedSubview(label)
            stackView.addArrangedSubview(chevronView)
        }
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 2
        stackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        alpha = 0
    }

    func updateProgress(_ progress: CGFloat) {
        let clamped = min(max(progress, 0), 1)
        alpha = clamped
        let scale = 0.8 + 0.2 * clamped
        transform = CGAffineTransform(scaleX: scale, y: scale)

        if clamped >= 1.0 {
            chevronView.tintColor = .label
            label.textColor = .label
        } else {
            chevronView.tintColor = .secondaryLabel
            label.textColor = .secondaryLabel
        }
    }

    func reset() {
        UIView.animate(withDuration: 0.2) {
            self.alpha = 0
            self.transform = .identity
        }
    }
}

enum ReaderTextIndexMapper {
    static func sourceCharacterIndex(
        forDisplayedIndex displayedIndex: Int,
        sourceText: String,
        showHarakat: Bool
    ) -> Int {
        guard !showHarakat else { return displayedIndex }
        var displayedOffset = 0
        var sourceOffset = 0
        for scalar in sourceText.unicodeScalars {
            let scalarLength = String(scalar).utf16.count
            if scalar.isArabicHarakat {
                sourceOffset += scalarLength
                continue
            }
            if displayedOffset >= displayedIndex { return sourceOffset }
            displayedOffset += scalarLength
            sourceOffset += scalarLength
        }
        return sourceOffset
    }

    static func displayedRange(
        forSourceRange range: NSRange,
        sourceText: String,
        showHarakat: Bool
    ) -> NSRange {
        guard !showHarakat else { return range }
        let nsText = sourceText as NSString
        let boundedStart = min(max(0, range.location), nsText.length)
        let boundedEnd = min(max(boundedStart, NSMaxRange(range)), nsText.length)
        let prefixLength = (nsText.substring(to: boundedStart).removingHarakat() as NSString).length
        let endLength = (nsText.substring(to: boundedEnd).removingHarakat() as NSString).length
        return NSRange(location: prefixLength, length: endLength - prefixLength)
    }
}

fileprivate struct RenderSignature: Hashable {
    let contentID: Int
    let textHash: Int
    let textLength: Int
    let showHarakat: Bool
    let isMultiLanguage: Bool
    let isImported: Bool
    let fontName: String
    let fontSize: CGFloat
    let lineHeight: Double
}

fileprivate struct AnnotationRenderSignature: Hashable {
    let id: Int64?
    let range: NSRange
    let diacriticsRange: NSRange
    let colorHex: String
    let type: Int
}

fileprivate struct DecorationSignature: Hashable {
    let renderSignature: RenderSignature
    let annotations: [AnnotationRenderSignature]
    let searchText: String
    let searchMode: String
    let nearDistance: Int
    let clickableAnnotations: Bool
    let highlightTerms: [String]?
    let selectedSegmentRange: NSRange?
}

/// SwiftUI Wrapper for iOSCustomIbarotTextView
struct iOSIbarotTextView: UIViewRepresentable {
    @Binding var text: String
    var annotations: [Annotation] = []
    var searchEvent: ReaderHighlightEvent? = nil
    var annotationEvent: ReaderAnnotationEvent? = nil
    var targetAnnotation: Annotation? = nil
    var selectedSegmentRange: NSRange? = nil
    var isMultiLanguage: Bool = false
    var isImported: Bool = false
    var enhancedUnderline: Bool = false

    var viewModel: ReaderViewModel

    // Callbacks for the ViewModel to handle menu actions
    var onAddAnnotation: ((NSRange, AnnotationMode, String, UIColor) -> Void)?
    var onTapAnnotation: ((Int64) -> Void)?
    var onTapTextCharacterIndex: ((Int) -> Void)?
    var onManualScrollAwayFromSearchResult: (() -> Void)? = nil

    // Pull-to-navigate callbacks
    var onNavigateNext: (() -> Void)?
    var onNavigatePrev: (() -> Void)?

    var state = TextViewState.shared

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.clipsToBounds = true

        let textView = iOSCustomIbarotTextView()
        textView.accessibilityIdentifier = "reader-text"
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.delegate = context.coordinator
        textView.alwaysBounceVertical = true
        let tapRecognizer = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTextTap(_:)))
        tapRecognizer.cancelsTouchesInView = false
        tapRecognizer.delaysTouchesBegan = false
        tapRecognizer.delaysTouchesEnded = false
        tapRecognizer.delegate = context.coordinator
        textView.addGestureRecognizer(tapRecognizer)
        for recognizer in textView.gestureRecognizers ?? [] {
            guard recognizer !== tapRecognizer else { continue }
            if recognizer is UILongPressGestureRecognizer {
                tapRecognizer.require(toFail: recognizer)
            }
        }

        setupClosure(for: textView, context: context)

        container.addSubview(textView)

        // Pull navigation indicators
        let topIndicator = PullNavigationIndicatorView(direction: .prev)
        topIndicator.translatesAutoresizingMaskIntoConstraints = false
        topIndicator.tag = 1001
        container.addSubview(topIndicator)

        let bottomIndicator = PullNavigationIndicatorView(direction: .next)
        bottomIndicator.translatesAutoresizingMaskIntoConstraints = false
        bottomIndicator.tag = 1002
        container.addSubview(bottomIndicator)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: container.topAnchor),
            textView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            topIndicator.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            topIndicator.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor, constant: 8),
            topIndicator.heightAnchor.constraint(equalToConstant: 44),

            bottomIndicator.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            bottomIndicator.bottomAnchor.constraint(equalTo: container.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            bottomIndicator.heightAnchor.constraint(equalToConstant: 44),
        ])

        context.coordinator.topIndicator = topIndicator
        context.coordinator.bottomIndicator = bottomIndicator

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let textView = uiView.subviews.first as? iOSCustomIbarotTextView else { return }

        context.coordinator.parent = self
        updateTextAlignmentAndSemantics(for: textView)
        setupViewModelClosure(for: textView, context: context)

        if context.coordinator.lastBackgroundColorIndex != state.backgroundColorIndex {
            context.coordinator.lastBackgroundColorIndex = state.backgroundColorIndex
            if let tlm = textView.textLayoutManager {
                tlm.invalidateLayout(for: tlm.documentRange)
                textView.setNeedsDisplay()
            }
        }

        let rendered = resolveRenderedContent(textView: textView, context: context)

        if let pendingTarget = viewModel.consumePendingReaderScrollTarget() {
            switch pendingTarget {
            case .top:
                scrollTextViewToTop(textView)
            case .bottom:
                scrollTextViewToBottom(textView)
                let expectedContentId = viewModel.currentContentId
                DispatchQueue.main.async { [weak textView, weak viewModel] in
                    guard let textView, let viewModel, viewModel.currentContentId == expectedContentId else { return }
                    self.scrollTextViewToBottom(textView)
                }
            }
            viewModel.needsScrollRestore = false
            context.coordinator.restoredContentId = viewModel.currentContentId
        } else {
            restoreScrollAndSelectionIfNeeded(textView: textView, context: context)
        }

        handleTargetAnnotationAndSearchHighlight(
            textView: textView,
            context: context,
            searchRanges: rendered.searchRanges
        )
    }

    private func setupClosure(for textView: iOSCustomIbarotTextView, context: Context) {
        textView.onHighlight = { sourceRange, sourceText in
            let color = UserDefaults.standard.recentHighlightColors.first ?? .yellow
            onAddAnnotation?(sourceRange, .highlight, sourceText, color)
        }
        textView.onUnderline = { sourceRange, sourceText in
            let color = UserDefaults.standard.recentUnderlineColors.first ?? .label
            onAddAnnotation?(sourceRange, .underline, sourceText, color)
        }

        setupViewModelClosure(for: textView, context: context)
    }

    private func setupViewModelClosure(for textView: iOSCustomIbarotTextView, context: Context) {
        viewModel.fetchScrollPosition = { [weak textView, weak coordinator = context.coordinator] in
            guard let textView,
                  textView.window != nil,
                  !textView.isRestoringScroll,
                  textView.bounds.height > 0
            else {
                return coordinator?.lastKnownScrollPosition
            }

            let effectiveTopInset = max(textView.adjustedContentInset.top, textView.safeAreaInsets.top)
            let liveDocY = max(0, textView.contentOffset.y + effectiveTopInset)

            if liveDocY <= 0, let cached = coordinator?.lastKnownScrollPosition, cached.y > 0 {
                return cached
            }

            let pos = CGPoint(x: 0, y: liveDocY)
            coordinator?.lastKnownScrollPosition = pos
            return pos
        }
        viewModel.fetchSelectedRange = { [weak textView] in
            textView?.selectedRange
        }
    }

    private func resolveRenderedContent(
        textView: iOSCustomIbarotTextView,
        context: Context
    ) -> RenderedAttributedContent {
        let isSearchEventForThisContent = searchEvent != nil && searchEvent?.contentId == viewModel.currentContentId
        let activeSearchEventId = isSearchEventForThisContent ? searchEvent?.id : nil

        let currentKey = RenderCacheKey(
            bookId: viewModel.currentBook?.id,
            contentId: viewModel.currentContentId,
            text: text,
            annotations: annotations,
            searchEventId: activeSearchEventId,
            selectedSegmentRange: selectedSegmentRange,
            highlightTerms: viewModel.highlightTerms,
            showHarakat: state.showHarakat,
            clickableAnnotation: state.clickableAnnotation,
            enhancedUnderline: enhancedUnderline,
            isMultiLanguage: isMultiLanguage,
            isImported: isImported,
            fontName: state.fontName,
            fontSize: state.fontSize,
            lineHeight: state.lineHeight
        )

        if let lastKey = context.coordinator.lastRenderKey, lastKey == currentKey,
           let cached = context.coordinator.lastRenderedContent
        {
            return cached
        }

        let newlyRendered = renderAttributedContent(
            textView: textView,
            context: context,
            isSearchEventForThisContent: isSearchEventForThisContent
        )
        context.coordinator.lastRenderKey = currentKey
        context.coordinator.lastRenderedContent = newlyRendered

        textView.attributedText = newlyRendered.attributedString
        textView.invalidateIntrinsicContentSize()
        textView.setNeedsLayout()
        textView.layoutIfNeeded()
        return newlyRendered
    }

    private func updateTextAlignmentAndSemantics(for textView: iOSCustomIbarotTextView) {
        let targetAlignment: NSTextAlignment = isMultiLanguage ? .natural : .right
        if textView.textAlignment != targetAlignment {
            textView.textAlignment = targetAlignment
        }

        let targetSemantic: UISemanticContentAttribute = isMultiLanguage ? .unspecified : .forceRightToLeft
        if textView.semanticContentAttribute != targetSemantic {
            textView.semanticContentAttribute = targetSemantic
        }
    }

    struct RenderCacheKey: Equatable {
        let bookId: Int?
        let contentId: Int
        let text: String
        let annotations: [Annotation]
        let searchEventId: UUID?
        let selectedSegmentRange: NSRange?
        let highlightTerms: [String]?
        let showHarakat: Bool
        let clickableAnnotation: Bool
        let enhancedUnderline: Bool
        let isMultiLanguage: Bool
        let isImported: Bool
        let fontName: String
        let fontSize: CGFloat
        let lineHeight: Double
    }

    struct RenderedAttributedContent {
        let attributedString: NSMutableAttributedString
        let searchRanges: [NSRange]
    }

    private func renderAttributedContent(
        textView: iOSCustomIbarotTextView,
        context: Context,
        isSearchEventForThisContent: Bool
    ) -> RenderedAttributedContent {
        let renderer = ArabicTextRenderer()
        let renderResult = renderer.render(
            bookId: viewModel.currentBook?.id,
            contentId: viewModel.currentContentId,
            text: text,
            highlightColor: UIColor.header,
            showHarakat: state.showHarakat,
            isMultiLanguage: isMultiLanguage,
            isImported: isImported
        )

        textView.currentRenderResult = renderResult
        context.coordinator.currentRenderResult = renderResult

        let attributedString = NSMutableAttributedString(attributedString: renderResult.attributedString)
        renderer.applyAnnotations(
            annotations,
            to: attributedString,
            showHarakat: state.showHarakat,
            replacementEvents: renderResult.replacementEvents,
            harakatEvents: renderResult.harakatEvents,
            cleaningEvents: renderResult.cleaningEvents
        )

        if state.clickableAnnotation {
            applyClickableAnnotationLinks(to: attributedString)
        }

        var searchRanges: [NSRange] = []

        if isSearchEventForThisContent, let event = searchEvent, !event.query.isEmpty {
            if event.isTOC {
                if let range = attributedString.string.findTOCMatchingRange(title: event.query) {
                    searchRanges = [range]
                }
            } else {
                searchRanges = attributedString.highlightSearchText(
                    searchText: event.query,
                    mode: event.mode,
                    baseColor: .highlightText,
                    nearDistance: event.nearDistance
                )
            }
        } else if let highlightTerms = viewModel.highlightTerms, !highlightTerms.isEmpty {
            searchRanges = attributedString.highlightSearchText(
                searchText: "",
                mode: nil,
                baseColor: .highlightText,
                nearDistance: 10,
                highlightTerms: highlightTerms
            )
        }

        if let selectedSegmentRange {
            let displayedSelected = renderResult.displayedRange(forSourceRange: selectedSegmentRange)
            if displayedSelected.location != NSNotFound,
               displayedSelected.location >= 0,
               displayedSelected.length > 0,
               displayedSelected.location + displayedSelected.length <= attributedString.length {
                attributedString.addAttribute(
                    .backgroundColor,
                    value: UIColor.systemBlue.withAlphaComponent(0.14),
                    range: displayedSelected
                )
            }
        }

        return RenderedAttributedContent(
            attributedString: attributedString,
            searchRanges: searchRanges
        )
    }

    private func applyClickableAnnotationLinks(to attributedString: NSMutableAttributedString) {
        attributedString.enumerateAttribute(
            NSAttributedString.Key("annotationID"),
            in: NSRange(location: 0, length: attributedString.length)
        ) { value, range, _ in
            if let id = value as? Int64, let url = URL(string: "annotation://\(id)") {
                attributedString.addAttribute(.link, value: url, range: range)
            }
        }
    }

    private func restoreScrollAndSelectionIfNeeded(textView: iOSCustomIbarotTextView, context: Context) {
        let isNewContent = context.coordinator.restoredContentId != viewModel.currentContentId
            || context.coordinator.restoredBookId != viewModel.currentBook?.id
        guard isNewContent || viewModel.needsScrollRestore else { return }

        let targetDocY = viewModel.readerState.scrollPosition?.y ?? (isNewContent ? 0 : nil)
        if let targetDocY {
            context.coordinator.lastKnownScrollPosition = CGPoint(x: 0, y: targetDocY)
            textView.pendingRestoreOffset = targetDocY
            if textView.bounds.height > 0 {
                textView.applyPendingScrollRestore()
            }
        }

        if let range = viewModel.readerState.selectedRange,
           range.location >= 0,
           range.location + range.length <= textView.textStorage.length
        {
            textView.selectedRange = range
        }
        viewModel.needsScrollRestore = false
        context.coordinator.restoredContentId = viewModel.currentContentId
        context.coordinator.restoredBookId = viewModel.currentBook?.id
    }

    private func handleTargetAnnotationAndSearchHighlight(
        textView: iOSCustomIbarotTextView,
        context: Context,
        searchRanges: [NSRange]
    ) {
        guard textView.window != nil else { return }

        if let target = targetAnnotation {
            context.coordinator.animationTask?.cancel()
            context.coordinator.animationTask = Task { @MainActor [weak textView] in
                await textView?.highlighAndScrollToAnns(target)
            }
            return
        }

        if let event = annotationEvent,
           event.annotation.contentId == viewModel.currentContentId,
           context.coordinator.lastHandledAnnotationEventId != event.id
        {
            context.coordinator.lastHandledAnnotationEventId = event.id
            context.coordinator.animationTask?.cancel()
            context.coordinator.animationTask = Task { @MainActor [weak textView] in
                await textView?.highlighAndScrollToAnns(event.annotation)
            }
        }

        if let event = searchEvent,
           event.contentId == viewModel.currentContentId,
           !searchRanges.isEmpty || event.isTOC,
           context.coordinator.lastHandledSearchEventId != event.id
        {
            context.coordinator.lastHandledSearchEventId = event.id
            context.coordinator.animationTask?.cancel()
            context.coordinator.animationTask = Task { @MainActor [weak textView] in
                if let firstRange = searchRanges.first {
                    textView?.textLayoutManager?.ensureLayout(for: firstRange)
                    textView?.scrollRangeToVisible(firstRange)
                    await textView?.popupText(for: searchRanges)
                } else if event.isTOC, let tv = textView {
                    let effectiveTopInset = max(tv.adjustedContentInset.top, tv.safeAreaInsets.top)
                    tv.setContentOffset(CGPoint(x: 0, y: -effectiveTopInset), animated: true)
                }
            }
        } else if let selectedSegmentRange,
                  let renderResult = textView.currentRenderResult {
            let displayedSelected = renderResult.displayedRange(forSourceRange: selectedSegmentRange)
            if displayedSelected.location != NSNotFound, displayedSelected.length > 0 {
                DispatchQueue.main.async { [weak textView] in
                    textView?.textLayoutManager?.ensureLayout(for: displayedSelected)
                    textView?.scrollRangeToVisible(displayedSelected)
                }
            }
        }
    }

    private func scrollTextViewToTop(_ textView: UITextView) {
        let topY = -textView.adjustedContentInset.top
        textView.setContentOffset(CGPoint(x: 0, y: topY), animated: false)
    }

    private func scrollTextViewToBottom(_ textView: UITextView) {
        textView.layoutIfNeeded()
        let minY = -textView.adjustedContentInset.top
        let maxY = max(
            minY,
            textView.contentSize.height - textView.bounds.height + textView.adjustedContentInset.bottom
        )
        textView.setContentOffset(CGPoint(x: 0, y: maxY), animated: false)
    }

    class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        var parent: iOSIbarotTextView
        var currentRenderResult: ArabicRenderResult?
        var restoredBookId: Int?
        var restoredContentId: Int?
        var lastKnownScrollPosition: CGPoint?
        var lastHandledSearchEventId: UUID?
        var lastHandledAnnotationEventId: UUID?
        var lastRenderKey: RenderCacheKey?
        var lastRenderedContent: RenderedAttributedContent?
        var lastBackgroundColorIndex: Int?
        var animationTask: Task<Void, Never>?
        private var lastSelectionChangeDate: Date?
        private var manualDragStartOffset: CGFloat?
        private var didClearSearchForCurrentDrag = false

        // Pull-to-navigate state (delegated to ReaderPullNavigationStateMachine)
        weak var topIndicator: PullNavigationIndicatorView?
        weak var bottomIndicator: PullNavigationIndicatorView?
        private let pullStateMachine = ReaderPullNavigationStateMachine(pullThreshold: 80)
        private let hapticGenerator = UIImpactFeedbackGenerator(style: .medium)

        init(_ parent: iOSIbarotTextView) {
            self.parent = parent
        }

        deinit {
            animationTask?.cancel()
        }

        @objc func handleTextTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended,
                  recognizer.numberOfTouches == 1,
                  let textView = recognizer.view as? UITextView else { return }

            guard textView.selectedRange.length == 0 else { return }
            guard !textView.isDragging,
                  !textView.isDecelerating else { return }

            let point = recognizer.location(in: textView)
            DispatchQueue.main.async { [weak self, weak textView] in
                guard let self, let textView else { return }
                guard textView.selectedRange.length == 0 else { return }
                guard let characterIndex = self.characterIndex(in: textView, at: point) else { return }

                if characterIndex < textView.textStorage.length,
                   textView.textStorage.attribute(.link, at: characterIndex, effectiveRange: nil) != nil {
                    return
                }

                let sourceIndex = self.currentRenderResult?
                    .sourceCharacterIndex(forDisplayedIndex: characterIndex) ?? characterIndex
                self.parent.onTapTextCharacterIndex?(sourceIndex)
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let textView = gestureRecognizer.view as? UITextView else { return true }

            if textView.selectedRange.length > 0 {
                return false
            }

            if textView.isDragging || textView.isDecelerating {
                return false
            }

            if let lastSelectionChangeDate,
               Date().timeIntervalSince(lastSelectionChangeDate) < 0.35 {
                return false
            }

            return true
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            if textView.selectedRange.length > 0 {
                lastSelectionChangeDate = Date()
            }
        }

        private func characterIndex(in textView: UITextView, at point: CGPoint) -> Int? {
            guard textView.bounds.contains(point) else { return nil }
            guard let closestPosition = textView.closestPosition(to: point) else { return nil }
            let index = textView.offset(from: textView.beginningOfDocument, to: closestPosition)
            guard index >= 0, index <= textView.textStorage.length else { return nil }
            return index
        }

        // MARK: - Pull-to-Navigate Scroll Detection

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            manualDragStartOffset = scrollView.contentOffset.y
            didClearSearchForCurrentDrag = false
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if scrollView.isDragging || scrollView.isDecelerating || scrollView.isTracking {
                updateLastKnownScrollPosition(from: scrollView)
            }

            (scrollView as? iOSCustomIbarotTextView)?.updateViewportAccessibilityMetadata()
            if !didClearSearchForCurrentDrag,
               ReaderSearchContextCoordinator.shouldClearAfterScroll(
                   startOffsetY: manualDragStartOffset.map(Double.init),
                   currentOffsetY: Double(scrollView.contentOffset.y),
                   viewportHeight: Double(scrollView.bounds.height),
                   isManualUserDrag: scrollView.isDragging || scrollView.isTracking,
                   hasActiveHighlight: parent.viewModel.hasActiveSearchHighlight
               ) {
                didClearSearchForCurrentDrag = true
                parent.onManualScrollAwayFromSearchResult?()
            }
            let offsetY = scrollView.contentOffset.y
            let contentHeight = scrollView.contentSize.height
            let boundsHeight = scrollView.bounds.height
            let adjustedTopInset = scrollView.adjustedContentInset.top
            let adjustedBottomInset = scrollView.adjustedContentInset.bottom

            // Pull-to-navigate single-source state machine handling (BUG-02 fix)
            let topOverscroll = -(offsetY + adjustedTopInset)
            let maxOffsetY = contentHeight + adjustedBottomInset - boundsHeight
            let effectiveMaxOffsetY = max(maxOffsetY, -adjustedTopInset)
            let bottomOverscroll = offsetY - effectiveMaxOffsetY

            let isRestoring = (scrollView as? iOSCustomIbarotTextView)?.isRestoringScroll ?? false
            let transition = pullStateMachine.handleScroll(
                topOverscroll: topOverscroll,
                bottomOverscroll: bottomOverscroll,
                isTracking: scrollView.isTracking,
                isRestoringScroll: isRestoring
            )

            if transition.shouldTriggerHaptic {
                hapticGenerator.impactOccurred()
            }

            switch transition.direction {
            case .prev:
                topIndicator?.updateProgress(transition.progress)
                bottomIndicator?.reset()
            case .next:
                bottomIndicator?.updateProgress(transition.progress)
                topIndicator?.reset()
            case nil:
                topIndicator?.reset()
                bottomIndicator?.reset()
            }
        }

        func updateLastKnownScrollPosition(from scrollView: UIScrollView) {
            guard let customTextView = scrollView as? iOSCustomIbarotTextView,
                  !customTextView.isRestoringScroll,
                  scrollView.window != nil,
                  scrollView.bounds.height > 0
            else { return }
            let topInset = max(scrollView.adjustedContentInset.top, scrollView.safeAreaInsets.top)
            let docY = max(0, scrollView.contentOffset.y + topInset)
            lastKnownScrollPosition = CGPoint(x: 0, y: docY)
        }

        func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
            updateLastKnownScrollPosition(from: scrollView)
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            updateLastKnownScrollPosition(from: scrollView)

            defer {
                if !decelerate { manualDragStartOffset = nil }
                topIndicator?.reset()
                bottomIndicator?.reset()
            }

            if let direction = pullStateMachine.handleEndDragging(willDecelerate: decelerate) {
                switch direction {
                case .prev:
                    parent.onNavigatePrev?()
                case .next:
                    parent.onNavigateNext?()
                }
            }
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            manualDragStartOffset = nil
            pullStateMachine.reset()
            updateLastKnownScrollPosition(from: scrollView)
        }

        func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
            updateLastKnownScrollPosition(from: scrollView)
        }

        func textView(
            _ textView: UITextView,
            primaryActionFor textItem: UITextItem,
            defaultAction: UIAction
        ) -> UIAction? {
            // 1. Check if the item is a link
            if case let .link(url) = textItem.content {
                // 2. Extract your custom logic
                if url.scheme == "annotation",
                   let idString = url.host,
                   let annId = Int64(idString)
                {
                    // 3. Return an action that performs your logic
                    return UIAction { [weak self] _ in
                        self?.parent.onTapAnnotation?(annId)
                    }
                }
            }

            // 4. Return the default action for normal links
            return defaultAction
        }

        func textView(
            _ textView: UITextView,
            editMenuForTextIn range: NSRange,
            suggestedActions: [UIMenuElement]
        ) -> UIMenu? {
            guard range.length > 0 else { return nil }

            let mapper = ReaderSelectionRangeMapper()
            let rawSourceText = currentRenderResult?.sourceText ?? textView.text ?? ""
            let mappingProvider = currentRenderResult.map { res in ClosureRangeMappingProvider(transform: { r in res.remapSourceRange(r) }) }
            let mapResult = mapper.mapSelection(
                displayedRange: range,
                sourceText: rawSourceText,
                displayedText: textView.text,
                mappingProvider: mappingProvider
            )

            let sourceRange: NSRange
            let sourceText: String
            switch mapResult {
            case .success(let mapped):
                sourceRange = mapped.sourceRange
                sourceText = rawSourceText
            case .failure(let error):
                #if DEBUG
                print("[ReaderSelectionRangeMapper] Selection mapping rejected: \(error)")
                #endif
                return nil
            }

            let menuChildren: [UIMenuElement] = if let existing = parent.viewModel.findBestAnnotation(for: sourceRange) {
                buildExistingAnnotationMenuChildren(for: existing)
            } else {
                buildNewAnnotationMenuChildren(sourceRange: sourceRange, sourceText: sourceText)
            }

            var actions = suggestedActions
            if let shareContent = shareContent(sourceText: sourceText, sourceRange: sourceRange) {
                let shareAction = UIAction(
                    title: String(localized: "Share with Reference"),
                    image: UIImage(systemName: "square.and.arrow.up")
                ) { [weak self, weak textView] _ in
                    guard let self, let textView else { return }
                    presentShareSheet(content: shareContent, from: textView, selectedRange: range)
                }
                actions.insert(shareAction, at: 1)
            }

            let customMenu = UIMenu(
                title: String(localized: .annotation),
                image: UIImage(systemName: "highlighter"),
                children: menuChildren
            )
            actions.insert(customMenu, at: 1)
            return UIMenu(children: actions)
        }

        private func buildExistingAnnotationMenuChildren(for existing: Annotation) -> [UIMenuElement] {
            let editAction = UIAction(
                title: String(localized: .Annotation.editNote),
                image: UIImage(systemName: "square.and.pencil")
            ) { [weak self] _ in
                if let id = existing.id {
                    self?.parent.onTapAnnotation?(id)
                }
            }

            let deleteTitle = existing.note == nil ? String(localized: .Annotation.deleteHighlight) : String(localized: .Annotation.deleteHighlightNote)
            let deleteAction = UIAction(
                title: deleteTitle,
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { [weak self] _ in
                if let id = existing.id {
                    try? self?.parent.viewModel.deleteAnnotation(id: id)
                }
            }

            return [editAction, deleteAction]
        }

        private func buildNewAnnotationMenuChildren(sourceRange: NSRange, sourceText: String) -> [UIMenuElement] {
            let colors = Array(UserDefaults.standard.recentHighlightColors.prefix(UserDefaults.maxRecentColors))
            let highlightActions = colors.map { color in
                UIAction(
                    title: color.accessibilityName.capitalized,
                    image: UIImage(systemName: "circle.fill")?.withTintColor(color, renderingMode: .alwaysOriginal)
                ) { [weak self] _ in
                    self?.parent.onAddAnnotation?(sourceRange, .highlight, sourceText, color)
                }
            }

            let highlightMenu = UIMenu(
                title: String(localized: .Annotation.highlight),
                options: .displayInline,
                children: highlightActions
            )

            let underlineColor = UserDefaults.standard.recentUnderlineColors.first ?? .label
            let conf = UIImage.SymbolConfiguration(paletteColors: [underlineColor, .label])
            let underlineImage = UIImage(systemName: "underline")?.applyingSymbolConfiguration(conf)
            let underlineAction = UIAction(
                title: String(localized: "Underline"),
                image: underlineImage
            ) { [weak self] _ in
                self?.parent.onAddAnnotation?(sourceRange, .underline, sourceText, underlineColor)
            }

            return [highlightMenu, underlineAction]
        }

        private func shareContent(sourceText: String, sourceRange: NSRange) -> String? {
            guard let selectedText = substring(sourceText, in: sourceRange)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !selectedText.isEmpty else { return nil }

            return parent.viewModel.getShareReference(for: selectedText)
        }

        private func substring(_ text: String, in range: NSRange) -> String? {
            guard range.location >= 0,
                  range.length > 0,
                  range.location + range.length <= (text as NSString).length else { return nil }

            return (text as NSString).substring(with: range)
        }

        private func presentShareSheet(
            content: String,
            from textView: UITextView,
            selectedRange: NSRange
        ) {
            guard let topVC = ReusableFunc.getTopViewController() else { return }

            let activityVC = UIActivityViewController(
                activityItems: [content],
                applicationActivities: nil
            )

            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = textView
                popover.sourceRect = selectionRect(in: textView, range: selectedRange)
                popover.permittedArrowDirections = [.up, .down]
            }

            topVC.present(activityVC, animated: true)
        }

        private func selectionRect(in textView: UITextView, range: NSRange) -> CGRect {
            guard let start = textView.position(from: textView.beginningOfDocument, offset: range.location),
                  let end = textView.position(from: start, offset: range.length),
                  let textRange = textView.textRange(from: start, to: end)
            else {
                return CGRect(
                    x: textView.bounds.midX,
                    y: textView.bounds.midY,
                    width: 1,
                    height: 1
                )
            }

            let rect = textView.firstRect(for: textRange)
            guard !rect.isNull, !rect.isInfinite else {
                return CGRect(
                    x: textView.bounds.midX,
                    y: textView.bounds.midY,
                    width: 1,
                    height: 1
                )
            }
            return rect
        }
    }
}

import SwiftUI
import UIKit

/// A customized UITextView designed specifically for Arabic text and annotations, mirroring AppKit's IbarotTextView behavior.
class iOSCustomIbarotTextView: UITextView {
    var onHighlight: ((NSRange, String) -> Void)?
    var onUnderline: ((NSRange, String) -> Void)?

    var currentRenderResult: ArabicRenderResult?

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
        textLayoutManager?.delegate = self
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

    @MainActor
    func highlighAndScrollToAnns(_ ann: Annotation) {
        let range = displayedRange(for: ann)

        scrollRangeToVisible(range)
        Task { [weak self] in
            await Task.yield()
            await Task.yield()
            self?.popupText(for: [range])
        }
    }

    func popupText(for ranges: [NSRange]) {
        let nsString = textStorage.string as NSString
        guard let firstRange = ranges.first,
              firstRange.location >= 0,
              firstRange.length > 0,
              firstRange.location + firstRange.length <= nsString.length else { return }



        let path = UIBezierPath()
        for range in ranges {
            guard let startPos = position(from: beginningOfDocument, offset: range.location),
                  let endPos = position(from: startPos, offset: range.length),
                  let textRange = textRange(from: startPos, to: endPos) else { continue }
            
            let rects = selectionRects(for: textRange)
            for selectionRect in rects {
                let rect = selectionRect.rect
                guard rect.width > 0, rect.height > 0 else { continue }
                // Tambahkan padding kecil agar highlight tidak terlalu mepet
                path.append(UIBezierPath(rect: rect.insetBy(dx: -2, dy: -2)))
            }
        }
        
        let totalRect = path.bounds
        guard !totalRect.isNull, totalRect.width > 0, totalRect.height > 0 else { return }
        
        let containerView = UIView(frame: totalRect)
        containerView.alpha = 0
        containerView.transform = CGAffineTransform(scaleX: 1.35, y: 1.4)
        
        // 1. Background layer kuning dari gabungan rects
        let bgLayer = CAShapeLayer()
        let shiftedPath = UIBezierPath(cgPath: path.cgPath)
        shiftedPath.apply(CGAffineTransform(translationX: -totalRect.minX, y: -totalRect.minY))
        bgLayer.path = shiftedPath.cgPath
        bgLayer.fillColor = UIColor.systemYellow.cgColor
        containerView.layer.addSublayer(bgLayer)
        
        // 2. Teks di atasnya menggunakan UITextView dengan mengekstrak teks penuh halaman
        // Ini memastikan layout selaras sempurna dengan teks asli
        let attrText = NSMutableAttributedString(attributedString: textStorage)
        let fullRangeLocal = NSRange(location: 0, length: attrText.length)
        
        // Sembunyikan semua teks & hapus atribut anotasi lain (seperti link yang bisa meng-override warna text)
        attrText.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.clear, range: fullRangeLocal)
        attrText.removeAttribute(NSAttributedString.Key.link, range: fullRangeLocal)
        attrText.removeAttribute(NSAttributedString.Key.backgroundColor, range: fullRangeLocal)
        attrText.removeAttribute(NSAttributedString.Key.underlineStyle, range: fullRangeLocal)
        attrText.removeAttribute(NSAttributedString.Key.underlineColor, range: fullRangeLocal)
        
        // Hanya tampilkan bagian teks yang dianotasi
        for rng in ranges {
            guard rng.location >= 0, rng.location + rng.length <= attrText.length else { continue }
            attrText.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.black, range: rng)
        }
        
        // Buat UITextView dengan lebar yang SAMA dengan view aslinya agar layoutnya 100% identik
        let textOverlay = UITextView(frame: CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height))
        textOverlay.attributedText = attrText
        textOverlay.backgroundColor = .clear
        textOverlay.isScrollEnabled = false
        textOverlay.isEditable = false
        textOverlay.isSelectable = false
        textOverlay.textAlignment = self.textAlignment
        textOverlay.semanticContentAttribute = self.semanticContentAttribute
        textOverlay.textContainerInset = self.textContainerInset
        textOverlay.textContainer.lineFragmentPadding = self.textContainer.lineFragmentPadding
        textOverlay.clipsToBounds = false
        
        // Paksa layout agar kita bisa mencari posisi presisinya
        textOverlay.layoutIfNeeded()
        
        // Beri ruang tinggi secukupnya
        textOverlay.frame.size.height = max(self.bounds.height, textOverlay.contentSize.height)
        // Geser posisinya sehingga bagian target text tepat berada di (0,0) dari containerView
        textOverlay.frame.origin = CGPoint(x: -totalRect.minX, y: -totalRect.minY)
        
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

    func displayedRange(for annotation: Annotation) -> NSRange {
        let state = TextViewState.shared
        let range = state.showHarakat ? annotation.rangeDiacritics : annotation.range
        return displayedRange(forStoredRange: range)
    }

    private func displayedRange(forStoredRange range: NSRange) -> NSRange {
        currentRenderResult?.remapDisplayedRange(range) ?? range
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
}

/// SwiftUI Wrapper for iOSCustomIbarotTextView
struct iOSIbarotTextView: UIViewRepresentable {
    @Binding var text: String
    var annotations: [Annotation] = []
    @Binding var searchText: String
    var searchMode: SearchMode?
    var nearDistance: Int = 10
    var targetAnnotation: Annotation? = nil
    var selectedSegmentRange: NSRange?
    var isMultiLanguage: Bool = false
    var isImported: Bool = false
    
    var viewModel: ReaderViewModel

    // Callbacks for the ViewModel to handle menu actions
    var onAddAnnotation: ((NSRange, AnnotationMode, String, UIColor) -> Void)?
    var onTapAnnotation: ((Int64) -> Void)?
    var onTapTextCharacterIndex: ((Int) -> Void)?

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

        textView.onHighlight = { sourceRange, sourceText in
            let color = UserDefaults.standard.recentHighlightColors.first ?? .yellow
            onAddAnnotation?(sourceRange, .highlight, sourceText, color)
        }
        textView.onUnderline = { sourceRange, sourceText in
            onAddAnnotation?(sourceRange, .underline, sourceText, .black)
        }

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

        /* NavigationStack di SwiftUI tidak selalu destroy+recreate secara sinkron. Ada kasus di mana updateUIView dipanggil lebih dulu dengan parent baru sebelum SwiftUI selesai memutuskan apakah akan recreate atau reuse — terutama karena `ReaderViewModel` adalah @Observable class (reference type). SwiftUI mungkin mendeteksi "view type sama, posisi sama" dan mencoba reuse dulu, trigger updateUIView, baru kemudian recreate. Jadi context.coordinator.parent = self di updateUIView itu memang defensive programming — dan karena terbukti memperbaiki bug nyata, berarti memang ada skenario di mana Coordinator di-reuse dengan parent stale.
         */
        context.coordinator.parent = self

        viewModel.fetchScrollPosition = { [weak textView] in
            textView?.contentOffset
        }

        viewModel.fetchSelectedRange = { [weak textView] in
            textView?.selectedRange
        }

        if isMultiLanguage {
            textView.textAlignment = .natural
            textView.semanticContentAttribute = .unspecified
        } else {
            textView.textAlignment = .right
            textView.semanticContentAttribute = .forceRightToLeft
        }

        let renderer = ArabicTextRenderer()
        let renderSignature = RenderSignature(
            contentID: viewModel.currentContentId,
            textHash: text.hashValue,
            textLength: (text as NSString).length,
            showHarakat: state.showHarakat,
            isMultiLanguage: isMultiLanguage,
            isImported: isImported,
            fontName: state.fontName,
            fontSize: state.fontSize,
            lineHeight: state.lineHeight
        )
        let contentChanged = context.coordinator.renderSignature != renderSignature
        if contentChanged || context.coordinator.currentRenderResult == nil {
            let renderResult = renderer.render(
                bookId: viewModel.currentBook?.id,
                contentId: viewModel.currentContentId,
                text: text,
                highlightColor: .header,
                showHarakat: state.showHarakat,
                isMultiLanguage: isMultiLanguage,
                isImported: isImported
            )
            context.coordinator.renderSignature = renderSignature
            context.coordinator.currentRenderResult = renderResult
            context.coordinator.baseAttributedString = renderResult.attributedString
            textView.currentRenderResult = renderResult
        }

        guard let renderResult = context.coordinator.currentRenderResult,
              let baseAttributedString = context.coordinator.baseAttributedString else { return }
        textView.currentRenderResult = renderResult
        let contentIdChanged = context.coordinator.lastHighlightedContentId != viewModel.currentContentId
        let decorationSignature = DecorationSignature(
            renderSignature: renderSignature,
            annotations: annotations.map {
                AnnotationRenderSignature(
                    id: $0.id,
                    range: $0.range,
                    diacriticsRange: $0.rangeDiacritics,
                    colorHex: $0.colorHex,
                    type: $0.type.rawValue
                )
            },
            searchText: searchText,
            searchMode: searchMode.map { String(describing: $0) } ?? "",
            nearDistance: nearDistance,
            clickableAnnotations: state.clickableAnnotation
        )
        let decorationsChanged = context.coordinator.decorationSignature != decorationSignature
        var searchRanges = context.coordinator.searchRanges
        var shouldTriggerSearchAnimation = false

        if contentChanged || decorationsChanged {
            let decorated = NSMutableAttributedString(attributedString: baseAttributedString)
            renderer.applyAnnotations(
                annotations,
                to: decorated,
                showHarakat: state.showHarakat,
                replacementEvents: renderResult.replacementEvents
            )
            if state.clickableAnnotation {
                decorated.enumerateAttribute(
                    NSAttributedString.Key("annotationID"),
                    in: NSRange(location: 0, length: decorated.length)
                ) { value, range, _ in
                    guard let id = value as? Int64,
                          let url = URL(string: "annotation://\(id)") else { return }
                    decorated.addAttribute(.link, value: url, range: range)
                }
            }
            searchRanges = searchText.isEmpty ? [] : decorated.highlightSearchText(
                searchText: searchText,
                mode: searchMode,
                baseColor: .highlightText,
                nearDistance: nearDistance
            )
            shouldTriggerSearchAnimation = !searchText.isEmpty
                && (context.coordinator.processedSearchText != searchText || contentIdChanged)
            context.coordinator.processedSearchText = searchText.isEmpty ? nil : searchText
            context.coordinator.decorationSignature = decorationSignature
            context.coordinator.decoratedAttributedString = decorated
            context.coordinator.searchRanges = searchRanges
            context.coordinator.selectedDisplayedRange = nil
            context.coordinator.replaceTextStorage(
                in: textView,
                with: decorated,
                preserveSelection: !contentIdChanged,
                preserveOffset: !contentIdChanged
            )
            textView.invalidateIntrinsicContentSize()
            textView.setNeedsLayout()
            textView.layoutIfNeeded()
        }

        let displayedSelectedRange = selectedSegmentRange.map {
            renderResult.remapDisplayedRange(ReaderTextIndexMapper.displayedRange(
                forSourceRange: $0,
                sourceText: text,
                showHarakat: state.showHarakat
            ))
        }
        context.coordinator.updateSegmentHighlight(in: textView, displayedRange: displayedSelectedRange)

        if contentIdChanged {
        textView.selectedRange = NSRange(location: 0, length: 0)
    }

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
    } else if context.coordinator.restoredContentId != viewModel.currentContentId ||
                viewModel.needsScrollRestore
    {
        if let scroll = viewModel.readerState.scrollPosition {
            textView.setContentOffset(scroll, animated: false)
        } else {
            textView.setContentOffset(CGPoint(x: 0, y: -textView.adjustedContentInset.top), animated: false)
        }
        if let range = viewModel.readerState.selectedRange {
            textView.selectedRange = range
        }
        viewModel.needsScrollRestore = false
        context.coordinator.restoredContentId = viewModel.currentContentId
    }

        if contentIdChanged {
            context.coordinator.lastHighlightedContentId = viewModel.currentContentId
            context.coordinator.processedAnnotationId = nil
        }

        if let targetAnnotation = targetAnnotation {
            if context.coordinator.processedAnnotationId != targetAnnotation.id || targetAnnotation.id == nil || contentIdChanged {
                context.coordinator.processedAnnotationId = targetAnnotation.id
                DispatchQueue.main.async {
                    textView.highlighAndScrollToAnns(targetAnnotation)
                }
            }
        } else {
            context.coordinator.processedAnnotationId = nil
        }
        
        if shouldTriggerSearchAnimation, !searchRanges.isEmpty, let firstRange = searchRanges.first {
            DispatchQueue.main.async { [weak textView] in
                textView?.scrollRangeToVisible(firstRange)
                Task { [weak textView] in
                    await Task.yield()
                    await Task.yield()
                    textView?.popupText(for: searchRanges)
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
        var baseAttributedString: NSAttributedString?
        var decoratedAttributedString: NSAttributedString?
        fileprivate var renderSignature: RenderSignature?
        fileprivate var decorationSignature: DecorationSignature?
        var selectedDisplayedRange: NSRange?
        var searchRanges: [NSRange] = []
        var restoredContentId: Int?
        var lastHighlightedContentId: Int?
        var processedSearchText: String?
        var processedAnnotationId: Int64?
        private var lastSelectionChangeDate: Date?

        // Pull-to-navigate state
        weak var topIndicator: PullNavigationIndicatorView?
        weak var bottomIndicator: PullNavigationIndicatorView?
        private let pullThreshold: CGFloat = 80
        private var hasTriggeredHaptic = false
        private var activePullDirection: PullDirection?
        private let hapticGenerator = UIImpactFeedbackGenerator(style: .medium)

        init(_ parent: iOSIbarotTextView) {
            self.parent = parent
        }

        func replaceTextStorage(
            in textView: UITextView,
            with value: NSAttributedString,
            preserveSelection: Bool,
            preserveOffset: Bool
        ) {
            let priorSelection = textView.selectedRange
            let priorOffset = textView.contentOffset
            textView.textStorage.beginEditing()
            textView.textStorage.setAttributedString(value)
            textView.textStorage.endEditing()
            if preserveSelection, NSMaxRange(priorSelection) <= textView.textStorage.length {
                textView.selectedRange = priorSelection
            }
            if preserveOffset { textView.setContentOffset(priorOffset, animated: false) }
        }

        func updateSegmentHighlight(in textView: UITextView, displayedRange: NSRange?) {
            guard selectedDisplayedRange != displayedRange else { return }
            textView.textStorage.beginEditing()
            if let oldRange = selectedDisplayedRange,
               NSMaxRange(oldRange) <= textView.textStorage.length,
               let decoratedAttributedString {
                textView.textStorage.removeAttribute(.backgroundColor, range: oldRange)
                decoratedAttributedString.enumerateAttribute(.backgroundColor, in: oldRange) { value, range, _ in
                    if let value {
                        textView.textStorage.addAttribute(.backgroundColor, value: value, range: range)
                    }
                }
            }
            if let displayedRange,
               displayedRange.location >= 0,
               displayedRange.length > 0,
               NSMaxRange(displayedRange) <= textView.textStorage.length {
                textView.textStorage.addAttribute(
                    .backgroundColor,
                    value: UIColor.systemBlue.withAlphaComponent(0.14),
                    range: displayedRange
                )
                selectedDisplayedRange = displayedRange
            } else {
                selectedDisplayedRange = nil
            }
            textView.textStorage.endEditing()
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
                    .remapSourceRange(NSRange(location: characterIndex, length: 0))
                    .location ?? characterIndex
                self.parent.onTapTextCharacterIndex?(
                    ReaderTextIndexMapper.sourceCharacterIndex(
                        forDisplayedIndex: sourceIndex,
                        sourceText: self.parent.text,
                        showHarakat: TextViewState.shared.showHarakat
                    )
                )
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

            let layoutManager = textView.layoutManager
            let textContainer = textView.textContainer
            var location = point
            location.x -= textView.textContainerInset.left
            location.y -= textView.textContainerInset.top

            let glyphIndex = layoutManager.glyphIndex(for: location, in: textContainer)
            guard glyphIndex < layoutManager.numberOfGlyphs else { return nil }

            let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
            guard characterIndex >= 0, characterIndex <= textView.textStorage.length else { return nil }
            return characterIndex
        }

        // MARK: - Pull-to-Navigate Scroll Detection

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let offsetY = scrollView.contentOffset.y
            let contentHeight = scrollView.contentSize.height
            let boundsHeight = scrollView.bounds.height
            let adjustedTopInset = scrollView.adjustedContentInset.top
            let adjustedBottomInset = scrollView.adjustedContentInset.bottom

            // 1. Batas Atas (Previous Page)
            let topOverscroll = -(offsetY + adjustedTopInset)
            let isTopOverscrolling = handleOverscroll(
                topOverscroll,
                direction: .prev,
                scrollView: scrollView,
                onUpdate: { [weak self] progress in self?.topIndicator?.updateProgress(progress) },
                onReset: { [weak self] in self?.topIndicator?.reset() }
            )

            if isTopOverscrolling { return }

            // 2. Batas Bawah (Next Page)
            let maxOffsetY = contentHeight + adjustedBottomInset - boundsHeight
            let effectiveMaxOffsetY = max(maxOffsetY, -adjustedTopInset)
            let bottomOverscroll = offsetY - effectiveMaxOffsetY

            let isBottomOverscrolling = handleOverscroll(
                bottomOverscroll,
                direction: .next,
                scrollView: scrollView,
                onUpdate: { [weak self] progress in self?.bottomIndicator?.updateProgress(progress) },
                onReset: { [weak self] in self?.bottomIndicator?.reset() }
            )

            if isBottomOverscrolling { return }

            // Bersihkan state jika dilepas di posisi tengah/normal
            if !scrollView.isTracking {
                activePullDirection = nil
            }
        }

        private func handleOverscroll(
            _ overscroll: CGFloat,
            direction: PullDirection,
            scrollView: UIScrollView,
            onUpdate: (CGFloat) -> Void,
            onReset: () -> Void
        ) -> Bool {
            if overscroll > 0 {
                if scrollView.isTracking {
                    let progress = min(overscroll / pullThreshold, 1.0)
                    onUpdate(progress)
                    activePullDirection = direction

                    if overscroll >= pullThreshold {
                        if !hasTriggeredHaptic {
                            hasTriggeredHaptic = true
                            hapticGenerator.impactOccurred()
                        }
                    } else {
                        hasTriggeredHaptic = false
                    }

                    if !hasTriggeredHaptic {
                        hapticGenerator.prepare()
                    }
                }
                return true // Mengembalikan true untuk menandakan state sedang overscroll
            } else {
                onReset()
                return false
            }
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            defer {
                hasTriggeredHaptic = false
                activePullDirection = nil
                topIndicator?.reset()
                bottomIndicator?.reset()
            }

            guard hasTriggeredHaptic, let direction = activePullDirection else { return }

            switch direction {
            case .prev:
                parent.onNavigatePrev?()
            case .next:
                parent.onNavigateNext?()
            }
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

            let sourceRange = currentRenderResult?.remapSourceRange(range) ?? range
            let sourceText = currentRenderResult?.sourceText ?? textView.text ?? ""

            var menuChildren: [UIMenuElement] = []
            var actions = suggestedActions

            if let existing = parent.viewModel.findBestAnnotation(for: sourceRange) {
                // Ada anotasi yang tumpang tindih
                let editAction = UIAction(
                    title: String(localized: "Edit Note"),
                    image: UIImage(systemName: "square.and.pencil")
                ) { [weak self] _ in
                    if let id = existing.id {
                        self?.parent.onTapAnnotation?(id)
                    }
                }

                let deleteTitle = existing.note == nil ? String(localized: "Delete Highlight") : String(localized: "Delete Highlight & Note")
                let deleteAction = UIAction(
                    title: deleteTitle,
                    image: UIImage(systemName: "trash"),
                    attributes: .destructive
                ) { [weak self] _ in
                    if let id = existing.id {
                        try? self?.parent.viewModel.deleteAnnotation(id: id)
                    }
                }

                menuChildren = [editAction, deleteAction]
            } else {
                // Tidak ada anotasi, buat opsi Highlight & Underline
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
                    title: String(localized: "Highlight"),
                    options: .displayInline,
                    children: highlightActions
                )

                let underlineAction = UIAction(
                    title: String(localized: "Underline"),
                    image: UIImage(systemName: "underline")
                ) { [weak self] _ in
                    self?.parent.onAddAnnotation?(sourceRange, .underline, sourceText, .black)
                }

                menuChildren = [highlightMenu, underlineAction]
            }

            if let shareContent = shareContent(sourceText: sourceText, sourceRange: sourceRange) {
                let shareAction = UIAction(
                    title: String(localized: "Share with Reference"),
                    image: UIImage(systemName: "square.and.arrow.up")
                ) { [weak self, weak textView] _ in
                    guard let self, let textView else { return }
                    self.presentShareSheet(
                        content: shareContent,
                        from: textView,
                        selectedRange: range
                    )
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
                  let textRange = textView.textRange(from: start, to: end) else {
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

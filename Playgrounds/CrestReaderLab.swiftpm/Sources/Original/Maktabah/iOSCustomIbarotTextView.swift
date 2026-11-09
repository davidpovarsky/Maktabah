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

    var pendingRestoreOffset: CGFloat?
    var isRestoringScroll: Bool = false

    override func layoutSubviews() {
        super.layoutSubviews()
        if pendingRestoreOffset != nil {
            applyPendingScrollRestore()
        }
    }

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
        currentRenderResult?.remapDisplayedRange(range) ?? range
    }
}

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
        isEditable = false
        isSelectable = true
        textAlignment = .right
        semanticContentAttribute = .forceRightToLeft
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

    func highlightAndScrollToText(_ searchText: String) {
        let rawText = textStorage.string

        var normalizedChars: [Character] = []
        var indexMap: [Int] = []

        let diacritics = CharacterSet(charactersIn: "\u{064B}\u{064C}\u{064D}\u{064E}\u{064F}\u{0650}\u{0651}\u{0652}\u{0670}\u{0653}\u{0654}\u{0655}")

        var utf16Offset = 0
        for char in rawText {
            let scalars = char.unicodeScalars
            let isDiacritic = scalars.count == 1 && diacritics.contains(scalars.first!)
            let isTatweel = scalars.count == 1 && scalars.first!.value == 0x0640

            if isDiacritic || isTatweel {
                utf16Offset += char.utf16.count
                continue
            }

            let alefVariants: Set<Unicode.Scalar> = ["أ", "إ", "آ", "ٱ"]
            let normalizedChar: Character = if scalars.count == 1, let scalar = scalars.first, alefVariants.contains(scalar) {
                "ا"
            } else {
                char
            }

            indexMap.append(utf16Offset)
            normalizedChars.append(normalizedChar)
            utf16Offset += char.utf16.count
        }

        let normalizedText = String(normalizedChars)

        let searchTerms = searchText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { $0.normalizeArabic(true) }

        guard !searchTerms.isEmpty else { return }

        let colors: [UIColor] = [
            UIColor(named: "HighlightText") ?? .yellow,
            UIColor.magenta.withAlphaComponent(0.4),
            UIColor.systemPink.withAlphaComponent(0.4),
            UIColor.systemPurple.withAlphaComponent(0.4),
            UIColor.systemIndigo.withAlphaComponent(0.4),
        ]

        var firstMatchRange: NSRange?

        for (index, searchTerm) in searchTerms.enumerated() {
            let color = colors[index % colors.count]
            var searchStart = normalizedText.startIndex

            while searchStart < normalizedText.endIndex,
                  let found = normalizedText.range(
                      of: searchTerm,
                      options: [.diacriticInsensitive],
                      range: searchStart ..< normalizedText.endIndex
                  )
            {
                let normStartIdx = normalizedText.distance(from: normalizedText.startIndex, to: found.lowerBound)
                let normEndIdx = normalizedText.distance(from: normalizedText.startIndex, to: found.upperBound)

                guard normStartIdx < indexMap.count else { break }

                let rawUtf16Start = indexMap[normStartIdx]
                let rawUtf16End: Int = if normEndIdx < indexMap.count {
                    indexMap[normEndIdx]
                } else {
                    rawText.utf16.count
                }

                let nsRange = NSRange(location: rawUtf16Start, length: rawUtf16End - rawUtf16Start)

                if firstMatchRange == nil {
                    firstMatchRange = nsRange
                }

                var hasBackground = false
                textStorage.enumerateAttribute(.backgroundColor, in: nsRange, options: []) { value, _, stop in
                    if value != nil { hasBackground = true; stop.pointee = true }
                }

                if !hasBackground {
                    textStorage.addAttribute(.backgroundColor, value: color, range: nsRange)
                }

                searchStart = found.upperBound
            }
        }

        if let firstRange = firstMatchRange {
            scrollRangeToVisible(firstRange)
        }
    }
}

/// SwiftUI Wrapper for iOSCustomIbarotTextView
struct iOSIbarotTextView: UIViewRepresentable {
    @Binding var text: String
    var annotations: [Annotation] = []
    @Binding var searchText: String
    
    var viewModel: iOSReaderViewModel

    // Callbacks for the ViewModel to handle menu actions
    var onAddAnnotation: ((NSRange, AnnotationMode, String, UIColor) -> Void)?
    var onTapAnnotation: ((Int64) -> Void)?

    var state = TextViewState.shared

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()

        let textView = iOSCustomIbarotTextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.delegate = context.coordinator

        textView.onHighlight = { sourceRange, sourceText in
            let color = UserDefaults.standard.recentHighlightColors.first ?? .yellow
            onAddAnnotation?(sourceRange, .highlight, sourceText, color)
        }
        textView.onUnderline = { sourceRange, sourceText in
            onAddAnnotation?(sourceRange, .underline, sourceText, .black)
        }
        
        viewModel.fetchScrollPosition = { [weak textView] in
            textView?.contentOffset
        }
        
        viewModel.fetchSelectedRange = { [weak textView] in
            textView?.selectedRange
        }

        container.addSubview(textView)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: container.topAnchor),
            textView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let textView = uiView.subviews.first as? iOSCustomIbarotTextView else { return }

        let renderer = ArabicTextRenderer()
        let headerColor = UIColor.header

        let renderResult = renderer.render(
            text: text,
            highlightColor: headerColor,
            showHarakat: state.showHarakat
        )

        textView.currentRenderResult = renderResult
        context.coordinator.currentRenderResult = renderResult

        let attributedString = NSMutableAttributedString(
            attributedString: renderResult.attributedString
        )
        renderer.applyAnnotations(
            annotations,
            to: attributedString,
            showHarakat: state.showHarakat,
            replacementEvents: renderResult.replacementEvents
        )

        // Apply clickable links berdasarkan setting
        if state.clickableAnnotation {
            attributedString.enumerateAttribute(
                NSAttributedString.Key("annotationID"),
                in: NSRange(location: 0, length: attributedString.length)
            ) { value, range, _ in
                if let id = value as? Int64 {
                    let urlString = "annotation://\(id)"
                    if let url = URL(string: urlString) {
                        attributedString.addAttribute(.link, value: url, range: range)
                    }
                }
            }
        }

        textView.attributedText = attributedString
        
        // Restore Scroll & Selection exactly once per content ID
        if context.coordinator.restoredContentId != viewModel.currentContentId {
            if let scroll = viewModel.state.scrollPosition {
                textView.setContentOffset(scroll, animated: false)
            }
            if let range = viewModel.state.selectedRange {
                textView.selectedRange = range
            }
            context.coordinator.restoredContentId = viewModel.currentContentId
        }

        if !searchText.isEmpty {
            DispatchQueue.main.async {
                textView.highlightAndScrollToText(searchText)
            }
        }
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: iOSIbarotTextView
        var currentRenderResult: ArabicRenderResult?
        var restoredContentId: Int?

        init(_ parent: iOSIbarotTextView) {
            self.parent = parent
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

            // Create color actions for the highlight menu
            let colors = UserDefaults.standard.recentHighlightColors
            let highlightActions = colors.map { color in
                UIAction(
                    title: color.accessibilityName.capitalized, // Gunakan nama warna agar tampil di iPad
                    image: UIImage(systemName: "circle.fill")?.withTintColor(color, renderingMode: .alwaysOriginal)
                ) { [weak self] _ in
                    self?.parent.onAddAnnotation?(sourceRange, .highlight, sourceText, color)
                }
            }

            // Gunakan .displayInline agar ikon warna berjajar ke samping (seperti palet)
            let highlightMenu = UIMenu(
                title: String(localized: "Highlight"),
                options: .displayInline,
                children: highlightActions
            )

            let underlineAction = UIAction(
                title: String(localized: .underline),
                image: UIImage(systemName: "underline")
            ) { [weak self] _ in
                self?.parent.onAddAnnotation?(sourceRange, .underline, sourceText, .black)
            }

            // Menu utama Annotate
            let customMenu = UIMenu(
                title: "",
                image: UIImage(systemName: "highlighter"),
                children: [highlightMenu, underlineAction]
            )

            var actions = suggestedActions
            actions.insert(customMenu, at: 0)
            return UIMenu(children: actions)
        }
    }
}

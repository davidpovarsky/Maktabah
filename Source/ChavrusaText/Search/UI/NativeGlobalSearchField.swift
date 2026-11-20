import SwiftUI
import UIKit

/// A native search field placed in content: `.searchable` would create another navigation field.
struct NativeGlobalSearchField: UIViewRepresentable {
    @Binding var text: String
    @Environment(\.maktabahNativeRoutingSession) private var nativeSession
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UISearchTextField {
        let field = GlobalSearchTextField()
        field.delegate = context.coordinator
        field.nativeAttachmentDidChange = { [weak coordinator = context.coordinator] field in
            coordinator?.nativeStateChanged(field)
        }
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        field.setSearchPlaceholder(String(localized: "Search Books", defaultValue: "חיפוש בטקסט הספרים"))
        field.accessibilityLabel = field.placeholder
        field.accessibilityIdentifier = "global-search-query"
        field.returnKeyType = .search
        field.enablesReturnKeyAutomatically = true
        field.clearButtonMode = .whileEditing
        field.textAlignment = .natural
        field.autocorrectionType = .no
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        #if DEBUG
        Self.configureFontDiagnostics(field)
        #endif
        return field
    }

    func updateUIView(_ field: UISearchTextField, context: Context) {
        context.coordinator.parent = self
        context.coordinator.bindNativeField(field, session: nativeSession)
        if field.text != text, field.markedTextRange == nil { field.text = text }
        #if DEBUG
        Self.configureFontDiagnostics(field)
        #endif
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UISearchTextField, context: Context) -> CGSize? {
        CGSize(width: max(0, proposal.width ?? max(44, uiView.intrinsicContentSize.width)),
               height: max(44, uiView.intrinsicContentSize.height))
    }

    static func dismantleUIView(_ field: UISearchTextField, coordinator: Coordinator) {
        coordinator.unbindNativeField(field)
        (field as? GlobalSearchTextField)?.nativeAttachmentDidChange = nil
        #if DEBUG
        (field as? GlobalSearchTextField)?.nativeFontDiagnosticNamespace = nil
        (field as? GlobalSearchTextField)?.nativeFontDiagnosticSink = nil
        #endif
    }
    #if DEBUG
    @MainActor private static func fontDiagnosticNamespace() -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "-GlobalSearchFontDiagnosticsEnabled"),
              arguments.indices.contains(flag + 1), arguments[flag + 1] == "YES",
              UserDefaults.standard.bool(forKey: "GlobalSearchFontDiagnosticsEnabled"),
              OtzariaDataProfileRegistry.activeProfileID == "miniTest10",
              let raw = UserDefaults.standard.string(forKey: "studyWorkspaceTestingNamespace"),
              let namespace = UUID(uuidString: raw) else { return nil }
        return namespace.uuidString
    }

    @MainActor private static func configureFontDiagnostics(_ field: UISearchTextField) {
        guard let field = field as? GlobalSearchTextField else { return }
        guard fontDiagnosticNamespace() != nil else {
            field.nativeFontDiagnosticNamespace = nil
            field.nativeFontDiagnosticSink = nil
            return
        }
        field.nativeFontDiagnosticNamespace = { fontDiagnosticNamespace() }
        field.nativeFontDiagnosticSink = { OtzariaFileLogger.shared.log($0) }
    }
    #endif

    @MainActor final class Coordinator: NSObject, UITextFieldDelegate {
        private weak var nativeSession: MaktabahNativeSceneSession?
        private weak var nativeField: UISearchTextField?

        func bindNativeField(_ field: UISearchTextField, session: MaktabahNativeSceneSession?) {
            guard nativeField !== field || nativeSession !== session else { return }
            if let previous = nativeField { nativeSession?.detachSearchField(previous) }
            nativeField = field; nativeSession = session
            session?.attachSearchField(field)
        }

        func unbindNativeField(_ field: UISearchTextField) {
            guard nativeField === field else { return }
            nativeSession?.detachSearchField(field)
            nativeField = nil; nativeSession = nil
        }

        func nativeStateChanged(_ field: UISearchTextField) {
            guard nativeField === field else { return }
            nativeSession?.searchFieldStateDidChange(field)
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            if let field = textField as? UISearchTextField { nativeStateChanged(field) }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            if let field = textField as? UISearchTextField { nativeStateChanged(field) }
        }

        var parent: NativeGlobalSearchField
        init(_ parent: NativeGlobalSearchField) { self.parent = parent }

        @objc func changed(_ field: UISearchTextField) {
            parent.text = field.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.text = textField.text ?? ""
            textField.resignFirstResponder()
            parent.onSubmit()
            return false
        }

        func textFieldShouldClear(_ textField: UITextField) -> Bool {
            parent.text = ""
            return true
        }
    }
}

/// Keep both editable text and its native placeholder on the current trait's
/// body font. UISearchTextField's internal placeholder label can otherwise keep
/// its earlier font while the surrounding SwiftUI layout changes Dynamic Type.
private final class GlobalSearchTextField: UISearchTextField {
    var nativeAttachmentDidChange: (@MainActor (UISearchTextField) -> Void)?
    #if DEBUG
    var nativeFontDiagnosticNamespace: (@MainActor () -> String?)?
    var nativeFontDiagnosticSink: (@MainActor (String) -> Void)?
    private var nativeFontDiagnosticRecorder: GlobalSearchFontDiagnosticRecorder?
    private var nativeFontDiagnosticLayoutPending = false

    private func observeNativeFonts(_ phase: GlobalSearchFontDiagnosticRecorder.Phase) {
        guard let namespace = nativeFontDiagnosticNamespace?(),
              let sink = nativeFontDiagnosticSink, let window else { return }
        if nativeFontDiagnosticRecorder?.namespace != namespace {
            nativeFontDiagnosticRecorder = GlobalSearchFontDiagnosticRecorder(namespace: namespace)
        }
        nativeFontDiagnosticRecorder?.observe(window: window, field: self, phase: phase, sink: sink)
    }
    #endif
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureDynamicType()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureDynamicType()
    }

    private func configureDynamicType() {
        adjustsFontForContentSizeCategory = true
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) {
            (field: GlobalSearchTextField, _: UITraitCollection) in
            field.updateScaledTypography()
            #if DEBUG
            field.nativeFontDiagnosticLayoutPending = true
            field.observeNativeFonts(.trait)
            #endif
        }
        updateScaledTypography()
    }

    func setSearchPlaceholder(_ value: String) {
        placeholder = value
        updateScaledTypography()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateScaledTypography()
        nativeAttachmentDidChange?(self)
        #if DEBUG
        nativeFontDiagnosticLayoutPending = true
        observeNativeFonts(.mount)
        #endif
    }

    private func updateScaledTypography() {
        let bodyFont = UIFont.preferredFont(forTextStyle: .body, compatibleWith: traitCollection)
        font = bodyFont
        if let placeholder {
            attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [
                .font: bodyFont,
                .foregroundColor: UIColor.placeholderText
            ])
        }
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        #if DEBUG
        defer {
            if nativeFontDiagnosticLayoutPending {
                nativeFontDiagnosticLayoutPending = false
                observeNativeFonts(.layout)
            }
        }
        #endif
        // UISearchTextField creates its placeholder UILabel lazily. Its font
        // must retain Dynamic Type metadata as well as tracking visual size;
        // updating attributedPlaceholder alone leaves that native label opted
        // out of the system accessibility text-size audit.
        guard let placeholder, let bodyFont = font else { return }
        var descendants = subviews
        while let view = descendants.popLast() {
            descendants.append(contentsOf: view.subviews)
            guard let label = view as? UILabel, label.text == placeholder else { continue }
            label.adjustsFontForContentSizeCategory = true
            if label.font != bodyFont { label.font = bodyFont }
        }
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width, height: max(44, max(size.height, ceil(font?.lineHeight ?? 0) + 20)))
    }
}
#if DEBUG
/// Passive, bounded metadata of the field's actual window. This is not an
/// accessibility audit and never identifies a label as passing or failing one.
/// It reads no text, query, accessibility label/value, or attributed string.
@MainActor private final class GlobalSearchFontDiagnosticRecorder {
    enum Phase: String { case mount, trait, layout }
    let namespace: String
    private var observing = false
    private var snapshots = 0
    private var limitRecorded = false
    private var previous: Data?
    private static let nodeLimit = 768
    private static let labelLimit = 64
    private static let snapshotLimit = 32
    private static let byteLimit = 65_536
    private static let knownIdentifiers: Set<String> = [
        "global-search-screen", "global-search-header", "global-search-query",
        "global-search-history", "global-search-history-heading",
        "global-search-books", "global-search-mode", "global-search-options"
    ]

    init(namespace: String) { self.namespace = namespace }

    func observe(window: UIWindow, field: UISearchTextField, phase: Phase,
                 sink: @MainActor (String) -> Void) {
        guard !observing, field.window === window else { return }
        guard snapshots < Self.snapshotLimit else {
            if !limitRecorded {
                limitRecorded = true
                let notice: [String: Any] = ["event": "snapshot_limit", "namespace": namespace,
                    "truncatedSnapshots": true, "snapshotLimit": Self.snapshotLimit,
                    "phase": phase.rawValue, "fieldCategory": field.traitCollection.preferredContentSizeCategory.rawValue]
                if let bytes = try? JSONSerialization.data(withJSONObject: notice, options: [.sortedKeys]) {
                    sink("[GlobalSearchFontDiagnostics] " + String(decoding: bytes, as: UTF8.self))
                }
            }
            return
        }
        observing = true
        defer { observing = false }
        var stack: [(view: UIView, path: String, depth: Int, hidden: Bool, alpha: CGFloat, scope: String)] =
            [(window, "0", 0, false, 1, "unidentified")]
        var rows: [[String: Any]] = []
        var visited = 0, labels = 0
        var nodesTruncated = false, labelsTruncated = false
        while visited < Self.nodeLimit, let node = stack.popLast() {
            visited += 1
            let hidden = node.hidden || node.view.isHidden
            let alpha = node.alpha * node.view.alpha
            let identifier = node.view.accessibilityIdentifier
            let scope = identifier.flatMap { Self.knownIdentifiers.contains($0) ? $0 : nil } ?? node.scope
            if let label = node.view as? UILabel {
                labels += 1
                if rows.count < Self.labelLimit {
                    let font: UIFont? = label.font
                    let rect = label.convert(label.bounds, to: window)
                    rows.append([
                        "path": node.path, "class": String(NSStringFromClass(type(of: label)).prefix(160)),
                        "knownScope": scope, "hiddenOnPath": hidden, "effectiveAlpha": Self.number(alpha),
                        "isAccessibilityElement": label.isAccessibilityElement,
                        "windowIntersection": rect.intersects(window.bounds), "windowFrame": Self.rect(rect),
                        "contentSizeCategory": label.traitCollection.preferredContentSizeCategory.rawValue,
                        "adjustsFontForContentSizeCategory": label.adjustsFontForContentSizeCategory,
                        "fontName": Self.boundedString(font?.fontName),
                        "fontPointSize": Self.number(font?.pointSize), "fontLineHeight": Self.number(font?.lineHeight),
                        "fontTextStyle": Self.boundedString(font?.fontDescriptor.object(forKey: .textStyle) as? String)
                    ])
                } else { labelsTruncated = true }
            }
            let children = node.view.subviews
            if node.depth >= 24 { nodesTruncated = nodesTruncated || !children.isEmpty; continue }
            for index in children.indices.reversed() {
                guard stack.count + visited < Self.nodeLimit else { nodesTruncated = true; break }
                stack.append((children[index], node.path + "/" + String(index), node.depth + 1, hidden, alpha, scope))
            }
        }
        nodesTruncated = nodesTruncated || !stack.isEmpty
        var record: [String: Any] = [
            "event": "font_snapshot", "schemaVersion": 1, "namespace": namespace,
            "fieldCategory": field.traitCollection.preferredContentSizeCategory.rawValue,
            "windowCategory": window.traitCollection.preferredContentSizeCategory.rawValue,
            "windowIsKey": window.isKeyWindow, "windowBounds": Self.rect(window.bounds),
            "windowHasScene": window.windowScene != nil,
            "windowSceneForeground": window.windowScene?.activationState == .foregroundActive,
            "nodesVisited": visited, "labelsObserved": labels, "nodeLimit": Self.nodeLimit,
            "labelLimit": Self.labelLimit, "truncatedNodes": nodesTruncated,
            "truncatedLabels": labelsTruncated, "metadataStringsLimitedTo": 160, "labels": rows
        ]
        guard let signature = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]),
              signature != previous else { return }
        record["phase"] = phase.rawValue
        record["snapshot"] = snapshots + 1
        var bytes = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
        while let data = bytes, data.count > Self.byteLimit, !rows.isEmpty {
            rows.removeLast()
            record["labels"] = rows
            record["truncatedLabels"] = true
            record["truncatedBytes"] = true
            bytes = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
        }
        guard let bytes, bytes.count <= Self.byteLimit else { return }
        previous = signature
        snapshots += 1
        sink("[GlobalSearchFontDiagnostics] " + String(decoding: bytes, as: UTF8.self))
    }

    private static func number(_ value: CGFloat?) -> Any {
        guard let value, value.isFinite else { return NSNull() }
        return Double(value)
    }
    private static func boundedString(_ value: String?) -> Any {
        guard let value else { return NSNull() }
        return String(value.prefix(160))
    }
    private static func rect(_ rect: CGRect) -> [Any] {
        [number(rect.minX), number(rect.minY), number(rect.width), number(rect.height)]
    }
}
#endif

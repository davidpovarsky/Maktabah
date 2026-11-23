import CommandPalette
import SwiftUI

struct LibraryCommandPaletteAdapter: View {
    @Bindable var manager: iOSNavigationManager
    var isActive = true
    var drawsSurface = true
    let onDismiss: () -> Void

    private var commands: [Command] {
        // This is the original library's canonical filtered book membership, not another
        // search model or a second search-history store. IDs include the canonical locator.
        let books = manager.libraryViewModel.bookLookup.values.map(\.book)
        var seen = Set<String>()
        return books.sorted { $0.book.localizedStandardCompare($1.book) == .orderedAscending }.compactMap { book in
            let id = book.backendLocator?.persistenceKey ?? "book:\(book.id)"
            guard seen.insert(id).inserted else { return nil }
            return Command(book.book, id: id, section: "ספרים", symbol: "book.closed") {
                manager.openBook(book)
            }
        }
    }

    var body: some View {
        palette
    }

    private var palette: some View {
        CommandPaletteView(
            commands: commands,
            placeholder: "חפש ספר בספרייה…",
            initialQuery: manager.libraryViewModel.searchQuery,
            autofocus: true,
            isActive: isActive,
            drawsSurface: drawsSurface,
            queryBinding: Bindable(manager.libraryViewModel).searchQuery,
            onDismiss: onDismiss
        )
        .accessibilityIdentifier("reader-library-command-palette")
        #if DEBUG
        .onReceive(NotificationCenter.default.publisher(for: .init("ChavrusaCommandPaletteEscapeObservation"))) {
            LibraryCommandPaletteEscapeObservation.recordField($0)
        }
        .onAppear { LibraryCommandPaletteEscapeObservation.recordHost(.adapterAppeared) }
        .onDisappear { LibraryCommandPaletteEscapeObservation.recordHost(.adapterDisappeared) }
        #endif
    }
}

#if DEBUG
/// Passive, bounded, disposable-fixture trace. Release has no observer or writer.
@MainActor
enum LibraryCommandPaletteEscapeObservation {
    enum HostStage: String {
        case adapterAppeared = "adapter.appeared"
        case adapterDisappeared = "adapter.disappeared"
        case readerOpenEnter = "reader.open.enter"
        case readerOpenReturned = "reader.open.returned"
        case readerCloseEnter = "reader.close.enter"
        case readerCloseReturned = "reader.close.returned"
        case readerStateChanged = "reader.state.changed"
        case viewerOpenEnter = "viewer.open.enter"
        case viewerOpenReturned = "viewer.open.returned"
        case viewerCloseEnter = "viewer.close.enter"
        case viewerCloseReturned = "viewer.close.returned"
        case viewerStateChanged = "viewer.state.changed"
    }

    private static let fieldStages: Set<String> = [
        "field.attached", "field.focus.before", "field.focus.after",
        "field.didBegin", "field.didEnd", "field.dismantle.before", "field.dismantle.after",
        "key.commands", "key.can.escape", "key.presses", "key.insert.escape", "key.command.escape",
        "dismiss.enter", "dismiss.admitted", "dismiss.resigned", "dismiss.returned"
    ]
    private static let fieldFlags = [
        "firstResponder", "windowAttached", "keyWindow", "sceneForeground", "hasCallback", "wantsFocus"
    ]
    private static let repeatedStages: Set<String> = [
        "key.commands", "key.can.escape", "field.focus.before", "field.focus.after"
    ]
    private static var lastRepeated: [String: String] = [:]
    private static var eventCount = 0

    private static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["OTZARIA_DATA_PROFILE"] == "miniTest10"
            && OtzariaDataProfileRegistry.activeProfileID == "miniTest10"
            && ProcessInfo.processInfo.arguments.contains("-CommandPaletteEscapeTraceEnabled")
            && UserDefaults.standard.bool(forKey: "CommandPaletteEscapeTraceEnabled")
            && UserDefaults.standard.string(forKey: "studyWorkspaceTestingNamespace")
                .flatMap(UUID.init(uuidString:)) != nil
    }

    static func recordField(_ notification: Notification) {
        guard isEnabled, let values = notification.userInfo,
              let stage = values["stage"] as? String, fieldStages.contains(stage),
              Set(values.keys.compactMap { $0 as? String }).count == values.count,
              Set(values.keys.compactMap { $0 as? String })
                .isSubset(of: Set(fieldFlags + ["stage", "accepted", "escapeKeyCode"])) else { return }
        var flags: [String: Bool] = [:]
        for name in fieldFlags {
            guard let value = values[name] as? Bool else { return }
            flags[name] = value
        }
        if values["accepted"] != nil {
            guard let accepted = values["accepted"] as? Bool else { return }
            flags["accepted"] = accepted
        }
        var code: Int?
        if values["escapeKeyCode"] != nil {
            guard let observed = values["escapeKeyCode"] as? Int, observed == 41,
                  stage == "key.insert.escape" || stage == "key.command.escape"
                    || (stage == "key.presses" && flags["accepted"] == true) else { return }
            code = observed
        }
        record(stage: stage, flags: flags, escapeKeyCode: code)
    }

    static func recordHost(_ stage: HostStage, presented: Bool? = nil, focus: Bool? = nil) {
        guard isEnabled else { return }
        var flags: [String: Bool] = [:]
        if let presented { flags["presented"] = presented }
        if let focus { flags["quickFieldFocused"] = focus }
        record(stage: stage.rawValue, flags: flags)
    }

    private static func record(stage: String, flags: [String: Bool], escapeKeyCode: Int? = nil) {
        let flagsText = flags.keys.sorted().map { "\($0)=\(flags[$0] == true ? 1 : 0)" }.joined(separator: " ")
        let suffix = flagsText + (escapeKeyCode.map { " escapeKeyCode=\($0)" } ?? "")
        if repeatedStages.contains(stage) {
            guard lastRepeated[stage] != suffix else { return }
            lastRepeated[stage] = suffix
        }
        // Bound diagnostics independently of keyboard/UI correctness. A capped
        // trace is incomplete evidence; it never changes a branch or acceptance.
        guard eventCount < 256 else {
            if eventCount == 256 {
                OtzariaFileLogger.shared.log("[NativePaletteEscape] pid=\(ProcessInfo.processInfo.processIdentifier) stage=trace.limit")
                eventCount += 1
            }
            return
        }
        eventCount += 1
        OtzariaFileLogger.shared.log(
            "[NativePaletteEscape] pid=\(ProcessInfo.processInfo.processIdentifier) seq=\(eventCount) stage=\(stage) \(suffix)")
    }
}
#endif

/// The owner's compactSearchField, with only library-domain text/icon/binding substituted.
struct SafariLibrarySearchField: View {
    @Binding var query: String
    var quickAddressFocused: FocusState<Bool>.Binding
    let onExpand: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: "books.vertical")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("חיפוש בספרייה", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused(quickAddressFocused)
                // A native toolbar's TextField consumes its ancestor's tap.
                // Observe the same tap without replacing the original field
                // or changing the supplied source's appearance/focus behavior.
                .simultaneousGesture(TapGesture().onEnded { _ in onExpand() })
                .submitLabel(.search)
                .onSubmit(onExpand)
                .accessibilityLabel("חיפוש בספרייה")
                .accessibilityIdentifier("reader-library-search-field")
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .contentShape(RoundedRectangle(cornerRadius: 26))
        .onTapGesture(perform: onExpand)
        .modifier(SafariGlass(radius: 26))
    }
}


/// The owner's stable outer-shell morph, mounted over the existing whole split
/// view. Both children keep their natural sizes; only the outer bounds/corners
/// and child visibility change. The original native Button activates compact
/// mode, and the original CommandPalette owns expanded input/results.
struct ReaderLibrarySearchMorph: View {
    let manager: iOSNavigationManager
    @Bindable var sidebar: ReaderSidebarPageCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var motionOffset: CGSize = .zero
    @State private var motionStretch = CGSize(width: 1, height: 1)

    private var isExpanded: Bool { sidebar.librarySearchIsPresented }
    private var morphAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.52, dampingFraction: 0.86)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { sidebar.dismissLibrarySearch() }
                    .allowsHitTesting(isExpanded)
                    .accessibilityHidden(true)

                if let frames = sidebar.librarySearchFrames, sidebar.navigationChrome.isVisible {
                    let compact = frames.anchor.offsetBy(
                        dx: -frames.container.minX, dy: -frames.container.minY)
                    let expandedWidth = min(CGFloat(640), max(0, geometry.size.width - 24))
                    let expandedX = min(max(12, compact.midX - expandedWidth / 2),
                                        max(12, geometry.size.width - expandedWidth - 12))
                    let expandedY = max(0, compact.minY)
                    let expandedHeight = min(CGFloat(560), max(0, geometry.size.height - expandedY - 12))

                    searchShell(compact: compact, expandedWidth: expandedWidth, expandedHeight: expandedHeight)
                        .scaleEffect(
                            x: reduceMotion || !isExpanded ? 1 : motionStretch.width,
                            y: reduceMotion || !isExpanded ? 1 : motionStretch.height,
                            anchor: .top)
                        .scaleEffect(!reduceMotion && !isExpanded && sidebar.librarySearchIsPressed ? 1.01 : 1)
                        // UIWindow coordinates have a physical left origin.
                        // Position the center directly; a topLeading offset
                        // would add a mirrored layout origin in Hebrew RTL.
                        // The children retain their inherited layout direction.
                        .position(
                            x: (isExpanded ? expandedX + expandedWidth / 2 : compact.midX)
                                + (reduceMotion || !isExpanded ? 0 : motionOffset.width),
                            y: (isExpanded ? expandedY + expandedHeight / 2 : compact.midY)
                                + (reduceMotion || !isExpanded ? 0 : motionOffset.height))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .background {
                ReaderToolbarFrameReader(tracksPosition: isExpanded) { owner, frame, window in
                    sidebar.observeLibrarySearchContainer(owner: owner, frame: frame, window: window)
                }
                .accessibilityHidden(true)
            }
        }
        // Include the native toolbar in this overlay's genuine hit-test bounds.
        // Keyboard avoidance remains active; only container top safe area expands.
        .ignoresSafeArea(.container, edges: .top)
        .allowsHitTesting(isExpanded)
        .animation(morphAnimation, value: isExpanded)
        .animation(reduceMotion ? nil : .smooth(duration: 0.2), value: sidebar.librarySearchIsPressed)
        .onChange(of: isExpanded) { _, expanded in
            if !expanded {
                motionOffset = .zero
                motionStretch = CGSize(width: 1, height: 1)
            }
        }
        .onChange(of: reduceMotion) { _, reduced in
            if reduced {
                motionOffset = .zero
                motionStretch = CGSize(width: 1, height: 1)
            }
        }
        .onDisappear { sidebar.dismissLibrarySearch() }
    }

    private func searchShell(compact: CGRect, expandedWidth: CGFloat, expandedHeight: CGFloat) -> some View {
        let radius = isExpanded ? CGFloat(28) : compact.height / 2
        return ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                LibrarySearchMotionHandle(offset: $motionOffset, stretch: $motionStretch)
                    .frame(height: 16)
                LibraryCommandPaletteAdapter(manager: manager, isActive: isExpanded, drawsSurface: false) {
                    sidebar.dismissLibrarySearch()
                }
                .frame(height: max(0, expandedHeight - 16), alignment: .top)
            }
            .frame(width: expandedWidth, height: expandedHeight, alignment: .topLeading)
            .opacity(isExpanded ? 1 : 0)
            .allowsHitTesting(isExpanded)
            .accessibilityHidden(!isExpanded)

            compactContents(width: compact.width)
                .frame(width: compact.width, height: compact.height)
                .opacity(isExpanded ? 0 : 1)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .frame(width: isExpanded ? expandedWidth : compact.width,
               height: isExpanded ? expandedHeight : compact.height,
               alignment: .topLeading)
        .modifier(SafariGlass(radius: radius))
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .accessibilityIdentifier("reader-library-search-morph-shell")
    }

    private func compactContents(width: CGFloat) -> some View {
        HStack(spacing: 10) {
            if width >= 140 {
                Image(systemName: "books.vertical")
                    .foregroundStyle(.secondary)
                Text(manager.libraryViewModel.searchQuery.isEmpty
                     ? "חיפוש בספרייה" : manager.libraryViewModel.searchQuery)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            }
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, width >= 140 ? 16 : 0)
    }
}

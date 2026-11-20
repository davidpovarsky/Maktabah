import CommandPalette
import SwiftUI

struct LibraryCommandPaletteAdapter: View {
    @Bindable var manager: iOSNavigationManager
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

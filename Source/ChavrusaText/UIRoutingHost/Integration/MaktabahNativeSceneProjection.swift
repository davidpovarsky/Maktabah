#if os(iOS)
import Foundation
import SwiftUI
import UIKit
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

/// Read-only projection of the existing native controls and reader. This file
/// belongs to the app target (manager-owned membership), not the portable SPM
/// target. It neither saves reader state nor resolves a requested locator.
@MainActor
struct MaktabahNativeSceneProjection {
    enum Surface { case library, tableOfContents, reader, history, search, searchResults, annotations, settings, inspector, noteDraft }
    let manager: iOSNavigationManager
    let selectedTab: iOSTab
    let columnVisibility: NavigationSplitViewVisibility
    let settingsPresented: Bool
    let sidebar: ReaderSidebarPageCoordinator?
    let workspace: StudyWorkspaceNavigationAdapter?

    private var activeTab: iOSNavigationManager.ReaderTab? {
        guard let id = manager.activeTabId else { return nil }
        // Never substitute a first tab for a missing/stale active ID.
        return manager.openTabs.first { $0.id == id }
    }
    private func stable(_ id: UUID?) -> UIStableID? { id.flatMap { UIStableID(rawValue: $0.uuidString) } }
    private func id(_ value: String) -> UIDestinationID { UIDestinationID(rawValue: value)! }

    func identity() throws -> NativeSceneIdentity {
        let reader = activeTab?.viewModel
        let section = try reader?.currentLocator.map(ActionAppIdentityBridge.actionRef)
        var selection: UIUTF16Range?
        if let range = reader?.readerState.selectedRange, range.location != NSNotFound {
            guard let location = UInt64(exactly: range.location), let length = UInt64(exactly: range.length) else {
                throw UIRouteError(.unavailable, "native_selection_unavailable")
            }
            selection = .init(location: location, length: length)
        }
        let sidebarVisible: Bool? = columnVisibility == .all || columnVisibility == .doubleColumn ? true : columnVisibility == .detailOnly ? false : nil
        let state = UIStateSpec(workspaceID: stable(workspace?.selection?.groupID), profileID: stable(workspace?.selection?.profileID),
                               selectedItemID: sidebar?.page == .contents ? stable(activeTab?.id) : nil,
                               sidebarVisible: sidebarVisible, inspectorVisible: reader?.readerInspectorVisible,
                               sheet: settingsPresented ? id("native.settings") : nil)
        return .init(topLevel: selectedTab.canonical.rawValue, activeTabID: stable(manager.activeTabId), section: section,
                     selectedRange: selection, state: state, libraryQuery: manager.libraryViewModel.searchQuery, globalQuery: manager.searchText)
    }

    /// Only return states which can actually be observed from this host. Unknown
    /// compact-column visibility, unread content or source mismatch stays nil.
    func surface(_ surface: Surface) throws -> NativeSurfaceState? {
        let state = UIStateSpec(workspaceID: stable(workspace?.selection?.groupID),
            profileID: stable(workspace?.selection?.profileID), selectedItemID: nil)
        switch surface {
        case .settings:
            guard settingsPresented else { return nil }
            return .init(destination: id("native.settings"), presentation: .init(kind: .sheet), content: nil, state: state, focus: nil)
        case .history:
            guard !settingsPresented, selectedTab.canonical == .history, manager.currentMode == .history,
                  HistoryViewModel.shared.searchText.isEmpty else { return nil }
            return .init(destination: id("native.history"), presentation: .init(), content: nil, state: state, focus: nil)
        case .searchResults:
            let search = manager.unifiedSearchSession
            guard !settingsPresented, MaktabahNativeRootDestination.search.isAvailable,
                  selectedTab.canonical == .search, manager.currentMode == .search,
                  search.hasSubmitted, !search.isSearching, !search.resultsAreDirty,
                  search.errorMessage == nil else { return nil }
            return .init(destination: id("native.search.results"), presentation: .init(),
                         content: nil, state: state, focus: nil)
        case .search, .annotations:
            let root: MaktabahNativeRootDestination = surface == .search ? .search : .annotations
            guard !settingsPresented, root.isAvailable,
                  selectedTab.canonical == root.tab, manager.currentMode == root.tab.appMode else { return nil }
            // Existing private query/note state remains in its original owner.
            // Opening a root never submits a query, creates a draft or writes data.
            return .init(destination: id(root.rawValue), presentation: .init(), content: nil, state: state, focus: nil)
        case .library, .tableOfContents:
            guard !settingsPresented, selectedTab.canonical == .viewer, manager.currentMode == .viewer else { return nil }
            if let sidebar {
                let page: ReaderSidebarPageCoordinator.Page = surface == .library ? .library : .contents
                guard sidebar.page == page,
                      columnVisibility == .all || columnVisibility == .doubleColumn else { return nil }
                if surface == .tableOfContents {
                    guard MaktabahNativeSceneBindings.hasOriginalTableOfContents(manager) else { return nil }
                }
            } else {
                // Original compact Library is a NavigationStack root; its
                // pushed Reader must be gone before this surface can be visible.
                guard surface == .library, !MaktabahApp.isIpad, manager.selectedBook == nil else { return nil }
            }
            let destination = surface == .library ? "native.library" : "native.reader.toc"
            // Public v2 already defines currentTab roots. No new wire format,
            // private tab identity, or guessed sidebar state is introduced.
            // The exact original page plus its independent UIKit witness must
            // actually be visible before it can acknowledge this root.
            return .init(destination: id(destination), presentation: .init(),
                         content: nil, state: state, focus: nil)
        case .noteDraft:
            guard !settingsPresented, selectedTab.canonical == .viewer, manager.currentMode == .viewer,
                  MaktabahNativeInspectorBinding.currentReader(in: manager) != nil else { return nil }
            // The session additionally requires its exact unsaved original
            // editor binding, live UITextView and independent UIKit witness.
            return .init(destination: id("native.reader.noteDraft"), presentation: .init(kind: .sheet),
                content: nil, state: state, focus: nil)
        case .inspector:
            guard !settingsPresented, selectedTab.canonical == .viewer,
                  let reader = MaktabahNativeInspectorBinding.currentReader(in: manager),
                  reader.readerInspectorVisible else { return nil }
            return .init(destination: id("native.reader.inspector"), presentation: .init(kind: .inspector),
                content: nil, state: .init(workspaceID: state.workspaceID, profileID: state.profileID,
                                          inspectorVisible: true), focus: nil)
        case .reader:
            guard !settingsPresented, selectedTab.canonical == .viewer, manager.currentMode == .viewer,
                  let tab = activeTab, let destination = tab.viewModel.currentDestination,
                  let actual = tab.viewModel.backendSection?.locator,
                  actual == destination.sectionLocator,
                  actual.backend == BackendCoordinator.shared.activeBackendID,
                  tab.book.backendLocator?.workKey == actual.workKey,
                  !tab.viewModel.contentText.isEmpty else { return nil }
            let newlyCreated = workspace?.hasCommittedNativeReader(tabID: tab.id) == true
            let content = ActionReaderDestination(sectionLocator: try ActionAppIdentityBridge.actionRef(actual),
                focusLocator: try destination.focusLocator.map(ActionAppIdentityBridge.actionRef),
                presentationMode: newlyCreated ? .newTab : .sameTab)
            let actualState = UIStateSpec(workspaceID: state.workspaceID, profileID: state.profileID,
                                          inspectorVisible: tab.viewModel.readerInspectorVisible)
            // This describes model state only. The scene session separately
            // requires its original TextKit text/viewport witness before an
            // observation can acknowledge this content or focused segment.
            return .init(destination: id("native.reader"), presentation: .init(kind: newlyCreated ? .newTab : .currentTab, tabID: stable(tab.id)),
                         content: content, state: actualState, focus: nil)
        }
    }

    /// Read metadata from the exact loaded original Reader for a bounded user
    /// consent offer. This is independent of the stricter native-route receipt:
    /// Otzaria may load the containing unit for an exact requested source line.
    struct HanlinCurrentWorkReadSource: Equatable {
        let readerOwner: ObjectIdentifier
        let requestToken: ReaderContentRequestToken
        let requested: LibraryReaderDestination
        let loaded: LibraryReaderDestination
    }

    func hanlinCurrentWorkReadSource() throws -> HanlinCurrentWorkReadSource? {
        try Task.checkCancellation()
        guard !settingsPresented, selectedTab.canonical == .viewer, manager.currentMode == .viewer,
              BackendCoordinator.shared.activeBackendID == .otzaria,
              let activeID = manager.activeTabId else { return nil }
        let tabs = manager.openTabs.filter { $0.id == activeID }
        guard tabs.count == 1, let tab = tabs.first,
              MaktabahApp.isIpad || manager.selectedBook === tab.book,
              let book = tab.book.backendLocator, book.backend == .otzaria,
              tab.viewModel.currentBook?.id == tab.book.id,
              tab.viewModel.currentBook?.backendLocator == book,
              case .loaded = tab.viewModel.state,
              let requested = tab.viewModel.currentDestination,
              requested.sectionLocator.backend == book.backend,
              requested.sectionLocator.workKey == book.workKey,
              let section = tab.viewModel.backendSection,
              section.locator.backend == book.backend, section.locator.workKey == book.workKey,
              let render = tab.viewModel.backendRenderModel, !render.text.isEmpty,
              (render.text as NSString).isEqual(to: tab.viewModel.contentText),
              let token = tab.viewModel.contentLoadCoordinator.currentRequestToken(),
              token.backend == book.backend, token.workKey == book.workKey,
              token.sectionLocator == requested.sectionLocator,
              section.segments.allSatisfy({
                  $0.locator.backend == book.backend && $0.locator.workKey == book.workKey
              }) else { return nil }

        func containsRenderedSource(_ locator: TextLocator) -> Bool {
            let source = section.segments.filter { $0.locator == locator }
            let rendered = render.renderedSegments.filter { $0.locator == locator }
            return source.count == 1 && rendered.count == 1
                && rendered[0].segment == source[0] && rendered[0].visualRange.length > 0
        }
        if requested.sectionLocator != section.locator {
            guard case .legacyLine(let requestedLine) = requested.sectionLocator.position, requestedLine >= 0,
                  case .legacyLine(let loadedLine) = section.locator.position, loadedLine >= 0,
                  containsRenderedSource(requested.sectionLocator) else { return nil }
        }
        if let focus = requested.focusLocator {
            guard focus.backend == book.backend, focus.workKey == book.workKey,
                  containsRenderedSource(focus) else { return nil }
        }
        guard tab.viewModel.contentLoadCoordinator.canApplyContent(token: token, currentBookLocator: book) else { return nil }
        return .init(readerOwner: ObjectIdentifier(tab.viewModel), requestToken: token, requested: requested,
            loaded: .init(sectionLocator: section.locator, focusLocator: requested.focusLocator))
    }

    /// Independently read the original rendered view. NativeSurfaceWitness
    /// separately proves container visibility, presentation and scene ownership.
    func hasRenderedReaderEvidence(sceneID: UIStableID) -> Bool {
        guard let tab = activeTab, let section = tab.viewModel.backendSection,
              let destination = tab.viewModel.currentDestination,
              section.locator == destination.sectionLocator,
              section.locator.backend == BackendCoordinator.shared.activeBackendID,
              tab.book.backendLocator?.workKey == section.locator.workKey,
              let observe = tab.viewModel.isNativeReaderTextVisible else { return false }
        guard case .loaded = tab.viewModel.state else { return false }
        let sourceRange: NSRange?
        if let focus = destination.focusLocator {
            guard focus.backend == section.locator.backend,
                  focus.workKey == section.locator.workKey,
                  let range = tab.viewModel.backendRenderModel?.renderedSegment(for: focus)?.visualRange else { return false }
            sourceRange = range
        } else { sourceRange = nil }
        return observe(sceneID.rawValue, sourceRange)
    }
}

// BEGIN SELF-CONTAINED NATIVE READER TEXT VISIBILITY
/// Read-only proof from the existing UITextView, with its original renderer's
/// source-to-display mapping. It never scrolls, selects, mutates or renders text.
@MainActor
enum ReaderNativeTextVisibility {
    static func isVisible(textView: UITextView, sceneID: String,
                          expectedSource: String, renderedSource: String, renderedText: String,
                          sourceRange: NSRange?, displayedRange: (NSRange) -> NSRange) -> Bool {
        guard !expectedSource.isEmpty, !renderedText.isEmpty,
              (expectedSource as NSString).isEqual(to: renderedSource),
              (renderedText as NSString).isEqual(to: textView.textStorage.string),
              let window = textView.window, let scene = window.windowScene,
              scene.session.persistentIdentifier == sceneID,
              scene.activationState == .foregroundActive,
              !textView.isHidden, textView.alpha > 0,
              textView.bounds.width > 1, textView.bounds.height > 1 else { return false }
        var ancestor = textView.superview
        while let current = ancestor {
            guard !current.isHidden, current.alpha > 0 else { return false }
            ancestor = current.superview
        }
        let viewport = textView.bounds.inset(by: textView.adjustedContentInset)
        guard !viewport.isEmpty,
              textView.convert(viewport, to: window).intersects(window.bounds) else { return false }
        let glyphs: NSRange
        if let sourceRange {
            let sourceLength = (renderedSource as NSString).length
            guard valid(sourceRange, length: sourceLength) else { return false }
            let range = displayedRange(sourceRange)
            guard valid(range, length: textView.textStorage.length) else { return false }
            // Require the focus's first rendered glyph in the actual viewport;
            // a model range or a distant part of a long paragraph is insufficient.
            let first = NSRange(location: range.location, length: 1)
            textView.layoutManager.ensureLayout(forCharacterRange: first)
            glyphs = textView.layoutManager.glyphRange(forCharacterRange: first, actualCharacterRange: nil)
        } else {
            // Non-focused reads also require a real glyph in the viewport.
            // UIKit returns a range whose first/last glyph intersects this rect.
            let containerViewport = viewport.offsetBy(dx: -textView.textContainerInset.left,
                                                       dy: -textView.textContainerInset.top)
            let visible = textView.layoutManager.glyphRange(forBoundingRect: containerViewport, in: textView.textContainer)
            guard visible.length > 0 else { return false }
            glyphs = NSRange(location: visible.location, length: 1)
        }
        guard glyphs.length > 0 else { return false }
        let rect = textView.layoutManager.boundingRect(forGlyphRange: glyphs, in: textView.textContainer)
            .offsetBy(dx: textView.textContainerInset.left, dy: textView.textContainerInset.top)
        guard !rect.isEmpty, rect.origin.x.isFinite, rect.origin.y.isFinite,
              rect.width.isFinite, rect.height.isFinite else { return false }
        guard viewport.insetBy(dx: -1, dy: -1).intersects(rect),
              textView.convert(rect, to: window).intersects(window.bounds) else { return false }
        var clippingAncestor = textView.superview
        while let current = clippingAncestor {
            if current.clipsToBounds && !textView.convert(rect, to: current).intersects(current.bounds) { return false }
            clippingAncestor = current.superview
        }
        return true
    }

    private static func valid(_ range: NSRange, length: Int) -> Bool {
        range.location != NSNotFound && range.location >= 0 && range.length > 0
            && range.location <= length && range.length <= length - range.location
    }
}
// END SELF-CONTAINED NATIVE READER TEXT VISIBILITY
#endif

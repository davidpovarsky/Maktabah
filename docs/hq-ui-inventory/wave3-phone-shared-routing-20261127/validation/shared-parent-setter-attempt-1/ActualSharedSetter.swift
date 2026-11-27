func presentOriginalPhoneTOCReader(_ tab: iOSNavigationManager.ReaderTab) throws {
        let matches = manager.openTabs.filter { $0.id == tab.id }
        guard !MaktabahApp.isIpad, !showSettings.wrappedValue, isPresentationReady,
              MaktabahNativeRootDestination.library.isAvailable,
              manager.activeTabId == tab.id, matches.count == 1, let original = matches.first,
              original.book === tab.book, original.viewModel === tab.viewModel,
              manager.selectedBook == nil || manager.selectedBook === tab.book,
              let revision = manager.selectedBookPresentationRevision else {
            throw UIRouteError(.staleState, "native_phone_toc_reader_owner_changed")
        }
        let assignsBook = manager.selectedBook !== tab.book || manager.selectedBookPresentationMode != .viewer
        guard !assignsBook || revision < .max else {
            throw UIRouteError(.staleState, "native_phone_toc_presentation_exhausted")
        }
        let expectedRevision = assignsBook ? revision + 1 : revision
        selectedTab.wrappedValue = .viewer
        // selectedBook.didSet captures the ORIGINAL currentMode synchronously.
        manager.switchToMode(.viewer)
        if assignsBook { manager.selectedBook = tab.book }
        let after = manager.openTabs.filter { $0.id == tab.id }
        guard manager.activeTabId == tab.id, after.count == 1, let retained = after.first,
              retained.book === tab.book, retained.viewModel === tab.viewModel,
              manager.selectedBook === tab.book, manager.currentMode == .viewer,
              manager.selectedBookPresentationMode == .viewer,
              manager.selectedBookPresentationRevision == expectedRevision else {
            throw UIRouteError(.staleState, "native_phone_toc_reader_transition_changed")
        }
    }

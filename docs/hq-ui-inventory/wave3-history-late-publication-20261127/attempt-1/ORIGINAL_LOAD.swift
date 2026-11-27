    func loadBooksData() {
        let publicationLoad = beginQualifiedPublication()
        let hIds = historyOrder
        let fIds = favoriteBookIds
        let allNeededIds = Set(hIds).union(Set(fIds))

        let books = LibraryDataManager.shared.getBook(Array(allNeededIds))
        let booksDict = Dictionary(uniqueKeysWithValues: books.map { ($0.id, $0) })

        historyBooks = hIds.compactMap { booksDict[$0] }
        favoriteBooks = fIds.compactMap { booksDict[$0] }

        Task { [weak self] in
            let publicationEntries = await QualifiedLocatorStore.shared.entriesWithObservation()
            let qualified = publicationEntries.entries
            await MainActor.run {
                guard let self else { return }
                let active = BackendCoordinator.shared.activeBackendID
                if BackendCoordinator.shared.usesNativeMaktabahDataPath { return }
                let relevant = qualified.filter { $0.locator.backend == active }
                self.invalidateQualifiedPublication()
                self.historyBooks = relevant.filter { $0.lastOpened != .distantPast }.compactMap { entry in
                    MaktabahBackendAdapter.resolveBook(for: entry.locator, in: LibraryDataManager.shared)
                }
                self.favoriteBooks = relevant.filter(\.isFavorite).compactMap { entry in
                    MaktabahBackendAdapter.resolveBook(for: entry.locator, in: LibraryDataManager.shared)
                }
                self.completeQualifiedPublication(publicationLoad, entries: publicationEntries)
            }
        }
    }

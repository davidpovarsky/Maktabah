import SwiftUI

struct iOSLibraryView: View {
    @Environment(iOSNavigationManager.self) private var navigationManager

    @State private var viewModel = LibraryViewModel.shared

    private var singleDeleteBinding: Binding<Bool> {
        Binding(
            get: { viewModel.singleBookToDelete != nil },
            set: { if !$0 { viewModel.singleBookToDelete = nil } }
        )
    }

    private var importErrorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.importErrorMessage != nil },
            set: { if !$0 { viewModel.importErrorMessage = nil } }
        )
    }

    var body: some View {
        @Bindable var bindableViewModel = viewModel
        mainZStack(viewModel: viewModel)
            .navigationTitle(viewModel.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarLeading(viewModel: viewModel)
                toolbarTrailing(viewModel: viewModel)
            }
            .searchable(
                text: $bindableViewModel.searchText,
                isPresented: $bindableViewModel.isSearchPresented,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: Text(.Library.search)
            )
            .sheet(isPresented: $bindableViewModel.showingImportSheet) {
                BookImportSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $bindableViewModel.showingUpdateSheet) {
                BookUpdateSheet(viewModel: viewModel)
            }
            .alert(.Library.importError, isPresented: importErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.importErrorMessage ?? "")
            }
            .alert(.Library.deleteDownload, isPresented: $viewModel.showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    viewModel.confirmDeleteSelected()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(.Library.deleteDownloadedMultipleConfirmation(viewModel.selectedDeleteCount))
            }
            .alert(.Library.deleteDownload, isPresented: singleDeleteBinding) {
                Button("Delete", role: .destructive) {
                    if let book = viewModel.singleBookToDelete {
                        viewModel.deleteDownloadedBook(book)
                        viewModel.singleBookToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(.Library.deleteDownloadedSingleConfirmation(viewModel.singleBookToDelete?.book ?? ""))
            }
    }

    @ViewBuilder
    private func mainZStack(viewModel: LibraryViewModel) -> some View {
        ZStack {
            libraryVC(viewModel: viewModel)
                .themeTint()
                .ignoresSafeArea(edges: [.vertical])

            if viewModel.state == .loading {
                ProgressView(String(localized: "Loading Library..."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .themeBackground()
            }
        }
    }

    private func libraryVC(viewModel: LibraryViewModel) -> some View {
        LibraryViewControllerWrapper(
            navigationManager: navigationManager,
            viewModel: viewModel,
            showOnlyDownloaded: Binding(
                get: { viewModel.showOnlyDownloaded },
                set: { viewModel.showOnlyDownloaded = $0 }
            ),
            onDeleteSingleBook: { book in
                viewModel.singleBookToDelete = book
            },
            onDownloadSingleBook: { book in
                OtzariaLibraryImportActions.handleDownloadSingleBook(
                    book,
                    viewModel: viewModel,
                    navigationManager: navigationManager
                )
            },
            onShowBookInfo: { book in
                navigationManager.selectedBookForInfo = book
            }
        )
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private func toolbarLeading(viewModel: LibraryViewModel) -> some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if viewModel.isSelectionMode {
                Button(.Library.done) {
                    viewModel.exitSelectionMode()
                }
                .fontWeight(.semibold)
            } else {
                HStack(spacing: 8) {
                    viewModePicker(viewModel: viewModel)
                    filterButton(viewModel: viewModel)
                }
            }
        }
    }

    @ToolbarContentBuilder
    private func toolbarTrailing(viewModel: LibraryViewModel) -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if viewModel.isSelectionMode {
                selectionModeTrailing(viewModel: viewModel)
            } else {
                normalTrailingMenu(viewModel: viewModel)
            }
        }
    }

    // MARK: - Subviews

    private func viewModePicker(viewModel: LibraryViewModel) -> some View {
        Picker("View Mode", selection: Binding(
            get: { viewModel.viewMode },
            set: { viewModel.switchViewMode($0) }
        )) {
            ForEach(LibraryViewMode.allCases, id: \.self) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .fixedSize()
    }

    private func filterButton(viewModel: LibraryViewModel) -> some View {
        Button {
            viewModel.showOnlyDownloaded.toggle()
        } label: {
            Image(systemName: viewModel.showOnlyDownloaded ? "arrow.down.circle.fill" : "arrow.down.circle")
        }
    }

    private func normalTrailingMenu(viewModel: LibraryViewModel) -> some View {
        Menu {
            if !OtzariaLibraryImportActions.isEnabled {
                Button {
                    viewModel.enterSelectionMode()
                } label: {
                    Label(.Library.select, systemImage: "checkmark.circle")
                }

                Button {
                    viewModel.showingUpdateSheet = true
                } label: {
                    let bookUpdates = String(localized: .Library.booksUpdates)
                    Label(
                        viewModel.availableUpdateCount > 0
                            ? "\(bookUpdates) (\(viewModel.availableUpdateCount))"
                            : bookUpdates,
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                }

                Button {
                    viewModel.showingImportSheet = true
                } label: {
                    Label(String(localized: .Library.importBook), systemImage: "plus.viewfinder")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    private func selectionModeTrailing(viewModel: LibraryViewModel) -> some View {
        HStack(spacing: 12) {
            Menu {
                Button(.Library.selectAll) {
                    viewModel.selectAll()
                }
                Button(.Library.deselectAll) {
                    viewModel.deselectAll()
                }
            } label: {
                Image(systemName: "checklist")
            }

            if viewModel.hasSelection {
                let downloadSelected = String(localized: .Library.downloadSelected(viewModel.selectedDownloadCount))
                let deleteSelected = String(localized: .Library.deleteSelected(viewModel.selectedDeleteCount))

                Menu {
                    if viewModel.selectedDownloadCount > 0 {
                        Button {
                            handleBulkDownload(viewModel: viewModel)
                        } label: {
                            Label(downloadSelected, systemImage: "arrow.down.circle")
                        }
                    }

                    if viewModel.selectedDeleteCount > 0 {
                        Button(role: .destructive) {
                            viewModel.showingDeleteConfirmation = true
                        } label: {
                            Label(deleteSelected, systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    private func handleBulkDownload(viewModel: LibraryViewModel) {
        if AppConfig.isUsingBundleMode {
            let selectedBooks = viewModel.selectedBooksToDownload
            guard !selectedBooks.isEmpty else { return }

            ReusableFunc.showProgressAlert(
                title: String(localized: .Library.downloadBook),
                message: String(localized: .Library.beginDownloading),
                total: selectedBooks.count,
                onCancel: {
                    Task {
                        await CoreDatabaseDownloader.shared.cancelCurrentDownload()
                    }
                }
            )

            Task {
                await viewModel.bulkDownloadSelected()
            }
        } else {
            ReusableFunc.showConfirmationAlert(
                title: String(localized: .Library.downloadBook),
                message: String(localized: .Library.bulkDownloadWarning),
                confirmTitle: String(localized: .Library.download)
            ) {
                Task {
                    await viewModel.bulkDownloadSelected()
                }
            }
        }
    }
}

import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - SwiftUI View

struct iOSLibraryView: View {
    @Environment(iOSNavigationManager.self) private var navigationManager: iOSNavigationManager
    @State private var showingOtzariaImporter = false
    @State private var otzariaImportError: String?

    var body: some View {
        @Bindable var viewModel = navigationManager.libraryViewModel

        let importErrorBinding = Binding<Bool>(
            get: { viewModel.importErrorMessage != nil },
            set: { if !$0 { viewModel.importErrorMessage = nil } }
        )
        
        let singleDeleteBinding = Binding<Bool>(
            get: { viewModel.singleBookToDelete != nil },
            set: { if !$0 { viewModel.singleBookToDelete = nil } }
        )

        let otzariaErrorBinding = Binding<Bool>(
            get: { otzariaImportError != nil },
            set: { if !$0 { otzariaImportError = nil } }
        )

        mainZStack(viewModel: viewModel)
            .animation(.interpolatingSpring(stiffness: 300, damping: 20), value: navigationManager.activeIntegrationStates.count)
            .onChange(of: viewModel.selectedBookIds) { _, _ in
                handleSelectionChange(viewModel: viewModel)
            }
            .toolbar {
                toolbarContent(viewModel: viewModel)
            }
            .fileImporter(
                isPresented: $showingOtzariaImporter,
                allowedContentTypes: [.database, .data, .item],
                allowsMultipleSelection: false
            ) { result in
                handleOtzariaImport(result, viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingImportSheet) {
                NavigationView {
                    OfflineImportFormView { url, metadata, authorRow in
                        await viewModel.importOfflineBook(from: url, metadata: metadata, authorRow: authorRow)
                    }
                }
            }
            .alert(String(localized: "Import Success"), isPresented: $viewModel.showImportSuccessAlert) {
                Button(String(localized: "OK"), role: .cancel) {}
            } message: {
                Text(String(localized: .importSuccessDesc))
            }
            .alert(String(localized: "Import Error"), isPresented: importErrorBinding) {
                Button(String(localized: "OK"), role: .cancel) {}
            } message: {
                Text(viewModel.importErrorMessage ?? "")
            }
            .alert(String(localized: "Otzaria Database Error"), isPresented: otzariaErrorBinding) {
                Button(String(localized: "OK"), role: .cancel) {}
            } message: {
                Text(otzariaImportError ?? "")
            }
            .alert(String(localized: "Delete Download"), isPresented: $viewModel.showingDeleteConfirmation) {
                Button(String(localized: "Delete"), role: .destructive) {
                    viewModel.startBulkDeletion {}
                }
                Button(String(localized: "Cancel"), role: .cancel) {}
            } message: {
                Text(String(format: String(localized: "Are you sure you want to delete the downloaded content for %lld books?"), Int64(viewModel.selectedDeleteCount)))
            }
            .alert(String(localized: "Delete Download"), isPresented: singleDeleteBinding) {
                Button(String(localized: "Delete"), role: .destructive) {
                    if let book = viewModel.singleBookToDelete {
                        Task {
                            await viewModel.deleteSingleBook(book)
                            viewModel.singleBookToDelete = nil
                        }
                    }
                }
                Button(String(localized: "Cancel"), role: .cancel) {}
            } message: {
                Text(String(format: String(localized: "Are you sure you want to delete the downloaded content for \"%@\"?"), viewModel.singleBookToDelete?.book ?? ""))
            }
    }

    @ViewBuilder
    private func mainZStack(viewModel: LibraryViewModel) -> some View {
        ZStack {
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
                    if OtzariaMaktabahBridge.shared.isEnabled {
                        viewModel.selectBook(book, using: navigationManager)
                    } else {
                        navigationManager.showBookIntegrationConfirmation(
                            for: book,
                            initialContentId: nil
                        )
                    }
                }
            )
            .themeTint()
            .ignoresSafeArea(edges: [.vertical])

            if viewModel.state == .loading {
                ProgressView(String(localized: "Loading Library..."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .themeBackground()
            }

            if !navigationManager.activeIntegrationStates.isEmpty {
                VStack(spacing: 0) {
                    Spacer()
                    ActiveIntegrationStatesView()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(10)
            }
        }
    }

    private func handleSelectionChange(viewModel: LibraryViewModel) {
        guard !OtzariaMaktabahBridge.shared.isEnabled else { return }
        guard !viewModel.isBulkDownloading else { return }

        let downloadBooks = viewModel.selectedDownloadBooks
        if !downloadBooks.isEmpty {
            let hasBulkConfirmation = navigationManager.activeIntegrationStates.contains { state in
                if case .bulk = state.pendingData, state.mode == .confirmation { return true }
                return false
            }

            if !hasBulkConfirmation {
                navigationManager.showBulkDownloadConfirmation(books: downloadBooks)
            } else {
                if let bulkState = navigationManager.activeIntegrationStates.first(where: {
                    if case .bulk = $0.pendingData, $0.mode == .confirmation { return true }
                    return false
                }) {
                    navigationManager.activeIntegrationStates.removeAll { $0.id == bulkState.id }
                    navigationManager.showBulkDownloadConfirmation(books: downloadBooks)
                }
            }
        } else {
            navigationManager.activeIntegrationStates.removeAll { state in
                if case .bulk = state.pendingData, state.mode == .confirmation { return true }
                return false
            }
        }
    }

    @ToolbarContentBuilder
    private func toolbarContent(viewModel: LibraryViewModel) -> some ToolbarContent {
        if viewModel.isSelectionMode {
            ToolbarItem(placement: .topBarLeading) {
                Button(String(localized: "Done")) {
                    viewModel.exitSelectionMode()
                }
                .disabled(viewModel.isBulkDownloading)
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    viewModel.showingDeleteConfirmation = true
                } label: {
                    Label(String(localized: "Delete"), systemImage: "trash")
                }
                .disabled(viewModel.selectedDeleteCount == 0 || viewModel.isBulkDownloading)
                .tint(.red)
            }
        } else {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Section(String(localized: "Group By")) {
                        Button { viewModel.viewMode = .category } label: {
                            Label(String(localized: "Category"), systemImage: "folder")
                        }
                        Button { viewModel.viewMode = .author } label: {
                            Label(String(localized: "Author"), systemImage: "person")
                        }
                    }
                } label: {
                    Label(
                        String(localized: "Group By"),
                        systemImage: viewModel.viewMode == .category ? "folder" : "person"
                    )
                }
            }

            if !OtzariaMaktabahBridge.shared.isEnabled {
                ToolbarItem(placement: .topBarTrailing) {
                    Toggle(isOn: Binding(
                        get: { viewModel.showOnlyDownloaded },
                        set: { viewModel.showOnlyDownloaded = $0 }
                    )) {
                        Label(String(localized: "Downloaded"), systemImage: "line.3.horizontal.decrease")
                    }
                    .labelStyle(.iconOnly)
                    .toggleStyle(.button)
                }
            }

            CustomToolbarSpacer(placement: .topBarTrailing)

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingOtzariaImporter = true
                    } label: {
                        Label(String(localized: "Choose Otzaria Database"), systemImage: "externaldrive")
                    }

                    if OtzariaMaktabahBridge.shared.isEnabled {
                        Button(role: .destructive) {
                            OtzariaMaktabahBridge.shared.forgetDatabase()
                            DatabaseManager.shared.reloadConnectionAndLibrary()
                            Task { await viewModel.refreshLibrary() }
                        } label: {
                            Label(String(localized: "Disconnect Otzaria Database"), systemImage: "xmark.circle")
                        }
                    }

                    Divider()

                    Button {
                        viewModel.enterSelectionMode()
                    } label: {
                        Label(String(localized: "Select") + "...", systemImage: "checkmark.circle")
                    }
                    .disabled(OtzariaMaktabahBridge.shared.isEnabled)

                    Button {
                        viewModel.showingImportSheet = true
                    } label: {
                        Label(String(localized: "Import Book"), systemImage: "plus.viewfinder")
                    }
                    .disabled(OtzariaMaktabahBridge.shared.isEnabled)
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel(String(localized: "Library Options"))
                .help(String(localized: "Library Options"))
            }
        }
    }

    private func handleOtzariaImport(_ result: Result<[URL], Error>, viewModel: LibraryViewModel) {
        do {
            guard let url = try result.get().first else { return }
            try OtzariaMaktabahBridge.shared.installDatabase(from: url)
            DatabaseManager.shared.reloadConnectionAndLibrary()
            Task { await viewModel.refreshLibrary() }
        } catch {
            otzariaImportError = error.localizedDescription
        }
    }

    private func startSelectedDownloads(using viewModel: LibraryViewModel) {
        let state = BundleArchiveDownloadProgressState(
            title: NSLocalizedString("Download Book", comment: "Bulk download window title"),
            message: String(localized: "Begin downloading..."),
            mode: .downloading
        )
        navigationManager.activeIntegrationStates.append(state)

        viewModel.startBulkDownload(progressState: state) { message in
            navigationManager.activeIntegrationStates.removeAll { $0.id == state.id }
            viewModel.exitSelectionMode()

            if let message {
                navigationManager.alertMessage = iOSNavigationManager.AlertMessage(
                    title: NSLocalizedString("Download Book", comment: "Bulk download window title"),
                    message: message
                )
            }
        }
    }
}

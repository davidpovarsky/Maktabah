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
                OtzariaLibraryImportActions.handleSelectionChange(
                    viewModel: viewModel,
                    navigationManager: navigationManager
                )
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
                NavigationStack {
                    OfflineImportFormView { url, metadata, authorRow in
                        await viewModel.importOfflineBook(from: url, metadata: metadata, authorRow: authorRow)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingUpdateSheet) {
                UpdateView()
            }
            .task {
                viewModel.checkBookUpdatesPeriodically()
            }
            .alert("Import Success", isPresented: $viewModel.showImportSuccessAlert) {
                Button("OK", role: .cancel) {}
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
                    OtzariaLibraryImportActions.handleDownloadSingleBook(
                        book,
                        viewModel: viewModel,
                        navigationManager: navigationManager
                    )
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

    @ToolbarContentBuilder
    private func toolbarContent(viewModel: LibraryViewModel) -> some ToolbarContent {
        if viewModel.isSelectionMode {
            selectionToolbarItems(viewModel: viewModel)
        } else {
            standardToolbarItems(viewModel: viewModel)
        }
    }

    @ToolbarContentBuilder
    private func selectionToolbarItems(viewModel: LibraryViewModel) -> some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Done") {
                viewModel.exitSelectionMode()
            }
            .disabled(viewModel.isBulkDownloading)
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                viewModel.showingDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .disabled(viewModel.selectedDeleteCount == 0 || viewModel.isBulkDownloading)
            .tint(.red)
        }
    }

    @ToolbarContentBuilder
    private func standardToolbarItems(viewModel: LibraryViewModel) -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            groupByMenu(viewModel: viewModel)
        }

        ToolbarItem(placement: .topBarTrailing) {
            if !OtzariaLibraryImportActions.isEnabled && AppConfig.isUsingBundleMode {
                downloadedFilterToggle(viewModel: viewModel)
            }
        }

        CustomToolbarSpacer(placement: .topBarTrailing)

        ToolbarItem(placement: .topBarTrailing) {
            optionsMenu(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private func groupByMenu(viewModel: LibraryViewModel) -> some View {
        Menu {
            Section("Group By") {
                Button { viewModel.viewMode = .category } label: {
                    Label("Category", systemImage: "folder")
                }
                Button { viewModel.viewMode = .author } label: {
                    Label("Author", systemImage: "person")
                }
            }
        } label: {
            Label(
                "Group By",
                systemImage: viewModel.viewMode == .category ? "folder" : "person"
            )
        }
    }

    @ViewBuilder
    private func downloadedFilterToggle(viewModel: LibraryViewModel) -> some View {
        Toggle(isOn: Binding(
            get: { viewModel.showOnlyDownloaded },
            set: { viewModel.showOnlyDownloaded = $0 }
        )) {
            Label("Downloaded", systemImage: "line.3.horizontal.decrease")
        }
        .labelStyle(.iconOnly)
        .toggleStyle(.button)
    }

    @ViewBuilder
    private func optionsMenu(viewModel: LibraryViewModel) -> some View {
        Menu {
            Button {
                showingOtzariaImporter = true
            } label: {
                Label(String(localized: "Choose Otzaria Database"), systemImage: "externaldrive")
            }

            if OtzariaLibraryImportActions.isEnabled {
                Button(role: .destructive) {
                    OtzariaLibraryImportActions.disconnectDatabase(viewModel: viewModel)
                } label: {
                    Label(String(localized: "Disconnect Otzaria Database"), systemImage: "xmark.circle")
                }
            } else {
                Divider()

                Button {
                    viewModel.enterSelectionMode()
                } label: {
                    Label("Select".localized + "...", systemImage: "checkmark.circle")
                }

                Button {
                    viewModel.showingUpdateSheet = true
                } label: {
                    Label(
                        viewModel.availableUpdateCount > 0
                            ? "\("Update Books".localized) (\(viewModel.availableUpdateCount))"
                            : "Update Books".localized,
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                }

                Button {
                    viewModel.showingImportSheet = true
                } label: {
                    Label("Import Book", systemImage: "plus.viewfinder")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        .accessibilityLabel(String(localized: "Library Options"))
        .help(String(localized: "Library Options"))
    }

    private func handleOtzariaImport(_ result: Result<[URL], Error>, viewModel: LibraryViewModel) {
        do {
            try OtzariaLibraryImportActions.installDatabase(
                from: result,
                viewModel: viewModel
            )
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

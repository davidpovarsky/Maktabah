import SwiftUI

struct AuthorModeView: View {
    @Environment(iOSNavigationManager.self) private var navigationManager: iOSNavigationManager
    @StateObject private var backendCoordinator = BackendCoordinator.shared
    @State private var navigateToReader = false

    let onOpenBook: ((BooksData) -> Void)?

    init(onOpenBook: ((BooksData) -> Void)? = nil) {
        self.onOpenBook = onOpenBook
    }

    var body: some View {
        Group {
            if !backendCoordinator.activeCapabilities.contains(.authors) {
                ContentUnavailableView("Authors are not available for this library source",
                    systemImage: "person.2.slash")
            } else if OtzariaBackendActivation.isActive {
                OtzariaAuthorsModeView(onOpenBook: onOpenBook)
            } else {
                maktabahNarratorsView(viewModel: navigationManager.authorViewModel)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    @ViewBuilder
    private func maktabahNarratorsView(viewModel: NarratorViewModel) -> some View {
        Group {
            if viewModel.state == .loading {
                ProgressView("Loading Narrators...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .themeBackground()
            } else {
                iOSRowiSidebarView(viewModel: viewModel, searchQuery: viewModel.lastSearchQuery)
                    .themeTint()
                    .ignoresSafeArea(edges: [.vertical])
                    .onChange(of: viewModel.currentRowi) { _, newRowi in
                        if newRowi != nil {
                            navigateToReader = true
                        }
                    }
                    .navigationDestination(isPresented: $navigateToReader) {
                        iOSRowiReaderView(viewModel: viewModel)
                            .onDisappear {
                                viewModel.currentRowi = nil
                            }
                    }
                    .withActiveIntegrationStates()
            }
        }
        .task {
            await viewModel.loadData()
        }
    }
}

struct iOSRowiReaderView: View {
    @Bindable var viewModel: NarratorViewModel

    var body: some View {
        ThemeScrollView {
            Text(viewModel.rowiContentText)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .multilineTextAlignment(.trailing)
                .environment(\.layoutDirection, .rightToLeft)
                .padding()
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Picker("Mode", selection: $viewModel.displayMode) {
                    ForEach(RowiDisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .navigationTitle(viewModel.currentRowi?.isoName ?? "الراوي")
        .navigationBarTitleDisplayMode(.inline)
    }
}

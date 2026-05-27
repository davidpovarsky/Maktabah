import SwiftUI

struct AuthorModeView: View {
    @Environment(iOSNavigationManager.self) private var navigationManager: iOSNavigationManager
    @State private var navigateToReader = false

    var body: some View {
        let viewModel = navigationManager.authorViewModel

        Group {
            if viewModel.isLoading {
                ProgressView("Loading Narrators...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .themeBackground()
            } else {
                iOSRowiSidebarView(viewModel: viewModel, searchQuery: viewModel.lastSearchQuery)
                    .themeTint()
                    .ignoresSafeArea(edges: [.vertical])
                    .onChange(of: viewModel.selectedRowi) { _, newRowi in
                        if newRowi != nil {
                            navigateToReader = true
                        }
                    }
                    .navigationDestination(isPresented: $navigateToReader) {
                        iOSRowiReaderView(viewModel: viewModel)
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
    @Bindable var viewModel: iOSAuthorViewModel

    var body: some View {
        ThemeScrollView {
            Text(viewModel.rowiContentText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .environment(\.layoutDirection, .rightToLeft)
                .padding()
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                // Segmented Control Toolbar
                Picker("Mode", selection: $viewModel.displayMode) {
                    ForEach(iOSRowiDisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .navigationTitle(viewModel.selectedRowi?.isoName ?? "الراوي")
        .navigationBarTitleDisplayMode(.inline)
    }
}

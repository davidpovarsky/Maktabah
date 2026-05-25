import SwiftUI
import Combine

struct AuthorModeView: View {
    @Environment(iOSNavigationManager.self) private var navigationManager: iOSNavigationManager
    @StateObject private var viewModel = iOSAuthorViewModel()
    @State private var navigateToReader = false
    @State private var searchSubject = PassthroughSubject<String, Never>()
    @State private var debouncedQuery: String = ""

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading Narrators...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .themeBackground()
            } else {
                iOSRowiSidebarView(viewModel: viewModel, searchQuery: debouncedQuery)
                    .themeTint()
                    .ignoresSafeArea(edges: [.vertical])
                    // Trigger navigation when selectedRowi changes
                    .onChange(of: viewModel.selectedRowi) { _, newRowi in
                        if newRowi != nil {
                            navigateToReader = true
                        }
                    }
                    .onChange(of: navigationManager.searchText) { _, newQuery in
                        searchSubject.send(newQuery)
                    }
                    .onReceive(searchSubject.debounce(for: .seconds(0.3), scheduler: RunLoop.main)) { debounced in
                        debouncedQuery = debounced
                        viewModel.searchRowis(query: debounced)
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
    @ObservedObject var viewModel: iOSAuthorViewModel

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

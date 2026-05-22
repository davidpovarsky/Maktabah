import SwiftUI

struct AuthorModeView: View {
    @Environment(iOSNavigationManager.self) private var navigationManager: iOSNavigationManager
    @StateObject private var viewModel = iOSAuthorViewModel()
    @State private var navigateToReader = false

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading Narrators...")
            } else {
                iOSRowiSidebarView(viewModel: viewModel, searchQuery: navigationManager.searchText)
                    .ignoresSafeArea(edges: [.vertical])
                    // Trigger navigation when selectedRowi changes
                    .onChange(of: viewModel.selectedRowi) { _, newRowi in
                        if newRowi != nil {
                            navigateToReader = true
                        }
                    }
                    .onChange(of: navigationManager.searchText) { _, newQuery in
                        viewModel.searchRowis(query: newQuery)
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
        VStack(spacing: 0) {
            ScrollView {
                Text(viewModel.rowiContentText)
                    .font(iOSReaderViewModel.kfgqpcTitle)
                    .padding()
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, .rightToLeft)

            Divider()

            // Segmented Control Toolbar
            HStack {
                Picker("Mode", selection: $viewModel.displayMode) {
                    ForEach(iOSRowiDisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
            }
            .background(Color(UIColor.systemBackground))
        }
        .navigationTitle(viewModel.selectedRowi?.isoName ?? "الراوي")
        .navigationBarTitleDisplayMode(.inline)
    }
}

import Foundation

@MainActor
final class OtzariaIntegratedNavigationState: ObservableObject {
    @Published var selectedBook: OtzariaBook? {
        didSet {
            if oldValue?.id != selectedBook?.id {
                resetSelectedLine()
                readerToken = UUID()
            }
        }
    }

    @Published var selectedLineID: Int?
    @Published var isSourcesInspectorPresented = false
    @Published var readerToken = UUID()

    let sourcesViewModel = OtzariaSourcesViewModel()

    func openBook(_ book: OtzariaBook) {
        selectedBook = book
    }

    func clearBook() {
        selectedBook = nil
        resetSelectedLine()
    }

    func selectLine(_ line: OtzariaBookLine, repository: any OtzariaSourceRepository) {
        selectedLineID = line.id
        isSourcesInspectorPresented = true
        Task {
            await sourcesViewModel.load(line: line, repository: repository)
        }
    }

    func resetSelectedLine() {
        selectedLineID = nil
        isSourcesInspectorPresented = false
        sourcesViewModel.reset()
    }
}

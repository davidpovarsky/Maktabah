import Foundation

@MainActor
final class ZayitSearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var near: UInt32 = 5
    @Published var hits: [ZayitSearchHit] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var configured = false

    private let repository: ZayitSearchRepository
    private var generation = 0

    init(repository: ZayitSearchRepository) {
        self.repository = repository
    }

    func configure(paths: ZayitSearchDataPaths) {
        generation += 1
        Task {
            do {
                try await repository.configure(paths: paths)
                configured = true
                errorMessage = nil
            } catch {
                configured = false
                errorMessage = error.localizedDescription
            }
        }
    }

    func reset() {
        generation += 1
        configured = false
        hits = []
        isLoading = false
        errorMessage = nil
        Task { await repository.reset() }
    }

    func runSearch() {
        generation += 1
        let currentGeneration = generation
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            hits = []
            return
        }

        isLoading = true
        Task {
            do {
                let page = try await repository.search(
                    query: trimmedQuery,
                    near: near,
                    offset: 0,
                    limit: 50,
                    filters: .init()
                )
                guard currentGeneration == generation else { return }
                hits = page.hits
                errorMessage = nil
            } catch {
                guard currentGeneration == generation else { return }
                errorMessage = error.localizedDescription
            }
            guard currentGeneration == generation else { return }
            isLoading = false
        }
    }
}

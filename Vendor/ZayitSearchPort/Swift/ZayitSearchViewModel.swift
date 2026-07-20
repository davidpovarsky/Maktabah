import Foundation

@MainActor
final class ZayitSearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var matchMode: ZayitSearchMatchMode = .flexible
    @Published var hits: [ZayitSearchHit] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var configured = false

    private let repository: ZayitSearchRepository
    private var generation = 0

    init(repository: ZayitSearchRepository) {
        self.repository = repository
    }

    func configure(paths: ZayitSearchDataPaths) async throws {
        generation += 1
        do {
            try await repository.configure(paths: paths)
            configured = true
            errorMessage = nil
        } catch {
            configured = false
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func reset() async {
        generation += 1
        configured = false
        hits = []
        isLoading = false
        errorMessage = nil
        await repository.reset()
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
                    near: matchMode.nearValue,
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

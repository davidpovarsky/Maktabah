import Foundation

@MainActor
final class OtzariaSourcesViewModel: ObservableObject {
    @Published private(set) var selectedLine: OtzariaBookLine?
    @Published private(set) var sections: [OtzariaSourceSection] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    func reset() {
        selectedLine = nil
        sections = []
        errorMessage = nil
        isLoading = false
    }

    func load(line: OtzariaBookLine, repository: any OtzariaSourceRepository) async {
        selectedLine = line
        sections = []
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let sources = try await repository.sources(for: line)
            sections = Self.group(sources)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func group(_ sources: [OtzariaLinkedSource]) -> [OtzariaSourceSection] {
        let grouped = Dictionary(grouping: sources, by: \.connectionType)
        let order = ["COMMENTARY", "TARGUM", "REFERENCE", "SOURCE", "OTHER"]
        var result: [OtzariaSourceSection] = []

        for key in order {
            if let items = grouped[key], !items.isEmpty {
                result.append(OtzariaSourceSection(id: key, title: items[0].localizedConnectionType, items: items))
            }
        }

        let known = Set(order)
        for key in grouped.keys.filter({ !known.contains($0) }).sorted() {
            if let items = grouped[key], !items.isEmpty {
                result.append(OtzariaSourceSection(id: key, title: key, items: items))
            }
        }

        return result
    }
}

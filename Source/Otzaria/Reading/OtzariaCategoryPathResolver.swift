import Foundation

struct OtzariaCategoryPathResolver {
    let categoriesById: [Int: CategoryData]

    func path(for categoryId: Int?) -> [String] {
        guard let categoryId else { return [] }

        var result: [String] = []
        var currentId: Int? = categoryId
        var visited = Set<Int>()

        while let id = currentId,
              let category = categoriesById[id],
              visited.insert(id).inserted {
            result.append(category.name)
            currentId = category.parentId
        }

        return result.reversed()
    }
}

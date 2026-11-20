import Foundation

@main enum MobileBoundAcceptance {
    static func main() throws {
        var rows: [[String: Any]] = []
        func check(_ name: String, _ actual: String, _ expected: String) {
            rows.append(["name": name, "actual": actual, "expected": expected, "passed": actual == expected])
        }
        func refs(_ schema: SefariaJSONValue) throws -> String {
            let nodes = try SefariaNavigationParser.mobileIndexStructures(
                schema: schema, indexTitle: "Genesis", prefersHebrew: false).first?.nodes ?? []
            return nodes.map {
                if case .canonicalRef(let ref) = $0.locator.position { return ref }
                return "invalid"
            }.joined(separator: "|")
        }
        let scalar: SefariaJSONValue = .object([
            "nodeType": .string("JaggedArrayNode"), "depth": .number(1),
            "addressTypes": .array([.string("Integer")]), "content_counts": .number(3)
        ])
        check("depth-one.original-scalar-addresses", try refs(scalar), "Genesis 1|Genesis 2|Genesis 3")
        let array: SefariaJSONValue = .object([
            "nodeType": .string("JaggedArrayNode"), "depth": .number(2), "toc_zoom": .number(2),
            "addressTypes": .array([.string("Integer"), .string("Integer")]),
            "content_counts": .array([.number(0), .number(2)])
        ])
        do { _ = try refs(array); check("depth-one.ambiguous-array-rejected", "success", "invalidResponse") }
        catch LibraryBackendError.invalidResponse { check("depth-one.ambiguous-array-rejected", "invalidResponse", "invalidResponse") }
        catch { check("depth-one.ambiguous-array-rejected", "wrong error", "invalidResponse") }

        func named(_ count: Int) -> SefariaJSONValue {
            .object(["nodeType": .string("SchemaNode"), "nodes": .array((0..<count).map {
                .object(["nodeType": .string("JaggedArrayNode"), "depth": .number(1),
                         "title": .string("Section \($0 + 1)"), "content_counts": .number(2),
                         "addressTypes": .array([.string("Integer")])])
            })])
        }
        let supported = try SefariaNavigationParser.mobileIndexStructures(
            schema: named(500), indexTitle: "Genesis", prefersHebrew: false).first?.nodes ?? []
        check("named-leaves.valid-canonical-membership",
              "\(supported.count)|\(supported.first?.locator.persistenceKey ?? "")|\(supported.last?.locator.persistenceKey ?? "")|\(supported.allSatisfy(\.children.isEmpty))",
              "500|sefaria|Genesis|ref:Genesis, Section 1|sefaria|Genesis|ref:Genesis, Section 500|true")
        do {
            _ = try SefariaNavigationParser.mobileIndexStructures(
                schema: named(100_001), indexTitle: "Genesis", prefersHebrew: false)
            check("named-leaves.every-child-consumes-budget", "success", "invalidResponse")
        } catch LibraryBackendError.invalidResponse {
            check("named-leaves.every-child-consumes-budget", "invalidResponse", "invalidResponse")
        } catch { check("named-leaves.every-child-consumes-budget", "wrong error", "invalidResponse") }
        FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: rows, options: [.sortedKeys]))
        FileHandle.standardOutput.write(Data("\n".utf8))
        exit(rows.allSatisfy { $0["passed"] as? Bool == true } ? 0 : 1)
    }
}

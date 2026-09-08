import Foundation

enum SefariaNavigationParser {
    static func nodes(schema: SefariaJSONValue, indexTitle: String, baseRef: String) -> [LibraryTOCNode] {
        guard case .object(let object) = schema else { return [] }
        if case .array(let nodes)? = object["nodes"] {
            return nodes.compactMap { node in
                guard case .object(let child) = node else { return nil }
                let key = string(child["key"]) ?? schemaTitle(child, language: "en") ?? indexTitle
                let title = schemaTitle(child, language: "he") ?? schemaTitle(child, language: "en") ?? key
                let ref = child["default"] == .bool(true) ? baseRef : "\(baseRef), \(key)"
                return LibraryTOCNode(
                    locator: TextLocator(backend: .sefaria, workKey: indexTitle, position: .canonicalRef(ref)),
                    title: title,
                    children: self.nodes(schema: node, indexTitle: indexTitle, baseRef: ref)
                )
            }
        }
        guard let lengthsValue = object["lengths"] ?? object["content_counts"],
              case .array(let lengths) = lengthsValue,
              let count = lengths.first.flatMap(number).map(Int.init), count > 0 else { return [] }
        let talmud = (object["addressTypes"].flatMap { value -> [String]? in
            guard case .array(let values) = value else { return nil }
            return values.compactMap(string)
        }?.first == "Talmud")
        return (0..<count).map { offset in
            let address = talmud ? SefariaRef.talmudAddress(offset: offset) : String(offset + 1)
            let ref = "\(baseRef) \(address)"
            return LibraryTOCNode(locator: .init(backend: .sefaria, workKey: indexTitle,
                position: .canonicalRef(ref)), title: address, children: [])
        }
    }

    private static func schemaTitle(_ object: [String: SefariaJSONValue], language: String) -> String? {
        guard case .array(let titles)? = object["titles"] else { return nil }
        for title in titles {
            guard case .object(let values) = title,
                  values["lang"] == .string(language), values["primary"] == .bool(true),
                  let text = string(values["text"]) else { continue }
            return text
        }
        return titles.compactMap { value -> String? in
            guard case .object(let values) = value, values["lang"] == .string(language) else { return nil }
            return string(values["text"])
        }.first
    }

    private static func string(_ value: SefariaJSONValue?) -> String? {
        guard case .string(let string)? = value else { return nil }
        return string
    }

    private static func number(_ value: SefariaJSONValue) -> Double? {
        guard case .number(let number) = value else { return nil }
        return number
    }
}

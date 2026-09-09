import Foundation

enum SefariaNavigationParser {
    static func nodes(
        schema: SefariaJSONValue,
        alternateStructures: [String: SefariaJSONValue]? = nil,
        indexTitle: String,
        baseRef: String
    ) -> [LibraryTOCNode] {
        var result = schemaNodes(schema, indexTitle: indexTitle, baseRef: baseRef)
        for key in (alternateStructures ?? [:]).keys.sorted() {
            guard let structure = alternateStructures?[key] else { continue }
            result.append(contentsOf: alternateNodes(structure, indexTitle: indexTitle))
        }
        return deduplicated(result)
    }

    static func nodes(
        shapes: [SefariaShapeDTO],
        schema: SefariaJSONValue,
        alternateStructures: [String: SefariaJSONValue]? = nil,
        indexTitle: String
    ) -> [LibraryTOCNode] {
        let addressTypes = firstAddressTypes(in: schema)
        let primary: [LibraryTOCNode]
        if shapes.count == 1,
           let shape = shapes.first,
           shape.title == indexTitle,
           shape.isComplex != true {
            primary = shapeChildren(
                shape.chapters,
                indexTitle: indexTitle,
                baseRef: indexTitle,
                addressTypes: addressTypes,
                depth: 0
            )
        } else {
            primary = shapes.map { shape in
                LibraryTOCNode(
                    locator: locator(indexTitle: indexTitle, ref: shape.title),
                    title: shape.heTitle ?? shape.title,
                    children: shapeChildren(
                        shape.chapters,
                        indexTitle: indexTitle,
                        baseRef: shape.title,
                        addressTypes: addressTypes,
                        depth: 0
                    )
                )
            }
        }
        guard !primary.isEmpty else {
            return nodes(
                schema: schema,
                alternateStructures: alternateStructures,
                indexTitle: indexTitle,
                baseRef: indexTitle
            )
        }
        let alternatives = (alternateStructures ?? [:]).keys.sorted().flatMap {
            alternateNodes(alternateStructures![$0]!, indexTitle: indexTitle)
        }
        return deduplicated(primary + alternatives)
    }

    private static func schemaNodes(
        _ schema: SefariaJSONValue,
        indexTitle: String,
        baseRef: String
    ) -> [LibraryTOCNode] {
        guard case .object(let object) = schema else { return [] }
        if case .array(let children)? = object["nodes"] {
            return children.compactMap { value in
                guard case .object(let child) = value else { return nil }
                let key = string(child["key"]) ?? schemaTitle(child, language: "en") ?? indexTitle
                let title = schemaTitle(child, language: "he")
                    ?? schemaTitle(child, language: "en")
                    ?? key
                let ref = nodeReference(child, baseRef: baseRef, key: key)
                return LibraryTOCNode(
                    locator: locator(indexTitle: indexTitle, ref: ref),
                    title: title,
                    children: schemaNodes(value, indexTitle: indexTitle, baseRef: ref)
                )
            }
        }

        if string(object["nodeType"]) == "ArrayMapNode" {
            return arrayMapNodes(object, indexTitle: indexTitle)
        }
        if string(object["nodeType"]) == "DictionaryNode" {
            return dictionaryNodes(object, indexTitle: indexTitle)
        }
        guard let count = firstCount(object), count > 0 else { return [] }
        let addressTypes = strings(object["addressTypes"])
        let start = firstOffset(object)
        return (0..<count).map { offset in
            let address = address(offset: offset + start, type: addressTypes?.first)
            let ref = append(address: address, to: baseRef, depth: 0)
            return LibraryTOCNode(
                locator: locator(indexTitle: indexTitle, ref: ref),
                title: address,
                children: []
            )
        }
    }

    private static func shapeChildren(
        _ value: SefariaJSONValue,
        indexTitle: String,
        baseRef: String,
        addressTypes: [String],
        depth: Int
    ) -> [LibraryTOCNode] {
        switch value {
        case .array(let values):
            return values.enumerated().map { offset, child in
                if case .object(let object) = child,
                   let childRef = string(object["title"]) ?? string(object["book"]) ?? string(object["section"]) {
                    let childTitle = string(object["heTitle"]) ?? childRef
                    return LibraryTOCNode(
                        locator: locator(indexTitle: indexTitle, ref: childRef),
                        title: childTitle,
                        children: object["chapters"].map {
                            shapeChildren(
                                $0,
                                indexTitle: indexTitle,
                                baseRef: childRef,
                                addressTypes: addressTypes,
                                depth: depth
                            )
                        } ?? []
                    )
                }
                let address = address(offset: offset, type: addressTypes[safe: depth])
                let ref = append(address: address, to: baseRef, depth: depth)
                let descendants: [LibraryTOCNode]
                if case .array = child {
                    descendants = shapeChildren(
                        child,
                        indexTitle: indexTitle,
                        baseRef: ref,
                        addressTypes: addressTypes,
                        depth: depth + 1
                    )
                } else {
                    descendants = []
                }
                return LibraryTOCNode(
                    locator: locator(indexTitle: indexTitle, ref: ref),
                    title: address,
                    children: descendants
                )
            }
        case .number(let count):
            return (0..<max(0, Int(count))).map { offset in
                let address = address(offset: offset, type: addressTypes[safe: depth])
                let ref = append(address: address, to: baseRef, depth: depth)
                return LibraryTOCNode(
                    locator: locator(indexTitle: indexTitle, ref: ref),
                    title: address,
                    children: []
                )
            }
        default:
            return []
        }
    }

    private static func alternateNodes(_ value: SefariaJSONValue, indexTitle: String) -> [LibraryTOCNode] {
        guard case .object(let object) = value else { return [] }
        if case .array(let nodes)? = object["nodes"] {
            return nodes.flatMap { alternateNodes($0, indexTitle: indexTitle) }
        }
        return arrayMapNodes(object, indexTitle: indexTitle)
    }

    private static func arrayMapNodes(
        _ object: [String: SefariaJSONValue],
        indexTitle: String
    ) -> [LibraryTOCNode] {
        let title = schemaTitle(object, language: "he")
            ?? schemaTitle(object, language: "en")
            ?? string(object["key"])
        if case .array(let refs)? = object["refs"] {
            return refs.enumerated().compactMap { offset, value in
                guard let ref = string(value), !ref.isEmpty else { return nil }
                return LibraryTOCNode(
                    locator: locator(indexTitle: indexTitle, ref: ref),
                    title: title.map { "\($0) \(offset + 1)" } ?? ref,
                    children: []
                )
            }
        }
        guard let ref = string(object["wholeRef"]), !ref.isEmpty else { return [] }
        return [LibraryTOCNode(
            locator: locator(indexTitle: indexTitle, ref: ref),
            title: title ?? ref,
            children: []
        )]
    }

    private static func dictionaryNodes(
        _ object: [String: SefariaJSONValue],
        indexTitle: String
    ) -> [LibraryTOCNode] {
        guard case .array(let entries)? = object["headwordMap"] else { return [] }
        return entries.compactMap { entry in
            guard case .array(let pair) = entry,
                  pair.count >= 2,
                  let title = string(pair[0]),
                  let ref = string(pair[1]) else { return nil }
            return LibraryTOCNode(
                locator: locator(indexTitle: indexTitle, ref: ref),
                title: title,
                children: []
            )
        }
    }

    private static func nodeReference(
        _ object: [String: SefariaJSONValue],
        baseRef: String,
        key: String
    ) -> String {
        if let wholeRef = string(object["wholeRef"]), !wholeRef.isEmpty { return wholeRef }
        if object["default"] == .bool(true) || key == "default" { return baseRef }
        return "\(baseRef), \(key)"
    }

    private static func firstCount(_ object: [String: SefariaJSONValue]) -> Int? {
        for key in ["lengths", "content_counts"] {
            if case .array(let values)? = object[key], let first = values.first, let value = number(first) {
                return Int(value)
            }
        }
        return nil
    }

    private static func firstOffset(_ object: [String: SefariaJSONValue]) -> Int {
        for key in ["offset", "startingAddress"] {
            if let value = number(object[key]) { return max(0, Int(value) - 1) }
            if let value = string(object[key]), let integer = Int(value) { return max(0, integer - 1) }
        }
        return 0
    }

    private static func firstAddressTypes(in value: SefariaJSONValue) -> [String] {
        guard case .object(let object) = value else { return [] }
        if let types = strings(object["addressTypes"]), !types.isEmpty { return types }
        if case .array(let nodes)? = object["nodes"] {
            for node in nodes {
                let result = firstAddressTypes(in: node)
                if !result.isEmpty { return result }
            }
        }
        return []
    }

    private static func append(address: String, to baseRef: String, depth: Int) -> String {
        depth == 0 ? "\(baseRef) \(address)" : "\(baseRef):\(address)"
    }

    private static func address(offset: Int, type: String?) -> String {
        type == "Talmud" ? SefariaRef.talmudAddress(offset: offset) : String(offset + 1)
    }

    private static func locator(indexTitle: String, ref: String) -> TextLocator {
        TextLocator(backend: .sefaria, workKey: indexTitle, position: .canonicalRef(ref))
    }

    private static func schemaTitle(_ object: [String: SefariaJSONValue], language: String) -> String? {
        guard case .array(let titles)? = object["titles"] else { return nil }
        for title in titles {
            guard case .object(let values) = title,
                  values["lang"] == .string(language),
                  values["primary"] == .bool(true),
                  let text = string(values["text"]) else { continue }
            return text
        }
        return titles.compactMap { value -> String? in
            guard case .object(let values) = value, values["lang"] == .string(language) else { return nil }
            return string(values["text"])
        }.first
    }

    private static func strings(_ value: SefariaJSONValue?) -> [String]? {
        guard case .array(let values)? = value else { return nil }
        return values.compactMap(string)
    }

    private static func string(_ value: SefariaJSONValue?) -> String? {
        guard case .string(let string)? = value else { return nil }
        return string
    }

    private static func number(_ value: SefariaJSONValue?) -> Double? {
        guard case .number(let number)? = value else { return nil }
        return number
    }

    private static func deduplicated(_ nodes: [LibraryTOCNode]) -> [LibraryTOCNode] {
        var seen = Set<String>()
        return nodes.filter { seen.insert($0.locator.persistenceKey).inserted }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

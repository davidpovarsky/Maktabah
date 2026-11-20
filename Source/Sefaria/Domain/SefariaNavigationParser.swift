import Foundation

enum SefariaNavigationParser {
    static let parashaHebrewTitles: [String: String] = [
        "Bereshit": "בראשית", "Noach": "נח", "Lech Lecha": "לך לך", "Lech-Lecha": "לך לך",
        "Vayera": "וירא", "Chayei Sara": "חיי שרה", "Chayei Sarah": "חיי שרה",
        "Toldot": "תולדות", "Vayetzei": "ויצא", "Vayishlach": "וישלח", "Vayeshev": "וישב",
        "Miketz": "מקץ", "Vayigash": "ויגש", "Vayechi": "ויחי",
        "Shemot": "שמות", "Vaera": "וארא", "Bo": "בא", "Beshalach": "בשלח",
        "Yitro": "יתרו", "Mishpatim": "משפטים", "Terumah": "תרומה", "Tetzaveh": "תצוה",
        "Ki Tisa": "כי תשא", "Vayakhel": "ויקהל", "Pekudei": "פקודי",
        "Vayikra": "ויקרא", "Tzav": "צו", "Shmini": "שמיני", "Tazria": "תזריע",
        "Metzora": "מצורע", "Achrei Mot": "אחרי מות", "Acharei Mot": "אחרי מות",
        "Kedoshim": "קדושים", "Emor": "אמור", "Behar": "בהר", "Bechukotai": "בחוקתי",
        "Bamidbar": "במדבר", "Nasso": "נשא", "Beha'alotcha": "בהעלותך", "Beha'alothecha": "בהעלותך",
        "Sh'lach": "שלח", "Shelach": "שלח", "Korach": "קרח", "Chukat": "חקת",
        "Balak": "בלק", "Pinchas": "פינחס", "Matot": "מטות", "Masei": "מסעי",
        "Devarim": "דברים", "Vaetchanan": "ואתחנן", "Eikev": "עקב", "Re'eh": "ראה",
        "Shoftim": "שופטים", "Ki Teitzei": "כי תצא", "Ki Tetzei": "כי תצא",
        "Ki Tavo": "כי תבוא", "Nitzavim": "נצבים", "Vayeilech": "וילך",
        "Ha'Azinu": "האזינו", "V'Zot HaBerachah": "וזאת הברכה", "V'Zot HaBeracha": "וזאת הברכה"
    ]

    private static let aliyahHebrewTitles = [
        "ראשון", "שני", "שלישי", "רביעי", "חמישי", "ששי", "שביעי", "מפטיר"
    ]
    private static let aliyahEnglishTitles = [
        "1st Aliyah", "2nd Aliyah", "3rd Aliyah", "4th Aliyah", "5th Aliyah", "6th Aliyah", "7th Aliyah", "Maftir"
    ]

    static func structures(
        shapes: [SefariaShapeDTO]? = nil,
        schema: SefariaJSONValue,
        alternateStructures: [String: SefariaJSONValue]? = nil,
        indexTitle: String,
        baseRef: String? = nil,
        heTitle: String? = nil,
        prefersHebrew: Bool = LibraryPresentationPolicy.prefersHebrew(),
        primaryNodesOverride: [LibraryTOCNode]? = nil
    ) -> [LibraryNavigationStructure] {
        let primary = primaryNodesOverride ?? primaryNodes(
            shapes: shapes,
            schema: schema,
            indexTitle: indexTitle,
            baseRef: baseRef ?? indexTitle,
            prefersHebrew: prefersHebrew
        )

        let addressTypes = firstAddressTypes(in: schema)
        let primaryTitle: String
        if addressTypes.first == "Talmud" {
            primaryTitle = prefersHebrew ? "דפים" : "Folios"
        } else {
            primaryTitle = prefersHebrew ? "פרקים" : "Chapters"
        }

        var results = [LibraryNavigationStructure(id: "primary", title: primaryTitle, nodes: primary)]

        for key in (alternateStructures ?? [:]).keys.sorted() {
            guard let structure = alternateStructures?[key] else { continue }
            let title: String
            if case .object(let obj) = structure,
               let he = schemaTitle(obj, language: "he"), prefersHebrew {
                title = he
            } else if case .object(let obj) = structure,
                      let en = schemaTitle(obj, language: "en"), !prefersHebrew {
                title = en
            } else {
                title = ChavrusaTextLocalizationResolver.resolveNavigationStructureTitle(for: key, prefersHebrew: prefersHebrew)
            }
            let altNodes = alternateNodes(structure, indexTitle: indexTitle, prefersHebrew: prefersHebrew)
            if !altNodes.isEmpty {
                results.append(LibraryNavigationStructure(id: key, title: title, nodes: deduplicated(altNodes)))
            }
        }
        return results
    }


    /// The pinned Sefaria-Mobile textToc payload uses absolute, zero-based
    /// content_counts positions (including padding), not the native shape
    /// convention that starts Talmud at 2a. Keep that input contract explicit.
    static func mobileIndexStructures(
        schema: SefariaJSONValue,
        alternateStructures: [String: SefariaJSONValue]? = nil,
        indexTitle: String,
        prefersHebrew: Bool = LibraryPresentationPolicy.prefersHebrew()
    ) throws -> [LibraryNavigationStructure] {
        var remaining = 100_000
        let primary = try mobileSchemaNodes(schema, indexTitle: indexTitle,
            baseRef: indexTitle, prefersHebrew: prefersHebrew, depth: 0,
            remaining: &remaining)
        return structures(schema: schema, alternateStructures: alternateStructures,
            indexTitle: indexTitle, prefersHebrew: prefersHebrew,
            primaryNodesOverride: primary)
    }

    private static func mobileSchemaNodes(
        _ value: SefariaJSONValue, indexTitle: String, baseRef: String,
        prefersHebrew: Bool, depth: Int, remaining: inout Int
    ) throws -> [LibraryTOCNode] {
        try consumeMobileNode(depth: depth, remaining: &remaining)
        guard case .object(let object) = value else {
            throw LibraryBackendError.invalidResponse("Mobile TOC schema is not an object")
        }
        if let children = object["nodes"] {
            guard case .array(let values) = children else {
                throw LibraryBackendError.invalidResponse("Mobile TOC nodes are not an array")
            }
            return try values.flatMap { childValue -> [LibraryTOCNode] in
                // Named one-dimensional leaves do not recurse; account for
                // every original schema child before selecting its branch.
                try consumeMobileNode(depth: depth + 1, remaining: &remaining)
                guard case .object(let child) = childValue else {
                    throw LibraryBackendError.invalidResponse("Mobile TOC child is not an object")
                }
                let isDefault = child["default"] == .bool(true)
                let key = string(child["title"]) ?? schemaTitle(child, language: "en")
                    ?? string(child["key"]) ?? ""
                guard isDefault || !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw LibraryBackendError.invalidResponse("Mobile TOC child has no canonical title")
                }
                let ref = nodeReference(child, baseRef: baseRef, key: key)
                if isDefault {
                    return try mobileSchemaNodes(childValue, indexTitle: indexTitle,
                        baseRef: ref, prefersHebrew: prefersHebrew, depth: depth + 1,
                        remaining: &remaining)
                }
                if child["nodeType"] == .string("ArrayMapNode")
                    || child["nodeType"] == .string("DictionaryNode") {
                    return try mobileSchemaNodes(childValue, indexTitle: indexTitle,
                        baseRef: ref, prefersHebrew: prefersHebrew, depth: depth + 1,
                        remaining: &remaining)
                }
                // Original mobile named one-dimensional sections open the whole
                // named section; their content count is not a chapter count.
                let isNamedSection = child["nodeType"] == .string("JaggedArrayNode")
                    && child["depth"] == .number(1)
                let nested = isNamedSection ? [] : try mobileSchemaNodes(childValue,
                    indexTitle: indexTitle, baseRef: ref, prefersHebrew: prefersHebrew,
                    depth: depth + 1, remaining: &remaining)
                let title = LibraryPresentationPolicy.workTitle(
                    title: schemaTitle(child, language: "en") ?? string(child["title"]) ?? key,
                    heTitle: schemaTitle(child, language: "he") ?? string(child["heTitle"]),
                    localeIdentifier: prefersHebrew ? "he" : "en")
                return [LibraryTOCNode(locator: locator(indexTitle: indexTitle, ref: ref),
                    title: title, children: nested)]
            }
        }
        if object["nodeType"] == .string("ArrayMapNode")
            || object["nodeType"] == .string("DictionaryNode") {
            return schemaNodes(value, indexTitle: indexTitle, baseRef: baseRef,
                prefersHebrew: prefersHebrew)
        }
        guard object["nodeType"] == .string("JaggedArrayNode"),
              let counts = object["content_counts"],
              let declaredDepth = try mobileInteger(object["depth"]), declaredDepth > 0,
              declaredDepth <= 32,
              let types = strings(object["addressTypes"]), types.count >= declaredDepth else {
            throw LibraryBackendError.invalidResponse("Mobile TOC has no complete content-count schema")
        }
        let zoom = try mobileInteger(object["toc_zoom"]) ?? 1
        guard zoom > 0, zoom <= declaredDepth else {
            throw LibraryBackendError.invalidResponse("Mobile TOC zoom is outside its schema")
        }
        let offsets: [String: SefariaJSONValue]
        if let value = object["index_offsets_by_depth"], value != .null {
            guard case .object(let supplied) = value else {
                throw LibraryBackendError.invalidResponse("Mobile TOC offsets are not an object")
            }
            offsets = supplied
        } else { offsets = [:] }
        return try mobileContentNodes(counts, indexTitle: indexTitle, baseRef: baseRef,
            navigationDepth: declaredDepth - zoom + 1, addressTypes: types,
            offsets: offsets, referenceDepth: 0, nestingDepth: depth,
            prefersHebrew: prefersHebrew, remaining: &remaining)
    }

    private static func mobileContentNodes(
        _ counts: SefariaJSONValue, indexTitle: String, baseRef: String,
        navigationDepth: Int, addressTypes: [String], offsets: [String: SefariaJSONValue],
        referenceDepth: Int, nestingDepth: Int, prefersHebrew: Bool, remaining: inout Int
    ) throws -> [LibraryTOCNode] {
        let values: [SefariaJSONValue]
        if navigationDepth == 1 {
            // Pinned Mobile line 429 constructs Array(contentCounts) here.
            // Its supported contract is a scalar count. An array would become
            // one ambiguous JS entry; do not invent canonical references.
            guard case .number = counts, let count = try mobileInteger(counts) else {
                throw LibraryBackendError.invalidResponse("Mobile TOC depth-one count is not scalar")
            }
            guard count <= remaining else {
                throw LibraryBackendError.invalidResponse("Mobile TOC exceeds the node budget")
            }
            values = Array(repeating: .number(1), count: count)
        } else if case .array(let array) = counts {
            values = array
        } else {
            throw LibraryBackendError.invalidResponse("Mobile TOC content-count dimensions do not match")
        }
        let offset = try mobileInteger(offsets["1"]) ?? 0
        let type = addressTypes.first
        return try values.enumerated().compactMap { index, count in
            try consumeMobileNode(depth: nestingDepth, remaining: &remaining)
            guard try mobileHasContent(count, depth: nestingDepth + 1, remaining: &remaining) else { return nil }
            let position = index + offset
            let address: String
            if type == "Talmud" {
                address = "\(position / 2 + 1)\(position.isMultiple(of: 2) ? "a" : "b")"
            } else if type == "Folio" {
                address = "\(position / 4 + 1)\(["a", "b", "c", "d"][position % 4])"
            } else { address = String(position + 1) }
            let ref = append(address: address, to: baseRef, depth: referenceDepth)
            let title: String
            if !prefersHebrew { title = address }
            else if type == "Talmud" { title = TalmudHebrewAddressFormatter.format(address: address) }
            else if type == "Folio" {
                title = "\(hebrewNumeral(from: position / 4 + 1)),\(["א", "ב", "ג", "ד"][position % 4])"
            } else if referenceDepth == 0 { title = "פרק \(hebrewNumeral(from: position + 1))" }
            else { title = hebrewNumeral(from: position + 1) }
            if navigationDepth > 2 {
                let childOffsets = try mobileChildOffsets(offsets, index: index)
                let children = try mobileContentNodes(count, indexTitle: indexTitle, baseRef: ref,
                    navigationDepth: navigationDepth - 1, addressTypes: Array(addressTypes.dropFirst()),
                    offsets: childOffsets, referenceDepth: referenceDepth + 1,
                    nestingDepth: nestingDepth + 1, prefersHebrew: prefersHebrew,
                    remaining: &remaining)
                return LibraryTOCNode(locator: locator(indexTitle: indexTitle, ref: ref),
                    title: title, children: children)
            }
            // Original mobile zoomed sections retain the first actual inner
            // section in the canonical ref; never renumber a sparse count array.
            let terminal = try mobileRefTerminal(count, depth: nestingDepth + 1, remaining: &remaining)
            return LibraryTOCNode(locator: locator(indexTitle: indexTitle, ref: ref + terminal),
                title: title, children: [])
        }
    }

    private static func mobileInteger(_ value: SefariaJSONValue?) throws -> Int? {
        guard let value, value != .null else { return nil }
        guard case .number(let number) = value, number.isFinite,
              number >= 0, number <= 1_000_000, number.rounded() == number else {
            throw LibraryBackendError.invalidResponse("Mobile TOC count or offset is invalid")
        }
        return Int(number)
    }

    private static func mobileHasContent(
        _ value: SefariaJSONValue, depth: Int, remaining: inout Int
    ) throws -> Bool {
        try consumeMobileNode(depth: depth, remaining: &remaining)
        if case .number = value { return try mobileInteger(value)! > 0 }
        guard case .array(let children) = value else {
            throw LibraryBackendError.invalidResponse("Mobile TOC content count is malformed")
        }
        var found = false
        for child in children {
            // Validate every child, including those after the first nonzero one.
            if try mobileHasContent(child, depth: depth + 1, remaining: &remaining) { found = true }
        }
        return found
    }

    private static func mobileRefTerminal(
        _ value: SefariaJSONValue, depth: Int, remaining: inout Int
    ) throws -> String {
        try consumeMobileNode(depth: depth, remaining: &remaining)
        if case .number = value { return "" }
        guard case .array(let values) = value else {
            throw LibraryBackendError.invalidResponse("Mobile TOC terminal count is malformed")
        }
        for (index, value) in values.enumerated() {
            if try mobileHasContent(value, depth: depth + 1, remaining: &remaining) {
                return ":\(index + 1)" + (try mobileRefTerminal(value, depth: depth + 1, remaining: &remaining))
            }
        }
        throw LibraryBackendError.invalidResponse("Mobile TOC terminal has no content")
    }

    private static func mobileChildOffsets(
        _ offsets: [String: SefariaJSONValue], index: Int
    ) throws -> [String: SefariaJSONValue] {
        var child: [String: SefariaJSONValue] = [:]
        for (key, value) in offsets where key != "1" {
            guard let depth = Int(key), depth > 1, depth <= 32,
                  case .array(let values) = value, values.indices.contains(index) else {
                throw LibraryBackendError.invalidResponse("Mobile TOC nested offsets are malformed")
            }
            child[String(depth - 1)] = values[index]
        }
        return child
    }

    private static func consumeMobileNode(depth: Int, remaining: inout Int) throws {
        try Task.checkCancellation()
        guard depth <= 64, remaining > 0 else {
            throw LibraryBackendError.invalidResponse("Mobile TOC exceeds its bounded schema")
        }
        remaining -= 1
    }

    static func nodes(
        schema: SefariaJSONValue,
        alternateStructures: [String: SefariaJSONValue]? = nil,
        indexTitle: String,
        baseRef: String,
        prefersHebrew: Bool = LibraryPresentationPolicy.prefersHebrew()
    ) -> [LibraryTOCNode] {
        schemaNodes(schema, indexTitle: indexTitle, baseRef: baseRef, prefersHebrew: prefersHebrew)
    }

    static func nodes(
        shapes: [SefariaShapeDTO],
        schema: SefariaJSONValue,
        alternateStructures: [String: SefariaJSONValue]? = nil,
        indexTitle: String,
        prefersHebrew: Bool = LibraryPresentationPolicy.prefersHebrew()
    ) -> [LibraryTOCNode] {
        primaryNodes(
            shapes: shapes,
            schema: schema,
            indexTitle: indexTitle,
            baseRef: indexTitle,
            prefersHebrew: prefersHebrew
        )
    }

    private static func primaryNodes(
        shapes: [SefariaShapeDTO]?,
        schema: SefariaJSONValue,
        indexTitle: String,
        baseRef: String,
        prefersHebrew: Bool
    ) -> [LibraryTOCNode] {
        let addressTypes = firstAddressTypes(in: schema)
        if let shapes, !shapes.isEmpty {
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
                    depth: 0,
                    prefersHebrew: prefersHebrew
                )
            } else {
                primary = shapes.map { shape in
                    LibraryTOCNode(
                        locator: locator(indexTitle: indexTitle, ref: shape.title),
                        title: LibraryPresentationPolicy.workTitle(
                            title: shape.title,
                            heTitle: shape.heTitle,
                            localeIdentifier: prefersHebrew ? "he" : "en"
                        ),
                        children: shapeChildren(
                            shape.chapters,
                            indexTitle: indexTitle,
                            baseRef: shape.title,
                            addressTypes: addressTypes,
                            depth: 0,
                            prefersHebrew: prefersHebrew
                        )
                    )
                }
            }
            if !primary.isEmpty {
                return deduplicated(primary)
            }
        }
        return deduplicated(schemaNodes(schema, indexTitle: indexTitle, baseRef: baseRef, prefersHebrew: prefersHebrew))
    }

    static func schemaNodes(
        _ schema: SefariaJSONValue,
        indexTitle: String,
        baseRef: String,
        prefersHebrew: Bool = LibraryPresentationPolicy.prefersHebrew()
    ) -> [LibraryTOCNode] {
        guard case .object(let object) = schema else { return [] }
        if case .array(let children)? = object["nodes"] {
            return children.compactMap { value in
                guard case .object(let child) = value else { return nil }
                let key = string(child["key"]) ?? schemaTitle(child, language: "en") ?? indexTitle
                let title = LibraryPresentationPolicy.workTitle(
                    title: schemaTitle(child, language: "en") ?? "",
                    heTitle: schemaTitle(child, language: "he"),
                    localeIdentifier: prefersHebrew ? "he" : "en"
                )
                let ref = nodeReference(child, baseRef: baseRef, key: key)
                return LibraryTOCNode(
                    locator: locator(indexTitle: indexTitle, ref: ref),
                    title: title.isEmpty ? key : title,
                    children: schemaNodes(value, indexTitle: indexTitle, baseRef: ref, prefersHebrew: prefersHebrew)
                )
            }
        }

        if string(object["nodeType"]) == "ArrayMapNode" {
            return arrayMapNodes(object, indexTitle: indexTitle, prefersHebrew: prefersHebrew)
        }
        if string(object["nodeType"]) == "DictionaryNode" {
            return dictionaryNodes(object, indexTitle: indexTitle)
        }
        guard let count = firstCount(object), count > 0 else { return [] }
        let addressTypes = strings(object["addressTypes"])
        let start = firstOffset(object)
        return (0..<count).map { offset in
            let addressVal = address(offset: offset + start, type: addressTypes?.first)
            let ref = append(address: addressVal, to: baseRef, depth: 0)
            let display = chapterDisplayTitle(offset: offset + start, type: addressTypes?.first, prefersHebrew: prefersHebrew)
            return LibraryTOCNode(
                locator: locator(indexTitle: indexTitle, ref: ref),
                title: display,
                children: []
            )
        }
    }

    private static func shapeChildren(
        _ value: SefariaJSONValue,
        indexTitle: String,
        baseRef: String,
        addressTypes: [String],
        depth: Int,
        prefersHebrew: Bool
    ) -> [LibraryTOCNode] {
        switch value {
        case .array(let values):
            return values.enumerated().map { offset, child in
                if case .object(let object) = child,
                   let childRef = string(object["title"]) ?? string(object["book"]) ?? string(object["section"]) {
                    let childTitle = LibraryPresentationPolicy.workTitle(
                        title: childRef,
                        heTitle: string(object["heTitle"]),
                        localeIdentifier: prefersHebrew ? "he" : "en"
                    )
                    return LibraryTOCNode(
                        locator: locator(indexTitle: indexTitle, ref: childRef),
                        title: childTitle,
                        children: object["chapters"].map {
                            shapeChildren(
                                $0,
                                indexTitle: indexTitle,
                                baseRef: childRef,
                                addressTypes: addressTypes,
                                depth: depth,
                                prefersHebrew: prefersHebrew
                            )
                        } ?? []
                    )
                }
                let addressVal = address(offset: offset, type: addressTypes[safe: depth])
                let ref = append(address: addressVal, to: baseRef, depth: depth)
                let display = depth == 0
                    ? chapterDisplayTitle(offset: offset, type: addressTypes[safe: depth], prefersHebrew: prefersHebrew)
                    : addressVal
                let descendants: [LibraryTOCNode]
                if case .array = child {
                    descendants = shapeChildren(
                        child,
                        indexTitle: indexTitle,
                        baseRef: ref,
                        addressTypes: addressTypes,
                        depth: depth + 1,
                        prefersHebrew: prefersHebrew
                    )
                } else {
                    descendants = []
                }
                return LibraryTOCNode(
                    locator: locator(indexTitle: indexTitle, ref: ref),
                    title: display,
                    children: descendants
                )
            }
        case .number(let count):
            return (0..<max(0, Int(count))).map { offset in
                let addressVal = address(offset: offset, type: addressTypes[safe: depth])
                let ref = append(address: addressVal, to: baseRef, depth: depth)
                let display = depth == 0
                    ? chapterDisplayTitle(offset: offset, type: addressTypes[safe: depth], prefersHebrew: prefersHebrew)
                    : addressVal
                return LibraryTOCNode(
                    locator: locator(indexTitle: indexTitle, ref: ref),
                    title: display,
                    children: []
                )
            }
        default:
            return []
        }
    }

    private static func alternateNodes(
        _ value: SefariaJSONValue,
        indexTitle: String,
        prefersHebrew: Bool
    ) -> [LibraryTOCNode] {
        guard case .object(let object) = value else { return [] }
        if case .array(let nodes)? = object["nodes"] {
            return nodes.flatMap { alternateNodes($0, indexTitle: indexTitle, prefersHebrew: prefersHebrew) }
        }
        return arrayMapNodes(object, indexTitle: indexTitle, prefersHebrew: prefersHebrew)
    }

    private static func arrayMapNodes(
        _ object: [String: SefariaJSONValue],
        indexTitle: String,
        prefersHebrew: Bool
    ) -> [LibraryTOCNode] {
        let hebrewTitle = schemaTitle(object, language: "he")
            ?? (string(object["sharedTitle"]).flatMap { parashaHebrewTitles[$0] })
            ?? (string(object["key"]).flatMap { parashaHebrewTitles[$0] })
        let englishTitle = schemaTitle(object, language: "en")
            ?? string(object["sharedTitle"])
            ?? string(object["title"])
            ?? string(object["key"])
        let title = prefersHebrew ? (hebrewTitle ?? englishTitle) : (englishTitle ?? hebrewTitle)

        let nodeWholeRef = string(object["wholeRef"])
        let refs = strings(object["refs"]) ?? []
        let addressType = strings(object["addressTypes"])?.first ?? strings(object["sectionNames"])?.first
        let isAliyah = addressType == "Aliyah"

        let childNodes: [LibraryTOCNode]
        if refs.count > 1 || (refs.count == 1 && nodeWholeRef != nil) {
            childNodes = refs.enumerated().compactMap { offset, ref in
                guard !ref.isEmpty else { return nil }
                let childTitle: String
                if isAliyah {
                    if prefersHebrew && offset < aliyahHebrewTitles.count {
                        childTitle = aliyahHebrewTitles[offset]
                    } else if !prefersHebrew && offset < aliyahEnglishTitles.count {
                        childTitle = aliyahEnglishTitles[offset]
                    } else {
                        childTitle = prefersHebrew ? "עליה \(hebrewNumeral(from: offset + 1))" : "Aliyah \(offset + 1)"
                    }
                } else {
                    childTitle = prefersHebrew ? "\(title ?? "") \(hebrewNumeral(from: offset + 1))" : "\(title ?? "") \(offset + 1)"
                }
                return LibraryTOCNode(
                    locator: locator(indexTitle: indexTitle, ref: ref),
                    title: childTitle,
                    children: []
                )
            }
        } else {
            childNodes = []
        }

        if let wholeRef = nodeWholeRef, !wholeRef.isEmpty {
            return [LibraryTOCNode(
                locator: locator(indexTitle: indexTitle, ref: wholeRef),
                title: title ?? wholeRef,
                children: childNodes
            )]
        } else if childNodes.isEmpty && refs.count == 1 {
            return [LibraryTOCNode(
                locator: locator(indexTitle: indexTitle, ref: refs[0]),
                title: title ?? refs[0],
                children: []
            )]
        } else if !childNodes.isEmpty {
            return childNodes
        }
        return []
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

    static func address(offset: Int, type: String?) -> String {
        type == "Talmud" ? SefariaRef.talmudAddress(offset: offset) : String(offset + 1)
    }

    static func chapterDisplayTitle(offset: Int, type: String?, prefersHebrew: Bool) -> String {
        if type == "Talmud" {
            if prefersHebrew {
                return TalmudHebrewAddressFormatter.format(offset: offset)
            } else {
                return SefariaRef.talmudAddress(offset: offset)
            }
        }
        let number = offset + 1
        if prefersHebrew {
            return "פרק \(hebrewNumeral(from: number))"
        } else {
            return String(number)
        }
    }

    static func hebrewNumeral(from number: Int) -> String {
        guard number > 0 else { return "\(number)" }
        let hundreds = ["", "ק", "ר", "ש", "ת", "תק", "תר", "תש", "תת", "תתק"]
        let tens = ["", "י", "כ", "ל", "מ", "נ", "ס", "ע", "פ", "צ"]
        let units = ["", "א", "ב", "ג", "ד", "ה", "ו", "ז", "ח", "ט"]

        var n = number
        var letters = ""

        if n >= 1000 {
            let thousands = n / 1000
            letters += hebrewNumeral(from: thousands) + " "
            n %= 1000
        }

        if n >= 100 {
            letters += hundreds[min(n / 100, 9)]
            n %= 100
        }

        if n == 15 {
            letters += "טו"
        } else if n == 16 {
            letters += "טז"
        } else {
            letters += tens[n / 10]
            letters += units[n % 10]
        }

        if letters.count == 1 {
            return letters + "׳"
        } else if letters.count > 1 {
            let prefix = letters.dropLast()
            let last = letters.suffix(1)
            return "\(prefix)״\(last)"
        }
        return "\(number)"
    }

    static func schemaTitle(from schema: SefariaJSONValue, language: String) -> String? {
        guard case .object(let object) = schema else { return nil }
        return schemaTitle(object, language: language)
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

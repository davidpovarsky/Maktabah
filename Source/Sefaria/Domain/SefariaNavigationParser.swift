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
        prefersHebrew: Bool = LibraryPresentationPolicy.prefersHebrew()
    ) -> [LibraryNavigationStructure] {
        let primary = primaryNodes(
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
            } else if key == "Parasha" {
                title = prefersHebrew ? "פרשות" : "Parashot"
            } else if key == "Perek" {
                title = prefersHebrew ? "פרקים" : "Chapters"
            } else {
                title = key
            }
            let altNodes = alternateNodes(structure, indexTitle: indexTitle, prefersHebrew: prefersHebrew)
            if !altNodes.isEmpty {
                results.append(LibraryNavigationStructure(id: key, title: title, nodes: deduplicated(altNodes)))
            }
        }
        return results
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
                        title: shape.heTitle ?? shape.title,
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
                let title = schemaTitle(child, language: "he")
                    ?? schemaTitle(child, language: "en")
                    ?? key
                let ref = nodeReference(child, baseRef: baseRef, key: key)
                return LibraryTOCNode(
                    locator: locator(indexTitle: indexTitle, ref: ref),
                    title: title,
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
                    let childTitle = string(object["heTitle"])
                        ?? string(object["title"])
                        ?? childRef
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
            return SefariaRef.talmudAddress(offset: offset)
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

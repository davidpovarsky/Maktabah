import Foundation

struct MobileCheck: Encodable {
    let name: String
    let actual: String
    let expected: String
    var passed: Bool { actual == expected }
    enum CodingKeys: String, CodingKey { case name, actual, expected, passed }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name); try c.encode(actual, forKey: .actual)
        try c.encode(expected, forKey: .expected); try c.encode(passed, forKey: .passed)
    }
}

@main enum MobileNavigationAcceptance {
    static func errorKind(_ error: any Error) -> String {
        if error is CancellationError { return "cancelled" }
        if let e = error as? SefariaRPCError { return "rpc:" + e.code }
        if let e = error as? LibraryBackendError {
            switch e {
            case .invalidLocator: return "invalidLocator"
            case .invalidResponse: return "invalidResponse"
            case .staleRequest: return "staleRequest"
            default: return "otherLibraryError"
            }
        }
        return "unexpectedError"
    }
    static func main() async throws {
        var checks: [MobileCheck] = []
        func check(_ name: String, _ actual: String, _ expected: String) {
            checks.append(.init(name: name, actual: actual, expected: expected))
        }
        func ref(_ node: LibraryTOCNode?) -> String {
            guard let node, case .canonicalRef(let ref) = node.locator.position else { return "<missing>" }
            return ref
        }
        func flatten(_ nodes: [LibraryTOCNode]) -> [LibraryTOCNode] {
            nodes.flatMap { [$0] + flatten($0.children) }
        }
        func leaves(_ nodes: [LibraryTOCNode]) -> [LibraryTOCNode] {
            nodes.flatMap { $0.children.isEmpty ? [$0] : leaves($0.children) }
        }
        func body(_ name: String) throws -> String {
            try String(contentsOf: URL(fileURLWithPath: "Fixtures/" + name + ".json"), encoding: .utf8)
        }
        let adapter = SefariaEmbeddedNavigationAdapter.shared
        let transport = MobileFixtureTransport()
        let bridge = SefariaJSRPCBridge.shared
        func ready() async {
            await bridge.setTransport(transport)
            await bridge.notifyListenersActive(true)
            let event = SefariaRPCEvent(event: "ready", sequence: 1, backendID: "sefariaEmbedded")
            await bridge.handleIncomingEvent(jsonString: String(decoding: try! JSONEncoder().encode(event), as: UTF8.self))
        }
        await ready()
        check("portable.default-locale-is-english", String(LibraryPresentationPolicy.prefersHebrew()), "false")
        var dataByWork: [String: String] = [:]
        var structuresByWork: [String: [LibraryNavigationStructure]] = [:]
        for (file, work) in [
            ("Genesis", "Genesis"), ("Berakhot", "Berakhot"), ("Eruvin", "Eruvin"),
            ("Rashi_on_Genesis", "Rashi on Genesis"), ("Pesach_Haggadah", "Pesach Haggadah")
        ] {
            let data = try body(file); dataByWork[work] = data
            await transport.select(.body(data))
            do {
                structuresByWork[work] = try await adapter.navigationStructures(for: work)
                check("source." + file + ".loaded", "success", "success")
            } catch { check("source." + file + ".loaded", errorKind(error), "success") }
            check("source." + file + ".one-original-rpc", String(await transport.count()), "1")
            check("source." + file + ".exact-request", await transport.titles().joined(separator: "|"), work)
        }
        func primary(_ work: String) -> [LibraryTOCNode] {
            structuresByWork[work]?.first(where: { $0.id == "default" })?.nodes ?? []
        }
        let genesis = primary("Genesis")
        check("genesis.structure", structuresByWork["Genesis"]?.first?.title ?? "", "Chapters")
        check("genesis.chapter-count", String(genesis.count), "50")
        check("genesis.first", ref(genesis.first), "Genesis 1")
        check("genesis.last", ref(genesis.last), "Genesis 50")
        check("genesis.parasha-ref", ref(structuresByWork["Genesis"]?.first(where: { $0.id == "Parasha" })?.nodes.first), "Genesis 1:1-6:8")
        let berakhot = primary("Berakhot")
        check("berakhot.structure", structuresByWork["Berakhot"]?.first?.title ?? "", "Folios")
        check("berakhot.count-excludes-padding", String(berakhot.count), "125")
        check("berakhot.first", ref(berakhot.first), "Berakhot 2a")
        check("berakhot.last", ref(berakhot.last), "Berakhot 64a")
        check("berakhot.12a", berakhot.first(where: { ref($0) == "Berakhot 12a" })?.title ?? "", "12a")
        check("berakhot.12b", berakhot.first(where: { ref($0) == "Berakhot 12b" })?.title ?? "", "12b")
        check("berakhot.chapter-whole-ref", ref(structuresByWork["Berakhot"]?.first(where: { $0.id == "Chapters" })?.nodes.first), "Berakhot 2a:1-13a:15")
        let eruvin = primary("Eruvin")
        check("eruvin.loaded-not-empty", String(eruvin.count), "207")
        check("eruvin.first", ref(eruvin.first), "Eruvin 2a")
        check("eruvin.last", ref(eruvin.last), "Eruvin 105a")
        let rashi = primary("Rashi on Genesis"), rashiLeaves = leaves(rashi)
        check("rashi.chapters", String(rashi.count), "50")
        check("rashi.actual-section-count", String(rashiLeaves.count), "1072")
        check("rashi.first-verse", ref(rashiLeaves.first), "Rashi on Genesis 1:1")
        check("rashi.last-verse", ref(rashiLeaves.last), "Rashi on Genesis 50:23")
        check("rashi.sparse-verse-preserved", String(rashiLeaves.contains { ref($0) == "Rashi on Genesis 1:3" }), "false")
        let haggadah = primary("Pesach Haggadah")
        check("complex.named-roots", String(haggadah.count), "14")
        check("complex.named-section-ref", ref(haggadah.first), "Pesach Haggadah, Kadesh")
        check("complex.named-section-not-invented-chapters", String(haggadah.first?.children.count ?? -1), "0")
        check("complex.nested-canonical-ref",
            ref(flatten(haggadah).first(where: { $0.title == "The Four Sons" })),
            "Pesach Haggadah, Magid, The Four Sons")
        check("all.backend-work-identity",
            String(structuresByWork.allSatisfy { work, structures in
                structures.flatMap { flatten($0.nodes) }.allSatisfy {
                    $0.locator.backend == .sefariaEmbedded && $0.locator.workKey == work
                }
            }), "true")
        await transport.select(.body(dataByWork["Rashi on Genesis"]!))
        do {
            let items = try await adapter.navigationItems(for: "Rashi on Genesis", structureID: nil)
            check("items.flatten-original-sections", String(items.count), "1072")
            check("items.contiguous-index", String(items.enumerated().allSatisfy { $0.offset == $0.element.index }), "true")
        } catch {
            check("items.flatten-original-sections", errorKind(error), "1072")
            check("items.contiguous-index", errorKind(error), "true")
        }
        func responseOutcome(_ mode: MobileFixtureTransport.Mode, work: String = "Genesis", structure: String? = nil) async -> String {
            await transport.select(mode)
            do {
                if let structure { _ = try await adapter.tableOfContents(for: work, structureID: structure) }
                else { _ = try await adapter.navigationStructures(for: work) }
                return "success"
            } catch { return errorKind(error) }
        }
        check("error.rpc-not-empty", await responseOutcome(.error), "rpc:ORIGINAL_RPC_FAILURE_CONTROL")
        check("error.absent-not-empty", await responseOutcome(.absent), "invalidResponse")
        check("error.malformed-not-empty", await responseOutcome(.body("{")), "invalidResponse")
        check("error.null-not-empty", await responseOutcome(.body("null")), "invalidResponse")
        check("error.foreign-work", await responseOutcome(.body(dataByWork["Eruvin"]!)), "invalidResponse")
        check("error.missing-schema", await responseOutcome(.body(#"{"title":"Genesis"}"#)), "invalidResponse")
        check("error.unknown-structure", await responseOutcome(.body(dataByWork["Genesis"]!), structure: "not-a-real-structure"), "invalidLocator")
        check("error.foreign-backend-protocol", await responseOutcome(.foreignBackend), "rpc:BACKEND_MISMATCH")
        check("error.oversized-payload", await responseOutcome(.body(String(repeating: " ", count: 16_777_217))), "invalidResponse")
        let empty = #"{"title":"Genesis","schema":{"nodeType":"JaggedArrayNode","depth":2,"addressTypes":["Integer","Integer"],"lengths":[0],"content_counts":[]}}"#
        await transport.select(.body(empty))
        do {
            let emptyStructures = try await adapter.navigationStructures(for: "Genesis")
            check("empty.valid-loaded-empty", String(emptyStructures.count) + ":" + String(emptyStructures.first?.nodes.count ?? -1), "1:0")
        } catch { check("empty.valid-loaded-empty", errorKind(error), "1:0") }
        let negative = #"{"title":"Genesis","schema":{"nodeType":"JaggedArrayNode","depth":2,"addressTypes":["Integer","Integer"],"lengths":[1],"content_counts":[-1]}}"#
        check("error.negative-count", await responseOutcome(.body(negative)), "invalidResponse")
        let offsets = #"{"title":"Genesis","schema":{"nodeType":"JaggedArrayNode","depth":3,"addressTypes":["Integer","Integer","Integer"],"content_counts":[[0,1],[1,0,1]],"index_offsets_by_depth":{"1":2,"2":[4,7]}}}"#
        await transport.select(.body(offsets))
        do {
            let value = try await adapter.navigationItems(for: "Genesis", structureID: nil)
            check("offsets.original-depth-and-sparse-indices",
                value.map { item -> String in if case .canonicalRef(let r) = item.locator.position { return r }; return "invalid" }.joined(separator: "|"),
                "Genesis 3:6|Genesis 4:8|Genesis 4:10")
        } catch { check("offsets.original-depth-and-sparse-indices", errorKind(error), "Genesis 3:6|Genesis 4:8|Genesis 4:10") }
        let defaultNode = #"{"title":"Genesis","schema":{"nodeType":"SchemaNode","nodes":[{"nodeType":"JaggedArrayNode","default":true,"key":"default","depth":2,"addressTypes":["Integer","Integer"],"content_counts":[1,1]}]}}"#
        await transport.select(.body(defaultNode))
        do {
            let value = try await adapter.tableOfContents(for: "Genesis", structureID: nil)
            check("default-node.canonical-parent-preserved", value.map { ref($0) }.joined(separator: "|"), "Genesis 1|Genesis 2")
        } catch { check("default-node.canonical-parent-preserved", errorKind(error), "Genesis 1|Genesis 2") }

        // Actual bridge waits/cancellation/late-response ownership, no real Hermes.
        await transport.select(.hold(dataByWork["Genesis"]!))
        let observation = MobileCompletionObservation()
        let pending = Task {
            do {
                _ = try await adapter.navigationStructures(for: "Genesis")
                await observation.finish(); return "success"
            } catch { await observation.finish(); return errorKind(error) }
        }
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while await transport.count() == 0, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(5)) }
        check("lifetime.original-request-held", String(await transport.count()), "1")
        check("lifetime.loading-not-completed-empty", String(await observation.isFinished()), "false")
        pending.cancel()
        check("lifetime.cancelled-once", await pending.value, "cancelled")
        await transport.releaseLateResponses()
        check("lifetime.late-response-did-not-replace-cancellation", String(await observation.isFinished()), "true")
        await transport.select(.hold(dataByWork["Genesis"]!))
        let stale = Task {
            do { _ = try await adapter.navigationStructures(for: "Genesis"); return "success" }
            catch { return errorKind(error) }
        }
        let staleDeadline = ContinuousClock.now.advanced(by: .seconds(2))
        while await transport.count() == 0, ContinuousClock.now < staleDeadline { try await Task.sleep(for: .milliseconds(5)) }
        check("lifetime.stale-request-was-in-flight", String(await transport.count()), "1")
        _ = await bridge.bumpSessionEpoch()
        check("lifetime.generation-change-rejects-old-response", await stale.value, "rpc:CANCELLED")
        await transport.releaseLateResponses()
        await ready()
        check("lifetime.original-retry-after-cancellation", await responseOutcome(.body(dataByWork["Genesis"]!)), "success")

        #if MOBILE_LANGUAGE_CASES
        func decoded(_ work: String, hebrew: Bool) throws -> [LibraryNavigationStructure] {
            try SefariaEmbeddedNavigationAdapter.decodeStructures(
                .init(requestID: "decoded-fixture", status: "success", resultJson: dataByWork[work]!),
                workKey: work, prefersHebrew: hebrew)
        }
        let heGenesis = try decoded("Genesis", hebrew: true), enGenesis = try decoded("Genesis", hebrew: false)
        check("language.hebrew.chapters", heGenesis.first?.title ?? "", "פרקים")
        check("language.english.chapters", enGenesis.first?.title ?? "", "Chapters")
        check("language.hebrew.chapter-one", heGenesis.first?.nodes.first?.title ?? "", "פרק א׳")
        check("language.english.chapter-one", enGenesis.first?.nodes.first?.title ?? "", "1")
        let heBerakhot = try decoded("Berakhot", hebrew: true), enBerakhot = try decoded("Berakhot", hebrew: false)
        check("language.hebrew.folios", heBerakhot.first?.title ?? "", "דפים")
        check("language.english.folios", enBerakhot.first?.title ?? "", "Folios")
        check("language.hebrew.12a", heBerakhot.first?.nodes.first(where: { ref($0) == "Berakhot 12a" })?.title ?? "", "י״ב ע״א")
        check("language.hebrew.12b", heBerakhot.first?.nodes.first(where: { ref($0) == "Berakhot 12b" })?.title ?? "", "י״ב ע״ב")
        check("language.hebrew.alt-chapter", heBerakhot.first(where: { $0.id == "Chapters" })?.nodes.first?.title ?? "", "מאימתי")
        check("language.english.alt-chapter", enBerakhot.first(where: { $0.id == "Chapters" })?.nodes.first?.title ?? "", "Chapter 1; MeEimatai")
        check("language.hebrew.alt-structure-label", heBerakhot.first(where: { $0.id == "Chapters" })?.title ?? "", "פרקים")
        check("language.english.alt-structure-label", enBerakhot.first(where: { $0.id == "Chapters" })?.title ?? "", "Chapters")
        check("language.hebrew.genesis-parasha-label", heGenesis.first(where: { $0.id == "Parasha" })?.title ?? "", "פרשה")
        check("language.english.genesis-parasha-label", enGenesis.first(where: { $0.id == "Parasha" })?.title ?? "", "Parashot")
        let heRashi = try decoded("Rashi on Genesis", hebrew: true), enRashi = try decoded("Rashi on Genesis", hebrew: false)
        check("language.hebrew.rashi-parasha-label", heRashi.first(where: { $0.id == "Parasha" })?.title ?? "", "פרשה")
        check("language.english.rashi-parasha-label", enRashi.first(where: { $0.id == "Parasha" })?.title ?? "", "Parashot")
        // The mobile-only title rule must not override the native API's
        // explicit localized structure titles.
        guard case .object(let berakhotObject) = try JSONDecoder().decode(
            SefariaJSONValue.self, from: Data(dataByWork["Berakhot"]!.utf8)),
            let schema = berakhotObject["schema"],
            case .object(let alternates) = berakhotObject["alts"] else {
            fatalError("Retained original Berakhot fixture changed shape")
        }
        let nativeHebrew = SefariaNavigationParser.structures(schema: schema,
            alternateStructures: alternates, indexTitle: "Berakhot", prefersHebrew: true)
        let nativeEnglish = SefariaNavigationParser.structures(schema: schema,
            alternateStructures: alternates, indexTitle: "Berakhot", prefersHebrew: false)
        check("language.native-api.hebrew-title-preserved", nativeHebrew.first(where: { $0.id == "Chapters" })?.title ?? "", "ברכות")
        check("language.native-api.english-title-preserved", nativeEnglish.first(where: { $0.id == "Chapters" })?.title ?? "", "Berakhot")
        let heComplex = try decoded("Pesach Haggadah", hebrew: true)
        check("language.hebrew.complex-root", heComplex.first?.nodes.first?.title ?? "", "קדש")
        check("language.hebrew.complex-child", flatten(heComplex.first?.nodes ?? []).first(where: { ref($0) == "Pesach Haggadah, Magid, The Four Sons" })?.title ?? "", "כנגד ארבעה בנים")
        check("language.canonical-ref-identity",
            String(flatten(heBerakhot.flatMap(\.nodes)).map(\.locator) == flatten(enBerakhot.flatMap(\.nodes)).map(\.locator)), "true")
        #endif

        await bridge.setTransport(nil)
        let data = try JSONEncoder().encode(checks)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
        exit(checks.allSatisfy(\.passed) ? 0 : 1)
    }
}

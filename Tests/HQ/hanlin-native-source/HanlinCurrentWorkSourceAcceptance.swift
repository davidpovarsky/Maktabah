import Foundation

@MainActor final class Fixture {
    let manager = iOSNavigationManager()
    let reader = ReaderViewModel()
    let id = UUID()
    let book: BooksData
    var projection: MaktabahNativeSceneProjection
    static func ref(_ line: Int, work: String = "book:3891", backend: BackendID = .otzaria) -> TextLocator {
        .init(backend: backend, workKey: work, position: .legacyLine(line))
    }
    init(request: Int = 522) {
        BackendCoordinator.shared.activeBackendID = .otzaria
        MaktabahApp.isIpad = true
        book = .init(id: 3891, backendLocator: Self.ref(0))
        projection = .init(manager: manager)
        reader.currentBook = book
        manager.openTabs = [.init(id: id, book: book, viewModel: reader)]
        manager.activeTabId = id
        manager.selectedBook = book
        reader.currentDestination = ReaderDestinationResolver.resolve(locator: Self.ref(request)).destination
        let segments = (522...526).map {
            LibraryTextSegment(locator: Self.ref($0), heRef: nil, primaryText: "source line \($0)", translation: nil)
        }
        let section = LibraryTextSection(locator: Self.ref(522), displayRef: "fixture bounded unit",
            heRef: nil, segments: segments, previous: nil, next: nil, versions: [], links: [], origin: .offline)
        reader.backendSection = section
        reader.backendRenderModel = .init(section: section, preferredMode: .source)
        reader.contentText = reader.backendRenderModel!.text
        reader.contentLoadCoordinator.beginRequest(backend: .otzaria, workKey: "book:3891",
            sectionLocator: Self.ref(request))
    }
    func hasOffer() throws -> Bool { try observe(projection) != nil }
    func replaceSection(locator: TextLocator? = nil, segments: [LibraryTextSegment]? = nil, render: Bool = true) {
        let old = reader.backendSection!
        let section = LibraryTextSection(locator: locator ?? old.locator, displayRef: old.displayRef,
            heRef: old.heRef, segments: segments ?? old.segments, previous: nil, next: nil,
            versions: [], links: [], origin: .offline)
        reader.backendSection = section
        if render {
            reader.backendRenderModel = .init(section: section, preferredMode: .source)
            reader.contentText = reader.backendRenderModel!.text
        }
    }
}
@main struct HanlinCurrentWorkSourceAcceptance {
    @MainActor static func main() throws {
        var failed: [String] = [], executed: [String] = []
        func check(_ name: String, _ body: () throws -> Bool) {
            executed.append(name)
            do { if try body() { print("PASS \(name)") } else { failed.append(name); print("FAIL \(name) :: oracle") } }
            catch { failed.append(name); print("FAIL \(name) :: \(String(reflecting: type(of: error)))") }
        }
        check("exact_original_section_offers_current_work") { try Fixture().hasOffer() }
        check("requested_523_in_actual_522_unit_offers_current_work") {
            let f = Fixture(request: 523)
            guard f.reader.currentDestination?.sectionLocator == Fixture.ref(523),
                  f.reader.backendSection?.locator == Fixture.ref(522) else { return false }
            return try f.hasOffer()
        }
        check("containing_unit_without_focus_still_uses_requested_source") {
            let f = Fixture(request: 523)
            f.reader.currentDestination = .init(sectionLocator: Fixture.ref(523), focusLocator: nil)
            return try f.hasOffer()
        }
        check("native_ack_projection_remains_strict") {
            try Fixture(request: 523).projection.surface(.reader) == nil
        }
        check("source_from_another_work_denied") {
            let f = Fixture(); f.replaceSection(locator: Fixture.ref(522, work: "book:1"))
            return try !f.hasOffer()
        }
        check("source_from_another_backend_denied") {
            let f = Fixture(); f.replaceSection(locator: Fixture.ref(522, backend: .sefaria))
            return try !f.hasOffer()
        }
        check("active_backend_change_denied") {
            let f = Fixture(); BackendCoordinator.shared.activeBackendID = .sefaria
            return try !f.hasOffer()
        }
        check("missing_active_tab_denied") {
            let f = Fixture(); f.manager.activeTabId = nil; return try !f.hasOffer()
        }
        check("missing_actual_section_denied") {
            let f = Fixture(); f.reader.backendSection = nil; return try !f.hasOffer()
        }
        check("missing_requested_destination_denied") {
            let f = Fixture(); f.reader.currentDestination = nil; return try !f.hasOffer()
        }
        check("loading_reader_denied") {
            let f = Fixture(); f.reader.state = .loading; return try !f.hasOffer()
        }
        check("failed_reader_denied") {
            let f = Fixture(); f.reader.state = .error; return try !f.hasOffer()
        }
        check("empty_rendered_text_denied") {
            let f = Fixture(); f.reader.contentText = ""; return try !f.hasOffer()
        }
        check("missing_original_render_model_denied") {
            let f = Fixture(); f.reader.backendRenderModel = nil; return try !f.hasOffer()
        }
        check("render_model_text_mismatch_denied") {
            let f = Fixture(); f.reader.contentText += " changed"; return try !f.hasOffer()
        }
        check("foreign_focus_denied") {
            let f = Fixture()
            f.reader.currentDestination = .init(sectionLocator: Fixture.ref(522),
                focusLocator: Fixture.ref(523, work: "book:1"))
            return try !f.hasOffer()
        }
        check("focus_outside_actual_source_denied") {
            let f = Fixture()
            f.reader.currentDestination = .init(sectionLocator: Fixture.ref(522), focusLocator: Fixture.ref(900))
            return try !f.hasOffer()
        }
        check("requested_line_outside_actual_unit_denied") {
            try !Fixture(request: 900).hasOffer()
        }
        check("unrelated_canonical_reference_not_normalized") {
            let f = Fixture()
            let locator = TextLocator(backend: .otzaria, workKey: "book:3891", position: .canonicalRef("unrelated"))
            f.reader.currentDestination = .init(sectionLocator: locator, focusLocator: nil)
            f.reader.contentLoadCoordinator.beginRequest(backend: .otzaria, workKey: locator.workKey, sectionLocator: locator)
            return try !f.hasOffer()
        }
        check("settings_presentation_denied") {
            let f = Fixture(); f.projection.settingsPresented = true; return try !f.hasOffer()
        }
        check("another_top_level_tab_denied") {
            let f = Fixture(); f.projection.selectedTab = .search; return try !f.hasOffer()
        }
        check("another_manager_mode_denied") {
            let f = Fixture(); f.manager.currentMode = .search; return try !f.hasOffer()
        }
        check("reader_book_owner_mismatch_denied") {
            let f = Fixture(); f.reader.currentBook = .init(id: 1, backendLocator: Fixture.ref(0, work: "book:1"))
            return try !f.hasOffer()
        }
        check("request_token_identity_mismatch_denied") {
            let f = Fixture()
            f.reader.contentLoadCoordinator.beginRequest(backend: .otzaria, workKey: "book:3891", sectionLocator: Fixture.ref(900))
            return try !f.hasOffer()
        }
        check("invalidated_original_request_denied") {
            let f = Fixture(); f.reader.contentLoadCoordinator.invalidate(); return try !f.hasOffer()
        }
        check("same_work_aba_cannot_reuse_original_source_witness") {
            let f = Fixture(), before = try observe(f.projection)
            f.reader.contentLoadCoordinator.beginRequest(backend: .otzaria, workKey: "book:3891", sectionLocator: Fixture.ref(523))
            f.reader.contentLoadCoordinator.beginRequest(backend: .otzaria, workKey: "book:3891", sectionLocator: Fixture.ref(522))
            let after = try observe(f.projection)
            return before != nil && after != nil && before != after
        }
        check("exact_source_observation_is_stable_without_mutation") {
            let f = Fixture(), before = try observe(f.projection)
            let after = try observe(f.projection)
            return before != nil && before == after
        }
        guard Set(executed).count == executed.count else { fatalError("Duplicate cases") }
        print("EXECUTED \(executed.count) FAILED \(failed.count)")
        if !failed.isEmpty { exit(1) }
    }
}

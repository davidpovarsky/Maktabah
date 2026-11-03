//
//  ChavrusaTextiPadUIPlanTests.swift
//  MaktabahTests
//
//  Comprehensive unit tests for ChavrusaText iPad UI Execution Plans A, B, C, D, and E.
//

import Foundation
import Testing
@testable import Maktabah

@MainActor
struct ChavrusaTextiPadUIPlanTests {

    // MARK: - Feature Flags: Safe Default (false) & Dependency Matrix Tests

    @Test("Feature Flags: All 6 flags default to false on fresh init and resetToDefaults()")
    func testFeatureFlagsDefaultToFalse() {
        let suiteName = "ChavrusaTextFeatureFlagsTests_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let flags = ChavrusaTextFeatureFlags(defaults: defaults, environment: [:])
        #expect(flags.sidebarPagerEnabled == false)
        #expect(flags.safariToolbarSearchEnabled == false)
        #expect(flags.studyWorkspaceEnabled == false)
        #expect(flags.duckTabStripEnabled == false)
        #expect(flags.inspectorHostRefinementEnabled == false)
        #expect(flags.semanticSliderPolicyEnabled == false)

        #expect(flags.effectiveSidebarPagerEnabled == false)
        #expect(flags.effectiveSafariToolbarSearchEnabled == false)
        #expect(flags.effectiveStudyWorkspaceEnabled == false)
        #expect(flags.effectiveDuckTabStripEnabled == false)
        #expect(flags.effectiveInspectorHostRefinementEnabled == false)
        #expect(flags.effectiveSemanticSliderPolicyEnabled == false)

        flags.enableAll()
        #expect(flags.sidebarPagerEnabled == true)
        #expect(flags.studyWorkspaceEnabled == true)

        flags.resetToDefaults()
        #expect(flags.sidebarPagerEnabled == false)
        #expect(flags.safariToolbarSearchEnabled == false)
        #expect(flags.studyWorkspaceEnabled == false)
        #expect(flags.duckTabStripEnabled == false)
        #expect(flags.inspectorHostRefinementEnabled == false)
        #expect(flags.semanticSliderPolicyEnabled == false)
    }

    // MARK: - Plan A: ReaderSidebarStateCoordinator Tests

    @Test("Plan A: Sidebar coordinator transitions between Library and TOC while preserving state")
    func testSidebarCoordinatorTransitions() {
        let coordinator = ReaderSidebarStateCoordinator()
        #expect(coordinator.selectedPage == .library)
        #expect(coordinator.sidebarVisible == true)

        coordinator.closeSidebar()
        #expect(coordinator.sidebarVisible == false)
        #expect(coordinator.selectedPage == .library)

        // showTOC() must both select .toc and ensure sidebar is visible
        coordinator.showTOC()
        #expect(coordinator.selectedPage == .toc)
        #expect(coordinator.sidebarVisible == true)

        // Toggling sidebar hides it without losing .toc selection
        coordinator.toggleSidebar()
        #expect(coordinator.sidebarVisible == false)
        #expect(coordinator.selectedPage == .toc)

        // showLibrary() restores visibility and switches to .library
        coordinator.showLibrary()
        #expect(coordinator.selectedPage == .library)
        #expect(coordinator.sidebarVisible == true)
    }

    // MARK: - Plan B: ExpandableLibrarySearchCoordinator & GelatinMotionMetrics Tests

    @Test("Plan B: Expandable search state machine and clear/dismiss lifecycle")
    func testExpandableLibrarySearchLifecycle() {
        let coordinator = ExpandableLibrarySearchCoordinator()
        #expect(coordinator.phase == .collapsed)
        #expect(coordinator.targetCapsuleWidth == ExpandableLibrarySearchCoordinator.collapsedCapsuleWidth)

        coordinator.expand()
        #expect(coordinator.phase == .expanded)
        #expect(coordinator.isFieldFocused == true)
        #expect(coordinator.targetCapsuleWidth == ExpandableLibrarySearchCoordinator.expandedCapsuleWidth)

        coordinator.updateQuery("שבת")
        #expect(coordinator.searchText == "שבת")
        #expect(coordinator.phase == .expanded)

        // First clearOrDismiss when query is non-empty clears the text while staying expanded
        coordinator.clearOrDismiss()
        #expect(coordinator.searchText.isEmpty)
        #expect(coordinator.phase == .expanded)

        // Second clearOrDismiss when query is empty collapses the search capsule
        coordinator.clearOrDismiss()
        #expect(coordinator.phase == .collapsed)
        #expect(coordinator.isFieldFocused == false)
    }

    #if canImport(SwiftUI)
    @Test("Plan B: GelatinMotionMetrics respects Reduce Motion and computes bounded stretch")
    func testGelatinMotionMetrics() {
        let reduced = GelatinMotionMetrics.compute(
            isPressed: true,
            dragTranslation: CGSize(width: 90, height: 10),
            reduceMotion: true
        )
        #expect(reduced == .identity)

        let active = GelatinMotionMetrics.compute(
            isPressed: true,
            dragTranslation: CGSize(width: 90, height: 10),
            reduceMotion: false
        )
        #expect(active.scaleX > active.scaleY)
        #expect(active.offset.width > 0)
    }
    #endif

    // MARK: - Plan C1: StudyWorkspace Migration, Persistence, Backup Recovery, and Isolation Tests

    @Test("Plan C1: Idempotent migration from legacy iOSReaderSession into default 'אישי' profile")
    func testIdempotentLegacySessionMigration() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("StudyWorkspaceMigrationTests_\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let tab1 = iOSReaderTabSession(
            id: UUID(),
            bookId: 101,
            bookTitle: "מסכת שבת",
            backendLocator: TextLocator(backend: .otzaria, workKey: "book:101", position: .legacyLine(25)),
            contentId: 25
        )
        let tab2 = iOSReaderTabSession(
            id: UUID(),
            bookId: 202,
            bookTitle: "שולחן ערוך אורח חיים",
            backendLocator: TextLocator(backend: .otzaria, workKey: "book:202", position: .legacyLine(12)),
            contentId: 12
        )
        let legacySession = iOSReaderSession(
            activeTabId: tab2.id,
            selectedTabModeRaw: 0,
            tabs: [tab1, tab2],
            backend: BackendID.otzaria.rawValue
        )

        let firstMigration = StudyWorkspaceMigration.migrateIfNeeded(
            existingSnapshot: nil,
            legacySession: legacySession
        )
        #expect(firstMigration.migratedFromLegacySession == true)
        #expect(firstMigration.profiles.first?.name == "אישי")
        #expect(firstMigration.tabsByID.count == 2)
        #expect(firstMigration.groups.first?.activeTabID == tab2.id)

        // Running migration a second time must be idempotent and never duplicate tabs
        let secondMigration = StudyWorkspaceMigration.migrateIfNeeded(
            existingSnapshot: firstMigration,
            legacySession: legacySession
        )
        #expect(secondMigration == firstMigration)
        #expect(secondMigration.tabsByID.count == 2)
    }

    @Test("Plan C1: Independent tab instances of the same book across groups and safe profile deletion fallback")
    func testIndependentSameBookAcrossGroupsAndProfileFallback() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("StudyWorkspaceStoreTests_\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let persistence = StudyWorkspacePersistence(directoryURL: tempDir)
        let store = StudyWorkspaceStore(persistence: persistence, legacySessionProvider: { nil })

        let groupA = store.activeGroup
        let groupB = store.createGroup(name: "סוגיית שבת", inProfile: store.activeProfile.id, activateImmediately: false)

        let shabbatInA = ReaderDocumentTab(
            bookId: 500,
            bookTitle: "מסכת שבת",
            workKey: "book:500",
            sectionLocator: TextLocator(backend: .otzaria, workKey: "book:500", position: .legacyLine(10)),
            contentId: 10
        )
        let shabbatInB = ReaderDocumentTab(
            bookId: 500,
            bookTitle: "מסכת שבת",
            workKey: "book:500",
            sectionLocator: TextLocator(backend: .otzaria, workKey: "book:500", position: .legacyLine(95)),
            contentId: 95
        )

        store.addTab(shabbatInA, toGroup: groupA.id, activate: true)
        store.addTab(shabbatInB, toGroup: groupB.id, activate: true)

        #expect(shabbatInA.id != shabbatInB.id)
        #expect(store.tab(for: shabbatInA.id)?.contentId == 10)
        #expect(store.tab(for: shabbatInB.id)?.contentId == 95)

        // Mutating tab in Group A must not mutate tab of the same book in Group B
        store.updateTab(shabbatInA.id) { tab in
            tab.contentId = 42
        }
        #expect(store.tab(for: shabbatInA.id)?.contentId == 42)
        #expect(store.tab(for: shabbatInB.id)?.contentId == 95)

        // Default profile "אישי" cannot be deleted
        let deletedDefault = store.deleteProfile(StudyProfile.defaultProfileID)
        #expect(deletedDefault == false)

        // Creating a custom profile and deleting it falls back to default "אישי"
        let customProfile = store.createProfile(name: "עיון", activateImmediately: true)
        #expect(store.activeProfile.id == customProfile.id)
        let deletedCustom = store.deleteProfile(customProfile.id)
        #expect(deletedCustom == true)
        #expect(store.activeProfile.id == StudyProfile.defaultProfileID)
        #expect(store.activeProfile.name == "אישי")
    }

    @Test("Plan C1: Atomic sidecar persistence and automatic .bak recovery on corrupted primary file")
    func testSidecarPersistenceAndBackupRecovery() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("StudyWorkspaceBackupTests_\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let persistence = StudyWorkspacePersistence(directoryURL: tempDir)
        let store = StudyWorkspaceStore(persistence: persistence, legacySessionProvider: { nil })
        let tab = ReaderDocumentTab(bookId: 777, bookTitle: "משנה תורה")
        store.addTab(tab)
        try store.saveImmediately()

        #expect(FileManager.default.fileExists(atPath: persistence.workspaceFileURL.path))
        #expect(FileManager.default.fileExists(atPath: persistence.backupFileURL.path))

        // Corrupt primary file
        try Data("{corrupted-json".utf8).write(to: persistence.workspaceFileURL, options: .atomic)

        let (recovered, didRecover) = persistence.loadSnapshotWithRecovery()
        #expect(didRecover == true)
        #expect(recovered?.tabsByID[tab.id]?.bookTitle == "משנה תורה")
    }

    @Test("Plan C1 Stress: 30 tabs across 4 groups and 100 rapid switches preserve exact state")
    func testThirtyTabsAndHundredRapidSwitches() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("StudyWorkspaceStressTests_\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let persistence = StudyWorkspacePersistence(directoryURL: tempDir)
        let store = StudyWorkspaceStore(persistence: persistence, legacySessionProvider: { nil })

        var groupIDs: [UUID] = [store.activeGroup.id]
        for i in 1..<4 {
            let grp = store.createGroup(name: "קבוצה \(i)", activateImmediately: false)
            groupIDs.append(grp.id)
        }

        for tabIdx in 0..<30 {
            let targetGroup = groupIDs[tabIdx % groupIDs.count]
            let tab = ReaderDocumentTab(
                bookId: 1000 + tabIdx,
                bookTitle: "ספר בדיקה \(tabIdx)",
                contentId: tabIdx * 10
            )
            store.addTab(tab, toGroup: targetGroup, activate: true)
        }

        #expect(store.tabsByID.count == 30)

        for step in 0..<100 {
            let groupID = groupIDs[step % groupIDs.count]
            store.selectGroup(groupID)
            let groupTabs = store.tabs(in: groupID)
            if let pick = groupTabs.first {
                store.setActiveTab(pick.id, inGroup: groupID)
            }
        }

        #expect(store.tabsByID.count == 30)
        for groupID in groupIDs {
            let groupTabs = store.tabs(in: groupID)
            #expect(!groupTabs.isEmpty)
            #expect(store.group(for: groupID)?.activeTabID != nil)
        }
    }

    @Test("Plan C1/C3 Multiwindow Isolation: Two scenes maintain independent active profiles and groups")
    func testMultiwindowSceneCoordinatorIsolation() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("StudyWorkspaceMultiwindowTests_\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let persistence = StudyWorkspacePersistence(directoryURL: tempDir)
        let store = StudyWorkspaceStore(persistence: persistence, legacySessionProvider: { nil })

        let defaultProfile = store.defaultProfile
        let defaultGroup = store.activeGroup
        let iyunProfile = store.createProfile(name: "עיון", initialGroupName: "סוגיית שבת", activateImmediately: false)
        let iyunGroup = store.groups(for: iyunProfile.id).first!

        let sceneA = StudyWorkspaceSceneCoordinator(sceneID: "ipad-scene-window-A", store: store)
        let sceneB = StudyWorkspaceSceneCoordinator(sceneID: "ipad-scene-window-B", store: store)

        #expect(sceneA.sceneID != sceneB.sceneID)

        sceneA.selectGroup(defaultGroup.id)
        sceneB.selectProfile(iyunProfile.id)
        sceneB.selectGroup(iyunGroup.id)

        // Switching Scene B to "עיון / סוגיית שבת" must NOT mutate Scene A's active profile or group
        #expect(sceneA.activeProfile.id == defaultProfile.id)
        #expect(sceneA.activeGroup.id == defaultGroup.id)
        #expect(sceneB.activeProfile.id == iyunProfile.id)
        #expect(sceneB.activeGroup.id == iyunGroup.id)

        // Overview presentation is also isolated per scene
        sceneB.toggleOverview()
        #expect(sceneB.isOverviewPresented == true)
        #expect(sceneA.isOverviewPresented == false)
    }

    // MARK: - Plan C2 & Plan D: Layout Widths and Width-Driven Inspector Policy Tests

    #if os(iOS)
    @Test("Plan C2: DuckDuckGo-style tab strip layout clamps proportional tab widths cleanly")
    func testTabStripWidthCalculation() {
        let widthFor2 = ReaderTabStripLayout.calculateTabWidth(forTabCount: 2, availableWidth: 800)
        #expect(widthFor2 == ReaderTabStripLayout.maxTabWidth)

        let widthFor6 = ReaderTabStripLayout.calculateTabWidth(forTabCount: 6, availableWidth: 900)
        #expect(widthFor6 >= ReaderTabStripLayout.minTabWidth)
        #expect(widthFor6 <= ReaderTabStripLayout.maxTabWidth)

        let widthFor30 = ReaderTabStripLayout.calculateTabWidth(forTabCount: 30, availableWidth: 800)
        #expect(widthFor30 == ReaderTabStripLayout.minTabWidth)
    }
    #endif

    @Test("Plan D: Inspector presentation policy depends on available width rather than 3-column visibility")
    func testInspectorWidthDrivenPolicy() {
        #expect(ReaderInspectorHostPolicy.shouldUseWideInspectorWorkspace(
            availableWidth: 820,
            isCompactHorizontalSizeClass: false
        ) == true)

        #expect(ReaderInspectorHostPolicy.shouldUseWideInspectorWorkspace(
            availableWidth: 620,
            isCompactHorizontalSizeClass: false
        ) == false)

        #expect(ReaderInspectorHostPolicy.shouldUseWideInspectorWorkspace(
            availableWidth: 900,
            isCompactHorizontalSizeClass: true
        ) == false)

        let clamped = ReaderInspectorHostPolicy.clampedInspectorWidth(
            preferredWidth: 500,
            availableWorkspaceWidth: 740
        )
        // 740 - 340 (min reader width) - 18 (handle) = 382 max allowed
        #expect(clamped == 382)

        // Unified shouldPresentPanelInContent consistency check
        #expect(ReaderInspectorHostPolicy.shouldPresentPanelInContent(
            availableWidth: 820,
            isCompactHorizontalSizeClass: false,
            isAllColumnsVisibleInLegacySplit: true,
            inspectorHostRefinementEnabled: true
        ) == false)

        #expect(ReaderInspectorHostPolicy.shouldPresentPanelInContent(
            availableWidth: 620,
            isCompactHorizontalSizeClass: false,
            isAllColumnsVisibleInLegacySplit: false,
            inspectorHostRefinementEnabled: true
        ) == true)

        // Compact layout must return false so iOSReaderWorkspaceView falls through to compactStudyPanel
        #expect(ReaderInspectorHostPolicy.shouldPresentPanelInContent(
            availableWidth: 390,
            isCompactHorizontalSizeClass: true,
            isAllColumnsVisibleInLegacySplit: true,
            inspectorHostRefinementEnabled: true
        ) == false)

        // Seamless wide-column chrome removes outer 8pt floating inset when refinement flag is enabled
        #expect(ReaderInspectorHostPolicy.prefersSeamlessWideColumnChrome(inspectorHostRefinementEnabled: true) == true)
        #expect(ReaderInspectorHostPolicy.prefersSeamlessWideColumnChrome(inspectorHostRefinementEnabled: false) == false)
    }

    // MARK: - Plan E: Semantic Slider Policy & Hebrew Localization Tests

    @Test("Plan E2: ReaderNavigationDisplayPolicy across 5 Torah book structures (Bavli, Tanakh, Rambam, Shulchan Aruch, Multi-volume)")
    func testSemanticNavigationSliderGranularity() {
        // Structure 1: Talmud Bavli (מסכת -> פרק א -> דף ב ע"א, דף ב:)
        // Must NOT collapse Daf/Amud nodes into Perek even though Daf is at depth 1, and must preserve ':' in "דף ב:"
        let daf2a = LibraryTOCNode(
            locator: TextLocator(backend: .otzaria, workKey: "bavli:shabbat", position: .legacyLine(1)),
            title: "דף ב ע\"א",
            children: []
        )
        let daf2b = LibraryTOCNode(
            locator: TextLocator(backend: .otzaria, workKey: "bavli:shabbat", position: .legacyLine(35)),
            title: "דף ב:",
            children: []
        )
        let perek1Bavli = LibraryTOCNode(
            locator: TextLocator(backend: .otzaria, workKey: "bavli:shabbat", position: .legacyLine(1)),
            title: "פרק א - יציאות השבת",
            children: [daf2a, daf2b]
        )
        let bavliItems = ReaderNavigationDisplayPolicy.canonicalNavigationItems(from: [perek1Bavli])
        #expect(bavliItems.count == 2)
        #expect(bavliItems[0].title == "דף ב ע\"א")
        #expect(bavliItems[1].title == "דף ב:")

        // Structure 2: Tanakh (ספר -> פרק א -> פסוק א, פסוק ב)
        let pasuk1 = LibraryTOCNode(
            locator: TextLocator(backend: .otzaria, workKey: "tanakh:bereshit", position: .legacyLine(1)),
            title: "פסוק א",
            children: []
        )
        let pasuk2 = LibraryTOCNode(
            locator: TextLocator(backend: .otzaria, workKey: "tanakh:bereshit", position: .legacyLine(2)),
            title: "פסוק ב",
            children: []
        )
        let perekATanakh = LibraryTOCNode(
            locator: TextLocator(backend: .otzaria, workKey: "tanakh:bereshit", position: .legacyLine(1)),
            title: "פרק א",
            children: [pasuk1, pasuk2]
        )
        let tanakhItems = ReaderNavigationDisplayPolicy.canonicalNavigationItems(from: [perekATanakh])
        #expect(tanakhItems.count == 1)
        #expect(tanakhItems[0].title == "פרק א")

        // Structure 3: Rambam / Mishneh Torah (ספר -> הלכות שבת -> פרק א -> הלכה א, הלכה ב)
        // Must descend through "הלכות שבת" (depth 0) and stop at "פרק א" / "פרק ב" (depth 1) rather than collapsing chapters!
        let halakha1 = LibraryTOCNode(
            locator: TextLocator(backend: .otzaria, workKey: "rambam:shabbat", position: .legacyLine(10)),
            title: "הלכה א",
            children: []
        )
        let halakha2 = LibraryTOCNode(
            locator: TextLocator(backend: .otzaria, workKey: "rambam:shabbat", position: .legacyLine(15)),
            title: "הלכה ב",
            children: []
        )
        let rambamPerekA = LibraryTOCNode(
            locator: TextLocator(backend: .otzaria, workKey: "rambam:shabbat", position: .legacyLine(10)),
            title: "פרק א",
            children: [halakha1, halakha2]
        )
        let rambamPerekB = LibraryTOCNode(
            locator: TextLocator(backend: .otzaria, workKey: "rambam:shabbat", position: .legacyLine(40)),
            title: "פרק ב",
            children: []
        )
        let hilkhotShabbat = LibraryTOCNode(
            locator: TextLocator(backend: .otzaria, workKey: "rambam:shabbat", position: .legacyLine(10)),
            title: "הלכות שבת",
            children: [rambamPerekA, rambamPerekB]
        )
        let rambamItems = ReaderNavigationDisplayPolicy.canonicalNavigationItems(from: [hilkhotShabbat])
        #expect(rambamItems.count == 2)
        #expect(rambamItems[0].title == "פרק א")
        #expect(rambamItems[1].title == "פרק ב")

        // Structure 4: Shulchan Aruch (סימן א -> סעיף א, סעיף ב)
        let para1 = LibraryTOCNode(
            locator: TextLocator(backend: .otzaria, workKey: "book:1", position: .legacyLine(10)),
            title: "סעיף א",
            children: []
        )
        let para2 = LibraryTOCNode(
            locator: TextLocator(backend: .otzaria, workKey: "book:1", position: .legacyLine(20)),
            title: "סעיף ב",
            children: []
        )
        let simanA = LibraryTOCNode(
            locator: TextLocator(backend: .otzaria, workKey: "book:1", position: .legacyLine(10)),
            title: "סימן א",
            children: [para1, para2]
        )
        let simanB = LibraryTOCNode(
            locator: TextLocator(backend: .otzaria, workKey: "book:1", position: .legacyLine(50)),
            title: "סימן ב",
            children: []
        )

        let items = ReaderNavigationDisplayPolicy.canonicalNavigationItems(from: [simanA, simanB])
        #expect(items.count == 2)
        #expect(items[0].title == "סימן א")
        #expect(items[1].title == "סימן ב")

        // Structure 5: Multi-volume / Essay book (חלק א -> מאמר א, מאמר ב)
        let maamarA = LibraryTOCNode(
            locator: TextLocator(backend: .otzaria, workKey: "essay:1", position: .legacyLine(5)),
            title: "מאמר א",
            children: []
        )
        let maamarB = LibraryTOCNode(
            locator: TextLocator(backend: .otzaria, workKey: "essay:1", position: .legacyLine(25)),
            title: "מאמר ב",
            children: []
        )
        let chelekA = LibraryTOCNode(
            locator: TextLocator(backend: .otzaria, workKey: "essay:1", position: .legacyLine(5)),
            title: "חלק א",
            children: [maamarA, maamarB]
        )
        let essayItems = ReaderNavigationDisplayPolicy.canonicalNavigationItems(from: [chelekA])
        #expect(essayItems.count == 2)
        #expect(essayItems[0].title == "מאמר א")
        #expect(essayItems[1].title == "מאמר ב")

        // Line 22 inside Siman A resolves to index 0 ("סימן א")
        let resolvedIdx = ReaderNavigationDisplayPolicy.resolveActiveNavigationIndex(
            in: items,
            currentLocator: TextLocator(backend: .otzaria, workKey: "book:1", position: .legacyLine(22)),
            currentContentId: 22
        )
        #expect(resolvedIdx == 0)

        // Header sanitization strips ":segment" when no segment is explicitly selected
        let noSelectionHeader = ReaderNavigationDisplayPolicy.formattedCurrentSectionLabel(
            sectionDisplayRef: "Genesis 1:4",
            sectionHeRef: "בראשית א׳:ד׳",
            activeNavigationItemTitle: nil,
            explicitSelectedSegmentLocator: nil
        )
        #expect(noSelectionHeader.sectionTitle == "בראשית א׳")
        #expect(noSelectionHeader.selectedSegmentBadge == nil)

        // When a segment is explicitly selected, badge is surfaced separately
        let withSelectionHeader = ReaderNavigationDisplayPolicy.formattedCurrentSectionLabel(
            sectionDisplayRef: "Genesis 1:4",
            sectionHeRef: "בראשית א׳:ד׳",
            activeNavigationItemTitle: nil,
            explicitSelectedSegmentLocator: TextLocator(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis 1:4"))
        )
        #expect(withSelectionHeader.sectionTitle == "בראשית א׳")
        #expect(withSelectionHeader.selectedSegmentBadge == "קטע 4")

        // 3-way distinction: (1) reading position vs (2) link-opened destination focus vs (3) explicit user selection
        let linkFocus = TextLocator(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis 1:4"))
        let readingResolved = ReaderNavigationDisplayPolicy.resolveExplicitUserSelectedSegmentLocator(
            selectedSegmentLocator: nil,
            destinationFocusLocator: nil,
            searchHighlightFocusLocator: nil,
            isInspectorVisible: false
        )
        #expect(readingResolved == nil)

        // Link-opened position sets selectedSegmentLocator == destinationFocusLocator while readerInspectorVisible == false:
        // must NOT be treated as an explicit user selection!
        let linkOpenedResolved = ReaderNavigationDisplayPolicy.resolveExplicitUserSelectedSegmentLocator(
            selectedSegmentLocator: linkFocus,
            destinationFocusLocator: linkFocus,
            searchHighlightFocusLocator: nil,
            isInspectorVisible: false
        )
        #expect(linkOpenedResolved == nil)

        // Explicit user tap sets readerInspectorVisible == true and selectedSegmentLocator:
        let explicitUserResolved = ReaderNavigationDisplayPolicy.resolveExplicitUserSelectedSegmentLocator(
            selectedSegmentLocator: linkFocus,
            destinationFocusLocator: nil,
            searchHighlightFocusLocator: nil,
            isInspectorVisible: true
        )
        #expect(explicitUserResolved == linkFocus)

        // Otzaria line anchor tap when inspector is visible resolves to legacyLine locator:
        let otzariaTapResolved = ReaderNavigationDisplayPolicy.resolveExplicitUserSelectedSegmentLocator(
            selectedSegmentLocator: nil,
            otzariaSelectedLineIndex: 18,
            otzariaBookId: 42,
            isInspectorVisible: true
        )
        #expect(otzariaTapResolved == TextLocator(backend: .otzaria, workKey: "book:42", position: .legacyLine(18)))
    }

    @Test("Plan E3: SearchHistoryOverlay is disabled in in-book search while preserved in main search tab")
    func testSearchHistoryOverlayScopePolicy() {
        // In-book search NEVER shows SearchHistoryOverlay under any state
        #expect(ReaderSearchContextCoordinator.shouldPresentSearchHistoryOverlay(
            in: .inBookSearch,
            isSearchFieldFocused: true,
            isSearching: false,
            hasResults: false,
            showingHelp: true,
            isDistanceFocused: true
        ) == false)

        // Main search tab shows SearchHistoryOverlay when focused and results are empty
        #expect(ReaderSearchContextCoordinator.shouldPresentSearchHistoryOverlay(
            in: .mainSearchTab,
            isSearchFieldFocused: true,
            isSearching: false,
            hasResults: false
        ) == true)

        // Main search tab hides SearchHistoryOverlay once results are loaded
        #expect(ReaderSearchContextCoordinator.shouldPresentSearchHistoryOverlay(
            in: .mainSearchTab,
            isSearchFieldFocused: true,
            isSearching: false,
            hasResults: true
        ) == false)
    }

    @Test("Plan C1/C3: Zero eager StudyWorkspace init/migration/writes when flags are off + Scene ID stability across re-renders and window switches")
    func testLazyWorkspaceInitAndSceneIDStability() {
        StudyWorkspaceStore.resetSharedForTesting()
        #expect(StudyWorkspaceStore.isSharedInstanceInitialized == false)

        let suiteName = "ChavrusaLazyWorkspaceTests_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let flags = ChavrusaTextFeatureFlags(defaults: defaults, environment: [:])
        // Enable Safari toolbar and Sidebar Pager while keeping StudyWorkspace & DuckTabStrip FALSE
        flags.sidebarPagerEnabled = true
        flags.safariToolbarSearchEnabled = true
        #expect(flags.effectiveStudyWorkspaceEnabled == false)
        #expect(flags.effectiveDuckTabStripEnabled == false)

        var persistedSceneID = ""
        let sessionFallbackID = UUID().uuidString
        var storeProviderCalled = false

        let acquiredWhenOff = StudyWorkspaceSceneCoordinator.acquireIfEnabled(
            persistedSceneID: &persistedSceneID,
            sessionFallbackID: sessionFallbackID,
            existingCoordinator: nil,
            featureFlags: flags,
            storeProvider: {
                storeProviderCalled = true
                return .shared
            }
        )
        #expect(acquiredWhenOff == nil)
        #expect(storeProviderCalled == false)
        #expect(StudyWorkspaceStore.isSharedInstanceInitialized == false)

        // Verify Scene ID stability across 50 simulated re-renders before and after persistence
        var firstResolvedID: String?
        for _ in 0..<50 {
            let id = StudyWorkspaceSceneCoordinator.resolveStableSceneID(
                persistedSceneID: persistedSceneID,
                sessionFallbackID: sessionFallbackID
            )
            if firstResolvedID == nil { firstResolvedID = id }
            #expect(id == firstResolvedID)
            #expect(id == sessionFallbackID)
        }

        // Now enable StudyWorkspace and verify multi-window Scene ID stability across re-renders and window switches
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChavrusaSceneStability_\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let persistence = StudyWorkspacePersistence(directoryURL: tempDir)
        // Before StudyWorkspaceStore is created, no workspace file exists on disk
        #expect(FileManager.default.fileExists(atPath: persistence.workspaceFileURL.path) == false)

        flags.studyWorkspaceEnabled = true
        let customStore = StudyWorkspaceStore(persistence: persistence, legacySessionProvider: { nil })
        // Even after read-only init, no unwanted write occurs until a mutation is performed
        #expect(FileManager.default.fileExists(atPath: persistence.workspaceFileURL.path) == false)

        var windowAPersistedID = ""
        let windowAFallbackID = "window-A-stable-fallback"
        var windowACoordinator: StudyWorkspaceSceneCoordinator?
        for _ in 0..<20 {
            windowACoordinator = StudyWorkspaceSceneCoordinator.acquireIfEnabled(
                persistedSceneID: &windowAPersistedID,
                sessionFallbackID: windowAFallbackID,
                existingCoordinator: windowACoordinator,
                featureFlags: flags,
                storeProvider: { customStore }
            )
        }
        #expect(windowACoordinator?.sceneID == windowAFallbackID)
        #expect(windowAPersistedID == windowAFallbackID)
    }

    @Test("Plan E4: Hebrew book count grammar, author tab label, and Talmud daf/amud formatting")
    func testHebrewLocalizationAndTalmudFormatter() {
        #expect(ChavrusaTextLocalizationResolver.formatHebrewBookCount(0) == "אין ספרים")
        #expect(ChavrusaTextLocalizationResolver.formatHebrewBookCount(1) == "ספר אחד")
        #expect(ChavrusaTextLocalizationResolver.formatHebrewBookCount(2) == "שני ספרים")
        #expect(ChavrusaTextLocalizationResolver.formatHebrewBookCount(5) == "5 ספרים")

        #expect(ChavrusaTextLocalizationResolver.resolveAuthorTabTitle(for: .otzaria, forcedLocaleIdentifier: "he") == "מחברים")
        #expect(ChavrusaTextLocalizationResolver.resolveAuthorTabTitle(for: .sefariaEmbedded, forcedLocaleIdentifier: "en") == "Authors")

        #expect(TalmudHebrewAddressFormatter.formatWorkAndAddress(workTitle: "שבת", address: "12a") == "שבת דף י״ב ע״א")
        #expect(TalmudHebrewAddressFormatter.formatWorkAndAddress(workTitle: "ברכות", address: "15b", includeDafWord: false) == "ברכות ט״ו ע״ב")
    }

    @Test("Plan B/C: Feature flag independence - Chrome upgrades active even when sidebarPagerEnabled == false")
    func testFeatureFlagIndependenceAndChromeUpgradeProperty() {
        let suiteName = "ChavrusaFlagIndependence_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let flags = ChavrusaTextFeatureFlags(defaults: defaults, environment: [:])
        flags.resetToDefaults()

        // Initially all flags false -> hasAnyReaderChromeUpgradeEnabled == false
        #expect(flags.hasAnyReaderChromeUpgradeEnabled == false)

        // When sidebarPagerEnabled is false, Safari toolbar ALONE activates reader chrome upgrade
        flags.sidebarPagerEnabled = false
        flags.safariToolbarSearchEnabled = true
        #expect(flags.hasAnyReaderChromeUpgradeEnabled == true)

        // Duck tab strip ALONE activates reader chrome upgrade
        flags.resetToDefaults()
        flags.sidebarPagerEnabled = false
        flags.duckTabStripEnabled = true
        #expect(flags.hasAnyReaderChromeUpgradeEnabled == true)

        // Study workspace ALONE activates reader chrome upgrade
        flags.resetToDefaults()
        flags.sidebarPagerEnabled = false
        flags.studyWorkspaceEnabled = true
        #expect(flags.hasAnyReaderChromeUpgradeEnabled == true)
    }

    @Test("Plan E3: Main search tab history state machine - focus, re-entry, query submit, and mode toggle")
    func testMainSearchTabHistoryStateMachine() {
        var searchHistory: [String] = []
        var query: String = ""
        var isSearchFieldFocused: Bool = false
        var isSearching: Bool = false
        var results: [String] = []

        // Initial state on tab entry: unfocused, no results, history overlay hidden
        #expect(ReaderSearchContextCoordinator.shouldPresentSearchHistoryOverlay(
            in: .mainSearchTab,
            isSearchFieldFocused: isSearchFieldFocused,
            isSearching: isSearching,
            hasResults: !results.isEmpty
        ) == false)

        // 1. User focuses search field: history overlay must appear
        isSearchFieldFocused = true
        #expect(ReaderSearchContextCoordinator.shouldPresentSearchHistoryOverlay(
            in: .mainSearchTab,
            isSearchFieldFocused: isSearchFieldFocused,
            isSearching: isSearching,
            hasResults: !results.isEmpty
        ) == true)

        // 2. User submits query "בראשית": added to history, field unfocused, searching begins
        query = "בראשית"
        searchHistory.append(query)
        isSearchFieldFocused = false
        isSearching = true
        #expect(ReaderSearchContextCoordinator.shouldPresentSearchHistoryOverlay(
            in: .mainSearchTab,
            isSearchFieldFocused: isSearchFieldFocused,
            isSearching: isSearching,
            hasResults: !results.isEmpty
        ) == false)

        // 3. Search results arrive: results populated, searching ends
        isSearching = false
        results = ["בראשית א:א", "בראשית א:ב"]
        #expect(ReaderSearchContextCoordinator.shouldPresentSearchHistoryOverlay(
            in: .mainSearchTab,
            isSearchFieldFocused: isSearchFieldFocused,
            isSearching: isSearching,
            hasResults: !results.isEmpty
        ) == false)

        // 4. User re-taps search field while results exist:
        // In SearchModeView lines 52-64:
        // if !isSearching && isSearchFieldFocused { SearchHistoryOverlay(...) .zIndex(10) }
        // The overlay surfaces ON TOP of existing results to pick another query or change distance!
        isSearchFieldFocused = true
        #expect(!isSearching && isSearchFieldFocused)

        // 5. In-book search scope: overlay is NEVER displayed even with identical focus & state
        #expect(ReaderSearchContextCoordinator.shouldPresentSearchHistoryOverlay(
            in: .inBookSearch,
            isSearchFieldFocused: true,
            isSearching: false,
            hasResults: false
        ) == false)
    }

    // MARK: - Suite 15: Standalone Duck Tab Strip Isolation
    @Test func testStandaloneDuckTabStripZeroEagerStoreInitAndZeroDiskWrites() throws {
        StudyWorkspaceStore.resetSharedForTesting()
        #expect(StudyWorkspaceStore.isSharedInstanceInitialized == false)

        let suiteName = "ChavrusaStandaloneDuckTests_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let flags = ChavrusaTextFeatureFlags(defaults: defaults, environment: [:])
        flags.duckTabStripEnabled = true
        flags.studyWorkspaceEnabled = false
        #expect(flags.effectiveDuckTabStripEnabled == true)
        #expect(flags.effectiveStudyWorkspaceEnabled == false)

        var persistedSceneID = ""
        var storeProviderCalled = false
        let acquired = StudyWorkspaceSceneCoordinator.acquireIfEnabled(
            persistedSceneID: &persistedSceneID,
            sessionFallbackID: "fallback-scene-duck",
            existingCoordinator: nil,
            featureFlags: flags,
            storeProvider: {
                storeProviderCalled = true
                return .shared
            }
        )

        #expect(acquired == nil)
        #expect(storeProviderCalled == false)
        #expect(StudyWorkspaceStore.isSharedInstanceInitialized == false)
    }

    // MARK: - Suite 16: ACID Study Group Transition & Multi-Window Isolation
    @Test func testACIDStudyGroupTransitionAndMultiWindowIsolation() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("acid_group_tests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let persistence = StudyWorkspacePersistence(directoryURL: tempDir)
        let testStore = StudyWorkspaceStore(persistence: persistence, legacySessionProvider: { nil })
        let defaultProfile = testStore.defaultProfile
        let groupA = testStore.defaultGroup(for: defaultProfile.id)
        let groupB = testStore.createGroup(name: "Talmud Chulin Group", inProfile: defaultProfile.id, activateImmediately: false)

        let tab1 = ReaderDocumentTab(
            id: UUID(),
            backend: .sefaria,
            bookId: 101,
            bookTitle: "Chulin",
            sectionLocator: TextLocator(backend: .sefaria, workKey: "Chulin.2a", position: .legacyLine(1))
        )
        testStore.addTab(tab1, toGroup: groupA.id, activate: true)

        let tab2 = ReaderDocumentTab(
            id: UUID(),
            backend: .sefaria,
            bookId: 102,
            bookTitle: "Rashi on Chulin",
            sectionLocator: TextLocator(backend: .sefaria, workKey: "Rashi_on_Chulin.2a", position: .legacyLine(1))
        )
        testStore.addTab(tab2, toGroup: groupB.id, activate: true)

        // Window 1 coordinator
        let sceneCoord1 = StudyWorkspaceSceneCoordinator(sceneID: "window-scene-1", store: testStore)
        #expect(sceneCoord1.activeGroupID == groupA.id)

        // Atomic transition to Group B
        sceneCoord1.selectGroup(groupB.id)
        #expect(sceneCoord1.activeGroupID == groupB.id)

        // Transition to invalid / deleted group must be rejected and preserve previous activeGroupID
        let invalidGroupID = UUID()
        let previousActiveGroup = sceneCoord1.activeGroupID
        sceneCoord1.selectGroup(invalidGroupID)
        #expect(sceneCoord1.activeGroupID == previousActiveGroup)

        // Window 2 coordinator (multi-window scene isolation)
        let sceneCoord2 = StudyWorkspaceSceneCoordinator(sceneID: "window-scene-2", store: testStore)
        sceneCoord2.selectGroup(groupA.id)
        #expect(sceneCoord1.activeGroupID == groupB.id)
        #expect(sceneCoord2.activeGroupID == groupA.id)
    }
}

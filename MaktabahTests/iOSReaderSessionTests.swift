//
//  iOSReaderSessionTests.swift
//  MaktabahTests
//
//  Unit tests for durable iOS Reader Session Persistence (F01).
//

import CoreGraphics
import Foundation
@testable import Maktabah_Debug
import Testing

@Suite("iOS Reader Session Persistence Suite (F01)")
struct iOSReaderSessionTests {
    @Test("Codable roundtrip: serializes and restores complete reader session")
    func testSessionCodableRoundtrip() throws {
        let tabId1 = UUID()
        let tabId2 = UUID()

        let locator = TextLocator(
            backend: .otzaria,
            workKey: "bavli_berakhot",
            position: .legacyLine(42)
        )

        let tab1 = iOSReaderTabSession(
            id: tabId1,
            bookId: 101,
            bookTitle: "Berakhot",
            backendLocator: locator,
            contentId: 501,
            locator: locator,
            page: 2,
            part: 1,
            scrollPosition: CGPoint(x: 0, y: 1450.5),
            selectedRange: NSRange(location: 20, length: 35),
            expandedNodeIDs: [1, 5, 9],
            sidebarScrollPosition: CGPoint(x: 0, y: 120),
            isSidebarCollapsed: false,
            searchText: "תפילה",
            searchModeRaw: 0,
            nearDistance: 10,
            highlightTerms: ["תפילה", "שחרית"]
        )

        let tab2 = iOSReaderTabSession(
            id: tabId2,
            bookId: 202,
            bookTitle: "Shabbat",
            backendLocator: nil,
            contentId: 802,
            locator: nil,
            page: 15,
            part: 2,
            scrollPosition: CGPoint(x: 0, y: 300.0),
            selectedRange: nil,
            expandedNodeIDs: [],
            sidebarScrollPosition: nil,
            isSidebarCollapsed: true,
            searchText: nil,
            searchModeRaw: nil,
            nearDistance: nil,
            highlightTerms: nil
        )

        let session = iOSReaderSession(
            schemaVersion: iOSReaderSession.currentSchemaVersion,
            savedAt: Date(),
            activeTabId: tabId1,
            selectedTabModeRaw: AppMode.viewer.rawValue,
            tabs: [tab1, tab2]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(session)

        let decoder = JSONDecoder()
        let decodedSession = try decoder.decode(iOSReaderSession.self, from: data)

        #expect(decodedSession.schemaVersion == iOSReaderSession.currentSchemaVersion)
        #expect(decodedSession.activeTabId == tabId1)
        #expect(decodedSession.selectedTabMode == .viewer)
        #expect(decodedSession.tabs.count == 2)

        let restoredTab1 = decodedSession.tabs[0]
        #expect(restoredTab1.id == tabId1)
        #expect(restoredTab1.bookId == 101)
        #expect(restoredTab1.bookTitle == "Berakhot")
        #expect(restoredTab1.backendLocator == locator)
        #expect(restoredTab1.contentId == 501)
        #expect(restoredTab1.scrollPosition?.y == 1450.5)
        #expect(restoredTab1.selectedRange == NSRange(location: 20, length: 35))
        #expect(restoredTab1.expandedNodeIDs == [1, 5, 9])
        #expect(restoredTab1.searchText == "תפילה")
        #expect(restoredTab1.highlightTerms == ["תפילה", "שחרית"])

        let restoredTab2 = decodedSession.tabs[1]
        #expect(restoredTab2.id == tabId2)
        #expect(restoredTab2.bookId == 202)
        #expect(restoredTab2.scrollPosition?.y == 300.0)
        #expect(restoredTab2.isSidebarCollapsed == true)
        #expect(restoredTab2.searchText == nil)
    }

    @Test("Resilience: handles missing optional fields gracefully")
    func testSessionResilienceWithMissingFields() throws {
        let minimalJson = """
        {
            "schemaVersion": 1,
            "savedAt": 1729520000,
            "activeTabId": "00000000-0000-0000-0000-000000000001",
            "selectedTabModeRaw": 0,
            "tabs": [
                {
                    "id": "00000000-0000-0000-0000-000000000001",
                    "bookId": 42
                }
            ]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let session = try decoder.decode(iOSReaderSession.self, from: minimalJson)

        #expect(session.tabs.count == 1)
        let tab = session.tabs[0]
        #expect(tab.bookId == 42)
        #expect(tab.contentId == nil)
        #expect(tab.scrollPosition == nil)
        #expect(tab.backendLocator == nil)
        #expect(tab.searchText == nil)
    }
}

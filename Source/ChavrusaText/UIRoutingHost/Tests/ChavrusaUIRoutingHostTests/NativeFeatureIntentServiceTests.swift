import Foundation
import XCTest
import OtzariaActionCore
import OtzariaUIRouting
@testable import ChavrusaUIRoutingHost

@MainActor
final class NativeFeatureIntentServiceTests: XCTestCase, @unchecked Sendable {
    private func destination(_ root: String, component: String? = nil,
                             title: String = "Destination", scene: String = "scene.A",
                             backend: ActionBackendID = .otzaria) -> NativeIntentService.Destination {
        .init(backend: backend, destination: UIDestinationID(rawValue: root)!,
              title: title, sceneID: UIStableID(rawValue: scene)!,
              component: component.map { UIDestinationID(rawValue: $0)! })
    }

    func testCatalogExposesOnlyExistingSettingsAndContentsAnchorsAndHistoryRoot() async throws {
        let settings = [
            "backend", "offline", "databaseMode", "history", "storage", "annotations",
            "cloud", "appearance", "searchData", "searchCredits", "searchIndex",
            "optimization", "updates", "downloads", "miniApps"
        ].map { destination("native.settings", component: "native.settings." + $0) }
        let toc = [destination("native.reader.toc")] + [
            "contents", "structure", "currentSelection"
        ].map { destination("native.reader.toc", component: "native.reader.toc." + $0) }
        let history = destination("native.history")
        let other = [
            destination("native.settings"),
            destination("native.settings", component: "native.settings.backend.extra"),
            destination("native.reader.toc", component: "native.reader.toc.unknown"),
            destination("native.history", component: "native.history.row"),
            destination("native.library"), destination("native.reader")
        ]
        let service = NativeIntentService(discover: { settings + toc + [history] + other },
                                           navigate: { _ in XCTFail("Metadata cannot navigate"); return .requiresForeground })
        let actualSettings = try await service.featureDestinations(.settingsSection)
        let actualTOC = try await service.featureDestinations(.readerContents)
        let actualHistory = try await service.featureDestinations(.readingHistory)
        XCTAssertEqual(actualSettings, settings)
        XCTAssertEqual(actualTOC, toc)
        XCTAssertEqual(actualHistory, [history])
        let general = try await service.destinations()
        XCTAssertEqual(general, settings + toc + [history] + other,
                       "Existing generic catalog and identities remain unchanged")
    }

    func testFeatureFilterPrecedesOriginalExactTitleMatchingWithoutChangingGenericQuery() async throws {
        let settings = destination("native.settings", component: "native.settings.history",
                                   title: "History settings")
        let history = destination("native.history", title: "History")
        let service = NativeIntentService(discover: { [history, settings] }, navigate: { _ in .requiresForeground })
        let feature = try await service.featureDestinations(.settingsSection, matching: "History")
        let general = try await service.destinations(matching: "History")
        XCTAssertEqual(feature, [settings])
        XCTAssertEqual(general, [history])
        let wrongIdentifier = try await service.featureDestinations(.settingsSection, identifiers: [history.id])
        XCTAssertTrue(wrongIdentifier.isEmpty)
    }

    func testHebrewQueryKeepsBackendAndWindowIdentitiesDistinct() async throws {
        let a = destination("native.settings", component: "native.settings.appearance",
                            title: "מראה — חלון 1")
        let b = destination("native.settings", component: "native.settings.appearance",
                            title: "מראה — חלון 2", scene: "scene.B", backend: .sefaria)
        let state = FeatureIntentTestState()
        let service = NativeIntentService(discover: { [a, b] }, navigate: { target in
            state.navigations += 1; state.selected = target
            return .requiresForeground
        })
        let named = try await service.featureDestinations(.settingsSection, matching: "מראה")
        XCTAssertEqual(named, [a, b])
        XCTAssertNotEqual(a.id, b.id)
        let result = try await service.openFeature(.settingsSection, identifier: b.id)
        XCTAssertEqual(result, .requiresForeground)
        XCTAssertEqual(state.selected, b)
        XCTAssertEqual(state.navigations, 1)
    }

    func testWrongFeatureEntityCannotRequestForegroundOrNavigate() async throws {
        let history = destination("native.history", title: "History")
        let state = FeatureIntentTestState()
        let service = NativeIntentService(discover: { [history] },
            awaitForeground: { _ in state.foreground += 1 },
            navigate: { _ in state.navigations += 1; return .requiresForeground })
        do {
            _ = try await service.openFeature(.settingsSection, identifier: history.id)
            XCTFail("An unrelated system entity cannot be used for this action")
        } catch {
            XCTAssertEqual((error as? UIRouteError)?.code, "intent_feature_no_longer_available")
        }
        XCTAssertEqual(state.foreground + state.navigations, 0)
    }

    func testFeatureMetadataStillRequiresFreshOriginalForegroundDiscovery() async throws {
        let settings = destination("native.settings", component: "native.settings.appearance")
        let state = FeatureIntentTestState()
        let service = NativeIntentService(discover: { [] },
            resolveEntities: { [settings] },
            awaitForeground: { selected in
                XCTAssertEqual(selected, settings); state.foreground += 1
            },
            navigate: { _ in state.navigations += 1; return .requiresForeground })
        do {
            _ = try await service.openFeature(.settingsSection, identifier: settings.id)
            XCTFail("Metadata and foreground preparation cannot authorize a missing destination")
        } catch {
            XCTAssertEqual((error as? UIRouteError)?.code, "intent_entity_no_longer_available")
        }
        XCTAssertEqual(state.foreground, 1)
        XCTAssertEqual(state.navigations, 0)
    }

    func testOriginalNoncompletionIsNeverConvertedToSuccessfulIntent() async throws {
        let history = destination("native.history")
        let results: [(UISceneAcknowledgement, ActionStatus)] = [
            (.queued(handle: "actual_pending"), .uiQueued),
            (.requiresForeground, .requiresForeground),
            (.requiresBackendSwitch(.sefaria), .requiresBackendSwitch),
            (.cancelled, .cancelled)
        ]
        for (expected, status) in results {
            let service = NativeIntentService(discover: { [history] }, navigate: { _ in expected })
            let actual = try await service.openFeature(.readingHistory, identifier: history.id)
            XCTAssertEqual(actual, expected)
            do {
                try NativeIntentOutcome.requireVisibleAcknowledgement(actual)
                XCTFail("Only the original visible native acknowledgement completes the Intent")
            } catch {
                XCTAssertEqual((error as? NativeIntentOutcome)?.status, status)
            }
        }
    }

    func testNarrowFeatureCannotHideInvalidCompleteOriginalCatalog() async throws {
        let settings = destination("native.settings", component: "native.settings.backend")
        let history = destination("native.history")
        let service = NativeIntentService(discover: { [settings, history, history] },
                                           navigate: { _ in XCTFail("Invalid catalog"); return .requiresForeground })
        do {
            _ = try await service.featureDestinations(.settingsSection)
            XCTFail("Duplicate identities outside the feature still invalidate the catalog")
        } catch {
            XCTAssertEqual((error as? UIRouteError)?.code, "invalid_live_intent_catalog")
        }
    }

    func testBoundsAndCancellationStopBeforeHostMetadataResolution() async throws {
        let state = FeatureIntentTestState()
        let service = NativeIntentService(discover: { state.metadata += 1; return [] },
                                           navigate: { _ in XCTFail("Metadata only"); return .requiresForeground })
        do {
            _ = try await service.featureDestinations(.settingsSection,
                identifiers: Array(repeating: "cached", count: 65))
            XCTFail("Oversized identifiers")
        } catch {
            XCTAssertEqual((error as? UIRouteError)?.code, "too_many_intent_entities")
        }
        do {
            _ = try await service.featureDestinations(.readerContents, matching: String(repeating: "x", count: 513))
            XCTFail("Oversized query")
        } catch {
            XCTAssertEqual((error as? UIRouteError)?.code, "intent_query_too_large")
        }
        do {
            _ = try await service.openFeature(.readingHistory, identifier: String(repeating: "x", count: 513))
            XCTFail("Oversized identity")
        } catch {
            XCTAssertEqual((error as? UIRouteError)?.code, "invalid_intent_entity")
        }
        let task = Task { @MainActor in try await service.featureDestinations(.settingsSection) }
        task.cancel()
        do { _ = try await task.value; XCTFail("Cancelled query") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(state.metadata, 0)
    }

    func testCancelledForegroundPreparationCannotRunNativeNavigation() async throws {
        let toc = destination("native.reader.toc", component: "native.reader.toc.currentSelection")
        let state = FeatureIntentTestState()
        let service = NativeIntentService(discover: { [toc] },
            awaitForeground: { _ in state.foreground += 1; throw CancellationError() },
            navigate: { _ in state.navigations += 1; return .requiresForeground })
        do { _ = try await service.openFeature(.readerContents, identifier: toc.id); XCTFail("Cancelled route") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(state.foreground, 1)
        XCTAssertEqual(state.navigations, 0)
    }
}

@MainActor
private final class FeatureIntentTestState {
    var metadata = 0
    var foreground = 0
    var navigations = 0
    var selected: NativeIntentService.Destination?
}

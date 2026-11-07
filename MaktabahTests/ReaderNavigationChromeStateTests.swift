import Foundation
#if canImport(DuckDuckGoBookTabs)
@testable import DuckDuckGoBookTabs
#else
@testable import Maktabah_Debug
#endif
import Testing

@MainActor
struct ReaderNavigationChromeStateTests {
    @Test("Reader chrome uses direction hysteresis and restores at the top")
    func directionHysteresis() {
        var state = ReaderNavigationChromeState()
        state.beginDragging()
        state.consume(translationY: -20, isAtTop: false)
        #expect(state.isVisible)
        state.consume(translationY: -34, isAtTop: false)
        #expect(!state.isVisible)
        state.consume(translationY: -26, isAtTop: false)
        #expect(!state.isVisible)
        state.consume(translationY: -6, isAtTop: false)
        #expect(state.isVisible)
        state.consume(translationY: -50, isAtTop: false)
        #expect(!state.isVisible)
        state.consume(translationY: -50, isAtTop: true)
        #expect(state.isVisible)
    }

    @Test("Explicit reveal clears the previous scroll direction")
    func explicitRevealResetsDirection() {
        var state = ReaderNavigationChromeState()
        state.beginDragging()
        state.consume(translationY: -40, isAtTop: false)
        #expect(!state.isVisible)
        state.reveal()
        #expect(state.isVisible)
        state.consume(translationY: -180, isAtTop: false)
        #expect(state.isVisible)
    }

    @Test("Layout-only callbacks and small direction changes cannot flicker chrome")
    func layoutAndJitter() {
        var state = ReaderNavigationChromeState()
        state.beginDragging()
        state.consume(translationY: -40, isAtTop: false)
        for _ in 0..<20 {
            state.consume(translationY: -40, isAtTop: false)
            state.consume(translationY: -39, isAtTop: false)
            state.consume(translationY: -40, isAtTop: false)
        }
        #expect(!state.isVisible)
        state.consume(translationY: .nan, isAtTop: false)
        state.consume(translationY: -.infinity, isAtTop: false)
        #expect(!state.isVisible)
        state.consume(translationY: -20, isAtTop: false)
        #expect(state.isVisible)
    }

    @Test("Each real drag starts a fresh measurement without revealing hidden bars")
    func independentGestures() {
        var state = ReaderNavigationChromeState()
        state.beginDragging()
        state.consume(translationY: -80, isAtTop: false)
        #expect(!state.isVisible)
        state.beginDragging()
        state.consume(translationY: 10, isAtTop: false)
        #expect(!state.isVisible)
        state.consume(translationY: 20, isAtTop: false)
        #expect(state.isVisible)
    }
}

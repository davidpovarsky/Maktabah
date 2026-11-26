import XCTest
import UIKit
@MainActor
private final class R27PhoneRestorationCaptureObservation {
    let app: XCUIApplication
    let expectedLocator: String
    let expectedText: String
    private(set) var lastEvidence = "No native evaluation completed"

    init(app: XCUIApplication, expectedLocator: String, expectedText: String) {
        self.app = app
        self.expectedLocator = expectedLocator
        self.expectedText = expectedText
    }

    private func finitePositive(_ frame: CGRect) -> Bool {
        !frame.isEmpty && !frame.isNull && !frame.isInfinite
            && [frame.minX, frame.minY, frame.width, frame.height].allSatisfy(\.isFinite)
    }

    func settled() -> Bool {
        let window = app.windows.firstMatch
        let readers = app.textViews.matching(identifier: "reader-text")
        guard window.exists, readers.count == 1 else {
            lastEvidence = "Original window or unique TextKit reader is absent"
            return false
        }
        let reader = readers.firstMatch
        do {
            let windowSnapshot = try window.snapshot()
            let readerSnapshot = try reader.snapshot()
            let bounds = windowSnapshot.frame
            let textFrame = readerSnapshot.frame
            guard finitePositive(bounds), bounds.height > bounds.width,
                  XCUIDevice.shared.orientation.isPortrait,
                  finitePositive(textFrame), bounds.contains(textFrame),
                  reader.value as? String == expectedText,
                  app.staticTexts["reader-current-locator"].label == expectedLocator else {
                lastEvidence = "Actual phone Reader source/locator/window not settled: window=\(bounds), reader=\(textFrame)"
                return false
            }
            let query = app.toolbars.buttons.matching(NSPredicate(format: "identifier IN %@",
                ["reader-more-menu", "BottomOverflowBarButtonItem", "ToolbarOverflowBarButtonItem"]))
            let actions = query.allElementsBoundByIndex.filter {
                finitePositive($0.frame) && bounds.contains($0.frame) && $0.isHittable
            }
            guard actions.count == 1, let action = actions.first else {
                lastEvidence = "Require one actual original actionable compact bottom control; observed=\(actions.count)"
                return false
            }
            let actionFrame = action.frame
            let navigationBottom = app.navigationBars.allElementsBoundByIndex.map(\.frame)
                .filter { finitePositive($0) && $0.intersects(bounds) }.map(\.maxY).max()
            guard let navigationBottom, actionFrame.minY > navigationBottom else {
                lastEvidence = "Original native bars do not leave a visible Reader body"
                return false
            }
            let body = CGRect(x: textFrame.minX, y: max(textFrame.minY, navigationBottom),
                              width: textFrame.width, height: min(textFrame.maxY, actionFrame.minY) - max(textFrame.minY, navigationBottom))
            var descendants: [any XCUIElementSnapshot] = []
            var pending = readerSnapshot.children
            while let element = pending.popLast() {
                descendants.append(element)
                pending.append(contentsOf: element.children)
            }
            let visibleSource = descendants.filter {
                $0.elementType == .textView && $0.identifier != "reader-text"
                    && $0.label.utf16.count >= 31 && finitePositive($0.frame) && body.intersects($0.frame)
            }
            let current = window.frame == bounds && reader.frame == textFrame && action.frame == actionFrame
            lastEvidence = "window=\(bounds)\nreader=\(textFrame)\nbody=\(body)\noriginalAction=\(action.identifier)\nactionFrame=\(actionFrame)\nvisibleOriginalSourceChildren=\(visibleSource.count)\ncurrentGeometry=\(current)\nlocator=\(expectedLocator)"
            return finitePositive(body) && !visibleSource.isEmpty && current
        } catch {
            lastEvidence = "Native snapshot unavailable: \(error)"
            return false
        }
    }
}

@MainActor final class R27CompileOnlyHost: XCTestCase {
 let app=XCUIApplication()
    @MainActor
    private func captureRestoredPhoneReader(_ name: String, locator: String, text: String) {
        let observation = R27PhoneRestorationCaptureObservation(app: app, expectedLocator: locator, expectedText: text)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { observation.settled() }
        }, object: nil)
        let result = XCTWaiter.wait(for: [ready], timeout: 20)
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = result == .completed ? name : "UNSETTLED-" + name
        image.lifetime = .keepAlways; add(image)
        let evidence = XCTAttachment(string: observation.lastEvidence + "\n" + app.debugDescription)
        evidence.name = name + "-original-phone-geometry-and-source"
        evidence.lifetime = .keepAlways; add(evidence)
        XCTAssertEqual(result, .completed,
                       "Require actual restored source and original compact toolbar inside the current native phone window")
    }

}

import Foundation

/// Uses the user's pan distance rather than contentOffset changes caused by
/// safe-area/layout updates, restoration or programmatic navigation.
struct ReaderNavigationChromeState {
    private(set) var isVisible = true
    private var lastTranslationY: CGFloat?
    private var accumulatedDelta: CGFloat = 0
    private var direction: FloatingPointSign?

    mutating func beginDragging() {
        lastTranslationY = 0
        accumulatedDelta = 0
        direction = nil
    }

    mutating func consume(translationY: CGFloat, isAtTop: Bool) {
        guard translationY.isFinite else { return }
        if isAtTop {
            reveal()
            lastTranslationY = translationY
            return
        }
        guard let previous = lastTranslationY else {
            lastTranslationY = translationY
            return
        }
        let delta = previous - translationY
        lastTranslationY = translationY
        guard abs(delta) >= 0.5 else { return }
        if direction != delta.sign {
            direction = delta.sign
            accumulatedDelta = 0
        }
        accumulatedDelta += delta
        if accumulatedDelta >= 32, isVisible {
            isVisible = false
            accumulatedDelta = 0
        } else if accumulatedDelta <= -18, !isVisible {
            isVisible = true
            accumulatedDelta = 0
        }
    }

    mutating func reveal() {
        isVisible = true
        lastTranslationY = nil
        accumulatedDelta = 0
        direction = nil
    }
}

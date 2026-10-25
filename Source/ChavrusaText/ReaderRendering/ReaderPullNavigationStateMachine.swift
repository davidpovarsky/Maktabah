#if canImport(CoreGraphics)
import CoreGraphics
#else
public typealias CGFloat = Double
#endif
import Foundation

/// Pure Swift deterministic state machine for pull-to-navigate gesture in ChavrusaText reader.
/// Fixes BUG-02 by preventing intermediate non-tracking scroll events from clearing armed state
/// before `scrollViewDidEndDragging` can commit the navigation.
public final class ReaderPullNavigationStateMachine {
    public enum Direction: Equatable, Sendable {
        case prev
        case next
    }

    public enum State: Equatable, Sendable {
        case idle
        case dragging(direction: Direction, overscroll: CGFloat, progress: CGFloat)
        case armed(direction: Direction, overscroll: CGFloat)
        case committed(direction: Direction)
        case cancelled
    }

    public private(set) var state: State = .idle
    public let pullThreshold: CGFloat
    private(set) var hasTriggeredHaptic: Bool = false

    public init(pullThreshold: CGFloat = 80.0) {
        self.pullThreshold = pullThreshold
    }

    public struct ScrollTransitionResult: Equatable {
        public let state: State
        public let shouldTriggerHaptic: Bool
        public let progress: CGFloat
        public let direction: Direction?
    }

    /// Process a scroll event from UIScrollViewDelegate.scrollViewDidScroll
    public func handleScroll(
        topOverscroll: CGFloat,
        bottomOverscroll: CGFloat,
        isTracking: Bool,
        isRestoringScroll: Bool
    ) -> ScrollTransitionResult {
        guard !isRestoringScroll else {
            return ScrollTransitionResult(state: state, shouldTriggerHaptic: false, progress: 0, direction: nil)
        }

        let direction: Direction?
        let overscroll: CGFloat

        if topOverscroll > 0 {
            direction = .prev
            overscroll = topOverscroll
        } else if bottomOverscroll > 0 {
            direction = .next
            overscroll = bottomOverscroll
        } else {
            direction = nil
            overscroll = 0
        }

        var shouldTriggerHaptic = false

        if let direction, overscroll > 0 {
            if isTracking {
                let progress = min(overscroll / pullThreshold, 1.0)
                if overscroll >= pullThreshold {
                    if !hasTriggeredHaptic {
                        hasTriggeredHaptic = true
                        shouldTriggerHaptic = true
                    }
                    state = .armed(direction: direction, overscroll: overscroll)
                } else {
                    hasTriggeredHaptic = false
                    state = .dragging(direction: direction, overscroll: overscroll, progress: progress)
                }
                return ScrollTransitionResult(
                    state: state,
                    shouldTriggerHaptic: shouldTriggerHaptic,
                    progress: progress,
                    direction: direction
                )
            } else {
                // BUG-02 Fix: When isTracking is false, user has lifted finger and scroll view is bouncing.
                // Do NOT discard .armed state here! Preserve it so endDragging can commit navigation.
                if case .armed(let armedDir, _) = state, armedDir == direction {
                    return ScrollTransitionResult(
                        state: state,
                        shouldTriggerHaptic: false,
                        progress: 1.0,
                        direction: armedDir
                    )
                }
            }
        } else {
            // User retreated back within normal bounds while tracking
            if isTracking {
                hasTriggeredHaptic = false
                state = .idle
            }
        }

        let currentProgress: CGFloat
        switch state {
        case .dragging(_, _, let p): currentProgress = p
        case .armed: currentProgress = 1.0
        default: currentProgress = 0.0
        }

        return ScrollTransitionResult(
            state: state,
            shouldTriggerHaptic: false,
            progress: currentProgress,
            direction: direction
        )
    }

    /// Process end dragging event from UIScrollViewDelegate.scrollViewDidEndDragging
    /// Returns the Direction to navigate if the gesture was armed, or nil if cancelled.
    public func handleEndDragging(willDecelerate: Bool) -> Direction? {
        defer {
            hasTriggeredHaptic = false
            state = .idle
        }

        if case .armed(let direction, _) = state {
            state = .committed(direction: direction)
            return direction
        }

        state = .cancelled
        return nil
    }

    /// Explicitly resets the state machine (e.g. on content switch or deceleration complete).
    public func reset() {
        state = .idle
        hasTriggeredHaptic = false
    }
}

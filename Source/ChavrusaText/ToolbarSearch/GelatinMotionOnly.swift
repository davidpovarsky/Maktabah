//
//  GelatinMotionOnly.swift
//  Maktabah
//
//  Downstream-owned tactile spring/stretch motion modifier for interactive toolbar capsules and pills.
//
//  Attribution:
//  Adapted from Polarizz/Gelatin @ 2a3ad4cd9302685483a749059fa3e91f5ed7a4fc
//  https://github.com/Polarizz/Gelatin
//  License: MIT License (Copyright (c) 2025 Polarizz)
//
//  Design Policy (DESIGN_LANGUAGE.md):
//  Strictly motion-only (interactive spring, subtle pressed scale, directional stretch).
//  All brightness/saturation/color mutations and demo UI controls from upstream Gelatin are intentionally omitted.
//

#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation
#if canImport(SwiftUI)
import SwiftUI

/// Purely geometric spring/stretch parameters for `GelatinMotionOnly`.
struct GelatinMotionMetrics: Equatable, Sendable {
    let scaleX: CGFloat
    let scaleY: CGFloat
    let offset: CGSize

    init(scaleX: CGFloat = 1.0, scaleY: CGFloat = 1.0, offset: CGSize = .zero) {
        self.scaleX = scaleX
        self.scaleY = scaleY
        self.offset = offset
    }

    static let identity = GelatinMotionMetrics()

    /// Computes a subtle volume-preserving squash-and-stretch transform for a given interaction state.
    static func compute(
        isPressed: Bool,
        dragTranslation: CGSize = .zero,
        reduceMotion: Bool = false,
        pressedScale: CGFloat = 0.96,
        maxStretch: CGFloat = 0.06
    ) -> GelatinMotionMetrics {
        guard !reduceMotion else {
            return .identity
        }

        let baseScale: CGFloat = isPressed ? pressedScale : 1.0
        let distance = hypot(dragTranslation.width, dragTranslation.height)
        guard distance > 0.5 else {
            return GelatinMotionMetrics(scaleX: baseScale, scaleY: baseScale, offset: .zero)
        }

        let normalizedStretch = min(distance / 180.0, 1.0) * maxStretch
        let horizontalDominance = abs(dragTranslation.width) >= abs(dragTranslation.height)

        let scaleX = baseScale * (horizontalDominance ? (1.0 + normalizedStretch) : (1.0 - normalizedStretch * 0.5))
        let scaleY = baseScale * (horizontalDominance ? (1.0 - normalizedStretch * 0.5) : (1.0 + normalizedStretch))
        let dampedOffset = CGSize(
            width: dragTranslation.width * 0.08,
            height: dragTranslation.height * 0.08
        )

        return GelatinMotionMetrics(scaleX: scaleX, scaleY: scaleY, offset: dampedOffset)
    }
}

/// Applies subtle tactile spring & stretch motion to toolbar capsules and pills without altering colors, brightness, or saturation.
struct GelatinMotionOnlyModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var isPressed: Bool
    var dragTranslation: CGSize
    var pressedScale: CGFloat

    init(
        isPressed: Bool = false,
        dragTranslation: CGSize = .zero,
        pressedScale: CGFloat = 0.96
    ) {
        self.isPressed = isPressed
        self.dragTranslation = dragTranslation
        self.pressedScale = pressedScale
    }

    func body(content: Content) -> some View {
        let metrics = GelatinMotionMetrics.compute(
            isPressed: isPressed,
            dragTranslation: dragTranslation,
            reduceMotion: reduceMotion,
            pressedScale: pressedScale
        )

        content
            .scaleEffect(x: metrics.scaleX, y: metrics.scaleY)
            .offset(metrics.offset)
            .animation(
                reduceMotion
                    ? .linear(duration: 0.01)
                    : .interpolatingSpring(stiffness: 340, damping: 22),
                value: metrics
            )
    }
}

extension View {
    /// Applies ChavrusaText's motion-only Gelatin spring modifier (zero brightness/saturation mutation).
    func gelatinMotionOnly(
        isPressed: Bool = false,
        dragTranslation: CGSize = .zero,
        pressedScale: CGFloat = 0.96
    ) -> some View {
        modifier(
            GelatinMotionOnlyModifier(
                isPressed: isPressed,
                dragTranslation: dragTranslation,
                pressedScale: pressedScale
            )
        )
    }
}
#endif

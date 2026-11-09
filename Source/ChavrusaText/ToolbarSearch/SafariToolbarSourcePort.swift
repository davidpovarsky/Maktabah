// Owner-provided SafariToolbarSearch.swiftpm, 2026-10-29. Gelatin motion adaptation: MIT (bundled).
import SwiftUI

// A single Liquid Glass backing per toolbar group (iPadOS 26+), with a material fallback.
struct SafariGlass: ViewModifier {
    let radius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: shape)
        } else {
            content
                .background(.regularMaterial, in: shape)
                .overlay(shape.strokeBorder(Color.primary.opacity(0.09), lineWidth: 0.7))
        }
    }
}

struct GlassButtonGroup<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 0) {
            content
        }
        .padding(.horizontal, 5)
        .frame(height: 52)
        .modifier(SafariGlass(radius: 26))
    }
}

// Local adaptation of the movement/press behavior from Polarizz/Gelatin (MIT).
// Color adjustments are deliberately ABSENT: no brightness or saturation changes.
private struct GelatinMotionOnly: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var currentOffset: CGSize = .zero
    @State private var currentStretch: CGSize = CGSize(width: 1, height: 1)
    @State private var isPressed = false

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
            .offset(currentOffset)
            .scaleEffect(x: currentStretch.width, y: currentStretch.height)
            .scaleEffect(isPressed ? CGFloat(1.01) : CGFloat(1))
            .simultaneousGesture(dragGesture)
            .simultaneousGesture(pressGesture)
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                let x = ease(value.translation.width)
                let y = ease(value.translation.height)
                let limit: CGFloat = 130
                let strength: CGFloat = 0.12
                let xRatio: CGFloat = min(abs(x) / limit, CGFloat(1))
                let scaleX: CGFloat = CGFloat(1) + strength * xRatio
                let yRatio: CGFloat = min(abs(y) / limit, CGFloat(1))
                let scaleY: CGFloat = CGFloat(1) + strength * yRatio

                withAnimation(.smooth(duration: 0.22)) {
                    currentOffset = CGSize(width: x, height: y)
                    currentStretch = CGSize(width: scaleX, height: scaleY)
                }
            }
            .onEnded { _ in
                withAnimation(.smooth(duration: 0.55, extraBounce: 0.45)) {
                    currentOffset = .zero
                    currentStretch = CGSize(width: 1, height: 1)
                }
            }
    }

    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { _ in
                withAnimation(.smooth(duration: 0.20)) { isPressed = true }
            }
            .onEnded { _ in
                withAnimation(.smooth(duration: 0.3, extraBounce: 0.3)) { isPressed = false }
            }
    }

    private func ease(_ input: CGFloat) -> CGFloat {
        guard input != 0 else { return 0 }
        let magnitude = pow(Double(abs(input)), 0.5)
        let direction: CGFloat = input < 0 ? CGFloat(-1) : CGFloat(1)
        return CGFloat(magnitude) * direction
    }
}

extension View {
    func gelatinMotionOnly() -> some View {
        modifier(GelatinMotionOnly())
    }
}


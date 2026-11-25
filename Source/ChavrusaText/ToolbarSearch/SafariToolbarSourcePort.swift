// Owner-provided SafariToolbarSearch.swiftpm, 2026-10-29. Gelatin motion adaptation: MIT (bundled).
import SwiftUI

// A single Liquid Glass backing per toolbar group (iPadOS 26+), with a material fallback.
struct SafariGlass: ViewModifier {
    let radius: CGFloat
    var isInteractive = false

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(isInteractive), in: shape)
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
        .modifier(SafariGlass(radius: 26, isInteractive: true))
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


/// Observe the real native Button press without adding a drag recognizer to a
/// toolbar control. The single external surface follows this small motion.
struct LibrarySearchPressStyle: ButtonStyle {
    let onPressed: (Bool) -> Void

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, pressed in onPressed(pressed) }
            .onDisappear { onPressed(false) }
    }
}

/// Gelatin's movement/stretch is confined to a dedicated 16pt handle. Neither
/// the original text field nor the scrolling result list inherits its gesture.
struct LibrarySearchMotionHandle: View {
    @Binding var offset: CGSize
    @Binding var stretch: CGSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Capsule()
            .fill(.secondary.opacity(0.45))
            .frame(width: 36, height: 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(drag, including: reduceMotion ? .none : .all)
            .accessibilityHidden(true)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                let x = ease(value.translation.width)
                let y = ease(value.translation.height)
                withAnimation(.smooth(duration: 0.22)) {
                    offset = CGSize(width: x, height: y)
                    stretch = CGSize(width: 1 + 0.12 * min(abs(x) / 130, 1),
                                     height: 1 + 0.12 * min(abs(y) / 130, 1))
                }
            }
            .onEnded { _ in
                withAnimation(.smooth(duration: 0.55, extraBounce: 0.45)) {
                    offset = .zero
                    stretch = CGSize(width: 1, height: 1)
                }
            }
    }

    private func ease(_ input: CGFloat) -> CGFloat {
        guard input != 0 else { return 0 }
        return CGFloat(pow(Double(abs(input)), 0.5)) * (input < 0 ? -1 : 1)
    }
}

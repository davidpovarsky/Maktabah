import SwiftUI
import UIKit

/// Nonvisual bridge between the native navigation toolbar and the source
/// search overlay. It measures window coordinates without changing any bar,
/// safe-area preference, reader delegate, content offset or reader subtree.
struct ReaderToolbarOriginReader: UIViewRepresentable {
    let tracksPosition: Bool
    let onMeasure: (CGFloat) -> Void

    func makeUIView(context: Context) -> ReaderToolbarOriginView {
        let view = ReaderToolbarOriginView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: ReaderToolbarOriginView, context: Context) {
        view.onMeasure = onMeasure
        view.setTracking(tracksPosition)
    }

    static func dismantleUIView(_ view: ReaderToolbarOriginView, coordinator: ()) {
        view.onMeasure = nil
        view.setTracking(false)
    }
}


/// Full native toolbar geometry in its actual window. The toolbar and the
/// split-level overlay have separate SwiftUI graphs; preferences cannot bridge
/// them. Owner/window identity prevents a stale scene from supplying an anchor.
struct ReaderToolbarFrameReader: UIViewRepresentable {
    let tracksPosition: Bool
    let onMeasure: (UIView, CGRect, UIWindow?) -> Void

    func makeUIView(context: Context) -> ReaderToolbarOriginView {
        let view = ReaderToolbarOriginView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: ReaderToolbarOriginView, context: Context) {
        view.onMeasureFrame = onMeasure
        view.setTracking(tracksPosition)
    }

    static func dismantleUIView(_ view: ReaderToolbarOriginView, coordinator: ()) {
        view.onMeasureFrame?(view, .null, nil)
        view.onMeasureFrame = nil
        view.setTracking(false)
    }
}

final class ReaderToolbarOriginView: UIView {
    @MainActor private final class DisplayLinkTarget {
        weak var view: ReaderToolbarOriginView?
        init(_ view: ReaderToolbarOriginView) { self.view = view }
        @objc func tick(_ link: CADisplayLink) { view?.reportPosition() }
    }

    var onMeasure: ((CGFloat) -> Void)?
    var onMeasureFrame: ((UIView, CGRect, UIWindow?) -> Void)?
    private var lastY: CGFloat?
    private var lastFrame: CGRect?
    private weak var lastWindow: UIWindow?
    private var wantsTracking = false
    private var displayLink: CADisplayLink?

    func setTracking(_ active: Bool) {
        wantsTracking = active
        updateDisplayLink()
        scheduleReport()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            onMeasureFrame?(self, .null, nil)
            lastFrame = nil
            lastWindow = nil
        }
        updateDisplayLink()
        scheduleReport()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scheduleReport()
    }

    private func updateDisplayLink() {
        if wantsTracking, window != nil {
            if displayLink == nil {
                let link = CADisplayLink(target: DisplayLinkTarget(self), selector: #selector(DisplayLinkTarget.tick(_:)))
                link.add(to: .main, forMode: .common)
                displayLink = link
            }
        } else {
            displayLink?.invalidate()
            displayLink = nil
        }
    }

    private func scheduleReport() {
        Task { @MainActor [weak self] in self?.reportPosition() }
    }

    private func reportPosition() {
        guard let window else { return }
        let frame = convert(bounds, to: window)
        guard frame.origin.x.isFinite, frame.origin.y.isFinite,
              frame.width.isFinite, frame.height.isFinite else { return }
        if lastFrame != frame || lastWindow !== window {
            lastFrame = frame
            lastWindow = window
            onMeasureFrame?(self, frame, window)
        }
        if lastY != frame.minY {
            lastY = frame.minY
            onMeasure?(frame.minY)
        }
    }
}

extension ToolbarContent {
    /// The supplied GlassButtonGroup/SafariGlass already owns its background.
    /// Keep native ToolbarItem placement without adding a second glass capsule.
    @MainActor @ToolbarContentBuilder
    func readerSourceGlassBackground() -> some ToolbarContent {
        if #available(iOS 26.0, *) { sharedBackgroundVisibility(.hidden) }
        else { self }
    }
}

struct ReaderToolbarActionAdapter: View {
    @Environment(\.layoutDirection) private var layoutDirection
    let sidebarIsOpen: Bool
    let onToggleSidebar: () -> Void
    var body: some View {
        GlassButtonGroup {
            Button(action: onToggleSidebar) {
                Image(systemName: layoutDirection == .rightToLeft ? "sidebar.right" : "sidebar.left")
                    .font(.system(size: 19, weight: .regular))
                    .frame(width: 39, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(sidebarIsOpen ? "הסתר סרגל צד" : "הצג סרגל צד")
            .accessibilityIdentifier("reader-host-sidebar-toggle")
        }
    }
}

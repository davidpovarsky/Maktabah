import FloatingPanel
import SwiftUI

/// The original workspace's HStack, resize handle and FloatingPanel composition.
/// Keep Reader in one structural position as the native window/sidebar changes;
/// the original TextKit instance can then preserve its source anchor on reflow.
struct ChavrusaReaderWorkspaceLayout<Reader: View, Panel: View, ResizeHandle: View>: View {
    let reader: Reader
    let panel: Panel
    let resizeHandle: ResizeHandle
    let panelWidth: CGFloat
    let showPanel: Bool
    let floats: Bool
    @Binding var floatingState: FloatingPanelState?
    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        HStack(spacing: 0) {
            reader
                .environment(\.layoutDirection, layoutDirection)
                .geometryGroup()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if showPanel && !floats {
                resizeHandle.transition(.opacity)
                panel
                    .environment(\.layoutDirection, layoutDirection)
                    .frame(width: panelWidth)
                    .transition(.opacity)
                    .clipped()
                    .allowsHitTesting(showPanel)
            }
        }
        .animation(.snappy(duration: 0.42, extraBounce: 0), value: showPanel)
        .floatingPanel { _ in
            if showPanel && floats { panel }
        }
        .floatingPanelState($floatingState)
        .floatingPanelLayout(StudyContentFloatingPanelLayout())
        .floatingPanelSurfaceAppearance(.transparent(cornerRadius: 26))
    }
}

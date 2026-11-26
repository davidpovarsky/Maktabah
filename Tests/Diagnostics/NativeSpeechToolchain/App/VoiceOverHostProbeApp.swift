import SwiftUI

@main
struct VoiceOverHostProbeApp: App {
    var body: some Scene {
        WindowGroup {
            VStack {
                Text("Native speech probe").accessibilityIdentifier("voiceover-probe-title")
                Button("Probe button") {}
            }
        }
    }
}

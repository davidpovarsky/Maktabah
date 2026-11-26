import XCTest

final class VoiceOverHostProbeUITests: XCTestCase {
    @MainActor
    func testAppleVoiceOverEnablesAndProducesSpeech() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["voiceover-probe-title"].waitForExistence(timeout: 20))
        let voiceOver = XCUIDevice.shared.voiceOverService
        let initiallyEnabled = voiceOver.isEnabled
        defer {
            if !initiallyEnabled && voiceOver.isEnabled {
                XCTAssertNoThrow(try voiceOver.disable())
            }
        }
        try XCTContext.runActivity(named: "Enable Apple VoiceOver") { _ in
            try voiceOver.enable()
        }
        XCTAssertTrue(voiceOver.isEnabled)
        try XCTContext.runActivity(named: "Speak from the real focused element") { activity in
            let first = try voiceOver.moveForward().utterance
            let next = try voiceOver.moveBackward().utterance
            let attachment = XCTAttachment(string: first + "\n" + next)
            attachment.name = "Actual system utterances"
            attachment.lifetime = .keepAlways
            activity.add(attachment)
            XCTAssertTrue([first,next].contains { $0.contains("Native speech probe") || $0.contains("Probe button") })
        }
    }
}

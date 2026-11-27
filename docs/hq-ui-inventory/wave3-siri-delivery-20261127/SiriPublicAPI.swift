import XCTest

@MainActor
func invokeOriginalRegisteredSiri(_ phrase: String) -> XCTAttachment {
    XCUIDevice.shared.siriService.activate(voiceRecognitionText: phrase)
    return XCTAttachment(string: XCUIDevice.shared.siriService.debugDescription)
}

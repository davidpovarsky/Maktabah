# Original App Intents through Apple system infrastructure

Three actual UI test methods use iOS27 AppIntentsTesting to look up the app bundle's registered NativeDestinationEntity and invoke the original OpenNativeDestinationIntent from the separate test process. They additionally inspect the real app UI and the original canonical native navigation receipt. The negative case never counts as proof that a positive invocation works.

No app-code import, direct perform call, synthetic receipt, test-only app intent, authority change, shortcut publication, database reset or new AI agent is used. Normal existing fixture bootstrap and the owned test namespace remain in force. Existing App Intents and WidgetKit declarations are preserved.

Apple's documented same-development-team requirement for the app and UI runner must be satisfied by the actual environment. A signing/runtime refusal is a failed or blocked system gate, never a skipped success. Siri voice, the Shortcuts editor, Spotlight and physical device journeys remain separate acceptance.

## Primary API references

- https://developer.apple.com/documentation/appintentstesting/testing-your-app-intents-code
- https://developer.apple.com/documentation/appintentstesting/intentdefinitions
- https://developer.apple.com/documentation/appintents/verifying-your-app-intents-implementation
- https://developer.apple.com/videos/play/wwdc2026/295/

These methods are source additions only until real Xcode/iOS27 execution is accepted.

# Integration contract

## Shared entry owned by root

`NativeWorkspaceSelectionIntentService` uses `discover: () async throws -> [Selection]` and `navigate: (Selection, UUID) async throws -> UISceneAcknowledgement`. Its Selection has kind `.profile` / `.group`, actual scene and backend, profile/group UUIDs, expected active document UUID or nil, and original display titles.

The private registry descriptor is `NativeWorkspaceSelectionIntentService.destination` (`native.workspace.selection`). Do not add an arbitrary selected UUID to PublicNavigationV2 or route the selection through a generic root. Keep the existing five-second absolute deadline across activation, original stage, Core apply and actual native completion.

Session API:

```swift
workspaceSelectionCatalog(windowTitle:)
retainWorkspaceSelection(_:requestID:)
reserveWorkspaceSelection(_:)
prepareWorkspaceSelection(_:validateLifetime:) async
prepareWorkspaceSelectionRoute(_:invocation:scene:)
validateWorkspaceSelectionCompletion(_:receipt:)
releaseWorkspaceSelection(_:)
```

Retain before the first await. Reserve once before Core. `prepareWorkspaceSelection` is original async preparation only. `prepareWorkspaceSelectionRoute` builds the finite trusted route. The original orchestrator is the only entry that calls the synchronous effect. Recheck the exact binding after the returned actual receipt and keep any observed receipt in an uncertain failure. Never renew the deadline or grant.

## App membership

Register these new app files in the same original target ownership as their neighboring implementation:

- `Source/ChavrusaText/StudyWorkspace/StudyWorkspacePreparedGroupSelection.swift`
- `Source/ChavrusaText/StudyWorkspace/StudyWorkspaceGroupSelectionReservation.swift`
- `Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeWorkspaceSelectionBinding.swift` (iOS only)

The new `NativeWorkspaceSelectionIntentService.swift` and `NativeWorkspaceSelectionIntents.swift` are in the existing `ChavrusaUIRoutingHost` Swift package Sources directory. They do not need duplicate app membership. Root owns project edits.

## Localization and shortcut metadata

Root owns both catalogs. Preserve all prior entries and the four existing AppShortcut definitions. The two proposed additional shortcuts are ordinary thin wrappers for the service above; final shortcut build validation remains required.

| English literal | Hebrew |
| --- | --- |
| Study profile | פרופיל לימוד |
| Tab group | קבוצת טאבים |
| Open a study profile | פתיחת פרופיל לימוד |
| Open study profile | פתיחת פרופיל לימוד |
| Open a tab group | פתיחת קבוצת טאבים |
| Open tab group | פתיחת קבוצת טאבים |
| Select the first tab group of an original study profile in the current library of the selected Maktabah window. | בחירת קבוצת הטאבים הראשונה בפרופיל לימוד קיים, בספרייה הנוכחית של חלון Maktabah שנבחר. |
| Select an original tab group in the current study profile and library of the selected Maktabah window. | בחירת קבוצת טאבים קיימת בפרופיל הלימוד ובספרייה הנוכחיים בחלון Maktabah שנבחר. |

AppShortcut proposals:

```swift
AppShortcut(intent: OpenStudyProfileIntent(),
    phrases: ["Open study profile \(\.$selection) in \(.applicationName)"],
    shortTitle: "Open study profile", systemImageName: "person.crop.circle")
AppShortcut(intent: OpenStudyTabGroupIntent(),
    phrases: ["Open tab group \(\.$selection) in \(.applicationName)"],
    shortTitle: "Open tab group", systemImageName: "rectangle.3.group")
```

The code above illustrates the two existing intent parameter paths; root must use the actual AppShortcut interpolation syntax and validate the catalog. No shortcut implementation is included in this source packet.

## Explicit runtime boundary

Current Viewer only, current committed library only. Background activation of the same exact existing window is supported by root's retained registration wait. A hidden phone Reader for a same-active no-op selection is unavailable; selecting an already active tab does not invent a push. Legacy cold unqualified sessions and foreign-root continuation remain open. Actual UIKit empty-state geometry, cold loading, native modal behavior, multiwindow, App Intents delivery and physical QA are not established by these source controls.

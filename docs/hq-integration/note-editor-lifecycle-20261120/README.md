# Original note editor callback lifecycle — baseline evidence

The source-level review found that a Reader workspace owns one stable note-editor ID across multiple original sheet presentations. The original sheet sends a deferred `onCreated` callback and an anonymous nil `onDisappear` callback. Before the fix, both reach the same owner without a presentation identity check.

## Preserved baseline

- Original source: `0bc6be41f03855412d7dd24ee72608a7824fb5a7`.
- Regression fixture/driver commit: `03783f15` (full commit is preserved in Git).
- SentinelX job: `job_a247d91e0b8a`; Windows Swift 6.3.3; compilation exit 0, no warnings.
- Actual execution: **7 PASS / 6 FAIL / 13 cases**. The six failures cover old disappearance, old creation replacing the current editor, late creation after dismissal, disappearance before delayed creation, stale scene invalidation, and reopening an identical unsaved Annotation value.
- Exact extracted owner and scene callback are compiled. UIKit, SwiftUI Binding, Reader, Annotation and the scene revision counter are explicit boundary doubles. The historical signature adapter passes no presentation identity into old source; it adds no production guard.
- `red/RESULT.json` records full source hashes, fixture/driver hashes, generated source hash, compiler command, result and boundary. Raw compiler/test output and the generated exact-source Swift unit are retained.

This is portable source-level regression evidence. No native sheet, UIKit scheduling, persistence, Core action, Apple build, Simulator or physical-device PASS is claimed.

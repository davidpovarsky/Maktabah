# Original overview: establish one-book fixture through the original UI

The original Release run 44665679661 exposed two different real restored books in the overview, while the existing replacement/viewport oracle intentionally requires one book. A fresh test workspace sidecar does not make the ordinary reader's saved session empty: original StudyWorkspace attachment imports those restored tabs. Production restoration and migration remain unchanged.

The existing three overview tests now establish their one-book prerequisite before either measured 48pt/nonzero or 19pt presentation. The helper observes the original native selected UUID and the exact private test sidecar, verifies all current group members and the retained Otzaria book identity, closes only observed noncurrent members with the original RTL swipe, and requires each exact UUID removal to persist while retaining the active original document. It retains the before/after workspace and native evidence. It never writes a sidecar, session, or viewport and is bounded to the isolated non-production fixture.

All original measured overview code is byte-identical: count, full-display frame, covered-reader visibility, original source/object identity, pixel/source anchor, raw native offset, title, locator, and restored reader-frame assertions remain. An exact inverse of the added helper, two setup calls, and four actor annotations reproduces every original source byte.

A source review identified that the new MainActor helper also requires isolation on its existing caller and three XCTest methods. That correction is included; IDs and method bodies are preserved. Windows Swift 6.3.3 frontend parsing actually completed with exit 0 and two SDK warnings. Raw logs are retained.

This is source preparation and syntax evidence only. Apple typechecking and the actual three Native tests are NOT_RUN for this change. Acceptance remains open until source-bound Apple execution.

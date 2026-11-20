# Connect the original Inspector presentation options

The actual Release video and four finalized failures show both redundant titles: Study Tools and Selected Segment. The existing test deliberately requires these titles to be absent for the enabled reader. These were visible text, not an accessibility-only duplication.

The already pinned original TorahInspectorKit19d1b353 API has two optional host flags defaulting to true. The app host omitted presentationOptions. This change passes showsStudyToolsTitle:false and showsSelectedSegmentTitle:false only when ChavrusaTextReaderUI is enabled. Feature-off uses the exact original defaults. The existing SDK still renders the selected text/reference, all tools, close action, links, and note actions. usesMinimalChrome remains its original false default.

No SDK code, version, package pin, native assertion, navigation/receipt authority or expected geometry changes. The three original SDK files are retained losslessly for review; their Git blob IDs match the immutable upstream tree. SOURCE_REVIEW records those bindings and an exact inverse of the single call-site change.

Syntax parsing ran successfully on Windows for the iOS target. This is not an Apple SDK typecheck or Native success. The original four absent-title checks and complete Reader/Inspector acceptance remain required on Apple.

Observed evidence is in docs/hq-integration/release96-44665679661-20261120 at f2a4eef9004710be8040e183d8713dc28f73c2c7, including heading-final-original-frame and its original video/frame receipt.

# Native ProfileColor: tap the original current-value label

Native run 44723902453 (checkout 60a57972acb28739ec738565083bf17fb7503028; app/tests 87b783ac3f0257e8461762e0ea9dfa5248dd06e8) failed StudyProfileNativeAcceptanceTests/testProfileColorSaveCancelAndColdRelaunchPreserveWorkspace while waiting for the red menu option. The original Picker was visible but the menu did not appear.

The captured Picker row is 508 by 34.5 points. The actual synthesized event records originalOffset 254/17.25, the midpoint of that whole row. Its visible current-value label is in the separate left-side rectangle (367,333,88.5,20.5); the whole row is (351,326,508,34.5). The event's portrait-coordinate representation and the landscape AX geometry are retained as observed evidence, not a claim about a new hit-test result.

## Change

Only chooseProfileColor changes. It finds the exact current-value StaticText inside the same identified native Picker, requires exactly one match, live hittability and finite positive frames fully contained in both that Picker and the actual app window, then uses the original tap helper once on that label.

The original option lookup and its 30-second wait, post-selection value assertion, Save/Cancel flow, cold-relaunch checks, profile/workspace isolation, shared tap helper, production Picker and every other test remain unchanged. Invalid ownership or geometry fails before any new tap. No first-match fallback is introduced for the current-value label.

## Source and validation

The baseline is published commit 689d8db5a1186272779b278a5a86752ed9acef6a, exact Faithful Git blob 34a077a9bf2c59daf6ad5668b7414ab357f06a08. SOURCE_COMPARISON.json and the patch bind the complete baseline/candidate bytes and exact inverse.

Peer source review by Root and the Native agent found no concrete type or ownership blocker. That review does not prove StaticText hit reachability or menu opening.

**Windows syntax parse: NOT_RUN. Apple typecheck: NOT_RUN. Native rerun: NOT_RUN.** Sentinel disconnected before this isolated change was applied; publication uses the original Git objects and an expected-head guarded branch. No compiler or acceptance success is claimed.

## Evidence limits

The event decode and collector receipt come from CRC-verified selective ranges of capture artifact 14632274701. Its whole 775,094,118-byte archive was not downloaded, so its full archive SHA is not claimed as verified. Original event entry visual-11/9EF9D7C1-C85D-4BAF-A8A9-2CB1EEB19340 is 1,891 bytes, SHA256 759ec4fc6232816211c41f1f32b4657b15c30ddfef50a37fc0e25da61c96d76e, CRC234a6bc4.

The actual AX entry is visual-11/56DA839C-4DD8-4398-BCED-63BEFCF924F3.txt (46,339 bytes, SHA f8593c75af11f21ea44357b556fe43df6b32e707dc83045984c2503888e99363). The screenshot is visual-11/5A479ADD-9949-4AB3-9140-67CAB0C14A1B.png (556,095 bytes, SHA0349fb59358323303a09c589c6dfdf0e785f697228846961015797a9759bf339).

The full Native98 raw evidence package remains a separate collection. This small change does not close the Native or Profiles acceptance task.

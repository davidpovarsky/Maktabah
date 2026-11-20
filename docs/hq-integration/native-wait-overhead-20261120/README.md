# Native sidebar timeout: avoid redundant polling startup

Source base: `d0c649794e4262ffdea0e13635d5c8237668bd6e`. Native78 run44633736259 timed out the LTR sidebar test at600seconds; the log still shows successful real dot transitions afterward, and the RTL sibling passed in543.455seconds. The failure is preserved. This change does not claim a product hang was repaired or that the Native case now passes.

The exact LTR trace repeatedly records an already-present control followed by approximately1.02–1.07seconds before the first existence-predicate check. The prepared test code now accepts the same immediate live existence snapshot and otherwise uses the unchanged XCTest wait. The page-selection helper similarly asserts a currently true actual native selection and otherwise retains its original15second predicate wait.

All20body and20dot transitions per language, actual directional gestures, unique sidebar owner, source-derived fixture paths, private queries, empty-result and restored-catalog checks, title/locator/source/viewport identity, screenshot evidence and the600second execution limit remain unchanged. The existing viewport check and actual native coordinate tap are unchanged. There are no additional retries, reversed gestures or synthetic UI state. No production source changes.

`SOURCE_PRESERVATION.json` proves that reversing only the six reviewed substitutions reproduces both prior source files byte-for-byte. This is source evidence, not an executed XCTest result. Actual Native timing and acceptance remain pending.

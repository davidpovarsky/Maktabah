# A1: wait for the original Reader's text before sampling highlights

The authentic Release run 44665679661 failed A1 with searchHighlightCount=0 on app 7e, before any window case. This follow-up changes only the 21-line pre-sample readiness block in the original XCTest method. Product sources, original highlight/clear assertions and their deadlines remain unchanged. Candidate Apple typecheck and Native execution are NOT_RUN.

## Observed cause and limits

The original test waits for reader-text and reader-rendered-highlight-diagnostics to exist. Both can exist while the original UITextView is empty. The unchanged production diagnostic explicitly reports zero for empty attributedText, and updateUIView publishes that snapshot before backend text has loaded.

The original screen recording was recovered through authenticated HTTP206 ranges. Selected entries passed ZIP CRC validation and have recorded SHA256 hashes. The entire 3.11GB capture archive was not downloaded or hash-verified.
The Reader is visibly blank at video 39s and 41.7s (identical decoded-frame hashes), while its title and Clear X control are mounted. By 42.7s, the original Genesis text is visible, with a yellow highlight near the top. The final logged diagnostic query begins at test 41.98s, corresponding approximately to video 41.608s. The log does not timestamp the value's return. Video color is not a structured counter PASS.

The same run's original AX tree independently confirms that the diagnostic node is a child of the original reader-text TextView. Source defines the same containment; no new UI marker or synthetic state is introduced.

## Narrow correction

Before the unchanged sample, a six-second native predicate requires actual alphanumeric text from the same Reader's accessibility value, rejects diagnostic JSON as text, and verifies exactly one diagnostic descendant decodes with a positive renderGeneration. It does not wait for searchHighlightCount>0. A loaded Reader with zero real highlights still reaches and fails the original positive-count assertion.

The entire previous file is restored by removing exactly these 21 added lines. A Swift 6.3.3 frontend parse passed with exit 0 and zero warnings. No UIKit/native runtime was executed locally. The selected original A1 method remains required in diagnostic 38 and the full Release matrix.

## Evidence

RESULT.json records scope and source hashes. SOURCE_EVIDENCE.json preserves the actual diagnostic/render source; the diagnostic file is byte-identical between actual app 7e and this base.
TIMING.json states the precise timestamp relationship and its limit. RANGE_EVIDENCE.json and ARTIFACT_METADATA.json bind the selected capture reads to the actual run. The original 14.3MB recording and exact downloaded ranges remain in the owned build/release-a1-investigation-20261120 directory; only the relevant original decoded frames are committed here.

# Motion palette capture: actionable controls

This isolated candidate changes one condition in `captureOpenLibraryPalette` in the original complete `FaithfulReaderUIAcceptanceTests.swift`. The palette remains the exact identified accessibility container. The capture requires the original input and book result to be hittable within its verified bounds. It no longer asks the non-action container itself to be a hit target.

The parent is `28befd6ef09310eb4becc8ee64e43cba1dc3e00d`. Its canonical Git tree and UI leaf were fetched independently before editing. `SOURCE_INVERSE.json` records the exact whole-file inverse, source hashes, and preservation of all 40 existing test declarations. Only this Swift file and this documentation directory are changed.

## Actual failure that motivated the change

[Focused4 v2 run 44807261790](https://github.com/davidpovarsky/Maktabah/actions/runs/44807261790), immutable source `8bb0ab7e87895a85265132188ede021cef3a08ae`, completed with three passing cases and one failing Motion case. The full app build passed. The Motion test stopped at its 20-second palette capture settlement before tapping the actual book result. Its total duration was 241.513 seconds; this was not a 600-second case cutoff. Root's independent raw-leaf, canonical input, product, and privacy review is retained in `ROOT_NATIVE_RECEIPT_REVIEW.json`.

The two matched AX snapshots have identical window, palette, input, and book-button frames. The retained PNGs show the original search input and Genesis result above the keyboard. The ordered XCTest log reaches the container hit-test after retrieving all frames, then starts the next predicate evaluation without reaching the input/result hit-tests. This supports a short-circuit at the container condition. The Boolean itself was not serialized, and screenshots do not prove either actionable control was hittable.

## Preserved acceptance

The exact original palette ownership, positive finite geometry, window orientation, containment, 20-second settlement, and actual input/result hit-tests remain. The original Motion test body is byte-identical: actual system preference toggle and restoration, original search query, real book-button tap, original Reader restoration, and original Reader toolbar capture are retained. No application source, test selection, test count, feature flag, or 600-second case budget changes.

The earlier [Focused4 v1 failure](https://github.com/davidpovarsky/Maktabah/actions/runs/44786439788) and this v2 failure remain failures. The candidate has no Swift typecheck or Native execution result. The new source must pass the real original test before it receives acceptance credit.

## Raw evidence

The complete original GitHub artifacts remain authoritative:

- [Evidence artifact 14670442656](https://api.github.com/repos/davidpovarsky/Maktabah/actions/artifacts/14670442656): 11,255,807 bytes, SHA256 `d0c4805b46ae132b3007388ba590947f95624a68bf3c264d3be1381cc5be2cfe`, 150 CRC-verified members.
- [Captures artifact 14670143892](https://api.github.com/repos/davidpovarsky/Maktabah/actions/artifacts/14670143892): 125,174,360 bytes, SHA256 `c842d4706b51fa22efb1a72e74d9bde798b26be267aa6e74f333b97a6e62886e`, 1,507 CRC-verified members.

`raw/` contains the exact matched before/UNSETTLED AX and PNG files, their original attachment metadata, the complete test log compressed without changing its bytes, and the original complete Swift source compressed for the inverse. Private download credentials are excluded. `EVIDENCE.json` binds these files to the full artifacts and records the inference limits. `ARTIFACTS.json` indexes every other published source/document file, including compressed inner hashes.

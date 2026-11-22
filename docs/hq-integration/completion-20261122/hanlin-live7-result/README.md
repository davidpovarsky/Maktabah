# Hanlin Live7 — actual failed result and verified cleanup

Run [44993301949](https://github.com/davidpovarsky/Maktabah/actions/runs/44993301949), attempt 1, executed checkout `77c7df82ef5f822bf0b1dd7e08ff2b4b98d425d2`, application `0ea7218331d1441d37d06d43333e579f267056e3`. It completed **FAILURE** at 2026-11-22T06:54:09Z.

The original app/UI build passed. The one original Live case executed for **78.00888001918793 seconds**, with **0 PASS / 1 FAIL / 0 SKIP** on iPad Pro 11-inch (M5), iOS Simulator 27.2. Reader/paragraph/provider settings and consent ON passed. After the actual Connect tap at t=42.97s, the source-qualified read-session element did not appear within 30 seconds. The case stopped at HanlinConsumerAcceptanceTests.swift:551 before composing or sending a prompt. **Zero provider conversations were verified.**

[Original failure analysis](original/FAILURE_REVIEW.md) preserves the observation and uncertainty. No callback, currentness or configuration cause is inferred without evidence. The 45-second simulator container lookup timeout belongs to setup; the existing second install succeeded before the testcase.

## Evidence and verification

The sole artifact14743563942 was downloaded once, 87,598 bytes, SHA256 `13b8464d57769bce384436b68c5b5230248f7fbcde189f2d84d9f365942aed35`, matching the GitHub digest. The unchanged [original packet index](original/FILE_INDEX.json) covers 28 payloads / 456,797 bytes and remains a closed directory with its index as the 29th file.

[Root review](ROOT_REVIEW.json) independently verified all 28 payloads, all 22 safe CRC-checked ZIP entries, all 21 admitted payloads, all 281 immutable execution Git blobs and the four product trees. Source-before and source-after are byte-identical. Five runner-recorded binary digests remain stable; the filtered artifact excludes binary payloads, so no independent local verification of their bytes is claimed. [Actual verification execution](ROOT_REVIEW_EXECUTION.json) and [verification source](ROOT_REVIEW.py) retain the performed checks. No build, test or download was repeated.

The original privacy admission reports one-use input staged/consumed/removed, no credential in child environment or test arguments, no raw container/result bundle/video publication, zero redactions, restoration of prior artifacts and successful owned simulator cleanup.

## Secret lifecycle completed

Root's sole lifecycle job22da37438b5f terminated successfully after observing the exact failed run. Its gh-watch exit1 records that failed run, not failed cleanup. Matching owned secret metadata was followed by **DELETE204 and GET404 at 2026-11-22T06:54:36.558829Z**.

[Final lifecycle](../hanlin-live7-lifecycle/LIFECYCLE_FINAL.json) and [secret cleanup](../hanlin-live7-lifecycle/SECRET_CLEANUP.json) preserve those results. The original dispatch snapshot and controller remain unchanged. No active Live observer or secret remains at publication; no credential value is retained.

This packet accepts neither Live nor full Native116/Release114. A separate bounded diagnostic proposal is being validated. Its evidence cannot substitute for the original final witness or authorize provider/body/receipt acceptance.

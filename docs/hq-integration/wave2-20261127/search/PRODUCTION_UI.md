# Published production v40 native UI contract

Status: source and public manifest checks completed; actual Apple compilation and native execution pending. These tests are not an acceptance receipt until the exact integration candidate runs them.

Run the ordered selectors in **production-ui-contract.json** on the same owned Simulator app installation. The first selector requires an original app-managed v40 database and no preinstalled search manifests. It uses Search → More → Search Data → the original “הורד והתקן רכיבים חסרים” button. The two later selectors require that resulting installation. Do not seed an index or replace the database.

The launch uses normal production bootstrap and the original backend and engines. The only new launch diagnostics are a DEBUG-only opt-in flag and a separate UUID for passive provider/publication observations. The ordinary production workspace has no test namespace. The observer neither supplies responses nor changes queries or results. Reader line mode is an existing user preference selected for a later reader navigation gate.

The tests reject external database/shared-root overrides. They independently discover the original app and App Group by Simulator container-manager metadata, reject ambiguous owners and symbolic-link paths, require the exact v40 release, stream the complete 4,355,063,808-byte database through SHA-256, and compare original manifest/ownership bytes after index operations. The independent SQL connection is read-only.

The page gates submit the real query בראשית. Zayit explicitly uses its existing flexible/near5 picker. Native counters must show 50, 100, 150 for Zayit and 100, 200 for Otzaria. An actual no-match title-filter control stops automatic prefetch while the existing Load more results button requests the next page. The tests compare original provider order, stable IDs, all retained metadata, UI-published IDs/book/line/reference/locator/highlights, and every source line's ID/title/reference in the actual installed database. A snapshot/model-only or source-different result does not satisfy these gates.

## Current public manifest verification

Both small manifests were fetched directly from the already published GitHub releases; no index payload was downloaded. Their SHA-256 values exactly match the previous delivery. See **otzaria-public-size-receipt.json**, **zayit-public-size-receipt.json** and the original manifest bytes beside this file.

| Package | Installed payload bytes | Compressed transfer bytes | Largest compressed part | Parts |
| --- | ---: | ---: | ---: | ---: |
| Otzaria | 5,696,232,697 | 4,150,325,346 | 478,203,591 | 15 |
| Zayit | 4,108,856,448 | 3,159,917,458 | 436,703,806 | 74 |
| Installed total | 9,805,089,145 | 7,310,242,804 | — | 89 |

Every part is independently zstd-compressed. The current original installers download and verify one part, extract it into staging, and delete the compressed part before the next one. Promotion is a same-volume rename. Otzaria uses installStreaming, not its older all-parts installation method.

For a fresh sequential installation, a conservative upper bound on additional search payload at the second installer is **10,241,792,951 bytes**: installed Otzaria + complete Zayit staging + its largest compressed part. With the existing production database, this is **14,596,856,759 bytes**. Both capacity policies additionally require a **1,073,741,824-byte reserve**, which is free-space headroom, not another file. These figures exclude the app/build products and shared lexical.db. Its exact manifest size is recorded in the Zayit manifest.

A resumed URLSession transfer can transiently retain a partial and its downloaded remainder while appending, so allow another largest-part budget for an arbitrary resume. The UI install acceptance starts without seeded indexes; the runner must retain the actual disk observations and not represent this computed bound as an observed high-water mark.

## Limits that remain open

No offline credit is assigned here. A real per-process or owned-Simulator network negative control must demonstrate failed public traffic while installed original searches still work. A Wi-Fi icon is not evidence, and global Mac network changes are excluded because other agents use the host.

This suite covers published-bundle installation/cold recognition and original engine pagination/identity/metadata. It does not replace full-v32 reader/Inspector acceptance, canonical translation/version-grouping cases, or the complete F01–F10/R01–R08 matrix.

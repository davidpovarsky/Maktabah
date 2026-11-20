# Completed producer test copy cleanup

At 2026-11-20 05:40:01 UTC, after explicit owner confirmation of the corrected exact path, only the completed temporary full-v32 producer265 read copy was removed:

C:\Users\DAVID\Code\Maktabah-index-read-compatibility-20261120\build\index-read-qualification-20261120\read-copies\full-v32\producer265

The initial instruction named runtime/full-v32; inspection showed that directory contains evidence, while payload copies are under read-copies/full-v32. The mismatch was reported and the exact producer265 path was authorized before deletion. No file under runtime was selected.

All 10 files had one hard link, no reparse/symlink attribute, and matching sealed after-inventory sizes. No matching owned engine/reader process was observed. All ten Windows share-denied read handles opened simultaneously and were then closed before unlink. See VERIFICATION_SCOPE.json for the exact meaning and limits of the metadata checks; the 5.22 GB payload was not unnecessarily rehashed.

Logical bytes removed: 5,219,903,460. Observed free space increased from 656,097,280 to 5,876,002,816 bytes, a 5,219,905,536-byte difference. Concurrent host writes can affect the free-space delta.

The authenticated original pristine directory, all 14 compressed archives, the consumerd5 read copy, copy/after-hash receipts and runtime evidence remain. Their retained file identity/size/write-time observations and original meta hashes were checked before and after. No original database or user index was touched. This removes a reproducible test copy, not original data or qualification evidence.

The two original cleanup receipts are stored losslessly as deterministic gzip, with both raw and stored hashes in SHA256SUMS.json. They preserve the initial observed field names; VERIFICATION_SCOPE.json explicitly clarifies the historical-mtime limitation without rewriting those receipts.

# Explicitly approved search compiler-cache retirement

At 2026-11-27T06:02:55Z, the only retired path was /Users/m1/builds/otzaria-wave2-search-20261127/post-update-ui-typecheck/module-cache. Root explicitly authorized this exact reproducible cache after receiving the read-only inventory and confirming the library/reader lanes had no current or planned use. This followed, and is separate from, offline source checkpoint 84a3de944b9197521f15fdb975d45a7b1f73f2c3.

The original 218-file membership and full device/inode/size/nlink/mtime/ctime records matched again immediately before unlink. Canonical paths and regular-file/directory types were required, symlinks refused, actual process references were absent, and root lsof +D returned exit1 with empty stdout/stderr. Only the current controller's actual ancestor PID chain was excluded from command-text matching. Every file identity was rechecked before its individual unlink; only freshly matched empty owned directories were removed afterward. No recursive wildcard deletion was used.

Allocated file bytes retired: 130,023,424. Measured free space changed 11,458,555,904 to 11,588,268,032 bytes, a delta of 129,712,128. The actual free-space delta may include concurrent independent writes on the shared volume; it is not substituted for the separately accounted allocated bytes.

All 2,028 sibling files under the search-owned build root retained identical full stat inventories. Source, logs, signatures, probe binaries, modules outside this cache and evidence receipts were preserved. No SDK, foreign path, PF state, launchd configuration or network policy was changed. There was no transport-probe, offline-window or native-UI execution.

ORIGINAL_INVENTORY.json preserves the earlier read-only inventory. BEFORE.json is the exact fsynced Mac admission receipt. MAC_RESULT.json is the original final Mac receipt; RESULT.json is its parsed Oracle copy. retire-owned-module-cache.py, DISPATCH.json, RUN.json and raw stdout/stderr preserve the exact action and its result.

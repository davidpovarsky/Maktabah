# First production v40 install: phase storage budget

## Result

The first-install corpus payload reaches **8,614,869,080 logical bytes (8.615 GB; 8.023 GiB)** while verified multipart files, their assembled archive and the extracted database coexist. That amount excludes small metadata, filesystem allocation overhead, the simulator, installed application images, application startup data, evidence, OS/swap and other owners' growth.

The current acceptance pipeline nevertheless has three separate storage checks. The outer `WORK_BYTES = 24_000_000_000` is a fixed conservative lane budget; the code does not derive it from the release manifest. A second shell check requires **22 GiB free after simulator boot and app installation**, and the original product has its own conservative six-times-output preflight. All three checks remain unchanged.

This is source analysis at commit `8de1c26e36dc15c5641eeba0a182279714ac687b`, not a new disk-usage measurement or native installation result. `SOURCE_BINDINGS.json` records the exact Git blobs, lengths and SHA-256 of the nine inspected inputs. Local inspection copies were verified byte-for-byte against those Git blob identities.

## Actual payload inputs

Let C be the official total compressed archive and D the previously admitted full database.

| Input | Bytes | GiB |
| --- | ---: | ---: |
| Part 000 | 1,992,294,400 | 1.855469 |
| Part 001 | 137,608,236 | 0.128158 |
| C: complete compressed archive | 2,129,902,636 | 1.983626 |
| D: extracted full database | 4,355,063,808 | 4.055969 |

The retained official manifest at `docs/hq-integration/library-acceptance-20261125/seforim-schema7.db.zst.manifest.json` binds v40 archive SHA-256 `39a2b52129323ea53ac3629835c4721e25acff010a8fc971bf076a666a3b9587`.

D comes from the existing full-source identity receipt under `../inspector-v40/SOURCE_IDENTITY.json`: database SHA-256 `8389709c1702753af6f0719ef1c98c09854450e48ebb05fe1f95486b26348b01`, observed by the actual read-only hash at 00:28:01–00:29:54 UTC on November 27. This audit reuses that receipt. It did not rehash, recount, copy or reopen the full corpus.

For the controller's newly created owned simulator, the initial managed old database O is zero. Existing unrelated simulator/application files already consume the measured free-space baseline and must not be silently treated as reusable space.

## Simultaneous corpus files

| Phase | Retained parts | Assembly or archive | New staging or final DB | Old managed DB | Maximum logical corpus bytes |
| --- | ---: | ---: | ---: | ---: | ---: |
| Sequential part downloads | up to C | 0 | 0 | 0 | 2,129,902,636 |
| End of archive assembly | C | C | 0 | 0 | 4,259,805,272 |
| Complete archive verification | C | C | 0 | 0 | 4,259,805,272 |
| End of extraction and read-only SQLite validation | C | C | D | 0 | **8,614,869,080** |
| First promotion before cleanup | C | C | D | 0 | **8,614,869,080** |
| Successful cleanup and cold restore | 0 | 0 | D | 0 | 4,355,063,808 |

The table accounts for the following actual source behavior:

- `OtzariaDatabaseDownloader.downloadMultipart` downloads parts sequentially through the original per-asset data delegate. The delegate writes received data directly to each part file. There is no application-owned full URLSession download-task temporary file in this path.
- Completed part files remain available for resume. Assembly writes their bytes into `seforim.db.zst.assembling` with a 4 MiB read buffer, so parts and assembly coexist.
- Assembly is moved to `seforim.db.zst.part` in the same directory. These are successive names for one assembled file, not two simultaneous complete archive copies. Invalid old archive/assembly paths are removed before a new assembly starts.
- The service verifies the whole archive and then streams it into one unique `seforim.db.installing-<pid>-<UUID>` staging file. The extractor reads/writes bounded chunks; it does not create another complete output file.
- `validateDatabase` opens staging with `SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX` and runs quick_check/schema validation. No corpus-copy or writable migration is requested by this validation.
- On a first install, `OtzariaDatabaseInstaller.promote` takes the no-existing-final branch and moves staging to `seforim.db` within its parent directory. It does not create a previous database. The pending installation manifest is small metadata written atomically.
- The original adapter activates the database, completes the manifest commit and calls `finishSuccessfulInstall`. Only then are the archive, part directory, sidecars and leftover assembly removed.

No APFS clone, deduplication, filesystem compression or sparse-file savings are credited. Logical byte counts are not exact physical allocated-block measurements. Small atomic JSON writes, directory entries and allocation rounding are represented by an additional metadata allowance, not by an invented zero-byte guarantee.

## Cancel, resume, retry and recovery

The existing shell requests cancellation after 67,108,864 downloaded bytes. The observed retained R can exceed that threshold by an in-flight chunk; the real cancellation report is authoritative. Resume opens/appends the same qualified part files. The script terminates and relaunches the same installed app three times; it does not install three copies of the database or archive.

An already assembled archive of the exact expected size is reused and then verified by the service. An incomplete assembly is removed before rebuilding. A normal extraction error/cancellation removes this operation's unique staging file. A metadata-promotion rollback restores the previous database, if one exists, and preserves verified download input for retry.

The first-install table assumes a fresh owned simulator and no orphan staging files. A hard kill during extraction can leave a unique staging file that is outside a normal cancellation cleanup; any retained failure container therefore needs its own inventory before reuse. This audit does not authorize deletion of such files or of another owner's container.

For a later update with an old database O, the named files before promotion can contain O + 2C + D. After replacement, O has the rollback role and D the final role. The Foundation replacement call's private temporary allocation is not measured here; the product preflight conservatively adds `existingFinalSize` to requested free capacity. No extra O is charged to the first-install move branch, where O = 0.

## Three unchanged admission checks

| Check and point | Formula / threshold | Exact bytes |
| --- | --- | ---: |
| Python controller, before creating the new simulator | WORK_BYTES + OS margin + reserved-other | 24,000,000,000 + M + R_other |
| Python default, with no other-owner reserve | 24e9 + default 2e9 | **26,000,000,000** |
| Shell helper, after boot and simctl install | 22 × 1024³ free at the actual container | **23,622,320,128** |
| Product, fresh multipart download | C remaining + 6C unknown output + C assembly + 1 GiB | **18,112,962,912** |
| Product extraction, if frame header declares D, no old DB | D + 1 GiB free at extraction time | 5,428,805,632 |
| Product extraction, if header size is unknown, no old DB | 6C + 1 GiB free at extraction time | 13,853,157,640 |

For resume, the product download formula is `8C - min(max(R,0),C) + 1 GiB`. R is already resident and has already reduced available free space; reuse does not allocate a second R.

The zstd header was not reread for this audit. Both extraction branches are shown. In the unknown-header case, the extraction check occurs after 2C has been stored; its required initial free capacity is therefore 2C + 6C + 1 GiB, exactly the fresh download preflight above. In the known-D case, the initial content-plus-reserve requirement is 2C + D + 1 GiB = 9,688,610,904 bytes, but the earlier conservative download gate still applies.

The six-times fallback is a reservation policy; it is not the actual v40 compression ratio. Similarly, 24e9 bytes is **24 decimal GB**, approximately 22.352 GiB, not 24 GiB.

These checks also use different free-space APIs: Python's disk_usage at ROOT, df -Pk at the installed app container, and Apple's important-usage capacity with ordinary-volume fallback. Their observed values must be retained separately.

## Setup and other-owner growth

Let F0 be free space measured by the controller before creating its simulator; M the OS margin; R_other the explicitly reserved concurrent growth; and G_setup actual new simulator/app/startup/evidence growth before the shell check. To pass both wrapper checks, at minimum:

`F0 >= max(24e9 + M + R_other, 22 GiB + G_setup + other growth before the shell check)`.

At the default outer minimum of 26e9 bytes, only 2,377,679,872 bytes remain above the shell's 22 GiB threshold for all intervening growth. An outer pass therefore does not guarantee the inner pass if setup consumes more.

Keep these categories separate from 2C + D:

- the new simulator's data and boot caches;
- the installed application and any startup-created user data;
- pre-existing runtime/build images, which are already charged to F0;
- new compiler/build images if another owner builds concurrently;
- test reports, screenshots and logs;
- OS/swap growth and explicit other-owner reservations.

The installer driver consumes an already-qualified app and the shell only installs it into the new simulator; neither inspected script runs xcodebuild. The scripts copy JSON reports and metadata to evidence output, not the full database. No amount for the unmeasured setup categories is asserted here.

A free-space observation of about 20.44 decimal GB would fail the unchanged outer gate and also be below the inner 22 GiB check even before new setup growth. The smaller corpus payload does not make that execution admitted.

## Cache ownership observation

`OWNED_CACHE_INVENTORY.json` records a separate read-only Mac observation at 02:34:18.944 UTC. It found three module-cache directories under the library-controls owner root and no process command referencing that root. The library owner's last tiny typecheck finished at 02:14:29 and no subsequent library job was started. This is a timestamped ownership/command-reference observation, not proof about future processes or every open file descriptor. Root remains responsible for any fresh cleanup admission.

No files were deleted, no application or storage gate was modified, and no build or native acceptance was run for this budget.

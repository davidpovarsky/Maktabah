# Three original runner contexts: read-only capacity finding

## Decision

These three contexts do not provide a sufficient closed generated-output scope for the pending SDK launch. No archive, deletion, process action, simulator action or build was performed. The original 15,032,385,536-byte launch admission and 2,415,919,104-byte live reserve remain unchanged.

The `session.ntx0UjXO` repository is the observed working directory and executable parent of the explicitly protected upload-symbols processes. Its apparent completed GitHub job does not release that dependency. The two other contexts have only 7,507,968 allocated bytes combined under their remaining `build` directories. Their larger totals are primarily source, Git objects, documentation and Vendor inputs; none is reclassified as disposable cache.

## Exact scope and observations

Common parent: `/Users/m1/builds/otzaria-root-actions-acceptance-20261126.wjQnLNJl`.

| Exact child | Root inode | Terminal runner-log result | Allocated runner/_work bytes | Allocated remaining repository/build bytes |
| --- | ---: | --- | ---: | ---: |
| session.ntx0UjXO | 59155998 | Release build and prototype: Succeeded, 2026-11-26 15:20:41Z | 2,485,870,592 | 114,659,328 |
| session.XsIaHMlh | 60263108 | R27 real UI environment and acceptance: Failed, 2026-11-26 16:03:44Z | 1,376,907,264 | 6,488,064 |
| session.FK20ACaB | 59894314 | Release build and prototype: Failed, 2026-11-26 15:36:42Z | 1,046,147,072 | 1,019,904 |

Each repository is the exact child `runner/_work/Maktabah/Maktabah`. The immutable HEAD read was `ec14460748dc79818b1a7a3f269a54e3a1ddfaa9` for ntx and `ad6388628ba8a32c0b88d3f4a01bd1a7bb1ade9d` for Xs and FK. These are metadata observations, not source acceptance or cleanliness assertions.

The remaining ntx build allocation includes historical native artifacts and xcresult evidence. Its `ReleaseDerivedData` path is absent from the current immediate build-directory inventory, while the exact original app executable path remains held by the protected processes. Xs and FK contain only small original generated files, bundle artifacts and failed-run evidence. All original failures remain in place.

## Live dependency hold

One bounded `lsof -nP -Fpcfn` query retained only paths inside these exact three roots. It found:

- Shell PID 35619 and upload-symbols PID 35620, start 2026-11-26 17:01:38.
- Shell PID 41371 and upload-symbols PID 41372, start 2026-11-26 17:09:32.
- Both process pairs retain the ntx repository as cwd.
- Both upload-symbols processes retain `Pods/FirebaseCrashlytics/upload-symbols` and the original `build/ReleaseDerivedData/Build/Products/Release-iphonesimulator/Maktabah.app/Maktabah` executable.

Those PIDs and their parents were already explicitly protected by the root integration owner. They were not signalled or otherwise changed. No scoped open paths were observed for Xs or FK at the observation time; this is not a permanent no-use guarantee or a retirement authorization.

No runner credential or registration contents, environment contents, or process arguments were read or copied. Unrelated open-file rows were discarded in memory and were not retained in the receipt. All Mac inspection code was sent on stdin through the existing pinned Oracle-ubuntu to scaleway-mac SSH route; it created no Mac files.

## Capacity implication and limits

The first bounded observation at 15:57 UTC recorded available bytes changing from 11,907,018,752 to 11,851,247,616. The second at 15:59 UTC recorded 11,564,916,736 to 11,470,454,784. The final sample was 3,561,930,752 bytes below the unchanged launch admission. These are concurrent shared-filesystem observations; no causal attribution is made.

All three remaining build directories total only 122,167,296 allocated bytes, and the protected ntx context is not proposed for retirement. No additional APFS-private-allocation traversal was needed: even this allocated upper bound cannot close the measured gap. Allocated bytes are not a promised free-space gain, and no full preservation or recovery proof has been made for these scopes.

The read-only hypothesis is exhausted. Do not archive a whole runner or remove source, Git objects, Vendor dependencies, shared SourcePackages, qualified SDKs, paired Release products, held symbol outputs, or the protected Golden5000 simulator based on this report. Any future scope requires its own root authorization and complete source/dependency/preservation proof.

## Reproducibility and evidence

`RESULT.json` binds both raw JSON observations and transport receipts. `ARTIFACTS.json` binds every file in this packet. The exact two scripts are included. The original raw Oracle receipts remain at the absolute paths recorded in RESULT. The reads were jobs `job_c3dce0fbc8c1` and `job_ed60dc5746b4`.

The scripts only inspect the three fixed root inodes, selected sanitized job-status lines, immediate directory names, bounded du results, immutable HEADs and same-root open references. They do not run a project verifier, inspect dirty-worktree acceptance, compile or qualify any source. This packet is documentation only.

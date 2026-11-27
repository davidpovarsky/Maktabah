# MiniApps canonical CI guard correction

Base: `4e057e453bc837f54e176f8160a3bc7446bac9ad`. This packet is an isolated downstream CI correction on the delivered Wave1 evidence path. It changes no application, Swift XCTest, dependency, source-equivalence selection, miniTest10 requirement or signed-owner record.

## Concrete defects and correction

The image-origin auditor's original `assert not sys.flags.optimize` is itself removed by optimized Python. The before-correction run actually executed the existing wrong-UUID fixture under `python -I -O` and returned `SOURCE_INTEGRITY_FIXTURE_WRONG_UUID_ACCEPTED=True`. The added module-level ordinary `if sys.flags.optimize: raise RuntimeError(...)` now refuses import before any image-origin acceptance. All original image-audit assertions remain intact.

The canonical MiniApps runner previously inherited diagnostic branch flags without rejecting them. These flags select abbreviated or alternative native journeys:

| Exact flag | Diagnostic branch |
| --- | --- |
| `MINIAPPS_NATIVE_RICH_ONLY_ORIGINAL_DB` | Rich-only path returns before the original compact text path |
| `MINIAPPS_NATIVE_CALLBACK_ACCEPTANCE_ONLY` | Bypasses original picker editing |
| `MINIAPPS_RICH_ORIGINAL_TEXTSTUDIO_SEED` | Seeds through TextStudio instead of the original keyboard path |
| `MINIAPPS_RICH_ORIGINAL_PASTE_SEED` | Seeds through paste instead of the original keyboard path |

The guard rejects presence of each name and its exact `TEST_RUNNER_` alias, including empty and `0` values. It checks the canonical runner's inherited environment whenever configuration is admitted, checks the environment again at final xctestrun construction, and recursively checks every dictionary/list in the effective xctestrun before writing any copied configuration or admission record. Ordinary acceptance settings and original values remain allowed.

## Verification actually executed

All runs used Oracle Python 3.12.3. No Apple app, simulator, native XCTest, SDK build or physical-device run was performed.

- Before changing the two existing CI files, the new 8-method suite ran against exact base source and reported 85 failing negative subcases. Its two clean-path methods succeeded. The actual optimized wrong-UUID acceptance is visible in the raw failure log.
- The identical new control-file SHA256 ran after correction: 8 methods passed, including actual subprocesses with `-O`, `-OO`, `PYTHONOPTIMIZE=1`, optimized canonical configuration, and the existing wrong-UUID fixture. All inherited names/aliases and embedded xctestrun app, runner, native-target and nested environments were refused. Rejection left the original xctestrun bytes unchanged and created no output admission files.
- The 12 unchanged image-origin controls passed. They retain the PID, actual private bytes, loaded UUID, foreign image, original artifact, independent XCTest PID and loader-preservation assertions.
- A separately retained actual `python -I -O` command exited 1 with the ordinary RuntimeError before importing the acceptance module.
- `after-correction/PRESERVATION.json` records exact unchanged native Swift tests, original image test source, original matrix, current input pins and 16-file bridge-equivalence JSON. The original `ImageAudit`, sample UUID parser, `collect()`, `matrix()` and full native workflow function bodies are AST-identical to base.

These results are source-integrity controls only: native acceptance is **NOT RUN**. The existing canonical runner still requires a genuine miniTest10 build. Production MiniApps acceptance remains a separate open requirement and is not relabeled by this patch. The earlier Wave1 confirm-button assertion change also remains outside this narrow guard correction.

## Ownership, evidence and rollback

Both modified CI paths are downstream-owned and absent from the pinned upstream tree `4203de5fd77beb119e5826e039be1a61325f7be0`; their last prior change is `0e450c9ce777f766e99c2dad356b3cb6416d5646`. The pinned upstream value comes from the root's live review and was checked as a local Git object; this lane's separate live read timed out. No upstream sync occurred.

The new test file and this evidence directory are downstream additions. No upstream application hook is changed. Rollback is the single correction commit, while this directory retains the baseline failure and final control receipts.

Raw commands, source hashes, stdout/stderr and source-preservation records are stored in `before-4e057e45/` and `after-correction/`. `RESULT.json` seals the scoped evidence inventory.

The baseline unittest stderr is retained byte-for-byte as `before-4e057e45/stderr.log.gz`; its decoded SHA256 is the original value in the untouched baseline execution receipt. Compression preserves the authentic failure output, including unittest's trailing spaces, while keeping source diff checks clean. An additional raw copy remains in this isolated worktree's build/wave3-miniapps-ci-guards-20261127 directory.

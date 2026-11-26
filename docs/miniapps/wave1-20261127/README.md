# Wave 1 MiniApps product handoff — 27 November 2026

Status: product source ready for the integration owner. Integrated runtime acceptance remains open.

## Exact product chain

Base is Maktabah `29a731e273f9a757c743c49e182fece0e8047d46`. Two product commits are required, in order:

1. `d1cea8e83f91d7e725d7dd04409162043da0e4ff`: retain the saved native launch context.
2. `50caaf82d922c0ecc26642d98f9d4ab9c4aa4dbb`: distinguish the durable captured context from the current live mount, retaining edits in other blocks and remapping cold-import targets.

They were replayed without conflict as `1d6c413e` then `7f68307e6395b832ad294d26129f9dc6baa0639f` on branch `codex/otzaria-wave1-miniapps-20261127`. The previous integration intake `82918d66` also contains these two commits, but base `29a731e2` does not. Pick one chain only. No release branch was modified.

Only `Source/ChavrusaText/Annotations/LocalEditor/AnnotationOriginalEditorProductionUI.swift` and `Source/ChavrusaText/MiniApps/OtzariaMiniAppsCoordinator.swift` change (38 insertions, 12 deletions). Both are downstream files absent from original Maktabah upstream `4203de5fd77beb119e5826e039be1a61325f7be0`. Existing architecture, native editor, SQLite transaction, receipt and callback ACK ownership remain in their original implementations. Rollback is the reverse of these two small commits; stored user content is not changed by this source operation.

## The accepted TextStudio build was a composed product

Do not mistake the test commit `a540762478940a2d920c504a03e413ea710a4df1` for application source. The actual original app checkout was `2aa8e3aa0819e74ae3e5af1056b84e73e723fa57`, with these separate dependencies:

| Role | Exact source |
| --- | --- |
| Standalone MiniApps producer | Hanlin `9565a9e4775901a4cee6f0402d7fd2978fab6612` |
| Shared Hanlin SDK linked in Otzaria | Hanlin `9b3d0555275f2fc6cc53926c7bf66cb8b1516f5a` |
| Anytype native framework used by that run | Diagnostic source `9ebf4271954d375d1bffe4a310a772660eeb4ae0` |
| Corresponding clean native product | Anytype `bfc80e5e85eabaa52f914e872f2da6c6888ca88c` |
| Original Heart engine | `b18e6733605deb4086ee95aa4cf755404746cf51` |

The clean Anytype provider `OriginalEditorFramework/AnytypeOriginalEditorLocalAnnotation.swift` has Git blob `877ed9e6b39e82c6e617be32cddf4821c89f8a00` and SHA-256 `fc9a6bb869bb2c7929a3242cb8d62a3a83704d31027e2e1f7b3f93a4c5027e3c`. The tested diagnostic file is SHA-256 `c552e640984e46896d6ea32bdb67c25ac828523deccdf30ed5542218922f91ec`. Twenty-two of the framework tree's twenty-three files are byte-identical; the remaining exact patch is retained beside the receipt and only adds stage logging. The journal is already included in the clean product, Git blob `860d7c172726c357c0310613a6a0b7fdc1055a5f`.

The two host files in `7f68307e` are token-identical to the accepted app after removal of explicit diagnostic logging only. Raw diagnostic patches are retained so this claim is inspectable. The five original save-receipt lifetime files from `7af5c5a0` and `3c15e967` are already byte-identical in base `29a731e2`; do not reapply them.

The shared MiniApps package difference between tested host `9b3d0555` and base `9565a9e4` is exactly the full-width row hit area in `MiniAppPicker.swift`. The minimal product commit on base9565 is `7ee863657323f314f25a6e58bca0aa9ee669e51b`; picker blob `97f775753e0f24e446479687176b43071556566b` exactly matches the tested newer source. The Hanlin owner chooses the final shared pin; this handoff does not blindly replace the whole divergent SDK.

## Historical evidence preserved and rechecked

The two original evidence archives were read in full and their SHA-256 hashes verified again. No Apple test was rerun to manufacture duplicate evidence.

- TextStudio original iPad Simulator test: 1 passed, 0 failed, 0 skipped; three actual callbacks to one native note, explicit save cancellation without writes, another edited block preserved, cold return, replay without a second save. Archive `miniapps-a5407624-original-rich-warm-cold-verified-evidence.tar.gz`, SHA-256 `20017e02978d0cbeadcaf75c43771e4d6875029593e458021220ce9d4c08a3e3`.
- File Workshop original iPad Simulator test: 1 passed, 0 failed, 0 skipped; actual file bytes, warm/cold callback, cancellation, same-name files, persistent share and replay checks. Archive `miniapps-289a64d9-original-file-workshop-verified-evidence.tar.gz`, SHA-256 `43ab4ec6b05f4f7dd884da3c8ad22f7641a7d841453cba8814508cd561a8a0fe`.

`PRODUCT_SOURCE_RECEIPT.json` records immutable paths, all compared blobs, hashes, exact dependencies and scope. These old runtime passes apply to their recorded products. They do not become tests of `7f68307e` or of an eventual new SDK by virtue of this mapping.

## Remaining acceptance ownership

The Anytype owner fixes manifest loading and qualifies the final original SDK. The Hanlin owner selects the final shared source. The parent/root and integration owner run the genuinely integrated TextStudio/File Workshop/picker scenarios after source admission. Current standalone producer tests, image-origin and multiwindow work remain with the already active producer lane; its current receipts must be mapped to the chosen producer source. Physical-device and release gates remain separate. No task or release is declared complete by this source handoff.

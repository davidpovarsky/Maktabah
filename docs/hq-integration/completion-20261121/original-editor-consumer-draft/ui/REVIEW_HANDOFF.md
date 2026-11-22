# Maktabah original editor UI qualification draft

## Frozen source

`maktabah-original-editor-ui.patch` is based on canonical Maktabah `34d06949e7fedbda6e0d256a769b3d0b8659c211`. Its SHA-256 is `1ca6843ce106269064325cc665dd80096d98604cc74b813620a5e3fcf2ae821a`. `CANDIDATE_INPUTS.json` lists all five exact outputs and their preimages; `GIT_BASE_PROOF.json` independently records the three edited Git blobs.

The source adds the qualification view, inserts its entry into the original annotation sheet, adds passive qualification identities to the original book-annotation list/Edit action, adds one separate UI test, and adds four app-only Swift source memberships. The existing UI-test directory is filesystem synchronized, so the test needs no duplicate PBX membership. `AnnotationLocalEditorSession.swift` already belongs to the app target; the reviewed source-lifetime increment must update that existing file, not add another reference.

The original sheet's Save/Delete implementations and original book-annotation navigation/persistence are unchanged. Original inspector Notes deliberately excludes empty notes. The test therefore creates the blank row through original Save, then uses Reader More → Annotations → the actual row's context-menu Edit.

## Admission and lifecycle

The new entry is compiled only for Debug iOS Simulator and displayed only when `OTZARIA_ORIGINAL_EDITOR_QUALIFICATION=owned-local-only`. It requires a saved positive row ID and valid UUID; blank saved quick-note text; the current mounted original text view; and exact unchanged quick-note, style, color and tags. Whitespace and pending static/native text are treated as edits. The original adapter separately re-reads the durable row and rejects any existing rich or unsupported body.

`root-adapter-qualification-guards.patch` changes only the first conditional line of the three root-owned adapter files. Its SHA-256 is `a61c733f248cab66ec72c741b00e7a58bf666b8bbb1ef5887030770cdcbb331b`. `root-adapter-guards-inputs.json` is regenerated against the reviewed source-lifetime bodies. The condition adds Debug, Simulator and `canImport(AnytypeOriginalEditor)` so ordinary device/Release builds do not acquire an unavailable SDK dependency. When the exact qualification is requested without the module, the UI explicitly reports unavailable; the Native test fails instead of skipping.

The full-screen child retains the actual SDK Host controller. The SDK handles editing, registered-write/RPC drain, export and import; the original annotation session handles the UUID/revision CAS. Both actual commit receipt variants are retained. Explicit Reopen obtains a new source observation and saved-row session; it does not revive the retired first Host. Closing the native journey closes the original quick-note sheet without calling its stale Save action.

This Stage B route preserves the original blank quick-note preview. It neither parses native blocks nor invents a text preview. Every receipt records `preview_derived_from_native_body=false`. Production preview semantics remain unqualified.

## Separate original SDK identity increment

`sdk-passive-block-identity.patch` belongs to the Anytype agent and is not part of the Maktabah patch. Its SHA-256 is `28ec1b436fdafc0d5977f27228734402ef8ba6992724a828d02cecd82ec2e658`; the exact original `TextBlockContentView.swift` blob is `05e3e4c43a7cb8c75e17472c2ec03a058ca4b1f2`. The reviewed delta assigns `original-editor-block-text:<actual blockID>` to the real original text view under Debug + Simulator + the exact marker, and clears it on reuse outside that condition. It changes no text, rendering or editing behavior.

## Native acceptance

Dedicated selector:

`Maktabah-iOSUITests/OriginalEditorAnnotationAcceptanceTests/testSavedBlankAnnotationUsesOriginalEditorAndDurablyReopensTwoBlocks`

The dedicated runner must supply the exact marker to the XCTest runner. The test forwards it to the app through the original `launchWithTier` helper. It uses `.realUI`, the original miniTest10 installer/reader launch and original viewport/workspace observations. The standard Native116 and Release114 catalogs remain unchanged.

The case verifies unsaved-entry rejection, real pending quick-note rejection and original Cancel preservation; opens the saved blank row; types two distinct body blocks through the original native text views; invokes explicit capture/Save; checks the durable same-ID/UUID revision and native archive receipt; invokes the SDK's actual import/reopen; and asserts both distinct original rendered body blocks. It also verifies parent-sheet dismissal and preservation of the original Reader instance/source/viewport. No body seed, smoke-note text file, alternate renderer or fixture RPC writes the text.

The app retains bounded stage receipts under its owned `Documents/original-editor-qualification/<presentation UUID>` directory. The SDK retains its original capture/import evidence. Collection must remain limited to those named proof artifacts; do not archive the SDK's local account/repository or wallet.

## Remaining gates

- Review and join the exact UI patch, root adapter guard lines, reviewed root source-lifetime increment and separate SDK passive identity.
- Build the new original SDK Host source with the original exporter. Prior v9/v10 binaries do not contain these APIs and are not acceptable substitutes.
- Admit the exact source-bound distribution and API surface, then use app-target-only link/embed integration in the original stage2 driver. The distribution is arm64 iOS 27 Simulator Debug, not an XCFramework. Its actual dynamic inventory must determine linking/embedding; modules, headers and library search inputs come from the full original distribution.
- Preserve the exporter's signed framework bytes (no `CodeSignOnCopy` or `RemoveHeadersOnCopy`). Compare and reuse identical existing resources/frameworks; reject collisions. Shared Hanlin, TorahInspector and ZIPFoundation bundle names already exist in Maktabah and cannot be silently overwritten.
- Perform actual Apple typecheck/link/build and one dedicated original-matrix Native execution with exact zero-skip/log/xcresult verification and owned Simulator cleanup. Retain application/SDK source identities, actual framework/bundle inventory, original Native artifacts, stage receipts and original export/import proof.

No Apple build, SDK API typecheck, link, native editor execution, import execution or production/device qualification is claimed by this draft. The separate syntax receipt records only parsing of activated source conditionals.

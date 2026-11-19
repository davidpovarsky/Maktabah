# Navigation contract proof platform repair

Source baseline: e215f277afc913cd2fbd8e9b9b21619c9faf2091.
Original Hanlin SDK: 080d1a2b264ead9e3f9df690f2dd0d3e81ebd07e.

## Verified failure and change

Authenticated [run 44438829968](https://github.com/davidpovarsky/Maktabah/actions/runs/44438829968)
completed with a failure in the generated navigation contract package. Its temporary
manifest omitted platform declarations; the actual compiler invocation targeted
arm64-apple-macos12.0. The original unchanged contracts use APIs available since
macOS 13, and their own original package manifests require macOS 26 and iOS 27.

The proof manifest now declares those same original platforms. No original contract,
dispatcher, test case, app source, SDK pin, product deployment target or assertion changed.
The eight navigation tests remain byte-identical
(SHA-256 ec04b22758a56cb6c6b842d1513d69bcbc9e974c8d9b916d735e765f661653d1).

The official artifact 14492724653 was downloaded in full and all ZIP CRCs verified.
Its complete SHA-256 matches GitHub:
0fb0a23789e3ab101ab4e48ef7c1b3a882ab5ec30b6f1a3d0dfa4d1743f82410.

## Validation boundaries

Python grammar passed. The actual installed Swift 6.3.3 package-manifest evaluator
successfully evaluated the repaired proof and both original pinned package manifests:
all declare macOS 26.0 and iOS 27.0. This is Windows manifest evaluation, not an Apple build.
The corrected Apple contract run remains pending at source publication.

This proof deliberately retains explicit navigation-host/effect doubles. A pass verifies
the original dispatcher's current context-transition limitation; it does not demonstrate
a production reader opening, provider execution, AgentSession/ChatUI composition or native UI.
The original host currently rejects content navigation with
hanlin_content_context_transition_not_installed; its strict stale-context checks remain.
A real same-account navigation transition needs an explicit authority/lifetime contract,
while account, namespace and scene changes must remain rejected.

Current Otzaria is the native Maktabah SwiftUI application. The owner specification
excludes legacy Flutter integration. The successful sibling run
[44438833857](https://github.com/davidpovarsky/Maktabah/actions/runs/44438833857)
is an unsigned app compile only; its runtime job was skipped.

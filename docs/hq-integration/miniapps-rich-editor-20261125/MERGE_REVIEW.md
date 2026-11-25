# Preserve the complete current Maktabah source

Frozen parents: MiniApps adapter 7d56e65d2504f600e0055c037c450edfdce2b533 and original final-delivery 7028e8cbceed9914c51c526c680026aecbc137ca. This is a true merge; previous component commits and original evidence remain in history.

The sole textual conflict was the imports of AnnotationOriginalEditorProductionUI.swift. Both the AnytypeOriginalEditor and HanlinMiniAppsBridge imports remain. The original entry retains its new share/receive presentations and registered legacy annotation identities. The MiniApps launch/receive/reopen implementation remains in the same normal editor presentation. No replacement editor was introduced.

Non-conflicting seams were reviewed separately:

- AnnotationLocalEditorSession keeps every native revision/backfill operation and adds only saveMiniApps using the same original persistence owner.
- Original SQLite persistence keeps complete-note backfill preservation, explicit legacy identity resolution, original revision CAS and native history. The MiniApps journal still wraps the native archive commit within its outer SQLite transaction.
- MiniApps result binding now compares the canonical resolved annotation UUID from the actual editor binding. It retains the original CloudKit record name for row access and transport receipt identity; a registered legacy name is never silently replaced by a generated UUID.
- Settings retains the managed library update and annotation preparation entries and adds the shared MiniApps preferences navigation.
- Xcode registration, original Native116 selection, managed library work and source-bound component receipts are preserved from 7028e8cb. The MiniApps lane retains its separate own selection manifest and does not shrink Native116.

Hanlin remains pinned to the new existing 4e921b9517f2fc28fcaebcb2ba7441ab1fb46a90 source while the central producer integrates that lineage with the MiniApps branch. Moving straight to the initially offered 7214 source would remove existing SIWC, storage, runtime preparation and canonical action behavior. The central owner was notified before a producer build.

Six merged integration files passed actual Apple Swift parse (APPLE_SYNTAX_MERGED.json). This checks syntax only. Full native API compilation and real warm/cold/reader/rich-editor execution remain required. Existing component acceptance is not relabelled as MiniApps app acceptance.

# Otzaria canonical Hanlin SDK ownership and validation

## Authorized scope and source

Worktree: `maktabah-sdk-consumer-20261123`; branch:
`codex/otzaria-canonical-sdk-20261123`; starting source:
`e7f4098e9282d58b965cc6a886b79f74ff940117`.

Actual maintained Maktabah upstream tree was read from
`bismillah-100/Maktabah@6f71e4578dabe0573bf3eebd02441036661c2be2`
on 23 November 2026 (710 tree entries, not truncated). No upstream merge is
part of this SDK integration.

The user's current Hanlin SDK instruction explicitly requires real Otzaria
integration and a single shared implementation. The repository's
19 November standing owner authorization permits the necessary source,
configuration, Git and validation actions and supersedes older per-hunk pauses.
The original architecture and source-bound acceptance requirements remain in
force. No policy, exception register or acceptance guard is relaxed.

Canonical SDK pin:
`b66aa5e0e979f36d1a34b85e08899449b72d1dc2`.

## Ownership matrix recorded before implementation

| Path | Ownership and origin | Change | Downstream alternative and rationale | Validation |
|---|---|---|---|---|
| `Maktabah.xcodeproj/project.pbxproj` | Shared integration seam in an upstream-tracked project; existing three Hanlin references are downstream registrations | Replace three package locations with one selected root SDK location; retain all eight product references and their target membership | Package registration cannot be supplied by a Swift adapter; this is the narrow existing dependency seam | Parse before/after project graph; preserve all non-Hanlin objects and product identities; actual Apple gate remains required |
| `Maktabah.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` | Shared integration dependency lock | Advance only streaming Markdown from6bde0228 to canonical Hanlin5cbb4b6c | The actual original Hanlin app and SDK both require5cbb;6bde is10commits older, and the two dependency manifests are identical | Compare exact canonical dependency identity; Apple resolution remains required |
| `Scripts/CI/prepare-hanlin-sdk.py` | Downstream-owned; absent from current upstream; original Hanlin preparation lineage includes e75f88b9/2f5e41f3 | Delegate installation to the immutable canonical installer and verify actual selected original source bytes plus derived profile | Extend the existing preparation entry point, preserving `verify(pin)`, `--sha`, `--output`, and `--verify-only` consumers | Actual installation/source proof, read-only verification, stale/source/profile rejection |
| `HanlinSDK.lock.json` | New downstream input metadata | Record immutable SDK revision and existing eight public products | Keeps one shared SDK implementation and makes dependency selection reviewable | Lock, Gitlink, installed HEAD and generated products must agree |
| `Vendor/HanlinSDK` | Existing canonical upstream Gitlink; never copied modules | Advance to the published SDK source and keep one Gitlink | Retain the original repository provenance and `.gitmodules` URL | Original source blobs, pinned HEAD and selected manifest checks |
| `.gitignore` | Downstream-owned; absent from current upstream | Allow the canonical installer to record its managed checkout location; tracked Gitlink remains tracked | Shared installer behavior is reused unchanged | Git mode160000 and tracked Gitlink verified |
| `Scripts/CI/hq-stage2-focused-apple.inputs.json` | Downstream-owned source-bound CI metadata | Follow code commit with truthful application SHA/tree identities and SDK Gitlink | Existing source gate remains authoritative; do not label an old run as new acceptance | Compare committed source trees and immutable SDK SHA |
| `PROJECT_BOARD.md` and this evidence folder | Downstream memory/evidence | Record the one-package consumer contract and actual verification boundaries | Avoid duplicate app or SDK code | Documentation-only |

## Preserved application boundaries

All files under `Source/`, all original host adapters, native tool ports,
conversation storage, reader behavior, UI compositions, test fixtures and
Swift package product names remain unchanged. The original composer, native
editor, Markdown/OpenUI and tool-activity UI continue to come from their
original canonical SDK sources.

Existing strict original-editor framework source-membership checks remain
unchanged. A prior framework built from different Hanlin sources is not
acceptable for this new pin; any required producer must be regenerated and
qualified against the actual source instead of bypassing its guard.

The three former package roots are canonical definitions inside the same
repository. The host consumes a derived selected root manifest whose source
targets still point to those original definitions.

## Acceptance boundary

Installation and original-source/profile verification are this change's
focused Oracle checks. Apple compile, original host lifecycle/native tests,
visual validation and physical iPad checks are separate gates. No native
dispatch or acceptance is claimed by this record. Unchanged earlier evidence
may be reused only with its exact source/impact qualification.

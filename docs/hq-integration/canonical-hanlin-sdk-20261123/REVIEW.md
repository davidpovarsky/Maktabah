# Canonical Hanlin SDK consumer — 23 November 2026

The actual Maktabah/Otzaria project now selects its existing eight Hanlin
products from one canonical root package at `Vendor/HanlinSDK`. The existing
Gitlink is retained and pinned to published source
`b66aa5e0e979f36d1a34b85e08899449b72d1dc2`. No SDK implementation or UI
component was copied into the host.

## What changed

- Three Xcode package registrations became one selected root package. All
  eight product identities, framework membership and target membership were
  preserved.
- `HanlinSDK.lock.json` records that source and product selection.
- The existing preparation entry point delegates installation to the exact
  canonical installer. Its original CLI and `verify(pin)` entry remain
  available to the existing source-bound Apple workflows.
- Verification checks every materialized original source and the complete
  selected source trees against Git blobs from the immutable SDK revision.
  It separately derives and checks the generated manifest from the verified
  original definitions. Only the two installer-owned generated outputs are
  permitted to differ from their repository versions.
- The existing host lock now uses Hanlin's exact streaming Markdown revision
  `5cbb4b6c950051f98f02a0b0ae56756f5174a9b8`. The prior host revision
  `6bde022876ef4af738c154b3d5c871984ef76195` is ten commits older. Their
  dependency manifests are byte-identical. The other direct SDK dependency
  already matched.

All `Source/` files are unchanged. Native tool ports, the conversation store,
reader and scene ownership, composer, original native editor, Markdown/OpenUI,
tool activity and application navigation continue to use their existing
implementations.

## Focused evidence

| Check | Observed result |
|---|---|
| Actual immutable Gitlink installation | PASS; one canonical source checkout |
| Original source verification | PASS; 571 original Git blobs |
| Selected products | Eight existing products; 13 canonical source directories |
| Installed footprint | 627 files / 27,287,879 bytes outside Git metadata at verification time |
| Unused native runtimes | Zero binary targets; Node, Python, Expo and NativeScript artifact roots absent |
| `--verify-only` compatibility | PASS; proof identical before and after verification |
| Modified original source | Rejected; original bytes restored |
| Modified generated manifest with a matching edited receipt hash | Rejected by regeneration check; original bytes restored |
| Missing selected source hidden by changed sparse checkout | Rejected; original sparse profile restored |
| Xcode registration comparison | All eight product names and all other semantic project objects preserved |
| Source tree | No edits |
| Apple compile, runtime, visual and physical-device acceptance | NOT_RUN by this lane |

See `source-proof.json`, `source-proof-after.json`,
`installation-acceptance.json`, `project-graph-proof.json` and
`selected-dependency-inventory.json`.

The pre-existing project contains five repeated, byte-identical inline object
definitions. The read-only comparison deduplicated identical entries in memory
for parsing both versions, verified that the duplicates were unchanged, and
did not normalize the project file or alter any gate. This comparison is not
an Xcode build claim.

## Existing acceptance routes

The existing `hq-stage2-focused-apple.py` preparation and before/after checks
call the preserved `verify(pin)` contract and compare complete proofs.
The actual prepared profile passes that verification. The SDK's two generated
files intentionally make the Gitlink appear dirty in ordinary Git status;
they are verified individually and their source derivation is checked. No
ignore/skip-worktree flag is used to hide changes.

The separate source-specific `annotation-combined-core194-apple.py` route has
a blanket root-dirty check and is not this selected consumer acceptance route.
It remains unchanged. Likewise, the strict original-editor binary framework
source-membership gate remains unchanged: an older framework cannot be reused
as evidence for this new SDK pin. An appropriate matching producer must pass
before that separate distribution route can be accepted.

Source-bound Apple input metadata is updated in a follow-up commit to name
the actual preceding code commit and its Source/Vendor/project trees. This
does not retroactively relabel an earlier native run.

## Reproduce the prepared source check

```sh
python3 Scripts/CI/prepare-hanlin-sdk.py \
  --sha b66aa5e0e979f36d1a34b85e08899449b72d1dc2 \
  --output build/hanlin-sdk-source.json

python3 Scripts/CI/prepare-hanlin-sdk.py \
  --sha b66aa5e0e979f36d1a34b85e08899449b72d1dc2 \
  --output build/hanlin-sdk-source-after.json --verify-only
```

On a constrained server, add `--source-cache /path/to/existing/hanlin-ai`
during preparation to borrow the existing canonical Git object store.
The initial host lock and Gitlink must already name the same immutable source.

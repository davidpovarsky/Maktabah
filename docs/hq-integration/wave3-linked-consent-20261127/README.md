# Linked receive consent: retained SQLite source

## Scope and source

This is the root-reserved follow-up to Wave1's linked-sync donor
`178bf8e6697df7aa3d2d1b16092f4e35b4ca1462`. It changes four original product
files and adds controls to the existing annotation exchange acceptance target.
No peer worktree, original transport, account implementation, gate, signing
record, schema definition, CAS rule or ACK rule was changed.

| Source | Commit | Meaning |
| --- | --- | --- |
| Reviewed donor | `178bf8e6697df7aa3d2d1b16092f4e35b4ca1462` | Original linked-sync product |
| Failing baseline | `744686e4ad3efbb642e01ddcc9e1eed84dce3bcd` | Donor product plus seven additive consent controls |
| Candidate | `c765dfac3d036a6d7a60fa3c1b7c14ba4eb7ab8c` | Four-file repair, required test API bindings and additive runner |

The candidate source archive contains 79 exact Git-bound files. Its SHA-256 is
`f703090699a9f75a4f5a4d6574bc0537c33a4333015e8cb52daf07526f731f5a`;
the original archive verifier validates manifest SHA-256
`103070069e5488beee94b3d5b6da9880c25d79fd9b813fa753d49d63ee15ebc8`.
The archive is a small exact source transfer, not a replacement Git repository.

## Demonstrated defect

The original receive dialog remembered `keepLinked` but did not retain the
consent identity observed before the native read. Unlinking changes a durable
link row's active flag without advancing the annotation revision. A subsequent
receive could therefore pass the annotation source/revision checks and create
a new active link from a stale Boolean. A new link in the same account, space
and object could also be adopted without observing that new consent.

The baseline ran on the actual Apple compiler and original SQLite connection,
pending queue, exchange ledger and Action Core. All three stale-consent saves
actually **committed**. The captured before/after images show changed original
body/queue/version/exchange table bytes. These are demonstrated component
failures, not timeout failures or a claim that a native UI journey was run.

The relink control deliberately attaches an origin at an already available,
unreceived local version through the actual ledger API. This isolates consent
identity from annotation revision. It does not represent a fabricated native
receipt or an assertion that the native UI can perform that exact sequence.

## Repair

`AnnotationExchangeNativeConsentObservation` retains the complete historical
link set for the original namespace and annotation UUID. Each entry binds its
link UUID, destination/account/space, native object identity and active state.
It deliberately excludes mutable transport root, confirmed revision and
dispatch progress. The original ledger retains inactive rows and creates a
fresh UUID for a new opt-in; it never reactivates an old row. Consequently the
historical set distinguishes absence from absence after an intervening
link/unlink cycle without introducing new schema or migration rules.

| Boundary | Exact behavior |
| --- | --- |
| Persistence `linkedState` | Captures the original snapshot/version, active links, delivery progress and full historical consent inside the same original SQLite transaction. |
| Receive `begin` / `readSelected` | Retains that state, then copies its immutable consent before the original native read and its suspensions. |
| Progress refresh | Compares against the retained consent before accepting refreshed delivery state. It cannot refresh the consent proof. Original source/account checks run again after the new await. |
| Session `saveReceived` | Passes the same immutable proof and the already captured Boolean into the original detached storage worker. |
| Fresh persistence Save | Requires the proof with the native origin and calls the ledger inside the existing outer transaction. |
| Ledger `acceptNativeOrigin` | Compares exact historical consent before incoming/link mutations. A mismatch throws the existing stale-revision error, rolling back the enclosing body, pending queue and immutable-version writes too. |
| Explicit dialog unlink | Validates the original consent, calls the original unlink mutation, and returns its exact post-state before releasing the transaction. Only this owned action advances the dialog's proof. |
| Already committed replay | Uses the unchanged original replay binding and returns its historical receipt without changing link consent, including after a later unlink. |

The production receive methods require the observation; there is no optional
default that bypasses it. The private ordinary-save path permits `nil` only
when there is no native origin. The original test fixture helper has an
optional argument so unchanged old scenarios can obtain an immediate genuine
ledger read; the seven new scenarios pass their previously captured read
explicitly and never recapture it at Save time.

## Controls and observed results

The baseline component run completed at **2026-11-27 05:35:59 UTC**, Sentinel
`job_6bdc57e26f0b`. Compile exit was 0; test executable exit was 1. Its result
was exactly **4 PASS / 3 FAIL**. The supervisory status
`BASELINE_REPRODUCED_3_STALE_CONSENT_FAILURES` means only that the expected
failing baseline was reproduced.

| Additive control | Baseline | Candidate |
| --- | --- | --- |
| Retained active link after another real connection unlinks | FAIL: committed | PASS: rejected |
| Retained identity after same-scope relink at unchanged annotation revision | FAIL: committed | PASS: rejected |
| Retained absence after another connection links then unlinks | FAIL: committed | PASS: rejected |
| Fresh explicit opt-in after an observed unlink creates a new identity | PASS | PASS |
| Same-dialog explicit unlink returns its own atomic post-consent for receive-only | PASS | PASS |
| Committed replay after unlink remains historical without relinking | PASS | PASS |
| Root and dispatch progress do not replace consent identity | PASS | PASS |

**The actual candidate Apple run passed original15/15 and additive7/7**, with
zero failures. Sentinel `job_482b460ef682` completed at
**2026-11-27 05:59:31 UTC**. Compile and both executable exits were 0. Each of
the three stale cases returned the exact stale-revision error; its annotation
revision remained unchanged and its complete before/after database images were
byte-identical. All four exact product files separately parsed for iOS27 with
exit 0. No candidate pass is inferred from that parsing.

The original runner was invoked once with `--linked-sync-only`; its compiled
executable was then reused for `linked-consent-only`. The additive wrapper
enforces a live free-space reserve
of 2 GiB + 256 MiB and only terminates its own process group if that reserve is
violated. It never starts an app, simulator, SDK rebuild or native runtime.

The three app-layer files are not compiled by the small ledger target. The
wrapper records separate exact-file iOS27 frontend parsing; that checks syntax
only and is not an app SDK typecheck. Integrated SDK compilation and actual
Anytype/native journeys remain required on the final source.

## Preservation and audit

The complete original linked15 scenario body remains byte-identical:
23,942 bytes, SHA-256
`c2092fd181d36a8d384f68dc85acfef01ab706e82cdc8de500622b3f79aa6fd9`.
The seven baseline/candidate scenario bodies also remain byte-identical:
7,718 bytes, SHA-256
`8fd9a054ef4413fa5c53ac0143ff9fb154e1dd64619ca22dce74816c25edd9ae`.
The original default-suite bodies, linked schema definitions, original replay
and callback tail and the canonical acceptance driver are preserved.

`validation/BASELINE_PRESERVATION.json` binds all 22 raw baseline files,
1,444,081 bytes, copied Mac→Windows→Oracle and checked against the original Mac
hashes. The ZIP retains the seven actual SQLite fixture databases as well as
all logs and images. Readable JSON/log copies are byte-identical; their
whitespace is not normalized. All 75 baseline source inputs were independently
checked against Git commit `744686e4` after transfer.

Key evidence:

- `validation/baseline-control-attempt-1/RESULT.json`, SHA-256
  `27e7625209be95f40fa840a8ed74085c452b35c890aea49e27d1f34d41ebf110`.
- `validation/baseline-control-attempt-1.zip`, 80,306 bytes, SHA-256
  `f2f0f759a8a3935e82567265f599500d11b576f3e31fe37fc83212ea481048e6`.
- `validation/SOURCE_REVIEW.json`: exact six changed source/test inputs and the
  app-layer capture/transaction review.
- `validation/candidate-control-attempt-1/RESULT.json`, SHA-256
  `2dbe3fd206cf5d634bbea2b8237ac8c5e856b017d302408ea1f46be5fd14b3c1`.
- `validation/candidate-control-attempt-1/original-linked15/RESULT.json`, SHA-256
  `20ace0151c316a5dbb4e7851ff8243b906c2f0a8b4ae451427f19398a73e768f`.
- `validation/candidate-control-attempt-1.tar.gz`, 1,661,960 bytes, SHA-256
  `023bbbf8cb585faa35270c4aa9ea634ab09ac0ed56e6b456fa3403c1847a1b48`:
  all 59 raw result/log/fixture/package-source artifacts and the actual compiled
  test executable. Its manifest binds 9,333,517 uncompressed bytes. The eight
  copied compilation inputs were independently compared with the actual
  source-root files; all 79 wrapper inputs and 75 canonical-driver inputs match
  their source pins before and after execution.
- `validation/run-baseline.py`: exact supervisory baseline driver, SHA-256
  `df6571483512f4f1247be7083cc3577e2523af683f7b7565cb8c08e09215f60f`.
- `Tests/HQ/annotation-exchange/run-linked-consent-controls.py`: additive
  candidate wrapper around the unchanged original acceptance driver.

The historical baseline, failed checks, original source inputs and all
subsequent candidate attempts remain separate. This packet asserts no live
Anytype transport, full app SDK, native UI, CloudKit runtime or physical-device
acceptance and creates no owner attestation.

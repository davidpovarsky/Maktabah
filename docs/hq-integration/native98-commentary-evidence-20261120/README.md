# Original Native98 Commentary evidence extraction

## Purpose and current status

This is an isolated, read-only evidence processor for the **existing** Native98 run `44723902453`, attempt 1, checkout `60a57972acb28739ec738565083bf17fb7503028` and application/test source `87b783ac3f0257e8461762e0ea9dfa5248dd06e8`. It executes no application, simulator, Swift compiler, or Native test. It does not change or rerun that historical source.

The original Commentary case failed in `requireSystemReaderSource`'s TextKit/locator predicate before the call that triggers the Core Commentary action. The current task is to recover the original final hierarchy, screenshot and independent source metadata before deciding whether a source correction is justified. No successful Commentary execution, product defect, or timing cause is inferred here.

Preparation actually executed **40 Python controls, all passing**, plus validation of the retained authentic GitHub metadata and the new workflow's source checksum pins/structure. The first 39-control run is retained; the final run adds a concrete prior-output preservation control and passed 40/40. These are synthetic transport/archive/source controls and metadata checks. The original large archive has **not** been downloaded or hash-verified by this preparation. The evidence-processing CI job is **not activated by this packet**; the integrator owns its single activation after review.

## Exact historical authority

| Field | Required value |
|---|---|
| Repository / ID | `davidpovarsky/Maktabah` / `1280062128` |
| Native run / attempt | `44723902453` / `1` |
| Native checkout | `60a57972acb28739ec738565083bf17fb7503028` |
| Native branch | `codex/otzaria-native98-signature-reviewed-20261120` |
| Capture artifact | `14632274701`, `runtime27-native-captures` |
| Complete ZIP length | `775094118` bytes |
| Advertised, required complete ZIP SHA-256 | `7ce28dc10dbdfb6a52fe15e0eb0ec4bfaef746f8165974d060367cf61594a69d` |
| Original producer job | `136246398292`, `R27 real UI environment and acceptance` |
| Actual run / job conclusions | Both `cancelled`; actor and cause are not inferred |
| Successful capture upload step | Step 17, `Retain original native result bundles and visual captures separately`, 13:37:04–13:40:05 UTC |
| Artifact creation | 2026-11-20T13:40:04Z, inside that successful upload step |

The metadata digest is an expected value, not a claim that this preparation read all 775 MB. The authenticated connector refused the download because `775094118` exceeds its `536870912`-byte limit and returned no downloadable file URI. That refusal is retained. An ordinary GitHub Actions read of the same authorized artifact is the chosen alternative; it uses the repository's read-only Actions permission and does not alter any service limit.

## Exact selection and provenance

Only these three complete original files may be emitted under `entries/`:

| Exact ZIP member | Meaning in the original export |
|---|---|
| `visual-11/34995614-E845-4469-8EBB-AE7E59600FF9.txt` | Final native hierarchy |
| `visual-11/09F8F8D6-7BAF-450B-8077-5500D4413075.png` | Final native screenshot, pixels unchanged |
| `visual-11/A828823B-94E0-42DA-AE05-27BDECC745D9.txt` | Independent reader source metadata |

The member names and case attribution are retained in the original `native-matrix-driver.log` export, lines 3264–3277. The prior selected Windows capture collection observed the `visual-11/` paths; its payloads are currently inaccessible while that host is offline. The exact original workflow at F60 uploads `build/artifacts/**/*.xcresult/**` and `build/artifacts/visual-*/**`, preserving the shared `build/artifacts` relative root. The processor requires the exact paths above and has no basename or alternate-path fallback. A missing path fails extraction.

`raw/SOURCE_EXPORT_LOG.log.gz` preserves the original already-retained matrix log. `EXPORT_MAPPING_PROVENANCE.json` records its complete uncompressed hash and the fully verified **small** evidence artifact `14632383919` from which it came. That smaller archive's verification does not qualify the larger capture archive.

## Processing contract

The new workflow runs only on `codex/otzaria-native98-commentary-evidence-20261120`, with `contents: read` and `actions: read`, an Ubuntu runner and a 20-minute job budget. Its parent must be the known Git commit `e603d8182a1c10c4b37b14c92b5f0bc3829edea8`, tree `5128feff6992aab17b368775e3b5d7ec7e33cc82`. It permits only the four new processor files and this documentation directory to differ from that parent. No existing workflow or product file is changed.

The checkout materializes only the four processor source files, with submodules disabled and no SDK/corpus download. The original `actions/checkout@v4` sparse path uses its existing `blob:none` fetch. The workflow first checks the reviewed driver, test and contract hashes. The processor verifies its exact GitHub repository, event, ref, attempt, workflow ref/SHA, checkout HEAD, single parent, Git source bytes and before/after source hashes. It then validates the original run, artifact, job, successful upload step and creation interval before reading the ZIP, and validates them again afterward. A cancelled historical job is retained as cancelled.

Authorization is sent only to constructed `https://api.github.com/repos/davidpovarsky/Maktabah/actions/...` endpoints. The archive request requires an explicit GitHub 302 response. A new request and a separate no-redirect opener fetch the HTTPS storage URL without Authorization; only GitHub Actions storage host suffixes are admitted. The temporary signed URL and token remain in memory and are never written or printed. Network failures produce fixed codes, not raw exception text.

The complete original ZIP is streamed into a separate runner temporary cache, with exact size and SHA-256 checked. Every member is streamed through CRC verification, including nonselected members. The processor refuses unsafe/duplicate paths, symlinks/special files, encrypted or unsupported entries and excessive expansion. It independently hashes the complete ZIP again after reading all members. Selected bytes are emitted only after that complete integrity pass; they are not transformed, decoded, rotated or interpreted as an oracle.

The small output includes original API metadata before/after, source receipts, complete member verification (CRC and per-member hashes), a selected-file manifest, and `RESULT.json`. Qualification is true only after every step succeeds. Failure still retains bounded diagnostic output and fails the job. Neither the large input ZIP nor the temporary signed download URL is included in the output artifact. The input remains the authenticated original GitHub artifact.

## Verification and activation

Local controls:

```bash
python3 Scripts/CI/test-native98-commentary-evidence.py
```

Retained-packet verification:

```bash
python3 docs/hq-integration/native98-commentary-evidence-20261120/verify.py --root .
```

The integrator should verify the packet's `READY_FILES.json`/`PUBLICATION_REVIEW.json`, create one commit with the exact e603 parent and the reviewed files, and then create the exact owned trigger ref once. This packet has not performed that write. On ambiguous publication, use read-only discovery; do not repeat activation blindly. After completion, check the actual processor run/head/attempt and output artifact metadata, then verify its complete small ZIP and all source/selection receipts before reading the three files.

The historical Native evidence remains authoritative only for its original F60/M87 source. The processing run adds zero Native executions and cannot change a historical failed or unexecuted action into a pass.

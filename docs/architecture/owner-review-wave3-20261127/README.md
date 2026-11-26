# Wave 3: review of two owner signature updates

Status: **PREPARED_FOR_ROOT_REVIEW_NOT_SIGNED**. No private key was read and no new signature was produced during packet preparation. The integration owner reviews the exact script, manifest, source differences and evidence before invoking explicit signing mode. The current user has authorized development and signing; no additional generic user prompt is required.

## Frozen inputs

| Input | Exact identity |
| --- | --- |
| Signing checkout D | 0db0ab78cfde4845bfe3a7e2621ca31d630acd56 |
| Product source S | 22fd689971ebe6506087cd85d740f54d5d9f36e5 |
| Last source with 55 existing verified approvals | 29a731e273f9a757c743c49e182fece0e8047d46 |
| Owner policy baseline | 157729471b649a023a81f923be33fb7bfa6e41c9 |
| Release gate upstream | a0ed0df908a6cb38bc459d4baaeb400f447b2fc4 |
| Reviewed manifest SHA-256 | ed750de696a80d908d7cce2d61a8785075d68d57d8ab5f69aa14679b420a79da |
| New bridge SHA-256 | 9e66c9eebb969cbf31938ee8b84de5a215b4632aa92e3a48872970a891e4790b |
| Superseded-record capture SHA-256 | f24f4c15fbda7aeeac9e67d4a715ef522c928898e8ae2aaf7bf53a0f5b575672 |

The owner policy pinned by the existing release verifier covers necessary protected-file changes under the development task. It still requires provenance, affected behavior, exact differences and release verification. This packet changes no existing release wrapper, canonical signer, verifier, policy, registry or historical signing script.

At handoff, the integration owner reported an additional incoming iOSTOCView.swift change. That later scope is not covered by this packet. Do not invoke this packet's signing mode for a newer candidate; preserve it and prepare a separately reviewed manifest/bridge for the new exact scope.

The bridge refuses any other checkout, manifest, old registry, public-key fingerprint, protected-path set, changed blob or patch digest. If source changes again, prepare and review a new exact packet. Source admission grants no Native116, Release114+2, production or TestFlight acceptance.

## Exact renewal scope

| Existing ID | File | New Git blob | Canonical full-baseline patch SHA-256 |
| --- | --- | --- | --- |
| OWNER_PATCH_017 | Source/Features/Reader/ViewModel/BookTOCViewModel.swift | cefdba7518894946196c7678a8f108e9e3bc19ae | 56ce55811f160d8712d37fa6adcca0cd8ced8c04f3851d13fbb7d8ef49493f84 |
| OWNER_PATCH_040 | Source/Localizable.xcstrings | a60bff78654244052bf0d213c34a90bef502694c | 48372a55dcf21df42ac8cbb0b6f471a034aea1c42bfa728b17704462f027c398 |

All 55 full-baseline patches are included for exact coverage. The original generator sorts paths and assigns new sequential IDs, which would renumber 47 historical records. This manifest explicitly preserves the existing authenticated path-to-ID mapping. Archive filenames 019 and 043 do not change approval IDs 017 and 040.

The existing registry has **55 approved signature records plus five unrelated informational records**. All 53 unchanged signature records and all five informational records must remain identical. The two prior signed records are retained in superseded-owner-records.json with their original registry blob/digest. Git history preserves the complete prior registry.

## Provenance and behavior

SOURCE_REVIEW.json identifies original upstream blobs, deliveries, exact intake equivalence, test receipts and gaps. Both files are original upstream-owned source. The release gate continues using pinned a0ed; the UI lane separately observed current upstream 4203de5fd77beb119e5826e039be1a61325f7be0.

- **Localization:** ten new Hebrew system-intent outcomes; all 671 existing entries remain equal. The downstream adapter adds localization calls while preserving status, code and visible acknowledgement. The original portable noncompletion test passed once on 4a04aeb208fd0e5408a2521f2757e97982bc258c. Its original receipt/log are included. Apple catalog compilation, AppIntentsTesting, Siri, VoiceOver and physical checks are not claimed here.
- **TOC:** one generation owns loading/completion; cancelled requests cannot clear newer state. Navigation caches reset on load/cleanup, native success/failure publishes terminal status, each acquired loader is released. The exact original model/node compiled on Apple Swift 6.4 with strict concurrency. The same 34 cases produced 20 pass/14 fail on 29a and 34 pass/0 fail on bbc68b0d8125a47f8c195653db77a7f771854837. These source-level cases use controlled backend/database boundaries. Full app UI, production database and physical acceptance remain separate. The original initial fixture compilation error is retained.

The smaller changes from 29a are under incremental-review. They supplement the complete canonical baseline patches used for signatures.

## Public checks executed

PUBLIC_PREFLIGHT.json records a real check on D with the public key freshly read from the existing GitHub variable. All 55 historical signatures authenticated; 53 still bind current source; exactly 2 require renewal. No DPAPI import/read or sign mode ran.

CHECKS.json records one positive check and four correct refusals: different public key, manifest byte tamper, patch byte tamper and wrong checkout. INITIAL_PUBLIC_CHECK_REFUSAL.json preserves the first draft's refusal: it incorrectly treated 60 registry entries as 55. The corrected bridge explicitly preserves the five informational entries and never counts them as approvals.

Sign mode and Windows DPAPI execution remain **NOT_RUN**. The final release gate must run after the integration owner reviews and imports authentic signing output.

## Minimal Windows preparation after root review

Use the existing Windows account and GitHub authentication. A partial clone with three sparse files avoids another full checkout. Export the packet separately while the signing checkout remains exactly D. No Mac storage is required. These commands have not been executed.

Replace only the packet-commit placeholder with the reviewed immutable commit.

~~~powershell
$ErrorActionPreference = 'Stop'
$PacketCommit = '<40-hex reviewed packet commit>'
if ($PacketCommit -notmatch '^[0-9a-f]{40}$') { throw 'Freeze reviewed packet commit first' }
$TaskRoot = Join-Path $env:USERPROFILE ('.codex\artifacts\otzaria-wave3-owner-review-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $TaskRoot | Out-Null
$Repo = Join-Path $TaskRoot 'checkout'
$Packet = Join-Path $TaskRoot 'packet'
$Tar = Join-Path $TaskRoot 'packet.tar'
$Candidate = '0db0ab78cfde4845bfe3a7e2621ca31d630acd56'

git -c 'credential.helper=!gh auth git-credential' clone --filter=blob:none --no-checkout --single-branch --branch codex/otzaria-wave3-owner-review-20261127 https://github.com/davidpovarsky/Maktabah.git $Repo
if ($LASTEXITCODE -ne 0) { throw 'Partial clone failed' }
git -C $Repo config core.autocrlf false
if ($LASTEXITCODE -ne 0) { throw 'Local configuration failed' }
git -C $Repo config credential.helper '!gh auth git-credential'
if ($LASTEXITCODE -ne 0) { throw 'Isolated credential-helper configuration failed' }
git -C $Repo sparse-checkout set --no-cone '/tools/sign_owner_approvals.py' '/tools/verify_upstream_boundary.py' '/docs/architecture/UPSTREAM_EXCEPTION_REGISTER.json'
if ($LASTEXITCODE -ne 0) { throw 'Sparse configuration failed' }
git -c 'credential.helper=!gh auth git-credential' -C $Repo checkout --detach $Candidate
if ($LASTEXITCODE -ne 0) { throw 'Frozen checkout failed' }
git -c 'credential.helper=!gh auth git-credential' -C $Repo archive --format=tar --output=$Tar $PacketCommit -- docs/architecture/owner-review-wave3-20261127
if ($LASTEXITCODE -ne 0) { throw 'Packet export failed' }
New-Item -ItemType Directory -Path $Packet | Out-Null
tar -xf $Tar -C $Packet --strip-components 3
if ($LASTEXITCODE -ne 0) { throw 'Packet extraction failed' }

$ExternalKey = (& gh api repos/davidpovarsky/Maktabah/actions/variables/MAKTABAH_OWNER_VERIFICATION_KEY --jq '.value').Trim()
if ($LASTEXITCODE -ne 0) { throw 'Existing external public-key read failed' }
$PublicKeyFile = Join-Path $TaskRoot 'external-public-key.txt'
[IO.File]::WriteAllText($PublicKeyFile, $ExternalKey + [char]10, [Text.Encoding]::ASCII)
Remove-Variable ExternalKey

$DigestCheck = @'
import hashlib, pathlib, sys
root = pathlib.Path(sys.argv[1])
for line in (root / "SHA256SUMS").read_text().splitlines():
    expected, name = line.split("  ", 1)
    path = root / name
    assert path.resolve().is_relative_to(root.resolve()) and path.is_file()
    assert hashlib.sha256(path.read_bytes()).hexdigest() == expected, name
print("Reviewed packet digests verified")
'@
$DigestCheck | python - $Packet
if ($LASTEXITCODE -ne 0) { throw 'Packet digest validation failed' }
python -B (Join-Path $Packet 'sign_wave3_owner_delta.py') check --repo $Repo --manifest (Join-Path $Packet 'manifest.json') --external-public-key-file $PublicKeyFile
if ($LASTEXITCODE -ne 0) { throw 'Public owner preflight refused' }
~~~

The clone may fetch missing blobs for the canonical 55 diffs. Git objects/files remain private to the new task directory. Existing worktrees, global configuration and credentials are not changed.

## Explicit signing after root review

~~~powershell
$SignedOutput = Join-Path $TaskRoot 'signed-output'
python -B (Join-Path $Packet 'sign_wave3_owner_delta.py') sign --repo $Repo --manifest (Join-Path $Packet 'manifest.json') --external-public-key-file $PublicKeyFile --out-dir $SignedOutput
if ($LASTEXITCODE -ne 0) { throw 'Exact owner signing refused' }
~~~

Only sign mode accesses the existing %LOCALAPPDATA%\Maktabah\OwnerVerification\owner-signing.dpapi. It verifies the local/external public identity, decrypts in memory, signs exactly 2 canonical payloads and verifies them immediately. No plaintext private key is written or transferred. Output must be a new directory outside the checkout and is created exclusively.

The output contains the new registry, the two preserved old records, a signing receipt and SHA256SUMS. The integration owner reviews/imports only intended registry/evidence changes in a separate commit, then runs unchanged verify-owner-release-approval.py on the final immutable checkout with the independent GitHub public key. Final source admission, Native116, Release114+2, production/engine/SDK checks and real Apple archive/upload remain required.

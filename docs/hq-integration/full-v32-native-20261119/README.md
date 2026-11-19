# Full v32 original-app installation and relaunch gate

Status: source preflight and 14 synthetic wrapper controls PASS; actual Apple execution has not yet passed.

This isolated mode addresses SEARCH-V32 / INDEX using the existing original
OtzariaPrebuiltSearchAcceptanceRunner and run-otzaria-prebuilt-acceptance.sh.
It is not a substitute for the 75/77 XCTest UI matrix, Zayit installation,
physical iPad acceptance, UI responsiveness, or release approval.

## Exact source and data

- Integrated app source: 65e142827be7c241fbda7ee79635494c8098132c.
  Source, Vendor, the Xcode project and the original UI case selection are unchanged.
- Existing immutable index release: otzaria-search-data-v32-20261010190601-102293b3a63c;
  release ID 419282321, manifest asset ID 661747835.
- Manifest SHA256: 34319ced48e76f22a5ae2df23745a03332160ddab2dd64244a5c917e0ce00a57.
- Canonical official database: v32-20261010190601, release 409213893 / asset 629048655,
  3,821,240,320 bytes, SHA256 2f4dcd72e8bdb1fc5c0516ae9705e57759c017ec2981b49c35115625c3d3f765.
- The real full index contains 7,080,797 documents across 7,876 sources.
  Fourteen original compressed parts total 3,809,352,289 bytes.

## Reused native acceptance

The existing focused Apple driver builds the original complete application with
its pinned SDK, original engines, dependency validation and source manifests.
The full-data preparation uses the official immutable bytes and independently
checks the canonical SQLite book/line counts.

Only one authenticated original part is fetched by the preparation script to
supply the existing 1 MiB partial-resume seed. The actual app downloader fetches
and validates the complete package; the original installer performs its normal
staging, compatibility and promotion. The original test runs exact/fuzzy/advanced
queries plus its Hebrew golden query, terminates the app, and relaunches it.
The wrapper additionally requires the same query identities and a different
actual PID after restart, with no download or indexing on reopen.

The original install/reopen assertions and 600/180-second phase timeouts remain.
The launcher gains only an optional exact simulator UDID. This mode creates a
fresh 11-inch iPad on the installed matching Xcode27 runtime and deletes only
that owned simulator after retaining reports and failure diagnostics. It never
selects an existing simulator or accesses any connected host's user database.

## CI scope

The existing otzaria-search-artifacts workflow has an explicit
native_existing_v32 mode. This mode requires publish_release=false,
repair_manifest_layout=false, the exact existing release tag and an immutable
checkout equal to the workflow commit. The legacy artifact-build job does not
run in this mode. Job permissions are contents:read and actions:read.

Raw reports, build/source provenance, privacy inputs and logs are uploaded on
success or failure. The existing original UI cases are compiled by the shared
build-for-testing path but zero XCTest cases are executed by this separate gate.
No production artifact is republished or relabeled; no corpus is reindexed.

## Local validation boundary

Fourteen explicit synthetic controls verified failure/status, exact artifact and
corpus identity, native resume, no rebuild/download on reopen, actual distinct
PID, result order, all three modes, the real manifest bytes and refusal to fall
back to an existing simulator. These are wrapper unit checks, not native tests.
The original launcher can be reversed to its prior exact source by removing
only the new optional simulator selector and os import. Python AST, workflow
YAML, Git Bash syntax and whitespace checks passed.

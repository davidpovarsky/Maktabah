# Three-cohort output ownership and original read paths

Application source: d6f3ec7a56999ad18f6f0e9d13cc41588849a7a6.
The accepted2180 workflow is preserved under a separate source reference.
Groups driver27cf5dcb and full-v32 collectord75618e4 remain byte-identical.
Library driver13d9c4db is the exact original c581 blob; only its source/tree input pins change.

## Why a CI-only artifact selector is required

The original mini matrix and runtime27 collector use build/artifacts for the
matrix JSON, result-11-reader.xcresult, test logs, verified cases, native logs
and captures. Both retained mini cohorts use their unchanged original
11-reader label. Running them consecutively in a single ordinary directory
would overwrite authentic first-cohort evidence.

The new helper selects four real directories under ignored build/native-cohorts:
shared-build, groups100, library7 and full-v32. The canonical build/artifacts
path is only an owned relative symlink. One exact checkout/run/attempt marker
admits that directory tree. An existing ordinary artifacts directory, another
owner, a foreign link or a symlinked directory component rejects selection.
Only the alias changes; existing data is never moved, merged, removed or replaced.
Each selection has a unique receipt. There is no product or original driver edit.

The helper runs before every cohort's prepare/run/collect, with sequential
workflow steps. The original collector runs before selecting another cohort.
Every cohort upload uses its real physical directory, independently of the alias
and of preceding native failures. The new filesystem controls use clearly
synthetic temporary files and do not manufacture native results.

## Original source read/write map

| Original path | Actual producer/consumer | Handling |
| --- | --- | --- |
| build/hq-stage2/result.json | Original hq build once; all three original collectors read it | Same physical file, outside the switched directory; no copying or fabricated report |
| build/DerivedData/Build/Products | Original one build; all three read exact app/runner/test binaries and xctestrun | Same original binaries; each original collector retains its existing hash/UUID/immutability checks |
| build/artifacts/runtime27/toolchain-selection.json | Original select-runtime27-toolchain --github-env | Retained once in shared-build; actual selected runtime is also exported through existing GITHUB_ENV and each original native report |
| build/artifacts/reader-groups100 | Existing Groups prepare/collect | groups100/artifacts physical directory |
| build/artifacts/library-morph | Unchanged original Library prepare/collect | library7/artifacts physical directory |
| build/artifacts/faithful-ipad-matrix.json and result-11-reader.xcresult | Original matrix independently invoked twice | Each invocation sees its own cohort directory and creates its own fresh owned Simulator |
| build/artifacts/runtime27/hid-tools.json | Original Library HID preparation and matrix | Same Library cohort; Groups keeps its existing no-HID selection |
| build/artifacts/production-native-fixture-install.json | Original production installer and full-v32 collector | full-v32/artifacts; absent-before-install guard and exact asset/database/UDID checks unchanged |
| build/artifacts/reader-full-v32-ui-observation | Existing full-v32 source/trace/observation/result collector | full-v32/artifacts; original output guards permit the owned alias, and actual database/container ownership guards remain unchanged |

Full-v32 source input symlink rejection applies to tracked execution inputs,
not generated output directories. Its immutable database/app-container paths
remain independently resolved and validated. No corpus is copied to Oracle.

## Runtime and source boundaries

Three actual source-admission steps retain their independent records, followed
by the one original build. Each native step requires that build and its own
source admission; no native step depends on another cohort's native PASS.
Mini collectors and full-v32 cleanup preserve failures. All artifact uploads
use always(), with shared build evidence uploaded once.

The administrative job ceiling changes from210 to330 minutes to accommodate
the seven additional leaves. Every existing600-second case deadline, original
matrix/installer command timeout, zero-skip requirement and case assertion
remains unchanged. Exactly1+7+2 leaves are selected; no passed Reader leaves,
full Native116, Release114 or physical-device acceptance is replayed or claimed.

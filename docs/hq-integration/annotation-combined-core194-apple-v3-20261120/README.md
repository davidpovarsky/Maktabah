# Core194, Annotation, Cloud and full-app combined Apple route v3

This is one new isolated validation child of source M **bd855c02fcef94a732f584c5992aeacec6b1b21d**, tree **3c08a3de2102dd80df64f79dd56035a689d26edb**. It does not change the application, Core, UI tests, vendor or project trees. The only correction to execution is complete observation of the original Core source inventory before any component starts.

## Concrete previous failures

The original v1 run [44821378113](https://github.com/davidpovarsky/Maktabah/actions/runs/44821378113) ran 40 Python route controls on macOS: 39 passed and one failed because the test used a case-insensitive filesystem alias when checking a differently capitalized receipt filename. Its original full-app job later succeeded at 22:07:44 UTC; the combined run remained failed. The exact v1 evidence is retained in [the v2 preparation packet](https://github.com/davidpovarsky/Maktabah/tree/52585e91a591c35f7e3e62a495fedb02def2f7de/docs/hq-integration/annotation-combined-core194-apple-v2-20261120).

The v2 run [44824168387](https://github.com/davidpovarsky/Maktabah/actions/runs/44824168387) actually passed Core194 (194 passed, zero failures/skips) and retained the original baseline20 result (11 passed, 9 failed as required). Its component postgate then failed with KeyError for Source/Otzaria/Actions/Integration/ActionAppIdentityBridge.swift. The route had pinned 49 of the 54 actual files under the unchanged Core tree; the original Cloud source-observation helper also consumed the three original Integration Swift files. No product edit caused that missing-record failure. Its original full-app job later succeeded at 22:31:45 UTC; aggregate failed at 22:32:03 UTC.

The v2 component artifact is 14674435032, 5,847,910 bytes, SHA256 fc1be8fcce3fbe2bdd4ecdcc5a7c9230ae1470678cc8868482cbb13eec9efc31. Root authenticated the whole archive and all 12 CRC members before the local runtime outage. The additional raw-source replay was not completed. Full-app/aggregate artifact metadata is retained in PRIOR_RUNS.json; those newly terminal archives have not been independently opened locally. Neither historical full-app success qualifies this new F.

## Exact source correction

All 54 original Core files now have committed Git/blob/byte/SHA256 pins; five unchanged files were added to the binding. An early guard compares that whole inventory to the committed Core tree before executing the original gates. Original baseline20, candidate194, local43, Cloud48 doubles, cold2, exchange28 plus two crash/reopen cases, original repository RED and ten GREEN races, and full-app compile requirements remain unchanged. These are local/service boundary tests, not live CloudKit/account or Native UI qualification.

The combined driver changes exactly three branch/workflow/document identities plus the early inventory helper and its call. All 13 original result-validator bodies are unchanged. The original Core driver changes only branch/workflow metadata; its support pin and the workflow CLI's expected manifest SHA are updated accordingly. The complete immutable source edit review is retained in ROOT_REVIEW.json.

The forty existing Python tests are byte-for-byte identical after removing only the added block. Two new controls cover the complete54 inventory and the actual v2 omission/changed-record failure. There are 42 direct class method declarations. During preparation, a first insertion placed those methods outside the class, and a first workflow retained the old Core-manifest CLI hash. Both mistakes were caught and corrected before any commit/ref/CI activation; rejected blobs and exact findings are retained in ROOT_REVIEW.json.

## Actual execution required

New local Python, Swift and Native execution is **NOT_RUN**: the local runtime is unavailable. Root and the independent peer performed source/byte/hash/tree inspections through GitHub APIs and JavaScript memory. The actual macOS route must run the 42 controls and all unchanged component gates, while a separate job must compile the original full application. Aggregate requires both jobs from the same run, attempt and F, and rechecks the original raw/source/result boundaries.

The push branch is codex/otzaria-annotation-core194-combined-apple-v3-20261120. Workflow .github/workflows/otzaria-annotation-core194-combined-apple-v3.yml retains the original 130-minute component, 100-minute full-app and 15-minute aggregate budgets, original individual commands and raw-artifact retention. No rerun, cancellation, forced ref or integration merge is part of this route. Final Native116/Release114 and release acceptance remain separate and unqualified.

ARTIFACTS.json indexes the exact 18 operational/reference files and these preparation documents. It omits itself to avoid a circular hash. The actual F/tree/activation and outcome will be recorded in the relevant Asana tasks after canonical readback.

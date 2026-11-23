# Normal iOS builds follow the canonical SDK lock

The normal ios-build.yml workflow still duplicated immutable SDK e00498e33f106cc43be0476ffa2e09329c8ca300 in its global environment, while the actual host lock and Gitlink are d49a4fd4115b8335105d2991bf74ab4d7f6aad2d. Each of its three preparation steps therefore rejected the current SDK before installation and would require another workflow edit on every future SDK update.

The three original preparation blocks now read HanlinSDK.lock.json, compare that exact revision with HEAD:Vendor/HanlinSDK, and pass it to the original unchanged prepare-hanlin-sdk.py. The bootstrap executes the canonical installer from that requested immutable revision. No original source, runtime, renderer, model, native SDK pin or generated profile is changed.

## Bounded verification

The two affected original workflow-policy methods passed (2 tests,0 failures,0 errors,0.271s). All three complete preparation blocks are identical. Their actual lock-reader and Gitlink shell check were executed once in the real host checkout and passed against d49. The tests preserve permissions, concurrency, all other steps, conditions, timeouts and the exact original bootstrap/receipt path.

The existing all-other-steps policy had a separate stale baseline: even its unmodified test and unmodified a65 workflow failed three subcases because later original Sefaria55 and embedded-native gates were absent from the older2f74 baseline. That pre-existing failure was reproduced and retained. The contract now binds the exact prechange a65cdf9add70586af4defc916d4817040b331137 workflow, keeping those newer gates, and normalizes only the explicitly checked lock-reader/variable change. No broad step omission or validation bypass was introduced. An independent source review found no blocker; it did not repeat tests.

## Native evidence boundary

The four application trees, canonical SDK pin, selected profile, original UI body and Host48 inputs are unchanged. The successful app/Host48/native UI evidence remains run45125110974 at its exact a65 source, not a newly executed result at this workflow commit. The changed regular workflow and its policy test are source/CI inputs, not native application implementation. No Apple compile, native test or SDK installation was repeated for this correction.

Publication uses the standard [skip ci] commit instruction to avoid repeating the already passed push-triggered focused48+1 native gate for this unrelated normal-workflow/control-only edit. The normal workflow itself remains manually dispatched; none of its native or source gates is disabled.

## Retained receipts

- verification.json: SHA25650f740cbb603fa59df8630a0e08d06212dd06d626c8924a6fffd2589f41566b4.
- original-policy-baseline-failure.json: SHA25623bb0fa8f5fe486f9e0f2bd91da00ddbe6c394c348f89a94f17092b91ca093e6.
- Oracle build/canonical-sdk-update-workflow-20261123/verification.log: SHA256b5a0e0c94b39c61d00598b798228327b3fb04512d117b7892b907d629c4aa6d9.
- The original before/after workflow and test file bytes remain in Git history; the receipt lists their exact new SHA256 and all four original application tree IDs.

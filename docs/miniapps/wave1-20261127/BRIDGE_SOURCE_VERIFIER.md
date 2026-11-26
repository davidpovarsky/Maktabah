# Original MiniApps producer and consumer source verification

The standalone HanlinMiniApps product and the shared Hanlin SDK linked by Maktabah have distinct source roles. The native consumer runner formerly required the two monorepo commits to match, rejecting the actual accepted pairing even when the entire bridge transport remained identical.

The existing original_editor_hanlin_equivalence.py now owns a narrow MiniApps compatibility admission. Its original binary SDK admission and byte-identical shared package checks remain unchanged. The native runner keeps the exact producer manifest, prepared-source inventory, archive, executable and signature checks.

## Inputs

otzaria-miniapps-native.inputs.json retains producer_source_sha, and may explicitly supply consumer_sdk_source_sha plus miniapps_source_equivalence: {path, sha256}. The consumer field must equal both the native build's hanlin_gitlink and the application's committed Vendor/HanlinSDK gitlink. Distinct revisions without the committed review fail admission.

The checked-in Scripts/CI/miniapps-source-equivalence-9565-7ee.json records the exact original producer 9565 and picker-only consumer 7ee. It is a reviewed source receipt, not the final capability-profile SDK pin. Generate and commit a new exact receipt with build_miniapps_review(sdk_path, producer_sha, final_consumer_sha) after the final shared SDK commit is selected. Then set its exact SHA256 in the committed native-runner inputs. Legacy native-runner inputs have intentionally not been repinned to an unvalidated SDK.

## Source checks

The complete package inventory contains 16 files on both sides, including manifests, resources, tests and original verification files. Each receipt records Git tree IDs, Git blobs, byte counts and SHA256 hashes. The entire HanlinMiniAppsBridge transport tree must be byte-identical. File additions, deletions, renames and executable mode changes are rejected. The only allowed picker difference is the exact original row insertion .contentShape(Rectangle()); another picker behavior change is rejected.

Preparation reads only the immutable committed receipt. After the standard shared SDK preparation, producer restoration validates the actual host checkout and all working package files against that receipt. Collection repeats that check and compares it to the pre-run proof. These source checks grant no native runtime or physical-device acceptance.

## Validation

python3 Scripts/CI/test_original_editor_hanlin_equivalence.py -v passed 13 source-integrity tests. Negative controls cover missing review, incomplete inventory, an uncommitted review with an updated digest, working-source mutation, extra source membership, transport changes, other picker behavior, source modes, checkout mismatch and swapped target roles. The original binary SDK identity guard also remains covered.

The real Git objects for producer 9565 and consumer 7ee independently passed build_miniapps_review: all 16 files are included; only MiniAppPicker.swift differs by the recorded one-line insertion. Python syntax and git diff --check passed. New native compilation and runtime acceptance remain pending on the final integrated candidate.

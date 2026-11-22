# Original fresh-read keyboard continuation: source admission

This packet preserves the bounded XCTest correction justified by actual Native failure [45006363282](https://github.com/davidpovarsky/Maktabah/actions/runs/45006363282). The first failure was independently verified and published at `ae9f63b17b6f9df91d2d125700dc8b62d2aa2cc4` in `../hanlin-fresh-read-terminal`; its 83-payload packet and both original archive hashes remain unchanged.

## Exact change

Application/test source `d49cedb3d5c163b7a008248d94b80a2eda28e3ce` adds 12 lines only to the existing original `testOriginalIPadFreshCurrentWorkReadConnectionWithoutSending` case. Immediately after actual dummy-key typing it requires the real keyboard and exactly one button with the observed AX label `Hide keyboard`, captures the actual state, performs the existing strict native tap, and waits at most 10 seconds for keyboard disappearance. It captures the state after that wait even before asserting its outcome. It then continues every original native consent, Connect, reopen, revoke, empty composer, close and same-reader assertion unchanged.

The reviewed initial proposal used identifier matching. Root required explicit label matching because the actual AX showed a label. Both proposals and the exact one-line correction are retained. Removing only the 12 added lines recovers the previous full XCTest file bytes.

There are no product edits, coordinate taps, value injection, private Live inputs, real provider credentials, Send action, saved-history shortcut or weaker assertions. The same one-case selection is preserved; previously passing Native cases remain absent.

The actual AX had a focused secure field and a keyboard window whose frame contained the native switch. The final screenshot 0.410 seconds later did not visibly display that keyboard. This discrepancy is retained, and no pixel-based proof of occlusion or successful dismissal is claimed before actual execution.

## Actual local verification

One full-file Windows Swift 6.3.3 syntax parse passed on candidate `9413eed5741bf3fec8b6c97da86ecb6caed026c7f9e85d80219beb57d037b0a7` in 0.703 seconds. This is syntax evidence; no Apple module typechecking or simulator runtime is inferred.

The existing source-only admission ran once on `aec8162c34598c859c9dc61b6e8b298b5d5d36e6`:

- Focused preparation: exit 0, 29.031 seconds, exactly one declaration and 279 actual execution inputs.
- Ordinary HQ `--preflight-only`: exit 0, 6.469 seconds.
- Original Host48 reuse: exit 0, 12.031 seconds, exact prior input binding and zero tests executed.

Source admission result SHA256: `dd412e45fc7f2ad77ba6131cd402acd3f1139ec189ebc749b2bfc88b95dd7877`.

Source, Vendor and project trees remain `91c1adf6c97cd8676e8b2c76860a40f78924b1ec`, `4065c0e62af325e83a65fe0c70270985229807ae` and `8c0fa1ccfbcfae01fae3c267512864e00efcf078`. Only the original UI-test tree changes to `86f07db3f58fe6d73c063b02ae3c1d31ae2d2468`.

The metadata commit changes only the focused SOURCE pin, ordinary HQ application-source pin and the dedicated workflow push branch `codex/otzaria-hanlin-fresh-read-keyboard-native-20261122`. The original build, source audit, binary recording, one-case execution, collectors, cleanup, capture retention and cache mechanics remain unchanged. Native116/Release114 manifests are not rewritten.

## Publication and limits

This documentation child preserves the exact admitted execution inputs; it does not require replaying the source commands. The eventual CI checkout must be bound to its actual immutable final head. At this publication no trigger branch was pushed, no Apple build or Native case was executed, and no Live secret was created.

The separate first-failure publication preserved a real raw-PBX-diff whitespace check failure and corrected only packet-local attributes, without rewriting evidence or rerunning tests. All original failure and admission outputs remain available. Nothing here establishes a pass for the separate Live8 post-configuration missing revoke control, full Native/Release, or original-editor StageB.

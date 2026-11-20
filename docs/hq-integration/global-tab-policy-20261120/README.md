# Global tab bar policy ownership

The one production change moves the existing Reader tab-bar visibility policy to the five direct global-tab content boundaries in `Source/UI/iOS/Views/iPadLayout.swift`, from exact application source `8ff4e820970e6697eabff40ac46e2f6e61484f27`. The original expression remains: the selected Reader uses its observed chrome visibility; another global tab requests `.automatic`. With the existing feature flag off, the modifier supplies no visibility preference. The feature flag alone controls the structural branch; selecting tabs changes the enum value without replacing a tab's content.

The prior policy was published only by the Reader subtree. Publishing the same policy from the active global contents is a source ownership correction. It preserves original tab selection, navigation stacks, nested sidebar pager, Reader models, state observations, controls, padding and safe areas. Apple documents that toolbar visibility preferences flow upward to the nearest container that renders a bar; this candidate attaches at each direct tab's content rather than outside `TabView`: https://developer.apple.com/documentation/swiftui/view/toolbarvisibility(_:for:).

## Actual evidence and limits

Original Release run [44723918854](https://github.com/davidpovarsky/Maktabah/actions/runs/44723918854) remains failed on F60/M87. Both original iPad 11 GlobalSearch navigation cases measured candidate navigation minY 86 versus original 106 with the original one-point tolerance. Their authenticated historical AX/screens are already retained in the [capture result packet](../release96-capture-result-44783201113-20261120/README.md), integrated by Root's evidence-only f3 checkpoint. No capture archive is duplicated here.

Those captures do not expose the effective SwiftUI preference or safe-area controller state. They therefore do not prove that this source defect caused the 20-point displacement. Root reviewed the complete source delta and found no source blocker. **Swift parse, Apple typecheck and Native execution of this candidate are NOT_RUN.** Existing failed evidence stays failed. The active Focused4 source is immutable and does not contain this later change.

## Exact next-run coverage

| Original case | Native116 | Release114 | Focused4 |
| --- | --- | --- | --- |
| `FaithfulReaderUIAcceptanceTests/testCandidateGlobalSearchLandscapeMatchesOriginalNavigation` | Not selected | `ipad11-native` and `ipad13-native` | Not selected |
| `FaithfulReaderUIAcceptanceTests/testCandidateGlobalSearchPortraitMatchesOriginalNavigation` | Not selected | `ipad11-native` and `ipad13-native` | Not selected |

The final Release114 freeze must retain all four selections on the new app source. Native116 does not substitute for these exact geometry checks. Original Reader collapse/restore, twenty global-tab round trips, and Annotations landscape/portrait regressions remain in Release114, as listed in `SELECTION_CROSSWALK.json`. No declaration, selection, assertion or deadline is edited by this packet.

## Integrity

`PROPOSED.patch` contains the entire single-file delta. `EXACT_EDIT.json` reverses it to the retained canonical Git bytes; `SOURCE_AUTHORITY.json` binds the original source and unchanged selection inputs to M8ff. The read-only verifier checks packet hashes, the whole-file inverse and the exact selection crosswalk. It does not claim Swift compilation or UI execution:

```sh
python3 docs/hq-integration/global-tab-policy-20261120/verify_packet.py --root .
```

Root owns publication, integration, final pins and actual Apple/Native activation.

# Native Search field component

The existing scene-owned UISearchTextField is registered as native.search.query under the original native.search destination. Public-v2 links and the original OpenNativeDestinationIntent use the same registry, original Core admission/commit fence, and exact native receipt. Root entity identifiers are unchanged.

The component is available only while the original Search screen and field are already visible in the exact foreground, key UIKit window. Open the Search root first, then focus its component. An absent, detached, replaced, foreign, covered or disabled field is not accepted. There is no queued focus effect or permission bypass.

The optional component focus observation is read from the retained original control's actual isFirstResponder state. Root navigation does not request/report this optional keyboard facet and remains unchanged. A late UIKit state change or replacement prevents completion. The field's query, marked input, history and source engine are not mutated by the focus action.

## Verification

- Seven actual shared observer tests passed; the new negative case cannot acknowledge an unfocused Search surface.
- Fourteen combined observer and NativeIntentService tests passed, zero Swift compiler warnings. Root/component IDs stay distinct; a cached component cannot reuse the root's availability after it disappears.
- These are portable package contracts with explicit native-projection/catalog/navigation fixtures. They do not compile UIKit or execute AppIntents.framework.
- Five actual Native UI cases were added: successful same-field input without another tap on iPad and iPhone; unknown and unavailable component refusal; and Apple's original out-of-process App Intent invocation.
- Native status is NOT_RUN for this change. The original 65 selected cases and all 27 required phase-1 cases are retained.
- A separate NativeFocusReceipt contains only the original canonical request/scene and fixed component ID. Existing native receipt fields/oracles are untouched; no private input is logged.

The complete original raw portable logs and receipts remain in the canonical continuation evidence folder. Committed log copies only normalize trailing whitespace.

## Synchronous ownership fence before publishing

Review of the initial local component commit2507cc2d found that the scene-directory revision was deferred with the SwiftUI graph update. The final implementation invalidates that original revision synchronously on attachment, detach, replacement/ABA and native callbacks. Only rendering notification is deferred. This uses the existing native directory and original Core precommit/completion checks.

The same nine ownership race controls gave 3PASS/6FAIL on2507cc2d and 9PASS on the correction. They execute the exact four original app methods and real Swift MainActor scheduling with explicit UIKit/presentation/directory-revision doubles. They do not execute real UIKit or Core grants. The initial two evidence runs are retained; one foreign-callback assertion was made independent of the preceding ABA control before running the corrected identical oracle on both versions.

Another24 existing original native-directory/Core-prepared package tests passed, including ABA during an await, owner replacement and final completion guards. No existing oracle was weakened. The five new real iPad/iPhone/system cases remain pending.

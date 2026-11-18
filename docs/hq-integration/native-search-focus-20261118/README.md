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

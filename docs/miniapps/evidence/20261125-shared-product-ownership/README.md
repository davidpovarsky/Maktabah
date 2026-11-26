# Original shared-product target ownership

The original full app preparation at control aa8e2599 stopped before the app compiler with `Shared product is owned by another target`. The actual generated Xcode project shares its ZIPFoundation product object between the iOS application and its original Maktabah and Maktabah-Direct macOS targets.

The bounded adapter now removes only the iOS package dependency and link for that shared object. Both original macOS target memberships, their links, the shared product object, and every other unrelated PBX object remain unchanged. All other products still require exclusive original iOS ownership. Unknown owners/referrers and ambiguous links are rejected.

The original Ruby adapter was executed against an isolated APFS copy of the actual generated project and its eight original Pods. Its receipt verifies exact whole-project inversion and 143 compiled Pod source members. The real source project and Pod inputs were unchanged. The read-only ownership test against the actual project passed and all eight altered ownership cases were rejected.

This evidence grants no application compiler, native editor, cross-app, UI, signing, or TestFlight credit. The original full app pipeline must execute with the committed adapter before those outcomes can be reported.

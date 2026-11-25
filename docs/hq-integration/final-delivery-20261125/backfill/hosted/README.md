# Genuine hosted native batch acceptance

This is a separate SDK/native acceptance target, hosted by the existing Maktabah-iOS application. Its TEST_HOST is the actual Maktabah.app executable; the app bundle identifier, App Group, Journal checks and production factories remain unchanged.

The existing macOS MaktabahTests target is not suitable for this iOS Journal contract. The existing Maktabah-iOSUITests target runs in an external test runner process. The new Maktabah-iOSNativeTests target loads inside the real app and can call its existing lifetime bridge through @testable import Maktabah.

The dedicated shared scheme has a single nonparallel hosted test target. It does not add cases to Native116, Release114+2 or the normal UI schemes. The actual Settings conversion and normal editor remain separate UI gates.

## Dependencies and actual execution

The Podfile nested target uses inherit! :search_paths, so the original Host remains the owner of its Pods. A test-only import projection, original-editor-hosted-tests.py, reads the exact already admitted Debug simulator route and original app projection receipt, then changes only five import settings in the new test configuration. All app objects, loader identity, linker inputs and ownership gates remain unchanged. It links the same original framework and embeds no extra SDK product.

Use an owned prepared checkout after SDK qualification and original Pod/app preparation. Run the projection with the exact admitted route path and SHA, build and execute the new scheme using the real Mac, preserve raw xcresult and runtime receipts, then restore the byte-exact generated project through the same script before another app acceptance route. A changed project causes restore to refuse rather than overwrite work.

A source or project-parse result is not runtime acceptance. Actual native no-mount conversion, 5,000 notes, private batch ownership, exact full text, cancellation/retirement, cold reopen and resource measurements remain open until the new XCTest source is merged and the real tests finish. This does not prove ordinary UI, cross-device delivery or physical iPad performance.

## Source validation evidence

Apple plutil parsed the real project graph: eleven new target objects, three existing metadata containers expanded, 2,402 other existing objects unchanged. Ruby accepted the Podfile and Python parsed the helper. Existing app targets and ordinary schemes are unchanged.

Independent review found that the first regex did not allow the baseConfigurationReference line inserted by the original CocoaPods serializer. The corrected helper preserves those metadata lines. A read-only control on the actual preserved CocoaPods project verified the match, one-setting fixture projection, exact inverse, rejection of the old faulty pattern/wrong target/cross-object match, and unchanged actual project. These are layout controls, not SDK execution.

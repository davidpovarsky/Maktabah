# Native search repairs from original failed run

Status: source repaired; 8 Swift files parsed by the real Swift 6.3.3 frontend. This is not Apple typechecking and no Native case has run for this candidate yet. The previous 65 PASS / 13 FAIL result remains unchanged.

## Evidence and changes

Original run: https://github.com/davidpovarsky/Maktabah/actions/runs/44633736259 . The original evidence and selected captures are preserved in ../native78-run44633736259-20261120 . Native88 run44657116407 uses an older source and cannot accept these repairs.

1. The heading's visual text occupied x371.5...494, while its identifier addressed a synthesized static-text AX element spanning x0...834. The actual Search controls occupied x16...498. Use one real native UILabel as the original heading, with system dynamic headline font, dynamic label color, native header/static-text traits, and proposal-bounded intrinsic size. No manual screen coordinates or accessibilityFrame override. Keep the strict actual bounds assertions and entire unfiltered system accessibility audit unchanged.
2. Tapping the original fourth Near mode removed the entire book-search controls overlay: the original complete AX contains neither the segmented control nor a distance TextField. The original controls depended on search-field focus. Keep those same controls in the existing book-search bottom safe-area inset for the presented search view's lifetime, reserving result-list space. Global history remains excluded. Add a passive stable identifier to the original distance TextField; require its value, hittability, all four modes, Help, and absence of persisted global queries in the Native test.
3. The preserved original tab UUID was x228...307.5, outside the native strip viewport x340...534. Keep the original newTab, distinct UUID, content/highlight, receipt and preserved-tab oracles; perform at most eight real strip gestures to reveal a geometrically offscreen original tab, then retain the strict UUID/hittability tap and original-locator check. A visible but occluded tab still fails. Give the original collection view a passive identifier and clear a reused placeholder label's old tab identifier.

No search engine, database, query semantics, data installer, public routing guards, or SDK changed. No direct model navigation, synthetic result, accessibility-audit exclusion, or UI test launch bypass was introduced.

## Apple API references

- https://developer.apple.com/documentation/swiftui/uiviewrepresentable/sizethatfits(_:uiview:context:)
- https://developer.apple.com/documentation/uikit/uilabel
- https://developer.apple.com/documentation/uikit/uicontentsizecategoryadjusting/adjustsfontforcontentsizecategory
- https://developer.apple.com/documentation/uikit/uiaccessibilitytraits

Next acceptance is original app/XCTest build plus actual Native cases at the exact new source. Source parse is not that acceptance.

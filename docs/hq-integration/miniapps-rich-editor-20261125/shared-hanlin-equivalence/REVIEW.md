# Exact shared Hanlin source equivalence

The original Debug editor framework keeps its qualified Hanlin producer revision 6f525c67f5f62587e46085da56e6a8c2a406cee4. The final original consumer and standalone MiniApps use 08ef8741ff58241a081c908536a3b4d3917cc0e8. All three complete SDK package trees are identical; the original Bridge package and its Bridge/Picker module trees are pinned separately to the actual standalone source. The verifier does not relabel compiled SDK provenance or grant native UI credit.

The opt-in review must be committed and SHA-256 pinned. Both actual Git identities, host gitlink, every package Git blob, complete on-disk four-package membership, existing SDK ownership SHA-256 map, and additional Bridge/Picker file bytes are verified. The original three-package same-revision route stays strict. Existing dependency, CocoaPods, Clang, implementation ownership and binary gates are unchanged.

Twenty real temporary-Git controls passed: mutations, missing/additional source, uncommitted review, mismatched trees/revisions, symlinks, and unchanged host-index checks. This is source-admission evidence only, with no Apple build or native consumer test execution.

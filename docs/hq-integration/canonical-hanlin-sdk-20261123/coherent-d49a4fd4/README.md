# Maktabah coherent Hanlin SDK consumer

The existing native SwiftUI host now resolves the canonical Hanlin SDK at `d49a4fd4115b8335105d2991bf74ab4d7f6aad2d`. The eight selected public products use the shared installer and immutable Git source verification. There are no selected native binary targets and no host-local implementation copies.

## Observed evidence

- The shared installer and its subsequent check both exited 0 on 2026-11-23.
- The original `prepare-hanlin-sdk.py --verify-only` gate passed against the staged Gitlink and lock: 577 original files, 13 source directories, eight products, zero binary targets. Full per-file Git blob evidence is in `source-proof.json`.
- Previous actual Apple run `45111458365` at `2393e9f31dcd7ad79bbd451036bfec3fabad4008` failed compiling the host Composer call. The only compiler errors reported an obsolete initializer.
- Host commit `b676c24cedf54c9a1bd6415758459d7f7273b392` uses the existing canonical Composer height contract and native editor measurement; it does not add an SDK compatibility fork or change the original view layout. Its Swift parse and diff checks passed.

## Native acceptance boundary

The install and source checks are not an Apple build or UI result. The next native gate must bind this exact application source tree and SDK pin. The existing original live-provider acceptance workflow can build the real app and UI runner once, then exercise its single original provider/tool/source-navigation/read-consent selector. Its immutable source comparisons, fixture ownership, credential isolation, cleanup and bounded evidence checks remain required. No live result is claimed in this commit. Existing frozen engine/framework/resource inputs remain unchanged.

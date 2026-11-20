# Isolated occurrence-bridge engine pin

This branch builds the original engine plus the reviewed additive occurrence
primitive and test hygiene from the owner-controlled fork. It is not merged into
the active application candidate.

Exact build source: d5d59d1269bdf87fb0a6901cf31941726a0c699b
Repository: https://github.com/davidpovarsky/otzaria_search_engine
Branch: codex/otzaria-exact-occurrences-20261120
Original upstream base: 265a14ea54f959a3e266d6e8acfa3a3b98101d68

The checkout is a real clone with a clean detached HEAD at that exact source,
and the original base is an ancestor. The build pin and manifest now report the
actual d5 source; no fork build is misreported as the older 265 source.
Repository/branch constants in the existing sync/materialize/build scripts point
to that explicit fork. Their pristine-source checks, exact SHA checks and
branch-ancestry checks are retained. No patch application or dirty-check bypass
is introduced. Cargo manifests, schema version4, generation order5, semantic
revision and dictionary/resource bytes remain unchanged.

Existing application index and managed-artifact equality checks are unchanged.
Consequently the old prebuilt v32 engine identity is not automatically accepted
under this new build source. A reviewed artifact/integration path is required
before merging this branch into the active app. Nothing in these provenance
changes migrates, rewrites, repairs or opens any user's database/index.

The bridge component tests may compile only after these truthful pin inputs
are present. Apple XCFramework, application/Core capability exposure and Native
acceptance remain separate gates.

The original C build-info repository and branch literals also now come from the
validated pinned manifest. The build exports the exact original-base commit for
the additive occurrence proof. No d5 build is labelled Otzaria/refactor.

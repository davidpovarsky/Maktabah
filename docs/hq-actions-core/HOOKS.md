# G1 ownership / integration audit

Base `07d1cafa6c6bc27aaf299aa826d28a4c02090cb5`; independent UUID `01a1dc89-87bb-7521-b249-ed383392e940`.

All files are new DOWNSTREAM_OWNED files under the explicit G1 lease:

| Paths | Necessity / alternative | Validation | Rollback |
|---|---|---|---|
| `Source/Otzaria/Actions/Package.swift`, `.gitignore`, `README.md` | Independent dependency-free testable module; avoid changing app/targets/original code | Focused SwiftPM Swift6 strict concurrency | Revert G1 commits |
| `Sources/OtzariaActionCore/Contracts/**` | Single typed wire / strict raw ingress; existing app persistence shapes remain unchanged | Frozen examples, exact integers, duplicates, limits, kind/value | Revert scoped new files |
| `Registry/**`, `Resources/**` | One versioned29-descriptor catalog, five implemented IDs | Resource SHA/bytes and catalog/example projections | Revert scoped new files |
| `Policy/**`, `Engine/**`, `Ports/**` | Trusted context, one actor, injected backend/resolver/search/UI; no duplicate provider implementation | Actual executor with controlled fake ports, stale/cancel/deadline/rights/output/ACK tests | Revert scoped new files |
| `Tests/OtzariaActionCoreTests/{Contracts,Engine,Ports}/**`, `docs/hq-actions-core/**` | Reproducible scoped evidence; tests excluded from app | SwiftPM + manual path review | Revert this lane's additions |

No original Maktabah/upstream source hunk or app hook is required. No app/project/source registration, Xcode dependency, workflow, lockfile, production database/index or existing Reader patch is changed. Reserved Resolver/** and Integration/** remain outside P ownership. App framework verification, provider integration, real UI and physical device acceptance remain separate. Manual ownership review only; no automated boundary guard is claimed.

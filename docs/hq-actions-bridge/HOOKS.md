# Additive Embedded search response evidence

[נועם | DEV] [MAIN_SESSION], 2026-11-15.
Base: 3d6f90c90403a18e780ca37504da1c71285b219e; original app07d1cafa.
Original Maktabah upstream pin: d46af139b3a265399c16d87f5923acd8e3444024.

Extended exclusive lease from Lead: only the search.query response-evidence hunk
in Vendor/SefariaMobile/Integration/JS/chavrusaRPCFacade.js. The Lead verified
this file is fork-owned, absent from original upstream. No upstream submodule,
existing Swift adapter, UI, project or shared ActionCore contract is edited.

Necessity: the existing facade normalizes missing hits to[] and unknown totals to
raw-hit length before Swift receives them. It also loses raw-vs-processed positions
and total relation. Downstream-only validation cannot recover discarded evidence.
Alternative: disable Embedded action search entirely; safe but unnecessarily loses
valid responses where the raw API supplies sufficient evidence. A second query or
engine would duplicate work and could observe a different index generation.

Hunk: additive `fidelity` metadata on the existing search.query result only, plus
local read-only variables capturing the original raw response. Old hits/total/
start/size, query execution, processing and UI consumers remain unchanged.
Capture raw counts and total/cursor scalars before the existing processor can
mutate the raw array. The actual-handler fixtures cover that mutation explicitly.
Expose raw hit array validity/count, processed count, requested start/size,
source-total presence/value/relation and source cursor presence/validity/value.
Unknown exactness/cursor stays unknown; no occurrence count or inferred exactness.

Tests: isolated actual-handler source with mocked existing search API, plus Swift
mapping fixtures; no Metro/dependency install/native bundle or full corpus run.
Matching JS bundle + Swift app/runtime acceptance remains NOT_RUN.

Rollback: remove only the added fidelity capture/property and disable the new
Embedded action-search adapter. Old consumers and persistence are unchanged.

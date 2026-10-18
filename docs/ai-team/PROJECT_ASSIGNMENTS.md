# Maktabah — Team Assignments & Work Routing

**Asana Project:** [אוצריא (1219602719070493)](https://app.asana.com/0/1219602719070493/list)  
**Base Branch:** `fix/maktabah-search-detail-unification`  
**Setup PR:** https://github.com/davidpovarsky/Maktabah/pull/3  
**Setup Task:** `1219611682682931`

---

## 1. Project Scope & Technical Boundaries
- Otzaria/Zayit stable search identities, pagination metadata, annotation persistence, and Inspector commentaries.
- Preserve Maktabah upstream UI styling and navigation structures.
- Isolating Otzaria / Zayit engine layers without leaking unstable identifiers.

---

## 2. Active Open Tasks & Role Assignments

| Task / Area | Logical Lead | Reviewer / QA | Scope & Constraints |
|---|---|---|---|
| **[P0][R01] Stable hit identity in Zayit search** | נועם (noam) | רוני (roni) | Fix `openResult` in `UnifiedSearchSessionController.swift` to use stable hit IDs instead of ambiguous title+page fallbacks. |
| **[P0][R03] Metadata mapping after Load More** | נועם (noam) | רוני (roni) | Fix `OtzariaTextSearchViewModel` and `UnifiedSearchWorkspaceView` to bind metadata per stable result ID across 100+ hits. |
| **[P0][F07] Sefaria notes UI on iPad** | נועם (noam) | מיה (maya) + רוני (roni) | Resolve `real-ui-sefaria-note` timeout in CI 38904511442. Fix binding and note editor viewport layout. |
| **[P1][F03] Zayit pagination beyond 50** | נועם (noam) | רוני (roni) | Add progressive offset paging, cancellation, and deduping in `ZayitSearchViewModel.swift`. |
| **[P1][R02] Otzaria generic backend anchors** | נועם (noam) | איתן (eitan) + רוני (roni) | Eliminate invented line locators in `OtzariaGenericBackendAdapter.swift`; return true SQLite anchors. |
| **[P1][F05/F06/F09/F10] Inspector commentaries** | מיה (maya) | נועם (noam) + רוני (roni) | Author grouping, quoting vs commentary classification, card expansion without duplicates. |
| **[P1][R04/F05] Link fetch error distinction** | נועם (noam) | רוני (roni) | Distinguish failed fetch from empty links; handle 2,000 links without MainActor blocking. |
| **[P1][CI/A32] 32 Acceptance Tests (A01–A32)** | רוני (roni) | Owner | Execute and verify full acceptance suite on unified HEAD before marking complete. |
| **Cross-Repo TorahInspectorKit Pinning** | תומר (tomer) | איתן (eitan) | Maintain pinned Kit SHA compatibility across Maktabah and Pinkha. |
| **Security & SQLite Transactions** | דנה (dana) | רוני (roni) | Audit statement reset, WAL mode, CloudKit disabled state, and session safety. |

---

## 3. Two-Tier Execution Policy & Approval Gates
- **מדיניות ביצוע (NORMAL מול TEAM):** ברירת המחדל היא ביצוע ישיר בסשן הראשי (`[MAIN_SESSION]`) תוך טעינת הוראות התפקיד מ-`.agents/roles/<role>.md` ו-`PROJECT_ASSIGNMENTS.md`. הפעלת סוכני משנה (`invoke_subagent` / `[SUBAGENT]`) מתבצעת אך ורק לפי בקשה מפורשת של המשתמש ("עבוד במצב צוות" / "הפעל סוכני משנה").
- **Release & Merges:** PR merges to `main`, TestFlight, or production indexing require explicit owner approval.
- **Physical Device:** Tasks with physical iPad requirements remain open until verified on hardware.
- **Asana Policy:** Autonomous updates and verified completion are authorized per `docs/ai-team/ASANA_POLICY.md`.

# G1 unified actions ASSIGN/ACK

[נועם | DEV] [MAIN_SESSION], 2026-11-15. Actual independent Desktop UUID `01a1dc89-87bb-7521-b249-ed383392e940`. Dispatcher `01a1dc84-2697-7902-b100-9e23913eb7f4`; HQ activation `1220541793847728`; assigned source GID only `1219614315863536`.

Verified worktree `C:\Users\DAVID\Code\Maktabah-hq-actions-core-20261115`, branch `codex/otzaria-actions-core-20261115`, exact initial HEAD `07d1cafa6c6bc27aaf299aa826d28a4c02090cb5`. Initial git status clean. Old reader worktree/commit and active Apple work untouched.

Exclusive lease: new `Source/Otzaria/Actions/Package.swift`, `Sources/OtzariaActionCore/{Contracts,Registry,Policy,Engine,Ports,Resources}/**`, matching `Tests/OtzariaActionCoreTests/{Contracts,Registry,Policy,Engine,Ports}/**`, package README/.gitignore, `docs/hq-actions-core/**`. No original source, app hooks, target/project/workflow/lockfile edits. No Resolver/** or Integration/** ownership. Other writers are active; their changes must be preserved.

All new application-independent files are DOWNSTREAM_OWNED; `Source/Otzaria/Actions` absent at base. Additive dependency-free portable Swift6 package only. No upstream integration hook planned. Rollback: scoped revert of G1 commits, no resets of shared/user trees.

Frozen wire and trusted-context semantics: `EXECUTION_G0_20261115.md`. First checkpoint is a compilable public DTO/port API and exact signature handoff; implementation continues immediately. Initial five working operations use injected honest ports; 29 metadata descriptors never imply 29 implemented actions. Full app/backend/Apple/UI acceptance is NOT_RUN. No live DB, expensive CI/build/signing/release.

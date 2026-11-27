# Repository-local hook and signing routing admission and correction

## Setup mistake and exact provenance

The search agent, while creating the isolated rootfs publication repository, added an unnecessary local `core.hooksPath` override. Root did not request it, and no project instruction or skill required it. Authorization to implement and commit the feature did not authorize bypassing an existing gate.

The initial command was:

```text
sudo -u ubuntu env GIT_OPTIONAL_LOCKS=0 git init --initial-branch=codex/otzaria-search-continuation-20261127 /tmp/otzaria-search-continuation-publication-4ea15e70e75444b89de36cd93858640f3/repository
```

There was no `--template` argument. The setup script then executed this additional step:

```python
hooks = repo / '.git/empty-hooks'
hooks.mkdir()
os.chown(hooks, 1001, 1001)
git_at(repo, 'config', 'core.hooksPath', str(hooks))
```

This redirected hook routing to a newly created empty directory. The setup did not copy, delete or replace hook files. However, the agent did not inventory inherited routing or templates before adding the override. **There is no retained pre-override hook inventory.** The current inventory below must not be described as historical verification that no gate was bypassed.

The step occurred in the first publication setup call, whose retained tool result identifies `script_job_278102eccde248b5a22500026c105a8c`. That call later stopped at the full diff check because the preserved `.patch` evidence contains context-prefix whitespace. The eventual source commit `0a68042bc6d7d3d7b2ecb03cc660b9550fac8ec6` was made while this local routing override was present. Root's later publication receipt saying it did not change hooks applies only to Root's own publication call, not to the earlier setup.

## Read-only inspection actually performed

The audit at **2026-11-27 11:19:14 UTC** queried only hook/template routing, selected Git environment overrides, and hook filenames/stat identities/hashes. It did not inspect credentials or dump whole Git configurations. It made no hook, configuration, source, branch or commit change.

`READ_ONLY_AUDIT.json` contains the actual raw result, SHA256 `8134e01cc66755e308b3e551d6f9176c0a8e78f8bc0f6680740da0c51c286c9f`. `AUDIT_CLASSIFICATION.json` records the comparison and its limits.

Current observations were:

- The publication repository had exactly the local `.git/empty-hooks` override; that directory was empty.
- Its ordinary `.git/hooks` contained 14 regular files, all named `*.sample`, with no symlink or active hook filename.
- The original Data worktree resolved ordinary hook routing to `/mnt/development/projects/git-mirrors/Maktabah.git/hooks`. That directory contained the same 14 regular `*.sample` files.
- Every sample filename and SHA256 matched the installed Git package's template directory, discovered through `dpkg-query -L git`, at `/usr/share/git-core/templates/hooks`.
- Ubuntu global and system queries for `core.hooksPath` and `init.templateDir` returned exit 1 with no value. The original Data worktree's effective queries also had no value. The publication repository's only hook-path value was its local override.
- The selected current environment variables `GIT_TEMPLATE_DIR`, `GIT_CONFIG_GLOBAL`, `GIT_CONFIG_SYSTEM` and `GIT_CONFIG_NOSYSTEM` were absent.

These observations found no currently active local hook to execute. They support the current matching-template inventory; they do not reconstruct settings or hook existence before the override, and they do not inspect GitHub's server-side controls. No sample hook was represented as a missed required gate or executed as one.

## Root's actual restoration

Root removed only the unnecessary local setting using:

```text
git config --local --unset core.hooksPath
```

`ROOT_HOOK_ROUTING_RESTORE.json` is copied byte for byte from Root's actual receipt: 3,367 bytes, SHA256 `6c15bf0f4841dd5875e4b88e30942359f3fbcb272c0184a597e49c35ce53ecca`. It records the **2026-11-27 11:20:32 UTC** restoration, exit 0, effective hook configuration absent afterward (exit 1), ordinary sample-hook hashes, clean status, unchanged source commit and unchanged Source tree.

No hook file, branch, source code, existing receipt or published commit was rewritten. The empty directory can remain unused; its existence does not select it after the override is removed.

This documentation follow-up uses ordinary hook routing and the established per-command agent author identity. It adds no product change or new test result. Source remains `41263bcc6d46ee3ea5066aa78d98d3e32c68964b`.

## Separate signing audit and restoration

The same original setup explicitly set local `commit.gpgSign=false`. That was another unnecessary choice by the search agent, not a requested requirement. The agent disclosed it to Root, which authorized a separate narrow audit and restoration before the documentation commit.

The audit read only the boolean and origin of `commit.gpgSign` in the publication repository, Ubuntu global/system configuration and the original Data worktree. It did not read signing key values or credentials. At **2026-11-27 11:23:21 UTC**, global/system and the original Data effective setting were absent; the publication repository had only its local false override. No inherited true requirement was found in that current inspection.

The agent removed only the local setting with `git config --local --unset commit.gpgSign`. Effective configuration was absent afterward (exit 1). `SEARCH_SIGNING_ROUTING_AUDIT_AND_RESTORE.json` is the exact 3,010-byte receipt, SHA256 `92db764179c068d1fa739c5798baa945d06054f0e89f51483ada6611a6a8dd70`. HEAD, Source and clean status stayed unchanged.

There is no historical pre-override signing audit. These observations do not retroactively qualify the already published commit against unobserved earlier settings. No commit was rewritten, and the documentation follow-up does not pass a per-command signing override. It uses the observed ordinary signing policy.

## Other exact setup settings

The initial setup wrote the following additional repo-local values. They are disclosed separately from hook/signing routing; no new settings were added during this audit.

| Setting | Setup value and purpose | Status in this correction |
|---|---|---|
| `gc.auto` | `0`, matching the explicit no-GC instruction for the alternate-backed isolated publication | Unchanged |
| `maintenance.auto` | `false`, avoiding automatic maintenance in the bounded alternate-backed repository | Unchanged |
| `core.sparseCheckout` | `true`, materializing only the authorized product/evidence paths | Unchanged |
| `core.sparseCheckoutCone` | `false`, using exact-file sparse patterns | Unchanged |
| `core.fsmonitor` | `false`, an additional performance/inspection choice by the agent; initial helper calls also passed `-c core.fsmonitor=false` | Disclosed; not restored or changed by this hook/signing correction |
| `core.hooksPath` | Newly created `.git/empty-hooks`, an unnecessary routing override | Removed by Root; ordinary routing restored |
| `commit.gpgSign` | `false`, an unnecessary signing override | Removed after Root-authorized boolean/origin audit; ordinary policy restored |

The documentation commit uses only the established per-command author identity; it does not change global author settings or pass hook/signing suppression flags.

Future isolated repositories must retain ordinary hook and signing routing unless an applicable existing instruction explicitly requires a different configuration. Repository isolation and resource limits are not reasons to suppress inherited gates.

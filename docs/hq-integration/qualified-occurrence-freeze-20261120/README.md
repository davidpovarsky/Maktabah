# Qualified occurrence combined source freeze

This commit freezes one exact combined application and XCTest source for the next Apple SDK, Native92, full Release96+2 and full-v32 d5 executions. It does not claim that those executions have passed.

Application and test source: 2e6f08659b347a755aef4e4fe6c00d9592ba700d. The freeze changes only downstream input pins, current helper fingerprints, and evidence documentation. All92 selected Native case IDs, grouping, original oracles, HID comparison and timeouts remain unchanged. All96 Release UI requirements and2 oracle requirements remain unchanged. Historical baseline fingerprints and previous-source results remain historical.

The current helper and Sidebar fingerprints name canonical Git LF bytes, the bytes used on Apple checkout. Their previous fingerprints are retained with their representation. The original SDK, engine producers, authenticated framework artifacts, resource manifests, package pins and embedded JavaScript inputs remain unchanged.

The full-v32 gate retains the original installer, resume, process restart, golden-row and no-reindex/no-redownload checks. Its added exact-token checks use observed Swift/C result fields and the independently completed full SQL oracle. They do not imply Core permission admission, UI acceptance or physical-device coverage.

This source seal still requires the original input preflight and independent review before immutable workflow dispatch. No Native acceptance is transferred from older source commits.

## Actual preflight and immutable dispatch

The original full-v32 preflight (including shared app/source inputs, live immutable artifact/release metadata and authenticated SQL oracle) passed on checkout b07f229e85fe894722566ad9444de31d0ba4490f. All26 evidence-gate methods also passed at that exact source. The original Native declaration/group validator accepted92 unique selections with HID retained; the original Release manifest loader accepted96UI+2oracle requirements in5 configurations on an exact Git-LF export. These are source/input/declaration checks, with zero Native executions.

Two independent read-only reviews found no source-freeze or full-v32 deployment blocker. Native and Release selections, timeouts, oracles, original SDK, engines, resources, package pins and JavaScript inputs remain unchanged.

| Exact-source workflow | Run | Initial observed status |
|---|---:|---|
| sdk | [44684593065](https://github.com/davidpovarsky/Maktabah/actions/runs/44684593065) | queued |
| native92 | [44684611471](https://github.com/davidpovarsky/Maktabah/actions/runs/44684611471) | queued |
| release96 | [44684629656](https://github.com/davidpovarsky/Maktabah/actions/runs/44684629656) | queued |
| v32d5 | [44684680952](https://github.com/davidpovarsky/Maktabah/actions/runs/44684680952) | queued |

Each workflow was dispatched once from a separate immutable branch at the same checkout. Initial queued state is not a successful build or test. Full-v32 publishing and manifest repair are disabled; only the existing original artifact is consumed. The four branches must not move while these runs are active. All raw preflight and dispatch receipts are retained losslessly with separate stored/raw hashes. Evidence collected from the earlier SDK run remains attributed to its earlier OFF-registry source, and is not transferred to these new runs.

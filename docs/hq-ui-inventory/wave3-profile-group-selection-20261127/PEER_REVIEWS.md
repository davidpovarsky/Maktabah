# Source review record

These are independent source reads supplied by the named project agents. They are not SDK, device, simulator or physical QA results.

## Navigation peer

Initial review of the coordinator `7d144b24…`, snapshot adapter `67cd2b7a…` and early workspace adapter `ca6a4653…` found no demonstrated issue in the shared rollback/terminal scaffold, while requiring the later exact Store/native publication fence.

A later read of the captured-publication draft found a concrete source bug: re-reading the optional current reservation after original load callbacks could turn a released owned request into an ordinary unchecked UI operation. This finding was corrected by carrying the explicit captured owner through stage, persistence, publication and each finite operation. The actual source control “release during original load prevents later original selectTab” passes in the final32/56 runs. The review finding is source evidence, not a claimed native reproduction or an unexecuted negative-control pass.

Final binding review read `0829ebda65406fa4fb639e100457485fd797a39a512d62d3fdb08d8aa1a2d0b8`, Session `4853b04ebbdf3ea531ac73175edc38a65871b7cc289a83dca2ec73d8dbf08a1b` and the Projection diff against aa509. It found no additional demonstrated blocker in the reviewed source-before-await, retained stage/Store/native owner, exact private identity, actual empty/nonempty surface and post-callback binding checks. It did not claim broad lower-adapter approval or runtime acceptance.

The peer separately demonstrated the original observable mode-counter lost-publication case and supplied the actual failed/passing source control. Root authorized its one-line passive metadata correction. The group binding observes actual `currentMode` as well as checking the counter; it does not rely only on counter notifications.

## Release/preflight peer

The final bounded read used:

- Reservation `a9a75bd53eb711e2a21e5f3011c965eb50414b2397f797806eb08bd74f6c739d`.
- Adapter `48e518d7b7ab39a6b9ee4cc2ab6093667d3e071d44a39799dc908cd233cd1ae4`.
- Store `22d20126a623b7593080a8a1f17b59a1003c821ecf0c25426df2ffc476a20aea`.
- Coordinator `830076552c95f05093dbf85ff6629f6a834e3bba8c6a9300631cdcfb11439f12`.
- Manager `2163d9d51b40423a5130b0d9b97e4a063af12c6fb3f1e1ec6b0dc40b753b24a2`.

No additional blocker was found in that apply/persist/publish scope. The read confirmed validation after original snapshot flush and before Store, exact candidate/revision and consumed will/did fences, captured nonnil original operation ownership, one declared pending-clear event, and failure remaining failure after native effects. Original `selectTab`'s same-active early return matches its declared zero-change step. No controls were rerun by the reviewer; this was not a complete review of all new binding/Session or all test evidence.

## Root Composition review

The shared integration draft belongs to root and is not included as a product edit here. The first draft lacked the finite private descriptor and needed an explicit MainActor staging closure for the original Sendable deadline operation. Root corrected both. The reviewed final draft is `2b1a991b804e11068478ed96fb11d86efe6ad5663f4acb3296411f3943b59a14` (200288 bytes). Its capture, fixed deadline, one reservation, bounded stage, original Core/orchestrator and retained strict completion sequence is consistent with the packet's APIs. Actual Apple typechecking remains pending.

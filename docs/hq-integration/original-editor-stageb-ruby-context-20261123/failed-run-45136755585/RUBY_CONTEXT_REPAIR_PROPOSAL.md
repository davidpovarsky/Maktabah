# Proposed bounded Ruby context repair — source review before implementation

Base: 8e9dac2d9585dd482e9ab784a65c5517b6847648, existing isolated Stage B branch. No workflow, application, UI test, distribution predicate, SDK artifact pin or original Ruby project mutation logic changes.

## Actual missing fact

The original successful `pod install` loads Xcodeproj in its own Ruby environment; the later PATH Ruby cannot. The current evidence cannot identify that successful Ruby/Gem context. Pinning a guessed runner path or installing another unbound version would not repair this evidence boundary faithfully.

## Proposed paths and behavior

1. `Scripts/CI/hq-stage2-focused-apple.py`: add an optional subprocess environment argument to the existing `logged` function and an optional original-editor-only context observation argument to `install_real_pods`. With no editor admission, the existing zero-argument/default path remains byte-equivalent in command and environment. With editor admission, only the one existing `pod install` subprocess receives an observer require and an owned receipt destination; all existing workspace/header/pin/source checks remain. No second pod install.
2. NEW `Scripts/CI/hq-original-editor-ruby-context.rb`: a small observer/launcher. In observer mode, Ruby's ordinary preload runs in the actual original pod process. Capture the initial program identity and command, then at exit record actual executable/engine/version/platform, Gem.dir/Gem.path and the loaded Xcodeproj dependency closure (exact versions, spec/source locations and hashes). Only the expected original pod process may create the exclusive owned receipt; no credentials or general environment dump. Nonzero original command or missing/ambiguous context refuses continuation. In launcher mode under that captured Ruby, reactivate exactly the captured original gem versions, verify the runtime/spec/source identities before loading the unchanged original project helper, and preserve its nonzero exit.
3. `Scripts/CI/hq-original-editor-distribution.py`: after all unchanged SDK/typecheck admission, validate the original pod receipt and launch the unchanged `hq-original-editor-app-target.rb` under the exact captured Ruby/Gem context, with a per-process environment only. Reject any path/runtime/gem identity mismatch before project mutation. Retain the original command logs and add the admitted runtime receipt to app integration evidence.
4. Owned failure/repair evidence and focused controls only. `hq-original-editor-app-target.rb` itself remains byte-identical.

The observer must preserve inherited RUBYOPT and apply only to the original pod subprocess. It must not claim a Ruby subprocess or task creation alone proves successful CocoaPods. A receipt is admissible only together with the actual existing pod command exit zero. Any child observer or duplicate receipt is refused. The launch must derive paths from the actual retained receipt rather than shell-evaluating strings. The original 2,528-file closure, dynamic signatures/platform/architecture, compiler API, project delta guards, app embedding inventory, native UI assertions and owned cleanup remain intact.

## Focused qualification scope to prepare after approval

Meaningful new controls cover exact same-runtime/gem-context success, alternate PATH Ruby not selected, nonzero/missing pod proof, duplicate/child observer refusal, runtime or gem/source drift rejection before original helper, and original helper nonzero propagation. Any portable fixture Ruby/gem mechanism is explicitly not Apple/CocoaPods/native qualification. Existing SDK admission controls are reused only by source correspondence. Execute the unchanged workflow source-admission blocks against the final populated source once, rebinding only affected source receipts if required. No CI activation or dependency installation before root reviews the concrete delta and control evidence.

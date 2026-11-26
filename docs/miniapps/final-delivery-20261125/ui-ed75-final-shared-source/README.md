# Exact Apple UI compile and final shared source materialization

The original Apple UI compiler ran on ed75bffe at 13:28 UTC and passed all 13 source files, source membership and the aggregate gate. The original compiler report records compilerExitCode=0. The local wrapper accidentally read an absent exitCode key and retained null in its redundant compiler_exit field; both raw files remain unchanged, with the distinction explicit in TRANSFER.json. No UI/native execution is claimed.

The original Mac consumer was then advanced from dd5c5497 to f7cc0431. Its two generated original Pods files remain byte-identical to the previously verified copies. The original pinned Hanlin verifier independently verified all 959 consumed files at final27381. No new pod installation ran. Original SDK292 admission, full Maktabah app compilation and native acceptance remain separate gates.

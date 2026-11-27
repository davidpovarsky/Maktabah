# Actual differential preservation and exact restoration pointer

The same private draft upload completed in job_429fd8747557 with exit0.
All three assets received full authenticated byte readbacks. The final receipt
and final-publication marker are both bound, and the failed original attempt
remains preserved in the previous integration checkpoint.

Preparation job_1d707ab36360 completed with exit0. It verified the original
archive identity and full hash, twelve exact metadata siblings, current private
asset identities and absence of active file/mapping holders. The original
archive still exists. This checkpoint makes no retirement or build claim.

The differential has four unchanged historical Windows base dependencies.
It is not self-contained. No full tree has been restored. The restoration tool
can recreate only the exact archive leaf, preserving original mode/owner/times
and verifying all three authenticated payloads. Original inode and ctime are
evidence and cannot be recreated. Restoration has not been executed.

The separate retirement command requires this exact committed PREDELETE and
fresh private/source/sibling/no-use checks before its sole named leaf unlink.
The full raw preparation and transport journals and all source reviews are
preserved losslessly as ZIP files. The scripts, pointer and terminal proofs
are also directly reviewable in prepared/. No Apple app is distributed here.

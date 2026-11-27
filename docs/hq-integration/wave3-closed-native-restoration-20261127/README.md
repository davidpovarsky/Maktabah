# Pinned restoration before exact archive retirement

Actual preparation job_630724af9922 completed with exit0. The original archive
is still present. The exact private release and all three asset identities,
source inode/ctime/full hash, all22 metadata siblings, and absence of current
archive holders were verified. The pointer and scripts were fsynced and read
back before PREDELETE was written. Their exact hashes are preserved here.

The restoration script recreates only the original archive leaf, verifies all
three full authenticated payloads and metadata members, and never extracts the
Mac/source payload. Its actual restoration has not been run. It requires the
original2GiB Data reserve plus space for the archive. Original mode/owner/times
are preserved; original inode and ctime are evidence and cannot be recreated.

Both tools refuse optimized Python before imports or actions. The initial
source drafts and review finding are retained, together with two actual local
expected-refusal checks. Those checks are not remote or native executions.

The separate commit phase still requires this exact PREDELETE acknowledgement,
fresh private/source/sibling/no-use checks and the pinned parent directory.
It may unlink only the named archive leaf. This Git checkpoint performs no
retirement, test, SDK build, native run or application distribution.

---
name: simplify
description: Simplify requested changes for reuse, clarity, and efficiency while preserving behavior.
---

# Simplify changes

Inspect the intended diff, including staged changes, and preserve unrelated work.
For explicitly named existing code, use that scope.

Review reuse, clarity, and efficiency together: existing helpers and components, duplicate
state, unnecessary wrappers, leaky abstractions, parameter proliferation, redundant I/O,
N+1 queries, recurring unnecessary updates, unbounded caches, and missing cleanup.

Fix concrete in-scope issues. Avoid extracting modules solely to shorten files or adding
optimization machinery without a demonstrated need. Preserve authorization, error behavior,
and public contracts. Measure before claiming performance improvements.

Run focused checks for changed behavior, the affected package suite where applicable, and
the current repository's required checks. Report what changed and any unverified behavior.

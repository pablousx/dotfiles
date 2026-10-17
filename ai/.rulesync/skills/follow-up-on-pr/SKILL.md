---
name: follow-up-on-pr
description: Address feedback and CI failures on an existing pull request, update its branch, and report merge readiness.
---

# Follow up on a PR

## Prerequisites

Use Git for local branch operations and an authenticated GitHub CLI (`gh`) or an
available GitHub connector for PR metadata, review threads, checks, and authorized
remote updates. These CLI workflows target Linux and macOS; verify tool availability,
network access, and the intended account/repository scope without exposing credentials.
Use the project's own test and build tools. Missing GitHub access may still permit
local diagnosis, but leaves remote findings or updates unverified; state that limit.
Do not install tools or change authentication merely by invoking this skill.

## Resolve the outstanding work

Inspect PR metadata, base, complete diff, unresolved review threads, CI results, and local
working-tree state. Read available requirements and establish whether reported problems
remain. A previous reply does not prove that its concern is fixed.

Preserve user work. Reuse an appropriate checkout or isolate the PR in a worktree. Fetch
the base before deciding whether synchronization is needed. Resolve conflicts against
both the intended outcome and current base behavior.

Address actionable feedback and CI failures. Reproduce defects where practical, update
the owning test when needed, and follow the current repository's verification requirements.
Verify a claimed pre-existing failure against the base before attributing it to unrelated work.
Reuse checks for unchanged code; affected checks do not replace the required root gates.

Stage only intended files and follow the repository's commit conventions.
Use a normal push unless a rebase requires a lease-protected update; inspect the remote
branch before rewriting its history. Never force-update the default branch.

Update the PR title/body when necessary to describe the final behavior and observed checks.
With the CLI, use `--body-file` for multiline text; use structured body fields with a
connector. Replies or submitted reviews require authorization
to communicate on the PR; draft them locally otherwise. Investigate security-scanner
blocks instead of bypassing them or recommending that the user disable the scanner.

Follow the harness's PR registration and monitoring requirements when available.
For a monitoring request, prefer its event-driven watcher over a polling loop.
When the task includes getting the PR ready, check CI for the pushed revision. Report
the URL, resolved concerns, failures, and unverified layers. Merge and deployment remain
separate actions.

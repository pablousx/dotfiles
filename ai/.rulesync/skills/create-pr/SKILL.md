---
name: create-pr
description: >
  Submit repository changes as a pull request when requested. Inspect the complete
  diff, reuse valid verification evidence, and report review readiness without
  merging or deploying.
---

# Create a pull request

## Prerequisites

Use Git for local branch and diff operations. Publishing requires network access
and an authenticated GitHub CLI (`gh`) or an available GitHub connector with
access to the intended repository. Git and the CLI can be used on Linux and macOS;
verify their availability and account/repository scope without printing credentials.
Use the project's own tools for verification. If GitHub access is unavailable,
prepare the title/body locally and report publication as blocked. Do not install
or authenticate tools as an implicit step.

## Submit the requested change

1. Inspect the working tree, branch, intended base, and complete diff. Preserve unrelated
   work. Confirm the intended commits are present and the branch is pushed before creating
   the PR; do not include unrelated files merely to make the tree clean.
2. Read the current repository's instructions, completion criteria, and verification
   commands. Run its required checks appropriate to executable changes;
   pure prose follows the documented diff,
   formatting, link and consistency checks. Reuse successful checks for the same code state; rerun only
   when edits, failures, or unresolved concerns invalidate the evidence.
3. Use an existing ticket reference when supplied or discoverable from the task. Otherwise
   omit it unless this repository explicitly requires one. Creating or selecting a ticket
   is not a general prerequisite for a PR.
4. Follow the repository's title conventions and PR template when present. Otherwise
   use a concise title describing the outcome. Describe the final problem and resulting behavior, material
   risk or migration steps, checks and results, and unverified layers or blockers. Link
   existing evidence instead of copying checklists. Separate optional improvements from
   blocking defects.
5. Publish through the available authorized GitHub interface. With the CLI, use
   `gh pr create --base <base> --head <branch> --title <title> --body-file <file>`.
   Write the exact multiline body to a temporary file; with a connector, pass structured
   title/body fields. Follow the harness's PR registration requirements when available.
   Use a draft when essential
   verification is pending, and state the blocker. Normal human PR review can follow
   implementation readiness.
6. Return the PR URL and remaining blockers. Human review, merge, and deployment are
   separate actions; never merge or deploy without authorization.

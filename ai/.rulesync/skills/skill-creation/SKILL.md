---
name: skill-creation
description: Create or revise reusable skills, including discovery metadata, supporting resources, tool prerequisites, and validation. Use for skill authoring rather than ordinary product documentation.
---

# Portable skill authoring

Follow [writing-for-agents](../writing-for-agents/SKILL.md) for guidance structure
and context pointers. This workflow defines a harness-neutral source; use any
available harness-specific authoring helpers only where their requirements apply.

## Prerequisites

Writing Markdown and checking local references requires no specific shell tool on
Linux or macOS. Git is optional for diff and provenance inspection. Validators,
generators, and the authored skill's runtime tools are conditional dependencies;
inspect their actual prerequisites before using them. For Rulesync generation,
use the existing configured toolchain and synchronization command. Do not install
tools merely to load this skill. State unavailable checks and their consequences.

## Choose the owner

- Inspect existing instructions and skills before adding a new trigger. Prefer
  correcting the owner over introducing a competing workflow.
- Put personal cross-project workflows in the user's maintained global sources.
  Keep product rules, repository paths, and workspace-specific workflows with
  their project. Follow an established layout and the user's chosen destination.
- If the setup uses Rulesync, edit its canonical skills input tree, not generated
  harness directories. Discover that tree from its configuration and setup scripts;
  do not assume a particular checkout location.
- Use a folder containing `SKILL.md`, with a lowercase hyphenated name matching
  the frontmatter `name`, and a concise `description` identifying when to use it.
  Add supporting references, scripts, or assets only when the workflow needs them.
- Keep always-applicable preferences in the owning instructions and architectural
  explanations in product documentation. Do not encode one-off task preferences
  as global rules or require reviewing session history without authorization.

## Write for capable agents

- State the desired outcome, essential constraints, and decision criteria. Reserve
  exact sequences for fragile operations. Avoid exhaustive triggers and unrelated
  mandatory procedures.
- Keep conditional detail in references and preserve useful resources. Links must
  remain valid after installation; do not depend on files outside the skill bundle
  unless that dependency is explicit and available at the destination.
- Distinguish required shell tools, optional tools, and non-shell capabilities.
  Document Linux/macOS support, authentication or access prerequisites, and useful
  fallback behavior when tools are missing. Reuse approved dependency setup.
- Point to maintained project sources instead of copying versions, commands, or
  API descriptions. Discover the current project's checks rather than imposing
  another repository's stack or conventions.
- Preserve existing authorization. A skill does not grant permission to publish,
  send messages, install dependencies, or modify production. Avoid unnecessary
  confirmation for reversible work already authorized.
- Keep optional harness capabilities conditional. Do not require a fixed model,
  tool name, worker count, or reasoning budget across environments.
- Preserve imported provenance and licenses. Inspect callers and lockfiles before
  moving resources; do not claim adapted content matches an upstream release hash.

## Validate

Check the complete content, frontmatter, names, links, commands, and agreement with
the owning instructions. Use an available compatible validator, while recognizing
that structural validation does not prove behavioral quality. Review a task that
should invoke the skill and a nearby task that should not.

Exercise new or changed scripts in isolation. For complex workflows, check routing,
decisions, stopping conditions, and side effects with representative tasks and
authorized resources. Follow the current repository's verification requirements.
For generated installations, inspect a dry run, check resulting paths and required
resources, and preserve existing content before applying changes.

Remove obsolete guidance rather than accumulating exceptions. Report what was
validated, what remains untested, and any missing tools or external access.

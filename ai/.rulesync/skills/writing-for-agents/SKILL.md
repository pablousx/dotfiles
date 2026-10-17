---
name: writing-for-agents
description: Review, write, or revise instructions, skills, and technical documentation that agents must apply reliably.
---

# Write for agents

Use when reviewing, creating, or editing `AGENTS.md`, skills, prompts, or documentation that controls an agent workflow. The goal is dependable decisions and behavior, not a longer instruction document. A read-only review ends with findings or a proposal; make changes only within the authorized scope.

## Shape the guidance

- Identify the intended reader, the task that should reach this document, and the observable outcome it should produce.
- Check canonical project rules, owning code, related skills, and existing documentation before drafting. Resolve contradictions at their source; do not create a second authority.
- Keep personal cross-project preferences in global instructions, product boundaries in the project's canonical `AGENTS.md`, specialized repeatable workflows in skills, and implementation facts with their owning package or feature.
- Make each document a coherent unit with a clear purpose. Integrate a needed rule into the existing workflow where it belongs; do not append a themed add-on, duplicate existing guidance, or preserve obsolete rules as exceptions.
- Use precise, conditional triggers. State what the agent must do, what it should decide, and when it should stop. Avoid vague keyword catchalls and repeated trigger lists.
- Prefer short context pointers that name both their purpose and the conditions that require reading them. Keep details in a linked reference when only some tasks need them.
- Specify hard sequences only where order is safety-critical or the operation is fragile. Otherwise provide decision criteria that let capable agents choose the smallest adequate path.
- Preserve authorization boundaries and user intent. Guidance must not imply permission to publish, modify production data, install dependencies, or perform external actions.
- Avoid fixed version claims, duplicate commands, and copied API descriptions when a maintained source already owns them. Do not assume a tool, integration, or directory exists without checking.
- When adding or syncing a skill, distinguish required shell tools, optional tools, and non-shell capabilities. Document prerequisites, check target-platform availability, and explain missing-tool behavior. Reuse the user's dependency setup for approved shared tools; loading a skill must not silently install them.
- Use the document's existing language and tone. Keep instructions portable across compatible agents unless a verified tool-specific contract requires otherwise.

## Validate the result

- Check the complete document, frontmatter, local links, commands, and examples against current sources.
- Confirm each rule has one clear owner and does not conflict with root or workspace guidance.
- Test routing with a representative task that should invoke the document and a nearby task that should not.
- When changing executable commands, scripts, or technical contracts, verify the changed behavior. For prose-only edits, inspect the complete diff, formatting, references, and consistency. For a read-only review, report findings and verification limits without invoking implementation checks.
- Remove superseded guidance instead of accumulating workarounds. Report unresolved assumptions rather than presenting them as established policy.

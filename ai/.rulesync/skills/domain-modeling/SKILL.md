---
name: domain-modeling
description: Clarify, review, or change product concepts, relationships, terminology, lifecycle rules, and invariants against the current project's canonical requirements.
---

# Domain modeling

Use when a task clarifies, reviews, or changes the product model. For ordinary
implementation with settled domain rules, consume those rules without opening a
separate modeling exercise. A read-only analysis ends with findings and unresolved
decisions; it does not authorize documentation or implementation changes.

## Prerequisites

No specific shell tool, framework, database, or diagram renderer is required for
source-based analysis on Linux or macOS. Read the available project instructions,
requirements, source, and tests. Git is optional for history; project runtimes and
test infrastructure are needed only for claims that require execution. Report
missing access or tools as evidence gaps, and distinguish analysis from verified
behavior. Do not install tools or access live data merely to load this skill.

## Start with the canonical model

- Read the applicable project and workspace instructions and the owning product
  documentation. Treat approved product rules as requirements; use implementation
  and migrations as evidence of shipped behavior, and flag discrepancies.
- Inspect the schemas, contracts, policies, UI, tests, and documentation that own
  the concept. Trace adjacent concepts, identities, and persisted values before
  proposing changes.
- Preserve the project's established vocabulary and meaningful distinctions. Do
  not import another product's roles, tenancy model, entities, or lifecycle.
- Discover existing contracts for affected formats, integrations, and generated
  content before proposing a parallel representation or compatibility adapter.

## Stress-test the model

- Define the concept by its user meaning and the invariant it preserves; avoid
  renaming merely to improve code vocabulary.
- Walk through realistic success, failure, permission, lifecycle, and boundary
  cases. Include actor identity, resource scope, ownership, provenance, and time
  when they change the outcome.
- Check whether the proposed rule fits existing concepts and shared workflows
  instead of creating an inconsistent parallel model.
- Separate explicit decisions from unresolved choices. Ask for missing product
  decisions only when they materially change behavior, compatibility, or access.

## Report and implement within scope

- Explain the invariants, their owning layers, and gaps between intended and
  implemented behavior. Distinguish inspected code from executed evidence.
- When documentation changes are authorized, put durable rules in their canonical
  owner and implementation facts beside the relevant code. Use the project's
  existing documentation structure; do not create a glossary or decision log
  unless it serves the requested outcome.
- When implementation changes are authorized, update affected contracts and
  consumers together: validation, persistence, authorization, UI, localization,
  reporting, and integrations as applicable. Verify at the layers that own the
  changed invariant, using the current project's required checks.
- Preserve historical data and external contracts. Resolve destructive migrations
  or compatibility changes beyond existing authorization before performing them.

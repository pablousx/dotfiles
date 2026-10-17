---
name: threat-model-generation
description: Create or update a repository threat model when requested, including assets, trust boundaries, threats, controls, and evidence gaps.
---

# Threat modeling

## Prerequisites

No shell tool, scanner, or diagram renderer is mandatory for a source-based model.
Use available file-reading tools on Linux or macOS; Git is optional for revision
context. Use an existing diagram tool only when it clarifies the requested model.
Project tests or deployment access are needed only for claims that depend on them.
If unavailable, document those evidence gaps rather than inventing controls or
installing tools. This workflow does not require live probing.

## Model the requested scope

Model the requested system and deployment, not a generic SaaS template. Start with root
and owning workspace instructions, actual entrypoints, schemas, auth policies, queues,
storage, external providers, AI flows, and deployment configuration.

Use an existing maintained model when present. If a new document is requested without a
location, use the repository's documentation structure; do not create a `.factory`
directory, scanner configuration, or policy as an implied prerequisite.

## Establish the model

- Inventory components and data flows. Link source paths for security-relevant claims.
- Identify assets, actors, attacker capabilities, entrypoints, and trust boundaries.
  Authenticated users and internal services can carry hostile input.
- Apply the project's canonical access, data ownership, provenance, external-input,
  and AI-action constraints where those concerns exist. Trace their implementing
  boundaries rather than assuming a particular role or tenancy model.
- Analyze STRIDE threats where applicable. Distinguish implemented controls, intended
  requirements, confirmed gaps, and unknown deployment assumptions.
- Describe concrete abuse paths and impact. Rank remediation using stated likelihood and
  impact; uncertainty is separate from severity.
- Record coverage and unanswered questions. Do not invent accepted risks, security owners,
  compliance status, or review schedules on the user's behalf.

Use [the outline](stride-template.md) as optional structure, omitting irrelevant sections.
A diagram helps when several flows cross trust boundaries; it is not mandatory.

Validate important claims against code and tests. Documenting a control does not prove
it works, and completing headings does not establish audit coverage. Report evidence and
follow-up checks. Commit, publish, configure scanners, or notify people only if requested.

# Threat model outline

Adapt this outline to the requested system. Replace placeholders with verified facts;
omit irrelevant sections. Do not present proposed controls or unapproved risks as current.

## Scope and evidence

Revision/date, components and deployments included, inspected sources, exclusions, unknowns.

## System and data flows

Purpose, components, entrypoints, external dependencies, sensitive data, and trust boundaries.
Describe who can influence each input, including authenticated users and upstream services.

## Assets and authorization

Protected data/actions, actors, identities, resource ownership, authorization enforcement,
session/revocation behavior, storage and cache scope.

## Threats

For each relevant STRIDE threat:

- Scenario and attacker prerequisites.
- Entry point, controlled input, crossed boundary, and consequence.
- Current controls with source references and evidence of enforcement.
- Gaps or uncertainties, distinguished from confirmed vulnerabilities.
- Impact, likelihood, confidence, and proposed mitigation or verification.

Do not fill every STRIDE category with hypothetical findings just to complete a table.

## Verification and remaining work

Executed checks versus code inspection, negative/permission cases, coverage gaps,
proposed next steps. List accepted risks only when an authorized owner has accepted them.

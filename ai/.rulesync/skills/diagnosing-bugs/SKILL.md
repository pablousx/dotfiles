---
name: diagnosing-bugs
description: Diagnose a reported defect or performance regression before changing code; establish the failing behavior, trace its cause, and verify a focused correction.
---

# Diagnose bugs

Use this workflow when the user reports broken, incorrect, intermittent, or slow behavior and wants an explanation or diagnosis. Respect the requested boundary: a read-only investigation ends with evidence and next steps, not an unrequested fix.

## Establish the failure

- Restate the observable symptom, affected user path, and scope from the request. Separate observed facts from assumptions.
- Read the applicable project instructions, the owning implementation, relevant callers, and existing tests. Follow the project's domain and authorization rules; do not infer intended behavior from implementation alone.
- Identify the appropriate observable feedback loop: a focused test, browser path, runtime log, trace, or measured workload. Use existing tools and fixtures before adding instrumentation.
- For runtime logs, identify the actual process output, session capture, or external sink and its format before parsing. A missing log file does not prove there are no logs. Redact secrets and personal data before sharing evidence.

## Narrow the cause

- Reproduce the failure or state clearly why it cannot be reproduced. Reduce the investigation to the smallest realistic input and boundary that still exhibits it.
- Form a specific hypothesis from the evidence. Trace data, identity, authorization, state transitions, async work, and external effects only where relevant.
- Change one causal factor at a time. Prefer a focused test or other repeatable signal that fails for the reported defect and passes when the cause is corrected.
- Do not treat correlation, unusual code, or a passing mock as proof. Check relevant mitigations and distinguish pre-existing conditions from regressions.

## Correct and verify when authorized

- Make the smallest complete correction that preserves the product contract and user intent. Resolve choices that would change compatibility, persisted data, external effects, or scope beyond the existing authorization before making those changes.
- Add or strengthen a test only when it catches a realistic regression, following the project's test conventions. Use browser or integration evidence when a unit test cannot establish the user-visible behavior.
- Run the focused feedback loop while iterating, then the current repository's required checks on the final state. Inspect the full result for diagnostics, skips, and unexercised layers.
- For performance claims, compare the same representative workload before and after. Do not claim an improvement without measurements.

## Report

Give the conclusion first, followed by the evidence that supports it, files or boundaries involved, checks run, and remaining uncertainty. If blocked, state what was attempted and the concrete missing evidence. Do not present a hypothesis as a confirmed cause.

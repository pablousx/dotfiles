---
name: retro
description: Review a completed coding session for evidence-backed improvements to the agent workflow, project guidance, or tooling.
---

# Session retrospective

Use only when the user asks for a retrospective or for improvements to the coding setup. Do not turn routine implementation into an unsolicited review of the user's workflow.

## Gather evidence

- Review the current session or the specific sessions the user names. Read additional local session history only when requested or clearly authorized for this retrospective.
- Look for repeated, consequential friction: misunderstood requirements, missed project rules, avoidable verification gaps, duplicated work, or unavailable tooling.
- Distinguish a demonstrated pattern from a one-off event, preference, or speculative opportunity. Do not quote secrets, credentials, or irrelevant personal content.
- Check the current `AGENTS.md`, relevant skills, scripts, and configuration before proposing a change. Verify that the issue is not already addressed or intentionally constrained.

## Recommend proportionate changes

- Rank recommendations by observed impact and recurrence. Name the evidence and the concrete behavior that the change should improve.
- Prefer correcting the owning instruction or tool over adding a new skill, duplicate rule, or general exception. Keep durable product rules in `AGENTS.md`, specialized workflows in their owning skills, and technical detail beside the implementation.
- State risks and trade-offs, including extra instructions loaded on unrelated tasks. Do not introduce model-specific behavior or unsupported tools.
- A retrospective authorizes analysis and recommendations, not unrelated code changes, external writes, or persistent configuration changes. Make requested, in-scope edits only.

## Report

Summarize observed patterns, prioritized recommendations, evidence reviewed, and remaining limits. Separate confirmed friction from ideas that need a future trial.

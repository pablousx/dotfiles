---
name: research
description: Research a technical or product question using authoritative sources, then report verifiable findings and implications for the requested decision.
---

# Technical research

Use when answering a question requires checking external documentation, standards, APIs, release behavior, or implementation details beyond the local codebase. For questions answerable from repository sources, inspect those sources first.

## Investigate

- Define the question, the decision it informs, and any relevant version, platform, or compatibility scope. Ask if an ambiguity could change the conclusion.
- Prefer primary sources that own the claim: official documentation, standards, release notes, source code, or protocol specifications. Use secondary sources to discover leads, not as sole evidence for consequential claims.
- Verify claims against the applicable version and date. Separate documented behavior from inference, recommendation, and unresolved uncertainty.
- Check the current project's contracts and the user's constraints before recommending adoption. Consider security, privacy, operational burden, compatibility, and user-visible behavior where relevant.
- Do not install packages, run paid services, contact third parties, alter connected systems, or write research files unless the user authorizes that work.

## Report

Answer the question directly. Provide citations or exact source links for material claims, explain their relevance to the requested decision, and identify contradictions, version limits, and remaining unknowns. Save findings as a project artifact only when requested or needed to fulfill the task.

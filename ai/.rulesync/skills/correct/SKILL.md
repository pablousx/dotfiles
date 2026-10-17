---
name: correct
description: |
  Correct code, behavior, or project guidance when the user points out a mistake. Update AGENTS.md or
  SKILL.md only when the correction reveals a recurring, durable project convention or an incorrect rule.
---

# Correct Skill

Use when correcting a mistake or addressing user feedback. Fix the requested behavior first. Change durable guidance only when the mistake came from a missing, incorrect, contradictory, or repeatedly violated project convention.

## Prerequisites

No specific shell tool is required by this workflow. Use the current project's
inspection and verification tools on Linux or macOS. If a required check is
unavailable, report the missing tool and leave that verification pending; do not
install dependencies merely because this skill was loaded.

## Correct the outcome

1. **Root Cause**: Identify why the mistake happened (e.g., missing rule, misunderstood pattern).
2. **Decide Whether Guidance Should Change**:
   - Update `AGENTS.md` or the relevant `SKILL.md` only for durable, reusable project conventions.
   - Keep one-off task preferences and ordinary implementation mistakes out of permanent agent guidance.
   - Define rules from a constructive, **"what to do"** (proper architecture/pattern) perspective rather than a "what not to do" list.
   - State the **current** convention only. Rewrite obsolete guidance out of the doc — do not leave deprecation / "old vs new" narration.
3. **Structural Fix**: Implement a clean, type-safe code correction aligning with the updated rules. Do not use patchy workarounds.
4. **Verify**: Follow the current repository's verification requirements. Pure prose needs diff, formatting, link and consistency checks. Executable, test, configuration or technical contract/example changes need the applicable project checks and relevant behavior evidence; inspect autofix changes.

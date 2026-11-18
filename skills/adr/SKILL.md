---
name: adr
description: Record a decision made in this session as an architecture decision record in .brain, without an interview. Use when the user says yes to "Record it in the brain?", asks to record or write up a decision, or runs /adr.
---

# Record a decision

Draft the ADR from what is already in the conversation and the diff. Ask at most one question, and only if the reason behind the decision is missing from both.

Formats: `.brain/skills/grill-with-docs/ADR-FORMAT.md` (ADRs) and `.brain/skills/grill-with-docs/CONTEXT-FORMAT.md` (glossary).

## Steps

1. **Find the decision.** Read `MAIN_BRANCH` from `.brain/brain.conf` (if empty, run `.brain/scripts/brain main-branch`). Look at the conversation, `git diff <MAIN_BRANCH>...HEAD` and the uncommitted changes (`git diff HEAD`). If the session made several decisions and the user didn't say which, ask which one to record. That is your one question.
2. **Get the latest brain.** Run `.brain/scripts/brain pull`. It fast-forwards `.brain` and keeps upstream's graph. This is the only brain sync a skill does; don't run git in `.brain` (the /absorb skill is the one exception).
3. **Check what exists.** Run `.brain/scripts/brain lookup <keywords>` and read the ADRs it lists.
   - Someone else holds a live claim on this topic: stop, and tell the user who.
   - An existing ADR already says all of it: stop, and tell the user which one.
   - The decision fails one of the three criteria in ADR-FORMAT.md: stop, and say which one.
4. **Write it.**
   - Claim the topic: `.brain/scripts/brain claim <slug> <one-line topic>`. If the claim is refused, stop and name the holder.
   - Pick the file from the ADR-FORMAT.md table. Numbers come from `.brain/scripts/brain next` or `.brain/scripts/brain next-sub NNNN`; identity from `.brain/scripts/brain me`; `Branch` is the current project branch.
   - A sub-ADR also means rewriting the parent's body to the new truth and adding its Revisions line.
   - Reasons come from the conversation, the diff or commit messages. If none of them states it and the user isn't around to ask, write `Why: not recorded; inferred from <source>`.
   - Add or amend `.brain/CONTEXT.md` entries for any new domain terms.
5. **Release and report.** Run `.brain/scripts/brain release <slug>`. Reply with the paths you wrote or changed and a three-line summary, and say they ship with the next project push.

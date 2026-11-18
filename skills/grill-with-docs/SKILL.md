---
name: grill-with-docs
description: Stress-test a plan or design against the project's code, glossary and ADRs by interviewing the user one question at a time, recording settled terms and decisions in .brain as they land, and ending with a Plan-mode handoff. Use when the user wants to grill, pressure-test or poke holes in a plan before building it.
---

# Grill with docs

Interview the user about their plan until every branch of the design is resolved, using the brain as the reference.

## Before the first question

1. Read `.brain/CONTEXT.md`.
2. Run `.brain/scripts/brain lookup <keywords from the plan>` and read the ADRs it lists.
3. Ask the graph about the areas the plan touches: `graphify query "<question>"`, `graphify path "<A>" "<B>"`, `graphify explain "<concept>"`.
4. Read `MAIN_BRANCH` from `.brain/brain.conf`. If it's empty, `.brain/scripts/brain main-branch` gives it.

## The interview

- **One question at a time.** Each question comes with your recommended answer and the reason for it. Wait for the reply before the next one.
- **Look it up instead of asking.** If the code can answer a question, find the answer yourself (graph first, then files) and state what you found. Only ask the user what the code can't tell you: intent, priorities, constraints, people.
- **Challenge the words.** When the user uses a term that conflicts with `.brain/CONTEXT.md`, or a vague one ("handle", "process", "sync"), point it out and propose a precise word.
- **Test with scenarios.** Push the plan through concrete edge cases: empty input, the second concurrent user, a retry after a partial failure, the oldest data in the system, the permission that's missing.
- **Check claims against the code.** When the user says "X already does Y", verify it. If it doesn't, say so with the file:line.
- **Keep a running list** of open branches and work through them until none remain.

## Recording as you go

Follow `.brain/skills/grill-with-docs/CONTEXT-FORMAT.md` and `.brain/skills/grill-with-docs/ADR-FORMAT.md`.

- When a term is settled, add or amend its entry in `.brain/CONTEXT.md` right away.
- When a decision lands that meets all three ADR criteria:
  1. Run `.brain/scripts/brain lookup <keywords>`. If someone else holds a live claim on the topic, tell the user who and don't write it. If an ADR already says it, don't write it.
  2. Run `.brain/scripts/brain claim <slug> <topic>`.
  3. Write the top-level ADR or sub-ADR (and update the parent).
  4. Run `.brain/scripts/brain release <slug>`.
- Run no other git commands in `.brain`. The project's next push ships the changes.

## Finishing

Write the handoff described in `.brain/skills/grill-with-docs/PLAN-HANDOFF-FORMAT.md`. Show it in one fenced block, and also save it to a file in the system temp directory (`${TMPDIR:-/tmp}/handoff-<slug>.md`). Give the user that path, and list the glossary entries and ADRs you wrote.

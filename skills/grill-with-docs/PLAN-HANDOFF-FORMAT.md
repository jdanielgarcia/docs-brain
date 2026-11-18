# Plan handoff format

The grilling ends with this handoff. It goes into Plan mode, or to whoever builds the plan next. Leave out any section that would be empty. Point to paths instead of copying their content.

```markdown
# Handoff: <plan name>

## Goal for Plan mode
One or two sentences: what the plan must produce and what "done" means.

## Decisions resolved
- <decision>: <the answer>, because <reason>. (ADR: .brain/adr/NNNN-slug.md, if recorded)

## Domain language
- **Term**: meaning as settled in this session (see .brain/CONTEXT.md)

## Constraints
- Hard limits the plan must respect: deadlines, compatibility, budgets, people.

## Trade-offs accepted
- <what we gave up> in exchange for <what we got>.

## Open questions
- Questions that still need an owner or an answer, with who should answer.

## Files and ADRs to read
- path/to/file.ext: why it matters
- .brain/adr/NNNN-slug.md: what it decides
```

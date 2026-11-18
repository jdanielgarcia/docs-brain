# ADR format

## When to write one

Write an ADR only when all three hold:

1. **Hard to reverse.** Undoing it means a migration, a breaking API change, a rewrite or a contract with someone outside the code.
2. **Surprising without context.** A capable newcomer reading the code would ask "why on earth is it like this?"
3. **A real trade-off.** There was a credible alternative and choosing this one cost something.

If one fails, don't write it. Naming, folder layout and library picks that are easy to swap rarely qualify.

## Which file

| Situation | Write |
|---|---|
| New decision, no ADR covers its domain | Top-level `adr/NNNN-slug.md`, titled by the domain |
| New decision inside an existing domain | Sub-ADR `adr/NNNN.N-<initials>-slug.md`, then rewrite the parent's body and add a Revisions line |
| An existing ADR already says it | Nothing |
| Reversing a decision | New top-level ADR with `Supersedes: NNNN`; mark the old one `Superseded by` and keep it |
| A glossary term already exists | Amend it in place, never add a duplicate |

Get numbers from `.brain/scripts/brain next` and `.brain/scripts/brain next-sub NNNN`. Two people can still pick the same number on different machines. `brain sync` fixes that on push by moving the later file to the next free number.

## Top-level ADR

A top-level ADR names a domain, not a single decision. Its body is the current truth for that domain, so a reader never has to replay the sub-ADRs to know how things stand.

```markdown
# NNNN Domain name

**Initiated by:** @handle
**Status:** Proposed
**Branch:** feature/branch-name
**Date:** YYYY-MM-DD

## Context

What forces are at play. Facts, constraints, numbers.

## Decision

What we do now, stated as current truth.

## Consequences

What gets easier, what gets harder, what we gave up.

## Revisions
```

**Status** is `Proposed` while its branch is unmerged, then `Accepted`, `Rejected` or `Superseded by NNNN`. A reversal adds `**Supersedes:** NNNN` to the new ADR. Old ADRs are never deleted.

Titles:

- Good: `# 0003 Payments`. A domain. Later decisions about refunds, retries and currencies all revise it.
- Too narrow: `# 0003 Use Stripe webhooks for refund status`. One decision. The next payment decision has nowhere to go.

## Sub-ADR

A new decision inside an existing domain. File name `adr/NNNN.N-<initials>-slug.md`, with your initials from `.brain/scripts/brain me`.

```markdown
# NNNN.N What changed, in a few words

**Revises:** NNNN
**Initiated by:** @handle
**Branch:** feature/branch-name
**Date:** YYYY-MM-DD

## What changed

## Why
```

In the same session, rewrite the parent's body so it states the new truth, and add a line to the parent's `## Revisions`:

```markdown
- NNNN.N (YYYY-MM-DD, @handle): one-line summary
```

## Citing sources

When the reason behind a decision isn't written down anywhere, don't invent one. Write `Why: not recorded; inferred from <commit, PR or file>`.

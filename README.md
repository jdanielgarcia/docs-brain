# brain

A shared memory for AI coding agents, kept next to your code but in its own private repo. It holds three things:

- **A glossary** (`CONTEXT.md`) with one word per domain concept, so agents and people name things the same way.
- **Architecture decision records** (`adr/`) for the decisions that are hard to reverse, so nobody undoes them by accident.
- **A code graph** (`graphify-out/`) built by [graphify](https://pypi.org/project/graphifyy/), so agents ask "what calls X?" before grepping blindly.

It also ships a small CLI (`scripts/brain`), git hooks that sync it, Claude Code hooks that make agents use it, and four Claude Code skills that write to it.

Each project gets its own brain. The brain is a separate git repo cloned into `<project>/.brain` and hidden from the project's git, so it can stay private even when the project isn't, and it never clutters the project's history.

Requirements are git, bash and python3. `gh` and `uv` help but aren't needed.

## One-time setup

Create a private repo from this template, named `<project>-brain`:

```bash
gh repo create my-org/myapp-brain --private --template my-org/brain
```

Or use "Use this template" on GitHub. Then, in each clone of the project, on each machine:

```bash
cd myapp
git clone git@github.com:my-org/myapp-brain.git .brain
.brain/scripts/setup.sh
```

Setup asks for your GitHub handle (it uses `gh` if it can) and your initials. It then:

- hides `.brain/` from the project's git through `.git/info/exclude`,
- links `graphify-out` to `.brain/graphify-out`,
- installs graphify if it's missing,
- adds the Claude Code hooks to `.claude/settings.local.json`,
- installs the git hooks,
- links the skills into `.claude/skills/`.

It prints a block of rules at the end. Paste it into the project's `CLAUDE.md` once. In `.brain/brain.conf`, set `TEMPLATE_REMOTE` to this template's URL, and `MAIN_BRANCH` if origin's default branch isn't the one you merge into.

Check it works:

```bash
.brain/scripts/brain me
.brain/scripts/brain lookup auth
git status
```

`me` prints your handle and initials, `lookup` prints three (possibly empty) sections, and `git status` in the project shows nothing from the brain.

A new brain is empty. Open Claude Code in the project and run `/bootstrap` to build the graph and seed the glossary and the first ADRs from the existing code.

## What happens automatically

- **On project push**, the `pre-push` hook runs `brain sync`. It commits any brain edits, rebases on the brain's remote, fixes ADR number collisions and pushes. It never blocks or fails your push, even offline. If the brain can't push, it tries again next time.
- **On project pull or rebase**, the `post-merge` and `post-rewrite` hooks fast-forward the brain. They stay silent if that fails.
- **Before an agent searches code**, the graph gate denies Grep, Glob and shell `grep`/`rg`/`find` until the session has run one `graphify query`, `explain` or `path`. With no graph on disk there's no gate.
- **Before an agent first edits a file**, the ADR hook looks up the file's name in the brain and shows the agent any matching ADRs and glossary terms.

## How ADRs get written

1. **/absorb** reads what merged into the main branch since the last run, rebuilds and commits the graph, and records the decisions that qualify. Run it after a batch of merges. Only one person can run it at a time.
2. **Saying yes.** When an agent finishes a task that made a qualifying decision, it ends with "This introduced <decision>. Record it in the brain? (/adr)". Say yes and it writes the ADR.
3. **/adr or /grill-with-docs.** `/adr` records a decision from the current session without an interview. `/grill-with-docs` interviews you about a plan one question at a time, records terms and decisions as they settle, and hands off to Plan mode.

Before writing, a skill claims the topic (`brain claim`). The claim is pushed at once, so two people don't write the same ADR in parallel. Claims expire after `CLAIM_TTL_DAYS`.

## ADR rules

An ADR is worth writing only when the decision is hard to reverse, surprising without context and a real trade-off. The full format is in `skills/grill-with-docs/ADR-FORMAT.md`.

| Situation | Write |
|---|---|
| New decision, no ADR covers its domain | Top-level `adr/NNNN-slug.md`, titled by the domain |
| New decision inside an existing domain | Sub-ADR `adr/NNNN.N-<initials>-slug.md`, then rewrite the parent's body and add a Revisions line |
| An existing ADR already says it | Nothing |
| Reversing a decision | New top-level ADR with `Supersedes: NNNN`; mark the old one `Superseded by` and keep it |
| A glossary term already exists | Amend it in place, never add a duplicate |

Two people can pick the same number on different machines. `brain sync` moves the later one to the next free number and fixes its parent's Revisions line.

## How the graph is shared

The built graph (`graph.json` and its reports) is committed in the brain, so a fresh clone can query it right away. Only `/absorb` commits it, and the brain's own pre-commit hook refuses those files otherwise. Anyone can run `graphify update .` locally to get a fresher graph to query. That local build is never committed, and the next sync or pull replaces it when upstream has a newer one.

Hand-written notes in `graphify-out/` (any `.md` or `.html` other than the reports) are tracked and synced like ADRs.

## Upgrading

When this template gets fixes:

```bash
.brain/scripts/brain upgrade
```

It fetches `TEMPLATE_REMOTE` and overwrites `scripts/`, `skills/` and `CLAUDE.snippet.md`. Your glossary, ADRs and graph stay as they are. It shows the diff stat and leaves the commit to you. Re-run `setup.sh` if new skills arrived.

## CLI

```bash
.brain/scripts/brain lookup billing refunds
.brain/scripts/brain claim refunds "how refunds are recorded"
.brain/scripts/brain release refunds
.brain/scripts/brain next
.brain/scripts/brain next-sub 0003
.brain/scripts/brain me
.brain/scripts/brain sync
```

Run the tests with:

```bash
bash scripts/test.sh
```

## Glossary

**Brain**: The private repo cloned at `<project>/.brain` that holds one project's glossary, ADRs and code graph.

**Claim**: A short-lived, pushed marker in `claims/` saying someone is writing about a topic, so nobody else writes the same ADR at the same time.

**Top-level ADR**: An ADR named after a domain (`0003 Payments`), whose body always states the current truth for that domain.

**Sub-ADR**: A record of one later decision inside a domain (`0003.2-jd-refund-retries.md`). Writing one also means updating the top-level ADR it revises.

**Absorb**: The catch-up run that reads merged work, records what qualifies and commits the graph.

## License

MIT-0. See `LICENSE`.

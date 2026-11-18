---
name: absorb
description: Catch the brain up with work merged into the project's main branch since the last run. Rebuilds and commits the code graph, records ADRs and glossary changes from merged PRs or commits, and accepts Proposed ADRs whose branches merged. Use when the user runs /absorb or asks to update the brain from merged work.
---

# Absorb merged work

Only this skill commits the built graph and runs git in `.brain` directly. Formats: `.brain/skills/grill-with-docs/ADR-FORMAT.md` and `.brain/skills/grill-with-docs/CONTEXT-FORMAT.md`.

Read `MAIN_BRANCH` from `.brain/brain.conf`; if it's empty, `.brain/scripts/brain main-branch` gives it. Identity comes from `.brain/scripts/brain me`.

## Steps

1. **Clean tree.** If `git status --porcelain` in the project shows changes, stop and ask the user to commit or stash them.
2. **Claim the run.** Run `.brain/scripts/brain pull`, then read `.brain/state/absorb.json`.
   - If `claimed_by` is someone else and `claimed_at` is less than 24 hours old, stop and tell the user who is running it.
   - Otherwise set `claimed_by` to your `@handle` and `claimed_at` to the current UTC time (ISO 8601). Commit and push it: `git -C .brain commit -qm "absorb: claim by @handle" -- state/absorb.json && git -C .brain push -q`. If the push is rejected, pull and start this step again.
3. **Switch to the main branch.** Remember the current branch (`git rev-parse --abbrev-ref HEAD`), then `git checkout <MAIN_BRANCH> && git pull --ff-only`.
4. **List the new work.**
   - With `gh` available and authenticated: `gh pr list --base <MAIN_BRANCH> --state merged --limit 100 --json number,title,mergedAt,mergeCommit,headRefName`, keeping PRs with a number above `last_pr` (all of them if `last_pr` is null, then process only the latest 20 and say so).
   - Without `gh`: `git log --first-parent --oneline <last_sha>..<MAIN_BRANCH>` (or the last 20 first-parent commits if `last_sha` is null).
5. **Nothing new?** Clear `claimed_by` and `claimed_at`, commit and push `state/absorb.json`, switch back to the original branch and stop.
6. **Rebuild the graph.** Run `graphify update .`. If `graphify --help` lists `label`, also run `graphify label . --missing-only`.
7. **Read each PR or commit.** For each one, oldest first: read the description and diff (`gh pr diff <n>` or `git show <sha>`), and ask the graph about the areas it touches. Then:
   - Write or revise an ADR only where all three criteria in ADR-FORMAT.md hold. Run `.brain/scripts/brain lookup` first; if an ADR covers the domain, write a sub-ADR and update the parent. Set `Status: Accepted` and `Branch` to the PR's branch, and cite the PR or commit. Never invent the reason; use `Why: not recorded; inferred from <PR/commit>`.
   - Amend glossary entries whose meaning the change altered, and add terms it introduced.
   - Note what you skipped and why ("rename only", "easy to reverse", "no trade-off").
8. **Accept merged proposals.** For each ADR with `Status: Proposed`, check whether its `Branch` merged (`git branch -r --merged origin/<MAIN_BRANCH>`, or the PR list). If it did, set `Status: Accepted`.
9. **Commit and push.**
   - Stage the graph: `git -C .brain add -f $(.brain/scripts/brain graph-files | while read -r f; do [ -e ".brain/$f" ] && echo "$f"; done)`, plus `adr/`, `CONTEXT.md` and any write-ups in `graphify-out/`.
   - Set `last_pr` (with `gh`) or `last_sha` (the main branch head) in `state/absorb.json`, clear `claimed_by` and `claimed_at`, and stage it.
   - `ABSORB=1 git -C .brain commit -qm "absorb: <first..last PR or sha> by @handle"`, then `git -C .brain pull -q --rebase --autostash && git -C .brain push -q`.
   - Switch the project back to the original branch.
10. **Report.** List the ADRs and glossary entries written or changed, the ADRs moved to Accepted, and every PR or commit you skipped with the reason.

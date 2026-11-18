---
name: bootstrap
description: Seed an empty brain from the existing code. Builds the code graph, writes the first glossary terms and top-level ADRs for decisions already in the code, and starts the absorb marker at the main branch head. Use when the user runs /bootstrap or setup reports an empty brain.
---

# Bootstrap the brain

Formats: `.brain/skills/grill-with-docs/CONTEXT-FORMAT.md` and `.brain/skills/grill-with-docs/ADR-FORMAT.md`. Identity comes from `.brain/scripts/brain me`. Read `MAIN_BRANCH` from `.brain/brain.conf`; if it's empty, `.brain/scripts/brain main-branch` gives it.

If `.brain/adr/` already holds ADRs, stop and suggest /absorb or /adr instead.

## Steps

1. **Build the graph.** Run `graphify update .` in the project root, then one `graphify query "<a real question about this project>"` to check it returns nodes.
2. **Orient.** Read the README, the manifest files (package.json, pyproject.toml, composer.json, go.mod, Cargo.toml, Gemfile and so on), the top-level layout and `git log --oneline -300`. Use `graphify explain` on the central nodes the graph report names.
3. **Glossary.** Write 10 to 30 terms in `.brain/CONTEXT.md`, grouped under `##` areas. Only terms the code actually uses. End with a `## To confirm` list naming the terms whose meaning you guessed.
4. **ADRs.** Write 3 to 8 top-level ADRs for hard-to-reverse decisions already in the code: data model, auth, money, external integrations, deploy, state management. Get each number from `.brain/scripts/brain next`.
   - `Status: Accepted`, `Branch:` the main branch, `Initiated by:` your handle.
   - Cite the commit or file each one came from.
   - Never invent the reasoning. If it isn't written down in a commit, comment, doc or PR, write `Why: not recorded; inferred from <source>`.
5. **Absorb marker.** Set `last_sha` in `.brain/state/absorb.json` to `git rev-parse <MAIN_BRANCH>`, so /absorb starts from here. Leave `last_pr` null.
6. **Report.** List the terms to confirm and one line per ADR. Tell the user the files ship with the next project push. Don't run git in `.brain`, and don't commit the graph; /absorb does that.

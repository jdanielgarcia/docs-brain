# Glossary format (`.brain/CONTEXT.md`)

Each entry:

```markdown
**Term**:
One or two sentences on what it is in the domain, in plain words.
_Avoid_: aliases, near-synonyms and misreadings not to use
```

Rules:

- **One word per concept.** Pick one term and list the rest under `_Avoid_`. If the code says `Customer`, `Client` and `Account` for the same thing, the glossary picks one.
- **Project terms only.** No general programming concepts (cache, queue, endpoint), no file paths, no class names. If the code name differs from the term, the term still wins in prose.
- **Group when clusters appear.** Put related entries under `##` subheadings (for example `## Billing`, `## Accounts`) once there are a few in the same area.
- **Flag ambiguity.** If one word means two things in the code, say so in the entry and name which meaning the glossary keeps: `Ambiguous: "order" also means sort order in the reports module.`
- **Amend in place.** Before adding a term, check `.brain/scripts/brain lookup <term>`. If it exists, edit that entry. Never add a second one.
- **Guesses go last.** Terms whose meaning you inferred rather than confirmed go in a `## To confirm` list at the end of the file until someone confirms them.

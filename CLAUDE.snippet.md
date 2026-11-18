## Brain (`.brain/`)

This project keeps a shared memory in `.brain/`: a glossary (`.brain/CONTEXT.md`), architecture decision records (`.brain/adr/`) and a code graph (`graphify-out/`).

- **Graph before search.** Ask the graph before grepping or opening files: `graphify query "<question>"`, `graphify path "<A>" "<B>"` for how two things connect, `graphify explain "<concept>"` for one thing. Search and open files once the graph has pointed you somewhere.
- **Glossary words.** Name things in code, tests, commits and issues with the words in `.brain/CONTEXT.md`. If a concept has no entry, use the closest one and say so.
- **Decisions before changes.** Run `.brain/scripts/brain lookup <keywords>` before changing an area and read the ADRs it lists. If your change contradicts one, name it and say what it decides, for example "this contradicts 0004, which keeps invoices immutable".
- **Answer shape for "how/where does X work".** Open with a one-line answer. Give each path its own section and answer the same questions in the same order in each. Cite ADRs by what they decide, not by number alone. Put file:line references in one list at the end, and inferences you didn't check under an "Unverified" heading. Leave out empty sections.
- **Offer to record decisions.** When a task made a decision that is hard to reverse, surprising without context and a real trade-off, or changed what an ADR says, end with one line: "This introduced <decision>. Record it in the brain? (/adr)". Offer once per decision. Never write an ADR without a yes.
- **Brain writes go through skills.** Write to `.brain/` only through /adr, /grill-with-docs, /absorb and /bootstrap.
- **No git in `.brain`.** Don't run git there yourself. The project's push syncs it.
- **Local graph builds stay local.** Running `graphify update .` to refresh the graph before querying is fine. Only /absorb commits the graph.

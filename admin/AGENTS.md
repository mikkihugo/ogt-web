<!-- sf-doc: version=2.80.0 template=AGENTS.md state=pending hash=sha256:dc04211ddd84103bb94b805effcf00f436ea678c1e88301969647ded2e2a787a -->
# Agent Map

Keep this file short. Use it as a table of contents for agents and humans.

- Treat the repo as a purpose-to-software pipeline: intent -> purpose/consumer/contract/evidence -> tests -> implementation -> verification.
- Read `ARCHITECTURE.md` first for the system map and invariants.
- Read `docs/PLANS.md` and `docs/exec-plans/active/` for current work.
- Read `docs/QUALITY_SCORE.md`, `docs/RELIABILITY.md`, and `docs/SECURITY.md` before changing production behavior.
- Put durable product decisions in `docs/product-specs/`.
- Put durable design and architecture decisions in `docs/design-docs/`.
- Put generated reference material in `docs/generated/`.
- Use `docs/RECORDS_KEEPER.md` as the repo-order checklist after meaningful changes.
- Use the `records-keeper` skill when repo docs, plans, or architecture records need triage.
- Follow deeper `AGENTS.md` files when present. The closest one to the changed file wins.

Before implementation, inspect the relevant docs and source files, state observed facts before inferred facts, name the real consumer, and define the command or eval that proves the change.

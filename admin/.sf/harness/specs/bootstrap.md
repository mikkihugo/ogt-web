<!-- sf-doc: version=2.80.0 template=.sf/harness/specs/bootstrap.md state=pending hash=sha256:b86ba7cf2cec39a7a9f9d94f885998cfe26eebfc5b76fdd8375ef125e927e0cf -->
# Bootstrap Spec: Agent Legibility

Verifies that this repo is minimally agent-legible.

## Criteria

- [ ] `AGENTS.md` exists at repo root and is non-empty.
- [ ] `ARCHITECTURE.md` exists at repo root and is non-empty.
- [ ] `docs/exec-plans/active/` exists.
- [ ] `docs/exec-plans/tech-debt-tracker.md` exists.
- [ ] `docs/design-docs/ADR-TEMPLATE.md` exists.

## Verification command

```bash
for f in AGENTS.md ARCHITECTURE.md docs/exec-plans/active/index.md docs/exec-plans/tech-debt-tracker.md docs/design-docs/ADR-TEMPLATE.md .sf/harness/specs/bootstrap.md; do [ -s "$f" ] && echo "OK: $f" || echo "MISSING: $f"; done
```

All lines should start with `OK:` for the bootstrap spec to pass.

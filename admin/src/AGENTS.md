<!-- sf-doc: version=2.80.0 template=src/AGENTS.md state=pending hash=sha256:ac5f874be887aed0bd29105a7c3b7e9269b4b3c0cc7b5b1506da0994c466cf01 -->
# Source Agent Notes

- Start by mapping the owning module and its tests.
- Preserve existing public contracts unless the active plan explicitly changes them.
- Prefer typed/domain helpers over ad hoc parsing or duplicated logic.
- Keep edits scoped to the smallest module boundary that satisfies the plan.
- Update `ARCHITECTURE.md` when a source change creates a new subsystem or invariant.

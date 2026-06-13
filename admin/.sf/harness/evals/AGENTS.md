<!-- sf-doc: version=2.80.0 template=.sf/harness/evals/AGENTS.md state=pending hash=sha256:6f88bf8a2bad95d8db5985c9b3317b9edd65592c12e98bb0bff1a24ec152d768 -->
# Harness Evals Agent Notes

Evals verify behavior that unit tests cannot cover — model output quality, agent decisions, multi-turn flows.

Each eval should include:
- The input fixture or prompt
- The expected output or scoring rubric
- The command to run it (`promptfoo eval`, custom script, etc.)

Keep evals deterministic where possible. Log results to `docs/records/` at milestone close.

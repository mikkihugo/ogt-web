<!-- sf-doc: version=2.80.0 template=.sf/harness/graders/AGENTS.md state=pending hash=sha256:2db17feae1acfe62d85aafbe32d016873c3036d4d76e9dd0db478375fae0794e -->
# Harness Graders Agent Notes

Graders are reusable scripts or prompts that score eval outputs.

- Code-based graders: shell scripts or test files that check structured outputs deterministically.
- LLM-judge graders: prompt templates that ask a model to score free-text output against a rubric.

Prefer code-based graders. Add LLM-judge graders only when deterministic checking is impossible.

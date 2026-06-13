<!-- sf-doc: version=2.80.0 template=.sf/harness/AGENTS.md state=pending hash=sha256:685c41e601340086b8076263a71315c66554efdaeb074bc1b907eebf879174c6 -->
# Harness Agent Notes

The harness is SF-local operational scaffolding the agent can read and verify against.

- `specs/`: behavior contracts. Each spec states what "done" looks like and the command that proves it.
- `evals/`: task definitions for behaviors tests cannot cover — model output quality, multi-turn flows, agent decisions.
- `graders/`: reusable grader scripts (code-based checks, LLM-judge prompts used by evals).

**Rule:** Before marking a task done, run the relevant spec's verification command. Record the result in the completion summary or execution plan.

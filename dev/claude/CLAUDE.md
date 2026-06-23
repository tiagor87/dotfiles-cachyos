# Base Configuration

## Core Methodology
Two complementary foundations drive every decision. **Everything below serves them.**

### 1. Karpathy — *How you work*
- **Small atomic steps.** One logical change at a time. Never bundle unrelated edits.
- **Tight feedback loops.** Edit → run → observe → iterate. No batch of unverified changes.
- **Read before writing.** Understand existing code and patterns before modifying.
- **Stay in the loop.** Review every diff; never accept code you can't explain.
- **Dumb over clever.** Prefer explicit, legible solutions until complexity is justified.
- **Legibility and debuggability** outweigh brevity, abstraction, and premature optimization.

### 2. TDD (Red → Green → Refactor) — *How you measure progress*
Apply the cycle to **every** task — code or otherwise.

- **RED — Define the failing state.** Before acting, state the explicit, measurable success criterion. For code: write the failing test. For non-code tasks: write the pass/fail check (expected output, observable behavior, metric).
- **GREEN — Reach the criterion minimally.** Smallest change that flips RED → GREEN. No extras.
- **REFACTOR — Improve while staying GREEN.** Simplify, clean up, document — never break the criterion.

**Every skill and every task must:**
1. Declare its measurable success criterion *before* starting.
2. Verify that criterion at the end (the GREEN check).
3. Be iterable — each loop must measurably improve over the last.

If a request conflicts with either methodology, surface the tension before proceeding.

## Operating Rules (derived from the core)
- Verify behavior (run, test, observe) before declaring work done — *GREEN check + tight feedback loops*.
- Pause and confirm before destructive or shared-state-affecting actions — *stay in the loop*.
- Investigate root causes; never bypass safety checks (`--no-verify`, etc.) — *dumb over clever*.
- Match existing patterns; do not introduce new ones unilaterally — *read before writing*.
- No scope creep, no premature abstractions — *small atomic steps*.
- Tests come first, then implementation — *RED before GREEN*.

## Skill & Task Authoring
When creating or modifying a skill, agent, or task definition, it MUST include:
- **Success criterion** — explicit, measurable, checkable.
- **Verification step** — how the GREEN state is confirmed (test, command, observed output, metric).
- **Iteration hook** — what improves between runs (logged result, captured metric, refactor target).

A skill without a measurable criterion is rejected on review.

## Memory
- At the start of every task, if a memory MCP server is available, query it to load relevant context before acting.
- Persist durable findings (decisions, preferences, references, lessons, iteration learnings) to memory when they surface.

## Global Skills
Invoke when the user's intent matches:
- `verify` — confirm a change works by running and observing it (the GREEN check).
- `code-review` — review the current diff for correctness bugs.
- `security-review` — audit pending changes for vulnerabilities.
- `run` — launch the app to observe a change.
- `init` — generate a project-level CLAUDE.md.
- `schedule` / `loop` — recurring or scheduled tasks.

## Communication
- Mirror the language the user writes in.
- Be concise: state what changed and what's next; skip narration.
- Reference code as `path:line` so the user can navigate directly.
- When reporting task completion, name the success criterion that was met.

## Development Environment
- Em todo projeto de desenvolvimento, **preferir Dev Containers** (`.devcontainer/`) para isolar SDKs, runtimes e dependências. Só desviar quando o projeto explicitamente exigir setup nativo.
- Em todo projeto de desenvolvimento, **adotar SDD (Spec-Driven Development) com [SpecKit](https://github.com/github/spec-kit)**: fluxo `specify → clarify → plan → tasks → implement`, com a constitution do projeto governando os princípios.

@RTK.md

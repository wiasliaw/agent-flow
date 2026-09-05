---
name: prototype
description: >-
  Answers open technical questions with throwaway experiments, capturing
  the question, approach, and evidence — never the code itself.
---

# Prototype phase

Prototype answers open technical questions left by Explore by running
throwaway experiments — writing down the question, the approach, the
evidence, and the conclusion. The experiment code itself never becomes part
of the shipped product.

## Precondition

- **Dependency**: the Explore phase must be complete, and its "open technical
  questions" list (in `changes/<unit>/explore.md`) must be non-empty. If that
  list is empty, this phase has no reason to exist — PROMPT.md defines
  Prototype as answering technical questions, and there are none to answer.

- **When driven by `orchestrate`**: `orchestrate` reads `explore.md`'s open
  question list and only triggers this phase when it is non-empty. If it is
  empty, `orchestrate` records the skip directly (`state.json.phases.prototype
  = {"status": "skipped", "reason": "no open technical question"}`) and moves
  straight on to Spec, without invoking this skill at all.

- **When invoked directly by the user** (`/agent-flow:prototype`): this skill
  must check for itself whether `changes/<unit>/explore.md` exists and
  `state.json.phases.explore.status == "done"`.
  - If either condition fails: refuse to run, and tell the user to finish
    Explore first.
  - If Explore is done but its open-question list is empty: still allow the
    run. The user may want to validate a question that Explore's output
    didn't capture. This is a deliberate exception available only to a direct
    user invocation — the "skip when the list is empty" rule exists purely as
    a shortcut for `orchestrate`'s automatic continuation; it is not a hard
    restriction on the user manually running Prototype.

## Procedure

1. Dispatch `agent-flow:prototyper` with the Agent tool
   (`subagent_type: "agent-flow:prototyper"`), passing the open technical
   question list from `changes/<unit>/explore.md`. Require it to:
   - For every open question, write throwaway experiment code into
     `changes/<unit>/prototype/` — **never** into any production source path
     (e.g. `src/`). This is the core prohibition behind the "never ships to
     production" discipline (see "Coordination with production code" below).
   - Actually run each experiment and capture real evidence (command output,
     logs, measurements, etc.).
   - Produce `changes/<unit>/prototype.md` (see "Artifact" below).

2. Once `prototyper` finishes, dispatch `agent-flow:prototype-reviewer`,
   passing the path to `prototype.md`, the `prototype/` directory, and the
   current round number. `prototype-reviewer` actually re-runs the experiment
   code under `prototype/` to confirm the claimed evidence is reproducible.

3. Read the reviewer's verdict using the `quality-loop` internal skill's JSON
   output contract:
   - `"pass"`: set `state.json.phases.prototype = {"status": "done",
     "artifact": "prototype.md"}`, commit with message
     `flow(<unit>): prototype passed review`, then auto-continue into Spec.
   - `"reject"` with a finding whose `rootCause` is
     `"implementation-issue"`: re-dispatch `agent-flow:prototyper`, attaching
     `prototype-reviewer`'s `findings`, and increment the round count.
   - `"reject"` with a finding whose `rootCause` is `"approved-artifact"`:
     the root cause likely traces back to `discuss.md` (a misunderstanding of
     intent that pointed the experiment in the wrong direction). Escalate to
     the user through the standard escalation path — do **not** automatically
     send this back to `prototyper`.

4. Cap at 3 rounds. If round 3 still ends in `"reject"`, escalate per the
   orchestrator's round-limit escalation procedure instead of dispatching
   another round.

## Artifact: `changes/<unit>/prototype.md`

Fixed four sections (the four elements from PROMPT.md: question / approach /
evidence / conclusion):

```markdown
# Prototype: <unit-name>

## Questions

<Which open technical question(s) left by Explore this experiment answers — list each one it maps to>

## Approach

<Experiment design, technology/tools used, where the experiment code lives (relative path under prototype/)>

## Evidence

<Actual execution results: command output, logs, measurements — must be reproducible by prototype-reviewer>

## Conclusion

<For each question: resolved or not; if not, what is still missing>
```

## Experiment code: `changes/<unit>/prototype/`

The throwaway experiment code itself. It is committed to version control (not
placed in `/tmp` or otherwise excluded). Its internal directory structure is
unconstrained — organize it however the experiments need, for example one
subdirectory per question.

## Coordination with production code (the "never ships" discipline)

Three rules enforce keeping experiment code out of the shipped product:

1. `prototype/` lives at `.agent-flow/changes/<unit>/prototype/` — never
   under any production source path (e.g. `src/`). `prototyper`'s system
   prompt already prohibits writing there; in this phase's quality loop,
   `prototype-reviewer` additionally checks that `prototyper` did not
   accidentally write anything outside `prototype/` (for example, an
   "opportunistic" test file dropped into `src/` along the way).
2. The authoritative "zero production dependency" audit — whether any
   production code imports or otherwise depends on `prototype/` — does
   **not** happen in this phase. That final check belongs to the Review
   phase, performed by `review-spec-compliance-auditor`. This phase's
   `prototype-reviewer` only needs to confirm that the experiment code it is
   reviewing right now was not referenced from a production path; it does
   not need to run a final zero-dependency scan over the whole unit's state
   (Dev phase hasn't even happened yet at this point).
3. At Wrap time, `prototype/` moves along with the rest of `changes/<unit>/`
   into `archive/<date>-<unit>/` as-is, with no further integration into the
   product. This phase performs no archiving itself.

## Quality loop

Standard loop, single independent reviewer, capped at 3 rounds: `prototyper`
writes the experiments and the artifact → `prototype-reviewer` independently
verifies that each open question was actually answered and that the evidence
is credible, by actually re-running the experiment code → cap 3 rounds →
escalate to the user.

## Approval gate

None. Prototype is not an approval gate. Once the quality loop passes, the
workflow auto-continues into Spec without waiting for user input.

## Standalone invocation behavior (when not driven by `orchestrate`)

- **Precondition not met** (`explore.md` missing, or Explore not yet done):
  refuse to run, and tell the user to finish Explore first.
- **On completion**: this skill does **not** auto-continue into Spec. Once
  the quality loop passes, tell the user that Prototype is complete and that
  they can continue with `/agent-flow:spec`.

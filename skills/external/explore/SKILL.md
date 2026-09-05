---
name: explore
description: >-
  Investigates the existing codebase and external options to confirm the
  approved intent is actually feasible.
---

# Explore

Explore is the second of the eight agent-flow phases. It investigates
whether the intent approved at the Discuss gate is actually feasible, by
looking both inward (the existing codebase) and outward (external technical
options). Explore is not a commitment point: once its quality loop passes,
the work unit auto-continues without waiting for user approval.

## 1. Precondition

Explore depends on the Discuss gate having been approved:
`state.json.gates.discuss.approvedAt != null`.

- **Driven by `orchestrate`**: this phase is triggered automatically once
  the Discuss gate is approved — no separate user invocation is needed.
- **Invoked directly by the user as `/agent-flow:explore`**: this skill must
  check the precondition itself before doing anything else. Read
  `changes/<unit>/state.json` and check `gates.discuss.approvedAt`:
  - If it is `null` (Discuss has not been approved yet, or
    `changes/<unit>/discuss.md` does not even exist), refuse to run and tell
    the user: "This work unit has not passed the Discuss gate yet. Please
    run `/agent-flow:discuss` first."
  - Otherwise, proceed with the procedure below.

## 2. Procedure

1. Dispatch `agent-flow:explorer` (see `agents/explorer.md`) with the Agent
   tool, passing the path to `changes/<unit>/discuss.md` in the prompt, and
   require it to:
   - Investigate the existing codebase: read existing source code, existing
     tests, and existing dependencies to determine what the current state
     of the project means for the approved intent.
   - Investigate external technical options: look up official
     documentation, technical alternatives, and known limitations, whenever
     the work touches an unfamiliar dependency or a new technology choice.
   - Cover **both** sides regardless of how the unit looks. Do not skip
     either investigation just because the unit appears to be a clear
     greenfield case (still check whether existing conventions,
     architecture, or toolchain constrain the new feature) or a clear
     brownfield case (still check whether a better external technical
     option is available).
   - Write the findings to `changes/<unit>/explore.md` (see §3 for the
     required structure).
2. Once `explorer` finishes, dispatch `agent-flow:explore-reviewer` (see
   `agents/explore-reviewer.md`) with the Agent tool, passing the path to
   `explore.md` and the current round number in the prompt.
3. Read the reviewer's verdict, using the standard JSON contract defined by
   the `quality-loop` internal skill, and route as follows:
   - **`"pass"`**: set `state.json.phases.explore.status = "done"`, commit
     with message `flow(<unit>): explore passed review`, then move on to the
     auto-continuation decision in §5 — no user approval is required.
   - **`"reject"` with `findings[].rootCause == "implementation-issue"`**:
     re-dispatch `agent-flow:explorer` with the Agent tool (a fresh call,
     same `subagent_type`; Explore does not use worktree isolation, so this
     is a plain re-dispatch, not a `SendMessage` continuation), passing along
     `explore-reviewer`'s `findings` so it knows what to fix.
   - **`"reject"` with `findings[].rootCause == "approved-artifact"`**: the
     only approved artifact that exists during Explore is `discuss.md` (the
     Discuss gate has already passed), so `escalation.targetArtifact` will
     be `"discuss"`. If the reviewer determines the real root cause is that
     the Discuss summary itself is misleading or incomplete, this is
     escalated to the user immediately — per the approved-artifact routing
     rule, this is never auto-retried against `explorer`, because the fault
     does not lie with `explorer`.
4. The loop is capped at **3 rounds**. If the round limit is reached without
   a `"pass"` verdict, escalate per `spec/05-orchestrate.md` §4.6 (append an
   `ESC-<n>` entry to `decisions.md` and to `state.json.escalations`, and set
   `qualityLoops.explore.status = "escalated"`).

## 3. Artifact

`changes/<unit>/explore.md`, with exactly these three sections:

```markdown
# Explore: <unit-name>

## Internal codebase findings

<Findings about existing code, existing tests, existing dependencies, and
existing architectural conventions, each backed by a cited file path.>

## External technical findings

<External technical options, references to official documentation, and
known limitations, each backed by a cited source link.>

## Open technical questions

- <Question 1 — a concrete technical question that can only be answered by
  running an experiment>
- <Question 2>

(If there are none, write "None" here — this tells the Prototype phase it
can be skipped.)
```

The "Open technical questions" list is the direct input the Prototype phase
uses to decide whether it should run at all: if this list is empty,
Prototype is skipped entirely.

## 4. Quality loop

Standard loop (single reviewer, capped at 3 rounds): `explorer` writes
`explore.md` → `explore-reviewer` independently reviews it for obvious
omissions and unsupported conclusions → on rejection, send back to
`explorer` to fix → capped at 3 rounds → escalate to the user.

## 5. Not a commitment point

Explore is not a gate. Once its quality loop passes, `orchestrate` reads the
"Open technical questions" section of `explore.md` and decides
automatically, with no user input and no waiting message shown:

- **List is non-empty**: automatically proceed to the Prototype phase.
- **List is empty**: skip the Prototype phase entirely and set
  `state.json.phases.prototype = {"status": "skipped", "reason": "no open
  technical question"}`, then proceed directly to the Spec phase.

## 6. Behavior when invoked standalone (not via `orchestrate`)

- If the precondition in §1 is not met, refuse to run and show the message
  defined there.
- Because no `orchestrate` session is driving this invocation, this skill
  itself takes on the minimal orchestrator responsibility of writing
  `state.json` (per `spec/02-state.md`'s state-management rules) for the
  phase-status and quality-loop transitions described in §2 and §4 — it
  must not delegate this write to a subagent.
- Once the quality loop passes, this skill does **not** automatically
  continue into Prototype or Spec (continuation logic belongs to
  `orchestrate` only). Instead, tell the user: "Explore is complete. Open
  technical questions: <yes/no>. Continue with `/agent-flow:prototype` (if
  there are open questions) or `/agent-flow:spec` (if there are none)."

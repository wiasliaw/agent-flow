---
name: ticket
description: Splits the approved spec into verifiable tickets, each shipped with a real, currently-failing test — no implementation until you approve.
---

# Ticket

Ticket is the fifth of the eight agent-flow phases, and one of the four
approval gates (Discuss, Spec, Ticket, Review). It splits the approved delta
spec into small, independently verifiable tickets, each backed by a real,
currently-failing test — no implementation happens until you approve this
gate. Ticket is also the origin point of the test contract enforced later in
Dev: once you approve, every ticket's test becomes a locked artifact that
`dev-worker` is not allowed to modify.

## 1. Precondition

Ticket depends on the Spec gate having been approved:
`changes/<unit>/spec-delta.md` must exist, and
`state.json.gates.spec.approvedAt` must not be `null`.

- **Driven by `orchestrate`**: this phase is triggered automatically once
  the Spec gate is approved — no separate user invocation is needed.
- **Invoked directly by the user as `/agent-flow:ticket`**: this skill must
  check the precondition itself before doing anything else.
  - If `changes/<unit>/spec-delta.md` does not exist, or
    `state.json.gates.spec.approvedAt` is `null`: refuse to run and tell the
    user: "This work unit has not passed the Spec gate yet. Please run
    `/agent-flow:spec` and get it approved first."
  - Otherwise, proceed with the procedure below.

## 2. Work unit determination

Because Ticket may be invoked standalone (not via `orchestrate`), the
session running this skill must first determine which work unit it is
operating on:

1. If the current git branch matches `flow/<unit-name>`, treat that as the
   work unit.
2. Otherwise, if `.agent-flow/changes/` has exactly one subdirectory, treat
   that one as the work unit.
3. Otherwise (zero or multiple candidates, and the branch name does not
   match a unit), stop and ask the user which work unit to operate on
   (list every subdirectory under `changes/` as a candidate).

## 3. Procedure

1. Determine the work unit (§2).
2. Read the approved `changes/<unit>/spec-delta.md`. This is the sole
   source of requirements for the tickets that get written; nothing outside
   it should be introduced as new scope.
3. Dispatch `agent-flow:ticket-writer` (see `agents/ticket-writer.md`) with
   the Agent tool (`subagent_type: "agent-flow:ticket-writer"`), passing the
   path to `spec-delta.md` in the prompt (not its full contents), and
   require it to:
   - For every requirement, or logically independent group of requirements,
     in `spec-delta.md`, write one ticket file under
     `changes/<unit>/tickets/<ticket-id>.md`, following the ticket
     frontmatter schema in §4 and the red-before-green contract defined by
     the `tdd-guide` internal skill.
   - Give every ticket a `requirementRefs` entry tracing back to one or more
     requirement numbers in `spec-delta.md` — never write a ticket with no
     requirement backlink.
   - Write a real, executable test for each ticket (never a skeleton or a
     checklist), place it in the project's existing test directory structure
     (§5), and **actually run** that test command, confirming it fails
     (red) because the corresponding functionality is not implemented yet —
     not because of a syntax or environment error.
   - Set each ticket's `dependsOn` field according to the criteria in §6.
   - Assign ticket `id`s in the format `TICKET-<3-digit sequence>` (e.g.
     `TICKET-001`), incrementing within this work unit only, never reusing
     a number that belonged to a deleted ticket.
   - Set every new ticket's `status` to `draft`.
4. Once `ticket-writer` reports the batch complete, dispatch
   `agent-flow:ticket-reviewer` (see `agents/ticket-reviewer.md`) with the
   Agent tool **exactly once for this round** — a single dispatch that
   reviews the entire batch of tickets and their tests together, passing
   the path to `changes/<unit>/tickets/` and the current round number. This
   is not one dispatch per ticket; it is one review pass over the whole
   batch. Require it to check, separately for every ticket in the batch:
   - **The test genuinely executes.** Re-run the test command independently
     and confirm there is no syntax error or environment problem preventing
     it from running at all.
   - **The red is genuine and for the correct reason.** The test runner's
     failure output must be an assertion failure reported by the test
     framework itself (e.g. `AssertionError`, a failed
     `expect(...).toBe(...)`) — never any of the following, which count as
     a false red: a module-load error (`ImportError` /
     `ModuleNotFoundError` / `Cannot find module`), a syntax error, the test
     runner failing to start at all (an exit code that is not the test
     framework's own defined failure code), or a timeout. If the red traces
     to any of those causes, mark that ticket as problematic with the
     reason "environment-error red, not a valid test."
   - **The requirement backlink is correct.** Every number in the ticket's
     `requirementRefs` must actually exist in `spec-delta.md` and match its
     stated meaning.
5. `ticket-reviewer` reports **one** verdict covering the whole batch (never
   a separate verdict per ticket), using the standard JSON contract defined
   by the `quality-loop` internal skill:
   - **`"pass"`**: every ticket in the batch passed all three checks —
     proceed to §7.
   - **`"reject"`**: `findings[]` lists every ticket found to have a
     problem, each finding explicitly naming the ticket id it applies to.
     Because the Ticket phase has not been approved yet, every finding's
     `rootCause` is `"implementation-issue"` — there is no already-approved
     artifact for this phase to be overturning. Send the **entire batch**
     back to `ticket-writer` in a single re-dispatch, attaching the
     findings: `ticket-writer` only needs to fix the tickets named in the
     findings, not rewrite every ticket in the batch, but this retry (fix →
     re-review the full batch) counts as one single round, not one round
     per fixed ticket.
6. Update `state.json.qualityLoops.ticket.rounds` (single key `"ticket"` —
   shared across the whole batch; never a per-ticket key such as
   `ticket:<ticket-id>`). Cap at **3 rounds**. If round 3 is still
   `"reject"`, escalate per `orchestrate`'s round-limit escalation
   procedure: append an `ESC-<n>` entry to `changes/<unit>/decisions.md` and
   a matching entry to `state.json.escalations`, and set
   `qualityLoops.ticket.status = "escalated"`.
7. Once the whole batch passes review, move to the approval gate (§7 below).

## 4. Ticket file format

Each ticket lives at `changes/<unit>/tickets/<ticket-id>.md`, where
`<ticket-id>` matches the file name minus `.md` (e.g. `TICKET-001`).
Frontmatter fields:

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | string | yes | Matches the file name, e.g. `TICKET-001`. |
| `title` | string | yes | One-line summary. |
| `status` | string enum | yes | `draft` \| `approved` \| `in_dev` \| `in_review` \| `merged` \| `escalated`. Ticket phase only ever sets `draft` (on write) and `approved` (on gate approval) — the remaining values are advanced later, during Dev. |
| `dependsOn` | array\<string\> | yes (may be empty `[]`) | Ids of tickets this one depends on. This field is the authoritative source of the dependency graph — `state.json` only mirrors it. |
| `requirementRefs` | array\<string\> | yes | Requirement numbers from `spec-delta.md` this ticket implements, e.g. `["1.1", "1.2"]`. |
| `testFiles` | array\<string\> | yes, must be non-empty by the time Ticket completes | Paths to this ticket's test file(s), relative to the project root (see §5) — never a `.agent-flow/`-relative path. |

Example:

```markdown
---
id: TICKET-002
title: Send password reset email with time-limited token
status: draft
dependsOn: [TICKET-001]
requirementRefs: ["1.2", "2.1"]
testFiles:
  - tests/auth/test_password_reset_email.py
---

## Description

<what this ticket implements, referencing the requirement numbers above>

## Acceptance criteria (mapped to EARS requirements)

- **1.2**: WHEN a user requests a password reset THE SYSTEM SHALL send a
  reset link valid for 1 hour.

## Corresponding tests

- `tests/auth/test_password_reset_email.py`: `test_reset_link_sent_on_request`
```

## 5. Test file location

The test code itself is written into the **consumer project's existing test
directory structure** (for example `tests/`, `__tests__/` — whichever
convention the project already follows; if the project has no existing test
directory yet, follow that language/framework's community convention
instead). Tests are never written under `.agent-flow/`.

This placement is required because the test code must later be consumed and
turned green by the Dev phase, and the Wrap phase re-runs the entire test
suite against the merged `main` branch — the tests must be part of the
project's ordinary test suite so that a normal test command (`npm test`,
`pytest`, etc.) discovers and runs them. Each ticket's `testFiles`
frontmatter field records these paths, relative to the project root.

## 6. `dependsOn` determination

A ticket `B` depends on ticket `A` (`B`'s frontmatter lists `A`'s id in
`dependsOn`) when `B`'s implementation logically must be built on top of
`A`'s output — for example, "send the password-reset email" depends on
"generate the password-reset token."

The test: would starting `B`'s implementation before `A` is done make `B`
impossible to verify independently, or force it to mock an interface that
`A` has not created yet? If yes, `B` depends on `A`. This is a judgment
about implementation order, not about file read/write order — two tickets
that happen to touch the same file are not automatically dependent on each
other unless this test is met.

## 7. Approval gate

Once the whole batch of tickets passes review (§3 step 5), present the
ticket list to the user: for every ticket, its title, its `dependsOn`, and
its `testFiles`. Ask explicitly whether to approve moving into Dev.

- **If the user approves**:
  1. Flip every ticket's `status` from `draft` to `approved`.
  2. Update `state.json`: `phases.ticket.status = "done"`,
     `phases.ticket.artifact = "tickets/"`, write
     `gates.ticket = {"approvedAt": <now>, "approvedBy": "user"}`, and
     mirror every ticket's frontmatter (`status`, `dependsOn`,
     `requirementRefs`) into `tickets.<id>`.
  3. Commit with message `flow(<unit>): ticket passed review`.
  4. From this point, every ticket and its test are **approved artifacts**:
     `dev-worker` is not allowed to modify a ticket's test files during Dev.
     If it believes a test is wrong, it must stop and surface the problem
     instead of editing it, so it can be routed through the escalation path
     instead of silently overturning an approved artifact.
  5. If this phase was driven by `orchestrate`, auto-continue into Dev. If
     invoked standalone, stop here (see §8).
- **If the user asks for changes instead of approving**: treat this as an
  additional revision round handled the same way as a `"reject"` in §3 step
  5 — send the ticket(s) needing changes back to `ticket-writer` — but do
  **not** count it toward `qualityLoops.ticket.rounds`, because this is a
  direct user intervention, not a reviewer rejection.

## 8. Standalone invocation behavior

- If the precondition in §1 is not met, refuse to run and show the message
  defined there.
- Because no `orchestrate` session is driving this invocation, this skill
  itself takes on the minimal orchestrator responsibility of writing
  `state.json` for the phase-status, quality-loop, and gate transitions
  described in §3 and §7 — it must not delegate this write to a subagent.
- Once you approve the Ticket gate, this skill does **not** automatically
  continue into Dev. Tell the user: "Ticket is approved. Continue with
  `/agent-flow:dev`, or hand off to `/agent-flow:orchestrate` to drive the
  rest automatically."

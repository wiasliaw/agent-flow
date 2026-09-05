---
name: using-worktree
description: >-
  Load this only as the orchestrator, before creating or resuming a
  ticket's isolated worktree — the branch/baseRef precondition, the
  same-agent SendMessage resume rule, and worktree cleanup after merge.
user-invocable: false
---

# using-worktree

## Scope

This skill is loaded **only by `orchestrate`**. Creating, resuming, merging, and
cleaning up a ticket's Dev-phase worktree is done entirely by the main session:

- `dev-worker` does not preload this skill — it does not need to know how to
  create or resume a worktree, it only works inside a worktree that already
  exists.
- `wrap-executor`'s leftover-worktree cleanup is a generic safety-net cleanup
  step and is unrelated to the create/resume rules defined here, so it does
  not preload this skill either.

The reason only the orchestrator ever performs these actions is rule 2 below:
resume-completion notifications are delivered only to the main session.

## Rules

### 1. Precondition before creating a ticket worktree

Before creating a ticket's worktree, the orchestrator must first `git checkout`
the unit branch `flow/<unit-name>`, and when calling `dev-worker` must
explicitly set `worktree.baseRef: "head"`. Never rely on the default value
`"fresh"`.

Rationale: the official semantics of `"fresh"` is "fork from the remote
default branch." Testing only observed the fork point following the current
checkout in a repo with **no remote**. Once a project has a remote, relying on
the unset default — hoping it will automatically track the current branch —
can cause every ticket to fork from the remote's `main` instead of the unit
branch's accumulated progress, which breaks the design premise that multiple
tickets stack incrementally on top of the same unit branch.

### 2. Resume rule when a review rejects

When `dev-reviewer` rejects a ticket, the orchestrator (main session) must
**itself** use `SendMessage` to resume the `dev-worker` call using the
`agentId` returned by that original call. It must **not**:

- Re-dispatch via the Agent tool (even with the same `subagent_type`) —
  re-dispatching always produces a brand-new worktree; the prior
  implementation and worktree contents are not preserved.
- Delegate the resume to any intermediary subagent instead of doing it itself
  — when `SendMessage` resumes an already-completed subagent, the completion
  notification is delivered only to the **main session**, never to the
  subagent that initiated the resume. If an intermediary subagent were to
  resume on the orchestrator's behalf, it would wait indefinitely for a
  notification that never arrives.

### 3. Parallel dispatch and batch scheduling

At the start of Dev phase, the orchestrator computes the set of tickets whose
`dependsOn` are all already complete (i.e., the corresponding tickets have
been merged into the unit branch). It issues the Agent tool calls for every
ticket in that set within the **same turn** of its own response (multiple
calls in one turn = parallel dispatch). It then waits for the entire batch to
finish, for each ticket to pass its quality loop, and for each to be merged,
before computing the next batch of unlocked tickets.

When the set of tickets to dispatch exceeds the 20-concurrent-subagent cap,
follow the batching rule defined in the `parallel-dispatch` skill — it is not
redefined here.

### 4. Cleanup after merge

Once a ticket's quality loop passes, the orchestrator merges that ticket
worktree's changes into the unit branch and then **immediately and
explicitly** runs `git worktree remove` (running `git worktree unlock` first
if necessary). Do not rely on Claude Code's automatic cleanup: only worktrees
with no changes are auto-removed on completion, and a Dev-phase ticket
worktree always has changes, so it must always be removed explicitly.

### 5. Dev and Review do not share a worktree

Review phase reviews the diff of the whole, already-merged unit branch — it
does not attempt to read a Dev worktree that has since been removed. This is
naturally consistent with rule 4 (immediate cleanup after merge): the
orchestrator does not need to keep any worktree around between Dev phase and
Review phase.

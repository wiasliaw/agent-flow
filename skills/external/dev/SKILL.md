---
name: dev
description: Implements approved tickets in parallel, one isolated worktree per ticket, until every test goes green and passes independent review.
---

# Dev

Dev is the sixth of the eight agent-flow phases. It implements every approved
ticket, one isolated git worktree per ticket, dispatching one `dev-worker`
instance per ticket as soon as that ticket's dependencies are merged, and
running an independent `dev-reviewer` check on each one before it is merged
into the unit branch. Dev is not an approval gate: once every ticket has been
merged, the flow auto-continues into Review.

## 1. Trigger and precondition

- **Trigger**: `/agent-flow:dev`, or driven by `orchestrate` once the Ticket
  gate is approved.
- **Precondition**: every ticket file under `changes/<unit>/tickets/*.md`
  exists with `status: approved` (`state.json.gates.ticket.approvedAt` is not
  `null`). Each ticket's test has already been confirmed red by the Ticket
  phase's `ticket-reviewer` — this phase trusts that result and does not
  re-verify it before dispatching `dev-worker`.
- **Driven by `orchestrate`**: triggered automatically once the Ticket gate
  is approved — no separate invocation needed.
- **Invoked directly as `/agent-flow:dev`**: this skill must check the
  precondition itself before doing anything else. If any ticket is missing
  or its `status` is not `approved`, refuse to run and tell the user: "This
  work unit has not passed the Ticket gate yet. Please run
  `/agent-flow:ticket` and get it approved first."

## 2. Work unit determination

Because Dev may be invoked standalone (not via `orchestrate`), the session
running this skill must first determine which work unit it is operating on:

1. If the current git branch matches `flow/<unit-name>`, treat that as the
   work unit.
2. Otherwise, if `.agent-flow/changes/` has exactly one subdirectory, treat
   that one as the work unit.
3. Otherwise (zero or multiple candidates, and the branch name does not
   match a unit), stop and ask the user which work unit to operate on (list
   every subdirectory under `changes/` as a candidate).

## 3. Dev-phase worktree precondition check

Before computing the first wave of dispatch, confirm the project has the
settings Dev-phase parallel worktrees depend on:

- **Driven by `orchestrate`**: `orchestrate` already performs this exact
  check right before it enters Dev phase. Do not repeat it here.
- **Invoked directly as `/agent-flow:dev`**: this skill performs the check
  itself:
  1. Read the project's `.claude/settings.json` (a missing file counts as
     "not configured").
  2. Check whether `worktree.baseRef` is set to `"head"`.
  3. **Already `"head"`**: skip straight to dispatch.
  4. **Not set, or set to anything else** (e.g. the default `"fresh"`):
     present this to the user and ask for consent before writing anything:

     ```
     The Dev phase needs every ticket's worktree to branch off the current
     unit branch, not off remote main (otherwise tickets would each start
     from a different point and couldn't correctly stack on top of the same
     unit branch as they accumulate).

     This requires setting the following in .claude/settings.json:
       { "worktree": { "baseRef": "head" } }

     Do you agree to write this project setting?
     ```

     If the user agrees: read the existing `.claude/settings.json` if one
     exists (keep every other existing field untouched, only add/overwrite
     `worktree.baseRef` to `"head"`); if none exists, create a new file
     containing only this field. If the user does not agree: stop — do not
     force entry into Dev phase.
  5. **Regardless of the outcome of steps 2–4**: separately confirm the
     current git branch is the unit branch `flow/<unit-name>`. If it is not,
     check it out (`git checkout flow/<unit-name>`) — this is the session's
     own branch switch, not a project-setting write, so it needs no
     additional user consent.

  Steps 4 and 5 are two complementary preconditions, neither a substitute
  for the other: `baseRef: "head"` alone, without actually being checked out
  on the unit branch, still forks new worktrees from the wrong branch;
  being checked out on the unit branch alone, without `baseRef: "head"`,
  falls back to the default `"fresh"` and may fork from remote `main`
  instead. Both must hold before any ticket worktree is created.

## 4. Parallel dispatch procedure

1. Read every ticket's `dependsOn` from its own frontmatter — that is the
   authoritative source. `state.json.tickets.<id>.dependsOn` is only a
   mirror of it, useful for cross-checking, never for deciding eligibility
   on its own.
2. Compute the set of tickets whose dependencies are all already satisfied:
   `status == "approved"` and every ticket id in its `dependsOn` has
   `status == "merged"` (a ticket with an empty `dependsOn` qualifies
   immediately).
3. If this set is empty while unfinished tickets remain, that is an
   unresolvable dependency deadlock. This should never happen in practice —
   `ticket-writer`'s dependency graph is supposed to be acyclic — but if it
   does happen, stop and escalate: write an ESC entry (append an
   `## ESC-<n>` block to `changes/<unit>/decisions.md`, and push a matching
   element onto `state.json.escalations`) with `rootCause:
   "approved-artifact"` and `escalation.targetArtifact: "ticket"` (the root
   cause is attributed to the Ticket phase's own dependency graph).
4. If the set has 20 or fewer tickets: dispatch every ticket in the set
   within the **same turn** of your response — multiple Agent tool calls
   issued in one turn constitute one parallel "wave." Dispatch each with
   `subagent_type: "agent-flow:dev-worker"` (its own agent definition
   already declares `isolation: worktree`, so every dispatch of it
   automatically gets a brand-new, isolated worktree). The project's
   `worktree.baseRef: "head"` setting confirmed in §3 already applies to
   every worktree this session creates from here on — there is no per-call
   `baseRef` parameter to pass on the dispatch itself.

   ```
   Agent(subagent_type="agent-flow:dev-worker",
         description="Implement TICKET-003",
         prompt="Implement changes/<unit>/tickets/TICKET-003.md. Its test is
                 already confirmed red — do not modify the test file. Once
                 it goes green, commit once inside your worktree and report
                 back your agentId and worktreePath.")
   ```

5. If more than 20 tickets qualify at once: dispatch the first 20, following
   the `parallel-dispatch` internal skill's batching rule; the remaining
   tickets wait for a slot to free up (when a dispatched ticket's quality
   loop passes and it is merged), then get dispatched. Eligibility is judged
   purely by "dependencies satisfied" — first-come-first-served, no extra
   priority ordering among the tickets waiting for a slot.
6. After a ticket's quality loop passes and it is merged (§7), redo steps
   1–5 to check whether this unlocks the next wave of tickets whose
   dependencies are now satisfied.
7. Once every ticket's `status` is `merged`, Dev phase is complete. If
   driven by `orchestrate`, auto-continue into Review.

A ticket that becomes `escalated` (see §6) does not unlock any ticket that
depends on it until it is resolved and eventually reaches `merged`, but this
never blocks unrelated tickets elsewhere in the dependency graph from
continuing their own waves.

## 5. Preconditions for creating each ticket worktree

Every single `dev-worker` dispatch that creates a new ticket worktree
requires both of the following to hold, not just the one-time check in §3:

1. The session is currently checked out on the unit branch
   `flow/<unit-name>`.
2. The project's `.claude/settings.json` has `worktree.baseRef: "head"` set
   — confirmed/written once in §3, and it applies to every worktree this
   session creates afterward. It is a persistent project setting, not a
   parameter passed on each individual Agent tool call (the Agent tool's
   call schema has no `baseRef` field).

Skipping either condition risks — especially on a project with a remote —
every new worktree forking from remote `main` instead of from the unit
branch's accumulated progress, which breaks the design premise that
multiple tickets stack incrementally on top of the same unit branch.

## 6. Quality loop (per ticket, one standard loop each)

Each ticket runs its own independent standard loop, capped at 3 rounds,
tracked under `state.json.qualityLoops["dev:<ticket-id>"]`:

1. `dev-worker` implements until the ticket's test goes green, commits once
   inside its own worktree, and reports completion. Its response includes
   `agentId` and `worktreePath`, both natively returned by the Agent tool
   call result.
2. Set the ticket's `status` to `in_review`, in both its frontmatter and
   `state.json.tickets.<id>.status`.
3. Dispatch `agent-flow:dev-reviewer` via the Agent tool, passing that
   `dev-worker` call's `worktreePath` in the prompt. `dev-reviewer` does not
   get an isolated worktree of its own — it works in its normal execution
   environment and uses `Bash` to `cd` into the given path to run the
   ticket's test and inspect its git history.
4. `dev-reviewer` independently re-runs the ticket's test to confirm it is
   genuinely green, checks the implementation against the ticket and
   `spec-delta.md`, and uses `git diff` to confirm the ticket's test file
   itself was not modified. It reports its verdict using the `quality-loop`
   internal skill's standard reviewer output format:
   - **`"pass"`**: proceed to §7 (merge and cleanup).
   - **`"reject"` with `findings[].rootCause == "implementation-issue"`**:
     personally — the session running this skill, never through an
     intermediary subagent — use `SendMessage` to resume that ticket's
     `dev-worker` `agentId`, attaching `dev-reviewer`'s `findings` and
     asking for a fix. `dev-worker` continues from its existing worktree
     content; it must not rewrite any part that already passed review.
     Once it reports done, return to step 2. This counts toward
     `state.json.qualityLoops["dev:<ticket-id>"].rounds`, capped at 3.
   - **`"reject"` with `findings[].rootCause == "approved-artifact"`** (for
     example, the ticket's test file was modified — per the `tdd-guide`
     skill's rule, this is always classified this way regardless of who
     modified it): immediately write an ESC entry (`decisions.md` +
     `state.json.escalations`, with `ticket` set to this ticket's id), set
     the ticket's `status` to `escalated`, and stop this ticket's loop.
     Wait for the user's decision — this does **not** block any other
     ticket's parallel progress.
   - **Round 3 still `"reject"`**: write an ESC entry with `rootCause:
     "round-limit-exceeded"`, and set the ticket's `status` to `escalated`.

Two hard rules — always follow both:

1. **Never fix a ticket by re-dispatching.** Calling the Agent tool again
   for `dev-worker` — even with the identical `subagent_type` — always
   produces a brand-new, empty worktree; the prior implementation and
   worktree contents are gone. Rework can only happen by using `SendMessage`
   to resume the existing `agentId`.
2. **Never delegate the `SendMessage` resume to an intermediary subagent.**
   When `SendMessage` resumes an already-completed subagent, the completion
   notification is delivered only to the main session — never to whatever
   subagent initiated the resume. If some intermediary subagent (rather
   than the session actually running `/agent-flow:dev` or `orchestrate`
   itself) were to issue that resume, it would wait forever for a
   notification that never arrives. This resume must always be issued
   directly by whichever session is currently executing this skill.

## 7. Merge and cleanup

Once a ticket passes `dev-reviewer`'s review, in order:

1. From the checkout of the unit branch `flow/<unit-name>`, merge that
   ticket's worktree branch into the unit branch (e.g. `git merge --no-ff
   <worktree-branch>`), keeping its commit as its own standalone node — one
   ticket, one commit, never squashed.
2. Once the merge succeeds, immediately run `git worktree remove
   <worktree-path>` (running `git worktree unlock <worktree-path>` first if
   it is locked, then retrying). Do this right away — do not rely on Claude
   Code's automatic worktree cleanup: worktrees with uncommitted or
   unmerged changes are never auto-removed, and a Dev-phase ticket worktree
   always has changes.
3. Update the ticket's `status` to `merged`, in both its frontmatter and
   `state.json.tickets.<id>.status`.
4. Set `state.json.qualityLoops["dev:<ticket-id>"].status` to `"passed"`.
5. Re-run §4's dispatch procedure (step 6) to check whether this unlocks the
   next wave of tickets.

## 8. Artifacts

- Implementation code: lands first inside the ticket's own worktree, then
  merges into the unit branch `flow/<unit-name>` once its review passes.
- `changes/<unit>/tickets/<ticket-id>.md`'s `status` field keeps being
  updated, all the way through `merged` (or `escalated`).

## 9. Approval gate

None. Dev is not one of the four approval gates. Once every ticket's
`status` reaches `merged`, if this phase was driven by `orchestrate`, it
auto-continues into Review with no user approval required.

## 10. Standalone invocation behavior

- If the Ticket gate has not been approved: refuse to run, and show the
  message defined in §1.
- Because no `orchestrate` session is driving this invocation, this skill
  itself takes on the minimal orchestrator responsibility of performing
  §3's worktree precondition check, and of writing `state.json` for every
  ticket-status and quality-loop transition described above — it must not
  delegate any of these writes to a subagent.
- The `SendMessage` resume rule in §6 does not change just because this was
  invoked standalone: a resume must always be issued by whichever session
  is currently running this phase skill, regardless of whether it is
  wrapped by `orchestrate`. When you call `/agent-flow:dev` directly, the
  session running that command is the one responsible for every resume.
- Once every ticket reaches `merged`, this skill does **not** automatically
  continue into Review. Tell the user: "Dev is complete — every ticket has
  been merged. Continue with `/agent-flow:review`, or hand off to
  `/agent-flow:orchestrate` to drive the rest automatically."

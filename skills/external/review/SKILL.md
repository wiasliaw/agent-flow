---
name: review
description: Runs a multi-perspective audit of the whole unit against its spec and tickets, then asks for your approval before wrap-up.
---

# Review

Review is the last of the four approval gates (Discuss, Spec, Ticket, Review).
It audits the whole work unit — the unit branch's entire diff against `main`
— against `spec-delta.md` and the tickets, using a heavyweight quality loop:
three independent review teams collect findings in parallel, then an
independent triage role re-verifies and classifies every finding (a
BMAD-style procedure). Nothing proceeds into Wrap until you approve this
gate.

## 1. Trigger and precondition

- **Trigger**: `/agent-flow:review`, or driven automatically by `orchestrate`
  once every ticket in the Dev phase has reached `"merged"`.
- **Precondition**: every ticket in the work unit has `status == "merged"`
  (i.e. `state.json.tickets.<id>.status` is `"merged"` for every ticket). If
  any ticket is `"escalated"` and has not yet been resolved by the user, this
  phase must not start.

## 2. Work-unit determination

Since this phase may be invoked standalone (not through `orchestrate`), the
session running this skill must first determine which work unit it is
operating on:

1. If the current git branch matches the `flow/<unit-name>` naming pattern,
   that is the work unit.
2. Otherwise, if `.agent-flow/changes/` contains exactly one subdirectory,
   treat that as the work unit.
3. Otherwise (zero or multiple candidates, and the current branch name
   doesn't match), stop and ask the user which work unit to operate on
   (listing every subdirectory under `changes/` as candidates).

## 3. Procedure

1. Determine the work unit (§2) and confirm the precondition (all tickets
   `merged`).
2. Get the unit branch's overall diff against `main`: `git diff
   main...flow/<unit-name>` (Q12 — Review always audits the whole unit
   branch's diff, not per-ticket diffs).
3. **Within the same turn**, dispatch three review teams in parallel, per the
   `parallel-dispatch` internal skill's general rules — the three teams must
   never see each other's process or conclusions:

   - Write the diff itself to a temporary file first (e.g.
     `changes/<unit>/.review-diff-round-<k>.txt` — not a permanent artifact;
     it may be deleted once Review completes). Pass only this file path in
     each of the three dispatch prompts below — never paste the full diff
     text inline (the output-landing principle shared by `parallel-dispatch`
     and DESIGN §5).

   ```
   Agent(subagent_type="agent-flow:review-gap-hunter",
         description="Find gaps for <unit>",
         prompt="Review the diff at <diff-file-path> against
                 changes/<unit>/spec-delta.md and changes/<unit>/tickets/.
                 Report findings using the raw-finding schema defined in
                 the quality-loop internal skill (role: review-gap-hunter).")

   Agent(subagent_type="agent-flow:review-edge-case-hunter",
         description="Find untested edge cases for <unit>",
         prompt="Review the diff at <diff-file-path> against
                 changes/<unit>/spec-delta.md and changes/<unit>/tickets/.
                 Report findings using the raw-finding schema defined in
                 the quality-loop internal skill (role: review-edge-case-hunter).")

   Agent(subagent_type="agent-flow:review-spec-compliance-auditor",
         description="Audit spec compliance for <unit>",
         prompt="Review the diff at <diff-file-path> against
                 changes/<unit>/spec-delta.md and changes/<unit>/tickets/.
                 Also confirm that no file in the production code path
                 imports or otherwise depends on anything under
                 changes/<unit>/prototype/. Report findings using the
                 raw-finding schema defined in the quality-loop internal
                 skill (role: review-spec-compliance-auditor).")
   ```

4. Once all three finish in parallel, each returns its own raw findings —
   the Review raw-finding schema defined by the `quality-loop` internal skill
   (no `verdict`, no `rootCause`; severity is reported as
   `reportedSeverity`, since it is not yet a final judgment).
5. Land each of the three teams' full raw-finding reports into its own file
   (e.g. `changes/<unit>/.review-round-<k>-<role>.json` — temporary,
   deletable once Review completes), then dispatch `agent-flow:review-triage`
   with the Agent tool, passing only those three file paths in the prompt —
   never paste the raw findings directly into `review-triage`'s prompt (same
   output-landing principle).
   - `review-triage` does **not** trust any team's self-reported severity for
     any finding. It personally re-verifies every finding (re-running
     relevant tests, re-reading the code) and returns a verdict using the
     `quality-loop` standard output format: `verdict`, `findings[].severity`,
     `findings[].rootCause`, `findings[].sourceFindingIds`, `escalation`.
     The `rootCause` classification is still computed and returned (it is
     used to categorize findings for presentation, and to determine what
     kind of fix is feasible if the user asks for one — see step 8) but, per
     the S1 decision below, it no longer drives any automatic revert or
     automatic escalation. This is the core difference from the standard
     quality loop's routing.
6. The orchestrator aggregates `review-triage`'s verdict (if `verdict ==
   "pass"`, or `findings` is empty, this round simply has no findings) and
   produces or updates `changes/<unit>/review.md`, listing **every** finding
   from this round regardless of its root-cause category (see "§5 —
   `review.md` structure" below).
7. **Present `review.md` to you (this round's approval-gate interaction)**:
   report this round's finding counts (blocking / non-blocking), the current
   round (`<k>`/5), list every finding along with its root-cause
   classification, and ask:

   > "Here are the issues found this round. Please indicate which ones need
   > to be fixed right away — anything you don't flag is treated as
   > deferred, and does not block approval into Wrap. Do you approve moving
   > into Wrap?"

   (This extends DESIGN §9's journey-step-9 question into a compound
   question: first pick what to fix, then decide on approval.)
8. Handle your reply as one of three cases:
   - **(a) You approve moving into Wrap, and flag no finding for fixing**
     (regardless of whether unresolved non-blocking findings remain — this
     is treated as you knowingly accepting the current state): go to step
     10 (gate passed).
   - **(b) You flag one or more findings to fix**:
     - `rootCause == "implementation-issue"`: the orchestrator, following
       "§4 — pure-implementation-issue fix mechanism" below, dispatches
       **one brand-new** `dev-worker` to handle every such finding you
       approved this round (all within the same worktree, processed in
       sequence — not one worktree per finding, to reduce the risk of
       conflicting fixes within the same round).
     - `rootCause == "approved-artifact"`: the orchestrator does **not**
       dispatch a fix subagent directly. The root cause lies in an already
       approved Spec or Ticket, and per Q5 an approved artifact is never
       overturned by an agent on its own. If you ask for it to be fixed
       anyway, that is equivalent to you actively deciding to reopen the
       corresponding phase, following `spec/05-orchestrate.md` §3.1's
       "user-initiated modification of an approved artifact" mechanism
       (go back to Spec or Ticket, re-run its full quality loop and
       approval gate, recorded in `decisions.md` — this is not a standard
       ESC flow). Only after the reopened phase is complete and the
       affected tickets' Dev phase has re-run to completion does the unit
       re-enter Review.
     - Once both kinds are handled (or at least the part you asked for this
       round is handled), go back to step 2: get a fresh diff and run a
       full new round of Review (all three review teams plus
       `review-triage` re-run from scratch). Increment
       `state.json.qualityLoops.review.rounds` (Q29: a "fix → re-review"
       cycle counts as one round).
   - **(c) You neither approve moving into Wrap nor flag any finding to
     fix** (e.g. you are still deciding): stay in the current state and wait
     for further input. Do not increment the round count and do not
     auto-execute anything.
9. If the loop reaches **5 rounds** (Q29) without your approval into Wrap:
   treat this as non-convergent. Write an ESC entry (`decisions.md` +
   `state.json.escalations[]`, `rootCause: "round-limit-exceeded"`), stop
   auto-rerunning the loop, and clearly tell you that the round limit has
   been reached. From this point everything depends entirely on your
   instructions (e.g. "let's go with this for now, approve into Wrap", or
   some other manual intervention) — do not auto-retry further.
10. Once you approve: set `state.json.phases.review.status = "done"`, write
    `gates.review.approvedAt`/`approvedBy`, and commit with message
    `flow(<unit>): review passed review`. If driven by `orchestrate`,
    automatically continue into Wrap.

## 4. Pure-implementation-issue fix mechanism (S1: a brand-new `dev-worker` forked from the unit branch's tip)

This differs from the Dev phase quality loop's "resume the existing
`dev-worker` via `SendMessage`" mechanism — Review has no "currently
in-progress" `dev-worker` to resume, because Review happens only after every
ticket has already been merged; it does not correspond to any single
in-progress `dev-worker`. The orchestrator follows these steps:

1. Confirm it is currently checked out on the unit branch `flow/<unit-name>`
   (after Dev phase completes, the unit branch should already contain the
   merged results of every ticket).
2. Use the Agent tool to dispatch a **brand-new** `dev-worker`
   (`subagent_type: "agent-flow:dev-worker"`, which already declares
   `isolation: worktree` in its own agent definition) — this is **not** a
   resume, it is a fresh call. The new worktree forks from the unit branch's
   current tip (`worktree.baseRef: "head"`, reusing the project setting
   already confirmed/written during Dev phase per
   `spec/05-orchestrate.md` §2.2 — there is no need to re-check it here),
   so it naturally contains the results of every already-merged ticket.
3. In the prompt, list every `implementation-issue` finding you approved for
   fixing this round (referencing the corresponding section's file path in
   `review.md`, not pasting the full finding text inline, per the
   `parallel-dispatch`/`using-worktree` file-landing principle), and require
   `dev-worker` to process every listed item in sequence.
4. Once `dev-worker` finishes the fixes (and confirms any relevant existing
   tests are still green), it commits once inside its own worktree.
5. The orchestrator merges that worktree's changes into the unit branch
   (mechanism referenced from `spec/11-dev.md`'s "merge and cleanup" section:
   `git merge --no-ff`, then immediately `git worktree remove` after merging
   — not repeated here).
6. Return to "§3 — Procedure" step 2, get a fresh diff, and start the next
   round of Review.

This fix does **not** go through an independent `dev-reviewer` review (unlike
a Dev-phase ticket's quality loop) — the next round of Review's three review
teams plus `review-triage` are themselves an independent verification of this
fix. Stacking an additional review layer on top would only duplicate work.

## 5. `review.md` structure

```markdown
# Review: <unit-name>

## Summary
- Blocking issues: <N>
- Non-blocking suggestions: <M>
- Review round: <k>/5

## Blocking issues

### R1: <one-line summary>
- Severity: blocking
- Location: <file path>
- Description: ...
- Root cause: <implementation-issue | approved-artifact>
- Disposition: <Pending your decision (first presented this round) | You requested a fix — fixed and re-reviewed in round <k> | You chose to defer — does not block approval | You requested reopening Spec/Ticket (see decisions.md)>
- Reported by: <review-gap-hunter | review-edge-case-hunter | review-spec-compliance-auditor>

## Non-blocking suggestions

### R2: <one-line summary>
(same fields as above, with Severity: non-blocking)

## Prototype zero-dependency audit (`review-spec-compliance-auditor`)
- Result: <Pass | Violation found: list of violating file paths>
```

Each `R<n>` corresponds to one entry in `review-triage`'s `findings[]` output
(its `id` is reused as, or mapped to, `R<n>`; `sourceFindingIds` is kept for
traceability back to the originating team's raw finding).

## 6. `review-spec-compliance-auditor`'s extra responsibility

Per DESIGN §8 (the companion discipline for Q18/Q35), this role **must**
explicitly check, within its review scope, that no file under the
production code path (judged by the project's actual structure, e.g. `src/`)
imports or otherwise depends on anything under
`.agent-flow/changes/<unit>/prototype/`. Any violation found **must** be
reported as a **blocking** finding (`reportedSeverity: "blocking"`). This is
one of the necessary conditions for the Review gate to pass — `review.md`
must explicitly record this result in the "Prototype zero-dependency audit"
section.

## 7. Quality loop

Heavyweight loop (Q4/Q29), but its rejection routing differs from every
other standard-loop phase per the S1 decision: there is no automatic revert
and no automatic escalation. Every round's full set of findings — regardless
of root-cause category — is presented to you first, and your choice of what
to fix triggers the next round (see §3 steps 7-8 and §4). Role definitions
live in `agents/review-gap-hunter.md`, `agents/review-edge-case-hunter.md`,
`agents/review-spec-compliance-auditor.md`, and `agents/review-triage.md`.
The output-format contract is the `quality-loop` internal skill's two-tier
Review schema: the three parallel teams report raw findings (no `verdict`,
no `rootCause`), and `review-triage` reports the final verdict (`verdict`,
`findings[].severity`, `findings[].rootCause`,
`findings[].sourceFindingIds`, `escalation`). In the Review context,
`rootCause` no longer drives automatic routing — its role changes to
determining which kind of fix is feasible if you ask for one (§3 step 8).
Capped at **5 rounds**; exceeding the cap goes to ESC
(`rootCause: "round-limit-exceeded"`).

## 8. Approval gate

Yes (Q3). Only after you approve can the unit proceed into Wrap. The
presentation behavior is described in §3 step 7.

## 9. Standalone invocation behavior (Q2)

- If any ticket is not yet `merged`: stop and tell you to finish the Dev
  phase first.
- After approval, this skill does **not** automatically continue into Wrap.
  You must call `/agent-flow:wrap` or `/agent-flow:orchestrate` yourself.

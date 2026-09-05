---
name: wrap
description: Merges, archives, and cleans up fully automatically once review is approved and every test is green — commits locally, never pushes.
---

# Wrap

Wrap is the last of the eight agent-flow phases: a fully automatic close-out
that merges the unit branch into `main`, folds the delta spec into the main
spec, archives the working directory, and removes the branch and any
leftover worktrees. Wrap is not a commitment point — it never stops to ask
for approval. Its only stopping condition is failure: any single
verification failure halts the whole sequence and escalates to the user.

## 1. Trigger and preconditions

- **Trigger**: `/agent-flow:wrap`, or driven automatically by `orchestrate`
  right after the Review gate is approved.
- **Precondition**: the Review gate must already be approved —
  `state.json.gates.review.approvedAt != null`. If it is not, and this skill
  is invoked standalone, see "9. Standalone invocation behavior" below —
  Wrap refuses to run rather than finding a way around the gate.

## 2. Determining the target unit

Since Wrap can be invoked standalone (not via `orchestrate`), the session
running this skill must first determine which work unit it applies to:

1. If the current git branch matches `flow/<unit-name>`, use that unit.
2. Otherwise, if `.agent-flow/changes/` contains exactly one subdirectory,
   treat that as the target unit.
3. Otherwise (zero or multiple candidates, and the branch name does not
   resolve it), stop and ask the user which unit to operate on, listing the
   subdirectories under `changes/`.

## 3. Execution precondition: every test must be green (Q13)

Passing the Review gate is necessary but not sufficient to run Wrap. Before
any merge, spec-merge, archive, or cleanup action happens, the full project
test suite must be re-run from scratch on the unit branch
(`flow/<unit-name>`) and must pass completely. This check is the first
action in the execute-verify sequence below (step 1) — if it fails, Wrap
stops immediately and escalates; it performs no merge, no archiving, and no
cleanup whatsoever.

## 4. Procedure: the execute-verify loop (Q25 — fail once, escalate, never retry)

This phase alternates dispatching `agent-flow:wrap-executor` (which performs
one mechanical action) and `agent-flow:wrap-verifier` (which independently
re-checks that action actually happened) with the Agent tool. After every
single action, verify it before moving to the next one. The instant any
verification fails, stop the entire sequence and escalate (see "6.
Escalation format") — do **not** retry the failed action, and do **not**
proceed to later actions. This is deliberately different from every other
phase's standard/heavy quality loop: there is no round count, no cap, and no
"send it back to the author" path — one failure is enough to stop and hand
control back to the user.

1. **Pretest.** Dispatch `wrap-executor` to run the full test suite on
   `flow/<unit-name>` from scratch.
   - Verify: dispatch `wrap-verifier` to independently confirm the test
     command's exit code and output genuinely represent a full pass — do
     not accept `wrap-executor`'s textual claim alone.
   - On failure: stop, escalate.
2. **Merge the unit branch into `main`.** `wrap-executor` performs a local
   merge only (e.g. `git checkout main && git merge --no-ff
   flow/<unit-name>`) and never pushes (Q13 — pushing is left entirely to
   the user).
   - Verify: `wrap-verifier` inspects `main`'s `git log` and confirms it
     genuinely contains the merge commit, together with the underlying
     per-ticket commit history (kept unsquashed — Q34).
   - On failure: stop, escalate.
3. **Merge the delta spec into the main spec.** `wrap-executor` applies
   `changes/<unit>/spec-delta.md`'s `ADDED`/`MODIFIED`/`REMOVED` blocks into
   `.agent-flow/specs/<domain>/spec.md` (`<domain>` read from
   `spec-delta.md`'s frontmatter), following the merge rules defined by the
   `sdd-guide` internal skill:
   - Each `ADDED` requirement is appended to the domain's `spec.md` (created
     if it does not yet exist).
   - Each `MODIFIED` requirement overwrites the existing entry found at the
     same requirement number.
   - Each `REMOVED` requirement is deleted from the existing entry at the
     same requirement number.
   - Verify: `wrap-verifier` reads the merged `spec.md` and checks, one by
     one, that every requirement in `spec-delta.md` is correctly reflected
     (`ADDED` entries present, `MODIFIED` entries match the new content,
     `REMOVED` entries gone).
   - On failure: stop, escalate.
4. **Archive the work unit.** `wrap-executor` moves the entire
   `changes/<unit>/` directory — `state.json`, `decisions.md`, `prototype/`,
   everything in it — to `archive/<date>-<unit-name>/`, where `<date>` is
   today's date (the date Wrap ran). Note: if `<unit-name>` already carries
   its own date prefix (the `<YYYY-MM-DD>-<slug>` naming convention), the
   archive path will contain two dates. This is intentional, not a bug to
   collapse — the first date is when the archiving happened, the second is
   when the work unit was created, and the two carry different meaning.
   - Verify: `wrap-verifier` confirms `changes/<unit>/` no longer exists,
     and `archive/<date>-<unit-name>/` exists with the same file count as
     before the move.
   - On failure: stop, escalate.
5. **Delete the unit branch and clean up any leftover worktree.**
   `wrap-executor` runs `git branch -d flow/<unit-name>` (a plain `-d` is
   enough since it was just merged), then checks `git worktree list` for any
   worktree still belonging to this unit — under normal operation, Dev-phase
   worktrees should already be gone by this point, so this is a safety-net
   check, not a routine expectation — and removes any that remain with
   `git worktree remove`.
   - Verify: `wrap-verifier` confirms `git branch` no longer lists
     `flow/<unit-name>`, and `git worktree list` no longer contains any path
     belonging to this unit.
   - On failure: stop, escalate (see the archived-path note under
     "6. Escalation format" — by this point step 4 has already run).
6. **Re-run the test suite after the merge.** `wrap-executor` runs the full
   test suite again on merged `main` — a fresh run, not a re-read of step
   1's result (this echoes the "re-run tests on the result after merging"
   pattern from Superpowers, research 04).
   - Verify: `wrap-verifier` independently confirms the exit code and output
     represent a full pass, by actually re-running the suite itself.
   - On failure: stop, escalate. This is the situation most in need of human
     judgment — `main` already contains the merge but the tests are red —
     and per Q25, agent-flow does not auto-revert; see the step-6-specific
     escalation content required below.
7. Once every action above is verified, `wrap-executor` writes
   `changes/<unit>/wrap.md` (by this point in the sequence step 4 has
   already moved the directory, so this file is actually written at its
   final path, `archive/<date>-<unit-name>/wrap.md`). The main session then
   prints a summary to the user: "Local merge complete. Not pushed — please
   push it yourself."
8. `state.json` (likewise already at `archive/<date>-<unit-name>/state.json`
   after step 4) is updated: `phases.wrap.status = "done"`,
   `phases.wrap.artifact = "wrap.md"`. `currentPhase` stays `"wrap"` — the
   work unit is finished and there is no next phase to move to.

## 5. Artifact: `wrap.md`

Fixed structure — a result line followed by one dated, verified record per
action:

```markdown
# Wrap: <unit-name>

## Result: <Success | Failed and escalated at step <n>>

## Per-action record

### 1. Pretest
- Action: ran `<test command>` on flow/<unit-name>
- Execution result: <passed (N tests) | failed (details)>
- Verification result: <wrap-verifier's independent confirmation: passed | failed: reason>
- Timestamp: <ISO 8601>

### 2. Merge the unit branch into main
- Action: `git merge --no-ff flow/<unit-name>`
- Execution result: ...
- Verification result: ...
- Timestamp: ...

(Steps 3–6 follow the same four-line format, in order: merge into the main
spec / archive the unit / delete the branch and clean up worktrees / re-run
tests after the merge.)
```

## 6. Escalation format

Any verification failure escalates using the same ESC format used
everywhere else in agent-flow (`spec/02-state.md` and
`spec/04-internal-skills.md`'s `quality-loop` §6 template): append an
`## ESC-<n>` entry to `decisions.md`, and push a matching entry to
`state.json.escalations[]` with `phase: "wrap"`. Two points are specific to
Wrap:

- **"Phase/round" field.** Wrap's execute-verify loop has no notion of
  rounds, so the template's `Phase／round: <phase> (round <k>/<max>)` line
  is instead filled with the fixed text **"Wrap (no rounds, execute-verify
  loop)"** — never a `<k>/<max>` number pair.
- **Step 6 failure (post-merge test re-run) — required content.** When step
  6 fails, the ESC's "Details" field **must** explicitly pose this question
  to the user: "`main` currently contains the merge result, but the tests
  are not passing — should the merge be reverted?" agent-flow does not
  perform any revert itself (no `git reset --hard` or equivalent) — Q25's
  "fail once, escalate, never retry" principle extends to "never
  auto-revert" as well. The decision is left entirely to the user.

**Where `decisions.md`/`state.json` live when the escalation is written**
(steps 1–3 vs. steps 5–6 differ, because step 4 archives the directory in
between):

- If step 1, 2, or 3 fails, the archive (step 4) has not happened yet — write
  the ESC entry to the original path, `changes/<unit>/decisions.md`, and
  push to the `escalations[]` array in `changes/<unit>/state.json`.
- If step 5 or 6 fails, step 4 has already completed and
  `changes/<unit>/` no longer exists — the ESC entry **must** be written to
  the archived path, `archive/<date>-<unit-name>/decisions.md`, and pushed
  to the `escalations[]` array in `archive/<date>-<unit-name>/state.json`.
  Never write back to the original `changes/<unit>/` path once it no longer
  exists.

## 7. Artifacts (produced by a successful Wrap)

- `changes/<unit>/wrap.md` (final path after archiving:
  `archive/<date>-<unit-name>/wrap.md`) — the per-action execution and
  verification record.
- A merge commit on `main` (with the full per-ticket commit history
  preserved underneath it).
- `.agent-flow/specs/<domain>/spec.md` updated with the delta spec's
  changes.
- `.agent-flow/archive/<date>-<unit-name>/` — the complete snapshot of the
  former `changes/<unit>/`.
- The unit branch and every ticket worktree belonging to it, all removed.

## 8. Approval gate

None. Wrap is fully automatic (PROMPT.md, Q13) — it never pauses for user
approval on success. Its only pause point is a verification failure, handled
as an escalation (§6), not a gate.

## 9. Standalone invocation behavior

If the Review gate is not yet approved
(`state.json.gates.review.approvedAt == null`): **refuse to run**, and tell
the user: "Review has not been approved yet — Wrap cannot run." Do not
perform any action. This is the same hard precondition described in §1/§3
(Review gate approved **and** every test green); Wrap provides no bypass
mechanism (agent-flow deliberately offers no "quick mode" to skip a gate).

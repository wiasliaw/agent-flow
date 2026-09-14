---
name: build
description: >-
  Implements ready tickets in parallel, one isolated worktree per ticket,
  until every contract test goes green and passes independent review.
---

# Build

Before executing, `Read` `${CLAUDE_PLUGIN_ROOT}/references/glossary.md` —
all DSL vocabulary and `INV-n` numbers resolve there. Worktree lifecycle
rules: `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md`.

## 1. Preconditions

```
resolve_unit()
if phases.tdd.status != "done":
  halt("Run /agent-flow:tdd first.")
if any ticket is "draft" or an unruled "escalated":
  halt(list them)
# pending tickets: "ready" (awaiting dispatch) or parked
# "in_build"/"in_review" (appear when restoring from a partial fallback —
# restored by resume, never re-dispatched). First run: all "ready";
# a replay after a fallback may mix "ready"/"merged"/parked states.
if all tickets are "merged" and nothing is pending:
  # full-fallback replay where no ticket was affected
  write_state(phases.build = "done"); auto-continue to Review; return
  # red was already confirmed by the TDD review — do not re-verify here
```

## 2. Preflight (`# INV-13`)

Build asks the user to configure nothing. `make_worktree` names the source
branch, so where a worktree forks from does not depend on any setting.

```
1. ensure .agent-flow/.gitignore exists and contains "worktrees/"
   # write it if absent; without it git add -A commits the worktree
   # as an embedded repository
2. if current branch != flow/$unit: run("git checkout flow/$unit")
   # merges land here; session-local action, no consent needed
```

## 3. Wave dispatch

```
0. partial-fallback restoration: first resume each parked
   "in_build"/"in_review" ticket (original $agent_id, original worktree,
   rounds continue from the preserved value — see the orchestrate skill's
   fallback procedure step 6), then compute waves
1. read every ticket's dependsOn (authority: frontmatter; state.json is
   cross-check only)
2. dispatchable set = tickets with status == "ready" whose dependsOn are
   all "merged"
3. if the set is empty but unfinished tickets remain, rule out IN ORDER
   before declaring deadlock:
     any "in_build"/"in_review" (running or parked)?
       -> wait for their current round to settle (or restore via step 0),
          recompute; not a deadlock
     an unruled "escalated" ticket on the remaining dependency chain?
       -> wait for the user's ruling; not a deadlock
     otherwise ("ready" tickets form an unsatisfiable dependency cycle)
       -> fallback("tdd", "dependency deadlock")
          # partial fallback; affected set = the cycle's tickets;
          # the root cause is the dependency graph itself
4. set size <= 20: make_worktree(t) for every ticket in the wave, then
   issue the whole wave in ONE turn —
   dispatch(worker, role: ticket implementer; refs: tdd-guide.md;
            pass ticket and spec paths, and the ABSOLUTE worktree path
            with an instruction to cd there first)   # INV-13
5. set size > 20: dispatch 20 first, refill as slots free up  # INV-4
6. after each merge, recompute steps 2-5 for the next wave
7. all tickets "merged" -> Build done; auto-continue to Review
   (orchestrate-driven)
```

## 4. Quality loop (per ticket, `qualityLoops.build:<ticket-id>`, cap 3)

```
1. worker implements until the tests turn green, commits ONCE in its
   worktree, reports ($agent_id from the launch result; $worktree_path
   from the completion notification)
2. ticket status -> "in_review"
3. dispatch(reviewer, refs: tdd-guide.md, quality-loop.md;
            pass $worktree_path — the reviewer cd's into it from its own
            normal environment)
4. reviewer independently re-runs the tests, checks the implementation
   against ticket and spec, git-diffs the test files for modification,
   replies with the contract:
   match $verdict:
     "pass" -> merge and clean up (section 5)
     "reject", targetPhase == "build"
            -> the main session ITSELF resumes $agent_id with the
               findings (INV-3 — never re-dispatch, never via an
               intermediary); worker fixes on the current worktree
               state; rounds += 1; back to step 2
     "reject", targetPhase == "tdd"
               (test file modified, or the test itself judged faulty)
            -> fallback("tdd", findings)     # partial fallback:
               # let other dispatched tickets finish their current round
               # (passes merge as usual; rejects are parked with state
               # and worktree kept); no new waves meanwhile; this ticket
               # status -> "draft", its build:<id> key removed;
               # unaffected tickets keep all loop records and statuses;
               # TDD redoes the affected set and re-passes the whole
               # batch loop ("merged"/parked tickets are exempt from the
               # red criterion); then restore parked tickets (step 3.0)
               # and return the affected tickets to the dispatch set
     "reject", any blocking targetPhase in {"spec","prototype","explore"}
            -> fallback(earliest such phase, findings)   # FULL fallback
               # (quiesce in-flight tickets first); a same-round
               # targetPhase "tdd" finding is covered by the downstream
               # replay — no separate partial fallback
     round 3 exceeded
            -> escalate("round-limit", findings, ticket: <id>)
               ticket status -> "escalated"; other tickets not blocked
```

## 5. Merge and clean up

```
1. with flow/$unit checked out: run("git merge --no-ff ticket/<id>")
   # one ticket, one commit — never squash
2. immediately drop_worktree(t)                    # INV-13
   # nothing is cleaned up on its own
3. ticket status -> "merged" (frontmatter and state.json in sync);
   qualityLoops.build:<id>.status = "passed"
4. recompute the next wave (section 3 step 6)
```

## 6. Gate

None. All tickets `merged` auto-continues to Review.

## 7. Standalone invocation

- TDD not done: stop with a hint.
- Resumes must be issued by the session running this skill itself
  (orchestrate-driven or not).
- A waterfall fallback to TDD in standalone mode: perform the records and
  revocation, then stop and hint the user to run `/agent-flow:tdd`
  (cross-phase replay belongs to orchestrate).
- Never auto-continue to Review when done `# INV-11`.

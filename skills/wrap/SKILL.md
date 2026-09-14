---
name: wrap
description: >-
  Merges, archives, and cleans up fully automatically once review is
  approved and every test is green — commits locally, never pushes.
---

# Wrap

Before executing, `Read` `${CLAUDE_PLUGIN_ROOT}/references/glossary.md` —
all DSL vocabulary and `INV-n` numbers resolve there.

## 1. Preconditions

```
resolve_unit()
if gates.review.approvedAt == null:
  halt("Review must be approved first.")   # no bypass, no quick mode
run the FULL test suite on the unit branch
if not all green:
  halt and report — execute NO merge/archive/cleanup                # INV-9
```

## 2. Procedure (execute-verify, `# INV-9`)

The `worker` (role: wrap executor; refs: sdd-guide.md) and the `reviewer`
(Wrap verification mode) alternate. Every action is verified as soon as it
completes; any failed step stops the whole phase and escalates — no retry,
no automatic rollback.

**Recording responsibility**: the `reviewer` only returns its verification
conclusions and methods to the main session — it never writes `wrap.md`.
The main session relays them to the `worker`, who transcribes them into
the "Verified" fields of section 3 without altering the reviewer's
pass/fail conclusions or verification methods. `state.json` and ESC
records stay with the main session (`# INV-1`, `# INV-12`).

```
1. pre-test: worker runs the full suite on flow/$unit
   verify: reviewer independently confirms the exit code and output mean
           all passed
2. merge the unit branch into main:
   run("git checkout main && git merge --no-ff flow/$unit")  # never push
   verify: git log shows the merge commit and per-ticket history
3. merge the delta spec into the main spec: per references/sdd-guide.md
   (ADDED append / MODIFIED overwrite / REMOVED delete) into
   .agent-flow/specs/<domain>/spec.md   # domain from spec-delta.md frontmatter
   verify: reviewer checks requirement by requirement that every entry
           landed per the rules
4. archive: move changes/$unit/ wholesale to archive/<date>-$unit/
   # the two dates differ on purpose: archive date vs creation date
   verify: source directory gone; archive directory complete
5. delete the unit branch and leftover worktrees:
   run("git branch -d flow/$unit")
   run("git worktree list")  # safety net: remove any leftover belonging
                             # to this unit
   verify: neither listing shows this unit any more
6. post-merge re-test: run the full suite AGAIN on merged main (not a
   re-read of step 1's result)
   verify: independent confirmation all passed
   # a failure here is the case most in need of human hands — never
   # auto-revert
7. all passed: worker writes the action-by-action record at the FINAL
   path archive/<date>-$unit/wrap.md (section 3); main session prints:
   "Local merge complete. Nothing was pushed — push when you are ready."
8. state.json (already moved with the archive):
   phases.wrap = "done", artifact: "wrap.md"
```

## 3. Artifact — `wrap.md`

```markdown
# Wrap: <unit-name>

## Result: <success | failed at step <n> and escalated>

## Action-by-action record

### 1. Pre-test
- Action: ran `<test command>` on flow/<unit-name>
- Result: <passed (N tests) | failed (details)>
- Verified: <reviewer independent confirmation: pass | fail: reason>
- Timestamp: <ISO 8601>

(2-6 in the same format, in order: merge into main / merge main spec /
archive / delete branch and worktrees / post-merge re-test)
```

## 4. Escalation

ESC format per `references/quality-loop.md` §7, with
`rootCause: "wrap-failure"`, `phase: "wrap"`, and "Phase / round" filled
"Wrap (no rounds, execute-verify loop)".

- **Step 6 failure**: the ESC "Details" must include "main now contains
  the merge result but the tests fail — do you want the merge reverted?"
  The decision is the user's; never execute any revert automatically.
- **`decisions.md` path**: steps 1–3 fail → write
  `changes/<unit>/decisions.md` (archive has not happened); steps 5–6
  fail → write `archive/<date>-<unit>/decisions.md` (archive done;
  `state.json.escalations` also lives at the archived path) — never
  write back to a path that no longer exists.
- **Step 4 (archive) failure**: stop everything; no retry, no automatic
  move-back. The ESC record follows the actual `state.json` location,
  decided in order by the main session:
  1. `changes/<unit>/state.json` still exists → record at the source:
     that directory's `decisions.md` and that `state.json.escalations`;
     even if the archive target also exists, the source wins — never
     write both sides.
  2. Source `state.json` gone but `archive/<date>-<unit>/state.json`
     exists → record at the archive side (covers "move finished but
     archive verification failed").
  3. Neither exists, or the chosen location cannot be read/written →
     immediately report to the user: archive failed and the ESC record
     cannot be completed; do not create a new `state.json` or rebuild
     the source directory; never claim the dual write happened; record
     later once the user has intervened.
  The ESC "Details" must state the actual existence of source and
  target, the failed action, and the chosen record location. Partially
  moved files stay as they are for the user to rule on.

## 5. Gate

None — fully automatic.

## 6. Standalone invocation

Review not approved: refuse and report; no bypass mechanism exists.

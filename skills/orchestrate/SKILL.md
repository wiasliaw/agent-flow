---
name: orchestrate
description: >-
  Drives all seven phases in sequence, stopping only at the three approval
  gates and falling back automatically to the faulty phase when a review
  finds its root cause upstream.
---

# Orchestrate

Before executing anything below, `Read`
`${CLAUDE_PLUGIN_ROOT}/references/glossary.md` — every primitive, variable,
shared procedure, and `INV-n` in this file resolves there. When a DSL step
names another reference (`references/<name>.md`), expand it against
`${CLAUDE_PLUGIN_ROOT}` and, when dispatching, pass the **expanded absolute
path** in the briefing.

The main session runs this skill itself: it dispatches, decides, and
records — all long-running work goes to `agent-flow:worker` /
`agent-flow:reviewer` subagents.

## 1. Startup

```
Read ${CLAUDE_PLUGIN_ROOT}/references/glossary.md
Read ${CLAUDE_PLUGIN_ROOT}/references/state-management.md
if user input points at an existing .agent-flow/changes/<unit-name>/
   (explicit unit name, or current branch is flow/<unit-name>):
  read_state()                       # INV-1; schemaVersion check first
  continue from currentPhase / phases / gates
else:
  create_unit($request)
  enter Explore
```

## 2. Phase sequence and the three gates

| # | Phase | Gate? | Auto-continue condition |
|---|---|---|---|
| 1 | Explore | yes | after approval: open questions non-empty → Prototype; empty → Spec |
| 2 | Prototype | no (optional, skippable) | loop passed → Spec |
| 3 | Spec | yes | after approval → TDD |
| 4 | TDD | no | loop passed (test contract in force) → Build |
| 5 | Build | no | all tickets `merged` → Review |
| 6 | Review | yes | after approval → Wrap |
| 7 | Wrap | no (fully automatic) | done → flow ends |

Each phase's own procedure is its phase skill
(`${CLAUDE_PLUGIN_ROOT}/skills/<phase>/SKILL.md`); orchestrate drives them
in order, holds at the gates, and owns cross-phase continuation.

At each gate run `gate(phase)` with the presentation content:

- **Explore**: intent summary + key investigation conclusions + open
  technical questions (+ round-3 unresolved items, if any).
- **Spec**: the full `spec-delta.md` text.
- **Review**: `review.md`.

Approval commit message: `flow(<unit>): <phase> passed review`.

## 3. Dispatch

### 3.1 Call syntax

`subagent_type: "agent-flow:worker"` or `"agent-flow:reviewer"`; the
briefing carries the five role-briefing elements (see `dispatch` in the
glossary). Example:

```
Agent(subagent_type="agent-flow:worker",
      description="Write delta spec for 2026-09-10-password-reset",
      prompt="Role: spec author. First Read <abs>/references/sdd-guide.md.
              Inputs: changes/2026-09-10-password-reset/explore.md and
              (if present) prototype.md, plus .agent-flow/specs/<domain>/spec.md.
              Write changes/2026-09-10-password-reset/spec-delta.md following
              the EARS and ADDED/MODIFIED/REMOVED contract.")
```

Prompts pass file paths, never pasted content; subagents return a
conclusion summary plus path lists; reviewer replies use the
`references/quality-loop.md` JSON contract.

### 3.2 Standard loop and routing

Run `standard_loop(key, …)` per the glossary; route each verdict by
`references/quality-loop.md` section 3:

```
match review result:                              # INV-5, INV-6
  "pass"                                    -> qualityLoops.<key>.status = "passed"
                                               gate phase -> gate(phase); else auto-continue
  "reject", all blocking targetPhase == current
                                            -> in-phase return to author
                                               (Build: resume; others: re-dispatch
                                                with ALL findings); rounds += 1
  "reject", any blocking targetPhase earlier
                                            -> fallback(earliest targetPhase, findings)
  round 3 still "reject" with in-phase routing
                                            -> escalate("round-limit", findings)
                                               qualityLoops.<key>.status = "escalated"
```

### 3.3 Heavy loop (Review)

`maxRounds: 5`; dispatches are 3 `reviewer` lenses + 1 `reviewer` triage;
`qualityLoops` key fixed to `"review"`. Routing difference: a blocking
finding with `targetPhase: "build"` is not a resume (no in-flight worker
exists at Review) — `make_worktree` a fix worktree off the unit branch and
dispatch a **brand-new** `worker` into it, then re-run a full round;
earlier `targetPhase` → the fallback procedure below. Full procedure: the
review skill.

## 4. Waterfall fallback procedure — `fallback(toPhase, reason)`

This is the expansion of the `fallback` primitive (INV-6). Execute the
steps in order.

**Step 0 — Quiesce in-flight dispatches.** If subagent calls are still
running (Build parallel wave): let them finish their current round's
disposition — tickets whose review passes merge as usual; rejected ones are
parked (partial fallback: keep their state and worktree for step 6; full
fallback: handle per step 3(b)). Issue no new dispatches until everything
has settled.

**Step 1 — Fallback-limit precondition.** If `state.json.fallbacks`
already has 2 entries with the same `toPhase` (this would be the third):
do not fall back — `escalate("fallback-limit", …)` instead. `# INV-6`

**Step 2 — FB record (atomic dual write, INV-12).** Append the `## FB-<n>`
entry to `decisions.md` (template in `references/quality-loop.md` §7,
including the revoked scope and each revoked gate's original approval
time) and push the matching element onto `state.json.fallbacks`.

**Step 3 — Revoke state.** Two situations:

- **(a) Partial fallback** (`fromPhase == "build"` and
  `toPhase == "tdd"`, only some tickets affected — includes the
  dependency-deadlock case): Build is not revoked wholesale —
  `phases.build` stays `"in_progress"`; unaffected tickets keep their
  `qualityLoops.build:<id>` keys and statuses **unchanged**; remove only
  the affected tickets' `build:<id>` keys; `phases.tdd → "in_progress"`,
  reset `qualityLoops.tdd`; `currentPhase = "tdd"` (back to `"build"`
  after TDD re-passes).
- **(b) Full fallback** (every other case: `toPhase` is `"explore"` /
  `"prototype"` / `"spec"`, or triggered from Review): every phase after
  `toPhase` → `"pending"`; `toPhase` itself → `"in_progress"`; covered
  gates' `approvedAt`/`approvedBy` reset to `null` (object shape kept);
  remove downstream `qualityLoops` keys (including `build:*`) — **sole
  exception: `qualityLoops.review` is never removed** (its `rounds` is the
  persistent five-round budget, kept across fallbacks; only `status` →
  `"in_progress"`) `# INV-5`; tickets still `in_build`/`in_review` after
  step 0 settles (rejected in the final round): remove their worktrees,
  `status → "ready"` — unmerged partial work is discarded; the Build
  replay re-dispatches them, and TDD's diff judgment may still turn them
  `draft`; `currentPhase = toPhase`. Standard-loop phases being replayed
  restart their round counts (oscillation is bounded by step 1's fallback
  limit).

**Step 4 — Artifacts stay as drafts.** Never delete existing artifact
files; redo work revises them, never rewrites from zero. **Artifact
validity is judged by `state.json` phase status, not by file existence**:
a revoked phase's leftover file is only a draft — downstream phases must
not treat it as valid input (e.g. after an Explore redo empties the open
questions, `phases.prototype = "skipped"` and a leftover `prototype.md` is
no longer valid Spec input).

**Step 5 — Ticket handling.**

- Partial fallback (`toPhase == "tdd"`): affected tickets (test or ticket
  content needs revision) `status → "draft"`; everything else untouched —
  including parked in-flight tickets keeping `in_build`/`in_review`
  (restored in step 6).
- Full fallback (`toPhase` is `"spec"` or earlier): **change no ticket
  status now**; the affected set is determined later when TDD is replayed
  (the tdd skill's diff judgment). Tickets whose test behavior is touched
  by requirement changes reset `status → "draft"` and are redone;
  ticket-data-only fixes are edited in place without turning `draft`;
  untouched tickets keep their status — `merged` keeps its implementation
  and evidence, `ready` keeps its red tests and is **never asked to
  re-demonstrate red because of the fallback**.
- General: Build commits already merged into the unit branch are **never
  rolled back**; the Build replay dispatches only tickets whose tests
  turned red or whose content changed — green, unaffected tickets count
  directly as `merged`. In a TDD redo round the red criterion applies only
  to cases added or modified that round; when the implementation already
  satisfies a new case (coverage backfill), fallibility evidence replaces
  red; everything else is checked for contract integrity
  (`references/tdd-guide.md`).

**Step 6 — Redo and replay.** Redo `toPhase` → its quality loop → (if a
gate phase) **re-approval** `# INV-8` → replay downstream in the section-2
order until back at `fromPhase`. Partial-fallback restoration: after TDD
re-passes, **first restore the parked in-flight tickets** — for each
ticket kept `in_build`/`in_review`, `resume` its original `agentId` (its
worktree survived because it was never merged) to continue the original
fix, with rounds continuing from the preserved
`qualityLoops.build:<id>.rounds` — then resume wave scheduling for `ready`
tickets.

## 5. Build resume rule

When the `reviewer` rejects a ticket with `targetPhase: "build"`, the main
session **itself** runs `resume($agent_id, findings)` — never through an
intermediary subagent. If that agent is no longer addressable, dispatch a
fresh `worker` into the ticket's **existing** worktree; the work is on
disk, so nothing is lost. Never create a second worktree for the ticket.
`# INV-3` Either way, re-dispatch the `reviewer` afterwards (reviews are
fresh dispatches), `rounds += 1`, cap 3.

## 6. Event → `state.json` updates

| Event | Fields |
|---|---|
| Unit created | full initialization (`create_unit`) |
| Phase starts | `phases.<phase>.status = "in_progress"`, `currentPhase` |
| Phase loop passes | `phases.<phase>.status = "done"`, `artifact`, `qualityLoops.<key>.status = "passed"` |
| Prototype skipped | `phases.prototype = {"status": "skipped", "reason": "no open technical question"}` |
| Gate approved | `gates.<phase>` |
| Loop round done | `qualityLoops.<key>.rounds` / `status` |
| Waterfall fallback | `fallbacks` push; downstream `phases`/`gates`/`qualityLoops` revoked; `currentPhase`; ticket statuses (section 4) |
| Ticket frontmatter change | mirror into `tickets.<id>` |
| ESC raised / ruled | `escalations` push / `resolvedAt` backfill |
| Every write | `updatedAt` |

## 7. Standalone phase skills

When the user invokes `/agent-flow:<phase>` directly, that phase skill
handles its own precondition check, quality loop, gate (if any), and never
auto-continues. `# INV-11` Standalone fallback special case: the current
session still executes steps 1–5 of section 4 (records and revocation) but
does **not** redo across phases — it halts and tells the user to run
`/agent-flow:<toPhase>`; cross-phase replay belongs to orchestrate.

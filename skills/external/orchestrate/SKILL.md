---
name: orchestrate
description: >-
  Drives all eight phases in sequence, stopping only at the four approval
  gates, so you don't have to invoke each phase by hand.
---

# Orchestrate

Orchestrate drives the entire agent-flow pipeline — Discuss, Explore,
Prototype, Spec, Ticket, Dev, Review, Wrap — end to end, dispatching the
role subagents for each phase and stopping only at the four approval gates
(Discuss, Spec, Ticket, Review) and at escalations.

**This skill does not fork a subagent.** It drives the main session itself,
for the same reason `discuss` documents its own main-session exception: the
Discuss phase's multi-turn dialogue with you can only happen in the main
session, and orchestrate has to carry that dialogue as part of driving the
whole pipeline. Every dispatch described below (`Agent(subagent_type=
"agent-flow:<role>")`) is made by the main session directly, never by a
forked-out intermediary.

The main session is also the **only** writer of `.agent-flow/changes/<unit>/
state.json` while orchestrate is running. Before any read or write to it,
load the `state-management` internal skill and follow its schema and field
semantics exactly. Load `quality-loop` before dispatching a reviewer or
interpreting a reviewer's returned verdict. Load `using-worktree` — which
only orchestrate ever loads — before creating or resuming a ticket's
isolated worktree in the Dev phase. Load `parallel-dispatch` before fanning
out more than one read-only subagent at once (its main use here is Review's
three parallel audit squads).

## 1. New work unit, or resume an existing one?

Whenever you invoke this skill, the main session first decides your intent:

1. **Resume**: if your message points at an existing
   `.agent-flow/changes/<unit-name>/` directory (you name a unit explicitly,
   or the current git branch is already `flow/<unit-name>`), read that
   unit's `state.json` (per the `state-management` skill's rules) and use
   `currentPhase` together with each `phases.<phase>.status` /
   `gates.<phase>` to determine which phase to resume from.
2. **New**: otherwise, this is a new work unit — follow "3. Creating a new
   work unit" below.

## 2. Worktree pre-flight check (only right before Dev)

This check matters only immediately before the Dev phase — specifically,
the first time a ticket worktree needs to be created for this unit.
`worktree.baseRef` has no effect during Discuss/Explore/Prototype/Spec/
Ticket, so the main session never asks about it earlier than this.

1. Read the project's `.claude/settings.json` (a missing file counts as
   "not configured").
2. Check whether `worktree.baseRef` is set to `"head"`.
3. **Already `"head"`**: skip this check and proceed straight into Dev.
4. **Not set, or set to anything else** (e.g. the default `"fresh"`):
   present this to you — wording may be adapted, but it must always include
   the current state, the reason, and the exact setting to be written:

   ```
   The Dev phase needs every ticket's worktree to branch off the current
   unit branch, not off remote main (otherwise tickets would each start
   from a different point and couldn't correctly stack on top of the same
   unit branch as they accumulate).

   This requires setting the following in .claude/settings.json:
     { "worktree": { "baseRef": "head" } }

   Do you agree to write this project setting?
   ```

5. **If you agree**: read the existing `.claude/settings.json` if one
   exists (keep every other existing field untouched, only add/overwrite
   `worktree.baseRef` to `"head"`); if none exists, create a new file
   containing only this field.
6. **If you do not agree**: stop — the main session does not force its way
   into Dev. This is you overruling orchestrate's own recommendation, not a
   disagreement between agents, so it does **not** go through the ESC
   escalation mechanism (§6.6).

This is a distinct, one-time check from the Dev-phase-internal guarantee
(defined in the `using-worktree` skill) that confirms `baseRef: head` is
actually in effect immediately before *each* ticket worktree is created —
this section's check is about whether the *project setting* exists at all
(once written, it persists, so it is not repeated for every ticket); the
Dev-phase-internal rule is the complementary runtime guarantee that the
main session has actually checked out the correct unit branch before
creating each individual worktree. The two checks are complementary, not
redundant.

## 3. Creating a new work unit

1. **Decide `<unit-name>`**, format `<YYYY-MM-DD>-<slug>`:
   - Date: today's date (the same day recorded in `state.json.createdAt`).
   - `slug`: derive it from the core intent of your request — take the 2–4
     English words that best represent the feature's subject (translating
     the key terms first if you wrote your request in Chinese), lowercase,
     hyphen-joined (kebab-case), stripped of punctuation and filler words
     (`the`/`a`/`for`, etc.). Example: "add a forgot-password flow for
     users" → `password-reset`, giving the full unit name
     `2026-09-04-password-reset`.
   - If a directory with the same slug already exists for today, append an
     incrementing numeric suffix (`-2`, `-3`, …) to avoid overwriting it.
2. **Create the directory**: `.agent-flow/changes/<unit-name>/`.
3. **Initialize `state.json`**, per the `state-management` skill's schema:
   `schemaVersion: 1`, `unit: <unit-name>`, `createdAt`/`updatedAt` set to
   the current time, `currentPhase: "discuss"`, all eight `phases.<phase>`
   entries set to `{"status": "pending"}`, all four `gates.<phase>` entries
   set to `{"approvedAt": null, "approvedBy": null}`, `qualityLoops: {}`,
   `tickets: {}`, `escalations: []`, and
   `branch: {"unit": "flow/<unit-name>", "baseRef": "main"}`.
4. **Cut the unit branch**: `git checkout -b flow/<unit-name> main` (always
   branched off `main`).
5. **Enter the Discuss phase**, per "4. Phase sequence" below.

## 4. Phase sequence and the four approval gates

Drive the eight phases in this fixed order. Each phase's own procedure is
defined by its own skill (`discuss`/`explore`/`prototype`/`spec`/`ticket`/
`dev`/`review`/`wrap` — see spec/06–13); this section defines only the
continuation logic between them and how gates are presented.

| # | Phase | Approval gate? | Auto-continue condition |
|---|---|---|---|
| 1 | Discuss | Yes | Continues into Explore only once you approve |
| 2 | Explore | No | Auto-continues as soon as its quality loop passes |
| 3 | Prototype | No (may be skipped entirely) | Skipped straight into Spec if Explore left no open technical question; otherwise auto-continues once its quality loop passes |
| 4 | Spec | Yes | Continues into Ticket only once you approve |
| 5 | Ticket | Yes | Continues into Dev only once you approve |
| 6 | Dev | No | Auto-continues into Review once every ticket's Dev quality loop has passed |
| 7 | Review | Yes | Continues into Wrap only once you approve |
| 8 | Wrap | No (fully automatic) | Ends the whole flow; there is no next phase |

## 5. Approval-gate presentation (the common pattern)

All four gates follow the same shape (see the discuss/spec/ticket/review
skills for exactly what content each one presents):

1. The phase's quality loop has passed
   (`qualityLoops.<key>.status == "passed"`).
2. Read the phase's artifact file(s) and present the content to you
   (Discuss: the intent summary; Spec: the full delta spec; Ticket: the
   ticket list and test file locations; Review: the gap/issue summary).
3. Explicitly ask for your approval (e.g. "Approve moving into Explore?")
   and wait for your response.
4. **You approve**: write `state.json.gates.<phase> = {"approvedAt": <now>,
   "approvedBy": "user"}`, commit with message
   `flow(<unit>): <phase> passed review`, then move into the next phase.
5. **You decline, or ask for a change** — split into two cases:
   - **A concrete content edit request** (e.g. "this requirement is
     wrong"): treat this as one extra rejection round of that phase's
     quality loop — it does **not** count against the reviewer's own round
     limit, because this is your direct intervention, not an automated
     rejection. Dispatch the phase's author subagent to revise, then
     re-present.
   - **A request to go back to an earlier phase**: if the target phase's
     gate is not yet approved (e.g. Explore hasn't reached its gate), roll
     back to it directly. If the target phase's gate is **already
     approved** (e.g. you want to revise an already-approved Discuss
     summary), your decision takes priority over the "an agent may not
     overturn an approved artifact" principle — that principle restricts
     agents acting on their own, not your own explicit instruction. Carry
     out the change, then append an entry to `changes/<unit>/decisions.md`
     for the record, reusing the ESC template shape with "Root cause
     classification" filled in as "User-initiated modification" and "User
     decision" filled in with a summary of the change. **This is not a
     standard ESC escalation** — do not push it onto
     `state.json.escalations` (that array's semantics are "an escalation
     triggered by disagreement between agents," not "the user asked for a
     change").

## 6. Dispatch procedure

### 6.1 Agent tool call syntax

Always dispatch with `subagent_type: "agent-flow:<role>"`, where `<role>`
is one of the 17 agent-flow role filenames (without the `.md` extension):
`intent-reviewer`, `explorer`, `explore-reviewer`, `prototyper`,
`prototype-reviewer`, `spec-writer`, `spec-reviewer`, `ticket-writer`,
`ticket-reviewer`, `dev-worker`, `dev-reviewer`, `review-gap-hunter`,
`review-edge-case-hunter`, `review-spec-compliance-auditor`,
`review-triage`, `wrap-executor`, `wrap-verifier`. For example:

```
Agent(subagent_type="agent-flow:spec-writer",
      description="Write delta spec for 2026-09-04-password-reset",
      prompt="Read changes/2026-09-04-password-reset/explore.md and (if present)
              prototype.md, then write changes/2026-09-04-password-reset/spec-delta.md
              following the sdd-guide internal skill's EARS/delta contract.")
```

### 6.2 File-path handoff, lightweight return values

- Always pass **file paths** in dispatch prompts (relative to the project
  root, or an unambiguous absolute path) — never paste a previous phase's
  whole artifact content directly into a prompt.
- On completion, the only things needed from a dispatched subagent are:
  (a) a one-sentence outcome summary; (b) the list of file paths it wrote
  or modified. The full content always lives on disk — read the file
  directly when the details are needed, rather than relying on the
  subagent restating them in conversation.
- A reviewer subagent's return **must** be the standard JSON verdict format
  defined by the `quality-loop` internal skill (see §6.4). State this
  requirement explicitly in the reviewer's dispatch prompt — a format
  example may be included.

### 6.3 Standard-loop dispatch and round management

Applies to Discuss / Explore / Prototype / Spec / Ticket / Dev (per
ticket). Using Spec as the running example, the same pattern applies to
every other standard-loop phase:

1. **Round 1**: dispatch the author subagent (e.g. `spec-writer`) to
   produce the artifact.
2. Once the author finishes, dispatch the reviewer subagent (e.g.
   `spec-reviewer`), telling it in the prompt which round this is
   (`round`) and the round limit (`maxRounds: 3`).
3. Parse the reviewer's returned JSON (§6.4) and branch on `verdict`:
   - `"pass"`: write `state.json.qualityLoops.<key> = {"rounds": <current
     round>, "maxRounds": 3, "status": "passed"}`. The phase is done — if
     it is a gate phase, present the gate (§5); otherwise auto-continue
     into the next phase.
   - `"reject"`: branch on `findings[].rootCause` (§6.5).
4. **If `rounds` is about to exceed `maxRounds`** (this round is already
   round 3 and still `"reject"`): do not dispatch another revision —
   escalate immediately (§6.6) and set
   `qualityLoops.<key>.status = "escalated"`.

### 6.4 Reading a reviewer's verdict

Parse the returned JSON per the `quality-loop` internal skill's schema:

- `verdict`: `"pass"` or `"reject"` — decides whether the phase completes
  or is routed for rework.
- `findings[].rootCause`: `"implementation-issue"` or
  `"approved-artifact"` — decides the rejection route (§6.5).
- `escalation`: required whenever `verdict = "reject"` and any finding's
  `rootCause` is `"approved-artifact"`; its `targetArtifact` names which
  already-approved artifact the root cause points to (`"discuss"` /
  `"spec"` / `"ticket"`).

Review's heavy loop has two additional layers of output (the three
parallel squads' raw findings, and `review-triage`'s ruling, which reuses
the standard-loop shape) — parse `review-triage`'s ruling and fold it into
`review.md`; the three parallel squads' raw findings are intermediate
artifacts only and are never presented to you directly. **Unlike every
other standard-loop phase**: Review's `verdict` / `findings[].rootCause`
does **not** drive automatic routing here (no automatic reject-and-retry,
no automatic ESC) — every finding, regardless of root-cause
classification, is simply collected into `review.md` and handed to you at
the Review gate for a decision. The actual routing logic — a fresh,
non-resumed `dev-worker` dispatch, since there is no live `dev-worker` left
to resume once Review runs — is described in §7's closing paragraph, and in
spec/12-review.md's "purely-implementation-issue fix mechanism".

### 6.5 Rejection routing

- **`implementation-issue`**: the problem is inside this phase's own,
  not-yet-approved artifact — route back to the original author subagent:
  - Regular phases (Discuss/Explore/Prototype/Spec/Ticket): dispatch the
    same `subagent_type` again (a brand-new Agent tool call), including
    the reviewer's `findings` in the prompt so it revises accordingly.
  - Dev phase (`dev-worker`): **never** re-dispatch — a fresh dispatch
    gets a brand-new worktree. Instead, personally continue the
    conversation with the same `agentId` via `SendMessage` (§7).
  - Increment `rounds` and write it back to `state.json`.
- **`approved-artifact`**: the root cause is in an already-approved
  artifact — do **not** route back to any author subagent; escalate
  immediately (§6.6) regardless of which round it currently is (there is
  no round-count exception for this case).

### 6.6 Escalation (round limit exceeded, or root cause is an approved artifact)

1. Determine the new `ESC-<n>` (`n` = the current count of ESC entries
   already recorded for this unit, plus one).
2. As a single atomic step:
   - Append an `## ESC-<n>` block to `changes/<unit>/decisions.md` (leave
     "User decision" / "Decision time" blank, marked "pending").
   - Push a new element onto `state.json.escalations`
     (`resolvedAt: null`).
3. Update the corresponding `qualityLoops.<key>.status = "escalated"`.
4. Present the ESC content to you and wait for your decision. This is,
   like a gate, a moment where control is handed back to you — but it is
   not one of the four approval gates; it is the quality loop's own
   exception exit.
5. **Once you give a decision**: fill in `decisions.md` and
   `state.json.escalations[].resolvedAt`. What happens next depends
   entirely on your decision's content (revise the approved artifact and
   re-run that phase's loop and gate; keep things as-is and retry,
   treating the finding as a false positive; or any other instruction you
   give) — there is no single fixed follow-up action.

### 6.7 The heavy loop (Review)

See spec/12-review.md for the full procedure. From orchestrate's side, the
differences from the standard loop are: `maxRounds` is fixed at 5; the
dispatch targets are the three parallel review squads
(`review-gap-hunter`, `review-edge-case-hunter`,
`review-spec-compliance-auditor` — fanned out together, so load
`parallel-dispatch` first) plus `review-triage` once all three report, not
a single reviewer; the `qualityLoops` key is fixed at `"review"` (not
per-ticket, because Review is a single review of the whole unit); and
**§6.5's rejection routing does not apply** — Review never auto-retries
and never auto-escalates. Every finding is surfaced at the Review gate for
you to decide. There, "one round" means "you approve a fix → the fix is
applied → the three squads and triage run again from scratch." The
5-round limit and "round limit exceeded → escalate"
(`rootCause: "round-limit-exceeded"`) still apply unchanged.

## 7. Dev-phase `SendMessage` resume

1. `dev-reviewer` judges a ticket's implementation `verdict: "reject"`
   with `rootCause: "implementation-issue"`.
2. The main session itself (never through an intermediary subagent) uses
   the `SendMessage` tool, with `to` set to the `agentId` returned by that
   ticket's `dev-worker` dispatch, attaching `dev-reviewer`'s `findings` as
   the follow-up content.
3. **Never** re-invoke `agent-flow:dev-worker` via the Agent tool for
   this — even with the same `subagent_type`, it would get a brand-new
   worktree and lose the prior implementation.
4. Once `dev-worker`'s follow-up finishes, its completion notification
   comes back to the main session, because the main session is the one
   that initiated it.
5. Dispatch `dev-reviewer` again — this time a fresh dispatch, not a
   resume, since a reviewer does not need worktree state preserved; each
   review is an independent judgment of the worktree's current state.
6. Increment `rounds` and repeat the round management in §6.3, up to the
   3-round limit.

This resume mechanism does **not** apply to the Review phase: by the time
Review runs, every ticket has already been merged and there is no longer a
live `dev-worker` to resume. Review-phase fixes always use a **brand-new**
(non-resumed) `dev-worker` dispatched from the tip of the unit branch —
see spec/12-review.md for that mechanism.

## 8. `state.json` updates: event → field table

| Event | `state.json` fields updated |
|---|---|
| New work unit created | Entire file initialized (§3 step 3) |
| A phase starts (first author dispatch) | `phases.<phase>.status = "in_progress"`, `currentPhase = <phase>` |
| A phase's quality loop passes | `phases.<phase>.status = "done"`, `phases.<phase>.artifact = <path>`, `qualityLoops.<key>.status = "passed"` |
| Prototype skipped (no open technical question) | `phases.prototype = {"status": "skipped", "reason": "no open technical question"}` |
| You approve a gate | `gates.<phase> = {"approvedAt": <now>, "approvedBy": "user"}` |
| Every quality-loop round completes (pass or reject) | `qualityLoops.<key>.rounds` incremented, `qualityLoops.<key>.status` updated per §6.3/§6.4 |
| A ticket's frontmatter change is observed | `tickets.<id> = {"status": ..., "dependsOn": [...], "requirementRefs": [...]}` (mirror only, not authoritative) |
| An escalation is raised | New element pushed onto `escalations`, corresponding `qualityLoops.<key>.status = "escalated"` |
| You resolve an escalation | The matching `escalations[].resolvedAt` filled in |
| Every write | `updatedAt` set to the current time |

## 9. Invoking a single phase skill directly (not through `orchestrate`)

When you call `/agent-flow:<phase>` directly instead of
`/agent-flow:orchestrate`, this skill plays **no role at all** — the phase
skill itself takes on:

(a) checking whether its own preconditions are met;
(b) driving its own quality loop;
(c) if it is a gate phase, presenting its own approval request and writing
    `state.json.gates.<phase>` itself (temporarily acting as the sole
    writer of `state.json`, since orchestrate is not running); and
(d) **not** auto-continuing into the next phase once it finishes —
    continuation is orchestrate's responsibility alone, and it was not
    invoked this time.

See each phase's own spec (spec/06–13) for its standardized "used
standalone" behavior.

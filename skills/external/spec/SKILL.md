---
name: spec
description: Turns the approved findings into an EARS-format delta spec, numbered for traceability, and asks for your approval before tickets get cut.
---

# Spec

Spec is the fourth of the eight agent-flow phases. It turns the approved
Discuss intent — sharpened by Explore and, if it ran, Prototype — into a
delta specification: EARS-format requirements, numbered for traceability,
organized as ADDED/MODIFIED/REMOVED sections relative to the project's main
spec. Spec **is** a commitment point: the user must explicitly approve the
delta spec before the Ticket phase can begin.

## 1. Trigger and precondition

- **Trigger**: the user runs `/agent-flow:spec` (optionally with free-form
  instructions passed through `$ARGUMENTS`), or `orchestrate` drives this
  phase automatically once Explore (and Prototype, if it ran) has completed.
- **Precondition**: `changes/<unit>/explore.md` must exist and its quality
  loop must have passed.
  - **Driven by `orchestrate`**: this is satisfied when
    `state.json.phases.explore.status == "done"`.
  - **Invoked directly by the user**: see §7 "Behavior when invoked
    standalone" for how this skill checks the precondition itself.
  - If `changes/<unit>/prototype.md` exists (Prototype ran for this unit),
    read it too.

## 2. Determining the work unit

This rule is shared by this skill and the Ticket, Dev, Review, and Wrap
phase skills (`spec/10-ticket.md` through `spec/13-wrap.md`); it is written
out in full here and only referenced from those files.

Because the Spec phase (and each of the other phase skills listed above)
can be invoked standalone, without going through the `orchestrate`
scheduling shell, the session executing this skill must first determine
which work unit it is currently operating on:

1. If the current git branch matches the `flow/<unit-name>` naming
   convention, use that as the work unit.
2. Otherwise, if `.agent-flow/changes/` contains exactly one subdirectory,
   treat that as the current work unit.
3. Otherwise (zero or multiple candidates, and the branch name does not
   match), stop and ask the user which work unit to operate on, listing all
   subdirectories under `changes/` as choices.

## 3. Procedure

1. Determine the work unit (§2).
2. Read `changes/<unit>/discuss.md`, `changes/<unit>/explore.md`, and (if
   present) `changes/<unit>/prototype.md`, plus the existing main spec at
   `.agent-flow/specs/<domain>/spec.md` (if it already exists) — the latter
   is used to avoid requirement-number collisions and to judge what is
   actually changing relative to the current state.
3. Dispatch `agent-flow:spec-writer` (see `agents/spec-writer.md`) with the
   Agent tool. Pass only file paths in the prompt, never the full text of
   any upstream document (per the output-lands-in-a-file, pass-a-lightweight-
   reference principle):

   ```
   Agent(subagent_type="agent-flow:spec-writer",
         description="Write delta spec for <unit>",
         prompt="Read changes/<unit>/discuss.md, changes/<unit>/explore.md,
                 and changes/<unit>/prototype.md (if present), plus the
                 existing main spec at .agent-flow/specs/<domain>/spec.md
                 (if present). Write changes/<unit>/spec-delta.md following
                 the EARS and ADDED/MODIFIED/REMOVED contract defined in the
                 sdd-guide internal skill.")
   ```
4. Once `spec-writer` finishes, it reports back only a conclusion summary
   and the path(s) it wrote — never the full spec content pasted into the
   conversation.
5. Dispatch `agent-flow:spec-reviewer` (see `agents/spec-reviewer.md`) with
   the Agent tool, again passing only the file path to `spec-delta.md`. It
   reviews EARS format correctness, numbering consistency, and whether the
   delta aligns with the conclusions in `discuss.md`/`explore.md`.
6. Read `spec-reviewer`'s verdict, using the standard JSON contract defined
   by the `quality-loop` internal skill, and route as follows:
   - **`"pass"`**: proceed to step 7.
   - **`"reject"`**: at this point in the workflow there is no approved
     artifact belonging to the Spec phase itself (the delta spec has not
     been approved yet), so **every** rejection during this phase's own
     quality loop is routed as `implementation-issue`, regardless of what
     `findings[].rootCause` literally reports — send back to step 3 for
     `spec-writer` to re-dispatch and fix, and increment
     `state.json.qualityLoops.spec.rounds`. The loop is capped at **3
     rounds** (Q4). If the cap is reached, write an ESC entry per the
     `quality-loop` internal skill's rules (`decisions.md` +
     `state.json.escalations[]`, with `rootCause: "round-limit-exceeded"`)
     and stop, waiting for the user's decision.
7. Once the review passes, present the full text of `spec-delta.md` to the
   user and ask whether to approve it and proceed to Ticket.
8. Once the user approves:
   - Update `state.json`: set `phases.spec.status = "done"`,
     `phases.spec.artifact = "spec-delta.md"`, and write
     `gates.spec.approvedAt` / `gates.spec.approvedBy`; commit with message
     `flow(<unit>): spec passed review`.
   - `spec-delta.md` now becomes an **approved artifact**: from this point
     on, the rule that approved artifacts cannot be silently overridden by
     any agent applies to it.
   - If driven by `orchestrate`, automatically continue into the Ticket
     phase. If invoked standalone, the flow ends here (see §7).
   - If the user does **not** approve and instead gives feedback, go back to
     step 3 and have `spec-writer` revise according to that feedback. This
     does **not** count against the quality-loop round counter, because it
     is a user rejection, not a reviewer rejection.

## 4. `spec-delta.md` format and requirement numbering rules

Per the `sdd-guide` internal skill (see `spec/04-internal-skills.md` §2),
here is the concrete, ready-to-use example this skill's output must follow:

```markdown
---
unit: 2026-09-04-password-reset
domain: auth
---

## ADDED Requirements

### 1.1 WHEN a user requests a password reset THE SYSTEM SHALL send a reset link valid for 1 hour.

### 1.2 WHEN the reset link is used after expiry THE SYSTEM SHALL reject the
request and prompt the user to request a new link.

## MODIFIED Requirements

(Omit this section entirely — do not write an empty section — for a
greenfield domain, or when this change does not modify any existing
requirement.)

## REMOVED Requirements

(Same as above: omit if this change does not remove any existing
requirement.)
```

- **Frontmatter**: `unit` (the work unit name) and `domain` (the target
  domain under `.agent-flow/specs/<domain>/spec.md` that this delta will be
  merged into at Wrap time, per Q24). `spec-writer` determines `domain` by
  checking the existing domain names already present under
  `.agent-flow/specs/`; if none matches, it invents a new domain name
  (kebab-case) based on the content of the change.
- **Numbering rule**: `<major>.<minor>` (e.g. `1.1`, `1.2`), and this format
  must be **exactly** consistent with the ticket frontmatter
  `requirementRefs` field format defined in `spec/02-state.md`
  (`requirementRefs: ["1.1", "1.2"]`) — every ticket produced in the Ticket
  phase references the numbers assigned here. Numbers must not repeat
  within the same domain. A `MODIFIED` entry keeps the original number of
  the requirement it modifies. A `REMOVED` entry likewise keeps the
  original number and adds a one-line explanation of why it was removed.

## 5. Quality loop

Standard loop (Q4): single independent reviewer, capped at 3 rounds. The
full frontmatter, responsibilities, and prohibitions for `spec-reviewer`
(author: `spec-writer`) are defined in `spec/03-agents.md` §6–7; the
reviewer output format contract is defined in `spec/04-internal-skills.md`
§6. Escalation via ESC applies when the round cap is exceeded. As noted in
§3 step 6, because the Spec phase's own artifact is not yet approved at
this point, a rejection whose root cause is "an already-approved artifact"
does not practically occur here — that only becomes possible starting with
the Ticket/Dev phases. Every rejection during this phase's loop is treated
as `implementation-issue`.

## 6. Commitment point

Yes (Q3). Once approved, `spec-delta.md` becomes an approved artifact, and
`state.json.gates.spec` records the approval timestamp and approver.

## 7. Behavior when invoked standalone (not via `orchestrate`)

- If `changes/<unit>/explore.md` does not exist: **stop and tell the user**
  to run `/agent-flow:explore` first. Do not automatically run Explore on
  the user's behalf — per Q2, a standalone phase invocation is manual only,
  and this phase must not silently execute another phase for the user. Do
  not offer any "force-skip Explore" option or syntax.
- If the phase runs successfully through to gate approval, behavior is
  identical to being driven by `orchestrate`, with one difference: after
  approval, this skill does **not** automatically continue into the Ticket
  phase. The user must invoke `/agent-flow:ticket` or
  `/agent-flow:orchestrate` themselves to continue.
